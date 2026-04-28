/* src/fs_main.c — entry from boot.asm (proof ROM) or intro_handoff (main ROM v6).
 * v1: render static layout + Link sprites once at fs_init, hand off to phase loop.
 * v2: phase machine + input dispatch + cursor nav (FS_LOAD → FS_NAV).
 */
#include "fs_main.h"
#include "fs_render.h"
#include "fs_phase.h"
#include "fs_input.h"
#include "render_abi.h"

/* Music driver hooks — proof ROM links music_stub.c (no-op);
 * main ROM links the real audio driver. */
extern void music_play(unsigned char bit);

/* SONG_FS_BIT = 0 — original NES FS is silent; intro_to_file_select_trampoline
 * (genesis_shell.asm:681) clears SongRequest before Mode 1. Call kept so call
 * site exists if the design ever changes. */
#define SONG_FS_BIT  0x00

/* Generated assets — defined in src/gen/. */
extern const uint8_t  fs_bg_chr_full[];        /* 242 tiles × 32 bytes = 7744 bytes */
extern const uint8_t  fs_link_sprite_chr[];    /* 4 tiles × 32 bytes = 128 bytes */
extern const uint8_t  fs_heart_cursor_chr[];   /* 1 tile  × 32 bytes =  32 bytes */
extern const uint16_t fs_palettes[4][4];       /* 4 Genesis CRAM palettes × 4 colors */

#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)

static void wait_vblank(void) {
    while ( (VDP_CTRL_WORD & 0x0008));
    while (!(VDP_CTRL_WORD & 0x0008));
}

/* fs_init: upload CHR data and all palettes once at boot.
 *
 * CRAM layout (64 words = 4 palettes × 16 colors on Genesis):
 *   Palette 0 (CRAM byte 0)  : NES BG pal 0 (attr=0 cells: black bg, white text)
 *   Palette 1 (CRAM byte 32) : NES BG pal 1 (attr=1 cells: LIFE/heart icon area)
 *   Palette 2 (CRAM byte 64) : NES sprite pal 0 / Redux green-Link override (Link sprites)
 *   Palette 3 (CRAM byte 96) : NES sprite pal 3 (heart cursor sprite)
 *
 * v1.fix2: Link slot tinting (blue/red) deferred — Gen 4-pal budget spent on
 * BG 0/1 + Link + cursor. Multi-pal BG (LIFE column) is the visual gate.
 *
 * VRAM layout:
 *   Tile 0x00..0xF1  BG CHR full block (242 tiles)
 *   Tile 0x100..0x103  Link sprite CHR
 *   Tile 0x104        Heart cursor CHR
 */
