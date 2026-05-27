# Round 1 — Pragmatic Implementer (Sonnet)

**Current score: 15/56 PASS** (sweep_report.md, 2026-05-26).
**Fail breakdown: 40 FAIL_MISSING, 1 FAIL_OBJTYPE.**

I read the actual code. Here is what is broken and exactly how to fix it.

---

## 1. Per-cave dispatch fixes — what is actually broken

### Bug A: CAVE_ID_MAX off-by-one (blocks caves $7A..$7D = 4 FAIL_MISSING)

`cave_dispatch.c:71` defines `CAVE_ID_MAX 0x7Cu`. The NES
`InitCaveContinue` (Z_01.asm:106) uses `SBC #$6A` into a Y index then
reads `OverworldPersonTextSelectors[Y]` — 20 entries, Y=0..19,
cave_id=$6A..$7D. $7D is valid. Genesis gate rejects it.

**Fix:** `cave_dispatch.c:71` — change `0x7Cu` to `0x7Du`. One byte.
Also update comment at line 69 ("0x7C inclusive" → "0x7D inclusive").
**Risk:** low. **Effort:** 5 minutes. Unblocks 4 scenarios immediately.

### Bug B: cave_78 FAIL_OBJTYPE — room_id mismatch (1 FAIL_OBJTYPE)

scenarios.json:159 maps cave_78 to `ow_room_id: 12`. sweep_report.md
shows s_room_id=$1C (28) vs exp=$0C (12). The probe navigates to room
$1C instead of $0C. This is a scenarios.json data error — the warp
route for cave_id=$78 (cave_idx=14, ow_room $0C) needs to be verified
against `reference/aldonunez/dat/LevelBlockAttrs*.dat`. **Do not guess.**
Write a NES probe: dump `LevelBlockAttrsB[all 128 rooms]` at $6004..683
(SRAM), find which room has selector `(selector & 0xFC) == 0x58` (cave_idx=14:
`k_overworld_person_text_selectors[14]=0xDC` → selector=`$DC & 0x3F = $1C`,
top2 = $C0 → flags). Cross-reference `warp_routes_expected.json` (already
exists at `tools/parity/`). **Effort:** 30 minutes (probe + json fix).

### D1: Bonfire SAT publish — ALREADY WIRED, not a blocker

cave_dispatch.c:125-130 sets ObjType+2/3=$40 and ENEMY_ALIVE_FLAG+2/3=1.
enemy_loop.c:860 has `[0x40] = enrt_update_standing_fire`. That chain is
complete. If bonfires aren't showing, the bug is in the SAT publish path
inside `enrt_update_standing_fire` (src/oracle/enemies/enemy_walker_runtime.c:146)
or the sprite_render link chain (feedback_genesis_sprite_link_chain). Probe
first: dump SAT at frame 60 after cave entry. Don't assume D1 is open.

### D2-D4: PersonTextAddrs / textbox / BCD — ALREADY LANDED

- D2: cave_dispatch.c:685-701 is a complete `cave_draw_person` implementation.
- D3: cave_dispatch.c:764-830 is `cave_update_person_state_textbox` with the
  Genesis pointer-array path. States 1 and 7 both call it (lines 596, 602).
- D4: cave_dispatch.c:279-285 calls `cave_write_prices_transfer_buf()`.

The context.md D1-D4 list is STALE. These are already closed. The
remaining 40 FAIL_MISSING are dungeon entries/exits + the 4 cave
7A-7D from the ID-max bug. Fix Bug A first; re-run the sweep.

---

## 2. Dungeon entry — the real blocker (36 FAIL_MISSING)

All 36 dungeon_enter + dungeon_exit scenarios show s_scene=$00, s_mode=$00,
s_room=$00. They never trigger. The probe's Y formula for dungeon entry
(probe_one_gen.lua:266) uses `link_y = wr*8 + 0x2D`, which targets
transition rule 4: `(link_y & 0x0F) == 0x05`.

`transition.c:267` implements rule 4: `((unsigned)link_y & 0x0Fu) != 0x05u`
returns 0. That part is correct. Rules 1 and 2 need grid_offset=0 and
underground_exit_type=0. The probe at line 271 calls `force_mode_walk()`
which zeros s_mode. But it does NOT zero `s_link_grid_offset` (acknowledged
at probe_one_gen.lua:65 comment: "address not known from probe-side").

If `s_link_grid_offset` stays non-zero at the frame the warp check fires,
rule 2 rejects every frame. The grid offset is `signed char` in `main.c`
BSS. Its symbol address is unknown to the probe.

**Fix path:**
1. Run `nm` on Debug.out to locate `s_link_grid_offset`. It's in BSS near
   `s_mode` / `s_scene` cluster. The probe already knows $FF027A=s_mode,
   $FF027E=s_scene (probe_one_gen.lua:23-24). Grep `nm Debug.out | grep grid`.
2. Add `force_grid_offset_zero()` to probe_one_gen.lua (same pattern as
   `force_mode_walk`).
3. Re-run sweep for dungeon scenarios.

**Alternatively:** check if `load_room()` resets grid_offset (transition.c
comment at line 67 says it does). The teleport navigate path calls load_room;
but probe writes link_xy AFTER teleport settles, without a subsequent
load_room call. Grid offset may be stale from the teleport landing.

**Effort:** 2 hours. **Risk:** medium — may reveal a second blocker once
grid_offset is fixed (underground_exit_type cell, or the manifest gate).

---

## 3. NES baseline capture infrastructure

