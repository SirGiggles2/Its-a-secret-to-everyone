# Round 1 — Sonnet (Pragmatic Implementer)
## Debate 058: Dungeon sprite/animation parity

---

### 1. Enemy sprite parity

Animation table plumbing exists via `z07_anim_advance_and_fetch`
→ `sprite_anim_advance_and_fetch` (enemy_walker_bridge.c:194).
`ObjAnimations` + `ObjAnimFrameHeap` verbatim porting is not present as
a compiled C table; the bridge calls the transpiled shim which reads from
the NES RAM mirror. **Likely bug**: any enemy type whose update body is not
yet wired (rows left NULL in the dispatch table) silently skips the anim
tick and parks at frame 0. Cross-check every row in the init table
(enemy_loop.c:455–630) against the update table (enemy_loop.c:641–1050):
rows $0B/$0C Darknut, $29 Rope, $12/$13 Bubble are present in the NES
table (Z_07.asm:5295–5388) but have no explicit C row — confirming they
either default to NULL or fall through to unrelated update bodies.
**Effort**: 1 probe per family to confirm NULL = no-op vs wrong dispatch,
then drain body per type (~2h for the 6 missing walker families).

---

### 2. Boss sprite parity — the critical gap

All 9 boss update rows are wired (enemy_loop.c:873–983). No
`boss_aquamentus.c` or `boss_ganon.c` file exists — Aquamentus update is
`enrt_update_aquamentus` (enemy_dispatch.c:135) which is a one-liner
initializer stub. Ganon is `enrt_update_ganon` from `enemy_ganon_bridge.c`
which explicitly warns "boot-smoke only — Ganon does not render or move"
(enemy_ganon_bridge.c:6). **No boss has verified sprite output.** The
atlas has 192 tiles in `bosses.c` (MANIFEST: 6144 B / 32 B per tile =
192 tiles), but there is no manifest table mapping those tile offsets to
NES boss tile IDs, so there is no guarantee the right tiles land in VRAM
when the boss room is entered. This is the direct analogue of the cave SPR
sub-pal gap from debate 057: tiles are extracted but the per-boss VRAM
upload path + tile-ID-to-atlas-offset mapping has not been probed.
**Effort**: 1 NES OAM probe per boss (14 probes total, ~3h), atlas audit
comparing NES tile IDs against bosses.c offsets, then VRAM upload fix per
boss (~4h).

---

### 3. UW palette per level — confirmed partial gap

`load_palette_from_blob` (uw_render.c:167) calls
`roomrom_bg_palette_load_palram_full` which loads **both** Gen PAL0 (BG)
and Gen PAL1 (SPR) from the captured 32-byte blob. That path is correct
when a room blob exists. `load_palette_from_levelinfo` (uw_render.c:174)
falls through to `roomrom_bg_palette_load_bg_only` with a comment "Sprite
half (PAL1) preserved from prior room load" (uw_render.c:210). That
preservation is only safe if the prior load was for the same level — on
first entry when the blob lookup misses, PAL1 retains whatever the OW or
inventory palette left. Bug magnitude: enemies use PAL1; wrong PAL1 =
wrong enemy colors on any level with uncaptured rooms. **Effort**: confirm
which levels have full room blob coverage, then either capture missing
rooms or force the SPR half from per-level NES PALRAM capture (~2h).

---

### 4. Item drop sprite — explicit deferred stub

`item_object_update` (item_object.c:120–124) contains a comment:
"AnimateItemObject lookup table (NES item-sprite anim) is deferred — drop
currently renders as whatever the type-$60 sprite map produces." The
`draw_animate_item_object` function at draw_dispatch.c:674 *is* implemented
with `k_item_id_to_descriptor` + `k_item_id_to_slot` tables (36 entries).
The wire-up gap is in `item_object_update` which skips the call.
One-line fix: add `draw_animate_item_object(META_ITEM_ID(slot), slot)`
in item_object_update. **Effort**: 30 minutes + 1 NES probe to verify
tile/palette per item type.

---

### 5. Door animations — BG tile patch only, no sprite anim

`door_state.c` patches 4 BG tiles per direction via
`s_open_patches[DOOR_DIR_COUNT][4][3]` (door_state.c:37). Door explosion
and shutter-slide are sprite animations in NES Z_05.asm, not BG patches.
No `door_anim.c` or shutter sprite path exists anywhere in `src/game/`.
**Effort**: 1 NES OAM probe at bomb-explosion frame and shutter-slide
frame to get tile IDs + positions, then implement sprite emitter (~3h).

---

### 6. Verification — extend dungeon_visual_sweep to UW golden

The cave sweep infrastructure lives in `tools/parity/dungeon_visual_sweep/`
with `probe_nes_one.lua` / `probe_one_gen.lua` / `run_sweep.py` /
`verify_sweep.py`. Extending to UW requires: (a) parameterize scenario
list for (level, quest, room_id) triples, (b) add OAM + PALRAM columns
alongside the existing screenshot diff, (c) gate CI on byte diff of SAT
dump not just PNG size. `expected_divergence.json` (tools/parity/) and
`tolerances.yaml` already exist as the tolerance layer. **Effort**: ~3h
scaffolding for 18 dungeon entry scenarios + ~2h per-boss room additions.

---

### Summary of gaps by priority

| Gap | Severity | Effort |
|---|---|---|
| Boss tiles: no verified VRAM upload or tile-ID mapping | Critical | ~7h |
| NULL dispatch rows for 6+ enemy families | High | ~2h |
| UW SPR palette (PAL1) not loaded on levelinfo fallback | High | ~2h |
| Item drop AnimateItemObject not called in update | Medium | ~1h |
| Door/shutter sprite animations unimplemented | Medium | ~3h |
| uw_golden CI bundle | Infra | ~5h |
