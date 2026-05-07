# Drain debt: G3 — `item_take_item` externs unlinked into RoomRom

**Filed:** 2026-05-07 (PR-1 CHR-FOUNDATION)
**Drained C path:** `src/game/items/item_dispatch.c:152`
**Owner:** Phase 6 (Link, Inventory, Items, Combat)

## Summary

`item_take_item(item_id)` is the canonical NES item pickup entry
point per Z_05.asm + Z_07.asm. The drained C definition exists at
`src/game/items/item_dispatch.c:152` but references several extern
const tables that are NOT linked into RoomRom standalone OR
CombinedDebug.md:

```c
extern const unsigned char ItemIdToSlot[];               /* line 22 */
extern const unsigned char ItemIdToDescriptor[];         /* line 23 */
extern const unsigned char LevelMasks[];                 /* line 24 */
extern const unsigned char SaveSlotToPaletteRowOffset[]; /* line 25 */
extern const unsigned char MenuPalettesTransferBuf[];    /* line 26 */
```

Calling `item_take_item()` from any RoomRom-side code path produces
a link error.

## Workaround in slice-1 (Tasks 5.9, 5.9.1)

RoomRom-local pickup wrapper writes inventory bytes directly via
`INVENTORY_VALUE(slot) |= LevelMask` (state surface from
`src/state/item_state.h:26`). Triforce wrapper bypasses GAME_MODE
= 18 transition to avoid end-level mode change conflict.

This worked for slice-1 verification (gate_5_9_inventory.py PASS)
but does NOT exercise the real NES dispatch chain (item-class
classification, palette transfer, menu refresh).

## Resolution path

Phase 6 weapon/items work owns:
1. Linking the 5 extern tables into RoomRom + CombinedDebug build.
   - `ItemIdToSlot` — Z_01.asm:4264. Already extracted; need
     compile target (data file emit OR drained const table).
   - `ItemIdToDescriptor` — TBD location.
   - `LevelMasks` — Z_07.asm:747-748 ($01..$80).
   - `SaveSlotToPaletteRowOffset` — TBD.
   - `MenuPalettesTransferBuf` — TBD.
2. Wiring `item_take_item()` call site at RoomRom collision
   detection point (replaces local wrapper).
3. Handling GAME_MODE = $12 (end-level) transition for triforce
   pickup (currently stubbed in `roomrom_uw_item_pickup` with
   `s_triforce_pickup_active` flag).

## Acceptance for closure

- [ ] All 5 externs link cleanly into both ROMs.
- [ ] `roomrom_uw_item_pickup` removed; replaced with direct
      `item_take_item(item_id)` call.
- [ ] Triforce pickup path executes Mode_EndLevel transition
      gracefully (or stub still acceptable until end-level
      renderer ports).
- [ ] gate_5_9_inventory.py PASS unchanged.

## Status: OPEN

Phase 6 prerequisite. Tracking under drain coverage:
`tools/audit/drain_coverage.json` should flag any new `item_take_item`
call site in RoomRom-side code as a regression until this debt
closes.

## Related drain rows

- `room_has_compass` / `room_has_map` (`src/game/room/room_dispatch.c:597,
  603`) — already ADOPT-able from RoomRom (read INVENTORY_VALUE only,
  no extern dependency).
- `room_is_dark_room` (`src/game/room/room_dispatch.c:75`) —
  reads `nes_ram[$0A7E + col]` which is OOB on RoomRom 2 KB
  nes_ram (G1; separate debt). RoomRom uses generated table
  instead.

## Cross-references

- 2026-05-07 spec: `docs/superpowers/specs/2026-05-07-whole-chr-rollout-design.md`
- Decision: `docs/superpowers/decisions/2026-05-07-chr-budget-lock.md`
- Memory: `feedback_drain_primary_nes_secondary.md`
- Memory: `feedback_combined_debug_only.md`
