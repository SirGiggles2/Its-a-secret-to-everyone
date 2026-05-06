# RoomRom OW-to-UW Level 1 Transition Design

**Date:** 2026-05-06 (revised same day after adversarial review)
**Status:** Approved design, pending implementation plan
**Scope:** First real RoomRom overworld-to-underworld scene transition, limited to Level 1.
**Phase / Task:** Ph5 Dungeon Core / Task 5.4 (registered in master plan; existing 5.4-5.9 renumbered to 5.5-5.10 to put entry before navigation)
**Targets affected (PARITY — both built + verified per commit):**
  - `RoomRom.md` — standalone gameplay harness (no Title boot).
  - `CombinedDebug.md` — **final shipping product** = Title boot + RoomRom runtime exports. User decision 2026-05-06.
  `Title.md` is **out of scope** (Phase 11/12 only).

## Drain-Coverage Header (Rule D1)

```
- NES source: reference/aldonunez/Z_05.asm:CheckWarps (line 7213)
              reference/aldonunez/Z_05.asm:HandleWarpOW (line 7313)
- Drained C:  NONE
- Coverage:   NONE
- Stance:     GREENFIELD
```

**GREENFIELD justification.** `tools/audit/drain_coverage.py` shows zero drained
rows for `CheckWarps` / `HandleWarpOW`. Translated 6502→M68K assembly exists at
`src/zelda_translated/z_05.asm:8035` and `:8163` but RoomRom does not link the
translated path. NES disasm is the final authority per Rule D1; this spec
treats `Z_05.asm:7213-7369` as the canonical behavior source.

## Goal

Wire the overworld entrance for Level 1 into the existing RoomRom underworld
runtime through an **NES-faithful warp state machine**, not a synchronous
teleport. The state machine is the reusable transition substrate for every
later dungeon, cave, and shortcut entrance.

The first playable proof is:

1. RoomRom starts in overworld room `$37`.
2. Link stands on the Level 1 entrance tile at NES-valid alignment.
3. RoomRom transitions into underworld Level 1 room `$73`.
4. The resulting UW scene matches direct UW boot to room `$73` byte-for-byte
   on the parity oracle.

## Current Context

RoomRom already has working pieces for both sides:

- `RoomRom/src/main.c` owns the direct gameplay harness, scene enum, movement
  loop, scroll transitions, room load.
- `RoomRom/src/ow_room_render_roomrom.c` decodes overworld room data and
  caches a 16x11 metatile walkability grid. It does **not** publish raw
  rendered tile ids and does **not** track tile mutations from secrets,
  bombed rocks, or burnt bushes.
- `RoomRom/src/uw_room_render_roomrom.c` renders UW rooms by level, quest,
  and room id (`set_level / set_quest / fill_plane_a`).
- `RoomRom/src/uw_door_state.c` initializes door state from LevelBlock
  attributes and is verified against Level 1 room `$73` (Phase 5.3 closed).
- `RoomRom/data/uw_level1_quest1_rooms.json:start_room_id == 0x73` is the
  data-driven destination authority.
- `data/rooms/overworld.c` is a flat byte blob (`rooms_overworld[4114]`).
  The OW LevelBlock `Attrs B` table lives at offset `+128` in the OW block
  (per `RoomRom/tools/audit_uw_walkability_all.py:79` / `:113`); attribute
  byte for OW room `$37` is `$07`.

The gap is **not** rendering UW. The gap is the warp state machine and a
small body of OW metadata accessors.

## Build-Target Coverage

This task touches RoomRom runtime exports linked into both `RoomRom.md`
and `CombinedDebug.md`. **Both ROMs are built and verified per commit.**
Anything new declared with file scope in `RoomRom/src/` that the
coordinator publishes for testing must be exported through
`roomrom_debug_runtime.h` so `tools/combined_debug/build_combined_debug.py`
sees the same ABI.

