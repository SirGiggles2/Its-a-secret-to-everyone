# Drain Finding — Phase 3 Task 3.4 (native port) — `cave_update_cave_person`

**Per Rule D1 Gate 1.** Top-level cave-person orchestrator. **NEEDS FULL
FINDING** in Phase 3 summary; this is the full block-by-block diff +
native port in one finding (drain MATCH proof + native equivalence).

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/cave/cave_dispatch.c` | `cave_update_cave_person` body |
| Drained C | `src/oracle/cave/cave_runtime.c` | 326-353 |
| NES asm | `reference/aldonunez/Z_01.asm` | 300-368 (UpdateCavePerson + JumpTable) |
| NES vars | `reference/aldonunez/Variables.inc` | `FrameCounter := $0015`, `ObjState := $00AC`, `ObjState+1 := $00AD` (= CavePersonState), `ButtonsPressed := $00F8`, `ObjType+1 := $0350` (cave room type), `Tune1Request := $0602`, `SelectedItemSlot := $0656`, `InvLetter := $0666` |
| State accessors | `src/state/cave_state.h` | `CAVE_PERSON_STATE = RAM($00AD)`, `CAVE_LINK_ACTION_TIMER = RAM($00AC)` (note: drain alias name, but it's actually NES ObjState — bit $40 = halted), `CAVE_LINK_INPUT_FLAGS = RAM($00F8)`, `CAVE_ROOM_SCRIPT_STATE = RAM($0666)` (alias for InvLetter per finding 3_2b), `cave_room_type_get`/`cave_room_type_set` |

## Drain MATCH proof — block-by-block

### Block 1: state-4 frame-skip

| NES (Z_01.asm 304-310) | Drain (cave_runtime.c 326-328) | Verdict |
|------------------------|--------------------------------|---------|
| `LDA ObjState+1 / CMP #$04 / BNE :+ / LDA FrameCounter / AND #$01 / BNE @UpdateCavePersonDirect / :+` | `unsigned char state = CAVE_PERSON_STATE; if (!(state == 4 && (RAM(0x0015) & 1)))` | **MATCH** — when state==4 AND FrameCounter&1, NES skips the draw block; drain's negated condition produces same skip. |

### Block 2: DrawCavePerson + medicine-shop letter logic

| NES (311-353) | Drain (329-340) | Verdict |
|---------------|-----------------|---------|
| `JSR DrawCavePerson` | `cavert_draw_cave_person(slot)` | **MATCH** |
| `LDA ObjType+1 / CMP #$74 / BNE @DrawItems` | `if (CAVE_ROOM_TYPE == 0x74 && ...)` | **MATCH** — drain combines into single `&&`. |
| `LDA InvLetter / CMP #$02 / BEQ @DrawItems` | `... && CAVE_ROOM_SCRIPT_STATE != 2` | **MATCH** — letter==2 means used, NES skips letter logic; drain inverted to "continue if not used". CAVE_ROOM_SCRIPT_STATE is the typed alias for $0666 = InvLetter (per cave_state.h:121-127 + finding 3_2b). |
| `LDY SelectedItemSlot / CPY #$0F / BNE @Unhalt / LDA ButtonsPressed / AND #$40 / BNE @UseLetter` | `if (RAM(0x0656) == 0x0F && (CAVE_LINK_INPUT_FLAGS & 0x40))` | **MATCH** — slot==$0F AND B-pressed → use letter. |
| `@UseLetter: LDA #$04 / STA Tune1Request / INC InvLetter / LDA #$07 / STA SelectedItemSlot` | `RAM(0x0602) = 4; CAVE_ROOM_SCRIPT_STATE++; RAM(0x0656) = 7` | **MATCH** — sets sfx, bumps letter state, selects potion. |
| `@Unhalt: LDA ObjState / CMP #$40 / BNE :+ / JSR UnhaltLink / :+ / RTS` | `if (CAVE_LINK_ACTION_TIMER == 0x40) z01_unhalt_link(); return` | **MATCH** — `UnhaltLink` (Z_01.asm:100) = `LDA #$00 / STA ObjState`, exact equivalent of clearing $00AC. |

### Block 3: DrawCaveItems

| NES (354-355) | Drain (341) | Verdict |
|---------------|-------------|---------|
| `@DrawItems: JSR DrawCaveItems` | `cavert_draw_cave_items()` | **MATCH** |

### Block 4: 9-state jump-table dispatch

| NES idx | NES target (Z_01.asm 360-368) | Drain switch (cave_runtime.c 343-353) | Verdict |
|---------|-------------------------------|---------------------------------------|---------|
| 0 | UpdateCavePersonState_TransferPrices | `cavert_update_transfer_prices` | **MATCH** |
| 1 | UpdatePersonState_Textbox | `cavert_update_person_state_textbox` | **MATCH** |
| 2 | UpdateCavePersonState_TalkOrShopOrDoorCharge | `cavert_update_talk_shop_or_door_charge` | **MATCH** |
| 3 | UpdatePersonState_CueTransferBlankPersonWares | `z01_cue_transfer_blank_person_wares` | **MATCH** |
| 4 | UpdatePersonState_DelayThenHide | `cavert_update_person_state_delay_then_hide` | **MATCH** |
| 5 | UpdateCavePersonState_HintOrMoneyGame | `cavert_update_hint_or_money_game` | **MATCH** |
| 6 | UpdatePersonState_CueTransferBlankPersonWares | `z01_cue_transfer_blank_person_wares` | **MATCH** (same as 3) |
| 7 | UpdatePersonState_Textbox | `cavert_update_person_state_textbox` | **MATCH** (same as 1) |
| 8 | UpdateCavePersonState_DoNothing | `break` (no-op) | **MATCH** |

