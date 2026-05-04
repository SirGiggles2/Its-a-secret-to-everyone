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
