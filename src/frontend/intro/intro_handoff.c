/* src/intro_handoff.c
 *
 * C side of Start press handoff. Performs VDP cleanup so the screen
 * is in a known state (display off, planes blank, vscroll=0) before
 * fs_main takes over. fs_main sets V32 internally then renders the
 * native File Select.
 *
 * v6 minimal-promote: replaces the transpiled FS trampoline call with
 * direct fs_main entry. fs_main never returns; back-handoff to transpiled
 * gameplay is added in v6.2 (FS_HANDOFF phase + ASM trampoline).
 *
 * S1.F4: vdp_* calls replaced with render_* API.
 */
#include "intro_handoff.h"
#include "render_abi.h"
#include "fs_main.h"
#include "platform_abi.h"

static void clear_plane(unsigned short plane_base) {
    unsigned short zero_row[32];
    unsigned short i;
    for (i = 0; i < 32; i++) zero_row[i] = 0;
    for (i = 0; i < 32; i++) {
        render_plane_write_row(plane_base, i, zero_row, 32u);
    }
}

/* Frames for the CRAM fade-to-black on Start press. 16 frames at 60Hz =
 * about 0.27s -- snappier than the title-loop's 230-frame fade but slow
 * enough to read as an intentional transition. */
#define HANDOFF_FADE_STEPS  16u

void intro_start_pressed(void) {
    nes_ram[0x07F2] = 0xAA;   /* probe: handoff begun */

    /* Fire LA "Get Item" jingle ($08 -> SongRequest mailbox). audio_driver's
     * VBlank tick consumes $FF0600 on the next vbi: m_song_req=$08 -> change_song
     * -> m_song=$08 (replaces title $80) -> tick_sq1 plays the ItemTaken slot,
     * which has been repurposed with the 7-byte LA reduction (see
     * tools/midi_to_zelda_song.py). Jingle is single-phrase: sq1 terminates with
     * $00, song_ended path runs music_silence, and FS sits silent thereafter.
     * No silence write needed. */
    *((volatile unsigned char *)0x00FF0600) = 0x08;

    /* Fade the currently-visible scene (title / fadeout / black hold /
     * story / items) to black over HANDOFF_FADE_STEPS frames before
     * blanking the planes + SAT. Snapshot reads live CRAM so this works
     * from any phase. */
    render_cram_fade_capture();
    for (unsigned char s = 1u; s <= HANDOFF_FADE_STEPS; s++) {
        render_wait_vblank();
        render_cram_fade_apply(s, HANDOFF_FADE_STEPS);
    }

    render_display_enable(0);
    clear_plane(0xC000);
    clear_plane(0xE000);
    render_sat_clear();
    render_vscroll_set(0);

    /* Native File Select. fs_main sets its own VDP plane-size + CHR + palettes
     * + sprite table + display_on. Never returns. */
    fs_main();
}
