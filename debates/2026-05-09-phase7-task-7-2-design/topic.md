# Phase 7 Task 7.2 step 2 — enemy loop framework

**Created:** 2026-05-09
**Style:** adversarial / 1 round / 4-way (Codex / Gemini / Sonnet / Opus)
**Topic source:** `.claude/session-plan.md` Phase D2 lock.

## Job

Decide the framework shape for wiring `enrt_init_*` / `enrt_update_*` (drained
walker family) into `roomrom_debug_tick` so an octorok renders + moves on the
Genesis ROM with NES-parity at a matched RNG seed. Five sub-questions.
Integrated verdict (one framework, not 5 silos).

## Q1 — Spawn data source

(a) Port `reference/aldonunez/dat/ObjListAddrs.inc` + `ObjLists.inc` directly
    into `RoomRom/data/obj_lists.c` (~200 LOC, full NES parity, deferred work
    pulled forward).
(b) Hardcoded 1-2-octorok test table in `RoomRom/data/enemy_test_spawns.c`
    (~40 LOC, fastest to first probe, throwaway).
(c) Extend existing `data/rooms/overworld.c` blob with enemy spawn arrays
    (uses existing data plumbing).

## Q2 — Iterator placement in `roomrom_debug_tick`

(a) Immediately after `level_chr_swap_tick`, before scroll state.
(b) After scroll-state finalize, before sprite draw.
(c) Inside scroll-stable branch only (no enemy ticks during transition —
    matches NES `IsSprite0CheckActive` at `Z_07.asm:496`).

## Q3 — Type dispatch shape

(a) Switch statement (compiler optimizes to jump table at -O2, easy extend).
(b) Function-pointer table indexed by `ENEMY_TYPE` (mirrors NES
    `InitObject_JumpTable` at `Z_07.asm:5601`, 70+ entries).
(c) Hybrid (switch on family — walker/flyer/jumper — table inside each).

## Q4 — First probe room

(a) Overworld $77 (Link spawn — easy reach, no enemies natively).
(b) L1 entrance with stalfos/goriya (UW, requires teleport debug).
(c) Overworld $7C (slow octorok column, simple walker, ~10 frames from spawn).

## Q5 — Substrate edit needed?

(a) None — RoomRom-only edits.
(b) Reserve enemy sprite-slot range in `roomrom_vram_map.h` (small adjacent edit).
(c) Add enemy-CHR bank dispatch hook (preempts PR-4b enemy_chr.c work).

## Context

- Task 7.1 framework landed (commit `83c00616`): `roomrom_enemy_state.h` +
  `roomrom_rng.{h,c}` + alias_table + parity_matrix.
- Task 7.2 step 1 landed (commit `b5026c1a`): walker-family drain (1340 LOC)
  linked into `Debug.md`.
- `roomrom_debug_tick` at `RoomRom/src/main.c:1231` — ZERO enemy logic exists.
- Drain Rule D1: ADOPT/EXTEND only. GREENFIELD banned.
- Sole build target `Debug.md`.
- CLAUDE.md priority: long-term outcome > coding practice > efficiency > NES.
- Risk: drain shims (`c_walker_move`, `z01_check_link_collision`,
  `z01_anim_set_sprite_desc_attrs`) may write Title-side OAM/SAT not
  RoomRom's SGDK-managed sprite list.

## Format expected

Brief verdict per sub-question (one or two sentences each) + integrated
framework recommendation (4-6 sentences). Adversarial: pick at the
weakest option of the others, name the failure mode. Under 800 words.
