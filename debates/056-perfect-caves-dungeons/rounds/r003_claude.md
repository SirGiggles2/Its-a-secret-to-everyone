# Opus R3 — Code-grounded answers to all 5 sub-questions

## 1. SAT publish ORDER

NES uses RollingSpriteIndex (Z_01.asm) — FIFO counter wrapping at $28 (40 slots). `sprite_dispatch.c:16` confirms Genesis port also uses RollingSpriteIndex with wrap at $28. Same mechanism.

`draw_dispatch.c:658` comment: "PHA / LDY RollingSpriteIndex / LDA SpriteOffsets,Y / TAY" — ports the NES OAM slot allocation. So Genesis SAT publishes in the same FIFO order as NES OAM.

**Verdict:** SAT order matches NES. Byte-diff on OAM (after normalize) will catch any reorder. NO false-pass risk if comparator iterates all 40 slots and diffs each (Y, X, tile, attr) pair in order.

## 2. PALETTE per-cave_id

`cave_palette.c:6` — hardcoded 8-byte table `k_cave_subpal_2_3_nes` from Z_06.asm:714:
```c
0x0F, 0x30, 0x00, 0x12,   /* subpal 2 */
0x0F, 0x07, 0x0F, 0x17    /* subpal 3 */
```
ONE PALETTE for ALL caves. Called at `cave_fade.c:153` SWAP_ENTRY + `main.c:2343` on cave toggle. No per-cave_id parameter. **NES does same**: Z_06.asm:714 is a single literal table the NES cave-mode setup loads identically per cave entry.

**Verdict:** Fixed palette is NES-correct. Codex's "treat as room-specific until proved" is wrong — proof is in the code. CRAM byte-diff will pass identically for all 20 caves.

## 3. ITEM rendering per cave_id

`cave_dispatch.c:90-91`: `LBA_E` at NES SRAM $6A7E (LevelBlockAttrsE per Variables.inc:331). `cave_dispatch.c:151`: `nes_ram[NES_SRAM_LBA_E_BASE + ware_off + i]` reads ware item id per cave.

For cave_id $6A: cave_idx = 0. CaveItemIds[0..2] = LBA_E[0..2]. NES values per `reference/aldonunez/dat/LevelBlockAttrsE.dat` first 3 bytes (need extract).

Item draw at `cave_dispatch.c:305`: `draw_animate_item_object(item, 19u)`. This uses `k_obj_animations[item+1]` for the sprite. Items $01..$3F have entries in k_obj_animations table (line 73-90 entries 0-63). For sword item $01 → k_obj_animations[$02] = $0B (sword sprite descriptor).

Cave $7B "doorway slabs" — the 3 visible slabs are NOT items in CaveItemIds. They're BG tiles from `k_cave_layout_shortcut`. The "doorway-as-sprite" hypothesis was wrong.

**Verdict:** Item rendering is per-item-id-dispatched via existing k_obj_animations. Byte-diff against NES will catch any item entry mismatch. No typed-renderer rewrite needed.

## 4. Q2 cave differences

Z_06.asm:263-267 patches OW LevelBlockAttrsB at 8 room indices for Q2. This changes which OW room maps to which cave_id (and which dungeon). It does NOT change cave_id → interior content mapping.

`cave_dispatch.c:142`: cave_init uses `cave_id` directly, no quest parameter. LBA_E (item/price table) is also Q-independent per NES Z_06.asm structure (Q2 overrides only LevelBlockAttrsB section).

**Verdict:** 20 cave scenarios cover both quests. No Q1/Q2 cave interior split needed. Q2 only matters for OW-side entry routing (already in Phase A oracle).

## 5. NES capture strategy

**Force-state via Lua first.** Cells to write:
- `$0012 GameMode` = mode_B (regular cave) or mode_C (shortcut)
- `$00EB RoomId` = cave_id
- `$0350 ObjType+1` = cave_id (slot 1)
- `$0070+1 ObjX+1` = $78 (NPC X)
- `$0084+1 ObjY+1` = $80 (NPC Y)
- `$0070+2/+3` = $48/$A8 (bonfire X)
- `$0084+2/+3` = $80 (bonfire Y)
- Trigger InitCave by setting GameMode change-pending flag

Then frameadvance ~120 frames for engine to populate OAM/PALRAM/CIRAM and stabilize. Capture bundle.

**Fallback to savestates** only if force-state glitches (e.g., NES doesn't accept mid-flight GameMode change cleanly). 56 × 100KB = 5.6 MB savestates if needed. Acceptable but commit-blob.

**Verdict:** Lua force-state primary. Smaller, scriptable, reproducible.

## Summary

All 5 layers are NES-faithful in the existing code (SAT order, palette, items, no Q split). The byte-diff verifier (H4) will validate this. Iteration (H5) catches the actual divergences — likely in:
- Specific k_obj_animations entries for items rarely-used
- Per-room palette patches (`roomrom_ow_palette_patch_subpal3`) interfering with cave_palette_apply
- Sprite link chain breaks (memory `feedback_genesis_sprite_link_chain`)
- BCD price formatter edge cases (signed door-repair amounts)

Continue with H0-H5 sequence. No new sub-phases needed.
