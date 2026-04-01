PLANE_A_VRAM         equ $8000
PLANE_B_VRAM         equ $A000
SPRITE_TABLE_VRAM    equ $7E00
HSCROLL_TABLE_VRAM   equ $7000
TILE1_VRAM           equ $0020

PLANE_TILEMAP_STRIDE equ 128
PLANE_MAP_COLS       equ 64
PLANE_MAP_ROWS       equ 32
VISIBLE_COLS         equ 32
VISIBLE_ROWS         equ 28
HUD_TOP_ROW          equ 2
HUD_ROWS             equ 4
PLAYFIELD_TOP_ROW    equ HUD_TOP_ROW+HUD_ROWS
SPRITE_MAX           equ 80
SPRITE_ENTRY_WORDS   equ 4
SPRITE_ENTRY_BYTES   equ 8
SPRITE_X_BIAS        equ 128
SPRITE_Y_BIAS        equ 128
SPRITE_SLOT_LINK_START equ 0
SPRITE_SLOT_LINK_COUNT equ 4
SPRITE_SLOT_ENEMY_START equ 4
SPRITE_SLOT_ENEMY_COUNT equ 48
SPRITE_SLOT_ITEM_START equ 52
SPRITE_SLOT_ITEM_COUNT equ 12
SPRITE_SLOT_PROJECTILE_START equ 64
SPRITE_SLOT_PROJECTILE_COUNT equ 16
SPRITE_SLOT_LINK_END equ SPRITE_SLOT_LINK_START+SPRITE_SLOT_LINK_COUNT
SPRITE_SLOT_ENEMY_END equ SPRITE_SLOT_ENEMY_START+SPRITE_SLOT_ENEMY_COUNT
SPRITE_SLOT_ITEM_END equ SPRITE_SLOT_ITEM_START+SPRITE_SLOT_ITEM_COUNT
SPRITE_SLOT_PROJECTILE_END equ SPRITE_SLOT_PROJECTILE_START+SPRITE_SLOT_PROJECTILE_COUNT
TRANSFER_QUEUE_MAX   equ 32
TRANSFER_ENTRY_BYTES equ 16
TRANSFER_TYPE_VRAM_UPLOAD equ 0
TRANSFER_TYPE_CRAM_UPLOAD equ 1
TRANSFER_TYPE_VSRAM_UPLOAD equ 6
TRANSFER_TYPE_PLANE_A_ROW equ 2
TRANSFER_TYPE_PLANE_B_ROW equ 3
TRANSFER_TYPE_PLANE_A_COLUMN equ 4
TRANSFER_TYPE_PLANE_B_COLUMN equ 5
TRANSFER_FLAG_REPEAT_VALUE equ 1

PAD1_DATA            equ $00A10003
PAD1_CTRL            equ $00A10009
PAD2_CTRL            equ $00A1000B

VRAM_WRITE_0000      equ $40000000
VRAM_WRITE_TILE1     equ $40200000
VRAM_WRITE_PLANE_A   equ $40000002
CRAM_WRITE_0000      equ $C0000000
VSRAM_WRITE_0000     equ $40000010

RAM_CLEAR_BYTES      equ $1000

Platform_Init:
    move.b  (VERSION_PORT).l,D0
    andi.b  #$0F,D0
    beq.s   .skip_tmss
    move.l  #$53454741,(TMSS_PORT).l
.skip_tmss:
    move.w  #$0100,(Z80_BUSREQ).l
    move.w  #$0100,(Z80_RESET).l

    lea     (RAM_START).l,A0
    moveq   #0,D0
    move.w  #(RAM_CLEAR_BYTES/4)-1,D7
.clear_ram:
    move.l  D0,(A0)+
    dbra    D7,.clear_ram

    bsr     JOYPAD_INIT
    bsr     Platform_InitVDP
    rts

Platform_InitVDP:
    move.w  #$8004,(VDP_CTRL).l
    move.w  #$8134,(VDP_CTRL).l
    move.w  #$8220,(VDP_CTRL).l
    move.w  #$833C,(VDP_CTRL).l
    move.w  #$8405,(VDP_CTRL).l
    move.w  #$853F,(VDP_CTRL).l
    move.w  #$8600,(VDP_CTRL).l
    move.w  #$8700,(VDP_CTRL).l
    move.w  #$8800,(VDP_CTRL).l
    move.w  #$8900,(VDP_CTRL).l
    move.w  #$8AFF,(VDP_CTRL).l
    move.w  #$8B00,(VDP_CTRL).l
    move.w  #$8C00,(VDP_CTRL).l
    move.w  #$8D1C,(VDP_CTRL).l
    move.w  #$8E00,(VDP_CTRL).l
    move.w  #$8F02,(VDP_CTRL).l
    move.w  #$9001,(VDP_CTRL).l
    ; Keep the VDP window plane disabled by leaving its origin at the
    ; upper-left in the "left/up side" mode, which yields a zero-sized window.
    move.w  #$9100,(VDP_CTRL).l
    move.w  #$9200,(VDP_CTRL).l

    move.l  #VSRAM_WRITE_0000,(VDP_CTRL).l
    move.w  #$0000,(VDP_DATA).l
    move.w  #$0000,(VDP_DATA).l

    bsr     Renderer_ClearCRAM
    rts

Platform_EnableDisplay:
    move.w  #$8174,(VDP_CTRL).l
    move.w  #$2000,SR
    rts

Platform_BeginFrame:
    rts

Platform_EndFrame:
.wait_vblank:
    tst.b   (VBLANK_PENDING).l
    bne.s   .consume
    stop    #$2000
    bra.s   .wait_vblank
.consume:
    bsr     Renderer_ProcessTransferQueue
    clr.b   (VBLANK_PENDING).l
    rts

Input_Poll:
    bsr     READ_JOYPAD
    move.b  (INPUT_HELD).l,(INPUT_PREVIOUS).l
    move.b  (INPUT_HELD).l,D1
    move.b  D0,D2
    not.b   D1
    and.b   D1,D2
    move.b  D0,(INPUT_HELD).l
    move.b  D2,(INPUT_PRESSED).l
    rts

JOYPAD_INIT:
    move.b  #$40,(PAD1_CTRL).l
    move.b  #$40,(PAD2_CTRL).l
    rts

READ_JOYPAD:
    move.b  #$40,(PAD1_DATA).l
    nop
    nop
    move.b  (PAD1_DATA).l,D1

    move.b  #$00,(PAD1_DATA).l
    nop
    nop
    move.b  (PAD1_DATA).l,D2

    clr.b   D0

    move.b  D1,D3
    andi.b  #$0F,D3
    eori.b  #$0F,D3

    btst    #0,D3
    beq.s   .no_up
    bset    #PAD_UP,D0
.no_up:
    btst    #1,D3
    beq.s   .no_down
    bset    #PAD_DOWN,D0
.no_down:
    btst    #2,D3
    beq.s   .no_left
    bset    #PAD_LEFT,D0
.no_left:
    btst    #3,D3
    beq.s   .no_right
    bset    #PAD_RIGHT,D0
.no_right:

    btst    #5,D2
    bne.s   .no_start
    bset    #PAD_START,D0
.no_start:
    btst    #4,D2
    bne.s   .no_a
    bset    #PAD_A,D0
.no_a:
    btst    #4,D1
    bne.s   .no_b
    bset    #PAD_B,D0
.no_b:
    btst    #5,D1
    bne.s   .done
    bset    #PAD_SELECT,D0
.done:
    rts
