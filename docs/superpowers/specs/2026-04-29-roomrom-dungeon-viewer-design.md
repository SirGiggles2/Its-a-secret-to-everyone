# RoomRom dungeon-room viewer — design

## Context

`RoomRom/` is a standalone SGDK harness that boots straight to overworld
room `$77` and lets the user walk every overworld room with the D-pad and
toggle the original/Redux variant with `C`. It exists so we can iterate
on room rendering without sitting through the title sequence and file
select on every test.

The HUD and overworld renderer are now correct (commits
[09f05047], [9e002c0d], [a3efd411]). The next biggest subsystem we still
have to boot through file-select to exercise is **dungeon rooms**:
- 8 dungeons × ~16 rooms each ≈ ~150 rooms of underworld content.
- Has its own room data (`data/rooms/dungeons.c`, 7022 bytes).
- Has its own background CHR (`data/chr/underworld_bg.c`, 264 lines).
- Tile/attr/heap layout mirrors overworld (per `data/rooms/MANIFEST.json`).

Goal: extend RoomRom so a single button press flips it from
"overworld viewer" to "dungeon viewer" and the D-pad walks dungeon rooms
the same way it walks overworld rooms today. Same harness, same fast
boot, no FS in the loop.

## Scope

**In scope**
- New "scene" axis in RoomRom: scene = overworld | dungeon.
  - Button `B` toggles scene (overworld ↔ dungeon).
  - Button `C` continues to toggle map variant (original/Redux) and is
    scoped per-scene (Redux dungeons reuse the existing Redux dungeon
    data if present; otherwise C is a no-op in dungeon scene).
- Dungeon room renderer that consumes `rooms_dungeons` the same way
  the overworld renderer consumes `rooms_overworld`:
  - Pull palette + attrs from `LevelBlockUW1Q1` style sub-tables.
  - Decode column-encoded room layouts.
  - Reuse `s_primary_squares` / `s_secondary_squares` if dungeons share
    them; if not, add `s_primary_squares_uw` / `s_secondary_squares_uw`
    sourced from the dungeon manifest entries.
- Dungeon CHR upload path: load `underworld_bg_chr` into the same VDP
  tile range overworld currently uses (replacing OW BG when scene =
  dungeon). Common CHR (font, HUD glyphs, item icons) stays loaded.
- HUD remains visible in dungeon scene with no changes — same map block,
  hearts, item counts. The map dot still tracks current room id (1-D
  position within whichever scene is active).
- D-pad nav clamps to dungeon room space (presumably 8 cols × 8 rows of
  rooms, depending on the dungeon data layout — confirm during impl).

**Out of scope (explicit non-goals)**
- Dungeon-specific HUD (the level-N indicator, compass/map tracking,
  triforce piece). Stock HUD only.
- Sprite rendering (Link, enemies, blocks).
- Doors, transitions, scrolling, music.
- Item subscreen.
- Cave/grotto interior rooms (separate sub-format).
- Boss rooms beyond what fits the static room renderer.

## Architecture

```
main.c
 └── load_room(scene, room_id, map_id)
      ├── if scene == OW : roomrom_ow_room_render_*
      └── if scene == UW : roomrom_uw_room_render_*
                            (new module, same shape)
ow_room_render_roomrom.c     ← unchanged
uw_room_render_roomrom.c     ← new, ports the OW pipeline to dungeons
roomrom_hud.c                 ← unchanged
build.bat                     ← add uw_room_render_roomrom.c + dungeons.o
```

`uw_room_render_roomrom` exposes the same surface as the OW module:

```c
void roomrom_uw_room_render_set_map(unsigned char map_id);
unsigned char roomrom_uw_room_render_get_map(void);
void roomrom_uw_room_render_load_palette(unsigned char room_id);
void roomrom_uw_room_render_upload_chr(void);
void roomrom_uw_room_render_fill_plane_a(unsigned char room_id);
```

`main.c` gains:

```c
typedef enum { SCENE_OW = 0, SCENE_UW = 1 } scene_t;
static scene_t s_scene = SCENE_OW;
```

…and `BUTTON_B` toggles `s_scene`, re-uploads CHR, reloads room.

## Critical files to modify or add

| File | Change |
|------|--------|
| `RoomRom/src/main.c` | Add scene state, button-B handler, scene-aware load. |
| `RoomRom/src/uw_room_render_roomrom.c` (new) | Dungeon renderer port of the OW renderer. |
| `RoomRom/src/uw_room_render_roomrom.h` (new) | Public surface for above. |
| `RoomRom/src/ow_room_render_roomrom.h` | Add `ROOMROM_SCENE_OW` / `ROOMROM_SCENE_UW` constants if shared. |
| `RoomRom/build.bat` | Compile `uw_room_render_roomrom.c` + `data/rooms/dungeons.c`. |
| `RoomRom/tools/gen_redux_roomrom.py` | If Redux dungeon data is generated here, extend it. Otherwise no-op. |

Existing functions to reuse:
- `render_set_plane_a_word`, `render_load_palette`, `render_chr_upload`
  (render_abi).
- `s_pal_to_attr`, `ow_tile_palette`, `tile_word`, `write_tile`,
  `write_square` — port verbatim into UW module if dungeon attribute
  layout matches OW. If it does not, write a UW-specific variant.

## Data flow

1. Boot: `init_video` → upload OW BG CHR + HUD CHR → `load_room(OW, $77)`.
2. User presses `B`: `s_scene ^= 1`, re-upload BG CHR for new scene,
   reset `room_id` to `$00`, call `load_room`.
3. User presses D-pad: `room_id` walks within scene's room-id space.
4. User presses `C`: scene-local map-variant toggle as today.

## Verification

- `RoomRom/build.bat` produces a clean `out/RoomRom.md` with no warnings
  beyond what overworld build already emits.
- Boot the ROM in BizHawk via the existing `bizhawkScript` skill.
- Press `B`. First dungeon room renders. D-pad walks rooms; tile data
  visibly differs per room. HUD remains intact.
- Press `B` again. Returns to overworld at room `$00` (or `$77` if we
  cache last-room-per-scene — TBD: defer caching to a follow-up; first
  cut just resets to scene-default).
- Press `C` in OW scene: still flips OW original/Redux as today.
- Screenshot dungeon room 1 entry and compare against an NES live-dump
  of the same room (probe pattern: `probe_nes_hud_reference.lua` style,
  but dumping NT rows 7..28 for the play area instead of HUD rows).
- Commit a `RoomRom/probe_nes_uw_reference.lua` for the dungeon NT/AT
  capture so future regressions can re-verify.

## Risks / open items

- Dungeon attribute encoding may not be identical to overworld. If the
  AT layout differs, the OW `ow_tile_palette` won't transplant cleanly
  and we'll need a UW-specific palette-resolution function. Resolve at
  implementation time by reading the dungeon section of
  `data/rooms/MANIFEST.json` against the actual NES disassembly path.
- Dungeon BG CHR may overlap or share VRAM tile slots with HUD glyphs.
  If so, the dungeon CHR upload must avoid the HUD slot range (currently
  $50..$52 custom + the font/digit range in common_chr).
- Redux-mode dungeons: `s_secondary_squares_redux` exists for OW but no
  redux dungeon data exists yet. First cut leaves dungeon-redux toggle
  as a no-op and prints nothing different.
