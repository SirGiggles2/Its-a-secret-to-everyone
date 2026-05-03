# Drain Finding — Phase 3 Task 3.4 (native port) — `cave_update_talk_shop_or_door_charge`

**Per Rule D1 Gate 1.** Native rewrite vs drained C vs NES disassembly.
Largest cave state-machine arm yet. Drain MATCH (verdict) per Phase 3 summary.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/cave/cave_dispatch.c` | `cave_update_talk_shop_or_door_charge` body |
| Drained C | `src/oracle/cave/cave_runtime.c` | 228-283 |
| NES asm | `reference/aldonunez/Z_01.asm` | 666 (UpdateCavePersonState_TalkOrShopOrDoorCharge) |
| NES vars | `reference/aldonunez/Variables.inc` | `ObjX := $0070` (Link X), `ObjY := $0084` (Link Y), `CavePersonState := $00AD`, `CaveFlags := $0413`, `CaveItemIds := $0422`, `CavePrices := $0430`, `CaveSelectedWareIndex := $0438`, `LinkRupees := $066D`, `LinkHearts := $066F`, `CaveDoorRepairRupeeDelta := $067E`, `CaveRoomType := $0350` (alias for ObjType+1) |
| State accessors | `src/state/cave_state.h`, `src/state/combat_state.h` | various typed get/set + LINK_* macros |

## Per-block diff (3 sub-branches)

### Branch 1: cave-flag $01 not set → state=8 + door-repair bump

| NES (Z_01.asm) | Drain (cave_runtime.c 230-237) | Native (cave_dispatch.c) | Verdict |
|----------------|-------------------------------|--------------------------|---------|
| `LDA CaveFlags / AND #$01 / BNE main_path` | `if (!(CAVE_FLAGS & 1))` | `if (!(cave_flags_get() & 0x01u))` | **MATCH** |
| `LDA #$08 / STA CavePersonState` | `CAVE_PERSON_STATE = 8` | `CAVE_PERSON_STATE = 8u` | **MATCH** |
| `LDA CaveRoomType / CMP #$71 / BNE skip` | `if (CAVE_ROOM_TYPE == 0x71)` | `if (cave_room_type_get() == 0x71u)` | **MATCH** |
| `CLC / LDA #20 / ADC CaveDoorRepairRupeeDelta / STA CaveDoorRepairRupeeDelta` | `CAVE_DOOR_REPAIR_RUPEE_DELTA += 20` | `CAVE_DOOR_REPAIR_RUPEE_DELTA = (int8_t)(CAVE_DOOR_REPAIR_RUPEE_DELTA + 20)` | **MATCH** |
| `JSR SetRoomFlagUWItemState` | `progrt_set_room_flag_uw_item_state()` | **STAGE-1 STUB** — Phase 4 native port | DEFERRED |

### Branch 2: door-repair pending wait

| NES | Drain (238-239) | Native | Verdict |
|-----|-----------------|--------|---------|
| `LDA CaveDoorRepairRupeeDelta / BNE return` | `if (CAVE_DOOR_REPAIR_RUPEE_DELTA != 0) return` | same | **MATCH** |

### Branch 3: ware-purchase loop (slots 2..0)

