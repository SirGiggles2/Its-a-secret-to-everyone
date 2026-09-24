# $5B MonsterArrow

- **NES source**: reference/aldonunez/Z_04.asm:2102 UpdateMonsterArrow
- **Drained C**:  src/oracle/enemies/enemy_projectile_runtime.c enrt_update_monster_arrow
- **Coverage**:   PARTIAL
- **Stance**:     EXTEND

Behavior: qspeed=$80 + ObjTimer pre-check (if !=0, draw + check
shooter alive via ObjRefId, reset timer if shooter dead). Active flight
uses NES MoveShot wall/boundary handling; blocked arrows enter spark state
$20. Spark uses NES frame $02, counts down three updates, and clears the
counted monster arrow. Shield-hit behavior now follows the NES ordering:
base update, Link collision, then bounce or harmful-hit cleanup.
Focused staged arrow/Link overlap entered `$30` when the shield faced the
incoming shot, preserving the active shot count; see
`builds/reports/recovery/monster-arrow-shield-hit-20260923/trace.txt`.

Focused BizHawk fixture: live type $5B arrow at room edge moved from $10 to
$20 on block, counted down `$03 -> $02 -> $01`, then cleared type/state and
decremented ENEMY_SHOT_COUNT `$01 -> $00`. A separate centered staged fixture
rechecked the timeout after the arrow frame-$02 draw correction. Evidence:
`builds/reports/recovery/monster-arrow-wall-live-20260923/trace.txt` and
`builds/reports/recovery/monster-arrow-spark-frame-20260923/trace.txt`.
A matched BizHawk capture after frame 2 changed exactly 28 pixels in an
8×8 box when the staged arrow was present. This establishes Genesis spark
visibility at the centered position; the earlier frame-1 capture preceded
the visible update. Evidence:
`builds/reports/recovery/monster-arrow-spark-frame-20260923/result.json`.
Paired NES/Genesis screenshots now establish the spark silhouette for both
horizontal facings: each arrow-minus-control capture changes the same 28
pixels in an 8×8 box after aligning the display crop. NES OAM selected tile
`$3C` and palette `$01`. The Genesis renderer now clears horizontal flip
for the spark, matching NES `@PrepareArrow`. The two emulators' white RGB
values and absolute capture Y differ. Evidence:
`builds/reports/recovery/monster-arrow-paired-20260923/result.json`.

Normal room `$4D` also loaded four Moblins and produced a natural `$5B`
arrow at frame 37. Consecutive frames showed flight across the room; the
tracked shot cleared at frame 128 while other Moblin shots remained. A
frame-75 capture shows the projectile in play. Evidence:
`builds/reports/recovery/moblin-natural-arrow-20260923/result.json`.

A staged rearward hit through the regular collision callback reduced Link's
partial health `$FF -> $DF`, cleared the arrow and decremented the active
shot count `$01 -> $00`. Evidence:
`builds/reports/recovery/monster-arrow-harm-hit-20260923/result.json`.

Still partial: NES-aligned shooter aim/cadence, vertical-facing spark,
paired movement/timing oracle, and broader shooter/arrow cleanup.
Music remains deferred.
