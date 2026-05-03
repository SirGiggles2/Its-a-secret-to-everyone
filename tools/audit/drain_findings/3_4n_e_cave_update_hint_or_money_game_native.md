# Drain Finding — Phase 3 Task 3.4 (native port) — `cave_update_hint_or_money_game`

**Per Rule D1 Gate 1.** Native rewrite vs drained C vs NES disassembly.
Drain MATCH (verdict) per Phase 3 summary.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/cave/cave_dispatch.c` | `cave_update_hint_or_money_game` body |
| Drained C | `src/oracle/cave/cave_runtime.c` | 285-324 |
| NES asm | `reference/aldonunez/Z_01.asm` | 851-991 (UpdateCavePersonState_HintOrMoneyGame + PrependSignToPrice helper) |
| NES tables | `reference/aldonunez/Z_01.asm` | 562 (TextboxLineAddrsLo `$C4 $E4 $A4`), 845 (HintCaveTextSelectors0 `$14 $14 $16`), 848 (HintCaveTextSelectors1 `$14 $18 $1A` — adjacent in ROM, indexed past selectors0 when base_off=3) |
| NES vars | `reference/aldonunez/Variables.inc` | `CavePersonState := $00AD`, `PersonTextSelector := $0415`, `PersonTextIndex := $0416`, `PersonTextPtr := $045F`, `Tune0Request := $0604` (alias for cave text-tick sfx slot), `CavePrices := $0430`, `MoneyGameAmounts := $0448`, `CaveSelectedWareIndex := $0438`, `InvRupees := $066D`, `ObjType+1 := $0350` (=cave room type) |
| State accessors | `src/state/cave_state.h` | `CAVE_TEXT_SELECTOR/_LINE_ADDR_LO/_CHAR_INDEX/_TICK_SFX/_PERSON_STATE/_TRANSFER_BUF_PRICE_SIGN` macros, `LINK_RUPEES`, `cave_flags_get`, `cave_room_type_get` |

## Per-block diff (3 sub-branches)

### Branch 1: hint cave (CAVE_FLAGS & 0x10)

| NES (Z_01.asm 854-886) | Drain (cave_runtime.c 286-294) | Native (cave_dispatch.c) | Verdict |
|------------------------|--------------------------------|--------------------------|---------|
| `LDA CaveFlags / AND #$10 / BEQ @MoneyOrGiveaway` | `if (CAVE_FLAGS & 0x10)` | `if (cave_flags_get() & 0x10u)` | **MATCH** |
| `LDA #$00 / LDY ObjType+1 / CPY #$75 / BEQ : / LDA #$03 :` | `base_off = (CAVE_ROOM_TYPE == 0x75) ? 0 : 3` | `base_off = (cave_room_type_get() == 0x75u) ? 0u : 3u` | **MATCH** |
| `CLC / ADC CaveChosenIndex / TAY` | `sel_idx = base_off + CAVE_SELECTED_WARE_INDEX` | `sel_idx = base_off + RAM(0x0438)` | **MATCH** |
| `LDA HintCaveTextSelectors0,Y / STA PersonTextSelector` | `CAVE_TEXT_SELECTOR = HintCaveTextSelectors0[sel_idx]` | `CAVE_TEXT_SELECTOR = k_hint_cave_text_selectors[sel_idx]` (6-byte combined table baked in) | **MATCH** |
| `LDA TextboxLineAddrsLo+2 / STA PersonTextPtr` | `CAVE_TEXT_LINE_ADDR_LO = TextboxLineAddrsLo[2]` | `CAVE_TEXT_LINE_ADDR_LO = k_textbox_line_addrs_lo[2]` | **MATCH** |
| `LDA #$00 / STA PersonTextIndex` | `CAVE_TEXT_CHAR_INDEX = 0` | `CAVE_TEXT_CHAR_INDEX = 0u` | **MATCH** |
| `JSR ClearPricesCaveFlag` | `cavert_clear_prices_cave_flag()` | `cave_clear_prices_flag_inline()` | **MATCH** |
| `LDA #$1E / JMP CueTransferBufAndAdvanceState` | `z01_cue_transfer_buf_and_advance_state(30)` | **STAGE-1 STUB** — Phase 4 | DEFERRED |

### Branch 2: door-charge variant (CAVE_ROOM_TYPE >= $7B)

| NES (Z_01.asm 893-912) | Drain (296-303) | Native | Verdict |
|------------------------|-----------------|--------|---------|
| `LDA ObjType+1 / CMP #$7B / BCC @MoneyGame` | `if (CAVE_ROOM_TYPE >= 0x7B)` | `if (cave_room_type_get() >= 0x7Bu)` | **MATCH** |
| `JSR CopyPriceListTemplate` | `z01_copy_price_list_template()` | **STAGE-1 STUB** | DEFERRED |
| `LDA #$24 / JSR WritePricesToDynamicTransferBuf` | `cavert_write_prices_to_dynamic_transfer_buf(36)` | **STAGE-1 STUB** | DEFERRED |
| `LDA #$08 / STA Tune0Request` | `CAVE_TEXT_TICK_SFX = 8` | `CAVE_TEXT_TICK_SFX = 8u` | **MATCH** |
| `JSR SetRoomFlagUWItemState` | `progrt_set_room_flag_uw_item_state()` | **STAGE-1 STUB** | DEFERRED |
| `LDA #$08 / STA ObjState+1` | `CAVE_PERSON_STATE = 8` | `CAVE_PERSON_STATE = 8u` | **MATCH** |
| `LDA CavePrices+1 / JMP PostCredit` | `z01_post_credit(CAVE_PRICE(1))` | **STAGE-1 STUB** | DEFERRED |

