# Audio Migration Trigger (Rule SGDK-4)

**Custom driver is the default.** Migrating a subsystem (or flipping the whole driver) to SGDK XGM2 requires ADR approval, triggered by ANY 2 of the following firing within a rolling 90-day window.

## Triggers

| # | Signal | Threshold | Tool | Cadence |
|---|--------|-----------|------|---------|
| 1 | `audio_tick` CPU usage | > 10% of frame budget | `tools/cycle_envelope.py` against the regression matrix | nightly + on every audio commit |
| 2 | Parity-oracle song failure | survives 1 full debug cycle (one fix attempt; failure persists across the next `parity_oracle_diff.py` run) | `tools/parity_oracle_diff.py` | nightly CI |
| 3 | Driver footprint | > 8 KB combined `.bss + .data` | `tools/check_audio_footprint.py` parsing `builds/Title.lst` symbol map | weekly |
| 4 | Unfixable parity bugs | ≥ 3 issues with `audio-parity` label, open >30 days, accumulated within the rolling 90d window | manual sweep | first of each month |

## Procedure when 2 triggers fire

1. Open an ADR (`docs/adrs/NNN-audio-migration-<subsystem>.md`) capturing which 2 triggers fired, with measurement evidence.
2. Owner reviews + signs off (Rule SGDK-5 governs forks; SGDK-4 governs in-tree audio path migration).
3. Migration is **per-subsystem** or **whole-driver** as named in the ADR — no silent partial flips.
4. Migration is a **one-way door**. Once a subsystem is on XGM2, the custom-driver code path for that subsystem is removed in the same release. No long-lived dual paths.
5. Parity oracle baselines re-recorded against the new path in the same commit as the migration.

## What does NOT trigger migration

- "XGM2 is more LLM-friendly" — true (Gemini's r1/r2 argument), but does not justify discarding NES parity. LLM ergonomics is a Prime Directive #6 consideration, subordinated to NES accuracy (#4) and Genesis-native impl (#5).
- A single parity bug — must survive 1 debug cycle before counting toward trigger #2.
- A single trigger firing — needs 2 within 90d.
- A single track having pressure — does not generalize to "migrate the driver". Trigger #4 requires accumulated label evidence.

## Why custom remains the default

- Custom Z80 driver is the spec carrier for NES audio behavior: frame counter cadence, sweep, length, envelope.
- Per project memory `project_midi_substrate_works`, the F3-era audit confirmed the custom driver works end-to-end.
- XGM2 cannot express NES-APU-shaped semantics without a translation layer that re-introduces every bug it claims to remove (Opus's r2 reproducibility argument).
- Audio migration is a one-way door (ADR-gated). We don't unlock it without measured failure.
