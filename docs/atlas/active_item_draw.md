# Active item drawing and tile ownership

Use this path for current Original gameplay work. The May 2026 `sprite_audit.md` and generated `sprite_catalog.md` describe a fixed-slot renderer that is not called by the linked game; their item-ID labels are historical.

| Step | Active owner | Data |
|---|---|---|
| Spawn / update an item object | `src/game/items/item_object.c:item_object_update`; room-item callers also enter `draw_animate_item_object` | NES object type `$60`, item ID in `$00AC+slot`, position in `$0070/$0084+slot` |
| Resolve item ID, grade, tile and NES OAM | `src/game/world/draw_dispatch.c:draw_animate_item_object` and `draw_item_by_slot` | ROM-drained `ItemIdToSlot`, `ItemIdToDescriptor`, `Anim_ItemFrameOffsets`, `Anim_ItemFrameTiles`; item context marks OAM with `ITEM_ATTR_MARKER` |
| Translate to Genesis SAT | `src/game/enemies/enemy_render.c:translate_tile` and item sprite cache | Marked NES tile routes through the resident ITEM atlas; rendered sprite shape/palette follows NES OAM |
| Draw pause inventory icon | `src/game/inventory/inventory_render.c` | Separate per-slot pause lookup; do not infer a pickup's ID from a pause icon tile |

The old `roomrom_sprites_set_room_item` and `roomrom_sprites_clear_room_item` fixed-slot functions in `src/game/world/render/sprite_render.c` have no production callers. Their switch maps `$0C` to ring, but the active NES table maps `$0C` to slot `$09`, `$0D` to slot `$0C`, and ring pickup IDs `$12/$13` to slot `$0B`. The active frame table assigns ring tile `$46/$47` and slot `$0C` tile `$76/$77`. Do not reactivate the old switch or use the historical atlas labels as gameplay truth without replacing its ID table from the ROM and capturing a live consumer.

Live checks: [T-121 pause ring](../audit/drain_findings/t121-pause-ring-icon.md) and [T-155 world ring grades](../audit/drain_findings/t155-ring-pickup.md). Both show NES tile `$46` and exact Genesis pixels/palette. T-155's contact fixture sets `InvRing` to 1 or 2 on the same tick as NES. The Ring2 color differs through sprite attributes, not a different tile number.
