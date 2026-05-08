#ifndef RENDER_BUDGET_H
#define RENDER_BUDGET_H

/* ---------------------------------------------------------------------------
 * Phase 6 Task 6.1 — Genesis sprite-per-line budget envelope.
 *
 * Genesis VDP sprite limits (H40 mode):
 *   - 80 sprites total in the SAT
 *   - 20 sprites per scanline before the line drops the rest
 *
 * Phase 6 render code MUST consume this budget so Phase 13 multiplayer
 * cannot violate it. The reservation columns sum to ≤ 20 per scanline
 * and ≤ 80 total. Anything over budget is dropped at frame compose time
 * (priority order: player > enemy > projectile > effect).
 *
 * Reservation rationale (1-player baseline that scales to 4-player):
 *   - Player Link  : 4 sprites (8x16 patches around 16x16 hitbox)
 *   - Enemies      : 32 sprites (8 enemies x 4 sprites each, NES cap)
 *   - Projectiles  : 16 sprites (NES allows ~12 active; 16 = headroom)
 *   - Effects      : 16 sprites (smoke, sparkle, item-pickup)
 *   - HUD overlay  : 8  sprites (heart row + selected-item icon)
 *   - Slack        : 4  sprites (debug overlays, late-frame inserts)
 *   = 80 sprites total (exact VDP cap).
 *
 * Per-scanline cap is 20. The frame compose pass enforces a per-row
 * counter and drops sprites that would push a row past 20. Phase 13
 * scales the player reservation to 4 * 4 = 16 sprites and shrinks the
 * enemy slice (engine-room work; the envelope itself is static).
 * ------------------------------------------------------------------------ */

#define RENDER_BUDGET_VDP_TOTAL_SPRITES   80u
#define RENDER_BUDGET_VDP_PER_LINE        20u

#define RENDER_BUDGET_PLAYER_SPRITES      4u
#define RENDER_BUDGET_ENEMY_SPRITES       32u
#define RENDER_BUDGET_PROJECTILE_SPRITES  16u
#define RENDER_BUDGET_EFFECT_SPRITES      16u
#define RENDER_BUDGET_HUD_SPRITES         8u
#define RENDER_BUDGET_SLACK_SPRITES       4u

/* Compile-time sanity: the reservation columns sum to exactly the VDP
 * cap. Phase 13 changes the player reservation and reduces another
 * column by the same delta — the static_assert is the wall it must not
 * push past. */
#if (RENDER_BUDGET_PLAYER_SPRITES \
   + RENDER_BUDGET_ENEMY_SPRITES \
   + RENDER_BUDGET_PROJECTILE_SPRITES \
   + RENDER_BUDGET_EFFECT_SPRITES \
   + RENDER_BUDGET_HUD_SPRITES \
   + RENDER_BUDGET_SLACK_SPRITES) > RENDER_BUDGET_VDP_TOTAL_SPRITES
#error "Render budget reservations exceed Genesis VDP 80-sprite cap."
#endif

/* Runtime accumulator. Frame compose resets this to 0, increments per
 * sprite emitted, and drops further sprites once the cap is hit. The
 * per-line array is indexed by Y/8 (32 rows, NTSC playfield).
 *
 * Phase 6 code that writes the SAT MUST go through render_budget_emit()
 * (defined in src/sgdk_adapter/) instead of raw SAT writes. */
typedef struct RenderBudget {
    unsigned short total_emitted;
    unsigned char  per_line[32];
} RenderBudget;

extern RenderBudget g_render_budget;

#endif /* RENDER_BUDGET_H */
