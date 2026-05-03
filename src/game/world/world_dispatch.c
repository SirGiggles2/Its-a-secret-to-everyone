/* world_dispatch.c — native overworld dispatch (Phase 4 entry).
 *
 * Phase 4 first port: world_get_object_middle. Pure C, no shims.
 * Drain MATCH per Gate 1 finding 4_1n_world_get_object_middle.
 */

#include "world_dispatch.h"
#include "world_state.h"  /* WORLD_TMP2/3, OBJ_X/_Y/_STATUS_FLAGS */

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
