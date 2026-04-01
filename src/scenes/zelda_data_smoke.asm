; =============================================================================
; Zelda Room Smoke Scene
; =============================================================================
; Phase 3 bootstrap scene:
; - uploads the full overworld + common background tile set
; - loads the extracted overworld start room from LevelInfo
; - keeps Plane B fixed for HUD space
; - draws a simple Link placeholder sprite
; - keeps the scene stable while room fidelity is debugged
; =============================================================================

ROOM_OW_BG_TILE_COUNT       equ 130
ROOM_COMMON_BG_TILE_COUNT   equ 112
ROOM_COMMON_MISC_TILE_COUNT equ 14
ROOM_COMMON_SPRITE_TILE_COUNT equ 112
ROOM_BG_TILE_COUNT          equ ROOM_OW_BG_TILE_COUNT+ROOM_COMMON_BG_TILE_COUNT+ROOM_COMMON_MISC_TILE_COUNT
ROOM_SPRITE_TILE_COUNT      equ 114
ROOM_OW_BG_VRAM             equ TILE1_VRAM+(ROOM_COMMON_BG_TILE_COUNT*32)
ROOM_COMMON_MISC_VRAM       equ ROOM_OW_BG_VRAM+(ROOM_OW_BG_TILE_COUNT*32)
ROOM_SPRITE_VRAM            equ TILE1_VRAM+(ROOM_BG_TILE_COUNT*32)
ROOM_COMMON_SPRITE_VRAM     equ ROOM_SPRITE_VRAM
ROOM_OW_SPRITE_VRAM         equ ROOM_COMMON_SPRITE_VRAM+(ROOM_COMMON_SPRITE_TILE_COUNT*32)
ROOM_COMMON_SPRITE_TILE_INDEX equ ROOM_COMMON_SPRITE_VRAM/32
ROOM_LINK_TILE_INDEX        equ ROOM_COMMON_SPRITE_TILE_INDEX+$000C
LINK_PLACEHOLDER_SPEED      equ 2
LINK_PLACEHOLDER_WIDTH      equ 16
LINK_PLACEHOLDER_HEIGHT     equ 16
LINK_RENDER_Y_OFFSET        equ 8
LINK_MIN_X                  equ 0
LINK_MAX_X                  equ (VISIBLE_COLS*8)-LINK_PLACEHOLDER_WIDTH
LINK_MIN_Y                  equ PLAYFIELD_TOP_ROW*8
LINK_MAX_Y                  equ (VISIBLE_ROWS*8)-LINK_PLACEHOLDER_HEIGHT
ROOM_TRANSITION_NONE        equ 0
ROOM_TRANSITION_RIGHT       equ 1
ROOM_TRANSITION_LEFT        equ 2
ROOM_TRANSITION_DOWN        equ 3
ROOM_TRANSITION_UP          equ 4
ROOM_TRANSITION_SCROLL_SPEED equ 8
ROOM_TRANSITION_STAGE_COL   equ VISIBLE_COLS
ROOM_TRANSITION_STAGE_ROW_DOWN equ PLAYFIELD_TOP_ROW+ROOM_TILE_ROWS
ROOM_TRANSITION_STAGE_ROW_UP equ PLANE_MAP_ROWS+PLAYFIELD_TOP_ROW-ROOM_TILE_ROWS
ROOM_TRANSITION_HORIZONTAL_PIXELS equ ROOM_TILE_COLS*8
ROOM_TRANSITION_VERTICAL_PIXELS equ ROOM_TILE_ROWS*8
ROOM_CONTEXT_OVERWORLD    equ 0
ROOM_CONTEXT_CAVE         equ 1
CAVE_TRANSITION_NONE      equ 0
CAVE_TRANSITION_ENTER     equ 1
CAVE_TRANSITION_EXIT      equ 2
CAVE_ENTRY_HALF_WIDTH     equ 8
CAVE_ENTRY_MAX_Y          equ PLAYFIELD_TOP_ROW*8+28
CAVE_INTERIOR_SPAWN_X     equ $0070
CAVE_ENTER_START_Y_OFFSET equ $0030
CAVE_EXIT_START_Y_OFFSET  equ $0010
CAVE_EXIT_TRIGGER_Y       equ LINK_MAX_Y-8
Scene_ZeldaDataSmoke_Init:
    move.w  #$0100,(BOOT_STAGE).l
    bsr     Renderer_ClearPlaneA
    bsr     Renderer_ClearPlaneB
    bsr     Renderer_ResetScroll

    move.w  #$0101,(BOOT_STAGE).l
    lea     TilesCommonBG(pc),A0
    moveq   #0,D0
    move.w  #TILE1_VRAM,D0
    move.w  #1791,D7
    bsr     Renderer_QueueVRAMWords

    move.w  #$0102,(BOOT_STAGE).l
    lea     TilesOverworldBG(pc),A0
    moveq   #0,D0
    move.w  #ROOM_OW_BG_VRAM,D0
    move.w  #2079,D7
    bsr     Renderer_QueueVRAMWords

    move.w  #$0103,(BOOT_STAGE).l
    lea     TilesCommonMisc(pc),A0
    moveq   #0,D0
    move.w  #ROOM_COMMON_MISC_VRAM,D0
    move.w  #223,D7
    bsr     Renderer_QueueVRAMWords

    move.w  #$0104,(BOOT_STAGE).l
    lea     TilesCommonSprites(pc),A0
    moveq   #0,D0
    move.w  #ROOM_COMMON_SPRITE_VRAM,D0
    move.w  #1791,D7
    bsr     Renderer_QueueVRAMWords

    move.w  #$0105,(BOOT_STAGE).l
    lea     TilesOverworldSP(pc),A0
    moveq   #0,D0
    move.w  #ROOM_OW_SPRITE_VRAM,D0
    move.w  #1823,D7
    bsr     Renderer_QueueVRAMWords

    move.w  #$0106,(BOOT_STAGE).l
    move.w  #HUD_TOP_ROW,D0
    moveq   #0,D1
    move.w  #VISIBLE_COLS,D2
    move.w  #HUD_ROWS,D3
    moveq   #0,D4
    bsr     Renderer_QueueFillRectPlaneB

    move.w  #$0107,(BOOT_STAGE).l
    bsr     Renderer_ProcessTransferQueue
    move.w  #$0108,(BOOT_STAGE).l
    bsr     Room_LoadStartingOverworld
    move.w  #$0109,(BOOT_STAGE).l
    bsr     Renderer_ProcessTransferQueue
    bsr     Scene_ZeldaDataSmoke_InstallLinkPalette
    move.w  #$010A,(BOOT_STAGE).l
    bsr     Renderer_ProcessTransferQueue

    bsr     Room_GetOverworldExitX
    move.w  D0,(LINK_PLACEHOLDER_X).l
    move.w  D0,(ROOM_CAVE_RETURN_X).l
    bsr     Room_GetOverworldExitY
    move.w  D0,(LINK_PLACEHOLDER_Y).l

    ; Initialize NES-accurate player system
    bsr     Player_Init

    clr.w   (ROOM_CONTEXT_MODE).l
    clr.w   (ROOM_CAVE_TRANSITION_MODE).l
    clr.w   (ROOM_CAVE_TRANSITION_TARGET_Y).l
    move.w  (CURRENT_ROOM_ID).l,(ROOM_CAVE_RETURN_ROOM).l
    move.w  D0,(ROOM_CAVE_RETURN_Y).l
    move.w  #$010B,(BOOT_STAGE).l
    rts

