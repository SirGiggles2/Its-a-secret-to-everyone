# Phase A-D close report — wire every cave + dungeon entrance perfectly

**Date:** 2026-05-24
**Plan:** `~/.claude/plans/i-want-every-cave-idempotent-hare.md`
**Scope:** caves (entry/interior/exit) + dungeons (entry/exit) for Q1+Q2
**Status:** code changes A through D landed; runtime sweeps E + F pending
harness work.

## Commits (this session)

| Phase | SHA | Title |
|-------|----------|-------|
| A | `168a62a1` | cave_entrance: NES-aligned LBA_B dispatch |
| B | `f8191655` | warp: L2-L9 + Q2 dungeon manifest + quest selector |
| C | `6fd48e02` | transition: UW→OW dungeon exit + UET state machine |
| D4 | `8f46ab11` | cave: wire BCD price formatter |
| D3 | `455ac37b` | cave: textbox char-streamer uses pointer-array PersonTextAddrs |

D1 (bonfire StandingFire SAT) + D2 (cave_draw_person full publish)
landed in pre-session commits (`6c4c1b63`, `c4fbb2f3`, `ad8bcf21`,
`7b9ca8e8`, `4c416831`).

## What was code-fixed

### Phase A — OW→cave/dungeon routing

- Tier 0 `cave_entrance_check(tile)` hardcoded `cave_id = 0x6A` for all
  128 OW rooms (127 wrong by inspection).
- Replaced with `cave_entrance_check(tile, room_id)` that reads
  `roomrom_ow_meta_level_selector(room_id)` and dispatches per NES
  `HandleWarpOW` (Z_05.asm:7338-7368): selector < $40 returns 0 (let
  `detect_warp_ow` handle dungeon), selector >= $40 returns
  `$6A + ((selector - $40) >> 2)` (20 cave_ids $6A..$7D).
- Oracle: `tools/parity/warp_routes_expected.json` — 128 rows
  generated from byte-extracted `reference/aldonunez/dat/LevelBlockOW.dat`.
  Summary: no_warp=36, dungeon=14, cave_regular=74, cave_shortcut=4.

### Phase B — L2-L9 + Q2 dungeon manifest

- `tools/levelinfo_start_rooms_gen.py` `SLICE_1_ENABLED` flipped from
  `[(1,1)]` to all 18 `(level, quest)` tuples.
- All 18 `RoomRom/data/uw_level{N}_quest{Q}_rooms.json` manifests
  verified populated with valid `start_room_id` fields.
- Master quest-selector state: `s_current_quest = 1u` in
  `RoomRom/src/main.c` + getter `roomrom_main_current_quest()` +
  setter `roomrom_main_set_quest(q)` (bounds-checked to {1, 2}).
- `transition.c` `detect_warp_ow` rule 7 manifest lookup + save state
  + outcome `dest_quest` all sourced from the getter instead of
  hardcoded `1u`.

### Phase C — UW→OW dungeon exit + UndergroundExitType state machine

- `rr_warp_save_state_t` extended with `dest_scene` + `dest_link_x` +
  `dest_link_y` so `LOAD` step is scene-agnostic (was hardcoded UW +
  `UW_SPAWN_X/Y`).
- New `detect_warp_uw_to_ow` arm in `transition.c`: fires when
  scene=UW, level > 0, `source_room == levelinfo_start_room_for`,
  `raw_tile` in $70..$73, save state has latched source. Routes
  outcome to OW with `dest_link_x/y = source_link_x/y` (pixel-exact
  return to OW entrance tile).
- `LOAD` step now reads `outcome` from save state generically.
- New `roomrom_main_set_underground_exit_type(u8)` setter.
  `apply_warp_outcome` stamps UET per dest_scene: UW=2, CAVE=1, OW=1
  (block re-trigger on entrance tile post-exit).
- New `ow_step_uet_clear()` helper in `transition.c` tick path: tracks
  `s_prev_grid_offset` across frames, clears UET when in OW scene and
  grid offset rolls non-zero → 0 (NES Z_07.asm:3170-3201).

### Phase D — cave interior perfection

- D1 (bonfire SAT) — substrate landed pre-session: bonfire slot 2/3
  alive flags set (`c4fbb2f3`), ENEMY_THROWER_SLOT wired before
  `cave_draw_person` (`ad8bcf21`), bonfires cleared on cave_exit
  (`6c4c1b63`). enemy_loop dispatch table maps `$40 StandingFire` to
  `enrt_update_standing_fire` (full drain at
  `src/oracle/enemies/enemy_walker_runtime.c:146`).
- D2 (cave_draw_person SAT publish) — full publish at
  `src/game/cave/cave_dispatch.c:670-686` (`sprite_anim_fetch_obj_pos`
  + `draw_object_mirrored` / `draw_object_not_mirrored`).
- D3 (textbox states 1/3/6/7) — `cave_update_person_state_textbox`
  reworked to dereference Genesis's pointer-array `PersonTextAddrs`
  directly instead of reading NES-style (lo, hi) byte pairs. Selector
  semantics preserved (still byte-pair offset); divide by 2 indexes
  the 38-entry pointer array.
- D4 (BCD price formatter) — `cave_update_transfer_prices` arm 0 was
  a TODO stub; wired to call existing
  `cave_write_prices_transfer_buf()` (5-line fix).
