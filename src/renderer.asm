; =============================================================================
; Renderer - Genesis VDP primitives
; =============================================================================
; Core VRAM/CRAM/tilemap operations. No game-specific rendering here.
; Game systems will call these primitives to draw their scenes.
;
; Phase 2 will extend this with:
;   - Sprite table manager (80-slot RAM table, DMA to VRAM)
;   - DMA-based VBlank transfer queue
;   - Room scrolling (column/row tilemap updates)
; =============================================================================

; --- VRAM clear ---

Renderer_ClearVRAM:
    move.l  #VRAM_WRITE_0000,(VDP_CTRL).l
    move.w  #$8F02,(VDP_CTRL).l
    moveq   #0,D0
    move.w  #32767,D7
.clear_loop:
    move.w  D0,(VDP_DATA).l
    dbra    D7,.clear_loop
    rts

; --- CRAM clear ---

Renderer_ClearCRAM:
    move.l  #CRAM_WRITE_0000,(VDP_CTRL).l
    moveq   #0,D0
    move.w  #63,D7
.clear_loop:
    move.w  D0,(VDP_DATA).l
    dbra    D7,.clear_loop
    rts

; --- Load CRAM palette from address in A0, count in D7 ---

Renderer_LoadCRAM:
    move.l  #CRAM_WRITE_0000,(VDP_CTRL).l
.cram_loop:
    move.w  (A0)+,(VDP_DATA).l
    dbra    D7,.cram_loop
    rts

; --- Clear Plane A tilemap ---

Renderer_ClearPlaneA:
    moveq   #0,D0
    move.w  #PLANE_A_VRAM,D0
    bsr     Renderer_SetVRAMWriteAddress
    move.w  #PLANE_MAP_ROWS-1,D7
.row_loop:
    move.w  #PLANE_MAP_COLS-1,D6
.cell_loop:
    move.w  #0,(VDP_DATA).l
    dbra    D6,.cell_loop
    dbra    D7,.row_loop
    rts

Renderer_ClearPlaneB:
    moveq   #0,D0
    move.w  #PLANE_B_VRAM,D0
    bsr     Renderer_SetVRAMWriteAddress
    move.w  #PLANE_MAP_ROWS-1,D7
.row_loop:
    move.w  #PLANE_MAP_COLS-1,D6
.cell_loop:
    move.w  #0,(VDP_DATA).l
    dbra    D6,.cell_loop
    dbra    D7,.row_loop
    rts

Renderer_ResetScroll:
    clr.w   (PLANE_A_HSCROLL).l
    clr.w   (PLANE_B_HSCROLL).l
    clr.w   (PLANE_A_VSCROLL).l
    clr.w   (PLANE_B_VSCROLL).l
    rts

Renderer_SetPlaneAHScroll:
    move.w  D0,(PLANE_A_HSCROLL).l
    rts

Renderer_SetPlaneBHScroll:
    move.w  D0,(PLANE_B_HSCROLL).l
    rts

Renderer_SetPlaneAVScroll:
    move.w  D0,(PLANE_A_VSCROLL).l
    rts

Renderer_SetPlaneBVScroll:
    move.w  D0,(PLANE_B_VSCROLL).l
    rts

Renderer_SubmitScrollState:
    lea     (PLANE_A_HSCROLL).l,A0
    moveq   #0,D0
    move.w  #HSCROLL_TABLE_VRAM,D0
    move.w  #1,D7
    bsr     Renderer_QueueVRAMWords
    lea     (PLANE_A_VSCROLL).l,A0
    move.w  #1,D7
    bsr     Renderer_QueueVSRAMWords
    rts

; --- Set VRAM write address (D0 = VRAM byte address) ---

Renderer_SetVRAMWriteAddress:
    bsr     Renderer_BuildVRAMWriteCommand
    move.l  D1,(VDP_CTRL).l
    rts

Renderer_BuildVRAMWriteCommand:
    move.l  D0,D1
    andi.l  #$00003FFF,D1
    swap    D1
    move.l  D0,D2
    andi.l  #$0000C000,D2
    lsr.l   #8,D2
    lsr.l   #6,D2
    or.l    D2,D1
    ori.l   #$40000000,D1
    rts

; --- Build tilemap write command: D0 = row, D1 = col, D2 = plane base ---

