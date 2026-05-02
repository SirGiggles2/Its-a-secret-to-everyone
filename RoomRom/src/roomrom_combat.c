#include "roomrom_combat.h"
#include "roomrom_sprites.h"

/* RoomRom S7 v4 combat — sword swing.
 *
 * NES Z1 model (reference/aldonunez/Z_05.asm WieldSword + Z_07.asm
 * UpdateSwordOrRod + PlayerToWeaponOffsets[XY]):
 *
 *   State 1 (5 frames): windup. Sword raised UP regardless of facing.
 *                       Link in attack pose facing his current direction.
 *   State 2 (8 frames): full extend in facing direction.
 *   State 3 (1 frame):  mid-retract.
 *   State 4 (1 frame):  almost retracted.
 *   State 5 (1 frame):  invisible — sword sprite hidden, Link returns
 *                       to walk pose.
 *
 * Total swing window: 5 + 8 + 1 + 1 + 1 = 16 frames. Re-swing locked
 * the entire 16 frames. Link's body stays in attack pose for states
 * 1-4 (15 frames), reverts to walk pose at state 5.
 *
 * Sword position offsets (from PlayerToWeaponOffsetsX/Y at Z_07:4337):
 *   reverse-direction order = up, down, left, right
 *   state 1: X=-1,+1, 0,-8   Y=-9,-14,-11,-11
 *   state 2: X=-1,+1,-11,+11 Y=-10,+13,+3,+3
 *   state 3: X=-1,+1,-7,+7   Y=-9,+9,+3,+3
 *   state 4: X=-1,+1,-3,+3   Y=-1,+5,+3,+3
 *
 * For state 1 the sword is drawn UP (vertical, no flip) regardless of
 * Link's facing — the windup. The position offset for state 1 still
 * varies per facing (Link's hand position differs).
 */

/* NES Z1 doesn't visibly draw a sword windup (sword raised UP above
 * Link for all facings before extending). Verified 2026-05-01 via
 * BizHawk OAM scan of NES Z1 sword swing: gameplay sword sprite first
 * appears at state 2 extend in facing direction — disassembly's state 1
 * branch may exist but isn't visible on real hardware. State 1 skipped
 * here to match observed NES behavior. */
#define COMBAT_STATE1_FRAMES   0u
#define COMBAT_STATE2_FRAMES   8u
#define COMBAT_STATE3_FRAMES   1u
#define COMBAT_STATE4_FRAMES   1u
#define COMBAT_STATE5_FRAMES   1u
#define COMBAT_TOTAL_FRAMES    (COMBAT_STATE1_FRAMES + COMBAT_STATE2_FRAMES \
                                + COMBAT_STATE3_FRAMES + COMBAT_STATE4_FRAMES \
                                + COMBAT_STATE5_FRAMES)

typedef enum {
    COMBAT_IDLE  = 0,
    COMBAT_ACTIVE
} combat_state_t;

static combat_state_t s_state    = COMBAT_IDLE;
static unsigned char  s_frame    = 0u;   /* 0..COMBAT_TOTAL_FRAMES-1 */
static link_face_t    s_face     = LINK_FACE_DOWN;

/* S7 v5 sword beam (Z_07.asm UpdateSwordShotOrMagicShot, MakeSwordShot
 * at Z_07:4581). Beam spawns at sword state 3 transition (frame 13 of
 * 16). Travels at q-speed $C0 = 3 px/frame in facing direction.
 * Lifetime: until off-screen. RoomRom OW playfield rough bounds:
 * x in [0, 256), y in [HUD_BOTTOM, 224). Use generous bounds for
 * v5 (x in [-16, 272), y in [-16, 240)). */
