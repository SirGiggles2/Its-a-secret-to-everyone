# T-050 OW tile objects ($62-$67) + pond fairy ($2F) — evidence

ROM: `rom_sha256.txt`. Harness: `tools/lockstep` presets `t050_*`,
verifiers `verify_play_area.py` (NES PlayAreaTiles $6530-$67DB vs Genesis
mirror) and `verify_plane.py` (NES nametable tile + attribute sub-palette ->
expected Genesis plane tile index, 704 playfield cells; reports tile identity
and sub-palette separately).

| Scenario | What happens | PlayAreaTiles | Plane |
|---|---|---|---|
| `t050_layout_plain` | enter $78 (tree object) | 704/704 | 704/704 exact |
| `t050_layout_secret` | enter $78 with world flag $80 (tree -> stairs at layout) | 704/704 | 704/704 exact |
| `t050_tree` | blue candle fire on the $78 tree | 704/704 | 704/704 exact |
| `t050_wall` | bomb on the $76 rock wall | 704/704 | 704/704 exact |
| `t050_rock_push` | bracelet push of the $79 rock, leave to $78, re-enter $79 (CheckShortcut) | 704/704 | tiles 704/704; sub-palette 0/704 (T-115) |

Object RAM (slot $B) vs NES, per run logs in this folder:
- Placement at room entry: type/X/Y/state/q-speed $20/ObjAttr $81 after init
  match; HP $F0 (tree) matches after extending ObjectTypeToHpPairs with the
  ROM bytes that follow it. ObjUninitialized differs (NES 0, Genesis 1):
  Genesis reuses $492 as its own alive flag for every enemy (pre-existing).
- Tree: reveal when the standing fire timer reaches 1; flag $80, slot
  destroyed as DestroyMonster_Bank4 (type 0, metastate 1, uninit $FF).
- Wall: reveal on the detonation tick; flag $80.
- Rock: push, 16 px move, gray floor then rock square, stairs at the shortcut
  position, MarkRoomVisited ($20); on re-entry CheckShortcut writes the stairs
  and the rock object is placed again.
- Genesis events run one frame later than NES (T-102 input/tick order).

Found, not T-050 (tracker rows):
- T-115: OW nametable sub-palette forced to 2 for every room; NES room $79
  uses sub-palette 3 (plane 0/704 exact, tile identity 704/704).
- `t050_rock_push`: Genesis Link hit by a Tektite during the push (enemy
  positions differ, T-108 residue); Genesis lag frames in busy $79 at the
  hit and at the reveal frame (T-080 budget).
- Genesis Link movement does not run CheckTileObjectsBlocking (Link port).

## Pond fairy ($2F, room $39) — `t050_pond_fairy`

Route $77->$78->$68->$69->$59->$49->$39 (edges from `tools/lockstep/ow_map.py`,
Link staged at each crossing), save with 1 heart (HeartValues $20, partial
$80), Link staged at the pond edge ($78,$AD). ROM `rom_sha256_pond.txt`.
- UpdatePondFairy states 0->1->2->3, Link halted ($AC=$40) and released on
  the same frames as NES (1301 / 1408 / 1488); World_FillHearts refills
  $20/80 -> $22/FF at +6 per frame (Genesis applies each step one frame
  later: fill runs before the object update, T-102).
- Hearts (slots 2-9): state, X, Y, angle whole/frac identical 624/624
  (frames 1410-1487).
- Sprites at frame 1450: NES OAM fairy $50 + 8 hearts $F3 == Genesis SAT
  x/y/palette (Link draws in fixed SAT slot 0); tile pixels NES $50/$51 ==
  VRAM 1021/1022, PT1 $F2/$F3 == VRAM 1025/1026 (the $F3 heart was drawn from
  the scene bank before this fix).
- Regression after the room-entry q-speed $20 default: `tektite_jump`
  motion identical (X differs by the staged per-console offset only),
  `t050_tree` / `t050_wall` 704/704 + 704/704, `t110_bomb` unchanged.
