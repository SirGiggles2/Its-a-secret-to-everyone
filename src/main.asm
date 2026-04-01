; =============================================================================
; WHAT IF - The Legend of Zelda for Sega Genesis
; =============================================================================
; Exact port of The Legend of Zelda (NES, 1986) to Genesis / Mega Drive.
; Native 68000 assembly. Real hardware target.
; =============================================================================

STACK_TOP       equ $00FFFFFE
RAM_START       equ $00FF0000
RAM_END         equ $00FFFFFF
ROM_SIZE        equ $00010000

VDP_DATA        equ $00C00000
VDP_CTRL        equ $00C00004
VERSION_PORT    equ $00A10001
TMSS_PORT       equ $00A14000
Z80_BUSREQ      equ $00A11100
Z80_RESET       equ $00A11200

; --- RAM layout (minimal shell — will grow as systems come online) ---
FRAME_COUNTER   equ $00FF0000
VBLANK_PENDING  equ $00FF0004
INPUT_HELD      equ $00FF0008
INPUT_PRESSED   equ $00FF0009
INPUT_PREVIOUS  equ $00FF000A
SPRITE_COUNT    equ $00FF000C
TRANSFER_QUEUE_COUNT equ $00FF000E
TRANSFER_QUEUE_OVERFLOW_COUNT equ $00FF0010
TRANSFER_QUEUE_LAST_COUNT equ $00FF0012
TRANSFER_TILEMAP_ACTIVITY_COUNT equ $00FF0014
TRANSFER_QUEUE_SUBMIT_COUNT equ $00FF0018
SPRITE_LAST_COUNT equ $00FF001A
TRANSFER_QUEUE_PROCESSED_COUNT equ $00FF001C
TRANSFER_QUEUE_PROCESS_CALL_COUNT equ $00FF0020
PLANE_A_HSCROLL equ $00FF0024
PLANE_B_HSCROLL equ $00FF0026
SPRITE_NEXT_ENEMY_SLOT equ $00FF0028
SPRITE_NEXT_ITEM_SLOT equ $00FF002A
SPRITE_NEXT_PROJECTILE_SLOT equ $00FF002C
SMOKE_SCROLL_PIXEL_OFFSET equ $00FF002E
SMOKE_SCROLL_TILE_OFFSET equ $00FF0030
PLANE_A_VSCROLL equ $00FF0032
PLANE_B_VSCROLL equ $00FF0034
SMOKE_SCROLL_MODE equ $00FF0036
SMOKE_VSCROLL_PIXEL_OFFSET equ $00FF0038
SMOKE_VSCROLL_TILE_OFFSET equ $00FF003A
CURRENT_ROOM_ID equ $00FF003C
BOOT_STAGE      equ $00FF0040
BOOT_DETAIL     equ $00FF0042
ROOM_DEBUG_COL  equ $00FF0044
ROOM_DEBUG_ROW  equ $00FF0046
LINK_PLACEHOLDER_X equ $00FF0048
LINK_PLACEHOLDER_Y equ $00FF004A
ROOM_TRANSITION_ACTIVE equ $00FF004C
ROOM_TRANSITION_DIRECTION equ $00FF004E
ROOM_TRANSITION_OFFSET equ $00FF0050
ROOM_TRANSITION_TARGET_ROOM equ $00FF0052
ROOM_BUILD_ROOM_ID equ $00FF0054
ROOM_CONTEXT_MODE equ $00FF0056
ROOM_CAVE_RETURN_ROOM equ $00FF0058
ROOM_CAVE_RETURN_X equ $00FF005A
ROOM_CAVE_RETURN_Y equ $00FF005C
ROOM_CAVE_TRANSITION_MODE equ $00FF005E
ROOM_CAVE_TRANSITION_TARGET_Y equ $00FF0060
SPRITE_TABLE_BUFFER equ $00FF0100
SPRITE_LAST_TABLE_BUFFER equ $00FF0380
TRANSFER_QUEUE_BUFFER equ $00FF0400
ROOM_TILEMAP_BUFFER equ $00FF0600
ROOM_PLAYAREA_ATTR_BUFFER equ $00FF0B80
ROOM_PALETTE_BUFFER equ $00FF0C00

; --- Room constants (needed by scenes) ---
ROOM_TILE_COLS equ 32
ROOM_TILE_ROWS equ 22

; --- Input bit definitions ---
PAD_RIGHT   equ 0
PAD_LEFT    equ 1
PAD_DOWN    equ 2
PAD_UP      equ 3
PAD_START   equ 4
PAD_SELECT  equ 5
PAD_B       equ 6
PAD_A       equ 7

; =============================================================================
; ROM header and vector table
; =============================================================================

    org $000000
    dc.l STACK_TOP
    dc.l EntryPoint
    rept 23
        dc.l DefaultException
    endr
    dc.l DefaultException

; =============================================================================
; Entry point and system initialization
; =============================================================================

EntryPoint:
    ; Clear RAM (except for transfer queue which needs to survive reset)
    move.w  #RAM_CLEAR_BYTES/4-1,D7
.clear_ram:
    move.l  D0,(A0)+
    dbra    D7,.clear_ram

    ; Initialize hardware
    bsr     JOYPAD_INIT
    bsr     Platform_InitVDP

    ; Load initial scene
    bsr     Scene_ZeldaDataSmoke_Init

MainLoop:
    ; Wait for VBlank
    bsr     VBlank_Wait

    ; Game systems will be added here as they come online:
    ; bsr     Mode_Update       (Phase 6)
    ; bsr     Room_Update       (Phase 3)
    ; bsr     Player_Update     (Phase 4)
    ; bsr     Objects_Update    (Phase 5)
    bsr     Renderer_BeginScene
    bsr     Scene_ZeldaDataSmoke_Update
    bsr     Renderer_EndScene

    ; Loop forever
    bra     MainLoop

; =============================================================================
; Exception handlers
; =============================================================================

DefaultException:
    rte

; =============================================================================
; VBlank Wait (from P3.66 platform.asm)
; =============================================================================

VBlank_Wait:
.wait_vblank:
    tst.b   (VBLANK_PENDING).l
    bne.s   .consume
    stop    #$2000
    bra.s   .wait_vblank
.consume:
    clr.b   (VBLANK_PENDING).l
    rts

; =============================================================================
; Include subsystems
; =============================================================================

    include "platform.asm"
    include "renderer.asm"
    include "rooms.asm"
    include "scenes/palette_diagnostic.asm"
    include "scenes/zelda_data_smoke.asm"