#define BEAM_FRAME_SPAWN     (COMBAT_STATE1_FRAMES + COMBAT_STATE2_FRAMES)  /* 13 */
#define BEAM_SPEED_PX        3
#define BEAM_BOUND_X_MIN     ((short)(-16))
#define BEAM_BOUND_X_MAX     ((short)272)
#define BEAM_BOUND_Y_MIN     ((short)(-16))
#define BEAM_BOUND_Y_MAX     ((short)240)

static unsigned char  s_beam_active   = 0u;
static link_face_t    s_beam_face     = LINK_FACE_DOWN;
static short          s_beam_x        = 0;
static short          s_beam_y        = 0;

/* Y bias applied to sword + beam to match NES Z_07.asm:3320 — in OW
 * (CurLevel == 0), Link is drawn 2 px DOWN from ObjY (INC $01 twice),
 * but the sword is NOT shifted. To replicate that visual relationship
 * on Genesis (where Link is drawn at link_y directly with no shift),
 * bias the sword/beam UP by 2 in OW; in UW (CurLevel != 0) NES draws
 * neither shifted, so bias = 0. Default OW (-2). */
static short s_uw_y_bias = -2;

/* Beam tip-offset table (from sword tip into open space). Indexed by
 * face. Beam spawns at link + this offset, then travels in facing
 * direction. Tuned to align with sword's state-2 tip + a small forward
 * extension. */
static const signed char beam_spawn_x[4] = {
    /* DOWN UP LEFT RIGHT */
     +4,  +4, -16, +16
};
static const signed char beam_spawn_y[4] = {
    /* DOWN UP LEFT RIGHT */
    +24, -16,  +4,  +4
};

/* Track UW separately so set_redux can recompute bias in case the redux
 * flag changes after set_uw was called. */
static unsigned char s_in_uw = 0u;

static void recompute_y_bias(void);

void roomrom_combat_set_uw(unsigned char in_uw)
{
    s_in_uw = in_uw ? 1u : 0u;
    recompute_y_bias();
}

static unsigned char s_redux = 0u;
void roomrom_combat_set_redux(unsigned char redux)
{
    s_redux = redux ? 1u : 0u;
    recompute_y_bias();
}

/* Compute sword/beam Y bias.
 *
 * Vanilla Z1 (Z_07.asm:3320): in OW (CurLevel==0), Link is drawn +2 px
 * down via INC $01 twice; sword draw doesn't get this shift, so visual
 * sword Y - link Y = offset - 2. UW skips the +2 shift entirely so
 * visual diff = offset.
 *
 * Redux (Zelda1-Redux/code/gameplay/sword_draw.asm:104): OW does not
 * shift the sword (BEQ skips the DECs), but UW shifts sword Y -= 2.
 * Link's +2 OW shift from vanilla is still active (Redux only patches
 * sword draw). Net: visual diff = offset - 2 in both OW and UW.
 *
 * RoomRom Genesis Link is drawn at link_y always (no shift). So the
 * sword bias must compensate to match the NES visual diff:
 *   Vanilla OW: offset - 2 → bias = -2
 *   Vanilla UW: offset      → bias =  0
 *   Redux   OW: offset - 2 → bias = -2
 *   Redux   UW: offset - 2 → bias = -2
 */
static void recompute_y_bias(void)
{
    if (s_redux) {
        s_uw_y_bias = (short)-2;
    } else {
        s_uw_y_bias = s_in_uw ? (short)0 : (short)-2;
    }
}

/* Redux ALttP-style 8-frame arc swing.
 *
 * Source: Zelda1-Redux/code/gameplay/sword_draw.asm wide_sword_xpos/ypos/
 * sprite/face/flip/flip_h16 tables. Each direction has 8 frames; the sword
 * arcs from one orthogonal side (windup) through diagonal to extended in
 * the facing direction.
 *
 * Direction order: NES tables use UP, DOWN, LEFT, RIGHT (reverse-direction
 * index). RoomRom link_face_t uses DOWN, UP, LEFT, RIGHT — tables below
 * are reordered to match.
 */
