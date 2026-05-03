# Drain Finding — Phase 3 Task 3.4 (native port) — `cave_update_transfer_prices`

**Per Rule D1 Gate 1.** Native rewrite vs drained C vs NES disassembly.
First state-machine arm port; introduces the `NATIVE_CAVE_PERSON` gate.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/cave/cave_dispatch.c` | `cave_update_transfer_prices` body |
| Drained C | `src/oracle/cave/cave_runtime.c` | 220-226 |
| NES asm | `reference/aldonunez/Z_01.asm` | 442+ (UpdateCavePersonState_TransferPrices) |
| NES vars | `reference/aldonunez/Variables.inc` | `CavePersonState := $00AD`, `CaveFlags := $0413` |
| State accessor | `src/state/cave_state.h` | `cave_flags_get`, `CAVE_PERSON_STATE = RAM(0x00AD)` macro |

## Per-block diff

| NES (Z_01.asm 442-) | Drain (cave_runtime.c 220-226) | Native (cave_dispatch.c) | Verdict |
|---------------------|--------------------------------|--------------------------|---------|
| `LDA CaveFlags / AND #$08 / BEQ skip_to_inc_state` | `if (!(CAVE_FLAGS & 8))` | `if (!(cave_flags_get() & 0x08u))` | **MATCH** |
| `INC CavePersonState / RTS` (skip path advances state) | `z01_inc_cave_state()` (transpile shim → CavePersonState++) | `CAVE_PERSON_STATE = (uint8_t)(CAVE_PERSON_STATE + 1u)` (inline state++) | **MATCH** (semantically; inlined to avoid z01_ shim) |
| `JSR WritePricesTransferBuf / RTS` | `cavert_write_prices_transfer_buf()` | **STAGE-1 STUB** — Phase 4 BCD formatter port | DEFERRED |

## Verdict summary

**STAGE-1 SHAPE MATCH.** Flag dispatch + state-advance arm are byte-for-byte
equivalents of NES + drain. The price-formatter body (BCD digit write into
transfer buf) is deferred to a future Phase 4 sub-task because it chains
into `cavert_write_prices_to_dynamic_transfer_buf` +
`cavert_format_decimal_byte`, both NEEDS-FULL-FINDING per Phase 3 summary
— porting the formatter prematurely would skip required Gate 1 coverage.

`z01_inc_cave_state` is replaced by an inline `CAVE_PERSON_STATE++` to
satisfy the "no transpile-bridge shims in src/game/" rule (debate 006 D2).
The macro expands to `RAM(0x00AD)` per cave_state.h, so the byte
written matches NES INC CavePersonState exactly.

## Cutover gate

- New gate: `NATIVE_CAVE_PERSON` for state-machine update handlers.
  Distinct from `NATIVE_CAVE` (init lifecycle) and `NATIVE_CAVE_DRAW`
  (render pass). Each can be enabled independently — important because
  the cave_update_cave_person dispatch table (9 states) is the riskiest
  cutover (per Phase 3 summary jump-table caveat) and warrants separate
  toggle.
- Title.md callsite `z01_update_cave_person_state_transfer_prices`
  (src/gen/z_01.c, hand-written outside auto-region) gates on
  `NATIVE_CAVE_PERSON`.
- Default OFF → oracle drain `cavert_update_transfer_prices` (drain
  MATCH verdict).
- Defined ON → native `cave_update_transfer_prices` (stage-1: state++
  works, price formatter no-ops → cave price text never appears until
  Phase 4 lands).
- RoomRom links it but doesn't yet call it (cave_tick stub).

## Stance update

Phase 3 Task 3.4 (Stance: ADOPT/EXTEND) — first cave state-machine arm
ported. Future arms (talk_shop_or_door_charge, hint_or_money_game,
person_state_textbox, person_state_delay_then_hide) port one-by-one
behind the same `NATIVE_CAVE_PERSON` gate. Once full state-machine
surface ports + drain finding promotes to FULL MATCH (native), the
top-level `cavert_update_cave_person` dispatch table can be ported as
a single native jump table calling these native arms.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc cited per process improvement from finding 3_2.