Renderer_BuildTilemapWriteCommand:
    move.w  D0,D3
    mulu.w  #PLANE_TILEMAP_STRIDE,D3
    move.w  D1,D4
    add.w   D4,D4
    add.w   D4,D3
    add.w   D2,D3
    moveq   #0,D0
    move.w  D3,D0
    bsr     Renderer_BuildVRAMWriteCommand
    rts

; --- Draw single tile at row D0, col D1, tile word D2 ---

Renderer_DrawTileAt:
    move.w  D0,D3
    mulu.w  #PLANE_TILEMAP_STRIDE,D3
    add.w   D1,D1
    add.w   D1,D3
    addi.w  #PLANE_A_VRAM,D3
    moveq   #0,D0
    move.w  D3,D0
    bsr     Renderer_SetVRAMWriteAddress
    move.w  D2,(VDP_DATA).l
    rts

Renderer_DrawTileAtPlaneB:
    move.w  D0,D3
    mulu.w  #PLANE_TILEMAP_STRIDE,D3
    add.w   D1,D1
    add.w   D1,D3
    addi.w  #PLANE_B_VRAM,D3
    moveq   #0,D0
    move.w  D3,D0
    bsr     Renderer_SetVRAMWriteAddress
    move.w  D2,(VDP_DATA).l
    rts

; --- Draw 2x2 metatile at row D0, col D1, base tile D2 ---
; Tiles: D2=TL, D2+1=TR, D2+2=BL, D2+3=BR

Renderer_DrawMetaTile2x2:
    move.w  D0,D4
    move.w  D1,D5
    move.w  D2,D6

    bsr     Renderer_DrawTileAt

    move.w  D4,D0
    move.w  D5,D1
    addq.w  #1,D1
    move.w  D6,D2
    addq.w  #1,D2
    bsr     Renderer_DrawTileAt

    move.w  D4,D0
    addq.w  #1,D0
    move.w  D5,D1
    move.w  D6,D2
    addq.w  #2,D2
    bsr     Renderer_DrawTileAt

    move.w  D4,D0
    addq.w  #1,D0
    move.w  D5,D1
    addq.w  #1,D1
    move.w  D6,D2
    addq.w  #3,D2
    bsr     Renderer_DrawTileAt
    rts

; --- Draw tile row: row D0, start col D1, count D2, tile word D3 ---

Renderer_DrawTileRow:
    move.w  D0,D5
    mulu.w  #PLANE_TILEMAP_STRIDE,D5
    add.w   D1,D1
    add.w   D1,D5
    addi.w  #PLANE_A_VRAM,D5
    moveq   #0,D0
    move.w  D5,D0
    bsr     Renderer_SetVRAMWriteAddress
    subq.w  #1,D2
.row_loop:
    move.w  D3,(VDP_DATA).l
    dbra    D2,.row_loop
    rts

Renderer_DrawTileRowPlaneB:
    move.w  D0,D5
    mulu.w  #PLANE_TILEMAP_STRIDE,D5
    add.w   D1,D1
    add.w   D1,D5
    addi.w  #PLANE_B_VRAM,D5
    moveq   #0,D0
    move.w  D5,D0
    bsr     Renderer_SetVRAMWriteAddress
    subq.w  #1,D2
.row_loop:
    move.w  D3,(VDP_DATA).l
    dbra    D2,.row_loop
    rts

; --- Draw tile column: row D0, col D1, count D2, tile word D3 ---

Renderer_DrawTileColumn:
    move.w  D2,D4
    move.w  D0,D5
    move.w  D1,D6
    move.w  D3,D7
    subq.w  #1,D4
.column_loop:
    move.w  D5,D0
    move.w  D6,D1
    move.w  D7,D2
    bsr     Renderer_DrawTileAt
    addq.w  #1,D5
    dbra    D4,.column_loop
    rts

; --- Fill rectangle: row D0, col D1, width D2, height D3, tile word D4 ---

Renderer_FillRect:
    move.w  D3,D5
    subq.w  #1,D5
.fill_loop:
    move.w  D5,-(A7)
    movem.l D0-D4,-(A7)
    move.w  D4,D3
    bsr     Renderer_DrawTileRow
    movem.l (A7)+,D0-D4
    move.w  (A7)+,D5
    addq.w  #1,D0
    dbra    D5,.fill_loop
    rts

