# Drain Finding — Phase 3 Task 3.4 (native port) — cave trivials batch

**Per Rule D1 Gate 1.** Two trivial cave functions ported in one batch.
Both have **MATCH (trivial)** verdicts per Phase 3 summary lines 20-21.

## Targets

### `cave_update_person_state_delay_then_hide`

| Side | Path | Lines |
|------|------|-------|
| Native | `src/game/cave/cave_dispatch.c` | `cave_update_person_state_delay_then_hide` |
| Drain | `src/oracle/cave/cave_runtime.c` | 74-78 |
| NES asm | `reference/aldonunez/Z_01.asm` | 838 (UpdatePersonState_DelayThenHide) |
| NES vars | `reference/aldonunez/Variables.inc` | `CaveDelayTimer := $0029`, `ObjType+1 := $0350` (cave room type) |

#### Diff

| NES (Z_01.asm 838-) | Drain (74-78) | Native | Verdict |
|---------------------|---------------|--------|---------|
| `LDA CaveDelayTimer / BNE :+ / LDA #$00 / STA ObjType+1 :+` | `if (CAVE_DELAY_TIMER == 0) CAVE_ROOM_TYPE = 0` | `if (CAVE_DELAY_TIMER == 0u) cave_room_type_set(0u)` | **MATCH** |

### `cave_clear_prices_flag`

| Side | Path | Lines |
|------|------|-------|
| Native | `src/game/cave/cave_dispatch.c` | `cave_clear_prices_flag` |
| Drain | `src/oracle/cave/cave_runtime.c` | 70-72 |
| NES asm | `reference/aldonunez/Z_01.asm` | inline at ClearPricesCaveFlag |
| NES vars | `reference/aldonunez/Variables.inc` | `CaveFlags := $0413` |

#### Diff

| NES | Drain (70-72) | Native | Verdict |
|-----|---------------|--------|---------|
| `LDA CaveFlags / AND #$F7 / STA CaveFlags` | `CAVE_FLAGS &= 0xF7` | `cave_clear_prices_flag_inline()` (file-static helper, expands to `cave_flags_set(cave_flags_get() & 0xF7u)`) | **MATCH** |

## Verdict summary

**FULL MATCH.** Both functions are byte-for-byte semantic equivalents
of NES + drain. No deferred TODOs.

The native body of `cave_clear_prices_flag` is a one-line wrapper around
the file-static `cave_clear_prices_flag_inline` helper introduced in
the talk_shop port (commit `dcc0d322`). Public symbol exposed for the
Title.md cutover gate.

## Cutover gate

- Both share `NATIVE_CAVE_PERSON` gate with prior state-machine arms.
- Default OFF → oracle drain (drain MATCH).
- Defined ON → native (full MATCH; no behavioral divergence expected).

## Stance update

Phase 3 Task 3.4 (Stance: ADOPT) — trivials batched. Remaining cave
state-machine work for Phase 3 close:

- `cavert_update_person_state_textbox` — NEEDS-FULL-FINDING per Phase 3
  summary (cross-subsystem text rendering — defers to Phase 4 or its
  own dedicated finding).
- `cavert_update_cave_person` — top-level dispatch (9 states); NEEDS-
  FULL-FINDING per summary; can be ported once all 9 state arms have
  native equivalents.
- `cavert_try_take_item` / `cavert_try_take_room_item` — NEEDS-FULL-
  FINDING (item dispatch + sound trigger).
- `cavert_format_decimal_byte` / `cavert_write_prices_*` —
  NEEDS-FULL-FINDING (price formatter chain).

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc cited per process improvement from finding 3_2.
