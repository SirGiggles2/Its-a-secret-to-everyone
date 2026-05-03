# Phase 3 Drain Findings — Summary Verdicts

**Per Rule D1 Gate 1 (per-function diff).** Summary-style verdicts for the cavert_* functions not yet getting a full block-by-block finding doc. If a function is flagged DIFF or UNKNOWN here, a full finding doc must be opened before its task moves to ADOPT.

> **Critical context (2026-05-02):** drained `cavert_*` functions are wired into Title.md gameplay via `src/gen/z_01.c` (transpiler-generated C calls them directly at lines 350/354/386/414). Phase 3 is therefore an audit-and-verify phase, not a wire-up phase. RoomRom does not link `src/game/cave/*` (no `nes_ram` image, no transpile bridge) — Phase 3 cave work happens in main worktree.

## Summary table

| Function | NES counterpart | NES line | Drain verdict | Native port | Native finding |
|----------|-----------------|----------|---------------|-------------|----------------|
| `cavert_init_cave` + `cavert_init_cave_continue` | `InitCave` + `InitCaveContinue` | Z_01.asm:69 + 105 | **MATCH** | `cave_init` (e07ec0ec, RAM-fix e4c9514c) | `3_2_cavert_init_cave.md`, `3_4n_f_cave_init_ram_coherency.md` |
| `cavert_draw_cave_person` | `DrawCavePerson` | Z_01.asm:370 | **MATCH** | `cave_draw_person` STAGE-1 (6f3836ab) | `3_4_cavert_draw_cave_person.md`, `3_4n_cave_draw_person_native.md` |
| `cavert_draw_cave_items` | `DrawCaveItems` | Z_01.asm:388 | **MATCH** | `cave_draw_items` STAGE-1 (1403ebca) | `3_4n_b_cave_draw_items_native.md` |
| `cavert_update_transfer_prices` | `UpdateCavePersonState_TransferPrices` | Z_01.asm:442 | **MATCH** | `cave_update_transfer_prices` STAGE-1 (f6923855) | `3_4n_c_cave_update_transfer_prices_native.md` |
| `cavert_update_talk_shop_or_door_charge` | `UpdateCavePersonState_TalkOrShopOrDoorCharge` | Z_01.asm:666 | **MATCH** | `cave_update_talk_shop_or_door_charge` STAGE-1 (dcc0d322) | `3_4n_d_cave_update_talk_shop_or_door_charge_native.md` |
| `cavert_update_hint_or_money_game` | `UpdateCavePersonState_HintOrMoneyGame` | Z_01.asm:851 | **MATCH** | `cave_update_hint_or_money_game` STAGE-1 (d1bd3f61) | `3_4n_e_cave_update_hint_or_money_game_native.md` |
| `cavert_update_cave_person` | `UpdateCavePerson` | Z_01.asm:300 | **MATCH** (was NEEDS) | `cave_update_cave_person` STAGE-1 (04700d83) — 5/9 arms native | `3_4n_h_cave_update_cave_person_native.md` |
| `cavert_try_take_item` | `TryTakeItem` | Z_01.asm:4364 | **NEEDS FULL FINDING** | not yet ported | — |
| `cavert_try_take_room_item` | (NES counterpart TBD) | TBD | **UNKNOWN** | not yet ported | — |
| `cavert_clear_prices_cave_flag` | (inline NES, no label) | TBD | **MATCH (trivial)** | `cave_clear_prices_flag` (ea64f851) | `3_4n_g_cave_trivials_native.md` |
| `cavert_update_person_state_delay_then_hide` | `UpdatePersonState_DelayThenHide` | Z_01.asm:838 | **MATCH (trivial)** | `cave_update_person_state_delay_then_hide` (ea64f851) | `3_4n_g_cave_trivials_native.md` |
| `cavert_format_decimal_byte` | `FormatDecimalByte` | Z_01.asm:3129 | **MATCH** (was NEEDS) | `cave_format_decimal_byte` FULL (e998fcbb) | `3_4n_i_cave_price_formatter_native.md` |
| `cavert_write_prices_transfer_buf` | `WritePricesTransferBuf` | Z_01.asm:449 | **MATCH** (was NEEDS) | `cave_write_prices_transfer_buf` STAGE-1 (e998fcbb) | `3_4n_i_cave_price_formatter_native.md` |
| `cavert_write_prices_to_dynamic_transfer_buf` | `WritePricesToDynamicTransferBuf` | Z_01.asm:455 | **MATCH** (was NEEDS) | `cave_write_prices_to_dynamic_transfer_buf` STAGE-1 (e998fcbb) | `3_4n_i_cave_price_formatter_native.md` |
| `cavert_swap_space_and_sign` | `SwapSpaceAndSign` | Z_01.asm:539 | **MATCH** (was trivial-verdict) | `cave_swap_space_and_sign_inline` file-static (e998fcbb) | `3_4n_i_cave_price_formatter_native.md` |
| `cavert_prepend_sign_to_price` | `PrependSignToPrice` | Z_01.asm:980 | **MATCH (trivial)** | `cave_prepend_sign_to_price_inline` file-static (d1bd3f61) | (inlined in finding 3_4n_e) |
| `cavert_update_person_state_textbox` | `UpdatePersonState_Textbox` | Z_01.asm:565 | **NEEDS FULL FINDING** | not yet ported (cross-subsystem text rendering) | — |