Scene_ZeldaDataSmoke_Update:
    moveq   #0,D0
    bsr     Renderer_SetPlaneBHScroll
    bsr     Renderer_SetPlaneAVScroll
    bsr     Renderer_SetPlaneBVScroll
    
    ; Update NES-accurate player system
    bsr     Player_Update
    
    bsr     Scene_ZeldaDataSmoke_HandleMovement

    move.w  (LINK_PLACEHOLDER_X).l,D0
    move.w  (LINK_PLACEHOLDER_Y).l,D1
    bsr     Scene_ZeldaDataSmoke_AdjustRenderPosForTransition
    addi.w  #LINK_RENDER_Y_OFFSET,D1
    move.w  #ROOM_LINK_TILE_INDEX,D2
    moveq   #0,D3
    bsr     Renderer_AddLinkMetaSprite2x2
    rts

Scene_ZeldaDataSmoke_AdjustRenderPosForTransition:
    tst.w   (ROOM_TRANSITION_ACTIVE).l
    beq.s   .done

    move.w  (ROOM_TRANSITION_OFFSET).l,D4
    move.w  (ROOM_TRANSITION_DIRECTION).l,D5
    cmpi.w  #ROOM_TRANSITION_RIGHT,D5
    beq.s   .right
    cmpi.w  #ROOM_TRANSITION_LEFT,D5
    beq.s   .left
    cmpi.w  #ROOM_TRANSITION_DOWN,D5
    beq.s   .down
    cmpi.w  #ROOM_TRANSITION_UP,D5
    bne.s   .done
    add.w   D4,D1
    bra.s   .done

