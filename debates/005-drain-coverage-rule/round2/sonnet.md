# SONNET ADVISOR — Round 2 Cross-Critique

All four r1 stamped RED on Phase 3. Convergence is real. Critique below
on the four divergences.

---

## 1. Audit structure

My r1 picked per-subsystem files (`docs/audit/drain/<subsystem>.md` +
INDEX). Codex picked single canonical doc per-phase. Gemini picked single
living manifest. Opus picked per-NES-source-file JSON + generated
per-phase per-subsystem tables.

**Concede to Opus.** His JSON-as-canonical / Markdown-as-view split is
strictly better than my Markdown-only approach. Why: the JSON is
machine-checkable (Gate 1 in his layered model), the Markdown views are
regenerable per-phase OR per-subsystem on demand. My per-subsystem files
would rot the moment we re-shuffle subsystems (they ARE our invention,
not NES's — Opus called this correctly). Codex's per-phase-only is
worse than mine: phases shift, NES asm doesn't.

**Defend partially against Codex's "planners think in phases":** true,
but planners ALSO grep by symbol when debugging. Generate both views
from one JSON source; everyone wins.

## 2. Verification depth

My r1: per-function diff (gate) + per-scenario oracle (smoke). Codex
matches me. Gemini went oracle-only. Opus went 3-gate layered
(per-function commit / per-RAM phase exit / per-scenario milestone).

**Concede to Opus.** His middle layer (per-RAM-cell trace tied to
existing parity oracle schema, commit `b476a2a5`) is the gap I missed.
My two-tier collapses state-machine drift into either "function looked
right" or "scenario broke later" — no middle signal. Opus's layered
gates plug the existing parity oracle infra into governance instead of
leaving it ad-hoc.

**Reject Gemini's oracle-only:** misses dead-code drift in functions
the oracle doesn't exercise. A per-function gate is cheap; skipping it
to "save time" guarantees silent rot in the long tail.

## 3. Task header format

Mine: 1-line. Codex: 1-line. Gemini: 1-line. Opus: 4-line
machine-checkable.

**Concede to Opus.** His 4-line (NES source / Drained C / Coverage /
Stance) is more verbose but every field is parseable by
`drain_coverage.py`. My 1-line is human-friendly but the tool would
need ad-hoc regex per field. Verbosity earns its keep when it gates
CI. The 80%-tool-fill mitigation Opus flagged (R2) defuses bureaucracy
fatigue.

## 4. Stance enum

Opus-only proposal: ADOPT / EXTEND / REPLACE / GREENFIELD with
evidence-required REPLACE.

**Adopt for everyone.** Binary REUSE/NEW collapses the EXTEND case
(drain logic correct, needs Genesis VDP shim swap) into either "lie
that we're reusing" or "lie that it's new." Phase 3 Task 3.4 IS
exactly EXTEND — drain logic right, `_ppu_*` shims wrong. The four-way
enum names that case correctly. Evidence-required REPLACE is the
critical safety: it stops "I think it's cleaner to rewrite" drift.

---

## Final stance: GREEN

Convergence package: master plan rule, `tools/audit/drain_coverage.py`,
memory `feedback_drain_primary_nes_secondary`, CLAUDE.md HARD section,
Phase 3 rewrite (Opus's Task 3.1 stays GREENFIELD as pure data
pipeline; 3.2-3.9 become ADOPT/EXTEND; 3.10 verification). My r1 RED
holds against the OLD plan. With the convergence package in place:
GREEN. Ship the four-line header, the JSON+Markdown audit, the
three-gate verification, and the four-way stance enum.