CombinedDebug = Title boot + RoomRom runtime = the **final shipping
product** per user 2026-05-06. Per-commit gate is parity-driven: warp
behavior must be byte-for-byte equivalent between RoomRom standalone and
CombinedDebug. ABI drift between the two = fail.

`Title.md` is **not** built or modified by this task. Build target rule
`BT-1` reserves Title.md for Phase 11+ with explicit user approval.

## Chosen Approach

Add a native RoomRom **transition coordinator** that owns a small NES-faithful
warp state machine, plus an OW metadata accessor module. The L1-only gating
is a manifest entry, not an `if` on a level constant. Room `$37` is never
mentioned in coordinator code; destinations come from
`data/levelinfo_start_rooms.{c,h}` (new, see §"Destination Resolver").

Rejected alternatives:

- **Hardcoded shortcut.** Fast, but creates a path that must be deleted before
  L2-9, cave transitions, and `Title.md` promotion.
- **Synchronous teleport in main loop** (the rejected v1 of this spec).
  Looks cheap, but skips the entire NES `GameMode = $10` transition phase.
  Future stairs / fade / audio work would have to rewrite the coordinator
  rather than extend it.
- **Full NES mode/submode port immediately.** Too broad for one slice and
  likely to tangle native RoomRom state with old mode assumptions.

## Architecture

### OW Metadata Accessor (new, NOT in renderer)

New module `RoomRom/src/ow_room_meta.{c,h}`. Keeps room metadata logic out
of the renderer. Exposes:

```c
unsigned char roomrom_ow_meta_attr_b(unsigned char room_id);
unsigned char roomrom_ow_meta_level_selector(unsigned char room_id); /* attr_b & 0xFC */
unsigned char roomrom_ow_meta_is_level_selector(unsigned char selector); /* selector < 0x40 */
unsigned char roomrom_ow_meta_level_from_selector(unsigned char selector); /* selector >> 2 */
```

Implementation reads from the canonical OW LevelBlock `AttrsB` table via
the data accessor already used by `audit_uw_walkability_all.py`
(blob offset `+128` of the OW LevelBlock).

### OW Raw-Tile Accessor

Extend `ow_room_render_roomrom` so every rendered overworld room records
the raw NES tile ids for the active 32x22 BG-tile grid (NES
`ObjCollidedTile` units), in addition to the existing 16x11 walkability
cache. **Do not put `level_selector` here** — the renderer reports pixels,
not metadata.

```c
/* Raw NES BG tile id at the requested 32x22 column/row of the currently
 * rendered OW room. Returns 0 for out-of-bounds. */
unsigned char roomrom_ow_room_render_raw_tile_at(unsigned char tile_col,
                                                 unsigned char tile_row);
```

**Cache scope.** One room — the currently rendered room. Re-rendering a
room overwrites the cache. This is sufficient for L1Q1: room `$37` is
virgin (no secret reveals). Mutation-aware updates from bombed rocks,
burnt bushes, and pushed blocks are **explicitly out of scope**; the API
docstring must say `tile_at_render_time`, not `tile_at`. A future ticket
adds a renderer publish hook for tile mutations.

### Destination Resolver (new, data-driven)

New table `RoomRom/data/levelinfo_start_rooms.{c,h}` generated from JSON
under `RoomRom/data/uw_level{N}_quest{Q}_rooms.json`:

```c
struct levelinfo_start_room {
    unsigned char level;
    unsigned char quest;
    unsigned char start_room_id;
};
extern const struct levelinfo_start_room levelinfo_start_rooms[];
extern const unsigned char levelinfo_start_rooms_count;

unsigned char levelinfo_start_room_for(unsigned char level,
                                       unsigned char quest,
                                       unsigned char *out_room_id);
```

Phase 1 generator covers L1Q1 only (one row, `$73`). Adding L2-L9 is a
JSON edit + regen, no coordinator change. **`$73` literal does not appear
anywhere in `roomrom_world_transition.{c,h}`.**

