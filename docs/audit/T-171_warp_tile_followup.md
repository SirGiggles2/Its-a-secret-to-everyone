# T-171: dungeon entrance tile mirror

NES authority: `reference/aldonunez/Z_05.asm:CheckWarps` and
`HandleWarpOW` (`STA UndergroundEntranceTile` before `@LoadLevel`).
Owning Genesis path: `src/game/world/transition.c:detect_warp_ow` and
`roomrom_world_transition_tick`.

In `t111_dark_candle` tick 2240, both systems entered Level 5 from the
same `$24` tile. NES `$0065` became `$24`; Genesis kept the earlier
`$74`. The transition coordinator had the raw `$24` in its saved outcome
but never mirrored it into NES RAM before beginning level entry. The
coordinator now writes that raw tile at the matched warp branch. This
also preserves the distinction between `$24` and collapsed `$70`
entrances for later step-out behavior.

Windows `Debug.bat` PASS, ROM SHA-256
`453E489908A2F1B635EA4FB3250BD4F6C309A487D7B41625FE886129A4809A17`.
`t111_dark_candle` KEY 2776/2776 and `$0065` improved/eliminated.
The ten other baselines that carried `$0065` were rerun with `--full
--bless`; all gates passed with no earlier or new ratchet cells. The
refreshed route baselines also retired already-fixed `$03D0/$03E4`
cells in `t012_route` and `$042D` in `t129_enemy_sweep`.

The mismatch report now has 26 open and 13 accepted cells across 67
baselines. Its leading `$049E` collision scratch mismatch remains open;
this repair does not claim collision-state parity or connected-quest
acceptance.