| NES | Drain (240-282) | Native | Verdict |
|-----|-----------------|--------|---------|
| `LDX #$02 / @loop ... DEX / BPL` | `for (i = 2; i >= 0; --i)` | `for (signed int i = 2; i >= 0; --i)` | **MATCH** |
| `LDA CaveItemIds,X / AND #$3F / CMP #$3F / BEQ next` | `item = CAVE_WARE_ITEM(i) & 0x3F; if (item == 0x3F) continue` | `(unsigned char)(RAM(0x0422+i) & 0x3Fu); if == 0x3F continue` | **MATCH** |
| `LDA ObjX / CMP CaveWareXs,X / BNE next` | `if (RAM(0x0070) != CaveWareXs[i]) continue` | `if (RAM(0x0070) != k_cave_ware_xs[i]) continue` | **MATCH** |
| `LDA ObjY / SEC / SBC #$98 / JSR Abs / CMP #6 / BCS next` | `dist = z01_abs((Link_Y - 0x98)); if (dist >= 6) continue` | `cave_abs_inline(RAM(0x0084) - 0x98u); if >= 6 continue` | **MATCH** (z01_abs replaced by inline 6502 abs equivalent) |
| `STX CaveSelectedWareIndex` | `CAVE_SELECTED_WARE_INDEX = i` | `RAM(0x0438) = (unsigned char)i` | **MATCH** |
| `LDA CaveFlags / AND #$30` | `flags30 = CAVE_FLAGS & 0x30` | same | **MATCH** |
| flags30 ≠ 0 sub-branch with $10 gate, rupee gate, post_debit, state=5 | mirrored | mirrored (post_debit STUB) | **MATCH (state writes), DEFERRED (post_debit)** |
| flags30 == 0: cave_flag $02 → rupee gate + post_debit | mirrored | mirrored (post_debit STUB) | **MATCH (state writes), DEFERRED (post_debit)** |
| cave_flag $40 → min_hearts gate (room $6C → 64, else 0xB0) | mirrored | mirrored | **MATCH** |
| `JSR SetRoomFlagUWItemState` | `progrt_set_room_flag_uw_item_state()` | **STAGE-1 STUB** | DEFERRED |
| `LDA #$FF / STA CaveItemIds,X` | `CAVE_WARE_ITEM(i) = 0xFF` | `RAM(0x0422+i) = 0xFFu` | **MATCH** |
| `JSR TakeItem` | `c_take_item(item)` | **STAGE-1 STUB** | DEFERRED |
| `LDA #30 / JSR CueTransferBufAndAdvanceState` | `z01_cue_transfer_buf_and_advance_state(30)` | **STAGE-1 STUB** | DEFERRED |
| `LDA #$40 / STA CaveDelayTimer` | `CAVE_DELAY_TIMER = 64` | `CAVE_DELAY_TIMER = 64u` | **MATCH** |
| `JSR ClearPricesCaveFlag` | `cavert_clear_prices_cave_flag()` | `cave_clear_prices_flag_inline()` (inline) | **MATCH** (drain trivial inlined to avoid cavert_ shim from src/oracle/) |

## Verdict summary

**STAGE-1 SHAPE MATCH.** All 3 sub-branches correctly dispatched. State
writes (CavePersonState, SelectedWareIndex, DelayTimer, ware-clear,
DoorRepairDelta) and rupee/heart/distance gates are byte-for-byte
equivalents of NES + drain.

Inline replacements:
- `z01_abs` → `cave_abs_inline` (6502 abs of signed byte; corert_abs trivial).
- `cavert_clear_prices_cave_flag` → `cave_clear_prices_flag_inline`
  (single-bit flag clear; drain trivial inlined to avoid cross-tree
  oracle shim from src/game/).

Cross-subsystem shims deferred to Phase 4:
- `progrt_set_room_flag_uw_item_state` (progress flag write).
- `cave_post_debit(price)` (deferred LINK_RUPEES debit + HUD anim).
- `cave_take_item(item)` (item state mutation + sound trigger).
- `cave_cue_transfer_buf_and_advance_state(value)` (text transfer cue + state++).

## Cutover gate

- Title.md callsite `z01_update_cave_person_state_talk_or_shop_or_door_charge`
  shares `NATIVE_CAVE_PERSON` gate with prior state-machine arms.
- Default OFF → oracle drain (drain MATCH verdict).
- Defined ON → native (stage-1: shop-flow flag/state writes work; no
  rupee debit, no item take, no text cue → ware-purchase appears stuck
  until Phase 4 lands the cross-subsystem shims).
- RoomRom links it but doesn't call it (cave_tick stub).

## Stance update

Phase 3 Task 3.4 (Stance: ADOPT/EXTEND) — second cave state-machine arm
ported. Remaining state-machine arms: hint_or_money_game,
person_state_textbox, person_state_delay_then_hide. Continuing top-down
per cook-prompt order.

Once full state-machine surface ported + cross-subsystem deps land, the
top-level `cavert_update_cave_person` dispatch table promotes to native
jump-table calling these arms. That promotion is a separate Gate 1
finding.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc cited per process improvement from finding 3_2.
