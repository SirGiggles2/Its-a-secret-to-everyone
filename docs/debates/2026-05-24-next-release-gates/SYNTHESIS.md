# Debate Synthesis — Next Release Gates for FINAL TRY v1.0

**Date:** 2026-05-24
**Topic:** Smallest, highest-leverage release-gate work that must land
before FINAL TRY v1.0 ships.
**Participants:** Codex CLI, Gemini CLI, Sonnet Agent, Opus (orchestrator)
**Rounds:** 2 (opening + critique)

---

## Final ranking (post-Round-2 convergence)

### #1 — `phase17_from_scratch_build_gate` — **REPRODUCIBILITY GATE**

**Vote:** 4/4 in top 2 after Round 2 (Codex #1, Sonnet #1, Opus #1, Gemini #2).
This is the single strongest cross-AI convergence in the debate.

**What it is:** Get `tools/builder/from_scratch_gate.py` from scaffold
to working — fresh clone, pinned SGDK install, byte-identical
`builds/Debug.md` reproduction on a clean Win10 VM. SHA-256 manifest
locked into `tools/builder/release_gate.py`.

**Why it's #1:** Every other gate's evidence (harness GREEN, cross-emu
pass, audio assertion) is privately verifiable only on Jake's machine
until this lands. Codex's framing won the debate: reproducibility is
a *precondition* for evidence to count as public, not a parallel item.

**Effort:** 1 wall-clock day (Codex, Sonnet, Opus all converge).

**Blast radius if skipped:** v1.0 zip can silently carry stale or
banned generated files; no third party can prove `Debug.md` came from
the tree; legal exposure on distribution.

---

### #2 — `phase14_dungeon_harness_population` — **GAMEPLAY PROOF GATE**

**Vote:** 3/4 keep top 3 (Codex, Gemini, Opus). Sonnet folded into #1
baseline gen but agrees the rows must be GREEN.

**What it is:** Convert `tools/dungeon_harness/manifest.json` from 18
SKIP rows to 18 GREEN — 9 dungeons × Q1 + Q2 — via scripted BizHawk
replay using the `tools/dungeon_harness/probes/dungeon_template.lua`
template.

**Why it's #2:** The actual product proof. All Phase 5–9 close-gate
`screenshot_state_evidence` fields are spot probes, not end-to-end
clears. This converts "tracker says complete" into "every dungeon
demonstrably finishes."

**Effort:** 2 wall-clock days (Codex 1-2, Opus 2-3, Gemini 12h
underestimates).

**Blast radius if skipped:** Day-1 user reports of unwinnable rooms,
softlocks, missing keys — exactly the bugs the 14 unverified
out-of-phase REPLACE entries are most likely to have introduced.

---

### #3 — `phase16_cross_emulator_matrix` — **HARDWARE-SMOKE PROXY**

**Vote:** 3/4 keep top 3 in some round (Sonnet, Opus, Gemini R1).
Codex omitted both rounds (debate's biggest dissent).

**What it is:** Headless boot + 60-second capture on BlastEm, Gens-KMod,
and Exodus. Diff CRAM/VRAM snapshots vs BizHawk baseline. Wire into
`tools/builder/release_gate.py` as a gate.

**Why it's #3:** Only available substitute for `phase16_hardware_tests`
(DEFERRED_HARDWARE — no physical console). BizHawk hides Genesis edge
cases: DMA-during-active-display, Z80 bus arbitration, FIFO underflow.

**Effort:** 1–1.5 wall-clock days.

**Blast radius if skipped:** Day-1 forum reports of "doesn't boot on
BlastEm / Mega EverDrive / real hardware" within 48 hours of release.

---

## Notable split: audio link (Phase 10.3 / 10.5)

**Gemini #1, Sonnet #2, Codex #3, Opus deferred** to v1.0.1.

The split: Gemini and Sonnet treat silent music as product-identity
failure ("silent Zelda is a tech demo"). Opus argues a reproducible
silent v1.0 ships and a v1.0.1-audio follows in days; an
unreproducible audible v1.0 cannot.

**Synthesis verdict:** Audio is **deferred from the top-3 release
gates** but should ship in v1.0 *if* MIDI-FS dependency clears in
< 1 day during gate-1 work. If MIDI-FS is still blocked after the
from-scratch gate lands, v1.0 ships silent + v1.0.1 follows within
2 weeks. This honors both Codex's reproducibility-precedes-everything
position and Gemini/Sonnet's product-identity concern.

---

## Rejected / deferred to post-v1.0

- **Phase 9.4 unwired option consumers** — cosmetic accessibility polish; v1.0.1+.
- **Phase 11 live-capture pass standalone** — folds into #1 baseline gen.
- **Phase 17 builder UX shell + release docs** — last-mile polish; gate on #1+#2+#3 GREEN first.
- **14 out-of-phase REPLACE backlog standalone** — folds into #2 harness verification (any breakage surfaces there).

---

## Critical path

```
DAY 1:   Phase 17 from-scratch build gate
DAY 2-3: Phase 14 dungeon harness population (9 dungeons × Q1+Q2)
DAY 4:   Phase 16 cross-emulator matrix
DAY 5:   Phase 17 release_gate.py orchestrator wiring + first end-to-end run
```

**Total:** ~5 wall-clock days for a defensible v1.0 release candidate.

---

## Round-by-round artifacts

- `brief.md` — original question + state snapshot
- `round1_codex.md`, `round1_gemini.md`, `round1_sonnet.md`, `round1_opus.md`
- `round2_brief.md` — critique brief
- `round2_codex.md`, `round2_gemini.md`, `round2_sonnet.md`, `round2_opus.md`
- `SYNTHESIS.md` (this file)
