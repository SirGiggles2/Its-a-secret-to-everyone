#include <genesis.h>
#ifdef RAM
#undef RAM
#endif
#include "platform_abi.h"
#include "audio_abi.h"
#include "intro_phase.h"
#include "render_abi.h"
#include "roomrom_debug_runtime.h"
#include "roomrom_main_state.h"   /* roomrom_main_set_quest */

#define A4_EXPECTED 0x00FF8000UL
#define PROBE_BASE ((volatile u8 *) 0x00FF7000UL)
#define ABS_RAM ((volatile u8 *) 0x00FF8000UL)
#define VDP_CTRL_WORD (*(volatile u16 *) 0x00C00004UL)
#define PASS_FRAME_LIMIT 180U
#define CHORD_DEBUG    (BUTTON_A | BUTTON_B | BUTTON_C)  /* boot quest 1 */
#define CHORD_DEBUG_Q2 (BUTTON_X | BUTTON_Y | BUTTON_Z)  /* boot quest 2 */

/* 2026-05-19 — MODE button at title enters debug tile-grid scene for
 * atlas byte-diff against the custom NES test ROM. Pattern mirrors
 * CHORD_DEBUG handling below; press is edge-triggered. */
#include "../game/debug/debug_tilegrid.h"
#include "../game/items/debug_unlock_all.h"  /* P6.1 */

/* File Select. Declared here rather than including fs_main.h /
 * fs_handoff.h: those headers pull in the proof-ROM stdint typedefs,
 * which collide with SGDK's types.h (conflicting types for u32/s32/s8)
 * in this TU. The three symbols are stable and plain. */
extern void fs_enter(void);
extern void fs_tick(void);
extern unsigned char g_fs_handoff_requested;
extern unsigned char g_fs_handoff_slot;

/* Persistent NES-format saves (T-100). src/state is on the include path. */
#include "save_game.h"
#include "../game/world/bg_palette.h"   /* refresh_link_color */
extern void room_patch_level_palette_link_color(void);   /* room_dispatch.c */

/* The room (and its palette) loads in roomrom_debug_enter, before the
 * save or the debug unlock sets InvRing. NES InitMode3_Sub1 patches
 * Link's color into the level palette after the File Select; do the same
 * once the profile is in RAM (t121_ring1). */
static void link_color_after_profile(void)
{
    room_patch_level_palette_link_color();
    roomrom_bg_palette_refresh_link_color();
}

/* Debug/probe sentinel block (platform_abi.h DBG_SENTINEL, T-109). */
volatile unsigned char g_debug_sentinel[32];

typedef enum {
    COMBINED_STATE_TITLE = 0,
    COMBINED_STATE_ROOMROM = 1,
    COMBINED_STATE_FS = 2
} combined_state_t;

extern u32 debug_get_a4(void);

static combined_state_t s_state;
static u16 s_frame;
static u16 s_fail_stage;
static u16 s_prev_joy;
static u32 s_last_a4;

static void probe_write_u16(u16 offset, u16 value)
{
    PROBE_BASE[offset + 0U] = (u8) (value >> 8);
    PROBE_BASE[offset + 1U] = (u8) value;
}

static void probe_write_u32(u16 offset, u32 value)
{
    PROBE_BASE[offset + 0U] = (u8) (value >> 24);
    PROBE_BASE[offset + 1U] = (u8) (value >> 16);
    PROBE_BASE[offset + 2U] = (u8) (value >> 8);
    PROBE_BASE[offset + 3U] = (u8) value;
}

static void probe_publish(void)
{
    PROBE_BASE[0] = 0xA4U;
    PROBE_BASE[1] = 0x4AU;
    probe_write_u16(2U, s_frame);
    probe_write_u16(4U, s_fail_stage);
    probe_write_u32(6U, s_last_a4);
    PROBE_BASE[10] = ABS_RAM[0x0012U];
    PROBE_BASE[11] = ABS_RAM[0x0013U];
    PROBE_BASE[12] = s_fail_stage ? 0xEEU : ((s_frame >= PASS_FRAME_LIMIT) ? 1U : 0U);
    PROBE_BASE[13] = (u8) s_state;
    PROBE_BASE[14] = roomrom_debug_get_scene();
    PROBE_BASE[15] = roomrom_debug_get_room_id();
    probe_write_u16(16U, (u16)roomrom_debug_get_link_x());
    probe_write_u16(18U, (u16)roomrom_debug_get_link_y());
}

static void probe_fail(u16 stage)
{
    if (!s_fail_stage)
    {
        s_fail_stage = stage;
    }
}