Renderer_FillRectPlaneB:
    move.w  D3,D5
    subq.w  #1,D5
.fill_loop:
    move.w  D5,-(A7)
    movem.l D0-D4,-(A7)
    move.w  D4,D3
    bsr     Renderer_DrawTileRowPlaneB
    movem.l (A7)+,D0-D4
    move.w  (A7)+,D5
    addq.w  #1,D0
    dbra    D5,.fill_loop
    rts

; --- Upload tile data to VRAM: A0 = source, D7 = word count - 1 ---

Renderer_UploadTiles:
    move.l  #VRAM_WRITE_TILE1,(VDP_CTRL).l
.tile_loop:
    move.w  (A0)+,(VDP_DATA).l
    dbra    D7,.tile_loop
    rts

; --- Upload tile data to arbitrary VRAM byte address: D0 = VRAM address ---

Renderer_UploadWordsToVRAM:
    bsr     Renderer_SetVRAMWriteAddress
.word_loop:
    move.w  (A0)+,(VDP_DATA).l
    dbra    D7,.word_loop
    rts

; --- Queued VDP writes ---

; Fixed-size queue entry format:
;   +0  word type
;   +2  word flags
;   +4  word row / command high word
;   +6  word col / command low word
;   +8  word count - 1
;   +10 word repeat tile / reserved
;   +12 long source pointer

; D4 = entry type, D5 = flags, D0 = row/cmd hi, D1 = col/cmd lo
; D2 = count - 1, D3 = repeat value/reserved, A0 = source pointer
Renderer_QueueTransferEntry:
    move.w  (TRANSFER_QUEUE_COUNT).l,D6
    cmpi.w  #TRANSFER_QUEUE_MAX,D6
    bcc.s   .full

    mulu.w  #TRANSFER_ENTRY_BYTES,D6
    lea     (TRANSFER_QUEUE_BUFFER).l,A1
    adda.w  D6,A1
    move.w  D4,(A1)+
    move.w  D5,(A1)+
    move.w  D0,(A1)+
    move.w  D1,(A1)+
    move.w  D2,(A1)+
    move.w  D3,(A1)+
    move.l  A0,(A1)+
    cmpi.w  #TRANSFER_TYPE_PLANE_A_ROW,D4
    bcs.s   .counted
    addq.l  #1,(TRANSFER_TILEMAP_ACTIVITY_COUNT).l
.counted:
    addq.w  #1,(TRANSFER_QUEUE_COUNT).l
    rts
.full:
    addq.w  #1,(TRANSFER_QUEUE_OVERFLOW_COUNT).l
    rts

; D4 = upload type, D1 = full VDP control command, A0 = source, D7 = word count - 1
Renderer_QueueVDPWriteWords:
    move.w  D7,D2
    moveq   #0,D5
    moveq   #0,D3
    move.l  D1,D6
    swap    D6
    move.w  D6,D0
    swap    D6
    move.w  D6,D1
    bra     Renderer_QueueTransferEntry

; D0 = VRAM byte address, A0 = source, D7 = word count - 1
Renderer_QueueVRAMWords:
    bsr     Renderer_BuildVRAMWriteCommand
    moveq   #TRANSFER_TYPE_VRAM_UPLOAD,D4
    bra.s   Renderer_QueueVDPWriteWords

; A0 = source, D7 = word count - 1
Renderer_QueueCRAMWords:
    move.l  #CRAM_WRITE_0000,D1
    moveq   #TRANSFER_TYPE_CRAM_UPLOAD,D4
    bra.s   Renderer_QueueVDPWriteWords

; A0 = source, D7 = word count - 1
Renderer_QueueVSRAMWords:
    move.l  #VSRAM_WRITE_0000,D1
    moveq   #TRANSFER_TYPE_VSRAM_UPLOAD,D4
    bra.s   Renderer_QueueVDPWriteWords

; D4 = entry type, D0 = row, D1 = col, D2 = count, A0 = source
Renderer_QueueTileSpan:
    tst.w   D2
    beq.s   .done
    subq.w  #1,D2
    moveq   #0,D5
    moveq   #0,D3
    bra     Renderer_QueueTransferEntry