.right:
    sub.w   D4,D0
    bra.s   .done
.left:
    add.w   D4,D0
    bra.s   .done
.down:
    sub.w   D4,D1
.done:
    rts

Scene_ZeldaDataSmoke_HandleMovement:
    tst.w   (ROOM_CAVE_TRANSITION_MODE).l
    beq.s   .check_room_transition
    bsr     Scene_ZeldaDataSmoke_UpdateCaveTransition
    rts

.check_room_transition:
    tst.w   (ROOM_TRANSITION_ACTIVE).l
    beq.s   .check_mode
    bsr     Scene_ZeldaDataSmoke_UpdateTransition
    rts

.check_mode:
    tst.w   (ROOM_CONTEXT_MODE).l
    beq.s   .normal_move
    bra     Scene_ZeldaDataSmoke_HandleCaveMovement

.normal_move:
    moveq   #0,D0
    bsr     Renderer_SetPlaneAHScroll
    move.w  (LINK_PLACEHOLDER_X).l,D1
    move.w  (LINK_PLACEHOLDER_Y).l,D2

.check_cave_entry:
    bsr     Scene_ZeldaDataSmoke_TryEnterCave
    tst.w   D0
    bne     .store_pos

.check_left_edge:
    cmpi.w  #LINK_MIN_X,D1
    bge.s   .check_right_edge
    move.w  (CURRENT_ROOM_ID).l,D3
    subq.w  #1,D3
    andi.w  #$007F,D3
    move.w  #LINK_MIN_X,D1
    move.w  #ROOM_TRANSITION_LEFT,D4
    bsr     Scene_ZeldaDataSmoke_StartHorizontalTransition
    bra     .store_pos

.check_right_edge:
    cmpi.w  #LINK_MAX_X,D1
    ble.s   .check_top_edge
    move.w  (CURRENT_ROOM_ID).l,D3
    addq.w  #1,D3
    andi.w  #$007F,D3
    move.w  #LINK_MAX_X,D1
    move.w  #ROOM_TRANSITION_RIGHT,D4
    bsr     Scene_ZeldaDataSmoke_StartHorizontalTransition
    bra     .store_pos

.check_top_edge:
    cmpi.w  #LINK_MIN_Y,D2
    bge.s   .check_bottom_edge
    move.w  (CURRENT_ROOM_ID).l,D3
    subi.w  #$0010,D3
    andi.w  #$007F,D3
    move.w  #LINK_MIN_Y,D2
    move.w  #ROOM_TRANSITION_UP,D4
    bsr     Scene_ZeldaDataSmoke_StartVerticalTransition
    bra     .store_pos

.check_bottom_edge:
    cmpi.w  #LINK_MAX_Y,D2
    ble.s   .store_pos
    move.w  (CURRENT_ROOM_ID).l,D3
    addi.w  #$0010,D3
    andi.w  #$007F,D3
    move.w  #LINK_MAX_Y,D2
    move.w  #ROOM_TRANSITION_DOWN,D4
    bsr     Scene_ZeldaDataSmoke_StartVerticalTransition
    bra     .store_pos

.store_pos:
    move.w  D1,(LINK_PLACEHOLDER_X).l
    move.w  D2,(LINK_PLACEHOLDER_Y).l
    rts

Scene_ZeldaDataSmoke_UpdateCaveTransition:
    move.w  (ROOM_CAVE_TRANSITION_MODE).l,D0
    beq.s   .done

    cmpi.w  #CAVE_TRANSITION_EXIT,D0
    bne.s   .step
    move.l  (FRAME_COUNTER).l,D3
    andi.l  #$00000003,D3
    bne.s   .done

