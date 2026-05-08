---
name: primedirective
description: |
  Sega Genesis Zelda 1 port — Prime Directive enforcer + master-plan progress tracker.
  Invoke when about to edit project source under src/, RoomRom/, data/, build.bat,
  tools/builder/, when claiming phase progress, before running build.bat or closing a
  phase, or when the user says any of: "phase close / what's blocking / next task /
  what phase / close phase / prime directive / pd". Surfaces active phase + task,
  passed/pending close-gate steps, blockers, NES-ground-truth requirements, worktree
  safety, drain stance, scope lock. Refuses to assert progress without a FRESH tracker.
argument-hint: "[status|refresh|gate|phase|task|why|--full|--brief]"
user-invocable: true
disable-model-invocation: false
---

# /primedirective — Prime Directive enforcer + master-plan tracker

## Operating contract (run on every invocation, in this order)

1. **READ** the tracker:
   ```bash
   python tools/audit/primedirective/prime_status.py --brief
   ```
   Exit code 0 = FRESH. Exit code 1 = STALE. Exit code 2 = BLOCKED.

2. **REFRESH** if STALE:
   ```bash
   python tools/audit/primedirective/prime_refresh.py
   python tools/audit/primedirective/prime_status.py --brief
   ```
   Never claim phase progress while STALE.

3. **EMIT** the status surface (BRIEF for path-trigger, FULL for explicit/keyword/phase-close).

4. **GUARD** before high-risk edits/builds:
   ```bash
   python tools/gates/prime_guard.py --intent <edit|build|close-phase> --paths <p>
   ```
   Honor exit code 2 (BLOCK). Honor exit code 1 (WARN, proceed only with explicit reason).

5. **CITE** tracker fields by name when claiming progress. Never paraphrase.

6. **EXECUTE** the next concrete action immediately. After emitting status, do not stop, do not ask, do not present options. Identify `active.next_concrete_action` (or, if it is generic like "Read status.md", derive the real next step from `phases[active].close_gate` first pending step combined with master-plan §"Current Next Action"). Then start that work in the same response — read the relevant files, run the relevant probes, write the relevant code, commit when done. The user invoking `/primedirective` is a request to advance the phase, not a request for a report. Status emission is a side effect; forward motion is the deliverable.

   Stop conditions (only these):
   - tracker BLOCKED (exit 2) or has entries in `blockers[]`
   - hard-rule refusal triggered (SGDK / WT / D1 / banned-name / GREENFIELD-on-drain)
   - bug-detection branch fires (defer to /chuckle + /octo:debate)
   - next action requires destructive op on shared state (push, force-push, branch delete, external publish)
   - user interrupts

   Otherwise: proceed without prompting. CLAUDE.md "Don't ask. Always pick the option with best long-term outcome / coding practice / efficiency / NES accuracy. Then execute" applies in full.

## Prime Directive (canonical)

**NES Zelda 1 = behavioral spec. Genesis-native = implementation.**

Match palette, layout, timing, RAM, sprite priority, scroll, animation EXACTLY unless explicitly told otherwise.

Decision priority, in order:
1. Best long-term outcome
2. Best coding practice
3. Maximal efficiency
4. NES accuracy

When unclear: **dump NES ROM ground truth** (CHR / OAM / nametable / PALRAM / RAM tables) BEFORE coding. Never guess layout, palette, timing, or animation cadence.

**No multi-choice prompts. No "OK to proceed?".** Pick the path and execute. User interrupts if wrong — that is faster than gating every step.

## Hard rules (refuse to violate)

### SGDK-1..5
- **SGDK-1** Adapter boundary: code under `src/game/`, `src/frontend/` MUST NOT include `<genesis.h>` or write VDP registers directly. Route through `src/sgdk_adapter/`.
- **SGDK-2** Version pin: `tools/sgdk_pin.json`. `build.bat` hard-fails on drift.
- **SGDK-3** Hand-rolled VDP: requires profiled hot path, ≥15% measured improvement, citation of replaced SGDK call, entry in `docs/handrolled_vdp.md`.
- **SGDK-4** Audio migration trigger: ADR + 2-of-4 firing per `docs/audio_migration_trigger.md`.
- **SGDK-5** Fork policy: project owner only; CVE / parity-blocker / reproducibility-break / build-breaker only; <200 LOC patch; lives at `vendor/sgdk-fork/`.

### WT-1..4
- **WT-1** Substrate single-writer: `src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`, `src/audio_driver.asm` edited from `main` worktree ONLY. RoomRom worktrees rebase on `main`.
- **WT-2** Active scope pointer: consult `docs/audit/active_scope.md` before any edit.
- **WT-3** Frontend boundary: `src/game/` and `RoomRom/src/` MUST NOT include `src/frontend/` headers. Phase 12 promotion gate hard-fails.
- **WT-4** Banned legacy build alias: builds emit `Title.*` / `RoomRom.*` / `CombinedDebug.*` exclusively. `tools/gates/check_banned_filename.py` enforces; reintroduction in active code paths is a CI hard-fail.

