# Drain Finding — Phase 3 Task 3.4 (native port) — cave price-formatter chain

**Per Rule D1 Gate 1.** Three NEEDS-FULL-FINDING items resolved + ported
in one batch: `cavert_format_decimal_byte`, `cavert_write_prices_to_dynamic_transfer_buf`,
`cavert_write_prices_transfer_buf`.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/cave/cave_dispatch.c` | `cave_format_decimal_byte`, `cave_write_prices_to_dynamic_transfer_buf`, `cave_write_prices_transfer_buf`, file-static `cave_swap_space_and_sign_inline` |
| Drain | `src/oracle/cave/cave_runtime.c` | 56-67 (swap, prepend), 80-94 (format), 96-129 (write_prices_*) |
| NES asm | `reference/aldonunez/Z_01.asm` | 449-525 (WritePricesTransferBuf + WritePricesToDynamicTransferBuf + IncCaveState), 539-546 (SwapSpaceAndSign), 3129-3144 (FormatDecimalByte) |
| NES vars | `reference/aldonunez/Variables.inc` + `CaveVars.inc` | `DynTileBuf := $0302` (so DynTileBuf+3 = $0305, +5/6/7 = $0307/8/9), `CaveCurPriceIndex := $042E`, `CaveCurPriceOffset := $042F`, ZP `$01..$04` = scratch |
| State accessors | `src/state/cave_state.h` | `CAVE_TMP1..4` (= ZP_TMP1..4 = RAM($0001..$0004)), `CAVE_TRANSFER_BUF_PRICE_HUNDREDS/TENS/UNITS(off)` (= RAM($0307+off / $0308+off / $0309+off)), `CAVE_TRANSFER_PRICE_COUNT/OFFSET`, `cave_flags_get`, `CAVE_DELAY_TIMER` |

## Drain MATCH proof — `cavert_format_decimal_byte`

| NES (Z_01.asm 3129-3144) | Drain (cave_runtime.c 80-94) | Verdict |
|--------------------------|-------------------------------|---------|
| `JSR DivideBy10 / STA $03` | `unsigned char units = val % 10; CAVE_TMP3 = units` (after deferred store) | **MATCH** — DivideBy10 returns Y=quotient, A=remainder; remainder = val mod 10. |
| `TYA / JSR DivideBy10 / CPY #0 / BNE @WriteHighChars / LDY #$24 / CMP #0 / BNE @WriteHighChars / TYA / @WriteHighChars: STA $02 / STY $01` | `rest = val/10; tens = rest%10; hundreds = rest/10; if (hundreds==0) {hundreds=$24; if (tens==0) tens=$24;}; CAVE_TMP2 = tens; CAVE_TMP1 = hundreds` | **MATCH** — both encode the cascading leading-zero suppression: hundreds 0→$24, tens 0→$24 only if hundreds also 0. |

**Verdict: cavert_format_decimal_byte FULL MATCH** (promotes Phase 3
summary verdict from NEEDS-FULL-FINDING to MATCH).

## Drain MATCH proof — `cavert_swap_space_and_sign`

| NES (Z_01.asm 539-546) | Drain (cave_runtime.c 61-67) | Verdict |
|------------------------|-------------------------------|---------|
| `CMP #$24 / BNE :+ / TAX / LDA $04 / STX $04 / :+ / RTS` | `if (d0 == 0x24) { tmp = CAVE_TMP4; CAVE_TMP4 = d0; d0 = tmp; } return d0` | **MATCH** — both swap A and ZP $04 when A == $24. The drain stores `d0` (which is $24 in the swap branch) into TMP4, then returns the saved TMP4 — identical to NES TAX/LDA/STX. |

**Verdict: cavert_swap_space_and_sign FULL MATCH** (promotes summary).

## Drain MATCH proof — `cavert_write_prices_to_dynamic_transfer_buf`