## Drain verdict

**FULL MATCH.** Drain `cavert_update_cave_person` is byte-for-byte
semantic equivalent of NES `UpdateCavePerson` + JumpTable. No off-by-
one, no missed branch. Promotes Phase 3 summary verdict from
NEEDS-FULL-FINDING to FULL MATCH.

## Native port — per-block diff

| Block | Drain | Native (cave_dispatch.c) | Verdict |
|-------|-------|--------------------------|---------|
| state-4 frame-skip | `if (!(state == 4 && (RAM(0x0015) & 1)))` | same; `state` const-bound | **MATCH** |
| DrawCavePerson | `cavert_draw_cave_person(slot)` | `cave_draw_person(slot)` (native, finding 3_4n) | **MATCH** |
| medicine-shop check | `if (CAVE_ROOM_TYPE == 0x74 && CAVE_ROOM_SCRIPT_STATE != 2)` | `if (cave_room_type_get() == 0x74u && CAVE_ROOM_SCRIPT_STATE != 2u)` | **MATCH** |
| letter use | RAM writes + `CAVE_ROOM_SCRIPT_STATE++` | same RAM writes; `CAVE_ROOM_SCRIPT_STATE = (uint8_t)(... + 1u)` | **MATCH** |
| @Unhalt | `if (CAVE_LINK_ACTION_TIMER == 0x40) z01_unhalt_link()` | `if (CAVE_LINK_ACTION_TIMER == 0x40u) CAVE_LINK_ACTION_TIMER = 0u` (inlined NES UnhaltLink) | **MATCH** (z01_unhalt_link shim replaced with inline; NES UnhaltLink at Z_01.asm:100 is `LDA #$00 / STA ObjState`) |
| DrawCaveItems | `cavert_draw_cave_items()` | `cave_draw_items()` (native, finding 3_4n_b) | **MATCH** |
| state 0 | `cavert_update_transfer_prices()` | `cave_update_transfer_prices()` (native, finding 3_4n_c) | **MATCH** |
| state 1 | `cavert_update_person_state_textbox()` | **STAGE-1 STUB** | DEFERRED (Phase 4 textbox port) |
| state 2 | `cavert_update_talk_shop_or_door_charge()` | `cave_update_talk_shop_or_door_charge()` (native, finding 3_4n_d) | **MATCH** |
| state 3 | `z01_cue_transfer_blank_person_wares()` | **STAGE-1 STUB** | DEFERRED (Phase 4 cue_transfer port) |
| state 4 | `cavert_update_person_state_delay_then_hide()` | `cave_update_person_state_delay_then_hide()` (native, finding 3_4n_g) | **MATCH** |
| state 5 | `cavert_update_hint_or_money_game()` | `cave_update_hint_or_money_game()` (native, finding 3_4n_e) | **MATCH** |
| state 6 | (= state 3) | **STAGE-1 STUB** | DEFERRED |
| state 7 | (= state 1) | **STAGE-1 STUB** | DEFERRED |
| state 8 | `break` | `break` | **MATCH** |

## Native verdict

**STAGE-1 SHAPE MATCH.** Top-level dispatch + 5 of 9 state arms are
native + verified. 4 arms (1, 3, 6, 7) stubbed pending Phase 4
text-rendering / cue-transfer ports.

Defining `NATIVE_CAVE_PERSON` in Title.md:
- Working: medicine-shop letter logic, ware purchase, hint cave (sans
  text rendering), door charge, money game, delay-then-hide.
- Broken: dialog text doesn't render (state 1/7), state 3/6 transitions
  no-op (cue-transfer hooks).

Default OFF until Phase 4 fills the stubs.

## Cutover gate

- Title.md callsite `z01_update_cave_person` shares `NATIVE_CAVE_PERSON`
  gate with prior arms.
- Default OFF → oracle drain (drain FULL MATCH).
- Defined ON → native (5 arms native, 4 stubbed).
- RoomRom links it; cave_tick currently doesn't call it (cave_tick is
  itself a stub) so no runtime exercise yet.

## Stance update

Phase 3 Task 3.4 (Stance: ADOPT/EXTEND) — top-level dispatch ported.
Phase 3 close requires the remaining stubs (state 1/3/6/7) to be filled
+ cavert_try_take_item / cavert_format_decimal_byte / cavert_write_prices_*
ported. Most of these are cross-subsystem (text rendering pipeline,
item-take with sound trigger) and naturally belong to Phase 4 once
cross-subsystem deps land.

Recommendation: bring Phase 3 close to "scaffolding-complete" status —
declare the cave gamemode skeleton native. Phase 4 closes the last
mile by replacing transpile shims with native sprite-descriptor / SAT /
text rendering primitives that ALL subsystems share.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc cited for every NES symbol per process improvement from
  finding 3_2.
- Promotes the Phase 3 summary line 17 verdict for `cavert_update_cave_person`
  from NEEDS-FULL-FINDING to FULL MATCH.
