# T-110 bomb / fire in NES slots $10/$11 — evidence

ROM: see `rom_sha256.txt` (built from main + T-110 files, without T-105 WIP).
NES: `roms/Legend of Zelda, The (USA).nes`. Harness: `tools/lockstep` (presets
`t110_bomb`, `t110_fire`, `t110_bomb_enemy`), verifier `verify_weapon.py`.

## Object RAM (slots $10/$11: ObjState, ObjTimer, ObjX/Y, ObjDir, grid offset,
pos frac, q-speed, anim counter/frame; InvBombs, UsedCandle, hearts)

Genesis reads input after UpdateBombOrFire (NES before, T-102), so the Genesis
timeline is aligned one tick later (`--gen-lag 1`).

- `t110_bomb`: 240 ticks, 2 differing cells, both at tick 141: Genesis shows the
  placed-but-not-yet-updated state $11 with InvBombs already decremented for the
  one tick before its UpdateBomb runs (the same T-102 artifact seen at tick 0).
  Fuse $30/$18/$0C/$06, clouds, clear, second bomb, third-B refusal while the
  other slot holds a bomb < $13: identical. Lag frames 0/0.
- `t110_fire`: 200 ticks, 1 differing cell: HeartPartial at tick 44 (fire hits
  Link one tick later on Genesis because Genesis runs weapons before moving Link,
  T-102). Damage value ($FF->$7F), Link invincibility $18, shove dir $84 equal.
  Travel 0.5 px/frame to |grid| $10, stand $3F, anim toggle every 4, blue-candle
  refusal: identical.
- `t110_bomb_enemy` (staged stunned Tektite at the blast point, relative to each
  console's Link): kill on the same tick, metastate $10, shove $C2, invincibility
  $10 identical.

## Sprites / tiles / palette (final-frame dumps)

- Mid-explosion (odd FrameCounter): 8 cloud sprites, NES OAM x/y/h-flip ==
  Genesis SAT x/y/h-flip, tile $70, 8x16, front priority.
- Bomb body: NES OAM ($7C,$7D) t=$34 a=$01 == SAT (7C,7D) ITEM atlas 20, PAL2.
- Fire: NES OAM $5C/$5E at ($78/$80,$6D) a=$02 == SAT tiles 963/965, PAL3.
- Tile pixels: NES CHR $34/$35, $5C-$5F == VRAM 945/946, 963-966; cloud $70-$75
  (+4 bias) == VRAM 1300-1305. All MATCH.
- Palette: cloud PAL1[5..7] = LUT(NES $3F15-$3F17).
- Bomb flash grayscale (both consoles mid-flash): 29/30 NES-mapped CRAM entries ==
  LUT(NES PALRAM & $30). The miss, PAL1[15], holds a non-NES color before the
  flash (sprite sub-pal 3 is not carried on Genesis, bg_palette.h).

## Not verified

- UW bombable wall (Bomb_CheckState4): implemented, no NES capture. Blocked: no
  way to put both consoles in the same UW room — routes diverge at the first
  scroll (T-105: Link parks at X $F0 NES vs $BF Genesis) and the existing NES
  force-state probe does not load a room. Tracked as T-114.
- Audio: request cells written; no consumer until T-071.
