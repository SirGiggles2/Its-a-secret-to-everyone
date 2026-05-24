/* cave_fade.c — NES Link-descend cave-entry animation.
 *
 * NES Z_05.asm:1400 InitMode10 + Z_05.asm:2308 UpdateMode10Stairs_Full.
 * 64-frame descend (16 px × 4 frames/px). After descend, instant scene
 * swap to cave. Exit is instant (snap) — user-trigger via C+START chord.
 */

#include "cave_fade.h"
#include "cave_palette.h"
#include "ow_render.h"
#include "render_abi.h"  /* render_vram_read_word, render_set_plane_a_word */

/* Genesis Plane A VRAM base + cell stride. Per src/sgdk_adapter
 * config (RoomRom PR-2 H64xV32 layout): plane A at $C000, 64 cells
 * wide, 2 bytes per cell. Plane is 32 rows tall (PR-2 trimmed half
 * of V64 to free CHR space). */
#define CAVE_FADE_PLANE_A_BASE   0xC000u
#define CAVE_FADE_PLANE_COLS     64u
#define CAVE_FADE_PLANE_ROWS     32u
#define CAVE_FADE_HUD_ROW_OFFSET 7u  /* matches ROOMROM_ROOM_FIRST_ROW */

static void mark_cell_hi_prio_xy(unsigned char col, unsigned char row)
{
    if (col >= CAVE_FADE_PLANE_COLS || row >= CAVE_FADE_PLANE_ROWS) {
        return;
    }
    unsigned short vram_addr = (unsigned short)(
        CAVE_FADE_PLANE_A_BASE +
        ((unsigned short)row * CAVE_FADE_PLANE_COLS + (unsigned short)col) * 2u);
    unsigned short cur = render_vram_read_word(vram_addr);
    if ((cur & 0x8000u) != 0u) {
        return;  /* already high prio */
    }
    render_set_plane_a_word(col, row, (unsigned short)(cur | 0x8000u));
}

/* NES InitMode10 + UpdateMode10Stairs: 16 pixels down, 1 px every 4
 * frames = 64 frames total. */
#define CAVE_DESCEND_PIXELS   16u
#define CAVE_DESCEND_FRAMES_PER_PX 4u
#define CAVE_DESCEND_TOTAL_FRAMES \
    (CAVE_DESCEND_PIXELS * CAVE_DESCEND_FRAMES_PER_PX)

static cave_fade_phase_t     s_phase          = CAVE_FADE_IDLE;
static unsigned char         s_frame_counter  = 0u;  /* 0..63 for descend */
static unsigned char         s_step_idx       = 0u;  /* 0..15 px steps emitted */
static cave_id_t             s_pending_cid    = 0u;
static unsigned char         s_return_room_id = 0u;
static cave_fade_callbacks_t s_cb             = { 0, 0, 0 };

void cave_fade_set_callbacks(const cave_fade_callbacks_t *cb)
{
    if (cb != 0) {
        s_cb = *cb;
    }
}

void cave_fade_begin_enter(cave_id_t cid)
{
    if (s_phase != CAVE_FADE_IDLE) {
        return;
    }
    s_pending_cid   = cid;
    s_frame_counter = 0u;
    s_step_idx      = 0u;
    s_phase         = CAVE_FADE_LINK_DESCEND;
}

void cave_fade_begin_exit(unsigned char return_room_id)
{
    if (s_phase != CAVE_FADE_IDLE) {
        return;
    }
    s_return_room_id = return_room_id;
    s_frame_counter  = 0u;
    s_step_idx       = 0u;
    s_phase          = CAVE_FADE_LINK_ASCEND;  /* descend-mirror exit anim */
}

unsigned char cave_fade_is_active(void)
{
    return (unsigned char)(s_phase != CAVE_FADE_IDLE);
}

cave_fade_phase_t cave_fade_phase_current(void)
{
    return s_phase;
}

unsigned char cave_fade_descend_step_idx(void)
{
    return (s_phase == CAVE_FADE_LINK_DESCEND) ? s_step_idx : 0u;
}

