# Round 2 — OPUS critique + revised position

## Critiques

### CODEX R1
**Concrete flaw.** Helper scripts placed at `.claude/skills/primedirective/scripts/prime_*.py`. CI gates live in `tools/gates/` (e.g. `check_substrate_dual_rom.py`, `check_no_whatif.py`, `check_frontend_boundary.py`). Co-locating enforcement scripts inside the skill directory means `build.bat` and `tools/run_regression_matrix.py` cannot invoke them without special-casing `.claude/`. Codex itself says "rely on scripts and CI gates, not model memory" — but its placement makes CI participation impossible.

**What Codex got right that beats my R1.** Codex's freshness signal list is sharper than mine. Specifically: "phase-close evidence paths referenced by tracker no longer exist" and "active phase says complete but next phase is not active." These are existence + invariant checks, not just hash compares. My R1 listed hash compares + 24h age but missed the evidence-existence check and the active-phase-status invariant.

**Single change I adopt.** Lift evidence-existence check and "complete-without-successor-active" invariant into my `prime_status.py` freshness logic.

---

### GEMINI R1
**Concrete flaw.** Gemini's invocation protocol step 1 is "On every invocation, run `tools/audit/active_scope.py` to sync `.active_scope`." `active_scope.py` is a **mutating** generator, not a status reader. Calling it on every skill invocation:
- Races with any active build that reads `.active_scope`.
- Changes file mtimes, breaking `make`/incremental-build assumptions.
- Burns ~1–3 seconds on what should be a <100ms read.
- Means two parallel sessions that both invoke the skill will trample each other's writes.
The right rule is: read-only by default; only mutate on explicit `--refresh` or detected staleness.

Gemini also defines a `Hotfix` boolean state in the tracker. Boolean flags hide audit trails — once you set hotfix=true and save, you've lost the structured reason and target phase. Sonnet's `out_of_phase_tasks` array is strictly better.

**What Gemini got right that beats my R1.** The D1 4-line header is enforced as a **regex pre-flight check on `replace`/`write_file` calls into `src/game/`**. My R1 deferred header checking to `prime_guard.py` exclusively, run before edits. Gemini's framing as a tool-call interceptor is closer to mechanical guarantee — not just "the skill says check first" but "the check is wired into the actual write path." This is right *if* the runtime supports it; the skill itself can't intercept tool calls, but a pre-commit hook + `prime_guard.py --intent edit` invoked by the model contract gets us 90% of the way.

**Single change I adopt.** Make `prime_guard.py --intent edit` enforce the D1 4-line header check by inspecting the file content being written (not just the path). For `src/game/<subsystem>/*` writes, the script reads the file's first 8 lines, regex-matches the header pattern, exits 2 if absent.

---

### SONNET R1
**Concrete flaw.** Sonnet rejects a stored tracker entirely — "There is NO `tracker.json` that I update." Pure derivation has a real cost: **every status surface has to re-parse the master plan + drain_coverage.json + active_scope.md + git log, on every invocation**. Sonnet caps the derive-time cost by reading only the "Current Next Action" section and a bounded slice of git log, but multiple problems remain:
1. The master plan does not currently expose a stable "Current Next Action" anchor — Sonnet's design depends on a section that does not exist in `2026-05-02-title-roomrom-full-port-master-plan.md` today.
2. Multi-session work where Phase N closes mid-session leaves git log + active_scope.md briefly inconsistent; only a stored tracker can bridge that gap with explicit `last_refresh_at` and `stale_reasons[]`.
3. A pure-derivation skill cannot record decision artifacts — e.g., "user explicitly deferred gate step 6 for Phase 4 with reason X." Pure derivation throws those decisions away.

A stored tracker is not a hand-maintained tracker. The tracker is **always written by `prime_refresh.py`** and never by the model. Storage gives an `as-of` snapshot and a place for explicit deferrals; derivation gives ground truth. We need both.

**What Sonnet got right that beats my R1.** The threshold-trigger + keyword-trigger pattern is more disciplined than my R1's verbosity table. Specifically Sonnet's "Conversation start: NOT always-on, only on phase-relevant context" rule. My R1 had "Conversation start: none unless project-relevant first message" which is the same intent but Sonnet's enforcement via path-glob match on first tool call is sharper than my prose. And Sonnet correctly flags that frontmatter `description`-based path matching is *model-judgment, not mechanical* — my R1 wrote the description as if it were a runtime-enforced glob list. It isn't. The model reads the description and decides to invoke.

