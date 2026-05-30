# Get every boss working — Phase 8 close

## Context

User asked: "Get every boss working. Sprites, AI, movement, hitboxes, spawn."

Project = NES Zelda 1 → Sega Genesis port (FINAL TRY). CLAUDE.md
RULE ND-1: NO DEFERRALS. CLAUDE.md RULE V1: byte-diff > screenshot.
CLAUDE.md RULE D1: drained C primary, NES asm secondary.

Phase 8 tracker claims CLOSED but RULE V1 disqualifies — no byte-exact
NES-vs-Genesis parity has been produced for any boss. Plus 3 hard
deferral violations found in exploration:

1. `RoomRom/src/atlas/bosses_chr.h` = 100% stubs.
   All 23 boss-sprite offsets are `0u /* stub */`. All `W_*` / `H_*`
   hardcoded `{2u, 1u}` placeholder. Comment: "TODO (Phase 4) ? tiles
   are scene-conditional, PRG extraction deferred." Boss sprite draw
   code therefore addresses tile 0 of the boss bank for every boss —
   visually broken even though `boss_chr.c` byte data IS populated and
   `level_chr_swap.c` uploads it.

2. `src/game/enemies/enemy_ganon_bridge.c:61-84` has 4 PARTIAL stubs
   marked "TODO Phase 9":
   - `sprrt_anim_fetch_obj_pos` — Ganon DrawBurst dead
   - `lcrt_check_link_collision_preinit` — Ganon can't hit Link
   - `colrt_check_monster_sword_collision` — sword can't hit Ganon
   - `colrt_check_monster_arrow_or_rod_collision` — silver arrow can't
     hit Ganon (final boss unkillable)

3. `tools/debug/probes/probe_boss_matrix.lua` is dispatch-doesn't-crash
   only. RULE V1: not verification.

Intended outcome: all 10 NES Z1 bosses (Aquamentus, Dodongo, Manhandla,
Gleeok 1/2/3/4-head, Digdogger, Gohma, Patra, Moldorm, Lamnola, Ganon)
spawn correctly in canonical rooms, draw correct sprites from correct
CHR slots, run AI byte-identical to NES at sampled frames, take damage
per attack class (sword/bomb/arrow/silver-arrow) routed correctly,
drop heart container + triforce piece on death, and pass a full
matrix sweep with PASS verdicts copied from byte-differ output.

## Existing reusable infrastructure

- Dispatch: `src/game/enemies/enemy_loop.c` `enemy_init_fns[]` /
  `enemy_update_fns[]`. All 10 boss types $31-$48 already wired.
- HP seed: `k_object_hp_pairs[38]` (`enemy_loop.c:75-88`). Per-NES
  EnemyHP. Verify only.
- ObjAttr seed: `k_object_type_attrs[95]` (`enemy_loop.c:78-87`).
  Per-NES EnemyAttribs. Verify only.
- Boss state substrate: `src/state/boss_state.h` + `src/state/enemy_state.h`
  per-boss cells already declared.
- Boss CHR bytes: `RoomRom/src/atlas/boss_chr.c` (3 banks @ 2048 B
  each), uploaded via `level_chr_boss_request()` in
  `RoomRom/src/atlas/level_chr_swap.c`.
- Native bridges already on disk:
  - `src/game/enemies/bosses/boss_dodongo.c`
  - `src/game/enemies/bosses/boss_gleeok.c`
  - `src/game/enemies/bosses/boss_gohma.c`
  - `src/game/enemies/bosses/boss_manhandla.c`
  - `src/game/enemies/bosses/boss_patra.c`
  - `src/game/enemies/enemy_boss_bridge.c` (Aquamentus, Digdogger init)
  - `src/game/enemies/enemy_lamnola_bridge.c`
  - `src/game/enemies/enemy_ganon_bridge.c` (4 PARTIAL stubs)