void cave_fade_mark_arch_hi_prio(unsigned char link_tile_col,
                                 unsigned char link_tile_row)
{
    /* Per APPENDIX plan revision (2026-05-22 systematic-debug rounds
     * 1-4 review): NES PutLinkBehindBackground (Z_05.asm:2326-2331)
     * sets behind-BG bit on BOTH Sprites+74 + Sprites+78 = ENTIRE
     * Link sprite (slots $12/$13 in 8x16 mode = 2 OAM entries = 16x16
     * Link). My previous "upper-only" assumption was wrong.
     *
     * Genesis architecture: single low-prio Link sprite + wide BG-prio
     * stamp. Tile content (CHR color-0 pixels) determines what shows
     * through: cells with non-color-0 pixels cover Link; cells with
     * color-0 (transparent) pixels let Link show through.
     *
     * Stamp range rows -2..+4: covers Link's full descend Y range
     * [$4D, $5D] (plane rows 16-20) + 2 buffer rows above for the
     * arch/ground that should cover Link's head. Math (Y >> 3) + 7
     * HUD offset assumes Plane A vscroll = 0 (confirmed via probe).
     * Cols -1..+1 covers Link's 16-px-wide sprite + 1 col buffer. */
    for (signed char dr = -2; dr <= 4; ++dr) {
        for (signed char dc = -1; dc <= 1; ++dc) {
            signed int row = (signed int)link_tile_row + (signed int)dr;
            signed int col = (signed int)link_tile_col + (signed int)dc;
            if (row < 0 || row >= (signed int)CAVE_FADE_PLANE_ROWS) continue;
            if (col < 0 || col >= (signed int)CAVE_FADE_PLANE_COLS) continue;
            mark_cell_hi_prio_xy((unsigned char)col, (unsigned char)row);
        }
    }
}

void cave_fade_tick(void)
{
    switch (s_phase) {
    case CAVE_FADE_LINK_DESCEND: {
        /* NES: every 4th frame INC ObjY. We count frames; when
         * (frame_counter & 3) == 3 we are about to roll into a multiple
         * of 4 — emit one descend step + bump idx. After 16 steps, swap. */
        s_frame_counter = (unsigned char)(s_frame_counter + 1u);
        if ((s_frame_counter & 0x03u) == 0u) {
            if (s_cb.on_descend_step != 0) {
                s_cb.on_descend_step(s_step_idx);
            }
            s_step_idx = (unsigned char)(s_step_idx + 1u);
            if (s_step_idx >= CAVE_DESCEND_PIXELS) {
                s_phase = CAVE_FADE_SWAP_ENTRY;
            }
        }
        break;
    }

    case CAVE_FADE_SWAP_ENTRY:
        /* Instant: cave state init + cave plane fill + cave palette
         * stamp. Mirrors the three calls that pre-anim lived inline at
         * RoomRom/src/main.c. Owner callback then handles Link
         * reposition (cave-bottom) + scene flip. */
        (void)cave_init(s_pending_cid);
        roomrom_cave_room_render_fill_plane_a((unsigned char)s_pending_cid);
        roomrom_ow_room_render_publish_play_area_tiles();
        cave_palette_apply();
        if (s_cb.on_swap_entry != 0) {
            s_cb.on_swap_entry(s_pending_cid);
        }
        s_phase = CAVE_FADE_IDLE;
        break;

    case CAVE_FADE_LINK_ASCEND: {
        /* Mirror of LINK_DESCEND: Y -= 1 every 4 frames for 16 steps.
         * NES Z_05.asm:1603+ uses same Mode 10 path for cave-exit,
         * just with StairsTargetY = ObjY - $10 (= UP 16 px). After
         * 16 steps, SWAP_EXIT swaps plane back to OW. */
        s_frame_counter = (unsigned char)(s_frame_counter + 1u);
        if ((s_frame_counter & 0x03u) == 0u) {
            if (s_cb.on_ascend_step != 0) {
                s_cb.on_ascend_step(s_step_idx);
            }
            s_step_idx = (unsigned char)(s_step_idx + 1u);
            if (s_step_idx >= CAVE_DESCEND_PIXELS) {
                s_phase = CAVE_FADE_SWAP_EXIT;
            }
        }
        break;
    }

    case CAVE_FADE_SWAP_EXIT:
        /* Instant: cave teardown + OW plane refill + OW palette
         * restore. Owner callback handles Link reposition + HUD reset
         * + scene flip. */
        cave_exit();
        roomrom_ow_room_render_fill_plane_a(s_return_room_id);
        roomrom_ow_room_render_publish_play_area_tiles();
        roomrom_ow_room_render_load_palette(s_return_room_id);
        if (s_cb.on_swap_exit != 0) {
            s_cb.on_swap_exit();
        }
        s_phase = CAVE_FADE_IDLE;
        break;

    case CAVE_FADE_IDLE:
    default:
        break;
    }
}