#define REDUX_TOTAL_FRAMES   8u
#define REDUX_BEAM_SPAWN     7u

/* Per-face per-frame sword X/Y offsets from Link's top-left. */
static const signed char redux_x[4][8] = {
    /* DOWN  */ { -9, -9, -5, -3, -2, -1,  0,  1 },
    /* UP    */ { 10, 10,  7,  6,  4,  2,  0, -1 },
    /* LEFT  */ {  1, -1, -5, -6, -7, -8,-10,-11 },
    /* RIGHT */ {  1,  3,  5,  6,  7,  8, 10, 11 },
};

static const signed char redux_y[4][8] = {
    /* DOWN  */ {  3,  5,  9, 10, 11, 12, 13, 13 },
    /* UP    */ {  2,  0, -5, -6, -7, -8, -9,-10 },
    /* LEFT  */ {-10,-10, -9, -8, -6, -4,  2,  3 },
    /* RIGHT */ {-10,-10, -8, -7, -5, -3,  2,  3 },
};

/* 0=vertical (8x16), 1=horizontal (16x16), 2=diagonal (16x16). */
static const unsigned char redux_sprite[4][8] = {
    /* DOWN  */ { 1, 1, 2, 2, 2, 2, 0, 0 },
    /* UP    */ { 1, 1, 2, 2, 2, 2, 0, 0 },
    /* LEFT  */ { 0, 0, 2, 2, 2, 2, 1, 1 },
    /* RIGHT */ { 0, 0, 2, 2, 2, 2, 1, 1 },
};

/* Genesis-side combined flip flags per frame. NES handles flips
 * differently for narrow (vertical/diagonal) vs wide (horizontal):
 *   - Narrow tile (in [$20,$62)): goes to Anim_WriteSpritePair directly.
 *     wide_sword_flip_h16 is NOT applied. hflip = wide_sword_flip & $40.
 *   - Wide tile (>= $7C): goes to Anim_WriteHorizontallyFlippableSpritePair
 *     which toggles hflip when h16=1. Genesis hflip on 16x16 sprite
 *     replicates this: hflip = (flip & $40 ? 1 : 0) XOR h16.
 * Tables below pre-compute the per-frame hflip with this distinction. */
static const unsigned char redux_hflip[4][8] = {
    /* DOWN  */ { 1, 1, 0, 0, 0, 0, 1, 1 },
    /* UP    */ { 0, 0, 1, 1, 1, 1, 0, 0 },
    /* LEFT  */ { 0, 0, 0, 0, 0, 1, 1, 1 },
    /* RIGHT */ { 0, 0, 1, 1, 1, 1, 0, 0 },
};

static const unsigned char redux_vflip[4][8] = {
    /* DOWN  */ { 0, 0, 1, 1, 1, 1, 1, 1 },
    /* UP    */ { 0, 0, 0, 0, 0, 0, 0, 0 },
    /* LEFT  */ { 0, 0, 0, 0, 0, 0, 0, 0 },
    /* RIGHT */ { 0, 0, 0, 0, 0, 0, 0, 0 },
};

/* Per-state, per-facing X offset. Index: [state-1][face].
 * face order: 0=DOWN, 1=UP, 2=LEFT, 3=RIGHT.
 * NES tables are in reverse direction order (up, down, left, right);
 * reordered here to match RoomRom's link_face_t enum. */
static const signed char sword_offset_x[4][4] = {
    /*               DOWN UP   LEFT  RIGHT */
    /* state 1 */ {  +1, -1,    0,   -8 },
    /* state 2 */ {  +1, -1,  -11,  +11 },
    /* state 3 */ {  +1, -1,   -7,   +7 },
    /* state 4 */ {  +1, -1,   -3,   +3 },
};

