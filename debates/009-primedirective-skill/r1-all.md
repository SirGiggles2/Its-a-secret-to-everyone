**CODEX Round 1 Position**

I would build `/primedirective` as a lean skill plus deterministic helper scripts. The skill should load fast, state the rules, then delegate progress freshness and enforcement checks to tools. A mega-skill that tries to hold the whole 2171-line plan in prompt context will rot and will be resisted. A skill that runs a 1-second status script and only loads details on demand will actually get used.

**Skill Structure**

```text
.claude/skills/primedirective/
  SKILL.md
  references/
    hard-rules.md
    phase-ladder.md
    phase-close-gate.md
    target-boundaries.md
  scripts/
    prime_status.py
    prime_refresh.py
    prime_guard.py
  templates/
    tracker.schema.json
    tracker.initial.json
```

`SKILL.md` should stay under roughly 250 lines. The phase ladder and hard rules live in references, but the first-page operating protocol is in the body.

Literal frontmatter:

```yaml
---
name: primedirective
description: Load and enforce the Sega Genesis Zelda 1 Prime Directive. Use at conversation start, when the user invokes /primedirective, or before touching Title.md, RoomRom.md, Final.md, tools/builder/, src/, data/, build scripts, audit tools, parity tools, state tools, SGDK adapter code, or master-plan phase work. Tracks active master-plan phase, gates, blockers, NES-ground-truth requirements, worktree safety, substrate ownership, drain coverage, and phase-close readiness.
argument-hint: "[status|refresh|gate|phase|task|why]"
user-invocable: true
disable-model-invocation: false
---
```

Body outline:

