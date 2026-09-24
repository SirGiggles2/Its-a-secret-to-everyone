# Opus — Round 2

## 1. Strongest opposing point

**Codex's reproducibility-first framing** (round1_codex.md #1). I had
from-scratch build gate at #3; Codex correctly inverts the priority:
without a reproducible Debug.md, every other piece of evidence —
harness GREEN, cross-emulator pass, audio assertion — is unverifiable
by any third party. The gate is a *precondition* for the others to
count as public evidence, not a parallel item. Sonnet's Round 1
"trust in the artifact" framing leads to the same conclusion; Codex
just stated it sharper.

## 2. Three critiques

- **Codex** — Omitting `phase16_cross_emulator_matrix` is the biggest
  miss; "Jake's machine" reproducibility against BizHawk-only doesn't
  protect against day-1 forum reports of BlastEm crashes that the
  reproducible build can't fix without another release cycle.
- **Gemini** — The 8-hour audio link estimate is fiction; `task_10_3`
  explicitly notes MIDI-FS dep open + audio TUs not linked + probe
  infrastructure all gated together, and brief evidence text on Phase
  10 close confirms this is the deferral with the most blocking
  context, not a half-day chore.
- **Sonnet** — Bundling "Phase 10 audio + 14 REPLACE backlog flush
  through one regression sweep" as a single 2-3 day item conflates
  audio link work (substrate edit) with retroactive evidence backfill
  (matrix runs); they should be separate gates with separate failure
  modes.

## 3. Updated top 3

1. **`phase17_from_scratch_build_gate`** — conceded to Codex; this is
   the precondition for every other gate's evidence to be public.
2. **`phase14_dungeon_harness_population`** — was my #1; demoted because
   #1 makes #2 meaningful, not the reverse. Still the actual product
   proof.
3. **`phase16_cross_emulator_matrix`** — unchanged; BlastEm + Gens-KMod
   pass is the only hardware-smoke substitute available.

Audio link stays deferred to v1.0.1 — disagrees with 3/4, but a
silent-music v1.0 is shippable; a non-reproducible v1.0 isn't.

— Opus — Round 2
