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

## Phase 4 (Q1 enemy DATA): byte-exact NES — DONE
Gen dungeon rooms rendered BG-correct but spawned wrong enemies (e.g. L1 $63
= $2A x11; NES = $2D $2D $2C $23 $24 $23 $24, 7). Root cause: the reference
dat/LevelBlock*.dat + dat/LevelInfo*.dat do NOT match what NES loads into
SRAM (NES load transform; byte-proven dat LBA_C[$63]=$2A vs live $FD,
FoeCounts dat[32] vs SRAM $6BA2/[36]). rooms_dungeons[] was built 1:1 from
those dats → wrong LBA C/D (templates) + FoeCounts (counts).
Fix: regenerate from LIVE NES SRAM (probe_nes_dump_levelsram.lua dumps
$687E..$6C7D per level; regen_dungeon_blob_from_sram.py overrides the Q1
LevelBlocks UW1/UW2 + 9 LevelInfo slots). uw_collision regenerated (derives
from LBA), sentinel refreshed.
- **Verified (byte-diff):** Gen runtime SRAM == NES live SRAM for L1 (UW1) +
  L7 (UW2), 0 diffs excl. the probe-clobbered StartRoomId. $63 ObjType +
  FoeCounts byte-exact; enemies render on-screen. BG sweep $73/$63 still PASS.
- ⇒ every Q1 room (L1-L9) now loads NES-exact enemy templates + counts.

## Q2 dungeon interiors: quest-independent — covered by the Q1 fix
NES PatchQ2Rooms (Z_06.asm:237) patches only OVERWORLD LevelBlockAttrsB
(cave/dungeon routing) — NOT underworld room contents. Byte-proven: live NES
UW SRAM L*Q1 == L*Q2 (LevelBlock + LevelInfo, 0 diffs). The regen writes the
live UW1/UW2 images into ALL FOUR blob blocks (UW1Q1/UW2Q1/UW1Q2/UW2Q2) and
the install's LevelInfo slot is quest-independent (correct). Verified: Gen
L1Q2 $63 ObjType=$2D $2D $2C $23 $24 $23 $24 (== Q1, == NES). No per-quest
LevelInfo needed. ⇒ dungeon enemy DATA byte-exact for BOTH quests.

## NOT yet done
- **Enemy render/animation per-family (Phase 4 deeper):** sprite tile + flip
  + animation cadence per family vs NES OAM (spawn data is right; per-family
  rendering not yet byte-diffed). Needs a CLEAN NES per-room enemy capture —
  the golden mode-4 forced entry leaves garbage OAM (sprites not ticked), so a
  proper gameplay-entry NES capture is required for the OAM/SAT byte-diff.
- **Bosses (Phase 5)** — boss rooms render (BG byte-exact) + their regular
  monsters spawn correctly. The boss ENTITY does not appear. Findings:
  - `LevelInfo_BossRoomId` ($6BBC) drives only boss AMBIENT SOUND (Z_05.asm:
    4098), NOT the spawn — so the boss spawns via the room monster list.
  - A boss-render path already exists (commit 5e23443b "boss VISIBLE via
    OAM-shadow flush"), keyed off boss ObjType ranges $31-$3E/$41-$48
    (`request_boss_chr_if_boss_room`, main.c:784).
  - PINNED: L1 boss room = **$36** (LBA_C=$3C -> template $3C, boss range).
    Gen $36 seats ObjType[1]=$3C (count-1 boss override) AND renders a boss
    (boss CHR + OAM-flush fire) — but as TWO grey blobs flanking Link, NOT the
    green Aquamentus dragon. So the boss SPAWN works; the boss DRAW is wrong
    (CHR atlas tiles / palette / multi-part layout / state machine). That is
    the Phase 5 work, per-boss x9.
  - MANIFEST BUG: `uw_level1_quest1_rooms.json` mislabels $35 as "boss"
    (really Goriyas) and $36 as "triforce" (really Aquamentus). The room_tags
    boss/triforce are swapped/wrong — fix the manifest generator's boss/
    triforce derivation (it likely used the clobbered/raw BossRoomId).
- **UW→OW exit round-trip live-wire (Phase 6).**