### Branch 3: money game

| NES (Z_01.asm 916-991) | Drain (305-323) | Native | Verdict |
|------------------------|-----------------|--------|---------|
| `LDA InvRupees / CMP #$0A / BCC L493A_Exit` | `if (LINK_RUPEES < 0x0A) return` | `if ((unsigned char)LINK_RUPEES < 0x0Au) return` | **MATCH** |
| `LDA #$08 / STA Tune0Request` | `CAVE_TEXT_TICK_SFX = 8` | `CAVE_TEXT_TICK_SFX = 8u` | **MATCH** |
| `LDY #$02 :- / LDA MoneyGameAmounts,Y / STA CavePrices,Y / DEY / BPL :-` (3-iter copy) | `CAVE_PRICE(0..2) = CAVE_PRIZE_ORDER(0..2)` | `RAM(0x0430+0..2) = RAM(0x0448+0..2)` | **MATCH** |
| `JSR WritePricesTransferBuf` | `cavert_write_prices_transfer_buf()` | **STAGE-1 STUB** | DEFERRED |
| `LDA #$08 / STA ObjState+1` | `CAVE_PERSON_STATE = 8` | `CAVE_PERSON_STATE = 8u` | **MATCH** |
| `LDY #$01 / LDA MoneyGameAmounts+0 / JSR PrependSignToPrice` ×3 (offsets 1, 5, 9) | `cavert_prepend_sign_to_price(CAVE_PRIZE_ORDER(0..2), 1/5/9)` | `cave_prepend_sign_to_price_inline(RAM(0x0448+0..2), 1u/5u/9u)` | **MATCH** (drain trivial inlined; sign tile = 100 if amount in {$14,$32}, else 98 — verified against PrependSignToPrice asm at Z_01.asm:980) |
| Final dispatch: `chosen = CaveSelectedWareIndex; amount = MoneyGameAmounts[chosen]; if (amount == $14 || $32) PostCredit(amount); else PostDebit(amount)` | `chosen = CAVE_SELECTED_WARE_INDEX; amount = CAVE_PRIZE_ORDER(chosen); if (amount == 0x14 || 0x32) z01_post_credit(amount); else z01_post_debit(amount)` | `chosen = RAM(0x0438); amount = RAM(0x0448 + chosen); if (...) post_credit STUB else post_debit STUB` | **MATCH (control flow), DEFERRED (rupee mutators)** |

## Verdict summary

**STAGE-1 SHAPE MATCH.** All 3 sub-branches correctly dispatched. Table
indexing, branch thresholds, RAM writes, and sign-prepend logic are
byte-for-byte equivalents of NES + drain.

Inline replacements:
- `cavert_clear_prices_cave_flag` → `cave_clear_prices_flag_inline` (file-scope helper from prior commit).
- `cavert_prepend_sign_to_price(val, off)` → `cave_prepend_sign_to_price_inline` (file-scope; trivial per drain — sign tile 100 when val ∈ {$14,$32}, else 98; writes to `CAVE_TRANSFER_BUF_PRICE_SIGN(off)` = `RAM(0x0306 + off)`).

Tables baked in inline at file scope (independent of `src/data/*.inc` transpile path):
- `k_hint_cave_text_selectors[6]` — combines NES HintCaveTextSelectors0 + HintCaveTextSelectors1.
- `k_textbox_line_addrs_lo[3]` — NES TextboxLineAddrsLo.

Cross-subsystem shims deferred to Phase 4:
- `cue_transfer_buf_and_advance_state(value)` — text transfer + state++.
- `copy_price_list_template` — copy ROM template into transfer buf.
- `write_prices_to_dynamic_transfer_buf(char_param)` — formatter.
- `write_prices_transfer_buf` — formatter.
- `progrt_set_room_flag_uw_item_state` — progress flag write.
- `cave_post_credit(amount)` / `cave_post_debit(amount)` — deferred LINK_RUPEES adjustments + HUD anim.

## Cutover gate

- Title.md callsite `z01_update_cave_person_state_hint_or_money_game`
  shares `NATIVE_CAVE_PERSON` gate.
- Default OFF → oracle drain (drain MATCH verdict).
- Defined ON → native (stage-1: state/text/flag writes work; no rupee
  movement, no text cue, no template/price formatter — hint/money game
  appears stuck waiting on Phase 4).
- RoomRom links it but doesn't call it (cave_tick stub).

## Stance update

Phase 3 Task 3.4 (Stance: ADOPT/EXTEND) — third cave state-machine arm
ported. Remaining state-machine arms: `cavert_update_person_state_textbox`
(NEEDS-FULL-FINDING per Phase 3 summary; cross-subsystem text rendering)
and `cavert_update_person_state_delay_then_hide` (trivial). Then the
top-level `cavert_update_cave_person` dispatch table itself.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc + Z_01.asm:980 (PrependSignToPrice helper) cited per
  process improvement from finding 3_2.