.done:
    rts

; D4 = entry type, D0 = row, D1 = col, D2 = count, D3 = repeated tile word
Renderer_QueueTileSpanFill:
    tst.w   D2
    beq.s   .done
    subq.w  #1,D2
    moveq   #TRANSFER_FLAG_REPEAT_VALUE,D5
    suba.l  A0,A0
    bra     Renderer_QueueTransferEntry
.done:
    rts

Renderer_QueueTileRowPlaneA:
    moveq   #TRANSFER_TYPE_PLANE_A_ROW,D4
    bra.s   Renderer_QueueTileSpan

Renderer_QueueTileRowPlaneB:
    moveq   #TRANSFER_TYPE_PLANE_B_ROW,D4
    bra.s   Renderer_QueueTileSpan

Renderer_QueueTileColumnPlaneA:
    moveq   #TRANSFER_TYPE_PLANE_A_COLUMN,D4
    bra.s   Renderer_QueueTileSpan

Renderer_QueueTileColumnPlaneB:
    moveq   #TRANSFER_TYPE_PLANE_B_COLUMN,D4
    bra.s   Renderer_QueueTileSpan

Renderer_QueueTileFillRowPlaneA:
    moveq   #TRANSFER_TYPE_PLANE_A_ROW,D4
    bra.s   Renderer_QueueTileSpanFill

Renderer_QueueTileFillRowPlaneB:
    moveq   #TRANSFER_TYPE_PLANE_B_ROW,D4
    bra.s   Renderer_QueueTileSpanFill

; D0 = row, D1 = col, D2 = width, D3 = height, D4 = repeated tile word
Renderer_QueueFillRectPlaneA:
    move.w  D3,D6
    subq.w  #1,D6
.fill_loop:
    move.w  D6,-(A7)
    movem.l D0-D4,-(A7)
    move.w  D4,D3
    bsr     Renderer_QueueTileFillRowPlaneA
    movem.l (A7)+,D0-D4
    move.w  (A7)+,D6
    addq.w  #1,D0
    dbra    D6,.fill_loop
    rts

Renderer_QueueFillRectPlaneB:
    move.w  D3,D6
    subq.w  #1,D6
.fill_loop:
    move.w  D6,-(A7)
    movem.l D0-D4,-(A7)
    move.w  D4,D3
    bsr     Renderer_QueueTileFillRowPlaneB
    movem.l (A7)+,D0-D4
    move.w  (A7)+,D6
    addq.w  #1,D0
    dbra    D6,.fill_loop
    rts

; D0/D1 = packed VDP command words, D2 = word count - 1, A0 = source
Renderer_ExecuteQueuedUpload:
    move.l  A0,D6
    cmpi.l  #$00FF0000,D6
    bcs.s   .cpu_upload

    move.w  D2,D7
    addq.w  #1,D7

    move.w  #$9300,D4
    move.b  D7,D4
    move.w  D4,(VDP_CTRL).l
    lsr.w   #8,D7
    move.w  #$9400,D4
    move.b  D7,D4
    move.w  D4,(VDP_CTRL).l

    move.l  A0,D7
    lsr.l   #1,D7
    andi.l  #$007FFFFF,D7
    move.w  #$9500,D4
    move.b  D7,D4
    move.w  D4,(VDP_CTRL).l
    lsr.l   #8,D7
    move.w  #$9600,D4
    move.b  D7,D4
    move.w  D4,(VDP_CTRL).l
    lsr.l   #8,D7
    move.w  #$9700,D4
    move.b  D7,D4
    move.w  D4,(VDP_CTRL).l

    moveq   #0,D7
    move.w  D0,D7
    swap    D7
    move.w  D1,D7
    ori.l   #$00000080,D7
    move.l  D7,(VDP_CTRL).l
    rts

.cpu_upload:
    moveq   #0,D7
    move.w  D0,D7
    swap    D7
    move.w  D1,D7
    move.l  D7,(VDP_CTRL).l
    move.w  D2,D7
.word_loop:
    move.w  (A0)+,(VDP_DATA).l
    dbra    D7,.word_loop
    rts