- Drained runtimes in `src/oracle/enemies/`:
  enemy_boss_runtime, enemy_dodongo_runtime, enemy_gleeok_runtime,
  enemy_manhandla_runtime, enemy_lamnola_runtime, enemy_moldorm_runtime,
  enemy_ganon_runtime, enemy_patra_runtime.
- Existing probe scripts to extend (not replace):
  - `tools/debug/probes/probe_boss_matrix.lua` (full rewrite — currently dispatch-only)
  - `tools/parity/probe_gen_real_bosses.lua` / `probe_nes_known_bosses.lua` (boss room discovery loop)
  - `tools/parity/probe_gen_boss_uw_visual.lua` / `probe_nes_boss_uw_visual.lua`
  - `tools/parity/probe_gen_l1_boss.lua` (Aquamentus harness)
- Existing CHR extractor: `tools/extract_chr.py` already emits per-bank
  bytes. EXTEND with `--emit-boss-atlas` mode for per-sprite offsets —
  do NOT create a new extractor.
- Existing collision dispatcher: `src/game/combat/collision_dispatch.c`
  has `collision_check_monster_sword_collision`. ADD
  `collision_check_monster_arrow_or_rod_collision` next to it.
- Live damage path: `link_collision_link_be_harmed` in
  `src/game/combat/link_collision_dispatch.c:52` (per memory
  `project_link_damage_works`).
- NES boss source-of-truth: `reference/aldonunez/Z_04.asm` (see exploration
  notes for per-boss line numbers). HP table:
  `data/enemies/tables.c` offset 133. Init handlers offset 218. Update
  handlers offset 313.

## Plan revisions (post-`/octo:review` 4x — 2026-05-30)

Architecture / NES-accuracy / TDD reviewers found 16 concerns. Plan
revised below addresses each:

| # | Concern | Fix |
|---|---|---|
| 1 | Phase B↔D circular dep (Ganon stub needs func D creates) | Split: Phase B0 adds `collision_check_monster_arrow_or_rod_collision`, then Phase B per-boss can forward to it |
| 2 | Probe-first violated (B before C) | Fold C into B: atomic 5-step per boss (probe RED → drain diff → code → probe GREEN → commit) |
| 3 | L7 Aquamentus CHR bank swap missing | Phase A adds per-level dispatcher reading `BossPatternBlockSrcAddrs[level-1]`. L1=Bank1257, L7=Bank3468 |
| 4 | Gohma cite Z_04:8392 wrong | Use Z_04:8309 `NextOpenEyeCounter` for timer; 8392 is `AnimateAndDraw` |
| 5 | HP cell width unverified | Phase 0.A: 30-min width audit, document in captures |
| 6 | Existing 5 bridges drift untouched | Phase 0.B: drift audit ALL bridges vs `src/oracle/` drains |
| 7 | Boss room IDs hardcoded guesses | Phase 0.C: discovery loop, emit `docs/audit/boss_room_ids.md` |
| 8 | RULE V3 capture incomplete | Add SAT (`$F800` per `_oam_dma_flush`), PPUCTRL, GameMode, `$6BBC` BossRoomId, force domain enumerate first |
| 9 | Tracker reopen missing | Phase -1: `prime_refresh.py --record-out-of-phase phase8 "RULE V1 — byte-exact parity unverified"` |
| 10 | Excluded cells list missing | Differ excludes `$0012 FrameCounter`, `$001D-$001F RNG`, `$0600-$0700 audio`. Document each with NES asm cite |
| 11 | Sprite capacity math wrong | Comparator normalizes: NES 8×16 OAM count vs Genesis SAT cell-area / 2 |
| 12 | Death-anim 5-10f window too short | Capture +1..+96 frames every frame, full CRAM each |
| 13 | Regression for shared collision | Phase B0 captures Gohma BASELINE pre-change; Phase D regression assert Gohma byte-identical post-change |
| 14 | /octo:review × 20 probes burden | One reviewed template `tools/parity/probe_boss_template.lua` + per-boss config JSON |
| 15 | Moldorm stance ADOPT wrong | EXTEND (ADOPT reserved for drained `_runtime.c` itself) |
| 16 | 46h ambiguous halt points | Phase A independently shippable. Phase B per-boss atomic — halt only between bosses, never mid-boss |