static void probe_check(u16 stage)
{
    s_last_a4 = debug_get_a4();
    if (s_last_a4 != A4_EXPECTED)
    {
        probe_fail(stage);
        probe_publish();
        return;
    }

    RAM(0x0012) = 0xCDU;
    RAM(0x0013) = (u8) stage;
    if ((ABS_RAM[0x0012U] != 0xCDU) || (ABS_RAM[0x0013U] != (u8) stage))
    {
        probe_fail((u16) (stage | 0x8000U));
    }

    probe_publish();
}

/* Front-end video layout (title and File Select). */
static void frontend_video_layout(void)
{
    /* Match the native title boot layout from genesis_shell.asm. */
    VDP_CTRL_WORD = 0x8134u; /* display off, VBlank IRQ, DMA, M5 */
    VDP_CTRL_WORD = 0x8230u; /* Plane A @ $C000 */
    VDP_CTRL_WORD = 0x832Cu; /* Window @ $B000 */
    VDP_CTRL_WORD = 0x8407u; /* Plane B @ $E000 */
    VDP_CTRL_WORD = 0x857Cu; /* SAT @ $F800 */
    VDP_CTRL_WORD = 0x8B00u; /* full-screen scroll */
    VDP_CTRL_WORD = 0x8C00u; /* H32, no interlace, no shadow/highlight */
    VDP_CTRL_WORD = 0x8D3Fu; /* H-scroll @ $FC00 */
    VDP_CTRL_WORD = 0x8F02u; /* word auto-increment */
    render_mode_set_v32();
    render_window_v_set(0u);
}

static void debug_enter_title(void)
{
    s_state = COMBINED_STATE_TITLE;
    s_prev_joy = 0u;
    frontend_video_layout();

    DBG_SENTINEL(0x1Fu) = 0xA1u;
    DBG_SENTINEL(0x11u) = 0u;
    DBG_SENTINEL(0x12u) = 0u;
    intro_phase_init();
    intro_phase_step();
}

static void debug_poll_title(void)
{
    u16 joy;
    u16 was_chord;
    u16 is_chord;
    u16 was_q2;
    u16 is_q2;

    probe_check(2U);
    SYS_doVBlankProcess();
    ++s_frame;
    probe_check(3U);
    DBG_SENTINEL(0x11u) = (u8) s_frame;
    intro_phase_step();

    joy = JOY_readJoypad(JOY_1);
    was_chord = (u16)(s_prev_joy & CHORD_DEBUG);
    is_chord = (u16)(joy & CHORD_DEBUG);
    was_q2 = (u16)(s_prev_joy & CHORD_DEBUG_Q2);
    is_q2 = (u16)(joy & CHORD_DEBUG_Q2);

    /* C+START chord edge-press -> debug tile-grid scene (never returns).
     * Both buttons are 3-button readable so works in BizHawk default
     * controller config without needing 6-button mode. MODE button also
     * triggers (held as alt for 6-button pads). */
    {
        unsigned short trig_mask = BUTTON_MODE;
        unsigned short cs_chord  = BUTTON_C | BUTTON_START;
        unsigned char  cs_now    = ((joy & cs_chord) == cs_chord) ? 1 : 0;
        unsigned char  cs_prev   = ((s_prev_joy & cs_chord) == cs_chord) ? 1 : 0;
        unsigned char  mode_edge = ((joy & trig_mask) && !(s_prev_joy & trig_mask)) ? 1 : 0;
        if ((cs_now && !cs_prev) || mode_edge)
        {
            s_prev_joy = joy;
            debug_tilegrid_main();
            /* unreachable */
        }
    }
    /* START alone (edge) -> File Select. Checked AFTER the C+START chord
     * above so the tile-grid shortcut still wins when C is held; that
     * chord returns via debug_tilegrid_main() and never reaches here. */
    {
        unsigned char start_now  = (joy & BUTTON_START) ? 1u : 0u;
        unsigned char start_prev = (s_prev_joy & BUTTON_START) ? 1u : 0u;
        unsigned char c_held     = (joy & BUTTON_C) ? 1u : 0u;
        if (start_now && !start_prev && !c_held)
        {
            s_prev_joy = joy;
            s_state = COMBINED_STATE_FS;
            /* NES title Start runs UpdateMode0Demo_Sub1/Sub2: validate each
             * save file A and fill the slot info File Select shows. */
            save_game_boot();
            fs_enter();
            return;
        }
    }

    s_prev_joy = joy;

    {
        unsigned char abc_edge = (is_chord == CHORD_DEBUG && was_chord != CHORD_DEBUG) ? 1u : 0u;
        unsigned char xyz_edge = (is_q2 == CHORD_DEBUG_Q2 && was_q2 != CHORD_DEBUG_Q2) ? 1u : 0u;
    if (abc_edge || xyz_edge)
    {
        /* X+Y+Z (6-button pad) boots into 2nd quest; A+B+C boots 1st. */
        roomrom_main_set_quest(xyz_edge ? 2u : 1u);
        g_debug_session = 1u;   /* T-090: debug chord entry */
        s_state = COMBINED_STATE_ROOMROM;
        probe_publish();
        roomrom_debug_enter();
        /* Debug entry bypasses File Select's Q1/Q2 card. NES secret gates
         * read QuestNumbers[CurSaveSlot], not s_current_quest. Mirror the
         * selected debug quest there after roomrom_debug_enter resets RAM. */
        if (RAM(0x0016u) < 3u)
            RAM(0x062Du + RAM(0x0016u)) = xyz_edge ? 1u : 0u;

        /* P6.1 (2026-05-19): Debug.md gameplay-entry unlocks every item
         * so the inventory subscreen renders a fully-populated view
         * without playing through Z1 to collect items. Must run AFTER
         * roomrom_debug_enter() because that init writes Items bitfield
         * + HeartValues default values that would otherwise overwrite us.
         * Release builds (when they exist) should NOT call this. */
        debug_unlock_all_items();
        link_color_after_profile();
        /* Phase 10.3 audio per-event wiring (gameplay-mode entry).
         * Boot lands in SCENE_UW per RoomRom/src/main.c:96
         * (s_scene = SCENE_UW). Per docs/audit/audio_routing.md, UW
         * = per-level dungeon song. Boot-room defaults to L1Q1; play
         * the L1Q1 dungeon song. Real per-level dispatch lands when
         * roomrom_debug_enter exposes its level/quest selection. */
        audio_music_play(0x40);  /* NES Z1 SongRequest bit 6 = dungeon song */
    }
    }
}

