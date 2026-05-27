# Debate 059: BG tile + palette byte-exact vs NES (caves + dungeons + OW).

## Following 057 (cave sprites) + 058 (dungeon sprites)

This debate: BG (background plane). NES nametables, attribute tables, palette upload, sprite-vs-BG priority.

## Locked answers (carried)
- BYTE-EXACT after NES->Gen normalization
- ALL scenes (OW, cave, UW, intro)
- Parity first, opt-in improvements
- Long-term CI byte-diff

## Current Genesis BG state
- OW: 128 rooms render correctly. Phase A LBA_B oracle 128/128 routes.
- Cave: 2 layouts (regular $6A..$7A + shortcut $7B..$7D). `roomrom_cave_room_render_fill_plane_a`.
- UW: per-(level, quest, room_id) blob render via `roomrom_uw_room_render`.
- Plane A holds active room. Plane B holds room transition scroll target.
- HUD on Window plane.

## BG sub-systems
1. **OW BG**: 128 rooms × 32×22 metatiles. Tile heaps + room layouts.
2. **OW palette**: per-room patches (`roomrom_ow_palette_patch_subpal3` for level entries).
3. **Cave BG**: 2 layouts (k_cave_layout_regular + k_cave_layout_shortcut). Single palette (k_cave_subpal_2_3_nes).
4. **UW BG**: per-room walkability + tile arrangement. Per-level palette.
5. **BG sprite priority**: Link behind tree top, behind cave arch top.
6. **Transition scroll**: H_LEFT/H_RIGHT/V_UP/V_DOWN, 120-frame scroll.
7. **HUD overlay**: hearts, rupees, keys, bombs, B-item, A-button cursor.
8. **Animated BG tiles**: waterfall, cave entrance pulse?

## NES authority
- Z_02.asm:* CHR bank swap per scene
- Z_06.asm OW LevelBlock heap layout
- Z_06.asm:714 cave BG palette
- LevelInfoOW.dat + LevelInfoUW*.dat per-level palettes
- Z_01.asm rooms_overworld blob

## Question
How get EVERY BG tile + palette byte-perfect vs NES across all scenes?

Cover:
1. **OW per-room nametable byte-exact** — 128 rooms decoded from heap + secondary squares + col_dirs. Diff against NES PPU NT dump.
2. **OW palette per-room** — 128 rooms × 4 sub-pals each. Patches for level entry rooms.
3. **Cave BG** — 2 layouts × per-cave colorations.
4. **UW BG per room** — 9 levels × 2 quests × 128 rooms = up to 2304 unique UW rooms. Byte-exact.
5. **BG priority** — sprite-behind-BG cases (cave arch top, tree top). 8x8 priority masks.
6. **Animated BG** — waterfall, lava, candle-fire-revealed walls.
7. **Verification** — bg_golden bundle per scene. Per (scene, room_id) NT+attr+palette+priority_mask.

400 words per advisor. file:line. Effort estimates.
