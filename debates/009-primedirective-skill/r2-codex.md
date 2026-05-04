# CODEX Round 2

## Gemini

**Concrete flaw:** Gemini’s `docs/audit/master_plan_tracker.json` is a new hand-maintained canonical tracker with booleans like `REGRESSION_MATRIX_PASS`. That is too lossy for the 11-step close gate: it records pass/fail, but not required evidence paths, command outputs, schema diffs, probe artifacts, or commit SHAs. It also puts `active_phase: 1.5` as a number; phase IDs should be strings because `1.5` is an inserted phase label, not arithmetic state.

**Thing Gemini got right:** The “Task Lock” idea is stronger than my R1. I surfaced active task and next action, but Gemini explicitly says not to work outside `current_task` unless promoted. That is a useful guard against agents wandering into attractive adjacent work.

**Change I would make to my R1:** Add a `scope_lock` field to the tracker and guard:

```json
"scope_lock": {
  "active_task_only": true,
  "allowed_escape_hatches": ["blocking_fix", "phase_close_gate", "user_interrupt"],
  "requires_tracker_note": true
}
```

`prime_guard.py` should warn on phase-relevant edits outside the active task unless the reason is recorded.

## Sonnet

**Concrete flaw:** Sonnet rejects a tracker file entirely and derives state from `active_scope.md`, `drain_coverage.json`, git log grep, and a “Current Next Action” section. That cannot reliably satisfy the requirement to constantly surface gates passed/pending, blockers, and phase-close evidence. Git log grep like `phase.*close` is not a state machine, and `active_scope.md` is an active-scope pointer, not a complete phase ledger.

**Thing Sonnet got right:** The abbreviated path-trigger status is better than my R1’s implied full status on every invocation. A one-line `[PD] Phase … task … blocking …` keeps the skill usable during normal edit loops.

**Change I would make to my R1:** Split status output into mandatory brief and optional full. Every activation still surfaces phase/task/gates/blockers/next action, but path-triggered auto-load uses one compact line unless stale or blocked.

## Opus

**Concrete flaw:** Opus says `prime_guard.py` is mandatory before any Edit/Write tool call and gives binary exit codes, but a Claude Code skill cannot truly intercept tool calls unless the workflow is backed by integrated wrappers, pre-commit hooks, or CI gates. As written, it overstates enforcement. The skill can instruct and the scripts can verify; actual blocking needs tool integration outside SKILL.md.

**Thing Opus got right:** Moving helper scripts under `tools/audit/primedirective/` beats my R1 layout. Scripts under `.claude/skills/.../scripts` are skill-local and less likely to be reused by CI, regression workflows, or non-Claude agents. Enforcement code belongs in `tools/`; the skill should be the invocation contract.

**Change I would make to my R1:** Move `prime_status.py`, `prime_refresh.py`, `prime_guard.py`, and `schema.json` to:

```text
tools/audit/primedirective/
```

Leave `.claude/skills/primedirective/` for `SKILL.md`, references, and maybe thin command examples only.

## Revised Position Delta

I keep my R1 architecture: thin skill, deterministic helper scripts, canonical machine JSON plus generated Markdown, freshness checks, pre-edit guard, drain-first enforcement, and phase-close gate runner.

Changes after Round 2:

1. **Scripts move to `tools/audit/primedirective/`**
   The skill invokes repo tooling; it does not own enforcement code.

2. **Brief/full status tiers**
   Auto path trigger emits:

   ```text
   [PD] Phase {id} · task {task_id} · gates {passed}/{total} · blocking {n} · next: {action}
   ```

   Explicit `/primedirective`, stale state, blocked state, or phase-close intent emits the full Markdown status excerpt.

3. **Add task scope lock**
   Tracker gains `scope_lock`. Guard warns when edits fall outside active task scope, except for blocker fixes, gate work, or explicit user redirection.

4. **Tracker is a generated snapshot, not model-authored state**
   I would tighten wording from R1: JSON is canonical for agents to read, but authoritative facts come from inputs and evidence. Only `prime_refresh.py` writes it. The model never manually edits tracker state.

5. **Enforcement claims become precise**
   `prime_guard.py` can return `BLOCK`, but the skill must not pretend it physically intercepts edits. Real hard enforcement should also be wired into CI/pre-commit gates where possible: substrate, no-whatif, frontend boundary, and phase-close validation.