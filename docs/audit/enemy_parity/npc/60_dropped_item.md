# $60 DroppedItem

- **NES source**: reference/aldonunez/Z_04.asm:11236 UpdateItem
- **Drained C**:  src/game/items/item_object.c item_object_update
- **Coverage**:   FULL
- **Stance**:     EXTEND

Behavior: spawned by SetUpDroppedItem after dead-monster drop. Lifetime
$FF; item id at $00AC. Per-frame: decrement lifetime, check Link bbox
9×9 for pickup. On hit: item_take_item(id) + clear slot
(DestroyMonster_Bank4).

Note: ObjAttr table (k_object_type_attrs[95] @ enemy_loop.c:75) only
covers types < 95. $60=96 is out-of-bounds → ObjAttr stays $00.
Documented in shared_primitives.md.
