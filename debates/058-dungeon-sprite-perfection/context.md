# Debate 058: Every UW dungeon sprite + animation byte-perfect vs NES.

## Following debate 057 (cave-scene parity)

Caves done: 56/56 visual sweep PASS + plan I0-I5 (~9h) for byte-exact.

This debate: dungeons (UW). 18 dungeon scenarios (L1-L9 × Q1+Q2).

## Locked answers (carried from 057)
- Strictness: BYTE-EXACT OAM/CHR/PAL after NES->Gen normalization
- Scope: every sprite + every animation phase per UW level/quest
- Animation: parity first, Genesis improvements opt-in
- Verification: long-term CI byte-diff golden bundle

## Current Genesis dungeon state
- 18/18 dungeon entries dispatch correctly (s_scene=UW + correct level + start_room)
- 18/18 dungeon exits work via doorway $7D + bypass
- UW BG render via roomrom_uw_room_render (src/game/world/render/uw_render.c)
- UW palette per-level (different colors per L1-L9)
- Enemies populate via enemy_loop_room_init (slot 1-10)

## Dungeon sprite inventory (per NES Z1)
1. Enemy slots 1-N: Stalfos/Keese/Goriya/Wallmaster/Like-Like/Zol/Gel/Vire/Bubble/Darknut/Wizzrobe/...
2. Boss slots: Aquamentus/Dodongo/Manhandla/Gleeok/Digdogger/Gohma/Patra
3. Link slot 0: full action — walk/sword/shield/bomb/arrow/candle/boomerang/wand
4. Item drops: hearts/rupees/keys/bombs/clock/fairy/triforce piece
5. Projectiles: arrows/boomerang/bombs/magic shots/fire/whirlwind
6. Doors: 4-directional door states (open/closed/locked/bombed/shutter)
7. Stairs: up/down stair tiles
8. Pushblocks: visible position offsets per Z_05.asm pushblock state

## NES authority
- Z_01.asm:1958 ObjAnimations (covers ALL enemies + items)
- Z_01.asm:1977 ObjAnimFrameHeap (covers all sprite frames)
- Z_07.asm enemy_loop dispatch + drains
- Z_04.asm boss draw paths (bosses use over-Link priority)
- reference/aldonunez/Variables.inc enemy slot RAM cells
- Variables.inc:330 LevelInfo_PalettesTransferBuf — per-level UW palette source

## Question
How get EVERY dungeon sprite + EVERY animation byte-perfect vs NES across all 18 dungeon entries (and dungeon UW rooms beyond start_room)?

Cover:
1. **Enemy sprite parity** — Stalfos / Keese / Goriya per level. ObjAnimations + ObjAnimFrameHeap verbatim port. Verify each enemy type's tile cycle.
2. **Boss sprite parity** — Aquamentus (L1), Dodongo (L2), Manhandla (L3), Gleeok (L4), Digdogger (L5), Gohma (L6), Patra (L7), Aquamentus L8, Ganon (L9). Each boss has multi-state animation.
3. **UW palette per level** — 9 different palettes. L1=teal, L2=red, L3=green, etc. Verify Genesis loads correct per-level pal.
4. **Item drop sprite** — small items (rupee/heart/clock) byte-exact.
5. **Door animations** — bombable door explosion, shutter door slide, key-lock open.
6. **Verification** — extend cave_golden infra to uw_golden. Per (level, quest, room_id) bundle.

400 words per advisor. file:line citations. Effort estimates.
