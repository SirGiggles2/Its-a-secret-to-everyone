# Plan — Dungeon (Underworld) NES parity, byte-verified

**Goal:** Every dungeon room renders like NES (BG byte-exact, sprites/enemies/
bosses very close, Genesis-native), the same bar the caves met (20/20 BG
byte-exact, `docs/parity/cave_status.md`). 9 levels × 2 quests, ~hundreds of
rooms, 9 bosses.

**Method (proven on caves):** probe NES live + Gen live → byte-diff BG (CRAM +
nametable) + rendered-frame shape gate → fix each divergence → sweep. RULE
ZERO (probe first), RULE V1 (verdict = byte/pixel diff, never screenshots),
RULE V2 (review every `.lua`), WT-5 (no new `RoomRom/src` files; code in
`src/game/`, tools in `tools/`).

## What already exists (reuse, do NOT rebuild)
- **Cave byte pipeline** — `tools/parity/cave_golden/`: `probe_gen_*`,
  `probe_nes_*` (NesHawk + SRAM boot, core-agnostic), `cave_byte_diff.py`
  (CRAM byte-exact + BG structure), `pixel_diff.py` (per-channel shape gate,
  absorbs the ~49-91/ch NesHawk-vs-genplus color-model curve), `run_*_sweep`,
  `run_full_diff.py`, `aggregate_invariant.py`. `probe_gen_dungeon_golden.lua`
  (foundation, UW-targeted) already written.
- **Phase A-F dungeon dispatch** (verified synthetic): `cave_entrance_check`
  (`src/game/cave/cave_entrance.c`), `level_info_install_uw(level,quest)`
  (Q2 attr-B replacements), `roomrom_uw_room_render_*`,
  `levelinfo_start_room_for(level,quest,*)`, warp coordinator
  `src/game/world/transition.c` (`detect_warp_uw_to_ow`,
  `set_latched_source_for_probe`), manifests
  `RoomRom/data/uw_level{N}_quest{Q}_rooms.json` (18 files),
  `tools/parity/warp_routes_expected.json` (128-room OW→dest oracle).
- **NES authority:** `reference/aldonunez/Z_02.asm` (UW objects/persons),
  `Z_05.asm`/`Z_06.asm` (mode transitions, room load, Q2 PatchQ2Rooms
  237-267), `reference/aldonunez/dat/*.dat` (UW CHR/room/level data).

## Known blocker (found 2026-05-29, byte-proven)
**Live OW→dungeon entry is NOT wired.** OW gate `RoomRom/src/main.c:2099`
only dispatches caves (`cave_entrance_check`→`cave_fade_begin_enter`); a
dungeon entrance returns 0 (selector<$40) and nothing fires — scene stays OW.
Phase F verified only the synthetic dispatch. Everything below is blocked on
Phase 1.

---

## Phase 1 — Wire live OW→dungeon entry (0.5-1 day) [UNBLOCKS ALL]

**Deliverable.** Walking Link onto a dungeon entrance tile on Genesis loads
the correct UW level + start room, byte-matching the NES dungeon-load.

**Files (edit):**
- `RoomRom/src/main.c:2099` — after `cave_entrance_check` returns 0 AND the
  OW room's attr-B selector `< $40`, dispatch dungeon entry (sanctioned
  one-block hook per WT-5):
  - `level = (roomrom_ow_meta_attr_b(room_id) & 0xFC) >> 2`.
  - `level_info_install_uw(level, roomrom_main_current_quest())`.
  - `levelinfo_start_room_for(level, quest, &start_room)`.
  - latch `s_save.source_{room,link_x,link_y,face,tile}` (the return-exit
    reads them, Phase C).
  - transition to `SCENE_UW`, set `roomrom_uw_room_render_set_level/quest`,
    fill + palette the start room, spawn Link at the UW entrance (NES
    InitMode4 spawn pos).
- New `src/game/world/dungeon_entry.c/.h` for the entry sequence (keep
  main.c hook to one call). NES authority: `Z_05.asm` InitMode4 /
  EnterRoom + `Z_06.asm` level load.

**Probe (before code):** `tools/probes/probe_nes_dungeon_enter.lua` — NES,
walk into L1 from OW $37; dump GameMode/RoomId/CurLevel/LinkX/Y at the
transition + at settle. Confirms the NES entry sequence + spawn pos.

**Verify:** `probe_gen_dungeon_golden.lua` (prelude `C:\tmp\gen_dungeon_L1Q1.lua`,
OW $37) → scene reaches UW(1), room $73, captures. NES golden via the
adapted dungeon NES probe → byte-diff the start-room BG.

**Gate:** Gen enters L1 → room $73; `s_save.source_*` latched for the exit.

---

## Phase 2 — Dungeon golden capture pipeline (0.5 day)

**Deliverable.** NES + Gen golden capture for any (level, quest, room).

**Files:**
- Finish `probe_gen_dungeon_golden.lua` (foundation done) — drop the stale
  `$8041` roomid log, target UW, capture frames {0,8,16,24,60,120}.
- New `probe_nes_dungeon_golden.lua` — clone `probe_nes_cave_golden.lua`;
  enter the dungeon (NES InitMode4 fake or real OW walk), assert
  `CurLevel==level && RoomId==room`, capture OAM+PALRAM+CHR+CIRAM.
