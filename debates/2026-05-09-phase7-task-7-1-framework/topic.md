# Debate: Phase 7 Task 7.1 framework

**Date:** 2026-05-09
**Phase:** 7 (Enemies By Behavior Family)
**Task:** 7.1 (Enemy Framework — BLOCKING for parallel family fan-out)
**Master plan tier:** "Sonnet + Codex debate Tier 2"

## Three sub-questions, integrated verdict

### Q1 — enemy_state.h alias collision resolution

134 in-scope OBJ(0x0412) collisions per master plan. Sonnet evidence:
`ENEMY_FLYER_SPEED_FRAC` and `ENEMY_PUSH_TIMER` both map to slot 0x0412.

- (a) tagged-union per-enemy-family — NES Z_04.asm uses overlapping object scratch space (same memory, different meaning per type).
- (b) separate sub-arrays per family — wastes RAM, eliminates aliasing.
- (c) flat byte-slot array + per-enemy-type accessor macros that document the alias.

### Q2 — roomrom_rng.h design

Required exports: `rng_seed` / `rng_next` / `rng_peek` + `PROBE_RNG_SEED` probe address.

- (a) port NES Z1 Random helper byte-for-byte (LSR/EOR taps, single-byte state).
- (b) 16-bit LFSR (Galois).
- (c) xorshift32.

Constraint: enemy spawn positions, drop tables, and direction-pick math
must match NES exactly when seeded the same. NES uses 1-byte state;
widening breaks parity.

### Q3 — enemy_parity_matrix.md scope

Per master plan: per enemy: source room(s), spawn rule, RNG seed
positions, movement timer cadence, hitbox dimensions, damage value,
drop table, required probe id.

- (a) hand-author all rows now from NES asm reading (~30+ enemies, ~3 hours).
- (b) generate skeleton from existing `src/game/enemies/*_runtime.c` + NES asm grep, hand-fill probe ids as Phase 1.5 captures land.
- (c) defer the matrix until first family lands and grow incrementally.

## Project context

- 433 drained C functions across 7 subsystems exist.
- Phase 6 just closed (commit `d185fbb3`).
- Sole build target `Debug.md`.
- NES accuracy as spec, Genesis-native impl.
- CLAUDE.md priority: long-term outcome > coding practice > efficiency > NES accuracy.

## Format

Brief verdict per sub-question + integrated framework recommendation.
Under 600 words total per round.
