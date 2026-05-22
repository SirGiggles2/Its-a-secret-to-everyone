/* cave_fade.h — NES cave entry / exit Link-descend animation.
 *
 * Matches NES Z_05.asm:2308 UpdateMode10Stairs_Full + InitMode10
 * (Z_05.asm:1400). NES sequence on entry:
 *   1. Link standing on entrance tile $24 (or stairs $70-$73, $88).
 *   2. EffectRequest = $08 (stairs effect), StairsTargetY = ObjY + $10.
 *   3. Each frame: every 4th frame (FrameCounter & 3 == 0), increment
 *      ObjY by 1 (Link walks down one pixel). 16 px total = 64 frames.
 *      Link upper-half sprites get priority bit $20 set so background
 *      entrance arch covers them ("Link sinks into hole" effect).
 *   4. When ObjY == StairsTargetY: GameMode = TargetMode (cave). Scene
 *      swaps instantly to cave with Link at bottom-center.
 *
 * Exit mirrors with ObjY -= 1 every 4 frames until target reached.
 * For Tier 1 simplicity, exit uses a snap (no ascend anim) — user
 * hits C+START chord to leave; Link snaps to OW return position.
 *
 * Phase order on entry:
 *   IDLE -> LINK_DESCEND (64 frames) -> SWAP_ENTRY (1) -> IDLE.
 * Phase order on exit:
 *   IDLE -> SWAP_EXIT (1, instant) -> IDLE.
 */

#ifndef CAVE_FADE_H
#define CAVE_FADE_H

#include "../../cave/cave_dispatch.h"  /* cave_id_t */

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    CAVE_FADE_IDLE         = 0,
    CAVE_FADE_LINK_DESCEND = 1,
    CAVE_FADE_SWAP_ENTRY   = 2,
    CAVE_FADE_SWAP_EXIT    = 3
} cave_fade_phase_t;

typedef struct {
    /* Called once per LINK_DESCEND tick when Link should move down 1 px
     * (every 4th frame). step_idx counts 0..15 (16 steps total). Owner
     * adjusts players[0].y += 1 and sets sprite priority. */
    void (*on_descend_step)(unsigned char step_idx);
    /* Called at SWAP_ENTRY. Owner sets scene = SCENE_CAVE +
     * Link reposition (120, 192 face up) + any other RoomRom-local
     * state bookkeeping. */
    void (*on_swap_entry)(cave_id_t cid);
    /* Called at SWAP_EXIT. Owner sets scene = SCENE_OW + Link
     * reposition (16 px south of entrance facing down) + HUD reset. */
    void (*on_swap_exit)(void);
} cave_fade_callbacks_t;

void              cave_fade_set_callbacks(const cave_fade_callbacks_t *cb);

void              cave_fade_begin_enter(cave_id_t cid);
void              cave_fade_begin_exit(unsigned char return_room_id);

unsigned char     cave_fade_is_active(void);
cave_fade_phase_t cave_fade_phase_current(void);
void              cave_fade_tick(void);

/* Current descend step index (0..15). Owner uses this to decide when
 * to hide Link sprite (e.g. step >= 4 == "Link is mostly inside the
 * cave entrance" — approximates NES sprite-priority "behind arch"
 * effect without per-tile BG prio bit setup). Returns 0 if not in
 * LINK_DESCEND phase. */
unsigned char     cave_fade_descend_step_idx(void);

#ifdef __cplusplus
}
#endif

#endif /* CAVE_FADE_H */