Also: consolidate differs into single `tools/parity/diff_boss.py
--mode={state,matrix}`. Add `phase8-<phase>-pre` git tags for rollback.
Add Phase G: regression matrix integration (CI hook for substrate PRs).

## Implementation order (revised)

Phases run **-1 → 0 → A → B0 → B (10 bosses) → D → E → F → G**.
Per-phase 3-gate verification (CLAUDE.md): drain diff doc →
per-RAM-cell byte-diff → matrix sweep. Commit boundary at each phase.
Substrate edits stay on `main` worktree.

### Phase -1 — Tracker reopen

Run: `python tools/audit/primedirective/prime_refresh.py
--record-out-of-phase phase8 "RULE V1 — byte-exact parity unverified
across all 10 bosses; reopening for closure"`.

Commit: "tracker: reopen Phase 8 — RULE V1 byte-exact parity unverified"

### Phase 0 — Audits before differ exists

- 0.A HP cell width: grep `MON_HP` in `src/state/combat_state.h`,
  capture live, document in `docs/superpowers/captures/phase8/hp_width.md`.
- 0.B Existing-bridge drift: per-function diff of each existing bridge
  (Dodongo/Gleeok/Gohma/Manhandla/Patra) vs `src/oracle/<boss>_runtime.c`.
  Emit `tools/audit/drain_findings/phase8_existing_bridges.md`.
- 0.C Boss room IDs: run `probe_gen_real_bosses.lua` + NES mirror, read
  `$6BBC` post-`install_uw` per level. Emit `docs/audit/boss_room_ids.md`.
- 0.D Comparator multi-sprite: test `compare_t38_enemy_parity.py` against
  Gleeok baseline. If single-sprite tuned, extend with `--multi-sprite`
  groupBy parent-monster-id.

Commit: "phase8: pre-work audits (width + drift + room ids + comparator)"

### Phase A — Boss sprite atlas offsets + per-level CHR dispatch

**Goal:** populate `RoomRom/src/atlas/bosses_chr.h` per-sprite offsets,
correct W/H. Implement per-level CHR bank dispatch via
`BossPatternBlockSrcAddrs[level-1]` (Z_03.asm:24-34). L1→Bank1257,
L2→Bank1257, L5→Bank1257, L7→Bank3468, L3→Bank3468, L4→Bank3468,
L6→Bank3468, L8→Bank3468, L9→Bank9.

Files:
- Edit `tools/extract_chr.py`: `--emit-boss-atlas` mode.
- Regen `RoomRom/src/atlas/bosses_chr.h`.
- Edit `RoomRom/src/atlas/level_chr_swap.c` `level_chr_boss_request()`:
  read `BossPatternBlockSrcAddrs[level-1]`, upload matching bank.

Verify: probe per boss per level, byte-diff VRAM at
`ROOMROM_BOSS_TILE_BASE*32` vs NES CHR-RAM.

Commit: "atlas: per-sprite offsets + per-level CHR bank dispatch (Phase 4 close)"

### Phase B0 — Add `collision_check_monster_arrow_or_rod_collision`

Pre-requisite for Phase B Ganon close + Phase D damage routing.

- Add function to `src/game/combat/collision_dispatch.c` + decl in `.h`.
- Body transcribed from Z_04 `Gohma_HandleWeaponCollision` arrow-rod
  gate.
- Capture Gohma BASELINE (pre-change) — committed to
  `docs/superpowers/captures/phase8/gohma_baseline.bin` for Phase D
  regression assert.

Commit: "combat: arrow/rod collision dispatch entry (gates Ganon + Gohma)"

### Phase B — Per-boss atomic close (10 iterations)

For each boss, ONE atomic 5-step task (no halt mid-boss per ND-1):

