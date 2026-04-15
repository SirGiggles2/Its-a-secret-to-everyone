# Phase 12 Probe Findings — Zelda27.86

Source: `builds/reports/phase12_probe.txt`

## Defect 1 — FS1 heart cursor misaligned

**Probe A data** (CurSaveSlot=$03, which is REGISTER):
- heart sprite (spr0): screen (40, 169), tile=$1F2, pal=1
- REGISTER text row (Plane A row21) at screen Y=168
- slot 0/1/2 Link rows at screen Y = 93/117/141 (matches Mode1CursorSpriteYs $5C/$74/$8C + 129 − 128)
- **Vertical alignment fine** — heart Y=169 ≈ REGISTER row Y=168
- **Horizontal off by 8** — heart X=40, Link X=48

**Root cause**: `Mode1CursorSpriteTriplet` at z_02.asm:3783 has heart X=$28 (40). P23a already moved Links to X=$30 (48). Heart was never updated to match.

**Fix**: Change heart X from $28 → $30 in the transpiler patch (P28).

## Defect 2 — FS1: 2 of 3 Link sprites wrong color

**Probe D data** — Link sprites emit with tiles stepping per slot:
- spr4/5 (slot 0): tile $008 → CHR bank A (pixel indices 5,6,7)
- spr6/7 (slot 1): tile $208 → CHR bank B (pixel indices 9,A,B)
- spr8/9 (slot 2): tile $408 → CHR bank C (pixel indices D,E,F)

All 3 Link pairs emit with Genesis sprite palette 0. CRAM PAL0 is packed via CHR_EXPANSION as 4 sub-palettes of 4 colors each:
```
[0..3]: 0000 0EEE 0666 0E40    ; sub-pal 0: trans/white/grey/orange
[4..7]: 0000 02EA 048E 0028    ; sub-pal 1: trans/teal/brown/dark  <- slot 0 uses these
[8..B]: 0000 0E86 048E 0028    ; sub-pal 2: trans/pink-orange/brown/dark  <- slot 1
[C..F]: 0000 046E 048E 0028    ; sub-pal 3: trans/yellow-green/brown/dark  <- slot 2
```

**Root cause**: `Mode1_WriteLinkSprites` at z_02.asm:4015-4016 steps descriptor $04/$05 per slot (`addq.b #1`), giving NES sub-pal 0→1→2 → CHR expansion routes to different banks → 3 distinct colors.

On NES, all 4 sub-palettes were loaded with identical Link colors (green tunic), so stepping was invisible. On the Gen port via CHR_EXPANSION, each sub-pal routes to a different packed bank that does NOT share colors.

**Fix hypotheses** (need user to identify which Link looks "right"):
- **Hypothesis A** (slot 0 correct → teal): Force descriptor attr=0 throughout loop (disable stepping).
- **Hypothesis B** (slot 1 correct → pink-orange): Force attr=1.
- **Hypothesis C** (slot 2 correct → yellow-green): Force attr=2. *Likely user's "correct" since yellow-green is closest to Link's NES tunic.*

**❓ USER QUESTION**: Which Link (top/middle/bottom of file-select) looks "correct" to you?

## Defect 3 — FS2: 3 Link sprites misaligned

**Probe C data**: Link sprites at screen positions (80,49), (80,73), (80,97). Plane A rows 4-14 are ALL blank $124 — name slot backgrounds are NOT drawn anywhere.

REGISTER text heading at row 15 (Y=120). Keyboard at rows 16-22 (Y=128..176). No name slots visible in BG.

**Root cause (suspected)**: The BG layout for REGISTER screen never drew the 3 name slot frames. Links sit over blank BG. On NES, name slots were drawn as part of the REGISTER screen BG tilemap init; our Gen port's Mode E BG draw is incomplete.

Either the name-slot frames were never copied to Plane A, OR they're supposed to be on Plane B (not probed), OR they're supposed to be drawn into rows 0-3 (not probed).

