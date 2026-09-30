# T-054 slice — UW block after leaving and returning

- **NES reference:** `reference/aldonunez/Z_05.asm:FindAndCreatePushBlockObject` recreates the source `$68` block at room entry. A completed push has `BlockPushComplete=$01` only for the current room visit; the ordinary shutter from a block-door secret closes after leaving and returning. `Z_04.asm:UpdateBlock` starts the recreated block at state 0.
- **Linked owners:** `src/game/world/pushblock.c` held a private `s_pb_state_per_room` latch across room loads and repainted the source block as floor. `src/game/dungeon/door_state.c` owns the separate shutter state. Stance: REPAIR the linked block-entry state, leaving door state with its existing owner.
- **Coverage:** L1Q1 room `$42` completed push → room `$43` → room `$42`, via a staged NES mode-3 room transition and Genesis debug room navigation. These are mechanism fixtures, not controller-only progression.

The NES capture `t054_uw_block42_exit_reentry_nes` has room `$42` block Y `$80`, state 2, `$4CF=1`, opened shutter `$EE=2` before departure. After visiting `$43` and returning, it has block `$70,$90`, state 0, `$4CF=0`, `$EE=0`. The Genesis probe `t054-uw-block42-reentry-gen` reaches the same before/after values. `roomrom_pushblock_room_load` now clears the current-entry private pushed latch and retains the room's original block tiles on each room load. A separate same-room mode-3 reload in NES retained `$EE=2`; it is a different transition from leaving the room and is not used for this acceptance.

Windows `Debug.bat` PASS; `builds/Debug.md` SHA-256 `6E5D6A4454789FEA82736543FB0D2A510BD7F33FA6BFA5BE74632771D096FD97`. Evidence: `tools/lockstep/presets/t054_uw_block42_exit_reentry_nes.json`, `builds/reports/lockstep/t054_uw_block42_exit_reentry_nes/nes.txt`, `builds/reports/recovery/t054-uw-block42-reentry-gen/trace.txt` and `reentry.png`.

Other push directions, moving-sprite pixel parity, the five-tick shutter opening difference and T-058 all-dungeon metadata remain open.
