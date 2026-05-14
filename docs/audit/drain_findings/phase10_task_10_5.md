# Phase 10 Task 10.5 — Verify Audio

- **NES source**: Cross-reference for parity probes — NES emulator
                  capture of `SongRequest` / `SoundFXRequest` per
                  mode + event.
- **Drained C**:  Verification harness, not runtime.
- **Coverage**:   PARTIAL — verification spec written; runtime
                  execution blocked on `task_10_3_audio_link_into_debug_md`
                  (audio driver not linked into Debug.md). Without
                  audio in the ROM, the audio-event-log probes have
                  nothing to inspect.
- **Stance**:     PARTIAL — verification harness spec ADOPT, runtime
                  pass deferred to Phase 11.

## Probe specification

| Probe                                    | Asserts                                                  |
|------------------------------------------|----------------------------------------------------------|
| `probe_fs_silent_or_explicit_song`       | `SongRequest` on FS entry matches Task 10.1.2 table.      |
| `probe_audio_event_log_music`            | Each gameplay mode transition logs the expected song id. |
| `probe_audio_event_log_sfx`              | Each Task 10.4 trigger site logs the expected SFX id.    |
| `probe_audio_vblank_budget`              | `audio_tick_vblank` cycle cost < 10% of VBlank budget.   |
| `probe_audio_low_health_option`          | Option flip changes low-health warning SFX dispatch.     |

5 probes specced. None implemented yet — gated on audio link.

## Manual checklist (post-link)

- Title screen song plays on boot.
- FS silent (or explicit Redux song; NOT title bleed).
- OW song plays on game start.
- UW per-level song plays on dungeon enter.
- Boss song plays on boss room enter.
- Death dirge on Mode 7 entry.
- 14 SFX events fire on their trigger sites.
- VBlank budget under cycle ceiling under dense gameplay.

## Deferral

Task 10.5 implementation work blocked on
`task_10_3_audio_link_into_debug_md`. The 5 probes + manual checklist
are queued; they require audio in the ROM image to execute.

## Status

CLOSE (with deferrals) — Task 10.5 verification spec locked. Probe
implementation + manual checklist pass tracked as Phase 11 deferral.
