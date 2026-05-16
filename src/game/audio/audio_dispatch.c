/* Plan v5b Tier-5 T5.5 — audio dispatcher implementation.
 *
 * NES source: reference/aldonunez/Z_07.asm UpdateMode dispatch +
 *             SongRequest writes per gamemode (multiple writers).
 * Drained C : NEW (this file).
 * Coverage  : NONE (NES is byte-cell SongRequest writer; we replace
 *             with gamemode-keyed dispatch — equivalent observable
 *             behavior, different mechanism).
 * Stance    : EXTEND.
 *
 * Design: poll-and-edge-fire. On tuple change, emit one music_play().
 * Same-tuple frames are silent. Idempotent on re-entry: audio_dispatch_reset
 * forces re-fire on the next tick.
 */

#include "audio_dispatch.h"
#include "platform_abi.h"          /* A4-pinned nes_ram pointer */

extern void music_play(unsigned char song_bitmap);

/* Scene constants — must mirror RoomRom/src/main.c scene_t. */
#define SCENE_OW    0u
#define SCENE_UW    1u
#define SCENE_CAVE  2u

/* GameMode IDs from NES Z_07. */
#define GM_DEMO              0x00u
#define GM_FILE_SELECT       0x01u
#define GM_REGISTER_NAME     0x02u
#define GM_ELIMINATION       0x03u
#define GM_LOAD_LEVEL        0x04u
#define GM_PLAY              0x05u
#define GM_GAME_OVER         0x06u
#define GM_DYING             0x07u
#define GM_CONTINUE_QUESTION 0x08u

/* Song bitmap IDs (audio_driver.asm change_song). */
#define SONG_TITLE      0x80u
#define SONG_UW         0x40u
#define SONG_OW         0x20u
#define SONG_ENDING     0x10u
#define SONG_ZELDA      0x06u   /* boss-kill / triforce reveal fanfare */
#define SONG_SILENCE    0x00u

/* Last-published tuple. Initialized to sentinel so first tick fires. */
#define TUPLE_SENTINEL 0xFFu
static unsigned char s_last_gm    = TUPLE_SENTINEL;
static unsigned char s_last_scene = TUPLE_SENTINEL;
static unsigned char s_last_song  = TUPLE_SENTINEL;

/* Resolve target song from (gamemode, scene).
 * Per docs/audit/audio_routing.md routing table. */
static unsigned char resolve_song(unsigned char gm, unsigned char scene)
{
    switch (gm) {
    case GM_DEMO:
        return SONG_TITLE;

    case GM_FILE_SELECT:
    case GM_REGISTER_NAME:
    case GM_ELIMINATION:
    case GM_CONTINUE_QUESTION:
        return SONG_SILENCE;

    case GM_LOAD_LEVEL:
        /* Transient — keep last song through the load. */
        return s_last_song;

    case GM_PLAY:
        if (scene == SCENE_UW)   return SONG_UW;
        if (scene == SCENE_CAVE) return SONG_UW;  /* placeholder: cave shares UW bank until ripped */
        return SONG_OW;

    case GM_GAME_OVER:
    case GM_DYING:
        /* Death dirge — audio_driver.asm has no dedicated game-over
         * phrase yet; play Zelda fanfare ($06) for now so the
         * transition is audible. Real death dirge is a song-blob
         * ripping follow-up. */
        return SONG_ZELDA;

    default:
        /* Unknown gamemode → no change. */
        return s_last_song;
    }
}

void audio_dispatch_tick(unsigned char scene, unsigned char room_id)
{
    unsigned char gm = nes_ram[0x0012u];
    (void)room_id;  /* reserved for future cave/boss room keying */

    if (gm == s_last_gm && scene == s_last_scene) {
        return;  /* tuple unchanged */
    }

    unsigned char song = resolve_song(gm, scene);
    if (song != s_last_song && song != TUPLE_SENTINEL) {
        music_play(song);
        s_last_song = song;
    }
    s_last_gm    = gm;
    s_last_scene = scene;
}

void audio_dispatch_reset(void)
{
    s_last_gm    = TUPLE_SENTINEL;
    s_last_scene = TUPLE_SENTINEL;
    s_last_song  = TUPLE_SENTINEL;
}