.step:
    move.w  (LINK_PLACEHOLDER_X).l,D1
    move.w  (LINK_PLACEHOLDER_Y).l,D2
    move.w  (ROOM_CAVE_TRANSITION_TARGET_Y).l,D4

    subi.w  #1,D2
    cmp.w   D4,D2
    bhi.s   .store
    move.w  D4,D2
    cmpi.w  #CAVE_TRANSITION_EXIT,D0
    bne.s   .clear_transition
    clr.w   (ROOM_CONTEXT_MODE).l
.clear_transition:
    clr.w   (ROOM_CAVE_TRANSITION_MODE).l

.store:
    move.w  D1,(LINK_PLACEHOLDER_X).l
    move.w  D2,(LINK_PLACEHOLDER_Y).l
.done:
    rts

Scene_ZeldaDataSmoke_HandleCaveMovement:
    moveq   #0,D0
    move.b  (INPUT_HELD).l,D0
    move.w  (LINK_PLACEHOLDER_X).l,D1
    move.w  (LINK_PLACEHOLDER_Y).l,D2

    btst    #PAD_LEFT,D0
    beq.s   .check_right
    subi.w  #LINK_PLACEHOLDER_SPEED,D1
.check_right:
    btst    #PAD_RIGHT,D0
    beq.s   .check_up
    addi.w  #LINK_PLACEHOLDER_SPEED,D1
.check_up:
    btst    #PAD_UP,D0
    beq.s   .check_down
    subi.w  #LINK_PLACEHOLDER_SPEED,D2
.check_down:
    btst    #PAD_DOWN,D0
    beq.s   .try_exit
    addi.w  #LINK_PLACEHOLDER_SPEED,D2

.try_exit:
    bsr     Scene_ZeldaDataSmoke_TryExitCave
    tst.w   D0
    bne.s   .exit_started

    cmpi.w  #LINK_MIN_X,D1
    bge.s   .check_right_bound
    move.w  #LINK_MIN_X,D1
.check_right_bound:
    cmpi.w  #LINK_MAX_X,D1
    ble.s   .check_top_bound
    move.w  #LINK_MAX_X,D1
.check_top_bound:
    cmpi.w  #LINK_MIN_Y,D2
    bge.s   .check_bottom_bound
    move.w  #LINK_MIN_Y,D2
.check_bottom_bound:
    cmpi.w  #LINK_MAX_Y,D2
    ble.s   .store_pos
    move.w  #LINK_MAX_Y,D2
.store_pos:
    move.w  D1,(LINK_PLACEHOLDER_X).l
    move.w  D2,(LINK_PLACEHOLDER_Y).l
    rts

.exit_started:
    rts

Scene_ZeldaDataSmoke_TryEnterCave:
    moveq   #0,D0
    btst    #PAD_UP,(INPUT_HELD).l
    beq     .done

    movem.w D1-D2,-(A7)
    bsr     Room_GetOverworldCaveIndex
    tst.w   D0
    beq.s   .restore_done
    bsr     Room_GetOverworldExitX
    move.w  D0,D5
    bsr     Room_GetOverworldExitY
    move.w  D0,D7
.restore_done:
    movem.w (A7)+,D1-D2
    beq     .done
    moveq   #0,D0

    cmp.w   D5,D1
    bne     .done
    cmpi.w  #CAVE_ENTRY_MAX_Y,D2
    bhi     .done

    move.w  D5,D1
    move.w  D5,(LINK_PLACEHOLDER_X).l

    move.w  (CURRENT_ROOM_ID).l,(ROOM_CAVE_RETURN_ROOM).l
    move.w  D5,(ROOM_CAVE_RETURN_X).l
    move.w  D7,(ROOM_CAVE_RETURN_Y).l
    move.w  #ROOM_CONTEXT_CAVE,(ROOM_CONTEXT_MODE).l
    bsr     Room_LoadOverworldCave
    bsr     Scene_ZeldaDataSmoke_InstallLinkPalette
    bsr     Room_GetOverworldCaveSpawnY
    move.w  D0,(ROOM_CAVE_TRANSITION_TARGET_Y).l
    move.w  D0,D6
    addi.w  #CAVE_ENTER_START_Y_OFFSET,D6
    cmpi.w  #LINK_MAX_Y,D6
    bls.s   .enter_start_y_ok
    move.w  #LINK_MAX_Y,D6