### Transition Coordinator (warp state machine)

New module `RoomRom/src/roomrom_world_transition.{c,h}`. Owns a 4-state
machine that mirrors NES `GameMode = $10` semantics, even though the
first slice runs the visible portions in 0 frames.

```c
typedef enum {
    RR_WARP_IDLE      = 0,
    RR_WARP_PREPARE   = 1, /* tile + room latched, save state captured */
    RR_WARP_ANIM      = 2, /* mode $10 placeholder (0-frame in slice 1) */
    RR_WARP_LOAD      = 3, /* CHR upload + room load */
    RR_WARP_RESUME    = 4  /* movement + combat re-armed */
} rr_warp_state_t;

void roomrom_world_transition_init(void);
void roomrom_world_transition_tick(void);
unsigned char roomrom_world_transition_is_active(void); /* main.c freezes movement when 1 */
unsigned char roomrom_world_transition_check_warp(/* OW context: room_id, link_x, link_y, grid_offset, underground_exit_type */);
```

Responsibilities:
- Run the state machine each frame.
- On `IDLE`, query OW preconditions; on hit, transition to `PREPARE`.
- Persist source-of-truth state (see §"Coordinator Save State").
- In `LOAD`, perform exactly one CHR/scene/room/door/combat retarget
  through the existing RoomRom load primitives.
- On `RESUME`, re-arm input and movement; return to `IDLE`.

The coordinator does **not** draw rooms, does **not** decide what
attributes a destination room has, and does **not** duplicate UW renderer
or door-state logic.

### Coordinator Save State (closed contract)

The coordinator owns this struct. Field set is closed; adding a field is
a coordinator change and a spec amendment.

```c
typedef struct {
    unsigned char source_room_id;       /* OW room Link warped from */
    unsigned char source_underground_entrance_tile; /* NES UndergroundEntranceTile, post-collapse */
    unsigned char source_underground_entrance_tile_raw; /* pre-collapse, for $24/$88/$70-$73 routing */
    short         source_link_x;
    short         source_link_y;
    unsigned char source_link_face;
    unsigned char dest_level;
    unsigned char dest_quest;
    unsigned char dest_room_id;
} rr_warp_save_state_t;
```

`source_underground_entrance_tile` follows NES collapse `$70/$71/$72/$73 → $70`
([Z_05.asm:7331-7332](reference/aldonunez/Z_05.asm:7331)). Both raw and
collapsed forms are kept so the deferred UW→OW exit slice can replay NES
behavior without breaking the coordinator API.

## NES Rules For First Slice

The detector mirrors `CheckWarps` and the OW half of `HandleWarpOW`
([Z_05.asm:7213-7369](reference/aldonunez/Z_05.asm:7213)):

1. **`UndergroundExitType == 0`**. NES `LDA UndergroundExitType / ORA ObjGridOffset / BNE Exit`
   ([Z_05.asm:7217-7219](reference/aldonunez/Z_05.asm:7217)).
   RoomRom does not yet model `UndergroundExitType`; for the first slice
   wire a static `s_underground_exit_type` (initialized 0; set non-zero
   by the future UW→OW exit path) so the rule is callable today.
2. **`grid_offset == 0`**. RoomRom `s_link_grid_offset == 0`
   ([main.c:92](RoomRom/src/main.c:92)).
3. **X alignment.** For OW rooms other than `$22`, `link_x & 0x0F == 0`.
   Room `$22` (Level 6 wide entrance) uses `link_x & 0x07 == 0`
   ([Z_05.asm:7220-7237](reference/aldonunez/Z_05.asm:7220)).
   First slice supports both branches; only `$37` exercises the
   normal branch, but `$22` cost is one `cmp` and avoids a future
   special-case patch.