**Fix hypothesis**: Need to probe Plane A rows 0-3 AND Plane B to find where/if name slot BG exists. Deferred to next probe.

**❓ USER QUESTION**: Do you see any name slot "frames" (boxes where letters will appear) on FS2? Or is it just floating Links on blank BG?

## Defect 4 — FS2 flashing keyboard cursor misaligned

**Probe C data**:
- sprite 2 (block cursor) at screen (48, 127)
- first letter row (Plane A row17 "A B C D E F G") at screen Y=136
- `$0085` = $87, observed cursor Y derivation: $87 - 8 (ModifyFlashingCursorY) = $7F = 127 screen

**Cursor is 9 px ABOVE letter row top**, not below.

**Contradiction with user report**: User says "1 tile too far DOWN". Probe says ABOVE.

Possible reasons:
1. User may be looking at a different reference (e.g. row above vs row on)
2. Real HW may render differently from BizHawk (unlikely for pure sprite Y)
3. User may be counting from letter bottom

**Fix hypothesis**: Inject `add.b #$08,D0` at WriteCursorCoords (cancels the -8 from ModifyFlashingCursorY). Result: cursor Y = $87 = 135 screen, approximately on letter row 136.

If wrong direction, flip to `sub.b #$10,D0`.

**❓ USER QUESTION**: The flashing block cursor — is it ABOVE the letter (touching top of "A") or BELOW the letter (touching bottom of "A")?

## Defect 5 — FS2 A-press doesn't add letters

**Probe B data**:
```
pre-A:   $00F8=$00 $0638=24 24 24 24 24 24 24 24
press A: $00F8=$40  (= NES B = backspace per P25b)
         $0638 unchanged
press Right: $041F 0→1
press A: $00F8=$40 → still backspace, no write
press B: $00F8=$80  (= NES A = write!)
         $041F=$01 $0421=0→1 $0305=$0B $0638[0]=$0B  <-- LETTER 'B' WRITTEN
press C: $00F8=$20  (= NES Select)
         $0421 1→8 (weird jump)
```

**Root cause #1**: `_ctrl_strobe` maps Genesis A → NES B, Genesis B → NES A (intentional for gameplay). P25b dispatches NES A ($80) = write, NES B ($40) = backspace. Net: **Genesis A = backspace, Genesis B = write**.

User presses Genesis A expecting "confirm" → gets backspace → no visible change. Natural fix: swap the dispatch so Genesis A = write in REGISTER mode.

**Root cause #2** (SEPARATE): Even though Genesis B successfully writes $0B to `$0638[0]`, the Plane A nametable never displays it (rows 4-14 still blank after 3 frames). This is a **display-flush bug** — `$0302-$0306` PPU write queue is populated but something in the NMI drain path isn't writing to Plane A.

**Fix 5a** (input side, 1-line): change P25b dispatch `cmpi.b #$80,D0` to `cmpi.b #$40,D0`. Swaps behavior so NES A = backspace, NES B = write. With Gen→NES mapping intact, Genesis A → NES B → write (matches user expectation).

**Fix 5b** (display side): Deferred — need to trace `_transfer_tilebuf_fast` / NMI VRAM drain path to find why queued writes at $0302-$0306 don't reach Plane A name-slot rows. This is blocking visual confirmation of typing.

## Defect 6 — SRAM persistence unverifiable

Blocked by Defect 5b (display flush). Once user can see typed letters, SRAM can be tested.

## Proposed Build 27.87

**Minimal risk**: ship Fix 5a (button swap in P25b) + Fix 1 (heart X $28→$30). Both are 1-line patches with clear probe-data rationale. User can then verify:
- Does Genesis A add letters to the visible name field?
- Is heart cursor X now horizontally aligned with Link X?

If Defect 5b (display flush) is real, user will still see no visible letters even after swap. That tells us 5b is the real blocker and 5a/button-swap alone was insufficient.