.enter_start_y_ok:
    move.w  #CAVE_INTERIOR_SPAWN_X,(LINK_PLACEHOLDER_X).l
    move.w  D6,(LINK_PLACEHOLDER_Y).l
    move.w  #CAVE_TRANSITION_ENTER,(ROOM_CAVE_TRANSITION_MODE).l
    move.w  (LINK_PLACEHOLDER_X).l,D1
    move.w  (LINK_PLACEHOLDER_Y).l,D2
    moveq   #1,D0
.done:
    rts

Scene_ZeldaDataSmoke_TryExitCave:
    moveq   #0,D0
    btst    #PAD_DOWN,(INPUT_HELD).l
    beq     .done

    move.w  #CAVE_INTERIOR_SPAWN_X,D4
    move.w  D4,D5
    subi.w  #CAVE_ENTRY_HALF_WIDTH,D4
    addi.w  #CAVE_ENTRY_HALF_WIDTH,D5
    cmp.w   D4,D1
    bcs     .done
    cmp.w   D5,D1
    bhi     .done
    cmpi.w  #CAVE_EXIT_TRIGGER_Y,D2
    bcs     .done

    move.w  (ROOM_CAVE_RETURN_ROOM).l,D4
    move.w  D4,D0
    bsr     Room_LoadOverworldById
    bsr     Scene_ZeldaDataSmoke_InstallLinkPalette
    bsr     Room_GetOverworldExitX
    move.w  D0,(LINK_PLACEHOLDER_X).l
    move.w  D0,(ROOM_CAVE_RETURN_X).l
    bsr     Room_GetOverworldExitY
    move.w  D0,D6
    move.w  D0,(ROOM_CAVE_RETURN_Y).l
    move.w  D6,(ROOM_CAVE_TRANSITION_TARGET_Y).l
    addi.w  #CAVE_EXIT_START_Y_OFFSET,D6
    move.w  D6,(LINK_PLACEHOLDER_Y).l
    move.w  #CAVE_TRANSITION_EXIT,(ROOM_CAVE_TRANSITION_MODE).l
    move.w  (LINK_PLACEHOLDER_X).l,D1
    move.w  (LINK_PLACEHOLDER_Y).l,D2
    moveq   #1,D0
.done:
    rts

Scene_ZeldaDataSmoke_StartHorizontalTransition:
    move.w  #1,(ROOM_TRANSITION_ACTIVE).l
    move.w  D4,(ROOM_TRANSITION_DIRECTION).l
    clr.w   (ROOM_TRANSITION_OFFSET).l
    move.w  D3,(ROOM_TRANSITION_TARGET_ROOM).l
    movem.w D1-D2,-(A7)
    move.w  D3,D0
    bsr     Room_BuildOverworldTilemapForRoomId
    move.w  #PLAYFIELD_TOP_ROW,D0
    move.w  #ROOM_TRANSITION_STAGE_COL,D1
    bsr     Room_QueueOverworldTilemapAt
    movem.w (A7)+,D1-D2
    rts

Scene_ZeldaDataSmoke_StartVerticalTransition:
    move.w  #1,(ROOM_TRANSITION_ACTIVE).l
    move.w  D4,(ROOM_TRANSITION_DIRECTION).l
    clr.w   (ROOM_TRANSITION_OFFSET).l
    move.w  D3,(ROOM_TRANSITION_TARGET_ROOM).l
    movem.w D1-D2,-(A7)
    move.w  D3,D0
    bsr     Room_BuildOverworldTilemapForRoomId
    move.w  #0,D1
    cmpi.w  #ROOM_TRANSITION_DOWN,D4
    bne.s   .stage_up
    move.w  #ROOM_TRANSITION_STAGE_ROW_DOWN,D0
    bra.s   .queue_target
.stage_up:
    move.w  #ROOM_TRANSITION_STAGE_ROW_UP,D0
.queue_target:
    bsr     Room_QueueOverworldTilemapAt
    movem.w (A7)+,D1-D2
    rts

Scene_ZeldaDataSmoke_UpdateTransition:
    move.w  (ROOM_TRANSITION_DIRECTION).l,D1
    cmpi.w  #ROOM_TRANSITION_DOWN,D1
    bcc     Scene_ZeldaDataSmoke_UpdateVerticalTransition

    move.w  (ROOM_TRANSITION_OFFSET).l,D0
    addi.w  #ROOM_TRANSITION_SCROLL_SPEED,D0
    move.w  D0,(ROOM_TRANSITION_OFFSET).l

    move.w  D0,D2
    cmpi.w  #ROOM_TRANSITION_RIGHT,D1
    bne.s   .apply_scroll
    neg.w   D2
