/* world_dispatch.c — native overworld dispatch (Phase 4 entry).
 *
 * Phase 4 first port: world_get_object_middle. Pure C, no shims.
 * Drain MATCH per Gate 1 finding 4_1n_world_get_object_middle.
 */

#include "world_dispatch.h"
#include "world_state.h"      /* WORLD_TMP2/3, OBJ_X/_Y/_STATUS_FLAGS */
#include "platform_abi.h"     /* nes_ram[] direct access for SRAM ($6000+) tables */

/* NES SRAM base. Cartridge data tables (LevelBlockAttrsF,
 * LevelInfo_*) live at $6000+offset and are accessed through nes_ram[]
 * since the bridge layer mirrors SRAM into the same address space. */
#define NES_SRAM_BASE 0x6000u

unsigned int world_get_shortcut_or_item_xy_for_room(unsigned int room_id)
{
    /* NES GetShortcutOrItemXYForRoom (Z_01.asm:4002). Drain at
     * world_runtime.c:6-13. Drain MATCH per finding 4_1n_c.
     *
     *   LDA LevelBlockAttrsF, Y     ; SRAM $6AFE + room_id
     *   AND #$30 / LSR x4           ; isolate bits 4-5 -> type_idx
     *   LDA LevelInfo_ShortcutOrItemPosArray, Y  ; SRAM $6BA7 + type_idx
     *   PHA / AND #$0F / ASL x4     ; low nibble << 4 = Y
     *   PLA / AND #$F0              ; high nibble = X
     *   RTS                          ; A=X, Y=Y
     *
     * Native packs (X, Y) into one return: (X << 8) | Y. */
    const unsigned char lookup =
        nes_ram[NES_SRAM_BASE + 0x0AFEu + (room_id & 0xFFu)];
    const unsigned char type_idx = (unsigned char)((lookup & 0x30u) >> 4);
    const unsigned char entry =
        nes_ram[NES_SRAM_BASE + 0x0BA7u + type_idx];
    const unsigned char y = (unsigned char)((entry & 0x0Fu) << 4);
    const unsigned char x = (unsigned char)(entry & 0xF0u);
    return ((unsigned int)x << 8) | (unsigned int)y;
}

unsigned int world_get_shortcut_or_item_xy(void)
{
    /* NES GetShortcutOrItemXY (Z_01.asm:3993): LDY RoomId / fall-through
     * to GetShortcutOrItemXYForRoom. Native passes CUR_ROOM_ID = RAM($00EB). */
    return world_get_shortcut_or_item_xy_for_room((unsigned int)CUR_ROOM_ID);
}

void world_check_mazes(void)
{
    /* NES CheckMazes (Z_01.asm:4791). Drain at world_runtime.c:68-109.
     * Drain MATCH per finding 4_1n_b. Tables baked in inline:
     *   ForestMazeDirs   = $08, $02, $04, $02 (down, left, right(?), left)
     *   MountainMazeDirs = $08, $08, $08, $08 (down, down, down, down)
     *
     * NES uses ObjDir bits ($08=down, $04=right, $02=left, $01=right —
     * actually 6502 conventions vary; here we follow NES Z_01.asm
     * literal byte values). Drain uses LINK_DIR macro which reads
     * RAM($0098) = ObjDir. */
    static const unsigned char forest_dirs[4]   = { 0x08u, 0x02u, 0x04u, 0x02u };
    static const unsigned char mountain_dirs[4] = { 0x08u, 0x08u, 0x08u, 0x08u };

    const unsigned char step = WORLD_MAZE_STEP;
    const unsigned char dir  = LINK_DIR;
    const unsigned char room = CUR_ROOM_ID;

    /* Forest maze ($61). */
    if (room == 0x61u) {
        if (dir != forest_dirs[step]) {
            /* Mismatch: $01 (allow exit) else reset + lock-in-room. */
            if (dir == 0x01u) {
                return;
            }
            WORLD_MAZE_STEP = 0u;
            PREV_ROOM_ID    = room;  /* drain alias: PREV_ROOM_ID = NES NextRoomId ($00EC) */
            return;
        }
        /* Match. Last step? Play secret tune. Else advance + lock. */
        if (step == 3u) {
            WORLD_SECRET_SFX = 4u;   /* drain alias for Tune1Request */
            return;
        }
        WORLD_MAZE_STEP = (uint8_t)(WORLD_MAZE_STEP + 1u);
        PREV_ROOM_ID    = room;
        return;
    }

    /* Not forest or mountain → reset only. */
    if (room != 0x1Bu) {
        WORLD_MAZE_STEP = 0u;
        return;
    }

    /* Mountain maze ($1B). */
    if (dir == mountain_dirs[step]) {
        if (step == 3u) {
            WORLD_SECRET_SFX = 4u;
            return;
        }
        WORLD_MAZE_STEP = (uint8_t)(WORLD_MAZE_STEP + 1u);
        PREV_ROOM_ID    = room;
        return;
    }
    /* Mismatch in mountain: $02 (left) allows exit, else reset. */
    if (dir == 0x02u) {
        return;
    }
    WORLD_MAZE_STEP = 0u;
    PREV_ROOM_ID    = room;
}

void world_get_object_middle(unsigned int slot)
{
    /* NES GetObjectMiddle (Z_01.asm:5498). Drain at
     * src/oracle/world/world_runtime.c:19-27. Drain MATCH per finding
     * 4_1n_world_get_object_middle.
     *
     *   $02 = $03 = 8                   ; default offset = 8 (full sprite center)
     *   if (ObjAttr+X & $40) LSR $02    ; half-width → offset = 4
     *   $02 = ObjX+X + $02              ; mid-X
     *   $03 = ObjY+X + $03              ; mid-Y
     *
     * ObjAttr = $04BF per Variables.inc; bit $40 = "half width" flag
     * for collision detection. */
    WORLD_TMP2 = 8u;
    WORLD_TMP3 = 8u;
    if (OBJ_STATUS_FLAGS(slot) & 0x40u) {
        WORLD_TMP2 = (uint8_t)(WORLD_TMP2 >> 1);
    }
    WORLD_TMP2 = (uint8_t)(OBJ_X(slot) + WORLD_TMP2);
    WORLD_TMP3 = (uint8_t)(OBJ_Y(slot) + WORLD_TMP3);
}
