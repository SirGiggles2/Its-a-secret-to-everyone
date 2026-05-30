# Phase 8 — Boss Ground Truth (RED baseline)

_Generated 2026-05-30. Genesis capture only; NES mirror pending (see Open
Questions). Per RULE V1 the pass/fail verdicts here are byte/cell-derived;
screenshots are FAIL-triage only._

Probe: `tools/parity/probe_gen_boss_direct.lua` (direct PROBE_CTRL warp +
debug boss-CHR kick). Captures: `C:\tmp\gen_boss_direct/<boss>/` —
`m68k_ram.bin` (full 64 KB), `vram_full.bin` (full 64 KB), `sat.bin`,
`cram.*`, `boss_chr.bin`, `plane_a.bin`, `screen.png`, `state.txt`.

ROM: `builds/Debug.md` rebuilt this session (clean, exit 0). BizHawk core
domain = **`M68K BUS`** (no `68K RAM` domain on this GPGX-Waterbox build),
base `$FF0000`. SAT = `$F400` (`main.c:638`), planeA `$C000`, boss CHR
tile 659 → VRAM `$5260`.

---

## CRITICAL address-model correction (supersedes the plan's cell map)

The NES RAM mirror is a C array `nes_ram[]` at **A4 = `$00FF8000`**
(`src/abi/platform_abi.h:10`, `:59 #define RAM(off) nes_ram[off]`;
`docs/audit/enemy_parity/probe_address_model.md`). NES cell `$XXXX` lives
at `$FF8000 + $XXXX`.

- The plan (and the old probe) read NES cells at raw `$XXXX` (= `$FF0000+`
  in `M68K BUS`), which is C `.data/.bss` → **static garbage** (`$26/$D8…`
  identical across all rooms, including the invalid L1). That single bug
  invalidated every earlier "bosses broken / $6BBC garbage" conclusion.
- Correct reads (verified): `ObjType $034F+s → $834F+s`, `X $0070`,
  `Y $0084`, `Dir $008C` (NOT `$0098`), `HP $0485` (NOT `$04B8` — that
  aliases `ATTR $04BF`), `Room $80EB`, `Level $8010`, `GameMode $8012`.