static const signed char sword_offset_y[4][4] = {
    /*               DOWN UP   LEFT  RIGHT */
    /* state 1 */ { -14, -9,  -11,  -11 },
    /* state 2 */ { +13,-10,   +3,   +3 },
    /* state 3 */ {  +9, -9,   +3,   +3 },
    /* state 4 */ {  +5, -1,   +3,   +3 },
};

void roomrom_combat_init(void)
{
    s_state = COMBAT_IDLE;
    s_frame = 0u;
    s_beam_active = 0u;
    roomrom_sprites_clear_sword();
    roomrom_sprites_clear_beam();
}

void roomrom_combat_try_swing(link_face_t face, short link_x, short link_y)
{
    (void)link_x; (void)link_y;
    if (s_state != COMBAT_IDLE) return;
    s_state = COMBAT_ACTIVE;
    s_frame = 0u;
    s_face  = face;
}

unsigned char roomrom_combat_link_locked(void)
{
    return s_state != COMBAT_IDLE;
}

/* Returns 1..5 for active states, 0 for idle. */
static unsigned char compute_state(unsigned char frame)
{
    unsigned char acc = 0u;
    acc = (unsigned char)(acc + COMBAT_STATE1_FRAMES);
    if (frame < acc) return 1u;
    acc = (unsigned char)(acc + COMBAT_STATE2_FRAMES);
    if (frame < acc) return 2u;
    acc = (unsigned char)(acc + COMBAT_STATE3_FRAMES);
    if (frame < acc) return 3u;
    acc = (unsigned char)(acc + COMBAT_STATE4_FRAMES);
    if (frame < acc) return 4u;
    return 5u;
}

/* Tick the beam: move it BEAM_SPEED_PX in s_beam_face direction, redraw,
 * and despawn if it leaves the playfield. Called every frame regardless
 * of sword swing state — beam outlives the swing. */
static void update_beam(void)
{
    if (!s_beam_active) {
        roomrom_sprites_clear_beam();
        return;
    }

    switch (s_beam_face) {
    case LINK_FACE_UP:    s_beam_y = (short)(s_beam_y - BEAM_SPEED_PX); break;
    case LINK_FACE_DOWN:  s_beam_y = (short)(s_beam_y + BEAM_SPEED_PX); break;
    case LINK_FACE_LEFT:  s_beam_x = (short)(s_beam_x - BEAM_SPEED_PX); break;
    case LINK_FACE_RIGHT: s_beam_x = (short)(s_beam_x + BEAM_SPEED_PX); break;
    }

    if (s_beam_x < BEAM_BOUND_X_MIN || s_beam_x > BEAM_BOUND_X_MAX
        || s_beam_y < BEAM_BOUND_Y_MIN || s_beam_y > BEAM_BOUND_Y_MAX) {
        s_beam_active = 0u;
        roomrom_sprites_clear_beam();
        return;
    }

    roomrom_sprites_set_beam(s_beam_x, s_beam_y, s_beam_face);
}

/* Spawn the beam at the sword TIP for the current facing. Earlier
 * versions reused the state-2 sword sprite offset (which is the sword
 * sprite top-left, not the blade tip). The dedicated beam_spawn_x/y
 * table places the beam at the actual blade tip + a small forward
 * gap so the beam looks like it pops off the sword. */
static void spawn_beam(short link_x, short link_y)
{
    unsigned char face_idx = (unsigned char)s_face;
    s_beam_face   = s_face;
    s_beam_x      = (short)(link_x + beam_spawn_x[face_idx]);
    s_beam_y      = (short)(link_y + beam_spawn_y[face_idx] + s_uw_y_bias);
    s_beam_active = 1u;
}

