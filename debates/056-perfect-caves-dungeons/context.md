# Debate: How get every Zelda 1 cave + dungeon interior BYTE-EXACT vs NES?

## Decisions locked
- Definition of "perfect" = byte-exact NES parity (OAM/CIRAM/PALRAM byte-identical after NES->Gen LUT)
- Blocker = ALL of them at once (per-cave layout drift, no NES baseline, lenient verifier)
- Scope = full port + manifest
- Verification = ALL methods (byte-diff oracle, pixel-diff mosaic, char-stream, eyeball)

## Current Genesis state
- 20/20 caves DISPATCH correctly (s_scene -> CAVE, ObjType[1] = cave_id $6A..$7D)
- BUT all caves visually render with same template (3 slabs + bonfire + symmetric items)
- cave_dispatch.c has TODOs:
  - D1: StandingFire bonfire SAT publish (slot 2/3 ENEMY_ALIVE but no SAT)
  - D2: cave_draw_person Stage-1 stub (no per-cave OAM publish for old man/merchant/woman)
  - D3: Textbox states 1/3/6/7 NOT implemented (states 0/2/4/5 only)
  - D4: BCD price formatter TODO at cave_dispatch.c:275
- Dungeon entry path: requires force_mode_walk to bypass MODE_TELEPORT
- s_raw_tiles cache (BSS in ow_render.c) NOT writable from probe (only nes_ram mirror is)

## NES source authority
- reference/aldonunez/Z_01.asm:53-56 OverworldPersonTextSelectors
- reference/aldonunez/Z_05.asm:7313-7368 HandleWarpOW
- reference/aldonunez/Z_07.asm cave dispatch + bonfire enemy_loop
- reference/aldonunez/dat/Cave*.dat per-cave layouts (need extract)

## Target
20 caves $6A..$7D + 18 dungeon entries + 18 dungeon exits = 56 scenarios.
Each must byte-match NES on:
- OAM (after NES 4-byte -> Gen 8-byte SAT normalization + tile_id translation)
- PALRAM -> CRAM after canonical NES->Gen color LUT
- CIRAM nametable -> Plane A tile_id (normalized)
- Person/item state cells + text char stream

## Question
What is the COMPLETE plan to take this from 0/56 visual PASS to 56/56 byte-exact PASS?
Cover: (1) per-cave dispatch fix (port D1-D4 + manifest extraction), (2) NES baseline capture infrastructure, (3) strict byte-diff verifier with per-domain tolerances, (4) iteration loop to debug + retry per scenario.

What sequence of actions, what files touched, what probes written, what oracles built — be specific.
