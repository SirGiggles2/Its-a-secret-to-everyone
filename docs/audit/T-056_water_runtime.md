# T-056 — Windows water integration

- **NES source:** `reference/aldonunez/Z_07.asm:UpdatePlayer`, `Z_04.asm:UpdateDock`; `Z_07.asm:Link_EndMoveAndAnimate` and `Z_05.asm:CheckLadder`.
- **Drained C:** existing `src/game/items/link_ladder.c`, `src/game/world/dock.c`; existing native movement host in `RoomRom/src/main.c`.
- **Coverage:** PARTIAL: staged Q1 water mechanics and named halted-player consumers; connected progression and Q2 locations remain open.
- **Stance:** EXTEND integration; retain Claude's routine-equivalent ladder/dock implementations.

## Defect and correction

On synchronized build EE5979A0, `t056_raft` first disagreed at tick468. Enemy contact immediately before boarding left Link with shove distance `$18`. NES `UpdatePlayer` returns after the invincibility timer when `ObjState & $C0 == $40`. Genesis masked directional input but still ran Walker_Move/knockback, moving Link four additional pixels while UpdateDock carried him one pixel.

The native host now skips the entire movement branch while halted. Dock/Wallmaster retain carried-position ownership; enemy updates remain active. This changes no dock rules or NES RAM layout.

The UW ladder preset's final idle tail was shortened from200 to50 ticks. Its crossing, return and northward actions are unchanged. The old tail killed NES Link at1045, preventing Genesis capture; the repaired case finishes900 ticks without correcting health or position during actions.

## Evidence

Windows `Debug.bat` PASS. Frozen local ROM `builds/playtests/Debug-T056-halt.md`, SHA-256 `2307636AAF6E783270581269EF7D7CA1D1195E4C13C8792CE2BD589F793890BE`.

| Case | Executed ticks | Result |
|---|---:|---|
| Dock `$55` → `$45` → `$55`, including hit before boarding |800/800|KEY0; selected movement/shove/dock fields exact; screens120/468/550 MATCH; LAG PASS, worst end line `$BC`|
| Dock `$3F` → `$2F` → `$3F` |800/800|KEY0; dock states0/1/2 and both rooms observed; screen120 MATCH|
| L1 `$23` ladder crossing/return/stash |900/900|KEY0; ladder active183 ticks, finally stashed; screens560/720 MATCH|
| Unowned raft, dock `$55` |180/180|KEY0; no ride/halting; Link stops at NES Y `$75`|
| Unowned ladder, OW `$5F` |180/180|KEY0; no ladder installation or crossing; Link remains `$80,$8D`|
| Wallmaster grab/return |8156/8156|existing GATE PASS|
| Pond fairy |659/659|existing GATE PASS|
| Whirlwind transport |762/762|existing GATE PASS|

Reports: `builds/reports/lockstep/<preset>_t056_halt`. The adjacent JSON records selected-field comparisons. Compare after tick80 (UW500): level/mode/FC, LadderSlot, Link X/Y/dir/state/shove/grid/fraction/animation/invincibility, HP/partial, raft/ladder ownership; boats additionally compare slot11 X/Y/state/type; ladders additionally compare active slot X/Y/dir/state/type. No differences in these fields. `screen_diff.py --window-rows 7` compares decoded captured tile/palette pixels, not screenshot impressions.

## Limits and next work

New water cases have no ratchet baseline: full raw verdicts remain FAIL/NONE with66–70 differences, so KEY0 is not a blanket GATE PASS. Differences include native VDP scroll state and CurObjIndex publication; dock `$55` additionally has one exit tick531 with old-room object animation/timer differences, cleared on532. These have not all received formal baseline classification.

OW ladder remains610/610 KEY0 with61 extra stalled ticks on this build (previous sync build63). Profile-only180/610 capture is incomplete and is not acceptance. Full report `t056_ladder_ow_t056_profile`; busy video-frame218:238 profile `t056_ladder_ow_t056_busy`. Existing HUD heart row costs338 instructions per draw even with unchanged health; sprite sweep costs1518 instructions per call. T-172 owns focused performance repair. T-056 remains REVIEW, not whole-system completion.

Q2 data locations, connected acquisition/use/save routes and the older T-003 arrival1594 discrepancy remain unverified; this focused dock repair does not establish their causes or acceptance. Music remains last.
