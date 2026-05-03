/* world_dispatch.h — native overworld + object subsystem dispatch
 * (debate 006 D2 follow-up; Phase 4 entry point per master plan).
 *
 * Both ROMs link this. Title.md (post-cutover) replaces
 * src/gen/z_01.c worldrt_* / objrt_* / sprrt_* / progrt_* / trprt_*
 * callsites with native equivalents from src/game/world/. RoomRom
 * calls directly from main.c when SCENE_OW logic ports.
 *
 * Native impl mirrors src/oracle/world/ reference (drained C, MATCH-
 * verified per per-function findings) and reference/aldonunez/Z_*.asm
 * spec. NO transpile-bridge shims (z01_/z07_/c_/progrt_/objrt_/
 * sprrt_) — pure C + src/state/world_state.h typed accessors +
 * src/sgdk_adapter/ render API.
 *
 * Phase 4 first port: world_get_object_middle (smallest, no shims).
 * Subsequent ports per Phase 3 D1 loop: per-function diff against
 * NES asm before commit, Gate 1 finding doc per port.
 */

#ifndef WORLD_DISPATCH_H
#define WORLD_DISPATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* Compute the (X+8, Y+8) middle pixel of an object slot — or
 * (X+4, Y+8) if ObjAttr bit $40 is set (half-width). Result lands in
 * WORLD_TMP2 (mid-X) + WORLD_TMP3 (mid-Y). NES GetObjectMiddle at
 * Z_01.asm:5498. Used by collision detection in subsequent ports. */
void world_get_object_middle(unsigned int slot);

/* Maze step-tracker for the forest ($61) and mountain ($1B) overworld
 * mazes. Reads LINK_DIR + CUR_ROOM_ID + WORLD_MAZE_STEP, advances or
 * resets the step, and either lets Link exit (right in forest, left in
 * mountain) or pins the next room to current. Plays "secret found"
 * tune (Tune1Request = 4 = WORLD_SECRET_SFX) on the 4th matching step.
 *
 * Mirrors NES CheckMazes (Z_01.asm:4791). Drain at
 * src/oracle/world/world_runtime.c:68-109. Pure C, no shims. */
void world_check_mazes(void);

#ifdef __cplusplus
}
#endif

#endif /* WORLD_DISPATCH_H */
