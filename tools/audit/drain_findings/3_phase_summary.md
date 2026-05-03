# Phase 3 Drain Findings — Summary Verdicts

**Per Rule D1 Gate 1 (per-function diff).** Summary-style verdicts for the cavert_* functions not yet getting a full block-by-block finding doc. If a function is flagged DIFF or UNKNOWN here, a full finding doc must be opened before its task moves to ADOPT.

> **Critical context (2026-05-02):** drained `cavert_*` functions are wired into Title.md gameplay via `src/gen/z_01.c` (transpiler-generated C calls them directly at lines 350/354/386/414). Phase 3 is therefore an audit-and-verify phase, not a wire-up phase. RoomRom does not link `src/game/cave/*` (no `nes_ram` image, no transpile bridge) — Phase 3 cave work happens in main worktree.

## Summary table

| Function | NES counterpart | NES line | Verdict | Notes |
|----------|-----------------|----------|---------|-------|
| `cavert_init_cave` + `cavert_init_cave_continue` | `InitCave` + `InitCaveContinue` | Z_01.asm:69 + 105 | **MATCH** | Full finding: `3_2_cavert_init_cave.md`. Block-by-block 6/6 MATCH after offset re-verification. |
| `cavert_draw_cave_person` | `DrawCavePerson` | Z_01.asm:370 | **MATCH** | Full finding: `3_4_cavert_draw_cave_person.md`. Tiny 4-op function. |
| `cavert_draw_cave_items` | `DrawCaveItems` | Z_01.asm:388 | **MATCH** | Loop wares 2..0; X=CaveWareXs[i] writes ObjX+19 ($83); Y=$98 writes ObjY+19 ($97); item & $3F skip if $3F else c_animate_item_object(item, 19). Item-only flag $04, price-only flag $08, both branches present in C ✓. |
| `cavert_update_transfer_prices` | `UpdateCavePersonState_TransferPrices` | Z_01.asm:442 | **MATCH (verdict)** | C: `if (!(CAVE_FLAGS & 8)) z01_inc_cave_state(); else cavert_write_prices_transfer_buf();` Mirrors NES dispatch: skip-if-no-prices vs format-prices. Block-by-block diff deferred — single-branch dispatcher, low DIFF risk. |
| `cavert_update_talk_shop_or_door_charge` | `UpdateCavePersonState_TalkOrShopOrDoorCharge` | Z_01.asm:666 | **MATCH (verdict)** | C handles 3 sub-branches (no-take, door-repair $71, ware-purchase loop). Door-repair branch sets `CAVE_DOOR_REPAIR_RUPEE_DELTA += 20`, sets room flag UW item state. Ware loop: scans 2..0, distance check (Link-X vs CaveWareXs ≤ 6), then 4 cave-flag dispatch arms ($30, $10, $02, $40 hearts requirement). All NES branches present. Block-by-block diff deferred — large but structurally aligned. Recommend full finding before any production trust. |
| `cavert_update_hint_or_money_game` | `UpdateCavePersonState_HintOrMoneyGame` | Z_01.asm:851 | **MATCH (verdict)** | C handles 3 cases: (a) flag $10 hint cave (selector from HintCaveTextSelectors0[base+sel_idx]), (b) ROOM_TYPE ≥ $7B (door-charge variant), (c) money game with rupee threshold $0A. Each calls expected z01_* shims (cue_transfer_buf, post_credit, post_debit) + writes prize_order to cave_price + amount checks ($14/$32 = 20/50 win-amounts). Money game branch is verified-MATCH from finding 3_2 (RNG seed bytes correctly mapped). Recommend full finding before any production trust. |
| `cavert_update_cave_person` | `UpdateCavePerson` | Z_01.asm:300 | **NEEDS FULL FINDING** | Top-level dispatch: reads CAVE_PERSON_STATE, jumps via UpdateCavePerson_JumpTable. C version exists at line 326+ — needs full block-by-block; risk of jump-table mismatch (7 states). |
| `cavert_try_take_item` | `TryTakeItem` | Z_01.asm:4364 | **NEEDS FULL FINDING** | Item pickup dispatch. Cross-subsystem (item state mutation + sound trigger). |
| `cavert_try_take_room_item` | (NES counterpart TBD) | TBD | **UNKNOWN** | Need to find NES caller. |
| `cavert_clear_prices_cave_flag` | (inline NES, no label) | TBD | **MATCH (trivial)** | `CAVE_FLAGS &= 0xF7` — single bit clear. |
| `cavert_update_person_state_delay_then_hide` | `UpdatePersonState_DelayThenHide` | Z_01.asm:838 | **MATCH (trivial)** | `if (CAVE_DELAY_TIMER == 0) CAVE_ROOM_TYPE = 0;` — single timer check. |
| `cavert_format_decimal_byte` | (NES inline price formatter) | TBD | **NEEDS FULL FINDING** | Decimal formatter. Risk of off-by-one on hundreds/tens/units split. |
| `cavert_write_prices_transfer_buf` | (NES TBD) | TBD | **NEEDS FULL FINDING** | Calls cavert_write_prices_to_dynamic_transfer_buf. |
| `cavert_write_prices_to_dynamic_transfer_buf` | (NES TBD) | TBD | **NEEDS FULL FINDING** | Cross-references CAVE_TRANSFER_BUF_PRICE_* macros. |
| `cavert_swap_space_and_sign` | (NES helper) | TBD | **MATCH (trivial)** | Swap byte if d0 == 0x24. |
| `cavert_prepend_sign_to_price` | (NES helper) | TBD | **MATCH (trivial)** | Sign byte 100 (gain) or 98 (loss) per amount value. |
| `cavert_update_person_state_textbox` | `UpdatePersonState_Textbox` | Z_01.asm:565 | **NEEDS FULL FINDING** | Text rendering state machine. Cross-subsystem (text renderer in HUD or world). |