- Also: bumped `CAVE_ID_MAX` from $7C → $7D to accommodate the 20th
  derivable cave_id from `attr_b_fc = $8C` (no runtime ROM use yet
  confirmed; tracked under Phase E sweep).

## Build state

Last build: `Debug.bat` green. ROM size 2.0 MB. All five session
commits landed cleanly on top of pre-existing WIP cave-fade work.

## Phase E + F status (Phase E partial)

Phase E (per-cave sweep, 19+1=20 caves × Q1+Q2 layouts) and Phase F
(per-dungeon round-trip, 18 entrances) require automated runtime
verification. Phase E infrastructure landed (`42fdb219`):

- `src/game/cave/probes/warp_routes_probe.{c,h}` — in-ROM probe at
  $FF7C00 publishing 128-room dispatch results.
- `tools/debug/probes/probe_warp_routes.lua` — BizHawk reader with
  scripted A+B+C chord to advance past title; auto-exits.
- `tools/parity/diff_warp_routes.py` — byte-diff vs oracle JSON,
  generates `tools/parity/warp_routes_sweep_report.md`.

**Partial result:** probe reached rooms $00..$15 (22 of 128
iterations) — ALL MATCH ORACLE byte-for-byte. Direct blob read XOR
ow_meta read = 0 (the dispatch is correct end-to-end for the path
that runs to completion). Rooms $16+ retain $AA prefill sentinel,
indicating the in-ROM loop terminates early.

**Suspected cause:** VBlank interrupt or other early-boot interruption
clobbers the loop state. Boot-time probes that work (options/enemy)
are smaller; the 128-iteration loop exceeds whatever threshold the
boot context allows. Investigation deferred. Next-session candidates:

1. Disable interrupts during probe loop (`SYS_setInterruptMaskLevel`).
2. Chunk into 16-room batches across multiple frames.
3. Move the probe call later in `main.c` after the gameplay tick
   stabilizes (post-debug-enter, mid-game).

The blockers for an automated sweep:

1. **No scripted joypad chord.** Existing `tools/probes/probe_cave_fade_gen.lua`
   requires user-driven A+B+C at title to enter debug gameplay, then
   walk Link onto an entrance tile. Auto-sweep needs `joypad.set`
   sequencing in the probe Lua.

2. **No per-cave / per-dungeon savestate manifest.** Each warp scenario
   would either need a pre-captured BizHawk savestate placing Link on
   the relevant entrance tile, OR an in-ROM teleport chord that
   accepts a (level, quest, room) tuple and snaps Link there.

3. **No NES-side reference capture.** Per Rule Zero / CLAUDE.md, every
   parity oracle row needs a live-NES capture for byte-diff. The
   static dispatch table from `LevelBlockOW.dat` covers Phase A
   routing, but per-cave OAM / nametable / palette / char-stream
   captures from NES Zelda 1 don't exist yet.

## Recommended next-session path

1. **Build the unified warp harness scaffolding**
   (`tools/parity/warp_harness/`) per plan §"Unified harness":
   `run_warp_sweep.py` + `probe_warp_full.lua` (NES + Gen) + a
   `warp_savestates/` directory.
2. **Capture NES baselines** for all 19 caves + 18 dungeon entries +
   18 dungeon exits via BizHawk Lua with scripted joypad sequences.
3. **Capture Gen captures** for the same scenarios against the
   current Phase A-D Debug.md.
4. **Run the sweep + diff** to surface any per-cave / per-dungeon
   regressions. Likely candidates from the code-side review:
   - Whether `cave_id $7D` is actually reachable in NES gameplay
     (formula gives 20 cave_ids; inventory said only 19 — Phase E
     resolves which is real).
   - Whether `detect_warp_uw_to_ow` fires correctly on the dungeon
     entrance stair in L1Q1 (the only path actively tested).
   - Whether `dest_link_x/y` from the latched save state matches NES
     `ObjX/Y` byte-for-byte on dungeon exit (per-pixel guarantee in
     the plan's verification section).
5. **Q2 layout differences.** NES Z1 second-quest OW has the SAME
   geometry but `LevelBlockAttrsBQ2ReplacementOffsets` / `Values`
   override entries (per Z_06.asm:242-244). Phase E + F need to
   verify the overrides land correctly when `current_quest == 2`.

## Files touched this session (code)

- `src/game/cave/cave_entrance.c` + `.h`
- `src/game/cave/cave_dispatch.c` (D3 + D4 + CAVE_ID_MAX)
- `src/game/world/ow_meta.c` + `.h`
- `src/game/world/transition.c` + `.h`
- `RoomRom/src/main.c` (caller patch + quest accessor + UET setter +
  UET set in apply_warp_outcome)
- `RoomRom/src/roomrom_main_state.h` (quest + UET prototypes)
- `RoomRom/data/levelinfo_start_rooms.c` + `.h` (regen 1 → 18 rows)
- `tools/levelinfo_start_rooms_gen.py` (SLICE_1_ENABLED expansion)
- `tools/parity/nes_warp_dispatch_dump.py` (new oracle generator)
- `tools/parity/warp_routes_expected.json` (new oracle)
- `build/probes/phaseA/nes_attr_b_dump.txt` (human-readable table)
