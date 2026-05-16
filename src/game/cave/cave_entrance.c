/* cave_entrance.c — Tier 0 cave-entrance tile detection.
 *
 * NES source: reference/aldonunez/Z_05.asm:7313 HandleWarpOW.
 * Stance:     EXTEND (composes existing cave_init).
 *
 * NES check (Z_05.asm:7320-7332):
 *   CMP #$24  BEQ entrance         ; armos pad / special warp
 *   CMP #$88  BEQ entrance         ; rock pile / bombable
 *   CMP #$70  BCC  return_no_entry
 *   CMP #$74  BCS  return_no_entry
 *   STA  ObjCollidedTile = $70     ; normalize $70..$73 stairs tiles
 *
 * NES then looks up `LevelBlockAttrsB[RoomId] & $FC` to pick cave_id
 * (or level number). Tier 0 MVP returns first cave_id $6A so the
 * SCENE_CAVE transition fires; per-room cave-id lookup defers.
 */

#include "cave_entrance.h"

cave_id_t cave_entrance_check(unsigned char tile)
{
    /* Z_05.asm:7320 — special-tile checks first. */
    if (tile == 0x24u) {
        return (cave_id_t)0x6Au;
    }
    if (tile == 0x88u) {
        return (cave_id_t)0x6Au;
    }
    /* Z_05.asm:7324-7327 — stairs range $70..$73. */
    if (tile >= 0x70u && tile <= 0x73u) {
        return (cave_id_t)0x6Au;
    }
    return (cave_id_t)0;
}
