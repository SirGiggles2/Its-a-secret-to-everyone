# Phase 7 Task 7.1 Framework — Debate Synthesis

**Date:** 2026-05-09
**Participants:** Codex CLI, Gemini CLI, Sonnet (Agent), Opus (this turn)
**Topic:** [topic.md](topic.md)

## Round 1 verdicts — unanimous

| Sub-Q | Codex | Gemini | Sonnet | Opus | Verdict |
|---|---|---|---|---|---|
| Q1 enemy_state.h alias | (c) | (c) | (c) | (c) | **(c) flat byte-slot + accessor macros** |
| Q2 roomrom_rng.h | (a) | (a) | (a) | (a) | **(a) NES Random[13] byte-for-byte** |
| Q3 enemy_parity_matrix.md | (b) | (b) | (b) | (b) | **(b) skeleton-generate, fill probe ids incrementally** |

4-of-4 agreement on every sub-question. No round 2 needed.

## Why each option won

### Q1 — flat byte-slot + accessor macros

- **NES truth (`reference/aldonunez/ObjVars.inc:7,24`):** `ObjPushTimer := $412` and `Flyer_ObjSpeedFrac := $412` literally share the symbol. Aliasing IS the spec.
- **Drained reality (`src/state/enemy_state.h:21-22, 108-115`):** drain authors already converged on (c). `ENEMY_PUSH_TIMER` / `ENEMY_FLYER_SPEED_FRAC` / `ENEMY_JUMPER_VSPEED_HI` / `ENEMY_GOHMA_DIST_TRAVELED` all `OBJ(0x0412, slot)` with explicit `aliases ENEMY_X` comments.
- **Why not (a) tagged-union:** lies about NES memory; "dependency hell" once 30+ enemies need overlapping families (Sonnet); breaks `LDA Random,X` slot-indexed reads (Codex).
- **Why not (b) sub-arrays:** wastes ~144 bytes for cosmetic safety; breaks slot-indexed reads (`Z_04.asm:1221`); doesn't match NES behavior.

### Q2 — NES Random[13] byte-for-byte

- **NES scramble (`reference/aldonunez/Z_07.asm:499-515`):** `@ScrambleRandom` taps bit 1 of `$18` and `$19`, EORs them, ROR-chains carry through 13 bytes ($18..$24).
- **Why widening breaks parity:** every `LDA Random,X` slot-indexed read (Wizzrobe align, drop tables, Z_04 direction picks at `:1221`, `:11209`, `:11866`) depends on the byte sequence. 16-bit/32-bit state desyncs spawn positions, drop rolls, AI direction picks.
- **API compromise (Codex):** keep master-plan-mandated `uint16_t` ergonomics for probe — `rng_seed(uint16_t)` distributes seed across `Random[0..12]`; `rng_next()` returns `(Random[1] << 8) | Random[0]` after one step. Internal state is the 13-byte array.
- **Probe surface:** `PROBE_RNG_SEED = &Random[0]` in M68K WRAM; matches existing `tools/bizhawk_t38_enemy_nes_capture.lua:501` poke pattern.

### Q3 — skeleton-generate, fill probe ids incrementally

- **(a) hand-author 30+ rows now = fake confidence** (Codex) — RNG seed positions and probe ids are unknowable until first family runtime + Phase 1.5 captures land.
- **(c) defer = master plan blocks fan-out** on this artifact, so deferring blocks Phase 7 entirely.
- **(b) executes today:** grep `Z_04.asm` `Init*` / `Update*` enemy labels → ~30 rows; cross-link `src/game/enemies/enemy_dispatch.c` dispatch table; hand-fill known fields (hitbox, damage); `probe_id: PROBE_PENDING` placeholders. Family agents fan out against skeleton; matrix grows row-by-row.

## Integrated framework — single-commit blocking deliverable

Phase 7 root, ordered:

1. **`RoomRom/src/roomrom_enemy_state.h`** — port `src/state/enemy_state.h` enemy slice. `_Static_assert` per alias-cluster proves collision-as-feature. Aliases preserved verbatim with explicit `aliases X` comments.
2. **`RoomRom/src/roomrom_rng.h` + `roomrom_rng.c`** — 13-byte `Random[]` array. `@ScrambleRandom` ROR-chain in `rng_next()`. APIs: `void rng_seed(uint16_t)`, `uint16_t rng_next(void)`, `uint16_t rng_peek(void)`. `#define PROBE_RNG_SEED ((volatile uint8_t *)0xFF????)` to M68K WRAM addr of `Random[0]`.
3. **`docs/audit/enemy_parity_matrix.md`** — skeleton from `Z_04.asm` grep + `enemy_dispatch.c` (~30 rows). Columns: id, source_room, spawn_rule, rng_seed_positions, move_timer_cadence, hitbox, damage, drop_table, probe_id. Probe ids = `PROBE_PENDING`.
4. **`docs/audit/enemy_alias_table.md`** — explicit alias pairs by byte address (`0x0412 = PUSH_TIMER | FLYER_SPEED_FRAC | JUMPER_VSPEED_HI | GOHMA_DIST_TRAVELED`) so family agents grep-find their byte before writing.

Post-commit: master plan unblocks Tasks 7.2 (Walker), 7.3 (Flyer-Jumper), 7.4 (Projectile), 7.5 (Special), 7.6 (Aquatic-Terrain), 7.7 (Enemy Room Matrix) for parallel fan-out.

## Drain Rule D1 compliance

- **Drained C primary:** `src/state/enemy_state.h` (134 OBJ(0x0412) collisions) is PRIMARY. New `RoomRom/src/roomrom_enemy_state.h` ports that drain, doesn't rewrite from NES.
- **NES asm secondary:** `reference/aldonunez/ObjVars.inc` + `Z_04.asm` + `Z_07.asm` win ties. Confirmed (a) for Q2 by reading `Z_07.asm:499-515` directly.
- **Stance:** `EXTEND` (port + collision proofs added to existing drain). NOT GREENFIELD.

## Next action

Execute the four-file framework commit. No round 2. No AskUserQuestion — autonomous mandate per CLAUDE.md "no multi-choice prompts".