| NES (Z_01.asm 455-517) | Drain (cave_runtime.c 96-124) | Verdict |
|------------------------|-------------------------------|---------|
| `STA DynTileBuf+3` | `RAM(0x0305) = price_char` | **MATCH** — DynTileBuf+3 = $0305. |
| `LDX #0 / STX CaveCurPriceIndex / STX CaveCurPriceOffset` | `CAVE_TRANSFER_PRICE_COUNT = 0; CAVE_TRANSFER_PRICE_OFFSET = 0` | **MATCH** — CAVE_TRANSFER_PRICE_COUNT is the misleading drain alias for $042E (NES `CaveCurPriceIndex`) per CaveVars.inc. |
| `@LoopPrice: LDA CavePrices,X / BNE @Format / LDX #$24 / STX $01,$02,$03 / JMP @Align` | `if (price == 0) { CAVE_TMP1 = $24; CAVE_TMP2 = $24; CAVE_TMP3 = $24; }` | **MATCH** — zero-price special case writes spaces. |
| `@Format: JSR FormatDecimalByte` | `else cavert_format_decimal_byte(price)` | **MATCH** |
| `LDX #$24 / LDA CaveFlags / ASL / BCC @Align / LDX #$62 / @Align: STX $04` | `dash = (CAVE_FLAGS & 0x80) ? 98 : 0x24; CAVE_TMP4 = dash` | **MATCH** — ASL on CaveFlags shifts bit 7 into carry; BCC = no negative. NES branch correctly maps to drain `& 0x80` test. |
| `LDA $02 / JSR SwapSpaceAndSign / STA DynTileBuf+6,Y` | `CAVE_TRANSFER_BUF_PRICE_TENS(off) = cavert_swap_space_and_sign(CAVE_TMP2)` | **MATCH** — DynTileBuf+6+Y = $0308+off = TENS slot. |
| `LDA $01 / JSR SwapSpaceAndSign / STA DynTileBuf+5,Y` | `CAVE_TRANSFER_BUF_PRICE_HUNDREDS(off) = cavert_swap_space_and_sign(CAVE_TMP1)` | **MATCH** — DynTileBuf+5+Y = $0307+off = HUNDREDS slot. |
| `LDA $03 / STA DynTileBuf+7,Y` | `CAVE_TRANSFER_BUF_PRICE_UNITS(off) = CAVE_TMP3` | **MATCH** — DynTileBuf+7+Y = $0309+off = UNITS slot. |
| `LDA CaveCurPriceOffset / CLC / ADC #4 / STA CaveCurPriceOffset` | `CAVE_TRANSFER_PRICE_OFFSET = off + 4` | **MATCH** |
| `INC CaveCurPriceIndex / LDX CaveCurPriceIndex / CPX #3 / BNE @LoopPrice` | `price_index++; CAVE_TRANSFER_PRICE_COUNT = price_index; while (price_index < CAVE_WARES_PER_ROOM)` | **MATCH** — CAVE_WARES_PER_ROOM = 3u. |
| `LDA #$0A / STA ObjTimer+1 / BNE IncCaveState` | `CAVE_DELAY_TIMER = 10; z01_cue_transfer_buf_and_advance_state(10)` | **MATCH** — drain calls cue+state++ shim; ObjTimer+1 = $0029 = CAVE_DELAY_TIMER. |

**Verdict: cavert_write_prices_to_dynamic_transfer_buf FULL MATCH**
(promotes summary).

## Drain MATCH proof — `cavert_write_prices_transfer_buf`

| NES (Z_01.asm 449-454) | Drain (cave_runtime.c 126-129) | Verdict |
|------------------------|-------------------------------|---------|
| `JSR CopyPriceListTemplate / LDA #$21 / [fall-through]` | `z01_copy_price_list_template(); cavert_write_prices_to_dynamic_transfer_buf(33)` | **MATCH** — $21 = 33 = "X" tile. |

**Verdict: cavert_write_prices_transfer_buf FULL MATCH** (promotes
summary).

## Native port — per-block diff

| Function | Drain | Native | Verdict |
|----------|-------|--------|---------|
| swap helper | `cavert_swap_space_and_sign` (file-static) | `cave_swap_space_and_sign_inline` (file-static) | **MATCH** |
| format_decimal_byte | drain body | `cave_format_decimal_byte` — pure C arithmetic, no shims | **FULL MATCH** |
| write_prices_to_dynamic_transfer_buf | drain body using `c_animate_item_object` shim... wait drain doesn't use that — uses `cavert_format_decimal_byte` (now native equiv) + `cavert_swap_space_and_sign` (now inline native) + `z01_cue_transfer_buf_and_advance_state` | `cave_write_prices_to_dynamic_transfer_buf` — calls native `cave_format_decimal_byte` + `cave_swap_space_and_sign_inline`; cue_transfer STAGE-1 STUB | **MATCH (12 ops), DEFERRED (1 cue)** |
| write_prices_transfer_buf | `z01_copy_price_list_template + cavert_write_prices_to_dynamic_transfer_buf(33)` | `// TODO copy_price_list_template; cave_write_prices_to_dynamic_transfer_buf(0x21u)` | **MATCH (call shape), DEFERRED (template copy)** |

## Native verdict

**STAGE-1 SHAPE MATCH** for the chain. The two pure-leaf functions
(`format_decimal_byte` + `swap_space_and_sign`) are FULL MATCH (no
deferred ops). Two write_prices functions defer two cross-subsystem
shims:

- `cue_transfer_buf_and_advance_state(value)` — cues VBlank text
  transfer + state++. Phase 4 native port (text rendering pipeline).
- `copy_price_list_template` — copies a 30-byte ROM template into the
  static transfer buf. Phase 4 native port (or earlier — only needs
  `memcpy` from a baked-in const + RAM write).

When Phase 4 lands those, this commit's `// TODO` comments collapse
and the chain becomes FULL MATCH end-to-end.

## Cutover gate

- Title.md callsites `z01_format_decimal_byte`, `z01_write_prices_to_dynamic_transfer_buf`,
  `z01_write_prices_transfer_buf` share new `NATIVE_CAVE_FORMAT` gate.
- Default OFF → oracle drain (drain FULL MATCH per above).
- Defined ON → native (format leaf is fully working; write_prices have
  deferred cue + template copy, so price display works but state++
  doesn't auto-advance and copy_price_list_template no-ops the static
  buf seed).

Independent gate from `NATIVE_CAVE_PERSON` because the formatter chain
can be flipped on/off independently — they have no dependency on the
state-machine arms.

## Stance update

Phase 3 Task 3.4 (Stance: ADOPT/EXTEND) — formatter chain ported.
Promotes 3 NEEDS-FULL-FINDING entries in Phase 3 summary to FULL MATCH.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc + CaveVars.inc cited per process improvement from finding 3_2.
