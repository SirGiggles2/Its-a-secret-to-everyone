# OPUS ADVISOR — Round 2 cross-critique

**Lens**: architecture-first (drift detection, source-of-truth hierarchy, machine-checkable invariants)

All four r1 panelists landed on RED. Convergence on the *what* (drain-first, NES wins ties) is total. The divergences are about the *governance shape* — which is exactly where architecture lives. Defending mine, conceding where peers are stronger.

---

## 1. Audit structure — defend per-NES-source-file

Codex picked per-phase. Gemini picked single living manifest. Sonnet picked per-subsystem. I picked per-NES-source-file.

Codex is wrong: phases are *our* invention and re-shuffle (S0→S13 already supersedes T1→T14 per memory `project_what_if`). Anchoring the audit to a mutable axis guarantees rewrites. Sonnet's per-subsystem is closer — `src/game/<subsystem>/` is stable — but subsystem boundaries are still our taxonomy, not Nintendo's. Gemini's "single living manifest" is correct in spirit but doesn't pick a row axis, which is the actual question.

The Prime Directive says **NES accuracy is the spec**. The audit's row axis must be the spec axis: NES symbols in `reference/aldonunez/*.asm`. Phase, subsystem, and drained-C path are all *columns* on those rows. Concession to Sonnet: emit per-subsystem `.md` views from the JSON for navigation. Single source, multiple projections.

## 2. Verification depth — defend three-gate layered

Codex picked per-scenario oracle only. Gemini picked logic parity oracle. Sonnet picked per-function diff as gate + scenario as smoke test. I picked layered: function-diff → RAM-cell trace → scenario oracle.

Sonnet is closest and correctly identifies that per-function alone misses integration bugs while per-scenario alone misses dead-code drift. But two layers leaves a gap: state-machine drift in the middle (RAM cells diverge mid-flow even when function semantics match and end-state scenario passes). The parity oracle schema (`b476a2a5`) and reference capture harness (`bba19d31`) already exist — gate 2 is *free infrastructure we're not using*. Three gates aligned to commit/phase/milestone cadence is the right cost curve. Holding firm.

## 3. Task header format — defend four-line machine-checkable

Codex's one-line `Drain coverage: X | NES verify: Y | Status: Z` is dense but loses the Stance enum and the Coverage breakdown. Gemini's `[DRAIN: X] | [SPEC: Y]` loses both Status and Stance. Sonnet's one-liner with a parenthetical functions list is human-readable but hard to grep with `^- \*\*Coverage\*\*:` precision.

Four lines exists for one reason: each line has a distinct enum the tool validates independently. Coverage and Stance are *different* invariants — Coverage describes the world (what exists), Stance describes the decision (what you'll do about it). Collapsing them lets a planner write `Coverage: NONE | Stance: ADOPT`, which is incoherent but visually plausible. The four-line shape is bureaucracy in service of a real invariant. Holding firm.

## 4. Stance enum — defend, with adoption recommendation

I'm the only one with ADOPT/EXTEND/REPLACE/GREENFIELD. Binary (drain-or-greenfield) is what Sonnet and Gemini implicitly assumed. Binary is wrong: it conflates "use as-is" with "use as base, swap shims" with "drain wrong, rewrite". These have different evidence requirements (none / shim-list / RAM-trace pointer). Without the enum, every non-greenfield task collapses to "use the drain somehow" and the evidence gate evaporates. **Recommend panel adopt the four-stance enum** — it's the load-bearing piece that makes the header more than decoration.

---

## Convergence

GREEN on all five: master-plan rule, `tools/audit/drain_coverage.py`, memory entry `feedback_drain_primary_nes_secondary`, `CLAUDE.md` HARD section, Phase 3 rewrite (~6 of 10 tasks flip from GREENFIELD to ADOPT/EXTEND).

## Final stance

**RED on current Phase 3, GREEN on the four-line + four-stance + three-gate governance.** Adopt my Stance enum, Sonnet's per-subsystem `.md` views generated from my per-NES-file JSON, and ship.