extern void audio_vblank_hook_install(void);
extern void music_play(unsigned char song_bitmap);

/* 2026-05-15 perf fix: per-frame probe_check(4U) was unconditional,
 * eating ~7-12% of frame budget on accessor calls + 20 byte writes.
 * Gate behind enemy_loop_probe_is_armed() so default gameplay skips
 * the heartbeat. Probes that need it write the arm magic first. */
extern unsigned char enemy_loop_probe_is_armed(void);

/* T-168: SGDK's heap runs from the end of .bss to MEMORY_HIGH ($FFF600),
 * straight through the NES RAM mirror at $FF8000 (A4 base). A temporary
 * heap buffer that reached past $FF8000 overwrote NES cells: the gameplay
 * init_video font reload unpacked into [$FF7480, $FF8080) once .bss grew
 * ~130 bytes, writing GameMode $12 and CurSaveSlot $16 (write watch:
 * unpack PC $770, A1 = $FF8013). Wall the mirror off: allocate the free
 * space below $FF8000 as a filler, then one block from $FF8000 to the heap
 * top (kept), then free the filler. Later allocations stay below $FF8000
 * or fail (NULL) instead of corrupting NES RAM. MEM_allocAt cannot do
 * this (it only honors the address when the current free block is too
 * small). */
static void heap_wall_nes_mirror(void)
{
    /* Block = 2-byte header + data. The wall's header must sit below the
     * mirror ($FF7FFE; NES $0000 is game scratch), so the filler covers
     * [free start, $FF7FFE) and the wall's data starts at $FF8000. SGDK
     * heap pointers read $E0FFxxxx: compare the low 24 bits. */
    /* The probe stays allocated until the end: a freed block is not
     * reused by the next MEM_alloc, which would shift the filler (and put
     * the wall's header on NES $0002, measured). The probe block is
     * [start, start + 4). */
    unsigned char *probe = (unsigned char *)MEM_alloc(2);
    unsigned long start;
    void *filler = 0;
    void *wall;
    if (probe == 0) return;
    start = ((unsigned long)probe - 2ul) & 0xFFFFFFul;
    if (start + 4ul + 2ul < 0xFF7FFEul)
        filler = MEM_alloc((u16)(0xFF7FFEul - (start + 4ul) - 2ul));
    wall = MEM_alloc((u16)(MEM_getLargestFreeBlock() - 2u));
    if (filler) MEM_free(filler);
    MEM_free(probe);
    /* Probe-visible result (masked stack-page cell NES $01F8): 1 = the
     * wall sits at $FF8000. */
    *(volatile unsigned char *)0xFF81F8ul =
        (unsigned char)((((unsigned long)wall & 0xFFFFFFul) == 0xFF8000ul) ? 1u : 0u);
}

