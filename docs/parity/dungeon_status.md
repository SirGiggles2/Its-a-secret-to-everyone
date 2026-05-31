# Dungeon (UW) parity status — 2026-05-30

**Bar (user):** "Genesis is like the NES, very close, and better since the
hardware is different." BG byte-exact where it counts; sprites/enemies very
close; legit hardware deltas accepted. Same bar the caves met
(`docs/parity/cave_status.md`).

## Verdict (Phase 3): every Q1 dungeon room BG byte-exact NES vs Gen.

| Level | Rooms | BG-byte GATE |
|-------|-------|--------------|
| L1Q1  | 17    | 17/17 PASS   |
| L2Q1  | 18    | 18/18 PASS   |
| L3Q1  | 18    | 18/18 PASS   |
| L4Q1  | 20    | 20/20 PASS   |
| L5Q1  | 19    | 19/19 PASS   |
| L6Q1  | 19    | 19/19 PASS   |
| L7Q1  | 30    | 30/30 PASS   |
| L8Q1  | 20    | 20/20 PASS   |
| L9Q1  | 10    | 10/10 PASS   |
| **Total** | **171** | **171/171 PASS** |

GATE = `cave_byte_diff.py`: BG CRAM palette byte-exact (NES PALRAM[0..15] →
Gen CRAM[0..15] via the misc_palettes LUT) AND every NES BG play-cell has a
Gen tile at the structural offset (dy=-8, shared OW/UW/cave HUD row). 0
divergences per room.

## Tooling: `tools/parity/cave_golden/`
- `probe_nes_dungeon_golden.lua` — NES golden. NesHawk + battery SRAM boot
  (core-agnostic). Entry replicates HandleWarpOW @LoadLevel (Z_05.asm:7358):
  CurLevel + TargetMode=$02 + ObjCollidedTile=$70 + GameMode=$10 → mode 2
  loads the level CHR+LevelInfo palette+data; then per room force RoomId +
  LevelInfo_StartRoomId ($6BAD) + mode $04 (InitMode_EnterRoom) re-decode (the
  OW SRAM save resolves the level-load start room back to the save's OW room,
  so a per-room re-decode is needed). Loads the level ONCE then sweeps a ROOMS
  list. Captures OAM+PALRAM+CHR(VRAM domain)+ppuctrl+CIRAM (NCGD bundle).
- `probe_gen_dungeon_golden.lua` — Gen golden (genplus). Probe-warp ctrl
  ($FF73F8 ARM 'R'/'P' + dest scene/level/quest/room + $5A → roomrom_main_
  apply_warp_outcome, the same load path the live coordinator uses). Sweeps a
  ROOMS list, one warp per room. Full VRAM+CRAM+68K RAM+VSRAM (GCGD bundle).
- `run_dungeon_sweep.py LEVEL QUEST` — reads the manifest room list, captures
  both platforms (NES one launch loads the level once + re-decodes each room;
  Gen one launch warps each room), byte-diffs every room, prints a table.

## Notes / accepted deltas (same as caves)
- Color model (NesHawk vs genplus RGB), HUD row (Gen playfield 1 tile-row
  above NES) — accepted, byte data is NES-identical.
- Sweep launch flakiness: rapid back-to-back EmuHawk relaunch in one batch
  loop produced spurious NO-GEN/NO-NES (a launch occasionally didn't capture).
  Per-level standalone re-runs are deterministic; add a settle delay + a
  pre-launch taskkill between levels when batching. NOT a parity bug — every
  level passes 100% when run cleanly.

## NOT yet done (Phase 4-7)
- **Enemies (Phase 4):** Gen dungeon rooms render BG correct but spawn ZERO
  enemies (NES rooms are populated). Root-cause candidate: enemy_room_load_
  objects (obj_lists.c:226) returns 0 when LevelInfo_FoeCounts==0 / template
  ==0 — UW level-info install (FoeCounts + LBA C/D) must run on warp entry.
  Probe live FoeCounts/$034D/ObjType[1..] after a dungeon warp before any fix.
- Bosses (Phase 5), UW→OW exit round-trip (Phase 6), Q2 (Phase 7).
