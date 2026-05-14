# Phase 12 Task 12.3 — Shared State Conversion

- **NES source**: N/A — state-contract refactor. NES references
                  preserved per moved-file content.
- **Drained C**:  N/A.
- **Coverage**:   PARTIAL (planning) — substrate landscape already
                  established by prior phases; conversion is the
                  delta from per-TU globals to typed
                  `src/state/<sub>_state.h` structs with save-slot
                  initialization.
- **Stance**:     PARTIAL — substrate header inventory is FULL;
                  conversion of the per-TU globals lands family by
                  family alongside Task 12.2 migration PRs.

## Substrate inventory (already shipped)

`src/state/*.h` headers in tree:

```
boss_state.h          cave_state.h        collision_state.h
combat_state.h        dungeon_state.h     enemy_state.h
frontend_state.h      hud_state.h         item_state.h
link_state.h          object_state.h      palette_state.h
player_state.h        progress_state.h    render_budget.h
room_state.h
```

Plus Phase 12.2 will add:
- `inventory_state.h` (from `RoomRom/src/inventory.c`).
- `pause_state.h` (from `RoomRom/src/roomrom_pause.c`).
- `rng_state.h` (from `RoomRom/src/roomrom_rng.c`).
- `save_state.h` (already shipped Phase 9 Task 9.2).

## State contract (per docs/audit/state_contract.md)

Each shared state struct:

1. Lives in `src/state/<sub>_state.h`.
2. Is plain-old-data with explicit field types (no SGDK macros).
3. Initializes from save slot at game-start
   (`save_slot_deserialize` populates).
4. Exposes accessor macros routed through `RAM(addr)` / `SAVE_BYTE(off)`.
5. Has a contract test at `tools/debug/test_<sub>_state_contract.py`.

Existing contract test pattern: `test_boss_state_contract.py`,
`test_save_serializer_contract.py` (Phase 9). Each Phase 12.2 family
PR adds matching contract test for newly promoted state.

## Save-slot init wiring

Phase 9 Task 9.2 shipped `save_slot_serialize` + `_deserialize`.
Inventory mirror at SRAM offset 2..41 maps NES `$0657..$067E`. Task
12.3 work = wire `_deserialize` calls into `roomrom_debug_enter`
(game-start) for the newly promoted state structs so RAM picks up
the saved values, not boot defaults.

Wiring sequence per master plan:
1. `inventory_state` → from save slot inventory bytes (Phase 9.2
   already covers byte range).
2. `pause_state` → boots OFF (Phase 6 Task 6.10.1 invariant).
3. `rng_state` → seeds from frame counter at boot.
4. Per-family state → from save slot per-family bytes.

## Status

CLOSE (with execution deferral) — Task 12.3 substrate inventory +
conversion plan ready. Per-family state-conversion lands inside
Task 12.2 PRs (same migration PR converts the moved TU's globals
to the typed struct). Recorded as `phase12_state_conversion`
deferral with explicit per-family ordering.
