/* cave_dispatch.h — native cave gamemode entry (debate 006 D2).
 *
 * Both ROMs link this. Title.md (post-cutover) replaces
 * src/gen/z_01.c cavert_init_cave / cavert_update_cave_person /
 * cavert_draw_cave_person callsites with these. RoomRom calls
 * directly from main.c SCENE_CAVE dispatch.
 *
 * Native impl mirrors src/oracle/cave/cave_runtime.c reference
 * (verified MATCH per Gate 1 findings 3_2, 3_2b, 3_4) and
 * reference/aldonunez/Z_01.asm spec. NO transpile-bridge shims
 * (z01_/z07_/c_/progrt_) — pure C + src/state/cave_state.h typed
 * struct + src/sgdk_adapter/ render API.
 *
 * Scope (first iteration):
 *   cave_init   — populate CaveState + upload cave palette
 *   cave_tick   — per-frame logic (stub for now; NPC/shop ports later)
 *   cave_exit   — restore overworld state
 *
 * Phase 12 promotion target: this file becomes Title.md's primary
 * cave gameplay path; src/oracle/cave/ retires.
 */

#ifndef CAVE_DISPATCH_H
#define CAVE_DISPATCH_H

/* Avoid stdint.h here: under SGDK_GCC the toolchain's types.h defines
 * uint8_t / uint32_t as macros aliasing SGDK's u8 / u32, which collides
 * with the project's src/stdint.h shim (typedef-based). cave_dispatch.h
 * is a public header included by both Title.md (no SGDK_GCC) and RoomRom
 * (with SGDK_GCC), so use plain C types in the API. cave_state.h needs
 * stdint.h types internally — gate by SGDK_GCC there too if/when needed. */

#ifdef __cplusplus
extern "C" {
#endif

/* Cave identifier per NES Z_01.asm CaveSpec table.
 * 0x6A..0x7C maps to cave room types (sword/heart/shop/old man/etc.). */
typedef unsigned char cave_id_t;

/* Initialize cave subsystem for the given cave_id. Populates
 * CaveState typed struct + uploads cave BG CHR + loads palette via
 * src/sgdk_adapter/ render API. Idempotent — caller may re-init if
 * cave_id changes. Returns 0 on success, -1 on invalid cave_id. */
int cave_init(cave_id_t cave_id);

/* Per-frame cave tick. Called once per VBlank from gameplay loop.
 * Currently stub (returns immediately). NPC/shop/text logic ports
 * per-function from oracle reference in subsequent commits. */
void cave_tick(void);

/* Cave exit handler. Saves any persistent state to the typed CaveState
 * + signals scene transition back to overworld. Caller (RoomRom main
 * or Title.md gamemode dispatch) handles the actual scene swap. */
void cave_exit(void);

/* Read accessor: which cave is currently active. Returns 0 if no
 * cave entered since last cave_exit. */
cave_id_t cave_current_id(void);

/* Draw a cave NPC sprite for the given object slot.
 *
 * Native rewrite of NES Z_01.asm DrawCavePerson (lines 370-383),
 * verified MATCH per Gate 1 finding 3_4. NES dispatch logic:
 *
 *   JSR Anim_FetchObjPosForSpriteDescriptor
 *   LDY ObjType+1
 *   CPY #$7B
 *   BCS NotMirrored          ; ObjType+1 >= 0x7B
 *   JMP DrawObjectMirrored   ; otherwise
 *   NotMirrored: JMP DrawObjectNotMirrored
 *
 * Stage 1 (this commit): port branch shape only. The actual sprite
 * descriptor fetch + SAT writes are stubs — Phase 4 cross-subsystem
 * native object_draw port replaces them with render_sat_write-based
 * impl. Title.md gates this via NATIVE_CAVE_DRAW (default OFF), so
 * stage-1 stub never runs in shipping path. RoomRom links it but
 * doesn't call it yet (cave_tick is also stub). */
void cave_draw_person(unsigned int slot);

/* Draw the cave's wares row + price rupee.
 *
 * Native rewrite of NES Z_01.asm DrawCaveItems (lines 388-440), MATCH
 * verdict per Phase 3 summary. Two cave-flag conditions:
 *
 *   CAVE_FLAGS & 0x04 (show items)  -> loop wares 2..0, position via
 *                                      ware_xs[i] / Y=$98, draw item if
 *                                      not $3F (sentinel).
 *   CAVE_FLAGS & 0x08 (show prices) -> draw rupee sprite at ($30, $AB).
 *
 * Stage-1: positioning + flag dispatch native; underlying item_object
 * draw is Phase 4 deferred (c_animate_item_object stub). NES table
 * CaveWareXs = $58/$78/$98 baked in as ware_xs[]. */
void cave_draw_items(void);

#ifdef __cplusplus
}
#endif

#endif /* CAVE_DISPATCH_H */
