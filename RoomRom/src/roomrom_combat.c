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

#define COMBAT_STATE1_FRAMES   5u
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
static unsigned char  s_beam_phase    = 0u;

/* -2 Y bias applied to sword + beam when Link is in a dungeon.
 * Default 0 (OW). Toggled via roomrom_combat_set_uw. */
static short s_uw_y_bias = 0;

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

void roomrom_combat_set_uw(unsigned char in_uw)
{
    s_uw_y_bias = in_uw ? (short)-2 : (short)0;
}

static unsigned char s_redux = 0u;
void roomrom_combat_set_redux(unsigned char redux)
{
    s_redux = redux ? 1u : 0u;
    (void)s_redux;  /* Reserved for v11+ — diagonal sword + ALttP arc swing. */
}

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

    {
        unsigned char vertical = (s_beam_face == LINK_FACE_UP
                               || s_beam_face == LINK_FACE_DOWN) ? 1u : 0u;
        roomrom_sprites_set_beam(s_beam_x, s_beam_y, vertical, s_beam_phase);
    }
    s_beam_phase = (unsigned char)((s_beam_phase + 1u) & 0x3u);
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
    s_beam_phase  = 0u;
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