4. **Y alignment.** `link_y & 0x0F == 0x0D`
   ([Z_05.asm:7241-7244](reference/aldonunez/Z_05.asm:7241)).
5. **Tile is a warp tile.** `roomrom_ow_room_render_raw_tile_at(col, row)`
   returns one of `$24`, `$88`, `$70`, `$71`, `$72`, `$73`
   ([Z_05.asm:7320-7327](reference/aldonunez/Z_05.asm:7320)).
6. **Selector resolves to a level.** `attr_b = roomrom_ow_meta_attr_b(room_id)`,
   `selector = attr_b & 0xFC`, `selector < 0x40`
   ([Z_05.asm:7339-7344](reference/aldonunez/Z_05.asm:7339)).
7. **Manifest gate.** `levelinfo_start_room_for(level, quest, &dest)` succeeds.
   First slice manifest contains only L1Q1; selectors that resolve to
   L2-L9 hit rule 7 and stay in `IDLE`.
8. **Tile collapse.** If raw tile in `$70..$73`, store collapsed `$70` as
   `source_underground_entrance_tile`; raw form goes in
   `source_underground_entrance_tile_raw`. Tiles `$24` and `$88` pass
   through unchanged
   ([Z_05.asm:7328-7333](reference/aldonunez/Z_05.asm:7328)).

For Level 1 quest 1, the destination is whatever
`levelinfo_start_room_for(1, 1, ...)` returns (currently `$73`).

## Handoff Details (PREPARE → LOAD)

`PREPARE`:

1. Capture `rr_warp_save_state_t` (source room id, post-collapse and raw
   tile id, source Link x/y/face, dest level/quest/room).
2. Optional `SaveKillCount`-equivalent. RoomRom currently has no killed-
   enemy bitmap; add a no-op stub `roomrom_world_save_kill_count(scene, room)`
   exported through `roomrom_debug_runtime.h` so the call site is correct
   today and the implementation slots in when combat persistence lands
   ([Z_05.asm:7334](reference/aldonunez/Z_05.asm:7334)).
3. Transition to `ANIM`.

`ANIM` (slice-1 placeholder, runs 0 frames):

1. Future hook for stairs anim / palette mask / fade.
2. Transition immediately to `LOAD`.

`LOAD` (single-frame, atomic):

1. Call `roomrom_state_reset_for_scene_switch()` — see §"Scene-Switch Reset Contract".
2. Set scene to UW.
3. Set UW level via `roomrom_uw_room_render_set_level(dest.level)`.
4. Set UW quest via `roomrom_uw_room_render_set_quest(dest.quest)`.
5. Set room id `s_room_id = dest.room_id`.
6. Place Link at the canonical UW entrance spawn (same const as direct UW
   boot in `main.c`).
7. Upload UW CHR via `roomrom_scene_load(SCENE_UW, current_redux_flag())`.
8. Run the existing room load path (`load_room(s_room_id)` in
   `main.c`) — this already calls
   `roomrom_uw_room_render_load_palette`, fills the plane, anchors the
   slot, ticks palette, and inits door state.
9. Re-apply combat scene bias `roomrom_combat_set_uw(1)`.
10. Transition to `RESUME`.

`RESUME`:

1. `roomrom_world_transition_is_active()` returns 1 here for one more
   frame so `main.c` skips a movement tick during the same-frame switch.
2. Transition to `IDLE`.

## Scene-Switch Reset Contract

Single function `roomrom_state_reset_for_scene_switch(void)`. Closed list,
enumerated below. Adding to it requires a spec amendment.

