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

No other providers’ designs are visible in Round 1, so I cannot diff directly yet. My expected distinction: I reject “one giant SKILL.md” and “tracker only from git log.” I also reject per-phase Markdown as canonical state. My design uses JSON for machine enforcement, generated Markdown for human scanning, and helper scripts for anything that must be reliable.