**Single change I adopt.** Reframe the description field. Stop pretending it's a path-glob trigger. Write it as semantic context: "use whenever you are about to edit project source, claim phase progress, run build.bat, close a phase, or hear keywords like 'phase close / blocking / next task'." The model invokes based on semantic relevance, not glob match. Real path-based gating happens in `prime_guard.py`, run before each Edit/Write the model performs.

---

## REVISED POSITION (delta from R1 only)

### Delta 1: Tracker is stored *and* derived (synthesis with Sonnet)

R1 had stored-only. Sonnet had derived-only. Both miss a piece. Revised:

- `docs/superpowers/prime_directive_tracker.json` is **canonical for explicit decisions**: `deferrals[]`, `out_of_phase_tasks[]`, `task_overrides[]`. Written only by `prime_refresh.py`.
- All other fields (active phase, gate status, drain coverage summary, blockers) are **derived** at refresh time from `active_scope.md`, `drain_coverage.json`, `git log`, master plan.
- `prime_status.py` reads the stored tracker and re-derives the derived fields fresh on every call. If derived fields disagree with stored fields, exit STALE and recommend `--refresh`.

This gets Sonnet's "no model-written state" guarantee while keeping a place for human/tool-recorded decisions that pure derivation cannot reconstruct.

### Delta 2: Reframe `description` field

R1 wrote a long path-glob list pretending it was a runtime trigger. Revised description (literal):

```
Sega Genesis Zelda 1 port — Prime Directive enforcer + master-plan progress tracker.
Invoke when about to edit project source, claim phase progress, run build.bat,
close a phase, or when the user says any of: "phase close / what's blocking /
next task / what phase / close phase / prime directive". Surfaces active phase,
task, gates, blockers, NES ground-truth requirements; refuses progress claims
without a FRESH tracker.
```

Path-based blocking happens in `prime_guard.py`, not via description-text matching.

### Delta 3: D1 header enforcement promoted to write-path check

R1 had `prime_guard.py --intent edit` run before edits. Revised: same script also reads the file content being written (when given `--check-content <path>`), regex-matches the 4-line header, exits 2 if missing for `src/game/**` paths. This makes header enforcement near-mechanical — a pre-commit hook can also call this script, so missing headers cannot land in main even if the model bypasses the skill.

### Delta 4: Enforcement scripts moved to `tools/`

R1 had scripts under `.claude/skills/primedirective/scripts/`. Revised:

```
tools/audit/primedirective/
  prime_status.py        read-only; multi-signal freshness; emits FRESH | STALE | BLOCKED
  prime_refresh.py       mutating; --refresh only; rebuilds tracker
  schema.json            JSON schema for tracker
tools/gates/
  prime_guard.py         pre-edit/build/close-phase guard; usable by hooks + CI
.claude/skills/primedirective/
  SKILL.md               behavioral contract only
  references/
    prime-directive.md
    phase-ladder.md
    hard-rules.md
    phase-close-gate.md
    targets.md
```

Skills = contract; tools = enforcement. CI sees `tools/gates/`; skills are model-only.

### Delta 5: Multi-signal freshness from Codex

R1 freshness was 4 signals. Revised adds two from Codex:
6. Each `evidence[]` path in tracker exists on disk.
7. Invariant check: any phase with `status: "complete"` requires the next phase entry to have `status: "active" | "complete"`. Otherwise the tracker is internally inconsistent.

### Delta 6: Out-of-phase surgical edit path (from Gemini → Sonnet)

R1 had no sanctioned path for fixing closed-phase code during active-phase work. Revised: tracker schema gains `out_of_phase_tasks[]` array. Each entry: `target_phase_id`, `reason`, `stance` (PARTIAL | REPLACE only — never GREENFIELD or ADOPT for closed-phase edits), `regression_matrix_run: <commit_sha>`, `recorded_at`. The skill detects out-of-phase edits via path glob against closed-phase scope and emits a special BRIEF: `[PD] OUT-OF-PHASE Ph{target} ← Ph{active} · stance {S}`. Regression matrix run is mandatory before next refresh succeeds.

---

## What did not change from R1
- Two-tier surfacing (BRIEF / FULL).
- Phase ladder lives in `references/`, not in SKILL.md body.
- `prime_refresh.py` is the only writer of the tracker.
- 11-step phase-close gate ordering.
- GREENFIELD-with-candidate-drain BLOCK logic matches `tools/audit/drain_coverage.py`.
- No hotfix boolean.
