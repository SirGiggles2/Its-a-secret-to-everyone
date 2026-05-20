/* inventory_render.h — Phase 6 P6.2 pause subscreen renderer.
 *
 * Draws the NES Z1 inventory subscreen to Genesis Plane A when the
 * pause flag transitions to active. V1 = static BG tilemap layout
 * + sprite-based item icons + B-item cursor.
 *
 * Hook points:
 *   - inventory_subscreen_enter() — call when pause transitions OFF->ON
 *     (clears Plane A, writes subscreen tilemap, populates SAT with
 *     item icon sprites for owned items).
 *   - inventory_subscreen_exit()  — call when pause transitions ON->OFF
 *     (signals room renderer to re-paint Plane A from gameplay state).
 *   - inventory_subscreen_tick(joy_state) — call per-frame while paused
 *     (handles D-pad cursor movement + A-press B-item selection).
 *
 * NES reference: Z_05.asm:152 UpdateMenuAndMeters; :156 UpdateMenu;
 * Z_07.asm:868 DrawItemInInventory.
 */
#ifndef INVENTORY_RENDER_H
#define INVENTORY_RENDER_H

void inventory_subscreen_enter(void);
void inventory_subscreen_exit(void);
void inventory_subscreen_tick(unsigned char joy_state);

/* Query: is the subscreen currently being displayed? */
unsigned char inventory_subscreen_is_active(void);

/* Query: scroll-out finished (gameplay should resume + room reload). */
unsigned char inventory_subscreen_scrolled_out(void);

#endif /* INVENTORY_RENDER_H */