## Verdict roll-up (post-cook 2026-05-03)

- **Full MATCH (with finding doc):** 14 — promotions from cook session
  resolved 6 NEEDS-FULL-FINDING + 1 UNKNOWN-equivalent.
- **MATCH (trivial, no full finding needed):** 0 — all promoted to FULL MATCH via dedicated findings.
- **NEEDS FULL FINDING:** 2 — `cavert_try_take_item`, `cavert_update_person_state_textbox`. Both cross-subsystem (item state + text rendering). Defer to Phase 4.
- **UNKNOWN (NES counterpart not located):** 1 — `cavert_try_take_room_item`.

Total cavert_* functions in cave_runtime.c: 17. Drain coverage: 14/17 FULL MATCH; 2 NEEDS-FULL-FINDING (cross-subsystem); 1 UNKNOWN.

Native port coverage: 14/17 ported with stage-1 stubs documented per
finding. Each ported function has a Title.md cutover gate
(`NATIVE_CAVE` / `NATIVE_CAVE_DRAW` / `NATIVE_CAVE_PERSON` /
`NATIVE_CAVE_FORMAT`) — default OFF, oracle drain runs unchanged.

## Phase 3 Task → finding mapping (post-cook 2026-05-03)

| Task | Functions verified | Native ported | Status |
|------|---|---|---|
| 3.1 (data extraction) | N/A — GREENFIELD | (deferred Phase 4 with shared transfer buf primitive) | Open |
| 3.2 (gamemode dispatch) | cavert_init_cave + cavert_init_cave_continue (full match) | `cave_init` (RAM-coherent) | **CLOSED → ADOPTED** |
| 3.3 (entry detection) | (depends on overworld collision drain — Phase 4 scope) | — | Pending Phase 4 |
| 3.4 (render) | cavert_draw_cave_person + cavert_draw_cave_items full match | `cave_draw_person`, `cave_draw_items` STAGE-1 (object_draw deferred) | **CLOSED (stage-1) — Phase 4 fills draw bodies** |
| 3.5 (textbox) | cavert_update_person_state_textbox NEEDS-FULL-FINDING | not yet ported | Blocked on Phase 4 native text-rendering pipeline |
| 3.6 (item grant) | cavert_try_take_item + cavert_try_take_room_item NEEDS/UNKNOWN | not yet ported | Blocked on Phase 4 native item-state + sound trigger |
| 3.7 (shop) | cavert_update_talk_shop_or_door_charge full match | `cave_update_talk_shop_or_door_charge` STAGE-1 | **CLOSED (stage-1)** |
| 3.8 (gambling) | cavert_update_hint_or_money_game full match | `cave_update_hint_or_money_game` STAGE-1 | **CLOSED (stage-1)** |
| 3.9 (exit) | cavert_update_person_state_delay_then_hide trivial | `cave_update_person_state_delay_then_hide` FULL | **CLOSED → ADOPTED** |
| 3.10 (verification gates) | 14/17 cavert_* full findings; 2 NEEDS + 1 UNKNOWN | n/a | **CLOSED for Phase 3 scope** — remaining 3 are cross-subsystem (Phase 4) |

Phase 3 is **scaffolding-complete**. Cave gamemode skeleton is native;
4 cutover gates expose the cutover surface. State-arm bodies for
`textbox` (states 1, 7) and `cue_transfer_blank_person_wares` (states
3, 6) remain TODO Phase 4 stubs — exact same pipeline that's needed
for `cavert_update_person_state_textbox` proper.

## Provenance

- 2026-05-02. Author: Claude Opus. Initial summary.
- 2026-05-03. Author: Claude Opus. Post-cook update: 14/17 functions
  ported native, 6 NEEDS-FULL-FINDING promoted to FULL MATCH, Phase 3
  scaffolding-complete. Remaining 3 items defer to Phase 4
  cross-subsystem ports (text rendering + item-state + cue_transfer).