| Field (in `RoomRom/src/main.c` unless noted) | Reset value | Reason |
|---|---|---|
| `s_doorway_dir` | `UW_WALK_DOOR_NONE` | New scene, no carried doorway |
| `s_link_grid_offset` | `0` | NES rule 2 already enforced; defensive reset |
| `s_link_pos_frac` | `0` | Sub-pixel residue from OW movement |
| `s_link_subx` | `0` | ALTTP per-axis residue |
| `s_link_suby` | `0` | ALTTP per-axis residue |
| `s_link_dir` | `LINK_DIR_NONE` | No held direction across scenes |
| `s_scroll_state` | `SCROLL_NONE` | Scroll machine must idle |
| `s_scroll_frame` | `0` | |
| `s_active_slot_x` | `0` | New room renders into slot 0 |
| `s_active_row_base` | `0` | |
| `s_transition_target` | `0` | Pending scroll target stale |
| `s_transition_row_base` | `0` | |
| `s_active_scroll_x`, `s_active_scroll_y` | `0` | |
| `s_scroll_start_x/y`, `s_scroll_target_x/y` | `0` | |
| `s_scroll_start_link_x/y` | `0` | |
| `s_transition_link_x/y` | `0` | |
| `s_link_anim_tick`, `s_link_frame` | `0` | Animation cadence restarts |
| Combat | `roomrom_combat_init()` then `roomrom_combat_set_uw(1)` | Sword cooldown / projectile state cleared |
| Plane A | `VDP_clearPlane(BG_A, TRUE)` (already done by `load_room`) | |

**Not reset** (preserved across scene switch): `s_link_keys`, `s_link_face`
(face is overwritten in step 6 of `LOAD`, not reset to a default), `s_b_item`,
`s_frame_counter`, `s_joy_prev`.

The reset function lives in `main.c` and is called only from the
coordinator's `LOAD` step. `main.c` exposes it via a small private header
(`roomrom_main_state.h`, internal to RoomRom) so the coordinator can call
it without `main.c` exporting every static.

## Direct UW Boot

Direct UW boot remains the default in slice 1 to keep direct probes alive.
Boot scene is selected by a build-time flag `ROOMROM_BOOT_SCENE` (existing
or new) — `UW` for direct probes, `OW` for the warp probe. A later slice
decides whether to keep direct UW boot as a permanent debug option or
default boot to OW `$37`.

## Deferred Work

Slice 1 intentionally does not implement:

- UW exit back to OW (`UndergroundExitType` write path,
  `UndergroundEntranceTile` consumer).
- Stairs animation, palette mask, fade, audio (`GameMode = $10` visible
  semantics; `ANIM` state runs 0 frames in slice 1).
- Level 2-9 entry (manifest extension only; no coordinator change).
- Quest 2 Level 1 entry (manifest extension; needs RoomRom quest selector).
- Cave entry (selector `>= $40` branch:
  [Z_05.asm:7344-7356](reference/aldonunez/Z_05.asm:7344)).
- Mode `$10` compatibility with the transpiled `Title.md` path.
- Save persistence of `rr_warp_save_state_t` to NV-RAM.
- Tile-mutation publish from secrets / bombed rock / burnt bush /
  pushed block into the raw-tile cache.
- Real `SaveKillCount` body (stub-only in slice 1).

## Error Handling

Unsupported selectors leave the coordinator in `IDLE`. This includes cave
selectors (`>= $40`), Level 2-9 selectors (manifest miss), and invalid
room metadata (out-of-bounds `attr_b` lookup).

If the raw-tile cache is queried out of range, it returns `0`, which
cannot satisfy the entrance tile set.

If the destination cannot be resolved, the coordinator does not modify
scene, room id, Link position, or rendering state.

## Verification — Parity Gates Per Rule D1

All gates run on **both** RoomRom.md and CombinedDebug.md per commit.

### Gate A — Build cleanliness (every commit)

1. `RoomRom\build.bat` clean.
2. `set COMBINED_DEBUG_APPROVED=1 && CombinedDebug.bat` clean.
3. `tools/combined_debug/probe_combined_debug_entry.lua` PASS at the
   PASS frame budget.
4. `python tools/combined_debug/test_combined_debug_contract.py` PASS.
5. `python tools/audit/drain_coverage.py` clean (no new orphans /
   phantoms / malformed headers).

