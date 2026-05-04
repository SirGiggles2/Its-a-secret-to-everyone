Warning: True color (24-bit) support not detected. Using a terminal with true color enabled will result in a better visual experience.
Ripgrep is not available. Falling back to GrepTool.
### Researching Skill Architecture

I am analyzing the requirements for the `/primedirective` mega-skill. This involves integrating the behavioral spec (NES Zelda 1), the 18-phase Master Plan, and the "Hard Rules" (SGDK, WT, D1) into a single, cohesive enforcement and tracking mechanism. I am designing a state-machine-driven approach that utilizes a project-committed tracker to ensure continuity and rigor.

---

# Debate 009: /primedirective Mega-Skill Design — GEMINI Opening Position

## 1. Skill File Structure

The skill will be housed in the project-scoped directory `.claude/skills/primedirective/`. To ensure the skill is not just a passive document but an active participant in the workflow, it will utilize a **State-Machine Oracle** pattern.

### `.claude/skills/primedirective/SKILL.md`

```markdown
---
name: primedirective
description: Enforces the NES Zelda 1 Behavioral Spec, Master Plan progression, and Engineering Hard Rules.
argument-hint: [phase-check | task-update | gate-close | status]
user-invocable: true
disable-model-invocation: false
---

# The Prime Directive
NES accuracy is the **Specification**; Genesis-native is the **Implementation**. 
Match palette, layout, timing, RAM, sprite-priority, scroll, and animation exactly. When ground truth is ambiguous, you MUST use `tools/` to dump NES ROM data.

## I. Hard Rules (Enforcement)
- **D1 (Drain-First):** Edits to `src/game/` REQUIRE a 4-line task header:
  1. NES Source: [address/label]
  2. Drained C: [file/function]
  3. Coverage: [X%]
  4. Stance: [Verified/Ported/Fixing]
- **WT (Worktree):** Substrate (`src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`) is SINGLE-WRITER. Edit only from `main`.
- **SGDK:** Maintain the hand-rolled VDP gate. No high-level SGDK abstractions that bypass the VDP-direct paths.

## II. Master Plan Tracker
You are currently tracking progress via `docs/audit/master_plan_tracker.json`. 
- **Active Phase:** Consult `active_phase` in the tracker.
- **Task Lock:** Do not perform tasks outside the `current_task` scope unless explicitly promoted.
- **Gatekeeper:** You are FORBIDDEN from transitioning phases until the "Phase Close Gate" checklist is 100% verified in the tracker.

## III. Invocation Protocol
1. **Refresh:** On every invocation, run `tools/audit/active_scope.py` to sync `.active_scope`.
2. **Verify:** Check if the current file buffer matches the `active_scope` rules.
3. **Report:** If `status` is passed, emit a concise summary of Phase, Task, and pending Gates.
```

---

## 2. Tracker File Schema: `docs/audit/master_plan_tracker.json`

I propose a JSON format for the tracker. JSON is preferred over Markdown for tracking because it allows for easy programmatic validation by `tools/audit/` scripts, preventing "hallucinated" progress.

```json
{
  "metadata": {
    "project": "FINAL TRY",
    "last_updated": "2026-05-04T12:00:00Z",
    "updated_by": "gemini-cli"
  },
  "state": {
    "active_phase": 1.5,
    "current_task": "NES Reference Capture Harness Implementation",
    "active_targets": ["RoomRom.md", "tools/builder/"],
    "worktree_mode": "RoomRom_Worktree"
  },
  "phase_progression": {
    "phase_1_5": {
      "status": "in_progress",
      "tasks": [
        { "id": "ref_capture", "desc": "Implement NES capture harness", "done": false },
        { "id": "parity_logic", "desc": "Define parity-oracle-schema", "done": false }
      ],
      "gates": {
        "REQUIRE_GENERATED_ASSETS": false,
        "REGRESSION_MATRIX_PASS": false,
        "PROBE_LIMIT_OK": false,
        "CODE_REVIEW_DONE": false
      }
    }
  },
  "blockers": [],
  "deferrals": []
}
```

---

## 3. Activation & Invocation Pattern

1.  **Auto-Initialization:** The skill is activated immediately upon session start. It performs a "Ground Truth Sync" by reading `docs/audit/master_plan_tracker.json` and comparing it with the current `git branch` and `git worktree list`.
2.  **Contextual Trigger:** Any `replace` or `write_file` call to paths in `src/game/` or `src/sgdk_adapter/` triggers an internal "Directive Check". If the 4-line D1 header is missing or the worktree is incorrect, the agent must self-correct *before* applying the edit.
3.  **Slash Command (`/primedirective`):** Primarily used for manual state transitions (e.g., `/primedirective gate-close`). This triggers the 11-step "Phase Close Gate" automation.

---

## 4. Top 3 Enforcement Mechanisms

1.  **The D1 Header Guard:** The skill uses a regex-based pre-flight check on all `src/game/` edits. If the 4-line header (NES/C/Coverage/Stance) is absent, the skill aborts the `replace` tool call and emits a "Violation: Missing D1 Header" error to the agent's internal thought stream.
2.  **Worktree-Substrate Interlock:** Before editing any file in `src/sgdk_adapter/`, the skill executes `git rev-parse --abbrev-ref HEAD`. If the result is not `main`, it blocks the edit.
3.  **Gate-Locked Progression:** The tracker's `gates` object acts as a hard boolean lock. The agent cannot move to Phase N+1 until all Phase N gates in the JSON are `true`. These booleans are only flipped by the successful execution of `tools/run_regression_matrix.py` and other validation scripts.

---

## 5. Top 3 Failure Modes & Mitigations

1.  **Stale Tracker Sync:** The JSON tracker might fall out of sync with actual file state (e.g., tasks marked done but code reverted).
    *   *Mitigation:* The `tools/audit/drain_coverage.py` script will be updated to output a "verified_tasks" list that the skill diffs against the tracker on every invocation.
2.  **Context Bloat via Header Repetition:** Including the 4-line header in every single turn could eat context.
    *   *Mitigation:* The header is only required in the *file content* itself (as a comment), not necessarily in the agent's conversational turns, unless specifically requested.
3.  **Rigid Blocking of Emergency Fixes:** A critical bug in a previous phase might be blocked by the "Active Phase" lock.
    *   *Mitigation:* Implement a `Hotfix` state in the tracker that allows surgical edits to "Closed" phases without triggering a full phase re-validation, provided `tools/run_regression_matrix.py` remains green.

---

## 6. Strategic Intent Summary

My design treats the `/primedirective` skill as the **Project's Nervous System**. It doesn't just provide instructions; it creates a feedback loop between the Master Plan (JSON), the Codebase (D1 headers), and the Git Environment (Worktrees). By grounding the tracker in a version-controlled JSON file, we ensure that every agent (Claude or Gemini) is aligned on the exact same state, preventing drift and ensuring that the "Prime Directive" is an enforced reality rather than a polite suggestion.

I will now wait for the other providers' designs to perform the Round 2 diff.
