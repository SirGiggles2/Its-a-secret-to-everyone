# Round 2 — Pragmatic Implementer (Sonnet)

## Direct answer: `cave_draw_person` IS already per-cave-specific. Codex's path is wrong.

### Evidence from code

**cave_dispatch.c:685-700** — `cave_draw_person(slot)`:
1. Calls `sprite_anim_fetch_obj_pos(slot)` — loads `OBJ_TILE_X/Y(slot)` into draw ZP scratch.
2. Reads `cave_room_type_get()` = `RAM(0x0350)` = `ObjType+1` = cave_id ($6A..$7D).
3. Gates on `cave_id < 0x7B` → `draw_object_mirrored(0, slot)` vs `draw_object_not_mirrored(0, slot)`.

**draw_dispatch.c:440-453** — `draw_object_mirrored`/`draw_object_not_mirrored`:
```
const unsigned char anim_idx = (unsigned char)OBJ_TYPE(slot);
draw_object_with_type(frame, slot, anim_idx);
// → DRAW_ANIM_INDEX = anim_idx + 1
//   → k_obj_animations[cave_id + 1]
```

`OBJ_TYPE(slot=1)` = `RAM(0x0350)` = cave_id (set at cave_init via `cave_room_type_set`).

This exactly mirrors **Z_01.asm:4979-5012 DrawObjectMirrored** (`LDY ObjType,X` → INY → index ObjAnimations). The Genesis drain is byte-identical to NES. There is no separate "cave person sprite table" — the NES uses the **same ObjAnimations table** (Z_01.asm:4884), indexing by ObjType=$6A..$7D.

Computed lookup: cave_id $6A..$72 → `k_obj_animations[0x6B..0x73]` = `0x58` (Old Man descriptor). Cave_id $73..$76 → `0x59`. Cave_id $77..$7A → `0x5A`. Cave_id $7B..$7D → `0x5B` (shortcut/Moblin). That is the NES-authoritative per-cave sprite grouping — not 20 individual descriptors but 4 groups differentiated by ObjAnimations[cave_id+1]. The NES has no flat per-cave sprite table beyond this.

**NES authoritative table:** `ObjAnimations` at **Z_01.asm:4884**, indexed via `DrawObjectWithType` (line 5011). No separate OverworldPersonSpriteTable exists.

### Per-cave nametable

**ow_render.c:522-538** — `roomrom_cave_room_render_fill_plane_a(cave_id)`:
```c
static const unsigned char *cave_layout_for(unsigned char cave_id)
{
    if (cave_id >= 0x7Bu) return k_cave_layout_shortcut;
    return k_cave_layout_regular;
}
```

Only **two** layouts: regular ($6A..$7A) and shortcut ($7B..$7D). This matches NES Z_05.asm cave-edge check — the NES also only has two cave BG templates, not 20 unique nametables. Cave BG is fixed template data, not per-cave heap. Phase D already handles this correctly.

### Conclusion

Codex's `static CaveLayout cave_layouts[]` with 20 entries extracted per cave-id does not correspond to the NES architecture. The NES has 4 sprite-group descriptors (via ObjAnimations) and 2 BG layouts. The existing Genesis drain at cave_dispatch.c:685-700 is correct. The 40 FAIL_MISSING are not a rendering dispatch gap — they are the `s_link_grid_offset` probe bug (dungeons) and the `CAVE_ID_MAX` off-by-one (caves $7A..$7D). Fix those two structural bugs first, then byte-diff to find actual visual divergences.