1. **Probe RED.** Write `tools/parity/probe_{nes,gen}_boss_<name>.lua`
   from `probe_boss_template.lua` + per-boss JSON config. Capture
   pre-fix state. Run differ. Must show divergence (proves the probe
   detects bugs).
2. **Drain diff.** Emit `tools/audit/drain_findings/phase8_task_8_<N>.md`
   with 4-line D1 header + per-function diff vs NES asm. Stance per
   table above (Moldorm = EXTEND, not ADOPT).
3. **Code.** Edit bridge per drain-diff findings.
4. **Probe GREEN.** Re-run differ. Must show convergence (or
   documented residual divergence with NES asm justification).
5. **Commit.** "bosses: <name> drain + bridge close (Phase 8.<N>)".

Per-boss tag: `phase8-b-<name>-pre` for rollback before step 3.

Special: Ganon (Task 8.10) closes 4 PARTIAL stubs:
- `sprrt_anim_fetch_obj_pos` → `world/sprite_dispatch.c`
- `lcrt_check_link_collision_preinit` → `link_collision_dispatch.c:52`
- `colrt_check_monster_sword_collision` → `collision_dispatch.c`
- `colrt_check_monster_arrow_or_rod_collision` → Phase B0 function
- Silver-arrow gate: `INV_HAS_SILVER_ARROW` from `item_state.h`

### Phase D — Damage routing verification + Gohma regression

- Probe `probe_gen_boss_damage.lua`: each boss × each weapon class
  (sword/arrow/bomb/silver-arrow). HP cell before/after. NES mirror.
