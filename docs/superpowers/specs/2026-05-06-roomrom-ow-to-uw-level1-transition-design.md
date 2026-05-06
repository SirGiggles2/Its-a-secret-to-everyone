# RoomRom OW-to-UW Level 1 Transition Design

**Date:** 2026-05-06
**Status:** Approved design, pending implementation plan
**Scope:** First real RoomRom overworld-to-underworld scene transition, limited to Level 1.

## Goal

Wire the overworld entrance for Level 1 into the existing RoomRom underworld runtime without creating a one-off debug shortcut.

The first playable proof is:

1. RoomRom is in overworld room `$37`.
2. Link stands on the Level 1 entrance tile at NES-valid alignment.
3. RoomRom transitions into underworld Level 1 room `$73`.
4. The resulting UW scene uses the same render, HUD, palette, movement, collision, and door-state behavior that already works when RoomRom boots directly to UW room `$73`.

## Current Context

RoomRom already has working pieces for both sides:

- `RoomRom/src/main.c` owns the direct gameplay harness, scene enum, movement loop, scroll transitions, and room-load calls.
- `RoomRom/src/ow_room_render_roomrom.c` decodes overworld room data and caches 16x11 metatile walkability, but it does not expose the raw rendered tile that NES `CheckWarps` uses.
- `RoomRom/src/uw_room_render_roomrom.c` can render UW rooms by level, quest, and room id.
- `RoomRom/src/uw_door_state.c` initializes door state from LevelBlock attributes and is already verified around Level 1 room `$73`.
- `RoomRom/data/uw_level1_quest1_rooms.json` identifies Level 1 quest 1 start room as `$73`.
- `data/rooms/overworld.c` identifies the overworld Level 1 entrance room as `$37`, with `RoomAttrsOW_B[$37] = $07`; NES derives level `1` from `(attr_b & $FC) >> 2`.

The gap is not rendering UW. The gap is a reusable scene handoff from OW standing-tile detection into the existing UW load path.

## Chosen Approach

Add a native RoomRom transition coordinator with NES data/rules underneath it.

The first slice gates behavior to Level 1 only, but the implementation shape must be reusable for every later dungeon and cave transition. Room `$37` should not be hardcoded as "go to `$73`" in the movement loop. Instead, room `$37` should fall out of the overworld metadata and the coordinator should allow only the Level 1 result through for now.

Rejected alternatives:

- Hardcoded room/coordinate shortcut: fast, but creates a path that must be deleted before Level 2-9, cave transitions, and Title.md promotion.
- Full NES mode/submode port immediately: accurate eventually, but too broad for the first slice and likely to tangle native RoomRom state with old mode assumptions.

## Architecture

### Overworld Raw-Tile Cache

Extend `ow_room_render_roomrom` so every rendered overworld room records the raw NES tile ids for the active 32x22 playfield, in addition to the existing 16x11 walkability cache.

Required API:

```c
unsigned char roomrom_ow_room_render_raw_tile_at(unsigned char tile_col,
                                                 unsigned char tile_row);
unsigned char roomrom_ow_room_render_level_selector(unsigned char room_id);
```

`raw_tile_at` returns `0` for out-of-bounds. `level_selector` reads `RoomAttrsOW_B[room_id] & $FC`; callers derive a dungeon level with `selector >> 2` only when `selector < $40`.

### Transition Coordinator

Add a small RoomRom-owned transition boundary, either `roomrom_world_transition.{c,h}` or an equivalent narrowly named module.

Responsibilities:

- Decide whether Link is standing on a valid OW underground entrance.
- Resolve a supported destination.
- Apply the scene handoff through the existing RoomRom load primitives.
- Keep all first-slice limitations explicit.

The coordinator should not draw rooms directly and should not duplicate UW renderer or door-state logic. It should call the same upload/load path that direct scene toggles already use.

### Main Loop Integration

`main.c` remains the owner of input and movement. After movement, when Link is not scrolling and is not in combat lock, it asks the coordinator whether a transition should start.

If a transition fires, `main.c` stops further frame movement, switches scene state, and reloads the room through the normal path.

## NES Rules For First Slice

The detector mirrors the important NES `CheckWarps` and `HandleWarpOW` rules:

1. Link must not be mid-grid. In RoomRom terms, `s_link_grid_offset == 0`.
2. For normal overworld rooms, Link's X must be a multiple of `$10`.
3. Link's Y must be `(multiple of $10) + $0D`.
4. The standing tile must be one of:
   - `$24`
   - `$88`
   - `$70`, `$71`, `$72`, or `$73`
5. The OW selector is `RoomAttrsOW_B[room_id] & $FC`.
6. If selector `< $40`, it is a dungeon level selector.
7. The first slice only accepts `selector >> 2 == 1`.

For Level 1 quest 1, the destination is UW room `$73`.

## Handoff Details

On a valid Level 1 entry:

1. Record source OW room id and source Link position in RoomRom-private state for later exit work.
2. Set scene to UW.
3. Set UW level to `1`.
4. Set UW quest to the current UW quest setting, defaulting to quest 1.
5. Set room id to `$73`.
6. Reset movement residue: grid offset, position fractions, active doorway, scroll state, and last movement direction.
7. Place Link at the canonical UW entrance spawn already used by direct UW boot.
8. Upload UW CHR and sprite CHR through `roomrom_scene_load`.
9. Load room `$73` through the existing room load function.
10. Re-apply combat scene bias with `roomrom_combat_set_uw(1)`.

Direct UW boot should remain available until the transition path has its own probes. A later implementation plan can decide whether to keep direct UW boot as a debug option or default boot to OW `$37` for this task.

## Deferred Work

The first slice intentionally does not implement:

- UW exit back to OW.
- Stair/fade/audio transition polish.
- Level 2-9 entry.
- Quest 2 Level 1 entry.
- Cave entry.
- Mode `$10` compatibility with the transpiled Title.md path.
- Save persistence of source room and return position.

These are follow-up slices that should reuse the coordinator rather than extend special cases in `main.c`.

## Error Handling

Unsupported selectors do nothing. This includes cave selectors, Level 2-9 selectors, and invalid room metadata.

If the raw-tile cache is queried out of range, it returns `0`, which cannot satisfy the entrance tile set.

If the destination cannot be resolved, the coordinator leaves scene, room id, Link position, and rendering state unchanged.

## Verification

Minimum first-slice gates:

1. Build RoomRom cleanly.
2. Add a small unit-style probe for OW room `$37` metadata:
   - `RoomAttrsOW_B[$37] == $07`
   - selector `< $40`
   - derived level is `1`
3. Add or extend a BizHawk RoomRom probe:
   - start in OW room `$37`
   - place or move Link onto the entrance at valid alignment
   - verify scene becomes UW
   - verify room id becomes `$73`
   - verify UW level is `1`
   - verify Link can move after the handoff
   - verify room `$73` door state still matches the current Phase 5.3 expectations
4. Run the existing UW room `$73` door and movement probes after the transition probe to confirm the new entry path did not regress direct UW behavior.

## Acceptance Criteria

The design is complete when RoomRom can enter Level 1 from the overworld using NES-derived room metadata and land in UW room `$73` through the same runtime path used by direct UW boot, with no hardcoded room `$37` to room `$73` shortcut in the movement loop.