Renderer_ProcessTransferQueue:
    addq.l  #1,(TRANSFER_QUEUE_PROCESS_CALL_COUNT).l
    move.w  (TRANSFER_QUEUE_COUNT).l,D6
    move.w  D6,(TRANSFER_QUEUE_LAST_COUNT).l
    beq     .done
    moveq   #0,D7
    move.w  D6,D7
    add.l   D7,(TRANSFER_QUEUE_PROCESSED_COUNT).l
    subq.w  #1,D6
    lea     (TRANSFER_QUEUE_BUFFER).l,A1
.entry_loop:
    move.w  D6,-(A7)
    move.w  (A1)+,D4
    move.w  (A1)+,D5
    move.w  (A1)+,D0
    move.w  (A1)+,D1
    move.w  (A1)+,D2
    move.w  (A1)+,D3
    movea.l (A1)+,A0
    cmpi.w  #TRANSFER_TYPE_CRAM_UPLOAD,D4
    bls     .upload
    cmpi.w  #TRANSFER_TYPE_VSRAM_UPLOAD,D4
    beq     .upload
    cmpi.w  #TRANSFER_TYPE_PLANE_A_ROW,D4
    beq     .plane_a_row
    cmpi.w  #TRANSFER_TYPE_PLANE_B_ROW,D4
    beq     .plane_b_row
    cmpi.w  #TRANSFER_TYPE_PLANE_A_COLUMN,D4
    beq     .plane_a_column
    bra     .plane_b_column

.upload:
    bsr     Renderer_ExecuteQueuedUpload
    bra     .next_entry

.plane_a_row:
    move.w  #PLANE_A_VRAM,D4
    bra     .process_row

.plane_b_row:
    move.w  #PLANE_B_VRAM,D4

.process_row:
    move.w  D2,D7
    move.w  D4,D2
    bsr     Renderer_BuildTilemapWriteCommand
    move.l  D1,(VDP_CTRL).l
    btst    #0,D5
    bne     .row_repeat
.row_source:
    move.w  (A0)+,(VDP_DATA).l
    dbra    D7,.row_source
    bra     .next_entry
.row_repeat:
    move.w  D3,(VDP_DATA).l
    dbra    D7,.row_repeat
    bra     .next_entry

.plane_a_column:
    move.w  #PLANE_A_VRAM,D4
    bra     .process_column

.plane_b_column:
    move.w  #PLANE_B_VRAM,D4

.process_column:
    move.w  D2,D7
    move.w  #$8F80,(VDP_CTRL).l
    move.w  D4,D2
    bsr     Renderer_BuildTilemapWriteCommand
    move.l  D1,(VDP_CTRL).l
    btst    #0,D5
    bne     .column_repeat
.column_source:
    move.w  (A0)+,(VDP_DATA).l
    dbra    D7,.column_source
    bra     .restore_increment
.column_repeat:
    move.w  D3,(VDP_DATA).l
    dbra    D7,.column_repeat
.restore_increment:
    move.w  #$8F02,(VDP_CTRL).l

.next_entry:
    move.w  (A7)+,D6
    dbra    D6,.entry_loop
    clr.w   (TRANSFER_QUEUE_COUNT).l
.done:
    rts

; --- Sprite shadow table helpers ---

Renderer_ResetSpriteAllocators:
    move.w  #SPRITE_SLOT_ENEMY_START,(SPRITE_NEXT_ENEMY_SLOT).l
    move.w  #SPRITE_SLOT_ITEM_START,(SPRITE_NEXT_ITEM_SLOT).l
    move.w  #SPRITE_SLOT_PROJECTILE_START,(SPRITE_NEXT_PROJECTILE_SLOT).l
    rts

Renderer_ClearSpriteTable:
    lea     (SPRITE_TABLE_BUFFER).l,A0
    moveq   #0,D0
    move.w  #(SPRITE_MAX*SPRITE_ENTRY_WORDS)-1,D7
.clear_loop:
    move.w  D0,(A0)+
    dbra    D7,.clear_loop
    clr.w   (SPRITE_COUNT).l
    bsr     Renderer_ResetSpriteAllocators
    rts

; D0 = requested slot count, returns D0 = base slot or -1 on failure
Renderer_ReserveSpriteSlots:
    move.w  (SPRITE_COUNT).l,D4
    move.w  D4,D1
    add.w   D0,D4
    cmpi.w  #SPRITE_MAX,D4
    bhi.s   .full
    move.w  D4,(SPRITE_COUNT).l
    move.w  D1,D0
    rts