### D1 — drain-first, NES-disasm-second
- Drained C in `src/game/<subsystem>/*_runtime.c` is **PRIMARY** implementation evidence.
- NES disasm (`reference/aldonunez/*.asm`, `src/zelda_translated/*.asm`) is **SECONDARY** + final authority — wins ties.
- Every task touching a drained subsystem requires the 4-line header:
  ```
  - **NES source**: <file>:<symbol>
  - **Drained C**:  <path>:<symbol> | NONE
  - **Coverage**:   FULL | PARTIAL(<missing>) | STALE(<changed>) | NONE
  - **Stance**:     ADOPT | EXTEND | REPLACE | GREENFIELD
  ```
- `Stance: GREENFIELD` is **illegal** when `tools/audit/drain_coverage.json` shows a candidate row.
- 3-gate verification: per-function diff (every commit) → per-RAM-cell trace (phase exit) → per-scenario oracle (milestone tag).

## Status surface

### BRIEF (auto on path-trigger, ≤72 chars)
```
[PD] Ph{N} · task {T} · WT {worktree} · {p}/{t} gates · {n} blocking
```
Suffixes: ` ← CHECK` if blocking>0; ` ← STALE` if freshness fails; ` ← OUT-OF-PHASE` if active out-of-phase task.

### FULL (explicit + keyword + phase-close, ≤25 lines)
Read `docs/superpowers/prime_directive_status.md` (rendered from tracker by `prime_refresh.py`).

## Auto-activation triggers

| Source | Tier |
|---|---|
| `/primedirective` | FULL |
| `/primedirective --brief` | BRIEF |
| Keyword: "phase close / what's blocking / next task / what phase / close phase / prime directive / pd" | FULL |
| First tool call in session matching `src/**`, `RoomRom/**`, `data/**`, `tools/builder/**`, `tools/debug/**`, `Debug.bat`, `builds/Debug.md`, `docs/superpowers/plans/**` | BRIEF |
| Conversation start | none unless first user message matches phase-relevant context |

## Refusals

- **Refuse** to claim a phase complete or task done without a FRESH tracker (cite tracker fields by name).
- **Refuse** to edit substrate paths from a non-`main` worktree.
- **Refuse** to emit, name, or reference the banned legacy build alias anywhere — build outputs, staging copies, identifiers, comments, or documentation.
- **Refuse** `Stance: GREENFIELD` when drain coverage shows a candidate row.
- **Refuse** to skip steps in the 11-step phase-close gate.
- **Refuse** to read the entire 2171-line master plan inline; load only the active phase section + `references/phase-ladder.md` summary.

## Phase close gate (11 steps, ordered)

See `references/phase-close-gate.md` for the full checklist. The skill refuses to commit a phase-close until all 11 steps have artifacts in `phases[i].evidence[]`.

## Out-of-phase edits (sanctioned path)

When work in active phase requires editing closed-phase code:
1. Emit BRIEF: `[PD] OUT-OF-PHASE Ph{target} ← Ph{active} · stance {S}`.
2. Stance MUST be `PARTIAL` or `REPLACE`. `GREENFIELD` and `ADOPT` are prohibited for closed-phase edits.
3. Run `python tools/run_regression_matrix.py` after the edit. Mandatory before next FRESH status.
4. Append entry to `out_of_phase_tasks[]` via `prime_refresh.py --record-out-of-phase`.

## Bug detection branch

When `/primedirective` detects a bug — symptoms include: failing probe in tracker `phases[i].evidence[]`, `blockers[]` entry of kind `freshness|phase_close|drain_stance`, regression matrix red, parity oracle diff non-zero, build error, or user reports broken behavior — DO NOT attempt direct fix.

Sequence:

1. Invoke `/chuckle` — runs the 4-step debugging protocol (Real Problem → Research → Structural Fix → Verification). Diagnoses root cause; produces structural fix proposal.
2. Invoke `/octo:debate` with the proposed fix as the topic — adversarial 4-way review (Codex / Gemini / Sonnet / Opus) finds wrong assumptions, missed edge cases, ordering risks, scope creep BEFORE implementation.
3. Apply the synthesized fix from `/octo:debate`. Run phase-close gate steps 1–10 against the fix.
4. Record the bug + fix as a `deferrals[]` or `out_of_phase_tasks[]` entry via `prime_refresh.py`.

This pairing (/chuckle + /octo:debate) is mandatory for any bug touching substrate, src/game/, parity oracle, or phase-close gate. Quick-patch shortcut is forbidden — root-cause fix only per Prime Directive priority 1 (best long-term outcome).

## Progressive references

Load only when the question demands depth:

- `references/prime-directive.md` — full canonical text.
- `references/phase-ladder.md` — 0..17 with one-line summaries + plan offsets.
- `references/hard-rules.md` — SGDK-1..5, WT-1..4, D1 with rationales.
- `references/phase-close-gate.md` — 11-step ordered checklist + artifact contracts.
- `references/targets.md` — sole target `Debug.md` + `tools/debug/` build pipeline + retired-alias list.

## Skill ↔ tools split

- **Skill** (`.claude/skills/primedirective/`) = behavioral contract. Tells Claude what to invoke, refuse, cite.
- **Tools** (`tools/audit/primedirective/`, `tools/gates/`) = enforcement code. Callable from CI, pre-commit hooks, `build.bat`, regression matrix.

The skill **never writes** the tracker. Only `prime_refresh.py` writes. Sessions running in parallel can read; only one refresh job writes at a time (advisory file lock).
