# T-115 OW nametable sub-palettes — evidence

Bug: `ow_render.c` drew every OW playfield with outer = inner = sub-pal 2
("NES PlayAreaAttrs always $AA", 2026-05-23). NES FillPlayAreaAttrs uses
LevelBlockAttrsA & 3 (outer) and LevelBlockAttrsB & 3 (inner) per room.

- NES attribute tables (CIRAM $3C0) in captured rooms: $76 2/2, $78 2/2,
  $79 3/3, $39 3/2 == A&3 / B&3 of the room.
- Sweep: Genesis `rooms_overworld` A/B tables == NES WRAM LevelBlockAttrsA
  ($687E) / B ($68FE) for all 128 OW rooms (bytes 128/128 each). Outer/inner
  combos over the OW: 3/3 x73, 2/2 x35, 0/0 x8, 3/2 x7, 2/3 x3, 3/0 x2 —
  93 of 128 rooms were drawn with the wrong sub-palette before the fix.
- Atlas coverage: every layout tile of every OW room has its
  (tile, sub-pal) slot. Squares written only by secrets/pushes (stairs
  $70-$73, rock $C8-$CB, gravestone $BC-$BF) lacked 18 combos (sub-pal 0/3;
  e.g. $79 shortcut stairs drew blank). gen_bg_sparse.py force-includes them;
  atlas 637 -> 655 tiles; VRAM budget gate OK (BOSS_PAL3 ends 1110 < 1280);
  freshness gate 8/8.

Byte verification (lockstep, NES vs Genesis, `verify_plane.py` now fails on
unmapped combos):

| Scenario | room | plane playfield | PlayAreaTiles | BG PAL0 vs PALRAM | BG tile pixels |
|---|---|---|---|---|---|
| t050_layout_plain | $78 | 704/704 | 704/704 | | |
| t050_layout_secret | $78 | 704/704 | 704/704 | | |
| t050_tree | $78 | 704/704 | 704/704 | 12/12 | 21/21 |
| t050_wall | $76 | 704/704 | 704/704 | 12/12 | |
| t050_rock_push | $79 (3/3) | 704/704 | 704/704 | 12/12 | 29/29 |
| t050_pond_fairy | $39 (3/2) | 704/704 | 704/704 | 12/12 | 38/38 |

Sprite tiles after the +18 SPR/ITEM shift, pixels == NES CHR: bomb $34/$35,
fire $5C-$5F, fairy $50/$51, heart PT1 $F2/$F3, Link $0C/$0E (pond frame).