`probe_nes_full_room_dump.lua` exists and captures OAM/PALRAM/CIRAM/CHR/RAM
per (level, room) to `C:/tmp/dual/nes/lv<LV>_rm<RM>/static.txt`. It already
has SCAN_ALL=true mode. This is the right tool.

**What it still needs for cave/dungeon parity:**
- Cave scenarios: the NES probe must enter each cave ($6A..$7D) and capture
  at frame 240. Current probe navigates by level+room; add cave_id navigation
  (warp to OW room_id from warp_routes_expected.json, walk Link to entrance
  tile, wait for mode=$0B/$0C).
- Output path: one `.bin` file per scenario in GDMP format (matching Gen
  side), stored at `C:/tmp/g_sweep/nes_<scenario_id>.bin`. The binary must
  include NES-native blocks: `OAM_` (256 bytes), `PAL_` (32 bytes),
  `CIRA` (2048 bytes nametable 0 + 1), `RAM_` (zero-page), `STAT`.
- **New Lua file needed:** `tools/parity/dungeon_visual_sweep/probe_nes_cave.lua`
  — mirrors probe_one_gen.lua structure but for NES side. Single BizHawk
  launch per scenario via the /bizhawkScript skill.

**Effort:** 4 hours (new probe + GDMP writer + test on cave_6A). **Risk:** low
— existing probe_nes_full_room_dump.lua shows the domain access patterns work.

---

## 4. Strict byte-diff verifier — per-domain tolerances

`tolerances.yaml` already specifies the policy. `verify_sweep.py` currently
only checks STAT (scene/room). It does NOT diff OAM, CRAM, or Plane A.

**What must be added to `verify_sweep.py`:**

| Domain | Tolerance | Comparator needed |
|---|---|---|
| CRAM (64 Genesis words) | EXACT after NES PALRAM → Gen LUT | `cmp_exact` on converted array |
| SAT vs OAM | FUNCTIONAL: ±1px position, exact palette+flip | `cmp_sat_oam_functional` (defined in tolerances.yaml but not implemented in verify_sweep.py) |
| Plane A (cave nametable) | EXACT after NES tile_id → Gen tile_id LUT | `cmp_exact` on converted array |
| STAT game state cells | EXACT (GameMode/PersonState/CaveFlags) | already in STAT block |
| Char-stream text | EXACT byte sequence from PersonTextAddrs | compare RAM($0302..$030F) transfer buffer |

**What is translated, not exact:**
- NES tile_id → Gen tile_id: via the sparse atlas LUT in `bg_sparse_chr.h`
- NES PALRAM $3F color → Gen CRAM word: via `misc_palettes` LUT

**What is exact raw:**
- CAVE_PERSON_STATE ($00AD)
- CAVE_FLAGS ($0413)
- CaveItemIds ($0422-$0424)
- CavePrices ($0430-$0432)
- PersonTextSelector ($0415)
- TextCharIndex ($0416)

**Effort:** 6 hours (extend verify_sweep.py + implement cmp_sat_oam_functional).
**Risk:** high — SAT functional comparator is complex and will surface real
rendering bugs that are currently hidden by the coarse STAT-only check.

---

## 5. Iteration loop — per-scenario retry

```
# 1. Fix the code (cave_dispatch.c / transition.c / probe lua).
# 2. Build.
Debug.bat 2>&1 | tail -5  # must say "No errors"

# 3. Run one scenario.
python tools/parity/dungeon_visual_sweep/run_sweep.py --scenario cave_7A_enter

# 4. Verify.
python tools/parity/dungeon_visual_sweep/verify_sweep.py

# 5. Triage FAIL.
```

**Failure triage by failure class:**

- `FAIL_MISSING` (s_scene still $00): grid_offset or underground_exit_type
  not zero at the warp frame. Add nm lookup + force both cells in probe.
- `FAIL_OBJTYPE` (s_room_id wrong): OW room_id in scenarios.json is wrong.
  Run NES probe, dump LevelBlockAttrsB, find correct room. Fix json.
- `FAIL_CRAM` (future, once comparator lands): palette mismatch. Dump NES
  PALRAM at same frame, run through NES→Gen LUT, diff against Genesis CRAM.
  The divergence tells you which sub-palette is wrong.
- `FAIL_SAT` (future): sprite position or tile mismatch. Diff NES OAM vs
  Gen SAT side-by-side. The OAM dump is in the NES GDMP bundle.
- `FAIL_PLANE` (future): nametable tile mismatch. Diff NES CIRAM vs Gen
  Plane A after tile_id translation.

**Per-fail turnaround:** 20-40 minutes if the probe infrastructure is complete
(NES baseline + byte-diff comparator). Without NES baselines, visual inspection
only — much longer.

---

## Priority order

1. **Fix CAVE_ID_MAX** (5 min) — unblocks 4 scenarios, zero risk.
2. **Locate s_link_grid_offset via nm, patch probe** (2 hrs) — unblocks 36
   dungeon scenarios.
3. **Build NES cave probe** (4 hrs) — enables byte-diff on the 15 passing
   caves to find real visual bugs.
4. **Extend verify_sweep.py with CRAM/SAT/PlaneA comparators** (6 hrs) —
   turns visual PASS into byte-exact PASS.
5. **Fix cave_78 room_id in scenarios.json** (30 min) — unblocks 1 FAIL_OBJTYPE.

Total effort to 56/56 structural PASS: ~13 hours.
Total effort to 56/56 byte-exact visual PASS: +6-12 hours depending on how
many CRAM/SAT divergences the comparator surfaces.

**Do not write a line of speculative fix code before running the nm command
and the NES baseline probe. Every "fix" not grounded in a live diff is a guess.**