.apply_scroll:
    move.w  D2,D0
    bsr     Renderer_SetPlaneAHScroll

    cmpi.w  #256,(ROOM_TRANSITION_OFFSET).l
    bcs.s   .done

    move.w  (ROOM_TRANSITION_TARGET_ROOM).l,D0
    move.w  (ROOM_TRANSITION_DIRECTION).l,D3
    move.w  D3,-(A7)
    bsr     Room_LoadOverworldById
    bsr     Scene_ZeldaDataSmoke_InstallLinkPalette
    move.w  (A7)+,D3
    clr.w   (ROOM_TRANSITION_ACTIVE).l
    clr.w   (ROOM_TRANSITION_DIRECTION).l
    clr.w   (ROOM_TRANSITION_OFFSET).l
    clr.w   (ROOM_TRANSITION_TARGET_ROOM).l
    moveq   #0,D0
    bsr     Renderer_SetPlaneAHScroll
    cmpi.w  #ROOM_TRANSITION_RIGHT,D3
    bne.s   .finish_left
    move.w  #LINK_MIN_X,(LINK_PLACEHOLDER_X).l
    bra.s   .done
.finish_left:
    move.w  #LINK_MAX_X,(LINK_PLACEHOLDER_X).l
.done:
    rts

Scene_ZeldaDataSmoke_UpdateVerticalTransition:
    move.w  (ROOM_TRANSITION_OFFSET).l,D0
    addi.w  #ROOM_TRANSITION_SCROLL_SPEED,D0
    move.w  D0,(ROOM_TRANSITION_OFFSET).l

    move.w  (ROOM_TRANSITION_DIRECTION).l,D1
    move.w  D0,D2
    cmpi.w  #ROOM_TRANSITION_DOWN,D1
    bne.s   .apply_vscroll
    neg.w   D2
.apply_vscroll:
    move.w  D2,D0
    bsr     Renderer_SetPlaneAVScroll

    cmpi.w  #ROOM_TRANSITION_VERTICAL_PIXELS,(ROOM_TRANSITION_OFFSET).l
    bcs.s   .done

    move.w  (ROOM_TRANSITION_TARGET_ROOM).l,D0
    move.w  (ROOM_TRANSITION_DIRECTION).l,D3
    move.w  D3,-(A7)
    bsr     Room_LoadOverworldById
    bsr     Scene_ZeldaDataSmoke_InstallLinkPalette
    move.w  (A7)+,D3
    clr.w   (ROOM_TRANSITION_ACTIVE).l
    clr.w   (ROOM_TRANSITION_DIRECTION).l
    clr.w   (ROOM_TRANSITION_OFFSET).l
    clr.w   (ROOM_TRANSITION_TARGET_ROOM).l
    moveq   #0,D0
    bsr     Renderer_SetPlaneAVScroll
    cmpi.w  #ROOM_TRANSITION_DOWN,D3
    bne.s   .finish_up
    move.w  #LINK_MIN_Y,(LINK_PLACEHOLDER_Y).l
    bra.s   .done
.finish_up:
    move.w  #LINK_MAX_Y,(LINK_PLACEHOLDER_Y).l
.done:
    rts

Scene_ZeldaDataSmoke_LoadRoomFromD3:
    move.w  D1,-(A7)
    move.w  D2,-(A7)
    move.w  D3,D0
    bsr     Room_LoadOverworldById
    bsr     Scene_ZeldaDataSmoke_InstallLinkPalette
    move.w  (A7)+,D2
    move.w  (A7)+,D1
    rts

Scene_ZeldaDataSmoke_InstallLinkPalette:
    lea     (ROOM_PALETTE_BUFFER).l,A0
    clr.w   (A0)
    lea     LinkColorsGenesis(pc),A1
    move.w  (A1)+,2(A0)
    move.w  (A1)+,4(A0)
    move.w  (A1)+,6(A0)
    lea     (ROOM_PALETTE_BUFFER).l,A0
    move.w  #63,D7
    bsr     Renderer_QueueCRAMWords
    rts

    include "data/tiles_overworld.inc"
    include "data/tiles_common.inc"
