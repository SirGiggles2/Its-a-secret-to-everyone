# Opus R2 — Verdict: code IS per-cave-specific. Sonnet's path wins.

## Evidence (read live code)

**`cave_draw_person` at `cave_dispatch.c:685-700`** calls `draw_object_mirrored(0, slot=1)`. That function (`draw_dispatch.c:440-445`) sets `anim_idx = OBJ_TYPE(slot) = cave_id`. Then `draw_object_with_type` → `draw_object_with_anim` (`draw_dispatch.c:411`).

**Per-cave dispatch lives at `draw_dispatch.c:360`**:
```c
tile_idx = k_obj_animations[anim_idx] + frame;
left_tile = k_obj_anim_frame_heap[tile_idx];
```

`k_obj_animations[127]` at `draw_dispatch.c:73-90` is **the NES table ObjAnimations from Z_01.asm:1958**. Already ported. Already 127 entries. Already covers ObjType $6A..$7D (indices 107..126).

## Per-cave_id mapping (extracted from table)

ObjType → k_obj_animations entry → tile_id in frame_heap:
- $6A..$6E → $C6 (old man sprite — NES shares one sprite across 5 cave types)
- $6F..$70 → $C8 (variant person)
- $71..$72 → $C9
- $73..$76 → $CA (woman / merchant)
- $77..$7A → $CA
- $7B..$7C → $09 ("any road" doorway symbol — 3 slabs)
- $7D → $0A

**This is NES-authoritative.** Multiple cave_ids legitimately share NPC sprites — that's how NES works. Our captured PNGs reflect this exactly: cave_6A and cave_7B render differently (different table entries), cave_77 and cave_7A render same (same $CA entry).

## NES authority

NES `Z_01.asm:1958 ObjAnimations` table. Ported verbatim to `draw_dispatch.c:73`. Frame heap at `Z_01.asm:1977 ObjAnimFrameHeap` ported to `draw_dispatch.c:93`.

## Per-cave NT / CHR

Cave interior BG = **fixed nametable** at NES `Z_07.asm` CaveLayout (single layout for all caves; the variation is in sprite slot dispatch, not BG). Phase D port at `src/game/world/render/cave_fade.c` SWAP_ENTRY loads this fixed nametable. **No per-cave NT extraction needed** — NES doesn't have per-cave NTs.

Person CHR = preloaded into CHR-RAM at cave entry, shared across all caves. Item CHR uses standard sprite atlas.

## Verdict

**Sonnet wins.** Code dispatch is correct per NES authoritative tables. The current "all caves look samey" is NES-faithful behavior for cave_ids that NES groups together. Real divergences (palette, sprite positioning, text content per cave) need byte-diff verifier to surface.

**Codex's "CaveLayout cave_layouts[]" rewrite is wrong** — would diverge from NES authority. NES doesn't have a per-cave layout struct; it has ObjType-indexed dispatch which we already have.

## Adjusted plan

Drop Codex's typed-renderer rewrite. Keep:
1. H0 (5min) CAVE_ID_MAX fix → cave_7D works
2. H1 (2h) s_link_grid_offset force-zero → dungeons trigger
3. H2 (30min) scenarios.json cave_78 ow_room_id fix
4. H3 (4h) NES baseline GDMP probe
5. H4 (6h) byte-diff verifier (CRAM/SAT/Plane A/STAT/char-stream)
6. H5 iteration: per-FAIL class, patch smallest owning C function

Total: 13-25h. Don't replace dispatch — it's already NES-correct. Just measure + fix divergences.
