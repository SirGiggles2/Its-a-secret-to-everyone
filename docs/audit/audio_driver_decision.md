# Audio Driver Decision (Task 10.1)

**Status:** LOCKED — custom driver retained as default.
**Date:** 2026-05-14
**Authority:** Master plan Task 10.1 + memory `project_midi_substrate_works`.

## Decision

Keep `src/audio_driver.asm` (YM2612 + PSG NES-APU emulator) as the
default audio driver for all Debug.md / future shipping ROMs.

Do NOT block on an SGDK XGM / XGM2 migration. Audio data extraction
(Task 10.2) proceeds with the existing custom driver intact.

## Rationale

1. **Working substrate.** Memory `project_midi_substrate_works`
   confirms F3-era audit found `audio_driver.asm` `change_song` +
   `tick_sq1` work end-to-end when `SongRequest = $80` is poked. The
   pre-S1 silence was missing-init, not driver rot.
2. **NES parity model.** The driver is a faithful APU emulator —
   pulse 1/2 / triangle / noise / DPCM map onto YM2612 + PSG with
   Sonic 2 EHZ patches. NES sequence data feeds the driver directly,
   matching the Prime Directive (NES Zelda 1 = behavioral spec).
3. **Adapter contract is stable.** `src/sgdk_adapter/audio_adapter.c`
   already wraps `music_play` / `music_tick` behind
   `audio_music_play` / `audio_tick_vblank` per
   `docs/audit/audio_split_plan.md`. The contract holds whether the
   driver swaps to XGM2 later or not.
4. **Defer migration trigger.** Per Rule SGDK-4 the XGM2 swap
   triggers on (a) Phase 15 measurements showing custom driver over
   cycle budget, (b) maintenance failure, or (c) fidelity-blocking
   bug. None present today.

## Adapter API (stable contract)

```c
void audio_music_play(unsigned char song_id);   /* wraps music_play / change_song */
void audio_sfx_play(unsigned char sfx_id);       /* wraps sfx path */
void audio_tick_vblank(void);                    /* wraps music_tick */
```

Frontend / gameplay code calls only these three. The driver beneath
can swap without touching call sites.

## Revisit triggers (SGDK-4)

Revisit XGM / XGM2 migration ONLY if Phase 15 (Genesis-Specific
Optimization) measurements show:

- VBlank cycle budget exceeded under dense audio + gameplay load.
- Driver maintenance burden blocks bugfix velocity.
- A specific fidelity gap appears (e.g. envelope precision, sample
  rate ceiling, DPCM coverage gap).

Until then: custom driver wins on parity + working-substrate priority.

## Build integration plan

`src/audio_driver.asm` + `src/sgdk_adapter/audio_adapter.c` +
`data/audio/songs.c` + `data/audio/sfx*.c` + `data/audio/pcm_samples.c`
land in `tools/debug/build_debug.py` as a follow-up wiring step
(Task 10.3 / 10.4 implementation). Today they live as substrate but
are NOT yet linked into `Debug.md`; Title-frontend builds linked them
prior to the dual-ROM retire — restoring the link is the integration
work behind 10.3 / 10.4.

## Status

CLOSE — Task 10.1 driver policy locked. No active blocker; integration
wiring tracked under Tasks 10.3 / 10.4.
