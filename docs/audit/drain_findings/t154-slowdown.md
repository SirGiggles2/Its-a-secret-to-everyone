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

Named consumer `t154_uw_consumer` copied the `t131_uw_doors` preset without touching its report. ROM hash matches above; 1,187/1,187 KEY ticks pass. Against the earlier Genesis dungeon capture, only `$0526` (Claude's continue-path work) and video cells `$01FE–$01FF` differ. Video frames 1102–1111 contain one repeated mode-5 tick and two transition repeats; dungeon gameplay lag remains.

Generated 68K code for `emit_native_entries` at `$027340` already inlines tile/attribute lookup and SAT cache writes. Any further optimization needs a measured structural saving. A local sprite-pair scratch-caching experiment increased `anim_write_sprite_pair` from 22,515 to 24,130 instructions in the sample without reducing lag; it was reverted. Rebuilt ROM SHA matches the verified hash above.

## 2026-09-28 continuation: idle weapon collision

After the shared T-013 Continue re-entry change, a fresh profile (`t154_profile2_astra`) of video frames 2544–2579 measured 372,088 instructions: `anim_write_sprite_pair` 22,515, `emit_native_entries` 21,470, `object_move_object` 14,403, and `link_collision_check_monster_collisions` 14,250. The sampled OW room has no active player weapon slots `$0D–$12` on ticks 1920–1939. A fast translation-table branch in `enemy_render.c` saved only 418 instructions over 36 frames and did not reduce lag; reverted.

`link_collision_check_monster_collisions` now skips the first five weapon checks only when all six player weapon `ObjState` cells are zero. It still runs the final arrow/rod check to preserve scratch-cell writes, then performs Link collision. Skipping the whole battery caused differences at `$0004/$0005/$0007/$000D/$000E`; retaining the final check removed them. Against the pre-change full Genesis capture, the 9,065-tick route differs only in video timing cells `$01FE/$01FF`; all other 2,046 RAM cells agree at every tick. NES KEY 9065/9065. The busy 36-frame sample now repeats 16 ticks rather than 17. UW consumer KEY 1187/1187; its sampled four repeated video frames remain four. Current `Debug.bat` passed; ROM SHA-256 `2973c129a278602c5ffafeb21bf11daf59f301bb23b5bfb8210b4b8f3c1f407d`. Reports: `builds/reports/lockstep/t154_collision_route_astra/` and `t154_collision_uw_astra/` (separate diagnostic names; no full-RAM ratchet baseline, so their GATE reads FAIL despite zero KEY mismatches).

T-154 remains open: room `$38` still runs past the frame deadline near VCounter `$E6–$EA`; profile shows sprite-pair drawing and SAT emission as the largest remaining active consumers. Check cycle timing and optimize an actual hot path; do not treat the ~43% instruction share in `VDP_waitVBlank` as useful game work.

User clarification (2026-09-28): Genesis may run faster than NES and isolated one-frame timing differences are acceptable when gameplay remains correct. The repeated-frame rate above is sustained gameplay slowdown, so it remains a performance defect. A direct scratch-write replacement for the final idle arrow/rod check matched RAM but did not reduce repeated frames beyond the accepted idle-collision change; it was reverted to keep the NES call path simple.
