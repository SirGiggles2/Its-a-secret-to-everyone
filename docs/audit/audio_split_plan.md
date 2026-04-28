<!-- docs/audit/audio_split_plan.md -->
# Audio Responsibility Split — S1 Wrapper Plan

Spec Section 4.6's audio adapter API (`audio_music_play`, `audio_sfx_play`,
`audio_tick_vblank`) wraps the existing audio path in S1 without invasive
driver changes. SGDK's XGM2 driver is the long-term replacement (S11), but
S1 keeps the existing `audio_driver.asm` behind the adapter so frontend
music continues to play unchanged through the SGDK pivot.

## Existing audio path (current FINAL TRY)

- `src/audio_driver.asm` — standalone driver (Z80 / FM glue), classified as
  `platform_asm` per `file_classification.md`.
- `src/genesis_shell.asm` VBlank handler calls `music_tick` each frame.
- Frontend (`src/fs_main.c`, `src/intro_main.c`) calls `music_play(song_id)`.

## S1 wrapper (no driver changes)

`src/sgdk_adapter/audio_adapter.c` exposes:

```c
void audio_music_play(u8 song_id) { music_play(song_id); }
void audio_sfx_play(u8 sfx_id)    { music_play(sfx_id); /* or sfx_play if exists */ }
void audio_tick_vblank(void)      { music_tick(); }
```

The VBlank ISR (now SGDK's `SYS_doVBlankProcess` or its callback) calls
`audio_tick_vblank` instead of `music_tick` directly. Frontend C code calls
`audio_music_play` instead of `music_play`. The legacy entrypoints stay
linkable but become wrapper-only.

## S11 driver swap

S11 (audio final integration) replaces the wrapper bodies with XGM2 calls:

```c
void audio_music_play(u8 song_id) { XGM2_play(/* lookup table */); }
void audio_sfx_play(u8 sfx_id)    { XGM2_playPCMEx(/* lookup table */); }
void audio_tick_vblank(void)      { /* SGDK ticks XGM2 itself */ }
```

API is stable; driver beneath swaps. Game code never edits.

## Risk

Low. Adapter is ~10 lines of C; XGM2 swap is bounded to S11 with the
adapter API as the contract.