- New `run_dungeon_sweep_{gen,nes}.py` — drive every room in a level's
  manifest (`uw_level{N}_quest{Q}_rooms.json`).
- Reuse `cave_byte_diff.py` (CRAM + BG structure) + `pixel_diff.py` as-is;
  add a dungeon offset constant if the UW HUD row differs from the cave/OW.

**Gate:** L1 start room ($73) NES + Gen goldens captured; differ runs.

---

## Phase 3 — Per-level BG byte sweep, L1-L9 Q1 (2-4 days)

**Deliverable.** Every reachable room in each Q1 level: BG CRAM byte-exact +
nametable structure vs NES.

- Walk each level's room set (manifest), capture both platforms, byte-diff.
- Triage each FAIL: wall tile, door tile, sub-pal, item-block, water/lava.
  Fix the narrowest correct site (renderer in `src/game/dungeon/uw_render.c`;
  data regen via the blob-gen tool, allowed under WT-5).
- NES authority per tile: `Z_06.asm` room layout + `dat/*.dat`.

**Gate:** per-level table, BG-byte PASS N/N, like the cave `run_full_diff.py`.
Expect the same accepted hardware deltas (color model + HUD row).

---

## Phase 4 — Dungeon enemies (3-5 days)

**Deliverable.** Each dungeon enemy family renders + animates like NES
(sprite tile + count + cadence; pixel-diff ≤ tol).

- Reuse the `enemy_fix` skill workflow + `enemy_loop` dispatch. Drain-primary
  (`src/oracle/enemies/*`), NES asm secondary (`Z_07.asm`).
- Per family: probe NES OAM vs Gen SAT (link-chain displayed sprites, the
  cave lesson), byte-diff tiles + positions, fix dispatch/CHR.
- Families: Keese, Gel/Zol, Rope, Stalfos, Goriya, Darknut, Wizzrobe,
  Wallmaster, Like-Like, Vire, Bubble, Gibdo, Pols Voice, Lanmola, Moldorm,
  Zora, traps (statues/fireballs).

**Gate:** per-family OAM/SAT byte-diff + pixel-diff PASS.

---

## Phase 5 — Bosses (4-7 days, high risk)

**Deliverable.** All 9 bosses render + animate + fight like NES.
Aquamentus(L1/L8), Dodongo(L2), Manhandla(L3), Gleeok(L4), Digdogger(L5),
Gohma(L6), Patra(L7), Ganon(L9). Many are stubs (`enemy_dispatch.c:135`,
`enemy_ganon_bridge.c:6`).

- Per boss: state-machine port from `Z_04.asm` to `src/game/enemies/bosses/`.
  Per-state probe-side state write (skip combat), capture each state, byte-
  diff OAM + CHR (`data/chr/bosses.c` atlas, verify `MANIFEST.json` mapping).

**Gate:** per-boss per-state OAM/CHR byte-diff PASS.

---

## Phase 6 — UW→OW exit + round-trip (1 day)

**Deliverable.** Exiting a dungeon returns Link to the exact NES OW landing
tile, every level. (Phase C `detect_warp_uw_to_ow` exists; wire it live like
Phase 1 wires entry.)

- Hook the live UW exit at the stair/entrance tile → `detect_warp_uw_to_ow`
  → SCENE_OW at `s_save.source_*`.
- Verify: probe round-trip OW→UW→OW, `dest_link_x/y` byte-exact (18 tuples).

**Gate:** 18/18 round-trips land byte-exact.

---

## Phase 7 — Q2 (1-2 days)

**Deliverable.** Q2 levels verified. Q2 swaps room layouts + contents via
`PatchQ2Rooms` (`Z_06.asm:237-267`).

- Confirm `level_info_install_uw(level, 2)` applies the Q2 attr-B
  replacements (Phase B blind spot — the patch must run before capture).
- Re-sweep the Q2-divergent rooms (BG + enemies + bosses).

**Gate:** Q2 per-level BG-byte PASS; Q2 attr-B confirmed applied (not silently
== Q1).

---

## Sequencing / effort

| Phase | Days | Blocker |
|-------|------|---------|
| 1 Live entry | 0.5-1 | none (unblocks all) |
| 2 Capture pipeline | 0.5 | 1 |
| 3 BG sweep Q1 | 2-4 | 2 |
| 4 Enemies | 3-5 | 2 |
| 5 Bosses | 4-7 | 2 |
| 6 Exit/round-trip | 1 | 1 |
| 7 Q2 | 1-2 | 3,4,5 |
| **Total** | **~12-20** | (dungeons ≈ the whole cave effort, ×N rooms) |

Commit per phase. Tag `dungeons-bg-byte-exact-2026-MM-DD` after Phase 3,
`dungeons-parity-2026-MM-DD` after Phase 7.

## Verification (end-to-end)
```
Debug.bat
python tools/parity/cave_golden/run_dungeon_sweep_gen.py   # all levels, Gen
python tools/parity/cave_golden/run_dungeon_sweep_nes.py   # all levels, NES (NesHawk)
python tools/parity/cave_golden/run_full_diff.py --dungeon # BG-byte table
```
PASS = every reachable room BG-byte gate green + enemies/bosses pixel-diff ≤
tol + 18/18 round-trips byte-exact. RULE V1: verdict from byte/pixel diff.
