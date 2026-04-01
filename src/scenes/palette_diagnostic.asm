; =============================================================================
; Palette Diagnostic Scene - Hardware regression test
; =============================================================================
; Renders gradient palette bars to verify VDP color output.
; Keep this scene intact as a baseline sanity check.
; =============================================================================

Scene_PaletteDiagnostic_Init:
    lea     PaletteDiagnosticCRAM(pc),A0
    move.w  #15,D7
    bsr     Renderer_LoadCRAM
    bsr     .LoadDiagnosticTiles
    bsr     .FillPlaneAWithGradient
    rts

.LoadDiagnosticTiles:
    move.l  #VRAM_WRITE_TILE1,(VDP_CTRL).l
    lea     PaletteDiagnosticTileWords(pc),A0
    move.w  #15,D7
.tile_loop:
    move.w  (A0)+,(VDP_DATA).l
    dbra    D7,.tile_loop
    rts

.FillPlaneAWithGradient:
    move.l  #VRAM_WRITE_PLANE_A,(VDP_CTRL).l
    move.w  #27,D7
.row_loop:
    move.w  #63,D6
.cell_loop:
    move.w  #1,(VDP_DATA).l
    dbra    D6,.cell_loop
    dbra    D7,.row_loop
    rts

PaletteDiagnosticCRAM:
    dc.w $0000
    dc.w $0EEE
    dc.w $000E
    dc.w $0E00
    dc.w $00E0
    dc.w $00EE
    dc.w $0E0E
    dc.w $0EE0
    dc.w $0888
    dc.w $0008
    dc.w $0800
    dc.w $0080
    dc.w $0088
    dc.w $0808
    dc.w $0880
    dc.w $0444

PaletteDiagnosticTileWords:
    dc.w $0000,$0000
    dc.w $1111,$1111
    dc.w $2222,$2222
    dc.w $3333,$3333
    dc.w $4444,$4444
    dc.w $5555,$5555
    dc.w $6666,$6666
    dc.w $7777,$7777
