# Round 2 — Sonnet

## Strongest opposing point

**Codex's #1 (`round1_codex.md`): reproducibility-first.** I dismissed Phase 17 as "decorative" because baselines are placeholder — but Codex correctly inverts the dependency. Until `from_scratch_gate.py` proves the tree produces `Debug.md` deterministically, every other gate (my Phase 10 sweep, Phase 11 captures) is asserting on an artifact nobody else can rebuild. "Jake's machine built something" is the *real* trust collapse, worse than my "tracker is lying" framing. A reproducible silent ROM beats an unreproducible audible one — Codex is right that this is foundational, not packaging theater. 1 day effort vs my 5-day path makes it the cheapest credibility unlock.

## Three critiques

- **Codex:** Omitting Phase 16 cross-emulator entirely is wrong — a reproducible build that only boots on BizHawk still ships a field-bug grenade on day one.
- **Gemini:** "~8 hours" for audio link + MIDI-FS dependency resolution is fantasy; `project_midi_fs_integration` shows the substrate is blocked on native FS rewrite, not a TU link.
- **Opus:** Deferring audio to v1.0.1 abandons `task_10_5_audio_probes_runtime` evidence — you can't claim "v1.0 GREEN" with unasserted Z80 behavior, regardless of whether users hear music.

## Updated top 3

1. **Phase 17 from-scratch build gate** (was #2-equivalent) — Codex convinced me reproducibility precedes audit. 1 day.
2. **Phase 10 audio link + REPLACE sweep** (was #1) — still mandatory; demoted only because (1) gates the artifact (1) audits. 2-3 days.
3. **Phase 16 cross-emulator matrix** (unchanged) — non-negotiable hardware proxy. 1.5 days.

Dropped: Phase 11 live-capture pass — folds into Phase 17 baseline generation naturally.

— Sonnet — Round 2
