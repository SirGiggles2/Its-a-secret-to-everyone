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
