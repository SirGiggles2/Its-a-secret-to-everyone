# r1 — Sonnet verdict

**Round 1, Phase 7 Task 7.1 framework debate.**

## Q1 — alias collision resolution: **(c) flat byte-slot + documented accessor macros**

The 134 collisions are not a bug — they are NES Z1's object scratch
overlay, which is part of the spec we're matching. `enemy_state.h:108-115`
already encodes the right pattern: `ENEMY_GOHMA_DIST_TRAVELED(slot)`
explicitly comments `aliases ENEMY_PUSH_TIMER`, same for
`ENEMY_GOHMA_OPEN_EYE_TIMER` / `ENEMY_AI_STATE` etc. Every Z_04.asm
boss reuses `OBJ(0x0412)` because the NES had 12 slots × ~7 bytes of
scratch and the original devs packed semantics on top.

- **(a) tagged-union per-family** breaks the drain-primary invariant
  (Rule D1). 433 drained C functions read these as raw bytes. A union
  forces a rewrite of every consumer for zero parity gain.
- **(b) sub-arrays per family** wastes RAM, fragments the slot array
  that `enemy_find_empty_monster_slot` (enemy_dispatch.c:16-27) walks
  linearly slots 11→1, and would force every cross-family helper
  (combat damage, hit-react, shove) to switch on type before touching
  state. NES doesn't do this; we shouldn't either.
- **(c)** keeps NES RAM layout 1:1, matches what enemy_state.h is
  already growing toward, and the only debt is naming hygiene —
  solvable with a comment convention (`/* aliases X — used by FAMILY */`)
  and a lint that requires the comment when a new alias lands on an
  existing offset. Add `tools/audit/verify_alias_documented.py` as the
  Phase 7 gate.

## Q2 — RNG: **(a) NES Z1 Random helper, byte-for-byte**

Non-negotiable. NES `Random` is not a single byte — it's a 13-byte
array at `$18..$24` (`Variables.inc:8: Random := $18`,
`Z_07.asm:499-515 ScrambleRandom: LDX #$18 / LDY #$0D / ROR $00,X /
INX / DEY / BNE`). Enemies index it by **slot**: `Z_04.asm:8218
LDY Random, X` (Gohma direction pick), `:544`, `:609`, `:1098`,
`:1492`, `:1669` — same pattern across every AI. Slot-indexed reads
are baked into the spec.

- (b) 16-bit Galois LFSR and (c) xorshift32 both widen state and
  destroy the per-slot read. Same seed → different spawn directions,
  drop tables, Gohma stride pick — every parity oracle fails.
- (a) gives us `roomrom_rng.h` with `rng_advance_frame()` (the
  ScrambleRandom ROR-chain), `rng_byte(slot)` returning
  `Random[$18 + slot]`, and `PROBE_RNG_SEED` exposing the full 13-byte
  array. Cost: ~30 lines of C. Reward: any seeded RAM trace replays
  identically against NES.

## Q3 — parity matrix: **(b) skeleton-generate, hand-fill probe ids**

(a) hand-author is 3 hours of error-prone transcription with no
verification feedback loop until the family lands. (c) defer
guarantees the first family ships without parity evidence and we
re-relitigate scope every subsequent task.

(b) is the drain-primary play: `tools/audit/drain_coverage.py` already
walks `src/game/enemies/` (only `enemy_dispatch.c` exists today, ~239
lines, 5 leaf helpers + walker_alt_dir). Extend it to grep
`reference/aldonunez/Z_04.asm` for `Update<Name>:` labels, emit one
matrix row per enemy with NES line refs pre-populated, leave
spawn-rule / hitbox / drop-table / probe-id columns blank. Hand-fill
those during Phase 1.5 captures and per-family task work — same cadence
as the 4-line task header. Matrix becomes a living drain-coverage
artifact, not a one-shot doc.

## Integrated framework

1. **State**: extend `enemy_state.h` flat-byte model + add
   `verify_alias_documented.py` gate. No tagged unions.
2. **RNG**: ship `src/state/roomrom_rng.h` mirroring NES `Random[13]`
   exactly; advance via ScrambleRandom port; expose
   `PROBE_RNG_SEED = RAM(0x0018)`.
3. **Matrix**: generate skeleton from drain + Z_04.asm grep; hand-fill
   incrementally; gate phase-close on probe-id coverage ≥ N families
   landed.

This pattern is drain-primary, NES-secondary, parity-replayable, and
unblocks parallel family fan-out in Phase 7.2+.
