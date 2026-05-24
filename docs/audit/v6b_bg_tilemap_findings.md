# v6-B BG tilemap deep investigation findings

## NES OW attribute path
Per `reference/aldonunez/Z_05.asm:984` `FillPlayAreaAttrs`:
```asm
LDA LevelBlockAttrsA, Y    ; Y = RoomId
AND #$03                   ; outer palette selector
TAX
LDA RoomPaletteSelectorToNTAttr, X
; Fill all 48 PlayAreaAttrs[0..$2F]
LDA LevelBlockAttrsB, Y
AND #$03                   ; inner palette selector
TAX
; Loop Y=9..$26, skip edges, write inner attr
```

`RoomPaletteSelectorToNTAttr[4] = {$00, $55, $AA, $FF}`
- $00 = all sub-pal 0
- $55 = all sub-pal 1
- $AA = all sub-pal 2 (GREEN for r$00)
- $FF = all sub-pal 3 (BROWN)

## r$00 expected per asm
- LevelBlockAttrsA[0] = $A3 (from `dat/LevelBlockOW.dat` byte 0)
- $A3 & $03 = 3 → outer = $FF (brown)
- LevelBlockAttrsB[0] = $27, & $03 = 3 → inner = $FF (brown)
- FillPlayAreaAttrs result: all $FF → all brown

## NES r$00 ACTUAL nt0_attr (live dump)
```
00 00 40 00 00 44 55 55 00 00 04 00 00 44 55 55  ; HUD rows (bytes 0..15)
AA AA AA AA AA AA AA AA AA AA AA AA AA AA AA AA  ; Play area row 1 — sub-pal 2 GREEN
AA AA AA AA AA AA AA AA AA AA AA AA AA AA AA AA  ; Play area row 2
... AA throughout
```

Play area cells = $AA = sub-pal 2 = GREEN. Matches green-trees screenshot.

## Discrepancy
- Asm says outer&3=3 + inner&3=3 → $FF brown
- Live nt0_attr shows $AA green
- Either:
  - Gen extracted wrong LevelBlockOW bytes (mismatched offset)
  - NES uses a path beyond FillPlayAreaAttrs that overrides
  - NES uses bits 4-5 not bits 0-1 of LBA_A ($A3>>4 & 3 = 0xA & 3 = 2 — could explain $AA)

## Next step
Read NES live $6AFE.. (LevelBlockAttrsA NES RAM addr) post-r$00-transition.
If byte != $A3, Gen extract is wrong. If = $A3, NES asm uses different bits.

Either fix Gen extract OR change ow_tile_palette logic.