```md
# Prime Directive

Run this first:

```bash
python .claude/skills/primedirective/scripts/prime_status.py
```

If status says `STALE`, run:

```bash
python .claude/skills/primedirective/scripts/prime_refresh.py
python .claude/skills/primedirective/scripts/prime_status.py
```

Before edits, run:

```bash
python .claude/skills/primedirective/scripts/prime_guard.py --intent edit --paths <paths>
```

Before RoomRom build/edit, also run `git worktree list`.

## Non-Negotiables

NES Zelda 1 is the behavioral spec. Genesis-native code is the implementation.

Prefer, in order:
1. Best long-term outcome
2. Best coding practice
3. Maximal efficiency
4. NES accuracy

Do not ask permission to proceed. Execute the next concrete action unless blocked.

When behavior is unclear, dump NES ground truth: CHR, OAM, nametable, PALRAM, RAM tables, timing, scroll, sprite priority, animation.

Consult `docs/audit/active_scope.md` before edits.

Respect substrate ownership: `src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`, and `src/audio_driver.asm` are edited from `main` only.

Never emit `whatif.*`. `build.bat` emits only `Title.*`.

For drained systems, drained C in `src/game/<subsystem>/*_runtime.c` is primary. NES disasm is secondary and wins ties. Begin implementation notes with:

```text
NES source:
Drained C:
Coverage:
Stance:
```

Use the three-gate verification: focused probe, regression matrix, evidence artifact.

## Required Status Surface

Every invocation must report:
- active phase and task
- gates passed and pending
- blockers
- stale inputs, if any
- next concrete action

Load references only when needed:
- `references/phase-ladder.md`
- `references/hard-rules.md`
- `references/phase-close-gate.md`
- `references/target-boundaries.md`
```

**Tracker Format**

Use a hybrid tracker: JSON is canonical, Markdown is generated. Do not use per-phase Markdown as source of truth. Do not infer phase purely from git log. Git history is evidence, not state.

Canonical path:

```text
docs/superpowers/prime_directive_tracker.json
```

Generated human report:

```text
docs/superpowers/prime_directive_status.md
```

Literal schema shape:

```json
{
  "schema_version": 1,
  "updated_at": "2026-05-04T00:00:00-05:00",
  "updated_by": "primedirective",
  "plan_path": "docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md",
  "plan_hash": "sha256-of-master-plan",
  "active_phase": {
    "id": "1.5",
    "name": "NES Reference Capture Harness",
    "status": "active",
    "active_task_id": "1.5.2",
    "active_task": "Capture baseline title and room reference evidence",
    "entered_at": "2026-05-04T00:00:00-05:00"
  },
  "phases": [
    {
      "id": "0",
      "name": "Target Rename and Split",
      "status": "complete",
      "started_at": null,
      "completed_at": null,
      "evidence": [],
      "deferrals": []
    },
    {
      "id": "1.5",
      "name": "NES Reference Capture Harness",
      "status": "active",
      "tasks": [
        {
          "id": "1.5.1",
          "title": "Define capture schema",
          "status": "complete",
          "evidence": [
            "tools/parity/schema.json"
          ]
        },
        {
          "id": "1.5.2",
          "title": "Capture baseline title and room reference evidence",
          "status": "active",
          "blockers": []
        }
      ],
      "close_gate": {
        "require_generated_assets_build": "pending",
        "focused_probe_set": "pending",
        "screenshot_state_evidence": "pending",
        "diff_vs_nes_reference": "pending",
        "regression_matrix": "pending",
        "alias_collision_check": "not_applicable",
        "probe_cycle_limit": "pending",
        "code_review": "pending",
        "findings_resolved_or_deferred": "pending",
        "rerun_probes_and_matrix": "pending",
        "commit_with_phase_report": "pending"
      }
    }
  ],
  "freshness": {
    "active_scope_path": "docs/audit/active_scope.md",
    "active_scope_hash": null,
    "drain_coverage_path": "tools/audit/drain_coverage.json",
    "drain_coverage_hash": null,
    "git_head": null,
    "dirty_paths_hash": null,
    "last_refresh_at": null,
    "stale_reasons": []
  },
  "current_blockers": [],
  "next_concrete_action": {
    "kind": "command",
    "description": "Refresh active scope and inspect phase 1.5 pending capture work",
    "command": "python tools/audit/active_scope.py && python .claude/skills/primedirective/scripts/prime_status.py"
  }
}
```

**Tracker Freshness**

Stale if any of these changed since `last_refresh_at`:

- `plan_hash` differs from master plan hash.
- `git_head` changed.
- tracked dirty path set changed under phase-relevant paths.
- `docs/audit/active_scope.md` missing or hash changed.
- `tools/audit/drain_coverage.json` missing or hash changed when touching drained gameplay code.
- tracker older than 24 hours during active work.
- phase-close evidence paths referenced by tracker no longer exist.
- active phase says complete but next phase is not active.

`prime_status.py` should never mutate. It reports `FRESH`, `STALE`, or `BLOCKED`.

`prime_refresh.py` may mutate the JSON and generated Markdown. It should derive facts from the plan, audit outputs, evidence files, and git, but preserve human/agent decisions like current task, deferrals, and blockers unless contradicted by missing files.

**Activation Pattern**

Use all three activation routes:

1. Slash: `/primedirective`, with optional args: `status`, `refresh`, `gate`, `phase`, `task`.
2. Auto at conversation start: put a one-line instruction in project `CLAUDE.md`: “At session start, invoke `.claude/skills/primedirective` and run `prime_status.py` before phase work.”
3. Path-triggered model invocation: frontmatter description explicitly names `Title.md`, `RoomRom.md`, `Final.md`, `tools/builder/`, `src/`, `data/`, parity, audit, state, and build paths.

For actual blocking, rely on scripts and CI gates, not model memory. The skill instructs Claude; scripts verify Claude.

**Top 3 Enforcement Mechanisms**

1. **Pre-edit guard**

`prime_guard.py --intent edit --paths ...` checks:

- RoomRom touch requires prior `git worktree list` evidence.
- substrate paths require current branch/worktree to be `main`.
- phase-relevant edits require `docs/audit/active_scope.md`.
- `whatif.*` paths are rejected.
- `build.bat` changes are scanned for non-`Title.*` emissions.

2. **Drain-first checker**

For edits under `src/game/`, guard checks `tools/audit/drain_coverage.json`.

It rejects or warns on:

- claiming `GREENFIELD` when candidate drained C exists.
- missing 4-line task header in notes, commit body template, or phase report.
- using NES disasm as primary when drained C exists.

3. **Phase-close gate runner**

`prime_guard.py --intent close-phase --phase <id>` enforces the mandatory gate order and records exact evidence paths. It should block commit guidance unless all required gates are green or explicitly recorded as deferrals where allowed.

**Self-Update On Phase Close**

The skill should not manually “decide” completion. Completion belongs to tooling.

Flow:

1. Claude runs the phase-close gate.
2. Tools emit machine evidence.
3. `prime_refresh.py --close-phase <id>` updates tracker only if required evidence exists.
4. Skill reports the next active phase/task.

This keeps the skill declarative and prevents prompt-driven optimism from marking phases complete.

**Top 3 Failure Modes And Mitigations**

1. **Stale tracker pins Claude to the wrong phase**

Mitigation: status script must compare plan hash, git head, dirty path hash, evidence existence, active scope hash, and audit hashes. If stale, it must report “unknown until refresh,” not pretend certainty.

2. **False-positive blocking slows real work**

Mitigation: classify checks as `BLOCK`, `WARN`, or `INFO`. Block only substrate-on-non-main, `whatif.*`, missing active scope, missing RoomRom worktree check, and phase-close order violations. Drain ambiguity should warn unless a forbidden claim is being made.

3. **Overhead burnout**

Mitigation: default invocation runs one fast status command. Heavy commands run only for `refresh`, `gate`, RoomRom work, substrate edits, or phase close. References are progressive-disclosure files, not dumped into every prompt.

**Round 2 Diff Placeholder**

No other providers’ designs are visible in Round 1, so I cannot diff directly yet. My expected distinction: I reject “one giant SKILL.md” and “tracker only from git log.” I also reject per-phase Markdown as canonical state. My design uses JSON for machine enforcement, generated Markdown for human scanning, and helper scripts for anything that must be reliable.Warning: True color (24-bit) support not detected. Using a terminal with true color enabled will result in a better visual experience.
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
# Round 1 — SONNET opening position
# Debate 009: /primedirective Mega-Skill Design

---

## Core thesis

**The tracker must be auto-derived, not hand-maintained. The skill must be thin, not comprehensive.**

The single biggest failure mode for a mega-skill is becoming a liability — a stale document that Claude reads, nods at, and then ignores because it costs tokens and gives wrong answers. My design drives everything from `tools/audit/*.json` + `git log` + `.active_scope` as the **single source of truth**, with the SKILL.md acting as a lightweight interpreter layer and enforcement checklist — not a knowledge base. Heavy knowledge → rot. Thin interpreter → stays live.

---

## 1. Skill file structure

```
.claude/skills/primedirective/
  SKILL.md          ← the skill proper (frontmatter + behavior script)
  helpers/
    check_phase.sh  ← thin shell wrapper: reads .active_scope, drain_coverage.json, git log
    fmt_status.py   ← pretty-prints the derived state into a human block
```

### SKILL.md (literal)

```markdown
---
name: primedirective
description: >
  Prime Directive enforcer + master plan tracker. Surfaces active phase,
  active task, gate status, and blocking issues. Runs enforcement checks
  (worktree, substrate, drain stance, whatif). Auto-invoked on conversation
  start and on file-touch involving phase-relevant paths.
argument-hint: "[--refresh] [--phase <N>] [--task <T>]"
user-invocable: true
disable-model-invocation: false
---

# /primedirective — Prime Directive Enforcer + Plan Tracker

## Invocation contract

On every invocation (explicit `/primedirective` OR auto-load trigger):

1. **DERIVE state** — do not read a hand-maintained tracker file.
   Run the following reads in parallel:
   a. Read `docs/audit/active_scope.md` → active phase, worktree, allow/block paths.
   b. Read `tools/audit/drain_coverage.json` → per-subsystem coverage summary.
   c. Run `git log --oneline -20` → detect phase-close commits ("phase X closed",
      "phase X close gate") and any substrate-touching commits since last phase tag.
   d. Read `docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md`
      — ONLY the Current Next Action section (search "Current Next Action" heading)
      plus the active phase task list.

2. **EMIT a status block** (always, at conversation start or explicit invocation):

   ```
   ╔═ PRIME DIRECTIVE STATUS ══════════════════════════════════════╗
   ║ Phase: 2 — RoomRom Graphics Registry + No-Clobber Foundation ║
   ║ Worktree: RoomRom                                            ║
   ║ Active task: 2.x — [task name from master plan]             ║
   ║ Drain coverage: [subsystem: PARTIAL/FULL/NONE, ...]         ║
   ║ Gates passed: [list]                                         ║
   ║ Gates pending: [list]                                        ║
   ║ BLOCKING: [any hard violations detected in current session]  ║
   ╚═══════════════════════════════════════════════════════════════╝
   ```

3. **INSTALL session guardrails** (once per conversation):
   Register the six behavioral checks described in the Enforcement section below.
   These do not block tool calls — they emit a WARNING prefix before any
   response that would violate the directive.

## Prime Directive (canonical, read-only)

NES Zelda 1 = behavioral spec. Genesis-native = implementation.
Priority: best long-term outcome → best coding practice → maximal efficiency
→ NES accuracy. When in doubt: dump NES ROM ground truth (CHR/OAM/NT/PALRAM/RAM).
No multi-choice prompts. No "OK to proceed?". Execute.

## Hard Rules (enforced each invocation)

### SGDK-1..5
- SGDK-1: All Genesis-specific code lives behind `src/sgdk_adapter/` boundary.
- SGDK-2: SGDK pinned at sha ef9292c0 per `tools/sgdk_pin.json`.
- SGDK-3: No hand-rolled VDP writes that bypass the adapter gate.
- SGDK-4: Audio migration triggered per master plan phase 10 gate only.
- SGDK-5: Fork policy: patch → PR to upstream; never local silent fork.

### WT-1..4
- WT-1: Substrate (`src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`,
  `src/audio_driver.asm`) edited from `main` worktree ONLY.
- WT-2: Active scope pointer at `docs/audit/active_scope.md` consulted before
  any edit. Run `python tools/audit/active_scope.py` if stale.
- WT-3: Frontend boundary enforced by `tools/gates/check_frontend_boundary.py`.
- WT-4: `build.bat` emits ONLY `Title.*` / `RoomRom.*`. Zero `whatif.*`.

### D1 (Drain-first)
- Drained C in `src/game/<subsystem>/*_runtime.c` is PRIMARY evidence.
- NES disasm (`reference/aldonunez/*.asm`, `src/zelda_translated/*.asm`) is
  SECONDARY and wins ties.
- Every task touching a drained subsystem requires the 4-line header:
  ```
  NES source:  <file.asm>:<symbol>
  Drained C:   <path>:<function>
  Coverage:    PARTIAL | FULL | NONE
  Stance:      ADOPT | EXTEND | REPLACE | GREENFIELD
  ```
  GREENFIELD is illegal when `tools/audit/drain_coverage.json` shows a
  candidate row for that subsystem/symbol.
- 3-gate verification required before phase close.

## Enforcement: six behavioral checks

These run silently. Emit WARNING only when violated.

**CHECK-1 (Worktree/Substrate)**
Before any edit to substrate paths: call `git worktree list` and confirm
the active worktree is `main`. If not: emit BLOCKED, explain, do not proceed.

**CHECK-2 (Drain stance)**
Before generating any code for a subsystem with drained C:
read `tools/audit/drain_coverage.json`, find matching `nes_symbol` rows,
confirm stance is not GREENFIELD unless coverage = NONE. If mismatch: emit
WARNING with the correct task header template pre-filled.

**CHECK-3 (Scope boundary)**
Before any file edit: check path against `.active_scope` allow/block lists.
Substrate paths always require main worktree (CHECK-1 supersedes).
Non-substrate paths outside ALLOW get WARNING. Paths in BLOCK get BLOCKED.

**CHECK-4 (No whatif)**
If any code generation or build command would produce `whatif.*` output:
BLOCKED. Cite `tools/gates/check_no_whatif.py`. Correct to `Title.*`.

**CHECK-5 (Worktree rule before RoomRom)**
Before any RoomRom build, copy, or edit: run `git worktree list`.
Confirm which worktree has the most recent RoomRom commits by checking
`git log --oneline -5` per worktree. Use the most recent. Never assume main.

**CHECK-6 (Phase close gate)**
When user signals phase completion or asks to close a phase: walk the
11-step gate in order. Do not skip. Do not mark phase closed until
step 11 commit is made.

## Tracker: auto-derived, not hand-maintained

There is NO `tracker.json` that I update. Instead, phase state is always
derived at invocation from:

- `docs/audit/active_scope.md` — phase + worktree (authoritative)
- `tools/audit/drain_coverage.json` — D1 coverage per subsystem
- `git log --oneline --grep="phase.*close"` — detect closed phases
- master plan "Current Next Action" section — active task

**Staleness detection**: `docs/audit/active_scope.md` has a generation
timestamp. If the timestamp is older than the most recent phase-close commit
in `git log`, the file is stale. In that case: run
`python tools/audit/active_scope.py` before proceeding. Emit a WARNING if
the run fails (broken tool = blocked phase advance).

## Self-update on phase close

The skill does NOT self-update a tracker file. On phase close (step 11 of
gate), the post-commit hook calls `python tools/audit/active_scope.py` which
regenerates `docs/audit/active_scope.md` and `.active_scope`. The next
`/primedirective` invocation will see the new state automatically.

This keeps the skill stateless and the tool authoritative.

## Auto-activation triggers

The skill activates (emits status block, installs guardrails) when:
1. `/primedirective` is typed explicitly.
2. Conversation starts (first tool call in session).
3. Any tool call touches a file matching: `src/game/**`, `RoomRom/src/**`,
   `src/sgdk_adapter/**`, `src/audio_driver.asm`, `data/**`, `src/state/**`.
4. User types any of: "next task", "phase close", "what's blocking",
   "close phase", "what phase".

On trigger from (3), emit an abbreviated status (one line) rather than the
full block, to avoid token overhead on every file touch.
```

---

## 2. Tracker file schema

**There is no standalone tracker file. This is the core design choice.**

The "tracker" is a derived view assembled at invocation from existing authoritative files. If I must output something persistent, it is a **read-only cache** written by `tools/audit/active_scope.py`, never by the skill itself.

For human reference, the derived status format is:

```json
// .active_scope (machine-readable, written by tools/audit/active_scope.py)
// DO NOT EDIT BY HAND
{
  "schema_version": 2,
  "generated_at": "2026-05-04T00:00:00+00:00",
  "active_phase": 2,
  "active_phase_name": "RoomRom Graphics Registry + No-Clobber Foundation",
  "active_worktree": "RoomRom",
  "active_task": "2.x",
  "active_task_name": "[derived from master plan Current Next Action]",
  "allow_paths": ["RoomRom/src/", "RoomRom/data/", "RoomRom/tools/"],
  "block_paths": ["src/frontend/", "src/game/"],
  "substrate_paths": [
    "src/sgdk_adapter/", "src/abi/", "src/state/",
    "data/", "src/audio_driver.asm"
  ],
  "gates_passed": [],
  "gates_pending": [
    "build_REQUIRE_GENERATED_ASSETS",
    "probe_set",
    "screenshot_parity_oracle",
    "diff_nes_reference",
    "regression_matrix",
    "verify_no_alias_collisions",
    "PROBE_CYCLE_LIMIT",
    "code_review",
    "fix_deferrals",
    "rerun_probes",
    "phase_commit"
  ],
  "blocking": []
}
```

The `.active_scope` file already exists and is written by `tools/audit/active_scope.py`. My proposal extends its schema to include `active_task`, `gates_passed`, `gates_pending`, and `blocking` — all still machine-written by the Python tool, never by the skill.

---

## 3. Activation/invocation pattern

**Explicit + threshold-triggered, not always-on.**

Always-on auto-loading on every conversation start is wrong. It burns tokens reading the master plan header every session, including sessions that touch only a Lua probe script. The right model is:

- **Explicit**: `/primedirective` → full status block + guardrail install.
- **Threshold trigger**: first file touch in a session that hits a phase-relevant path → abbreviated one-line status + silent guardrail install.
- **Keyword trigger**: user says "next task / phase close / what's blocking" → full status block.
- **NOT**: every conversation start regardless of content.

The abbreviated trigger form (path-based):
```
[PD] Phase 2 | RoomRom worktree | Task 2.x | 0 blocking
```
This is 1 line, costs near-zero tokens, and signals the guardrails are active.

---

## 4. Top 3 enforcement mechanisms

### E1: Worktree gate before substrate touch (CHECK-1)

The single most destructive mistake in this project is editing substrate from the wrong worktree. Before ANY edit to `src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`, or `src/audio_driver.asm`, the skill runs `git worktree list` and fails hard if the active path is not the main worktree. This is mechanical, binary, and cannot be argued away. It mirrors what `tools/gates/check_substrate_dual_rom.py` does post-hoc, but catches it pre-action.

### E2: Drain stance check before code generation (CHECK-2)

Before writing any implementation for a subsystem listed in `tools/audit/drain_coverage.json`, the skill reads that file, finds matching rows, and enforces the 4-line task header. If `stance = GREENFIELD` but `coverage != NONE`, the skill emits a BLOCKED with the pre-filled header. This directly enforces D1 at the moment of action, not post-hoc. The drain_coverage.json file already exists and has the right schema — the skill just reads it.

### E3: Phase close gate walkthrough (CHECK-6)

When phase close is triggered, the skill enforces all 11 steps in order and refuses to emit the phase-close commit message until step 10 (re-run probes + regression matrix) is confirmed green. This prevents the common failure mode of closing a phase after step 3 and calling it done. The gate steps cite specific tools: `tools/run_regression_matrix.py`, `tools/state/verify_no_alias_collisions.py --scope <subsystems>`, `superpowers:requesting-code-review`.

---

## 5. Top 3 failure modes + mitigations

### F1: Stale `docs/audit/active_scope.md` pins Claude to wrong phase

**Scenario**: Phase 3 was closed but the post-commit hook didn't run (Windows hook reliability). `active_scope.md` still says Phase 2. Claude reads it, thinks Phase 2 is active, applies Phase 2 constraints to Phase 3 work.

**Mitigation**: Cross-check `active_scope.md` generation timestamp against `git log --oneline --grep="phase.*close" -5`. If a phase-close commit is newer than the file, flag staleness and re-run `python tools/audit/active_scope.py` before proceeding. Never trust the file in isolation.

### F2: Token overhead makes Claude skip the invocation

**Scenario**: The skill tries to read the 2171-line master plan on every activation. After a few sessions the user notices responses are slow and stops calling the skill.

**Mitigation**: Never read the full master plan. Search for the "Current Next Action" section only (one `Grep` call). For phase task details, read only the active phase section (50-100 lines max). The status block should cost under 5k tokens total. If the skill can't derive state in under 3 tool calls, something is wrong with the design, not the master plan.

### F3: CHECK-2 false-positive GREENFIELD block on genuinely new subsystem work

**Scenario**: Phase 5 introduces a new subsystem with no drain. drain_coverage.json has no rows for it. Claude checks the file, finds no rows, and... the skill says GREENFIELD is illegal. But GREENFIELD is correct here.

**Mitigation**: The drain_coverage.py tool already distinguishes "no candidate drain found" (GREENFIELD legal) from "candidate drain exists" (GREENFIELD illegal). The skill must read the row's `coverage` field, not just the `stance` field. CHECK-2 only triggers when `coverage != NONE` AND `stance == GREENFIELD`. A missing row = no constraint. This matches the exact logic in `tools/audit/drain_coverage.py`'s phantom detection.

---

## Where I disagree with obvious defaults

1. **Against: hand-maintained tracker.json updated by the skill**. This creates a write-conflict when two sessions run in parallel, drift when the skill fails mid-session, and a false sense of authority when the file is wrong. The Python tooling already has the authoritative state. Use it.

2. **Against: always-on conversation-start load of the full status block**. Every session pays the cost, most sessions don't need the full block. Threshold-trigger on relevant path touch is the right default.

3. **Against: putting the 18-phase master plan inside SKILL.md**. Skills are behavioral scripts, not knowledge bases. The master plan lives at `docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md`. The skill reads it; it doesn't duplicate it. Duplication = guaranteed drift.

4. **Against: the skill being responsible for its own self-update**. Post-commit hooks calling `python tools/audit/active_scope.py` is the right architecture. The skill is stateless; the tools maintain state. Clean separation.
# Round 1 — OPUS opening position
# Debate 009: /primedirective Mega-Skill Design

## Core thesis

**Thin skill body, fat helper scripts, derived-not-stored tracker, two-tier surfacing.**

The skill itself must read in <3s and cost <2k context tokens at the abbreviated tier. All heavy lifting (parse master plan, hash audit JSONs, walk gates, check worktree) lives in **stand-alone Python under `tools/audit/primedirective/`** that returns one of three exit states: FRESH | STALE | BLOCKED. The skill body is a contract that says: "run `prime status`, obey its output, refuse to claim phase progress without it."

Two surfacing tiers — **terse one-liner** (auto, on first phase-relevant tool call) and **full status block** (explicit `/primedirective`, conversation start when `--full`, or keyword "phase close / what's blocking"). Anything more aggressive will be ignored within 3 sessions.

The tracker JSON is **stored**, but is **only ever written by `prime_refresh.py`**, never by the model. The model reads it, never edits it. Master plan + git log + audit JSONs are the inputs; the tracker is a deterministic snapshot.

---

## 1. Skill file structure

```
.claude/skills/primedirective/
  SKILL.md                              ~200 lines
  references/
    prime-directive.md                  the canonical NES-spec / Genesis-impl text
    phase-ladder.md                     phases 0..17 with one-line summaries + plan offsets
    hard-rules.md                       SGDK-1..5, WT-1..4, D1
    phase-close-gate.md                 11-step ordered checklist
    targets.md                          Title.md, RoomRom.md, Final.md, tools/builder/
tools/audit/primedirective/
  prime_status.py                       read-only; emits FRESH/STALE/BLOCKED + status block
  prime_refresh.py                      mutating; rebuilds tracker from authoritative inputs
  prime_guard.py                        pre-edit checker; --intent edit|build|close-phase
  schema.json                           tracker JSON schema (jsonschema-validated)
docs/superpowers/
  prime_directive_tracker.json          machine-written canonical tracker
  prime_directive_status.md             generated human report (rendered from tracker)
```

### SKILL.md (literal)

```markdown
---
name: primedirective
description: |
  Sega Genesis Zelda 1 port — Prime Directive enforcer + master-plan progress tracker.
  Run at conversation start, on /primedirective, before editing Title.md/RoomRom.md/Final.md/
  src/sgdk_adapter/src/abi/src/state/data/src/audio_driver.asm/src/game/src/frontend/
  RoomRom/src/data/tools/builder/build.bat, before any phase-close commit, or when the user
  asks "what phase / what's blocking / next task / phase close". Surfaces active phase + task,
  passed/pending gates, blockers, NES-ground-truth requirements, worktree safety, drain
  stance, and the next concrete action. Refuses to assert progress without a FRESH tracker.
argument-hint: "[status|refresh|gate|phase|task|why|--full|--brief]"
user-invocable: true
disable-model-invocation: false
---

# /primedirective

## Operating contract

EVERY invocation, in this order:

1. `python tools/audit/primedirective/prime_status.py --json` — read-only, <2s.
2. If exit code != 0 OR result.state == "STALE":
   `python tools/audit/primedirective/prime_refresh.py` then re-run step 1.
3. Emit the **status surface** (brief or full per arg).
4. If user intent is an edit/build/close, run
   `prime_guard.py --intent <kind> --paths <p>` BEFORE the action.
5. Cite tracker fields by name when claiming progress. Never paraphrase.

## Prime Directive (canonical)

NES Zelda 1 = behavioral spec. Genesis-native = implementation.
Match palette, layout, timing, RAM, sprite priority, scroll, animation EXACTLY.

Decision priority:
  1. best long-term outcome
  2. best coding practice
  3. maximal efficiency
  4. NES accuracy

When unclear: dump NES ROM ground truth (CHR/OAM/NT/PALRAM/RAM) BEFORE coding.
Never ask "OK to proceed?". Pick the path and execute.
User interrupts if wrong — that is faster than gating every step.

## Hard rules (refuse to violate)

- **SGDK-1..5** — adapter boundary, version pin, hand-rolled VDP gate, audio migration trigger,
  fork policy. See `references/hard-rules.md`.
- **WT-1..4** — substrate single-writer (main worktree only), active-scope pointer,
  frontend boundary, no whatif emission. See `references/hard-rules.md`.
- **D1** — drained C in `src/game/<subsystem>/*_runtime.c` is PRIMARY; NES disasm is SECONDARY
  (wins ties). 4-line task header required:
    NES source: <file>:<symbol>
    Drained C:  <path>:<symbol> | NONE
    Coverage:   FULL | PARTIAL(...) | STALE(...) | NONE
    Stance:     ADOPT | EXTEND | REPLACE | GREENFIELD
  GREENFIELD illegal when `tools/audit/drain_coverage.json` shows a candidate row.

## Status surface

### Brief (auto-trigger on phase-relevant tool call)
```
[PD] Phase {id} {name} · task {tid} · WT {worktree} · gates {p}/{t} · blocking {n}
```

### Full (explicit /primedirective or keyword trigger)
Emit the rendered `docs/superpowers/prime_directive_status.md` excerpt (10–25 lines).

## Auto-activation triggers

1. Slash: `/primedirective [args]`.
2. First tool call in session whose path glob hits any of:
   `src/**`, `RoomRom/**`, `Title.md`, `RoomRom.md`, `Final.md`, `data/**`, `tools/builder/**`,
   `build.bat`, `docs/superpowers/plans/**`.
3. User text matches any of: "phase close", "what's blocking", "next task", "what phase",
   "close phase", "prime directive".

Trigger (1) and (3) emit FULL. Trigger (2) emits BRIEF.

## What this skill REFUSES to do

- Claim a phase complete or task done without a FRESH tracker.
- Edit substrate from a non-`main` worktree.
- Generate `whatif.*` output anywhere.
- Accept `Stance: GREENFIELD` when drain coverage shows a candidate row.
- Skip steps in the 11-step phase-close gate.
- Read the entire 2171-line master plan inline; only the active phase section + the
  "Current Next Action" pointer are loaded.

## Progressive references

Load only when the question demands depth:
- `references/phase-ladder.md` — full 0..17 ladder with one-liner per phase.
- `references/phase-close-gate.md` — the 11-step ordered checklist.
- `references/hard-rules.md` — SGDK-1..5, WT-1..4, D1 with rationales.
- `references/targets.md` — Title.md / RoomRom.md / Final.md / tools/builder/ scope.
```

---

## 2. Tracker file schema (literal, JSON, machine-written)

Path: `docs/superpowers/prime_directive_tracker.json`. Companion `prime_directive_status.md` is regenerated from this on every refresh.

```json
{
  "$schema": "tools/audit/primedirective/schema.json",
  "schema_version": 1,
  "generated_at": "2026-05-04T00:00:00-05:00",
  "generated_by": "tools/audit/primedirective/prime_refresh.py",

  "plan": {
    "path": "docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md",
    "sha256": "<hash>"
  },

  "active": {
    "phase_id": "1.5",
    "phase_name": "NES Reference Capture Harness",
    "task_id": "1.5.2",
    "task_title": "Capture baseline title + first-room reference evidence",
    "task_header_present": true,
    "worktree": {
      "path": "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY",
      "branch": "main",
      "is_substrate_writer": true
    },
    "next_concrete_action": "python tools/audit/active_scope.py && python tools/audit/primedirective/prime_status.py --full"
  },

  "phases": [
    {
      "id": "0",
      "name": "Target Rename and Split",
      "status": "complete",
      "evidence": ["commit:abc1234"],
      "deferrals": []
    },
    {
      "id": "1.5",
      "name": "NES Reference Capture Harness",
      "status": "active",
      "tasks": [
        {"id": "1.5.1", "title": "Define capture schema",
         "status": "complete", "evidence": ["tools/parity/schema.json"]},
        {"id": "1.5.2", "title": "Capture baseline reference evidence",
         "status": "active", "blockers": []}
      ],
      "close_gate": {
        "build_REQUIRE_GENERATED_ASSETS": "pending",
        "focused_probe_set": "pending",
        "screenshot_state_evidence": "pending",
        "diff_vs_nes_reference": "pending",
        "regression_matrix": "pending",
        "verify_no_alias_collisions": "not_applicable",
        "PROBE_CYCLE_LIMIT_envelope": "pending",
        "code_review_requested": "pending",
        "findings_resolved_or_deferred": "pending",
        "rerun_probes_and_matrix": "pending",
        "phase_commit_with_report_paths": "pending"
      }
    }
  ],

  "freshness": {
    "active_scope_md": {
      "path": "docs/audit/active_scope.md",
      "sha256": "<hash>",
      "ok": true
    },
    "drain_coverage_json": {
      "path": "tools/audit/drain_coverage.json",
      "sha256": "<hash>",
      "ok": true
    },
    "git_head": "<sha>",
    "dirty_paths_relevant": [],
    "last_refresh_at": "2026-05-04T00:00:00-05:00",
    "stale_reasons": []
  },

  "blockers": [],

  "guardrails_installed": [
    "worktree_substrate_gate",
    "drain_stance_gate",
    "scope_boundary_gate",
    "no_whatif_gate",
    "roomrom_worktree_gate",
    "phase_close_gate"
  ]
}
```

---

## 3. Activation/invocation pattern

**All three** are needed; difference is verbosity:

| Source | Verbosity | When |
|---|---|---|
| `/primedirective` (no arg) | full | explicit user invocation |
| `/primedirective --brief` | brief | scripted use |
| Path glob trigger (auto) | brief | first tool call in session hitting phase-relevant path |
| Keyword trigger (auto) | full | "phase close / next task / what's blocking" |
| Conversation start | none unless project-relevant first message | reduces token waste |

The frontmatter `description` is engineered to fire `disable-model-invocation: false` for trigger (2) and (3), but the BRIEF tier keeps cost negligible.

---

## 4. Top 3 enforcement mechanisms

### E1 — `prime_guard.py --intent edit --paths <paths>` (mandatory pre-edit)

Single binary check. Reads `prime_directive_tracker.json` + `git worktree list` + `tools/audit/drain_coverage.json`. Returns exit code 0 (proceed), 1 (warn), or 2 (BLOCK with reason). Substrate-on-non-main, `whatif.*` emission, GREENFIELD-with-candidate-drain are exit-code-2 BLOCKs.

The skill body says: **before any Edit/Write tool call into project paths, run prime_guard. Honor exit code 2.**

### E2 — Tracker-grounded progress claims

The skill REFUSES to claim "phase X complete" or "task Y done" using prose alone. It must cite tracker fields: `phases[i].status == "complete"`, `evidence[]` populated, `close_gate.<step> == "passed"`. This is a behavioral guardrail enforced by the SKILL.md operating contract section, audited by Codex review pass.

### E3 — Phase-close gate runner (`prime_guard.py --intent close-phase --phase <id>`)

Walks the 11-step gate in fixed order. Each step requires a concrete artifact: probe report path, schema instance path, regression matrix output line, code-review thread URL, fix/deferral entries, rerun probe path, commit SHA. Step 11 (commit) is blocked until steps 1–10 each have an artifact. The script writes the artifacts list back into `phases[i].evidence[]` on commit.

---

## 5. Top 3 failure modes + mitigations

### F1 — Stale tracker pinned to wrong phase after a Windows post-commit hook silently failed

**Mitigation:** `prime_status.py` always cross-checks:
- `plan.sha256` vs current master plan sha
- `freshness.git_head` vs `git rev-parse HEAD`
- `freshness.active_scope_md.sha256` vs `docs/audit/active_scope.md` sha
- `freshness.last_refresh_at` age (>24h during active work = stale)
If any drift, exit code 1 → STALE → skill auto-runs `prime_refresh.py`. No prose, just rebuild.

### F2 — Skill becomes a tax users disable

**Mitigation:** brief tier (one line, ~30 tokens) is the default for path-glob auto-trigger. Full status only on explicit invocation, keyword, or phase-close intent. Helper scripts run in <2s. References load lazily. No scrolling 2000-line plans into context.

### F3 — False-positive BLOCK on legal phase-introducing-new-subsystem GREENFIELD work

**Mitigation:** `prime_guard.py` reads `drain_coverage.json` row for the subsystem. BLOCK fires only when `coverage != "NONE"` AND `stance == "GREENFIELD"`. Missing row + new subsystem = legal GREENFIELD. The check matches the existing logic in `tools/audit/drain_coverage.py` so the skill never disagrees with the audit tool.

---

## Where I disagree with the obvious-but-wrong defaults

1. **No always-on full status at conversation start.** Wastes context for sessions that touch only a Lua probe or a doc edit.
2. **No model-written tracker.** Sessions can race; prompt drift causes optimistic completion claims. Only the Python tool writes the JSON.
3. **No regex-based D1 header check inside the skill.** That belongs in `tools/audit/drain_coverage.py` and `prime_guard.py`. Regex inside SKILL.md is brittle and bypassable.
4. **No duplicate phase ladder inside SKILL.md.** Reference under `references/phase-ladder.md`, lazy-loaded. Source of truth = master plan file.
5. **No "hotfix mode" boolean** (vs. Gemini's proposal). Hotfixes are normal PARTIAL stance entries with explicit deferral records; a special hotfix state hides the audit trail.