## Verdict roll-up

- **Full MATCH (with finding doc):** 2 (cavert_init_cave, cavert_draw_cave_person)
- **MATCH (verdict only, deferred to full finding before production trust):** 4
- **MATCH (trivial, no full finding needed):** 4
- **NEEDS FULL FINDING:** 7
- **UNKNOWN (NES counterpart not located):** 1

Total cavert_* functions in cave_runtime.c: 17. Coverage: 10/17 confirmed MATCH at some level; 7 need full block-by-block.

## Phase 3 Task → finding mapping

| Task | Functions verified | Status |
|------|---|---|
| 3.1 (data extraction) | N/A — GREENFIELD | Open |
| 3.2 (gamemode dispatch) | cavert_init_cave (full), cavert_init_cave_continue (full) | **MATCH-confirmed → ADOPT safe** |
| 3.3 (entry detection) | (depends on overworld collision drain — Phase 4 scope) | Pending Phase 4 |
| 3.4 (render) | cavert_draw_cave_person (full), cavert_draw_cave_items (verdict) | **MATCH → ADOPT safe** |
| 3.5 (textbox) | cavert_update_person_state_textbox needs full | Blocked |
| 3.6 (item grant) | cavert_try_take_item + cavert_try_take_room_item need full | Blocked |
| 3.7 (shop) | cavert_update_talk_shop_or_door_charge (verdict) | MATCH-likely; full finding before commit |
| 3.8 (gambling) | cavert_update_hint_or_money_game (verdict) | MATCH-likely; full finding before commit |
| 3.9 (exit) | cavert_update_person_state_delay_then_hide (trivial) | **MATCH → ADOPT safe** |
| 3.10 (verification gates) | All cavert_* with full findings | Open until 7 NEEDS FULL FINDING resolved |

## Provenance

- 2026-05-02. Author: Claude Opus.
- Process: rapid summary verdicts to map cave subsystem coverage. Full block-by-block findings open per Phase 3 sub-task as it's commit-ready.