### Gate B — Per-RAM-cell oracle (every commit; per Rule D1)

BizHawk Lua probe captures the full warp/UW state surface at the first
frame of UW gameplay post-warp under four boots:

- **Boot W-RR** — RoomRom coordinator-driven warp from OW `$37` to UW `$73`.
- **Boot D-RR** — RoomRom direct UW boot to room `$73`.
- **Boot W-CD** — CombinedDebug coordinator-driven warp from OW `$37` to UW `$73`.
- **Boot D-CD** — CombinedDebug direct UW boot to room `$73`.

Diff field set (must diff zero across all four pairwise comparisons in
the same target, AND across RoomRom↔CombinedDebug for matching boots):

- `s_room_id`, `s_link_x`, `s_link_y`, `s_link_face`
- `s_link_dir`, `s_link_grid_offset`, `s_doorway_dir`
- `roomrom_uw_room_render_get_level()`, `roomrom_uw_room_render_get_quest()`
- All `uw_door_state` bytes for room `$73`
- Link OAM (first 4 entries)
- Plane A first row (Window vs BG_A boundary check)
- CRAM PAL0 + PAL2 (UW BG palette + sprite palette; field-mapped)

Boot W-RR vs Boot D-RR = zero. Boot W-CD vs Boot D-CD = zero. Boot
W-RR vs Boot W-CD = zero (parity invariant). Boot D-RR vs Boot D-CD =
zero (existing baseline; this task must not regress it).

NES-side parity (Boot N) is **out of scope for slice 1**. Existing probes
are Genesis-only; building a NES-side capture rig is a separate ticket
logged in `phases[5].deferrals[]`.

### Gate C — Per-scenario regression (every commit)

Run on both RoomRom and CombinedDebug:

1. Direct UW boot to room `$73` → walk full Phase 5.3 door / movement
   probe loop. PASS.
2. OW boot to `$37` → walk warp probe → run the Phase 5.3 loop on the
   resulting scene. PASS, with the same diff budget.
3. OW boot to `$37`, leave Link off the entrance tile, walk one full
   N→S→E→W→N loop without crossing the entrance tile. Coordinator stays
   in `IDLE`, scene stays OW, no plane corruption.
4. Mock-manifest test exercising rule 3a (room `$22` `& 0x07`) branch
   via Gate D probe.

### Gate D — Metadata sanity unit probe (every commit, both ROMs)

Embedded-in-ROM metadata probe under build flag `ROOMROM_PROBE_METADATA=1`:

- `roomrom_ow_meta_attr_b(0x37) == 0x07`
- `roomrom_ow_meta_level_selector(0x37) == 0x04`
- `roomrom_ow_meta_is_level_selector(0x04) == 1`
- `roomrom_ow_meta_level_from_selector(0x04) == 1`
- `levelinfo_start_room_for(1, 1, &dest) == 1 && dest == 0x73`
- `levelinfo_start_room_for(2, 1, &dest) == 0` (manifest miss)
- `ROOMROM_PLAYFIELD_TOP_PX == 56`

Probe writes pass/fail bytes at fixed RAM probe address; BizHawk Lua reads.

## Acceptance Criteria

The design slice is complete when:

1. RoomRom enters Level 1 from the overworld using NES-derived room
   metadata and the warp state machine, landing in UW room `$73`.
2. No `$37` literal and no `$73` literal appear in
   `roomrom_world_transition.{c,h}`.
3. Gates A, B, C, D pass.
4. Master-plan tracker `phases[5].tasks[]` records this work as Task 5.4
   with `closed_at` set and Gate B + Gate C artifacts referenced from
   `evidence[]`.
5. Mode `$10` semantics, UW→OW exit, and tile-mutation publishing are
   recorded in `phases[5].deferrals[]` (or the equivalent project
   tracker field) so future slices know where to resume.
