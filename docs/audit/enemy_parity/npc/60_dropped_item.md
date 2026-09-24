# $60 DroppedItem

- **NES source**: reference/aldonunez/Z_04.asm:11236 UpdateItem
- **Drained C**:  src/game/items/item_object.c item_object_update
- **Coverage**:   PARTIAL
- **Stance**:     EXTEND

Behavior: spawned by SetUpDroppedItem after dead-monster drop. Lifetime
$FF; item id at $00AC. Per-frame: decrement lifetime, check Link bbox
9×9 for pickup. On hit: item_take_item(id) + clear slot.
NES also checks active arrow (slot $12), sword ($0D), and boomerang ($0F)
before Link. Those native weapons now publish their positions and active
states into the shared object slots. A focused Genesis BizHawk run collected
three staged drops with controller-fired weapons beyond Link's pickup range;
an inactive sword and a sword intersecting a lifetime-`$F0` grace-period
drop left the item untouched. See
`builds/reports/recovery/weapon-drop-pickup-20260923/trace.txt`.
One connected room-$67 Octorok fight also selected a heart drop naturally;
Link stayed outside the pickup box while a controller-fired boomerang took
it. See `builds/reports/recovery/connected-weapon-drop-20260923/result.json`.
Halted-player and negative-state rejection still need focused behavioral
verification; broader item/drop progression remains open.
(DestroyMonster_Bank4).

Note: ObjAttr table (k_object_type_attrs[95] @ enemy_loop.c:75) only
covers types < 95. $60=96 is out-of-bounds → ObjAttr stays $00.
Documented in shared_primitives.md.
