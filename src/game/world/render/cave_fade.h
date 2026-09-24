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
    CAVE_FADE_LINK_ASCEND  = 3,  /* cave exit: Link walks UP, Y-=1 per 4 frames */
    CAVE_FADE_SWAP_EXIT    = 4,
    CAVE_FADE_LINK_EMERGE  = 5,  /* cave ENTRY emerge: Link walks UP from $DD to
                                  * the cave floor ($D5) via NES MoveObject
                                  * (InitMode_WalkCave, Z_05.asm:6643). */
    CAVE_FADE_LOAD_HOLD    = 6   /* between descent-end and emerge: NES holds
                                  * Link at the descent-end Y while submodes 1-7
                                  * load the cave (~29 frames) before
                                  * InitModeB_EnterCave repositions to $DD. */
} cave_fade_phase_t;

typedef struct {
    /* Called once per LINK_DESCEND tick when Link should move down 1 px
     * (every 4th frame). step_idx counts 0..15 (16 steps total). Owner
     * adjusts players[0].y += 1 and sets sprite priority. */
    void (*on_descend_step)(unsigned char step_idx);
    /* Called at SWAP_ENTRY. Owner sets scene = SCENE_CAVE +
     * Link reposition (NES $70,$DD = 112,221 face up; Z_01.asm:2965) +
     * any other RoomRom-local state bookkeeping. */
    void (*on_swap_entry)(cave_id_t cid);
    /* Called once per LINK_ASCEND tick (cave exit). Owner adjusts
     * players[0].y -= 1 + ticks walk-anim. 16 steps total. */
    void (*on_ascend_step)(unsigned char step_idx);
    /* Called at SWAP_EXIT. Owner sets scene = SCENE_OW + Link
     * reposition (16 px south of entrance facing down) + HUD reset. */
    void (*on_swap_exit)(void);
    /* Called once per LINK_EMERGE tick (cave ENTRY emerge). Owner writes
     * players[0].y = obj_y and mirrors nes_ram ObjY[0]=$84=obj_y,
     * ObjGridOffset[0]=$394=grid, ObjPosFrac[0]=$3A8=posfrac so the byte-diff
     * tracks the NES emerge (InitMode_WalkCave). obj_y walks $DD -> $D5
     * (cave floor). Appended last to keep the positional initializer order
     * of the existing four callbacks unchanged. */
    void (*on_emerge_step)(unsigned char obj_y, unsigned char grid,
                           unsigned char posfrac);
    /* Called EVERY frame during DESCEND/EMERGE/ASCEND (independent of the
     * position step) with the NES walk-anim state: counter = ObjAnimCounter
     * ($3D0, down-counts 6..1 rolling to 6), frame = ObjAnimFrame ($3E4,
     * toggles 0/1 at each roll — the 6-frame walk-pose cadence,
     * Z_07.asm:5045 AnimateObjectWalking). Owner sets s_link_frame=frame and
     * mirrors nes_ram $3D0=counter / $3E4=frame. Appended last to preserve the
     * existing positional initializer order. */
    void (*on_anim_tick)(unsigned char counter, unsigned char frame);
} cave_fade_callbacks_t;

void              cave_fade_set_callbacks(const cave_fade_callbacks_t *cb);

void              cave_fade_begin_enter(cave_id_t cid);
void              cave_fade_begin_exit(unsigned char return_room_id);

unsigned char     cave_fade_is_active(void);
cave_fade_phase_t cave_fade_phase_current(void);
void              cave_fade_tick(void);

/* Current descend step index (0..15). Returns 0 if not in
 * LINK_DESCEND phase. */
unsigned char     cave_fade_descend_step_idx(void);

/* Stamp the 2x2 BG cells above Link's standing tile with high priority
 * so the low-priority Link sprite renders BEHIND the cave entrance
 * arch — matches NES OAM sprite-priority $20 effect on the Link
 * upper-half sprite slots ($12, $13) during UpdateMode10Stairs.
 *
 * Genesis layering: low-prio sprite < high-prio BG; low-prio sprite >
 * low-prio BG. So this gives Link "covered by arch lip, visible inside
 * black interior". Call from owner at cave-entry trigger (BEFORE the
 * fade starts) so the prio bit is live across descend frames.
 *
 * The cave-plane fill at SWAP_ENTRY overwrites all cells with prio=0
 * cave tiles; on SWAP_EXIT, ow_render fill_plane_a repaints OW with
 * prio=0 defaults. So the prio bit is transient — only set during
 * the descend window. */
void              cave_fade_mark_arch_hi_prio(unsigned char link_tile_col,
                                              unsigned char link_tile_row);

#ifdef __cplusplus
}
#endif

#endif /* CAVE_FADE_H */
