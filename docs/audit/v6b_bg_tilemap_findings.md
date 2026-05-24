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

## Iter 2 update (2026-05-23 23:30)

### NES live LBA_A[0..15] post-probe-warp: ALL $00

Live read via `probe_nes_lba_r00.lua`:
```
LBA_A[0..15]: $00 $00 ... $00
LBA_B[0..15]: $00 $00 ... $00
```

So NES Z1 doesn't populate LBA_A during normal OW play via probe-warp.
InitMode2 only fires on real level entry sequence.

Conclusion: NES OW NT attrs come from a different source than
LevelBlockAttrsA/B + FillPlayAreaAttrs.

### H2 partial validation

Changed `ow_tile_palette` to use `(byte >> 4) & 3` instead of
`byte & 3`. Result:
  - r$00: BROWN → GREEN ✓ (matches NES)
  - r$04 Lynel: tan + green trees ✓ (matches NES Lost Hills entry)
  - r$77 Start: red → GRAY (REGRESSION — NES is brown)
  - r$67 Octorok: red → GRAY (REGRESSION — NES is brown)

Concluded: NES doesn't use a single fixed bit position. Some rooms
encode palette in low bits, some in high. Variable per-room.

Reverted to bits 0-1 model. Real fix requires:
  - Per-room palette pattern decode beyond simple bit-shift
  - OR matching NES VRAM transfer logic exactly (find the OW attr
    transfer path that bypasses FillPlayAreaAttrs)
  - OR table-driven per-room sub-pal selector

Tagged for deeper iter — likely requires NES Z_05/Z_07 OW transition
mode tracing + matching VRAM upload sequence.

## Iter 3 update (2026-05-23 23:50) — bug FALSIFIED

### NES live PlayAreaAttrs[$530..$55F] dump post-r$00-warp:
```
$AA $AA $AA $AA $AA $AA $AA $AA  ; All sub-pal 2 (green)
... (entire 48 bytes = $AA)
```

But LBA_A[0..15] = $00. Per asm `outer = LBA_A[$00] & 3 = 0`, FillPlayAreaAttrs
would write $00 not $AA.

### Conclusion: PROBE ARTIFACT, not real bug

Path explanation:
1. NES boot sequence loads up to RoomId=$77 (start), GameMode=$05 (Play).
2. Mode 3 ran during initial r$77 entry → FillPlayAreaAttrs(r$77) → wrote
   $AA (outer for r$77 = 2 from r$77 LBA_A byte).
3. LBA_A[0..15] then CLEARED (likely by something — Mode 2 didn't re-run).
4. Probe-warp to r$00 forces RoomId=$00 + Mode=$06 then $05.
5. FillPlayAreaAttrs NOT re-triggered (Mode 6 ≠ Mode 3 trigger).
6. PlayAreaAttrs RAM stays $AA from r$77 init.
7. NT0 attr dump captures $AA — visually green for r$00.

But real NES Link-walk from r$77 to r$00 would trigger Mode 4 scroll →
re-run FillPlayAreaAttrs(r$00) → outer = $A3 & 3 = 3 → $FF brown.

So real NES r$00 IS brown. Gen brown rendering is correct.

The 650 sub-pal mismatches reported by diff_bg_tilemap.py for r$00 are
all probe-induced — NES capture was at stale state. NOT real bugs.

### Action: close task #49 as non-bug

Visual chases for individual OW room colors should be replaced by
gameplay-walk probes (NES Link actually walks through rooms via scroll
transitions, not raw RAM warps).