- The debug ctrl block (`$FF73F8`) and state mirror (`$FF7200`) are
  **absolute**, NOT in `nes_ram` — read directly. (This is why the mirror
  worked while raw cells didn't.)
- `$6Bxx` (BossRoomId/StartRoomId, NES SRAM `$6000+`) mapping past the
  13-bit bank is **unverified**; Phase 4 re-derives the SRAM layout.

---

## What WORKS (confirmed by cells/VRAM)

1. **Direct warp** sets `GameMode=$05` (Play), correct `Level` + `Room`
   for 9/10 (mirror `$FF7200` off4/off5 + `nes_ram` `$8010/$80EB` agree).
   The plan's "we have never captured a real boss room" is resolved — we
   are in the rooms.
2. **Boss-CHR DMA machine** works: `boss_kick_fired=true` all 10;
   `boss_chr` window `$5260` is ~1394–1459/2048 nonzero. The debug kick
   (flag `0x04` + scene_id at `$FF73FE`) drives `level_chr_boss_request`
   → `level_chr_boss_tick` → VRAM. Confirms Phase 2's premise: the
   machine is sound; it is simply never *requested* on real scene-load.
3. **HUD + Link sprite** render (SAT `$F400` has Link + HUD-icon entries).

## What's BROKEN (the real blockers — surfaced loud per RULE ND-1)

### BLOCKER A — dungeon room BG does not render (black playfield)
All valid-room screenshots show HUD + Link but a **black playfield**;
`plane_a` is only ~350–365/4096 nonzero (≈ HUD tilemap only). `load_room`
*does* call `render_room_into_slot` (`main.c:687`), yet nothing room-shaped
reaches the screen. Root cause unknown — candidate: the PROBE_CTRL warp
(`roomrom_main_apply_warp_outcome`) sets state + CHR but the BG fill
target/slot/scroll is wrong under warp, OR room tile data isn't loaded.
NOT yet a guess-fix — needs `/chuckle` (compare warp-render of a NORMAL UW
room vs boss room; inspect full `vram_full.bin` nametable planes).

### BLOCKER B — boss/enemy room-spawn result is wrong-or-unverifiable
`enemy_loop_room_init` is NOT a stub (the `main.c:857` comment is stale —
7.7 landed): it calls `enemy_room_load_objects` → `enemy_assign_spawn_
positions` → `enemy_init_fns` → `boss_framework_room_init`
(`enemy_loop.c:1200-1210`). Re-sliced real slots (`$834F+s`):

| Boss | L | Room | warp | slots populated | ObjType seen | expected boss type |
|---|---|---|---|---|---|---|
| aquamentus   | 1 | $35 | **FAILED→OW $77** | none | — | $3D |
| dodongo      | 2 | $73 | ok | **none** | — | $31 |
| manhandla    | 3 | $0F | ok | s1-11 | all `$28` | $3C |
| gleeok_2head | 4 | $45 | ok | s1-11 | all `$27` | $43 |
| digdogger    | 5 | $06 | ok | **none** | — | $38 |
| gohma_red    | 6 | $0F | ok | s1-11 | all `$28` | $33 |
| aquamentus_2 | 7 | $23 | ok | **none** | — | $3D |
| gleeok_4head | 8 | $1F | ok | s1-11 | `$16/$0C/$0B/$2B/$27` | $45 |
| patra_red    | 9 | $1E | ok | **none** | — | $47 |
| ganon        | 9 | $1F | ok | s1-11 | `$16/$0C/$0B/$2B/$27` | $3E |

- 4 rooms spawn **nothing**; 5 spawn slots whose ObjType does **not**
  match the expected boss obj_type. Whether the populated slots are
  correct-but-misinterpreted or a genuinely wrong spawn **cannot be
  concluded without the NES capture** (RULE ZERO). This is precisely why
  Phase 1 requires the NES mirror.
- L8/L9 share types ($16/$0C/$0B/$2B/$27) and room $1F (gleeok4 & ganon
  are the same room id at different quests) — consistent with reading the
  same loaded room.

### BLOCKER C (confirmed, lower priority) — boss CHR not requested on real entry
`level_chr_boss_request` is only called under the debug flag
(`main.c:1883`); the real scene-load path (`scene_load.c`) never requests
it. Moot until A+B yield a visible, spawned boss, but it is the Phase 2
one-liner.

## Probe robustness fixes applied this session
- NES cells now read at `$8000+addr`; Dir `$008C`; HP `$0485`.
- Warp verify-retry (≤3) — fixes the first-warp-too-early L1 OW landing.
- Cold-start hygiene (clear flags/trigger before arm); fail-loud `io.open`.
- Control-byte collision (warp `ctrl[6]/[7]` vs boss-trigger `$FF73FE/FF`)
  handled by toggling flag `0x04` per boss — hand-verified race-free
  against `main.c:1883/2945/2956` (the `/octo:review` multi-LLM fleet
  crashed; octo-code-reviewer agent fabricated its review — both discarded
  per RULE V2 fallback; verified by hand against source).

---

## Open questions (resolved only by the NES mirror + render trace)
1. NES capture of all 10 rooms (`probe_nes_boss_direct.lua`, NES warp via
   `$0010`/`$00EB`/`$0012` poke per `probe_nes_known_bosses.lua`): what
   ObjType/X/Y/HP does each boss room actually spawn? Byte-diff vs the
   re-sliced Genesis slots → settles BLOCKER B.
2. BLOCKER A root cause: does a NORMAL UW room render via the same warp?
   (Disambiguates warp-path bug vs boss-room-specific vs methodology.)
3. Is the boss CHR at `$5260` the CORRECT tiles (vs NES boss CHR-RAM)?
   (Phase 3 — only matters once a boss spawns + renders.)

## Corrected phase order (supersedes plan Phases 2-4)
- **P1.5 (next):** NES mirror capture + slot byte-diff → resolve B.
  Investigate BLOCKER A via `/chuckle` (warp render of normal vs boss room).
- **P2:** still wire `level_chr_boss_request` into `scene_load.c` (BLOCKER C).
- **P3+:** per-boss AI only after A+B+C give a visible, spawned, correct boss.

---

## UPDATE — Phase 1.5 root-causes (2026-05-30, same session)

Deeper investigation resolved A and exposed a foundational data error.

### BLOCKER A — root-caused + partial fix landed
Two causes (both real):
1. **Quest-index bug (FIXED).** The UW room blob `g_uw_room_lookup` is
   indexed under **quest 1** (quest-0 table is empty: 0 rooms; quest-1 =
   171 first-quest rooms; quest-2 = 147 second-quest). The PROBE_CTRL warp
   set `s_uw_quest=0` via `roomrom_uw_room_render_set_quest(dest_quest=0)`
   while `level_info_install_uw` normalizes 0→1 — inconsistent. So
   `find_blob_entry` looked up quest 0 → always −1 → `fill_one_col_at`
   (`uw_render.c:578`) took the non-blob branch → **wrote no tiles** →
   black playfield. Fix: `main.c` `apply_warp_outcome` now normalizes the
   render quest to match (0→1). Rebuilds clean (exit 0).
2. **Wrong boss room IDs (see below).** Even with the quest fixed, 8/10
   boss rooms in `boss_room_ids.md` are absent from the blob → still black
   until the IDs are corrected.

(OW warps always rendered because `roomrom_ow_room_render_fill_plane_a`
re-fills every frame and OW room IDs are valid; UW has no per-frame
re-fill, so a missed blob entry stays blank.)

### `boss_room_ids.md` is WRONG (8/10) — prior-session RULE-ZERO miss
The blob's real per-level room IDs are tight clusters; the doc's boss IDs
match only **L1 $35** and **L8 $1F**. The other 8 ($73/$0F/$45/$06/$0F/
$23/$1E/$1F) are not rooms in their dungeons at all (e.g. L2 lives in cols
C–F, so $73 cannot be Dodongo). Both probes + `diff_boss.py BOSS_TABLE`
inherited these bad IDs → 8/10 captures hit non-rooms (black + empty
slots). **Correct IDs must be re-derived from NES data.**

### NES object-placement spec decoded (RULE D1) — the ID + spawn oracle
`Z_05.asm @PlaceObjects` (1700-1811): per room,
`monster_list_id = (LevelBlockAttrsC[room]&0x3F) | (LevelBlockAttrsD[room]&0x80 ? 0x40:0)`.
- list_id in `[$32,$62)` ⇒ count forced to 1, ObjType = list_id (a boss /
  unique object). list_id `[1,$32)` ⇒ all `count` slots = list_id
  (repeated enemy). list_id `>=$62` ⇒ list of distinct types from
  `ObjListAddrs[(id-$62)*2]` → `ObjLists.dat`.
- **Boss room = the room whose `monster_list_id` equals the boss
  ObjType.** This is the authoritative source for BOTH the correct room
  IDs and the expected spawn (BLOCKER B oracle).

LevelBlockAttrs is **shared-block, NOT per-level**: `level_info_install_uw`
installs block 0 for L1-L6 Q1, block 1 for L7-L9 Q1 (Z1 dungeon rooms
share a 128-room map; each level occupies a disjoint region). C=`$697E`,
D=`$69FE` (`Variables.inc:324-329`). NES SRAM `$6xxx` mapping into the
Genesis `nes_ram` mirror is NOT simply `$8000+addr` (reads past the 13-bit
bank) — decode boss IDs from the **static** `data/rooms/dungeons.c`
(`rooms_dungeons[]`, the LBA source) instead, via the offsets in
`level_info_install.c:94-119`.

### Next (corrected)
1. Decode `rooms_dungeons[]` LBA blocks (offset 0 = L1-L6, 768 = L7-L9) →
   correct boss room ID per level + expected ObjType. Ground boss ObjType
   values against the NES update-fn dispatch (not the suspect table).
2. Fix `boss_room_ids.md`, both probes, `diff_boss.py BOSS_TABLE`.
3. Re-capture (quest fix already in) → confirm boss rooms render + spawn.
4. Then BLOCKER C (boss CHR request gated on boss-room) → per-boss AI.
