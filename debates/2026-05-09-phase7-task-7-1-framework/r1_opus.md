# Round 1 — Opus

## Q1 — enemy_state.h alias collision: **(c) flat byte-slot + documented accessor macros**

Ground-truth check: `src/state/enemy_state.h:21-22` already does (c) — `ENEMY_PUSH_TIMER` and `ENEMY_FLYER_SPEED_FRAC` both `OBJ(0x0412, slot)`. `:108-115` adds Gohma overlay with explicit `aliases ENEMY_X` comments. The drain authors already converged on flat+accessor, with the alias as a feature not a bug.

NES citation: `reference/aldonunez/ObjVars.inc:7,24` — `ObjPushTimer := $412` and `Flyer_ObjSpeedFrac := $412` literally share the symbol. Tagged-union (a) lies about NES memory: same byte, different family-meaning is the whole point of NES scratch overlay. Sub-arrays (b) waste 16 RAM × 9 slots = ~144 bytes for cosmetic safety + breaks slot-indexed reads at `Z_04.asm:1221` (`LDA Random,X`).

Migration scope for Task 7.1: the existing header is in `src/state/enemy_state.h` (substrate). Phase 7 is RoomRom-rooted. Port the header to `RoomRom/src/roomrom_enemy_state.h`, add `_Static_assert(sizeof(ObjBuf) >= 0x4F0, ...)` per-alias-cluster collision proof, and bake the alias-pairs into a `docs/audit/enemy_alias_table.md` so family agents can grep-find their slots.

## Q2 — roomrom_rng.h design: **(a) NES Random[13] byte-for-byte port**

Verified at `reference/aldonunez/Z_07.asm:499-515` — `@ScrambleRandom` taps bit 1 of `$18` and `$19`, EORs them, ROR-chains through 13 bytes ($18..$24). Single-byte state widened to 16/32 (b/c) breaks every `LDA Random,X` slot-indexed read in enemy AI (`Z_04.asm` Wizzrobe align, drop tables, direction picks). Parity-blocker.

Concrete API: keep the master-plan-mandated signatures `void rng_seed(uint16_t)`, `uint16_t rng_next(void)`, `uint16_t rng_peek(void)` for probe ergonomics — but `rng_next` returns `(Random[1] << 8) | Random[0]` after one scramble step; `rng_seed` writes the seed across `Random[0..12]` (NES poke pattern from `tools/bizhawk_t38_enemy_nes_capture.lua:501` already does `40 41 42 43 44 45 46 47` to `$18..$1F`). `PROBE_RNG_SEED` = `&Random[0]` in M68K WRAM.

## Q3 — enemy_parity_matrix.md: **(b) generate skeleton, fill probe ids incrementally**

(a) hand-author = 3 hours of guesswork before any family code lands; rows about "RNG seed positions" and "probe id" are unknowable until Phase 1.5 captures + first family runtime exists. (c) defer = master plan blocks fan-out on this artifact, so deferring blocks Phase 7 entirely.

(b) executes today: grep `reference/aldonunez/Z_04.asm` for `Init` and `Update` enemy labels → ~30 rows. Cross-link with `src/game/enemies/enemy_dispatch.c` dispatch table. Hand-fill what's known (hitbox, damage from existing constants); leave `probe_id: PROBE_PENDING` placeholders for Phase 1.5 to fill. Family agents fan out against the skeleton; matrix grows row-by-row as captures land.

## Integrated framework recommendation

Single-commit blocking framework, Phase 7 root:

1. **`RoomRom/src/roomrom_enemy_state.h`** — port of `src/state/enemy_state.h` enemy slice with `_Static_assert` collision proofs. Aliases preserved + audit-table cross-ref.
2. **`RoomRom/src/roomrom_rng.h` + `.c`** — 13-byte `Random[]` array, `@ScrambleRandom` ROR-chain in `rng_next()`, master-plan APIs (`rng_seed`/`rng_next`/`rng_peek`). `#define PROBE_RNG_SEED` to M68K WRAM addr of `Random[0]`.
3. **`docs/audit/enemy_parity_matrix.md`** — skeleton from `Z_04.asm` grep + `enemy_dispatch.c`, ~30 rows, `PROBE_PENDING` placeholders.
4. **`docs/audit/enemy_alias_table.md`** — explicit alias pairs (`0x0412 = PUSH_TIMER | FLYER_SPEED_FRAC | JUMPER_VSPEED_HI | GOHMA_DIST_TRAVELED`) so family agents grep-find their byte before writing.

This unblocks 7.2-7.7 fan-out without violating Drain Rule D1 (drained `enemy_state.h` is primary; NES `ObjVars.inc` + `Z_07.asm` win ties as secondary). Aligns with Codex/Sonnet/Gemini convergence (c/a/b unanimous) and existing drain reality (header already (c)).

(Word count: ~520)