- **Gohma regression assert**: re-capture Gohma at frame N after Phase
  B0 + Phase B Gohma changes. Byte-diff vs Phase B0 baseline. Must be
  zero (proves dispatch change didn't regress).
- Per-boss ObjAttr verify against NES `EnemyAttribs` live.

Commit: "combat: per-boss damage routing verified (Phase 8 close)"

### Phase E — Death + reward

- Death-cry capture: every frame +1..+96 post-final-hit, full CRAM.
  Byte-diff vs NES PALRAM across same window.
- Room-clear + slot 19 reward activation per boss.
- Ganon special: triangle-of-light + Zelda rescue scene reachable.

Commit: "bosses: death animation + reward verification (Phase 8 close)"

### Phase F — Matrix gate (Phase 8.11 close)

- Replace `probe_boss_matrix.lua` with full byte-diff sweep.
- Single differ `tools/parity/diff_boss.py --mode={state,matrix}`.
- Sprite count normalized: NES OAM 8×16 count vs Genesis SAT cell-area
  / 2.
- Excluded cells: `$0012 FrameCounter`, `$001D-$001F RNG`,
  `$0600-$0700 audio`. Documented per cell with NES asm cite.
- Output `docs/audit/boss_matrix.md` with PASS/FAIL per
  (boss, level, dimension) where PASS = byte-identical verdict copied
  from differ.

Commit: "test: Phase 8.11 boss matrix byte-diff sweep + audit doc"

### Phase G — Regression matrix integration

- Add `--bosses` flag to `tools/run_regression_matrix.py`.
- Pre-merge gate: file-filter `src/sgdk_adapter/`, `src/abi/`,
  `src/state/`, `src/audio_driver.asm` → require local matrix run.
- Document in PR template.

Commit: "ci: boss regression matrix integration (Phase 8 close)"

### Phase A — Boss sprite atlas offsets

**Goal:** populate `RoomRom/src/atlas/bosses_chr.h` with real per-sprite
tile offsets + correct W/H dimensions so draw code resolves to the
right tile inside the live boss bank.

- Edit `tools/extract_chr.py`: add `--emit-boss-atlas` mode that reads
  per-boss draw-tile tables from `Z_04.asm` (AquamentusTiles @ 5754,
  Gleeok `k_body_tiles0` already extracted at 9351, Manhandla tiles,
  Patra child tables, Gohma tiles, Dodongo frame 0/1, Ganon tiles,
  Digdogger main+parts, Lamnola, Moldorm). Emit one `_OFFSET` macro
  per sprite plus correct W/H.
- Regen `RoomRom/src/atlas/bosses_chr.h` from extractor output.
- Verify: new probe `tools/parity/probe_gen_boss_chr_offsets.lua`
  enters each boss room, reads `VRAM[ROOMROM_BOSS_TILE_BASE*32 + offset*32]`,
  byte-diffs against NES `CHR_RAM` at expected NES tile id × 16 bytes
  (normalized 2bpp → 4bpp via existing `tools/parity/diff_chr.py`
  helper if present, else add).
- Verify dimensions: tile capacity per bank (1024 bytes / 16 bytes/tile
  / 4x for 4bpp = 16 NES tiles per 2048-byte bank, packs to 64 Genesis
  tiles per bank at 32 bytes each = 64 tile slots × 8x8 each).
  Largest single boss = Ganon (~30 tiles); fits.
- Commit: "atlas: populate boss sprite offsets from NES draw tables (Phase 4 close)"

Complexity: **M**. Owner: extractor scripts. No drain risk.

### Phase B — Per-boss bridge / drain close

**Goal:** every boss-bridge file has zero TODO stubs, and per-boss
behavior matches NES disasm per RULE D1 4-line header.

Per boss, emit `tools/audit/drain_findings/phase8_task_8_<N>.md` with
the 4-line D1 header + per-function diff vs NES asm. Stance defaults
to **EXTEND** (drained runtime already exists) — escalate to REPLACE
only with explicit evidence.

| Task | Boss | File | Stance | Specific work |
|---|---|---|---|---|
| 8.2 | Aquamentus | `enemy_boss_bridge.c` | EXTEND | Verify fan spread + ResetShoveInfo tail Z_04:5605 |
| 8.3 | Dodongo | `boss_dodongo.c` | EXTEND | Verify Bloated_Sub_Wait Z_04:5945-5993 + bomb slot deactivation |
| 8.4 | Manhandla | `boss_manhandla.c` | ADOPT | Verify head-died flag $0383 → speed-up + per-segment hit |
| 8.5 | Gleeok | `boss_gleeok.c` | EXTEND | Verify 1/2/3/4-head init (6 segs × N necks Z_04:7649) + detached head $46 cadence |
| 8.6 | Digdogger | `enemy_boss_runtime.c` callees via `enemy_boss_bridge.c` | ADOPT | Verify recorder-split: spawn 3 children + `ENEMY_DIGDOGGER_COUNT=3` at $0507; child AfterFlute state 1/2 |
| 8.7 | Gohma | `boss_gohma.c` | ADOPT | Verify arrow-only gate via `Gohma_HandleWeaponCollision`; eye-open-timer Z_04:8392 |
| 8.8 | Patra | `boss_patra.c` | ADOPT | Verify @LoopChildren slot-9..2 scan + core-vuln-when-children-dead; angle cell $0394+3 |
| 8.9a | Moldorm | new `boss_moldorm.c` thin wrapper | ADOPT | Bridge to `enemy_moldorm_runtime` callees; segment-tail → $5D dead-dummy |
| 8.9b | Lamnola | `enemy_lamnola_bridge.c` | EXTEND | Verify `c_anim_write_sprite` is wired to real `Anim_WriteSprite` Z_01:5365 OAM push |
| 8.10 | Ganon | `enemy_ganon_bridge.c` | EXTEND | Close 4 PARTIAL stubs (see below) |

**Ganon stub close** (`enemy_ganon_bridge.c:61-84`):
- `sprrt_anim_fetch_obj_pos` → forward to `world/sprite_dispatch.c:sprite_anim_fetch_obj_pos`
- `lcrt_check_link_collision_preinit` → forward to `link_collision_dispatch.c:link_collision_link_be_harmed`
- `colrt_check_monster_sword_collision` → forward to `collision_dispatch.c:collision_check_monster_sword_collision`
- `colrt_check_monster_arrow_or_rod_collision` → ADD new entry in
  `src/game/combat/collision_dispatch.c` + decl in `.h`. Body transcribed
  from Z_04 `Gohma_HandleWeaponCollision` arrow-rod gate (already used
  for Gohma; Ganon reuses). Silver-arrow finisher gated via
  `INV_HAS_SILVER_ARROW` from `src/state/item_state.h`.

Per-boss commit boundary: "bosses: <name> drain + bridge close (Phase 8.<N>)"

Complexity: **S to M** per boss. Ganon = **L** (4 stubs + silver arrow
+ invisibility cell + Zelda rescue handoff).

### Phase C — Per-boss verification probes

**Goal:** byte-exact NES vs Genesis state diff per boss at multiple
frames. All Lua MUST pass `/octo:review` before run (RULE V2). All
probes capture EVERY domain in FULL per RULE V3.

Per boss, two new probes:
- `tools/parity/probe_nes_boss_<name>.lua` — warp NES to canonical
  boss room, capture frame 0/30/60/90.
- `tools/parity/probe_gen_boss_<name>.lua` — same on Debug.md via
  `PROBE_CTRL` warp at `RAM($73F8)`.

Per-probe capture (RULE V3 — enumerate domains live first):
- Genesis: `68K RAM` ($0000-$FFFF), `VRAM` (full 64 KB), `CRAM` (128 B),
  `VSRAM` (80 B), screenshot, frame counter, controller state.
- NES: `WRAM` (2 KB), `PALRAM` (32 B), `OAM` (256 B), `CIRAM` (2 KB),
  `VRAM` (8 KB CHR-RAM — NesHawk exposes as `VRAM` not `CHR` per V3
  lesson), PPUCTRL.
- Per-boss state cells from `enemy_state.h` (already enumerated;
  Gleeok head_timer / Manhandla segment_died / Gohma open_eye_timer /
  Digdogger count / Patra orbit / Moldorm hp/attr / Ganon hp_phase
  + cloud rect).

Diff tool: new `tools/parity/diff_boss_state.py`. Reuses
`tools/parity/diff.py` infrastructure. RAM cell normalization: Genesis
68K RAM mirrors NES at same offsets per `platform_abi.h`. OAM
normalization via existing `compare_t38_enemy_parity.py` shape.
HP cell width: capture both, normalize in differ (NES 8-bit, Gen
possibly 16-bit per `combat_state.h MON_HP`).

Verify canonical boss room IDs first via discovery loop (re-run
`probe_gen_real_bosses.lua`, read `$6BBC = BossRoomId` after
`install_uw`). Bake real IDs into matrix probe — do NOT hardcode
guesses.

Per-probe-pair commit: "parity: <boss> NES+Gen capture pair (Phase 8.<N>)"

Complexity: **M** per boss (30-60 min capture-fix-iterate).

### Phase D — Damage routing per attack class

**Goal:** sword / arrow / bomb / silver-arrow all route to correct
boss-hit path with correct HP decrement.

Per-boss ObjAttr correctness:
- Read NES `EnemyAttribs` live (existing capture in
  `data/enemies/tables.c`), byte-diff against
  `k_object_type_attrs[95]` in `enemy_loop.c:78-87`.
- Mismatch → fix table.

Damage path:
- Sword: `link_damage_apply` →
  `collision_check_monster_sword_collision` → boss HP −= weapon class
  upper nibble.
- Arrow: new `collision_check_monster_arrow_or_rod_collision`
  (Phase B Ganon close). Gohma gate: eye-open-timer non-zero.
- Bomb: `Dodongo_TryEatBomb` Z_04:6145; Manhandla per-segment bomb-hit.
- Silver arrow: Ganon-only. `INV_HAS_SILVER_ARROW` AND arrow-collision
  gate → final hit.

Per-boss damage probe `tools/parity/probe_gen_boss_damage.lua`:
drives Link via scripted joypad to hit with each weapon class.
Captures HP cell before/after. NES mirror.

Commit: "combat: arrow/rod collision routing for boss family +
silver-arrow gate (Phase 8 close)"

Complexity: **M**.

### Phase E — Death + reward

**Goal:** death animation, room-clear, heart container + triforce
piece drop work end-to-end per boss.

Already wired: `boss_framework_room_init` populates slot 19 via
`DUNGEON_LBA_E/F(room_id)`. Verify only:
- Death cry → palette flash via `AppendPaletteRowTransferRecord_*`
  (Ganon-specific drained at Z_04:10954-10960).
- Room-clear: `RoomKillCount` (Z_07:5453) increments → reward slot 19
  activates via `MoveAndDrawRoomItem` Z_07:771-820.
- Ganon special: `enrt_ganon_activate_room_item`
  (`enemy_boss_runtime.c:366`) → triangle-of-light → Zelda rescue
  scene reachable.

Probe `tools/parity/probe_gen_boss_death.lua`: per boss, drives kill,
captures CRAM 5-10 frames post-final-hit, captures `BOSS_ROOM_ITEM_*`
cells. NES mirror byte-diff.

Commit: "bosses: death animation + reward verification (Phase 8 close)"

Complexity: **M**.

### Phase F — Boss matrix gate (Phase 8.11 close)

**Goal:** REPLACE dispatch-only `probe_boss_matrix.lua` with full
per-boss byte-diff sweep. Output: `docs/audit/boss_matrix.md`
with PASS/FAIL per (boss, level, dimension) where PASS = byte-identical
verdict copied from differ.

Per boss: spawn → AI sample × 4 frames → kill → death-anim → reward →
room-clear. Sprite count check: OAM slot capacity verified per boss
(boss tiles + 2 projectiles + Link 4 tiles + 4 misc < 64).

Matrix columns: boss | level | spawn-ok | sprite-correct |
AI-state-match | hp-decrement-match | death-anim-match |
reward-spawn-match | room-clear-match.

Commit: "test: Phase 8.11 boss matrix byte-diff sweep + audit doc"

Complexity: **L**.

## Critical files

- `tools/extract_chr.py` — extend with `--emit-boss-atlas` mode
- `RoomRom/src/atlas/bosses_chr.h` — auto-regen from extractor
- `src/game/enemies/enemy_ganon_bridge.c` — close 4 PARTIAL stubs
- `src/game/combat/collision_dispatch.c` + `.h` — add
  `collision_check_monster_arrow_or_rod_collision`
- `src/game/enemies/enemy_loop.c` — verify HP/attr tables vs NES
- `tools/debug/probes/probe_boss_matrix.lua` — full rewrite
- `tools/parity/probe_{nes,gen}_boss_<name>.lua` — 10 boss pairs (new)
- `tools/parity/diff_boss_state.py` (new)
- `tools/parity/diff_boss_matrix.py` (new)
- `tools/audit/drain_findings/phase8_task_8_<N>.md` — 9 docs (new)
- `docs/audit/boss_matrix.md` — phase-close evidence (new)

## Verification

End-to-end test: launch Debug.md via `/bizhawkScript` skill, drive
through each boss room via PROBE_CTRL warp, capture state, run differ,
read matrix doc, all rows PASS.

Per-phase rebuild: `./Debug.bat` clean compile + boot-smoke (frame
counter advances past 600). Per-phase Lua probes run via
`/bizhawkScript` skill (never raw `--lua=` per memory
`feedback_use_bizhawk_skill`).

Phase-close gate (11 steps per `references/phase-close-gate.md`):
- 3-gate per task: drain diff doc → per-RAM-cell byte-diff → matrix
- Worktree = `main` (substrate writer)
- `tools/audit/active_scope.py` updated
- `prime_refresh.py` records completion

Total estimated time per Plan-agent budget: **~46 hours** real work.
Per RULE ND-1: no shelving. Execute serially in order A→F.
