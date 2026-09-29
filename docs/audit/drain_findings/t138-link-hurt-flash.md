# T-138 — Link hurt-flash palette and pixels

- **NES source:** `reference/aldonunez/Z_01.asm:Anim_WriteSpritePair`; `Z_07.asm:@ChooseTileObjPalette`; `Z_06.asm:GhostPaletteRow7TransferBuf`, `GreenBgPaletteRow7TransferBuf`, `BrownBgPaletteRow7TransferBuf`, `RedArmosPaletteRow7TransferBuf`.
- **Drained C:** `src/game/world/draw_dispatch.c:anim_write_sprite_pair` patches NES OAM attr with `ObjInvincibilityTimer & 3`; Genesis Link SAT path is `src/game/world/render/sprite_render.c` via `RoomRom/src/main.c`.
- **Coverage:** FULL for the representative Original OW hurt walk and sword-attack flash; broader room palette coverage remains P3/T-030 and T-159.
- **Stance:** EXTEND the linked Link sprite path and active OW palette loader.

## Reproduction and correction

2026-09-28 current-ROM NES/Genesis BizHawk capture used `t138_hurt_flash`: natural damage in OW room `$79`, identical Link position, invincibility timer and gameplay KEY cells. Before repair, Genesis selected PAL0..PAL3 from its frame counter; NES OAM selected sprite sub-palettes `0,3,3,2,2,1,1,0` across ticks 318–325. Genesis instead used `1,3,0,1,2,3,0,1`, including PAL0's background colors. The fourth NES sprite palette also had no exact Link tile route.

Link walk and attack now select the NES timer phase. Phases 0/1/2 route to Genesis PAL1/PAL2/PAL3. Phase 3 uses 48 persistent Link tiles with pixel indices 1..3 biased to 13..15 on PAL1; it does not rewrite CRAM or upload CHR per gameplay tick. VRAM verifier reserves tiles 1378–1425 and reports 110 tiles of tail headroom before VDP tables.

The active Original OW palette loader now chooses NES sprite row 7 from the room tile-object type and installed `LevelBlockAttrsB`, following `Z_07.asm`. In room `$79`, NES rock `$62` and odd attr `$83` choose brown `$0F/$17/$37/$12`. The old per-room scan table claimed `$0F/$0F/$1C/$16`, so it cannot supply this flash; see T-159. Genesis PAL1[13..15] now equals live NES PALRAM row 7 for this room. Redux palette setup remains on its existing branch.

## Focused verification

`Debug.bat` PASS. Final focused ROM SHA-256: `a879dc2a463213d5b59a4d4681d41e24dd652a5895be60b59d3bc2736f87cf53`. It also contains Claude's uncommitted T-013 work in `RoomRom/src/main.c`; no T-013 hunk was staged with this task.

| Preset / action | NES–Genesis gameplay KEY | Link colored pixels vs NES PALRAM/Genesis CRAM | End condition |
|---|---:|---:|---|
| `t138_hurt_flash`, natural rock-room damage, ticks 318–325 | 370/370 | 1216/1216 exact | Timer reaches zero at tick 364; Link returns to normal palette |
| `t138_hurt_attack`, controller A during same natural hurt, ticks 327–335 | 350/350 | 1501/1501 exact | Sword pose and all four flash phases visible |

Reproduce with each preset's `_note` command and `python tools/lockstep/verify_link_hurt_flash.py builds/reports/lockstep/<preset> <listed ticks>`. Raw screenshots, OAM, CHR, PALRAM, SAT/VRAM and CRAM are under `builds/reports/lockstep/<preset>/`; Genesis `run_gen/launch.json` records ROM identity. Both emulator runners exited zero. These new focused preset names have **no full-RAM ratchet baseline**: their overall GATE reads FAIL for 75–76 known unmasked initialization/scratch cells, with zero KEY failures. We do not treat that GATE as a pass. Verification establishes Link's two visible sprite halves and colors, not whole-frame equality or all dungeon palette states.
