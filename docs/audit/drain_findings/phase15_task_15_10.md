# Phase 15 Task 15.10 — Audio Hardware Optimization

- **NES source**: NES APU runs on CPU per-frame tick. Genesis Z80
                  + YM2612 + PSG runs independently of 68K. Audio
                  driver must never block rendering DMAs.
- **Drained C**:  `src/audio_driver.asm` (1337 LOC) + Z80 PCM
                  driver via `src/sgdk_adapter/audio_adapter.c`
                  XGM bringup.
- **Coverage**:   PARTIAL — audio substrate exists (Phase 10
                  policies LOCKED); Z80 driver runs independent of
                  68K by design (memory `project_midi_substrate_works`
                  confirms). Per-priority SFX gating + cosmetic-vs-
                  gameplay channel arbitration NOT shipped.
- **Stance**:     PARTIAL — driver layer ADOPT; per-priority SFX
                  + dense-combat measurement deferred. Gated on
                  Phase 10 deferral
                  `task_10_3_audio_link_into_debug_md` — audio not
                  yet linked into Debug.md, so live optimization
                  pass cannot run.

## Deferred items

| Item                                  | Blocked on                                |
|---------------------------------------|-------------------------------------------|
| Music-tick non-blocking verification  | Phase 10 audio link                       |
| SFX batch + priority                  | Phase 10 audio link                       |
| Low-health warning cost check         | Phase 9.4 unwired consumer + Phase 10     |
| Dense combat audio measurement        | Phase 10 audio link                       |
| Boss audio measurement                | Phase 10 audio link                       |
| Title/story music measurement         | Phase 10 audio link                       |
| Z80/audio survives scene transitions  | Phase 10 audio link                       |

## Status

CLOSE (with Phase 10 audio-link gate) — Task 15.10 substrate ADOPT;
optimization pass deferred end-to-end on
`task_10_3_audio_link_into_debug_md`.