.full:
    moveq   #-1,D0
    rts

; A0 = cursor address, D0 = requested slot count, D4 = exclusive range end
Renderer_ReserveSpriteSlotsFromCursor:
    move.w  (A0),D1
    move.w  D1,D2
    add.w   D0,D2
    cmp.w   D4,D2
    bhi.s   .full
    move.w  D2,(A0)
    move.w  D1,D0
    rts
.full:
    moveq   #-1,D0
    rts

; D0 = requested slot count, returns D0 = base slot or -1 on failure
Renderer_ReserveEnemySpriteSlots:
    lea     (SPRITE_NEXT_ENEMY_SLOT).l,A0
    move.w  #SPRITE_SLOT_ENEMY_END,D4
    bra.s   Renderer_ReserveSpriteSlotsFromCursor

Renderer_ReserveItemSpriteSlots:
    lea     (SPRITE_NEXT_ITEM_SLOT).l,A0
    move.w  #SPRITE_SLOT_ITEM_END,D4
    bra.s   Renderer_ReserveSpriteSlotsFromCursor

Renderer_ReserveProjectileSpriteSlots:
    lea     (SPRITE_NEXT_PROJECTILE_SLOT).l,A0
    move.w  #SPRITE_SLOT_PROJECTILE_END,D4
    bra.s   Renderer_ReserveSpriteSlotsFromCursor

; D4 = slot, D0 = X, D1 = Y, D2 = tile index, D3 = attribute bits
Renderer_AddSprite1x1AtSlot:
    cmpi.w  #SPRITE_MAX,D4
    bcc.s   .full

    move.w  D4,D5
    mulu.w  #SPRITE_ENTRY_BYTES,D5
    lea     (SPRITE_TABLE_BUFFER).l,A0
    adda.w  D5,A0

    move.w  D1,D5
    addi.w  #SPRITE_Y_BIAS,D5
    move.w  D5,(A0)+

    move.w  D4,D5
    addq.w  #1,D5
    andi.w  #$00FF,D5
    move.w  D5,(A0)+

    move.w  D3,D5
    or.w    D2,D5
    move.w  D5,(A0)+

    move.w  D0,D5
    addi.w  #SPRITE_X_BIAS,D5
    move.w  D5,(A0)+

    move.w  D4,D5
    addq.w  #1,D5
    cmp.w   (SPRITE_COUNT).l,D5
    bls.s   .full
    move.w  D5,(SPRITE_COUNT).l
.full:
    rts

; D0 = X, D1 = Y, D2 = tile index, D3 = attribute bits (palette/priority/flip)
Renderer_AddSprite1x1:
    movem.w D0-D3,-(A7)
    moveq   #1,D0
    bsr     Renderer_ReserveSpriteSlots
    cmpi.w  #-1,D0
    beq.s   .restore
    move.w  D0,D4
    movem.w (A7)+,D0-D3
    bra     Renderer_AddSprite1x1AtSlot
.restore:
    movem.w (A7)+,D0-D3
    rts

; D4 = base slot, D0 = X, D1 = Y, D2 = base tile index, D3 = attribute bits
Renderer_AddMetaSprite2x2AtSlot:
    movem.w D0-D3,-(A7)
    bsr     Renderer_AddSprite1x1AtSlot

    movem.w (A7)+,D0-D3
    addi.w  #8,D0
    addq.w  #1,D2
    addq.w  #1,D4
    bsr     Renderer_AddSprite1x1AtSlot

    movem.w (A7)+,D0-D3
    addi.w  #8,D1
    addq.w  #2,D2
    addq.w  #1,D4
    bsr     Renderer_AddSprite1x1AtSlot

    movem.w (A7)+,D0-D3
    addi.w  #8,D0
    addi.w  #8,D1
    addq.w  #3,D2
    addq.w  #1,D4
    bsr     Renderer_AddSprite1x1AtSlot

    movem.w (A7)+,D0-D3
    rts

