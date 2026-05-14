# Phase 10 Task 10.1 — Lock Driver Policy

- **NES source**: NES APU contract (Pulse 1/2, Triangle, Noise, DPCM)
                  per the Z_07 audio dispatch + `Variables.inc`
                  `SongRequest` / `SoundFXRequest` cells.
- **Drained C**:  None for the driver itself. `src/audio_driver.asm`
                  is the Genesis-native APU emulator: YM2612 + PSG
                  mapping with Sonic 2 EHZ FM patches. Adapter wrapper
                  at `src/sgdk_adapter/audio_adapter.c` exposes the
                  public ABI in `src/abi/audio_abi.h`.
- **Coverage**:   FULL (substrate + decision) — driver, manifest,
                  songs, sfx PCM, adapter wrapper all shipped earlier
                  phases. This task ratifies the decision and bans
                  silent driver swaps.
- **Stance**:     ADOPT — keep custom driver. NES-parity priority +
                  working-substrate priority + adapter contract
                  stability win over XGM2 ergonomics. Rule SGDK-4
                  governs any future migration (ADR + 2-of-4 trigger).

## Decision

Locked in `docs/audit/audio_driver_decision.md` (Task 10.1). Custom
`src/audio_driver.asm` is the default; SGDK XGM2 swap is gated by
Rule SGDK-4 trigger criteria documented at
`docs/audio_migration_trigger.md`.

## Adapter contract (stable)

```c
void audio_xgm_init(void);                          /* Z80 XGM PCM bringup */
void audio_music_play(unsigned char song);          /* music_play forwarder */
void audio_sfx_play(unsigned char sfx);             /* XGM PCM SFX dispatcher */
void audio_tick_vblank(void);                       /* music_tick forwarder */
```

Public header: `src/abi/audio_abi.h`.

## Status

CLOSE — Task 10.1 driver policy LOCKED.
