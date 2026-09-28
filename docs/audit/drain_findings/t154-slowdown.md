# T-154 gameplay slowdown — work in progress

- **NES source:** `reference/aldonunez/Z_07.asm:MoveObject`.
- **Drained C:** `src/oracle/world/object_runtime.c:objrt_move_object`.
- **Coverage:** FULL. **Stance:** EXTEND the native consumer with local quarter-step intermediates; final NES RAM writes retain the drained result.

## Reproduction

`t013_route` reaches overworld room `$38` with six enemies at game ticks 1920–1939. Genesis video frames 2544–2579 contained 17 repeated game ticks in the pre-change T-153 capture. The diagnostic runner used a separate preset name (`t154_profile_astra`) and `--pc-profile 2544:2579 --frame-dump`, preserving Claude's T-013 reports. Profile percentages count executed 68K instructions, including idle `VDP_waitVBlank`; they are not cycle measurements.

Pre-change `object_move_object`: 19,411 instructions in that 36-frame interval. Source at `src/game/world/object_dispatch.c` read/wrote volatile NES RAM inside each of four quarter-speed steps. No game logic is called between steps. Current code keeps intermediate fraction, grid offset, and position in locals, then publishes the same final cells.

## Verification and limit

`Debug.bat` passed. Current ROM SHA-256 `e47a004d8d3bfba30888241fe2e4932f5b509393f37c1a8bf1b51a7f7d760bb4` matches `builds/reports/lockstep/t154_profile_astra/run_gen/launch.json` after reverting a slower sprite-writer experiment.

Full route: 9,065/9,065 KEY ticks match NES. Compared with the previous Genesis route capture, all NES RAM bytes across 9,065 ticks match after excluding Claude's uncommitted `$0526` initialization change and `$01FD–$01FF` video timing instrumentation. Those four excluded cells are documented differences between the two builds, not a parity waiver. Diagnostic `GATE: FAIL` reports 137 pre-existing full-RAM differences because this new preset has no ratchet baseline; the existing `t013_route` report has a passing ratchet.

`object_move_object` fell to 14,403 instructions in the same interval (−25.8%). Gameplay lag fell only to 16/36 frames. **T-154 remains open.** `emit_native_entries` (~21,470 instructions), `anim_write_sprite_pair` (~22,515), and collision are the next measured consumers. Inspect generated code and actual SAT work before another edit. Recheck room `$38` and the named UW consumer after a candidate fix. Do not run the whole suite until a focused fix clears lag.