void roomrom_combat_update(short link_x, short link_y, link_face_t face)
{
    unsigned char st;
    short sx, sy;
    (void)face;

    if (s_state == COMBAT_IDLE) {
        roomrom_sprites_clear_sword();
        update_beam();
        return;
    }

    /* Redux 8-frame ALttP-style arc swing — separate state machine. */
    if (s_redux) {
        unsigned char fr = s_frame;
        unsigned char face_idx = (unsigned char)s_face;
        unsigned char sprite_type;
        short narrow_x_shift;
        if (fr >= REDUX_TOTAL_FRAMES) fr = (unsigned char)(REDUX_TOTAL_FRAMES - 1u);

        roomrom_sprites_set_link_attack_pose(link_x, link_y, s_face);

        sprite_type = redux_sprite[face_idx][fr];
        /* NES @Narrow path adds +4 to X to center the half-width sprite
         * within its 16x16 bounding box (Z_01.asm:5289). Applies to
         * vertical (sprite type 0) and diagonal (type 2). Wide
         * horizontal (type 1) is not centered — its 2 sprites already
         * span the full 16-pixel width. */
        narrow_x_shift = (sprite_type == 1u) ? (short)0 : (short)4;

        sx = (short)(link_x + redux_x[face_idx][fr] + narrow_x_shift);
        sy = (short)(link_y + redux_y[face_idx][fr] + s_uw_y_bias);

        switch (sprite_type) {
        case 0:
            roomrom_sprites_set_sword_vertical(sx, sy, redux_vflip[face_idx][fr]);
            break;
        case 1:
            roomrom_sprites_set_sword_horizontal(sx, sy, redux_hflip[face_idx][fr]);
            break;
        case 2:
            roomrom_sprites_set_sword_diagonal(sx, sy,
                                               redux_hflip[face_idx][fr],
                                               redux_vflip[face_idx][fr]);
            break;
        }

        if (s_frame == REDUX_BEAM_SPAWN && !s_beam_active) {
            spawn_beam(link_x, link_y);
        }
        update_beam();

        s_frame++;
        if (s_frame >= REDUX_TOTAL_FRAMES) {
            s_state = COMBAT_IDLE;
            s_frame = 0u;
            roomrom_sprites_clear_sword();
        }
        return;
    }

    st = compute_state(s_frame);

    /* Body pose: attack pose during states 1-4, walk pose at state 5
     * (set by main.c on the next frame once link_locked() returns 0). */
    if (st <= 4u) {
        roomrom_sprites_set_link_attack_pose(link_x, link_y, s_face);
    }

    if (st == 5u) {
        roomrom_sprites_clear_sword();
    } else {
        unsigned char tier = (unsigned char)(st - 1u);   /* 0..3 */
        unsigned char face_idx = (unsigned char)s_face;
        sx = (short)(link_x + sword_offset_x[tier][face_idx]);
        sy = (short)(link_y + sword_offset_y[tier][face_idx] + s_uw_y_bias);

        if (st == 1u) {
            /* Windup: sword raised UP (vertical, no flip). */
            roomrom_sprites_set_sword_vertical(sx, sy, 0u);
        } else {
            switch (s_face) {
            case LINK_FACE_DOWN:
                roomrom_sprites_set_sword_vertical(sx, sy, 1u);
                break;
            case LINK_FACE_UP:
                roomrom_sprites_set_sword_vertical(sx, sy, 0u);
                break;
            case LINK_FACE_LEFT:
                roomrom_sprites_set_sword_horizontal(sx, sy, 1u);
                break;
            case LINK_FACE_RIGHT:
                roomrom_sprites_set_sword_horizontal(sx, sy, 0u);
                break;
            }
        }
    }

    /* Spawn beam at start of state 3 (frame 13). RoomRom approximates
     * Z1's "full HP" check by always spawning (no HP system yet). */
    if (s_frame == BEAM_FRAME_SPAWN && !s_beam_active) {
        spawn_beam(link_x, link_y);
    }
    update_beam();

    s_frame++;
    if (s_frame >= COMBAT_TOTAL_FRAMES) {
        s_state = COMBAT_IDLE;
        s_frame = 0u;
        roomrom_sprites_clear_sword();
    }
}
