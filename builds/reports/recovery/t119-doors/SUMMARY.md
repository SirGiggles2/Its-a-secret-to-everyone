# T-119 UW door state = NES UpdateDoors — evidence

Build: main @ 8251ccca + T-113/T-119 working tree (LTO). Harness: lockstep
`t114_uw_wall` (L1: $73 key door N -> $63 -> $53 bombable wall N).

Room flags (world flags at LevelInfo_WorldFlagsAddr = $06FF, both consoles),
final frame:

| room | NES | GEN before | GEN after |
|---|---|---|---|
| $73 | $28 (visited + N door) | $20 | $28 |
| $63 | $24 (visited + S door) | $20 | $24 |
| $53 | $28 (visited + N bombed) | $20 | $28 |

PlayAreaTiles (`verify_play_area.py`): $63 700/704 -> 704/704, $53 704/704.

CurOpenedDoors $EE / TriggeredDoorCmd $54 / TriggeredDoorDir $55 events:
- key door $73 N: NES cmd7 f1713 -> $EE=$08 f1721; GEN cmd6 f1718, cmd7
  f1719 -> $EE=$08 f1727 (8-frame DoorTimer step matches; GEN one frame
  later = Link touch runs after UpdateDoors, T-102 order).
- entering $63 through S: $EE=$04 on both; close cmd 2 then reset (key door:
  no visual change) on both.
- bombable wall $53: NES cmd7 f2373 -> $EE=$08 f2381; GEN cmd7 f2374 ->
  $EE=$08 f2383.

Regression: 20-preset suite vs LTO build. Diffs only where Link is shoved
(T-113 fix, t110_fire now 540/540 cells equal to NES) or UW door state.
Genesis still lays out the door command one frame late (T-102).
