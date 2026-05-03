# Drain Finding — Phase 3 Task 3.2 — `cavert_update_cave_person`

**Per Rule D1 Gate 1.** Drained C vs NES disassembly. Top-level cave gamemode tick (jump-table dispatch over CAVE_PERSON_STATE).

## Targets

| Side | Path | Lines |
|------|------|-------|
| Drained C | `src/game/cave/cave_runtime.c` | 326-354 |
| NES asm | `reference/aldonunez/Z_01.asm` | 300-368 (UpdateCavePerson + jump table) |
| NES vars | `reference/aldonunez/Variables.inc` | `ObjState := $AC`, `FrameCounter := $15`, `ObjType := $34F`, `InvLetter := $666`, `SelectedItemSlot := $656`, `ButtonsPressed := $F8`, `Tune1Request := $602` |

## Block-by-block diff

### Block A — State 4 every-other-frame skip

| NES (304-309) | C (327-329) | Verdict |
|---|---|---|
| `LDA ObjState+1 / CMP #$04 / BNE :+ / LDA FrameCounter / AND #$01 / BNE @UpdateCavePersonDirect` | `state = CAVE_PERSON_STATE; if (!(state == 4 && (RAM(0x0015) & 1))) { cavert_draw_cave_person(slot); ...` | **MATCH** (NES branches to direct-state if state=4 AND FrameCounter bit 0 set, skipping draw; C inverts: do draw unless state=4-and-frame-bit-0; equivalent. RAM(0x0015) = FrameCounter ✓.) |

### Block B — Special-case medicine shop ($74) letter use

| NES (311-353) | C (330-340) | Verdict |
|---|---|---|
| `JSR DrawCavePerson; LDA ObjType+1; CMP #$74 BNE @DrawItems; LDA InvLetter; CMP #$02 BEQ @DrawItems; LDY SelectedItemSlot; CPY #$0F BNE @Unhalt; LDA ButtonsPressed AND #$40 BNE @UseLetter; @Unhalt: LDA ObjState; CMP #$40 BNE :+; JSR UnhaltLink; RTS; @UseLetter: LDA #$04 STA Tune1Request; INC InvLetter; LDA #$07 STA SelectedItemSlot;` | `cavert_draw_cave_person(slot); if (CAVE_ROOM_TYPE == 0x74 && CAVE_ROOM_SCRIPT_STATE != 2) { if (RAM(0x0656) == 0x0F && (CAVE_LINK_INPUT_FLAGS & 0x40)) { RAM(0x0602) = 4; CAVE_ROOM_SCRIPT_STATE++; RAM(0x0656) = 7; } else { if (CAVE_LINK_ACTION_TIMER == 0x40) z01_unhalt_link(); return; } }` | **MATCH (with NAMING SMELL)** |

**Naming smell:** drain calls byte `$0666` `CAVE_ROOM_SCRIPT_STATE` (cave_state.h:36), but NES Variables.inc:line specifies it as `InvLetter`. The byte is shared between cave-script-state and inventory-letter-state semantically — they happen to occupy the same address but mean different things in different contexts. Drain naming biases toward the cave use-site; should add a comment or rename to dual-name (e.g. `INV_LETTER_AKA_CAVE_SCRIPT_STATE`). **NOT a bug** — same byte, same writes, NES-correct semantics.

Cross-references verified against Variables.inc:
- `CAVE_LINK_INPUT_FLAGS = $00F8` ↔ NES `ButtonsPressed = $F8` ✓
- `CAVE_LINK_ACTION_TIMER = $00AC` ↔ NES `ObjState = $AC` ✓  (so `CAVE_LINK_ACTION_TIMER == 0x40` ↔ `CMP ObjState, #$40`)
- `RAM(0x0602) = 4` ↔ NES `STA Tune1Request` (= $602) ✓
- `RAM(0x0656) = 7` ↔ NES `STA SelectedItemSlot` (= $656) ✓
- `CAVE_ROOM_SCRIPT_STATE++` ↔ NES `INC InvLetter` (= $666) ✓

### Block C — DrawCaveItems + jump table dispatch

| NES (354-358) | C (341-353) | Verdict |
|---|---|---|
| `@DrawItems: JSR DrawCaveItems / @UpdateCavePersonDirect: LDA ObjState+1 / JSR TableJump` | `cavert_draw_cave_items(); switch (CAVE_PERSON_STATE) { ... 9 cases ... }` | **MATCH** (NES uses TableJump indirect via UpdateCavePerson_JumpTable[state]; C uses switch over 9 cases). |

### Block D — 9-state jump table mapping

NES `UpdateCavePerson_JumpTable` (lines 359-368):
```
0: UpdateCavePersonState_TransferPrices
1: UpdatePersonState_Textbox
2: UpdateCavePersonState_TalkOrShopOrDoorCharge
3: UpdatePersonState_CueTransferBlankPersonWares
4: UpdatePersonState_DelayThenHide
5: UpdateCavePersonState_HintOrMoneyGame
6: UpdatePersonState_CueTransferBlankPersonWares
7: UpdatePersonState_Textbox
8: UpdateCavePersonState_DoNothing
```

C switch:
```c
case 0: cavert_update_transfer_prices();        ✓ (TransferPrices)
case 1: cavert_update_person_state_textbox();   ✓ (Textbox)
case 2: cavert_update_talk_shop_or_door_charge(); ✓
case 3: z01_cue_transfer_blank_person_wares();  ✓
case 4: cavert_update_person_state_delay_then_hide(); ✓
case 5: cavert_update_hint_or_money_game();     ✓
case 6: z01_cue_transfer_blank_person_wares();  ✓
case 7: cavert_update_person_state_textbox();   ✓
case 8: break;                                   ✓ (DoNothing)
```

**FULL MATCH on all 9 entries.**

## Verdict summary

All 4 blocks (A entry-skip, B medicine shop letter, C dispatch, D jump table) **MATCH**. One naming smell on `CAVE_ROOM_SCRIPT_STATE` aliasing NES `InvLetter` — purely cosmetic, NOT a bug.

**Overall verdict: cavert_update_cave_person = FULL MATCH against NES UpdateCavePerson.**

## Stance update

Phase 3 Task 3.2 already had cavert_init_cave + cavert_init_cave_continue confirmed MATCH. Adding cavert_update_cave_person FULL MATCH means Task 3.2 main dispatch trio is **fully verified MATCH → ADOPT-safe across all dispatch entry points**.

## Action item

Open small follow-up: edit `src/state/cave_state.h:36` to rename `CAVE_ROOM_SCRIPT_STATE` → `CAVE_INV_LETTER_STATE` OR add a `// NES: InvLetter` provenance comment. Naming clarity for future readers; not a behavior change.

## Provenance

- 2026-05-02. Author: Claude Opus.
- Process: cited Variables.inc explicitly per finding 3_2 lesson.
