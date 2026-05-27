# Debate 057: Every cave sprite + animation byte-perfect vs NES (and improved on Genesis where possible).

## Locked answers
- Strictness: BYTE-EXACT OAM/CHR/PAL after NES->Gen normalization
- Scope: EVERYTHING — every sprite + every animation phase per cave_id
- Animation depth: "Make the NES game run best for Genesis (or even better than NES because Genesis is better)"
  → byte-exact parity first; then opportunistic Genesis upgrades (more colors, 16-color palettes, higher frame rates) where they don't break perceived NES feel
- Verification: best long-term — pick the verification infra that lasts

## Current Genesis state
- 20 caves dispatch correctly (cave_id $6A..$7D in ObjType[1])
- cave_init at src/game/cave/cave_dispatch.c:93-168:
  - Slot 1 NPC at ($78, $80), ObjType+1 = cave_id
  - Slot 2/3 bonfires (ObjType=$40, StandingFire) at ($48, $80) + ($A8, $80)
  - CaveItemIds/CavePrices populated from NES SRAM LBA_E ($6A7E)
- cave_draw_person at cave_dispatch.c:685-700 → draw_object_mirrored/not_mirrored
- draw_object_mirrored at src/game/world/draw_dispatch.c:440 → k_obj_animations[OBJ_TYPE+1] indexes into ObjAnimFrameHeap
- Tables (Z_01.asm:1958 ObjAnimations + 1977 ObjAnimFrameHeap) ported VERBATIM as k_obj_animations[127] + k_obj_anim_frame_heap[228]
- Frame cadence: NES uses FrameCounter ($0015). Bonfire StandingFire — enrt_update_standing_fire per frame.
- Palette: cave_palette.c k_cave_subpal_2_3_nes (8 bytes) hardcoded per Z_06.asm:714. One palette ALL caves.
- 56/56 visual sweep PASS via probe (bypass for L3Q2/L7-L9 hidden entries)

## NES authority
- Z_01.asm:1958 ObjAnimations (127 entries, OBJ_TYPE+1 indexed)
- Z_01.asm:1977 ObjAnimFrameHeap (228 entries, tile id per frame)
- Z_01.asm:2094 DrawObjectWithType
- Z_01.asm:4979 DrawObjectMirrored
- Z_06.asm:714 cave palette
- Z_07.asm enrt_update_standing_fire
- Z_03.asm:328 cave_person draw gate (FrameCounter bit gate)

## Cave sprite inventory (per NES Z1)
1. NPC slot 1: Old Man (sword/medicine) / Merchant / Woman / Moblin (shortcut) — sprite per group
2. Bonfire slots 2/3: StandingFire — 2-frame loop, palette flicker
3. Ware item slots: items $00..$3F drawn at k_cave_ware_xs positions (Z_01.asm:385)
4. Selection cursor: ware-purchase pointer
5. Link slot 0: NPC-locked walk pose, halt on $40
6. Bonfire flicker: sub-palette modulation per frame

## Question
How get EVERY sprite + EVERY animation byte-perfect vs NES per cave_id $6A..$7D (and improve on Genesis where possible)?

Cover:
1. **CHR coverage** — every tile id used by every cave-scene sprite, mapped NES tile -> Gen VRAM. Verify atlas (data/chr/MANIFEST.json) has all of them.
2. **OAM byte-exact** — slot order, X/Y, tile_id, attr, flip, priority per frame. Across animation cycle.
3. **Palette** — k_cave_subpal_2_3_nes vs NES $3F1x dump. Any palette flicker / hit-flash cycles.
4. **Animation cadence** — every animated sprite (bonfire, sword shine, item bob, person walk if any) — verify frame phase advance matches NES tile_id sequence.
5. **State machine — visible state transitions** — CavePersonState 0..8 (textbox states) — what sprites change between states.
6. **Genesis improvements** — where can Genesis beat NES without breaking feel? (60fps anim, smoother flicker, 16-color sprite palette utilization, higher-res tiles)
7. **Verification infra** — long-term: how do we prevent regression? Per-cave golden bundle (OAM+PAL+CHR snapshots) committed; CI hits each cave_id and byte-diffs vs golden.

300 words per advisor per round. Be SPECIFIC. file:line citations. Effort estimates per step.