int debug_main_after_a4(bool hardReset)
{
    (void) hardReset;

    heap_wall_nes_mirror();

    /* T-125: pad 2 only ever needs the NES buttons (NES controller 2 has
     * A/B/Start/Select/D-pad); the 6-button read runs every VBlank. */
    JOY_setSupport(PORT_2, JOY_SUPPORT_3BTN);

    /* Phase 10.3 audio link, VBlank tick slice: register music_tick
     * as VBlank callback so the audio driver advances notes once per
     * frame. Must run before any music_play() request. */
    audio_vblank_hook_install();

    /* Phase 10.3 audio link, XGM SFX path: load XGM Z80 driver and
     * register the 7 NES DMC samples (IDs 64..70) for SFX playback.
     * audio_driver.asm@dmc_trigger calls audio_sfx_play -> XGM
     * sample channels. FM/PSG music continues on M68K via music_tick
     * (XGM Z80 driver only owns sample channels by default). */
    audio_xgm_init();

    probe_check(1U);
    debug_enter_title();

    /* Phase 10.3 audio link, per-event music_play slice (title song).
     * NES Z1 title song = bit 7 set on SongRequest ($80). Memory
     * project_midi_substrate_works confirms the driver plays when
     * poked with $80. With the VBlank hook installed above, the driver
     * advances notes each frame. */
    music_play(0x80);

    while (TRUE)
    {
        if (s_state == COMBINED_STATE_TITLE)
        {
            debug_poll_title();
        }
        else if (s_state == COMBINED_STATE_FS)
        {
            SYS_doVBlankProcess();
            ++s_frame;
            fs_tick();

            /* The File Select sets this when the player commits to a
             * slot; CurSaveSlot ($0016) is already seeded by then. This
             * is the real New Game / Continue entry, so unlike the A+B+C
             * debug chord it does NOT unlock every item — the player
             * starts with whatever the chosen slot actually holds. */
            if (g_fs_handoff_requested)
            {
                g_fs_handoff_requested = 0u;

                /* fs_handoff_to_transpiled tears the screen down for the
                 * jump it used to make: display off, planes cleared, mode
                 * forced to V64. The gameplay runtime expects the V32
                 * layout debug_enter_title establishes, and nothing in
                 * roomrom_debug_enter re-enables display — so without
                 * this the handoff produced a black screen with no room
                 * loaded. Restore the same video state the title path
                 * hands to gameplay. */
                render_mode_set_v32();
                render_window_v_set(0u);
                render_display_enable(1);

                /* NES QuestNumbers: 0 = first quest, 1 = second. Needed
                 * before entry because level data installs per quest. */
                {
                    unsigned char slot = g_fs_handoff_slot;
                    unsigned char q2 = (save_game_slot_active(slot) &&
                                        save_game_slot_quest(slot)) ? 1u : 0u;
                    roomrom_main_set_quest(q2 ? 2u : 1u);
                }
                g_debug_session = 0u;   /* T-090: real game, no debug */
                s_state = COMBINED_STATE_ROOMROM;
                probe_publish();
                roomrom_debug_enter();

                /* Continue vs New Game. roomrom_debug_enter seeds the
                 * default profile, so the restore has to run AFTER it or
                 * the defaults would overwrite the save — same ordering
                 * reason debug_unlock_all_items runs after enter on the
                 * A+B+C path.
                 *
                 * The slot info was validated at title Start (NES file A
                 * markers + checksum); an inactive slot is a New Game.
                 * CurSaveSlot is set either way so a later save lands in
                 * the chosen slot. */
                RAM(0x0016u) = g_fs_handoff_slot;   /* CurSaveSlot */
                (void) save_game_load_slot(g_fs_handoff_slot);
                link_color_after_profile();

                audio_music_play(0x01);  /* SONG_OW — FS exits to overworld */
            }
        }
        else
        {
            roomrom_debug_tick();
            ++s_frame;
            /* T-149: NES UpdateModeDSave_Sub2 sets GameMode 0 submode 1:
             * UpdateMode0Demo_Sub1 validates the save files, then the menu
             * runs. Genesis: the same validation, then its File Select. */
            if (RAM(0x0012u) == 0x00u && RAM(0x0013u) == 0x01u)
            {
                s_state = COMBINED_STATE_FS;
                s_prev_joy = 0u;
                render_cram_defer(0u);   /* the File Select writes CRAM itself */
                frontend_video_layout();
                render_display_enable(1);
                save_game_boot();
                fs_enter();
                music_play(0x80);   /* FS shares the title song */
                continue;
            }
            if (enemy_loop_probe_is_armed())
            {
                probe_check(4U);
            }
        }
    }

    return 0;
}
