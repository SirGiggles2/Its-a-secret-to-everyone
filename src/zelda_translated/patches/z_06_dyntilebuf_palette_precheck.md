# Patch: DynTileBuf Palette Pre-Check (z_06.asm)

## Build
Zelda27.11

## Location
`src/zelda_translated/z_06.asm`, TransferCurTileBuf (line 814)

## Bug
Bug C: DynTileBuf/TileBufSelector timing contention. On NES, the palette
transfer record placed in DynTileBuf by InitDemoSubphaseTransferTitlePalette
(z_02.asm) is consumed by the next NMI before TileBufSelector changes. On
Genesis, a timing difference causes TileBufSelector to be overwritten to 16
(GameTitleTransferBuf) before the NMI fires, so the palette record in
DynTileBuf (index 0) is never dispatched. Result: CRAM stays at init values
instead of receiving the correct title screen palette.

## Fix
Added a pre-check at the top of TransferCurTileBuf that inspects DynTileBuf[0].
If the first byte is $3F (PPU palette address high byte), the palette record is
processed immediately via `bsr _transfer_tilebuf_fast` before the normal
TileBufSelector dispatch. After processing, the sentinel is reset to $FF.

Registers are saved/restored around the BSR to protect caller state. If
TileBufSelector was 0 (meaning DynTileBuf was the selected buffer), the main
dispatch is skipped to avoid redundant processing.

## Adversarial Review
- Finding 1 (register clobber): addressed with movem.l save/restore
- Finding 3 (double dispatch): addressed with tst.b/beq.s skip
- Finding 5 ($3F false positive): rejected — DynTileBuf[0] is always $FF after
  processing, only $3F when actively loaded by palette init code