static void fs_init(void) {
    /* 0a. Silence audio_driver music. Native intro_start_pressed bypasses the
     *     transpiled FS trampoline (which would have written SongRequest=0 at
     *     genesis_shell.asm:681) — so we silence here. Writing $80 to NES RAM
     *     $0604 (Tune0 silence request) triggers audio_driver's attract-mode-exit
     *     hook on the next VBlank: music_tick reads it, calls music_silence,
     *     and clears all sound state. Matches Redux-spec silent FS. */
    {
        volatile unsigned char *song_request    = (volatile unsigned char *)0x00FF0600;
        volatile unsigned char *tune0_silence   = (volatile unsigned char *)0x00FF0604;
        *song_request  = 0x00;
        *tune0_silence = 0x80;
    }

    /* 0. Force plane size H32xV32. Proof ROM boot.asm sets this directly, but
     *    main ROM intro_handoff sets V64 before calling fs_main; our nametable
     *    writes assume V32 stride (32 cells × 2 bytes = 64-byte rows). */
    render_mode_set_v32();

    /* 1. Upload full BG CHR block to VRAM tile 0x00 (242 tiles × 32 bytes = 7744 bytes). */
    render_chr_upload((unsigned short)(0x00u * 32u), fs_bg_chr_full,
                      (unsigned short)(242u * 32u));

    /* 1a. Zero VRAM tile 0 — both Plane A and Plane B nametables default to cells
     *     that reference tile 0; if tile 0 holds NES font glyph "0" (which it does
     *     in fs_bg_chr_full), the screen background fills with "0" digits. Forcing
     *     tile 0 to all-transparent makes cleared cells render as the BG color. */
    render_vram_write_zero_tile(0x0000u);

    /* 2. Upload Link sprite CHR to VRAM tile 0x100 (above BG block, no collision). */
    render_chr_upload((unsigned short)(0x100u * 32u), fs_link_sprite_chr,
                      (unsigned short)(4u * 32u));

    /* 3. Upload heart cursor CHR to VRAM tile 0x104 (32 bytes). */
    render_chr_upload((unsigned short)(0x104u * 32u), fs_heart_cursor_chr,
                      (unsigned short)(1u * 32u));

    /* 4. Load all 4 CRAM palettes (4 colors each at CRAM byte offsets 0/32/64/96).
     *    render_cram_open_write_byte takes raw byte address; caller streams words
     *    after with render_vram_write_words (reuses the open data port). */
    render_cram_open_write_byte( 0u);
    render_vram_write_words(&fs_palettes[0][0], 4u);  /* pal 0: BG attr=0 */
    render_cram_open_write_byte(32u);
    render_vram_write_words(&fs_palettes[1][0], 4u);  /* pal 1: BG attr=1 (LIFE) */
    render_cram_open_write_byte(64u);
    render_vram_write_words(&fs_palettes[2][0], 4u);  /* pal 2: Link sprite */
    render_cram_open_write_byte(96u);
    render_vram_write_words(&fs_palettes[3][0], 4u);  /* pal 3: heart cursor */

    /* 5. Phase + input init (v2). */
    fs_input_init();
    fs_phase_init();

    /* 6. Music: silent on FS per NES original; call site preserved. */
    music_play(SONG_FS_BIT);
}

/* Cursor row indices (matches fs_render_cursor table + fs_phase contract). */
#define FS_ROW_PLAYERS  5u
#define FS_ROW_OPTIONS  6u

static void fs_input_dispatch(uint8_t edge) {
    if (s_fs_phase != FS_NAV) return;
    if ((edge & FS_BTN_UP) && s_fs_cursor > 0u) {
        s_fs_cursor--;
        fs_render_cursor(s_fs_cursor);
    }
    if ((edge & FS_BTN_DOWN) && s_fs_cursor < FS_CURSOR_MAX) {
        s_fs_cursor++;
        fs_render_cursor(s_fs_cursor);
    }
    /* PLAYERS row L/R cycle 1..4 with wrap. */
    if (s_fs_cursor == FS_ROW_PLAYERS) {
        if (edge & FS_BTN_LEFT) {
            s_fs_players_value = (s_fs_players_value <= 1u) ? 4u : (uint8_t)(s_fs_players_value - 1u);
            fs_render_players_row(s_fs_players_value);
        }
        if (edge & FS_BTN_RIGHT) {
            s_fs_players_value = (s_fs_players_value >= 4u) ? 1u : (uint8_t)(s_fs_players_value + 1u);
            fs_render_players_row(s_fs_players_value);
        }
    }
    /* v6.handoff (gated): A on slot row should hand off to transpiled
     * gameplay / register-name. Trampoline + fs_handoff_to_transpiled are
     * wired and the trampoline runs (probe CC, vblank_mode=01), but the
     * transpiled FS state machine ends up stuck at GameSubmode=6 with display
     * off after the swap. Suspected: FrontendStartReleaseGate semantics or
     * leftover PPU register state from native fs_main is poisoning the
     * transpiled InitMode1 sub-phase chain. Trigger disabled until rooted —
     * the trampoline + fs_handoff.c stay compiled so re-enabling is one line.
     */
#if 0
    /* GATED: A press on slot row hangs transpiled FS even with
     * IsSaveSlotActive[0]=1 seeded — InitMode1_Sub6 stalls (display off,
     * GameSubmode=06). Root cause not yet found. Re-enable when fixed. */
    if (s_fs_cursor <= 2u && (edge & (FS_BTN_A | FS_BTN_START))) {
        s_fs_phase = FS_HANDOFF;
    }
#endif
}

void fs_main(void) {
    fs_init();
    render_display_enable(1);
    for (;;) {
        wait_vblank();
        fs_phase_step();
        fs_input_dispatch(fs_input_pressed());
    }
}