; D0 = X, D1 = Y, D2 = base tile index, D3 = attribute bits
Renderer_AddMetaSprite2x2:
    movem.w D0-D3,-(A7)
    moveq   #4,D0
    bsr     Renderer_ReserveSpriteSlots
    cmpi.w  #-1,D0
    beq.s   .restore
    move.w  D0,D4
    movem.w (A7)+,D0-D3
    bra     Renderer_AddMetaSprite2x2AtSlot
.restore:
    movem.w (A7)+,D0-D3
    rts

; D0 = X, D1 = Y, D2 = base tile index, D3 = attribute bits
Renderer_AddLinkMetaSprite2x2:
    moveq   #SPRITE_SLOT_LINK_START,D4
    movem.w D0-D3,-(A7)
    bsr     Renderer_AddSprite1x1AtSlot

    movem.w (A7),D0-D3
    addi.w  #8,D0
    addq.w  #2,D2
    addq.w  #1,D4
    bsr     Renderer_AddSprite1x1AtSlot

    movem.w (A7),D0-D3
    addi.w  #8,D1
    addq.w  #1,D2
    addq.w  #1,D4
    bsr     Renderer_AddSprite1x1AtSlot

    movem.w (A7)+,D0-D3
    addi.w  #8,D0
    addi.w  #8,D1
    addq.w  #3,D2
    addq.w  #1,D4
    bsr     Renderer_AddSprite1x1AtSlot
    rts

Renderer_AddEnemyMetaSprite2x2:
    movem.w D0-D3,-(A7)
    moveq   #4,D0
    bsr     Renderer_ReserveEnemySpriteSlots
    cmpi.w  #-1,D0
    beq.s   .restore
    move.w  D0,D4
    movem.w (A7)+,D0-D3
    bra     Renderer_AddMetaSprite2x2AtSlot
.restore:
    movem.w (A7)+,D0-D3
    rts

Renderer_AddItemSprite1x1:
    movem.w D0-D3,-(A7)
    moveq   #1,D0
    bsr     Renderer_ReserveItemSpriteSlots
    cmpi.w  #-1,D0
    beq.s   .restore
    move.w  D0,D4
    movem.w (A7)+,D0-D3
    bra     Renderer_AddSprite1x1AtSlot
.restore:
    movem.w (A7)+,D0-D3
    rts

Renderer_AddProjectileSprite1x1:
    movem.w D0-D3,-(A7)
    moveq   #1,D0
    bsr     Renderer_ReserveProjectileSpriteSlots
    cmpi.w  #-1,D0
    beq.s   .restore
    move.w  D0,D4
    movem.w (A7)+,D0-D3
    bra     Renderer_AddSprite1x1AtSlot
.restore:
    movem.w (A7)+,D0-D3
    rts

Renderer_FinalizeSpriteTable:
    tst.w   (SPRITE_COUNT).l
    beq.s   .done

    move.w  (SPRITE_COUNT).l,D0
    subq.w  #1,D0
    mulu.w  #SPRITE_ENTRY_BYTES,D0
    lea     (SPRITE_TABLE_BUFFER).l,A0
    adda.w  D0,A0
    andi.w  #$FF00,2(A0)
.done:
    rts

Renderer_SubmitSpriteTable:
    bsr     Renderer_FinalizeSpriteTable
    lea     (SPRITE_TABLE_BUFFER).l,A0
    moveq   #0,D0
    move.w  #SPRITE_TABLE_VRAM,D0
    move.w  #(SPRITE_MAX*SPRITE_ENTRY_WORDS)-1,D7
    bsr     Renderer_QueueVRAMWords
    rts

; --- Main loop hooks ---

Renderer_BeginScene:
    bsr     Renderer_ClearSpriteTable
    rts

Renderer_Submit:
    bsr     Renderer_SubmitScrollState
    move.w  (SPRITE_COUNT).l,(SPRITE_LAST_COUNT).l
    lea     (SPRITE_TABLE_BUFFER).l,A0
    lea     (SPRITE_LAST_TABLE_BUFFER).l,A1
    move.w  #15,D7
.snapshot_loop:
    move.w  (A0)+,(A1)+
    dbra    D7,.snapshot_loop
    bsr     Renderer_SubmitSpriteTable
    move.w  (TRANSFER_QUEUE_COUNT).l,(TRANSFER_QUEUE_SUBMIT_COUNT).l
    rts
