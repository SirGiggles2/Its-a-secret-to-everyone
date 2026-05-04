# Debate 009 — Synthesis (Winner)

## Convergence

All four providers agree:

1. **Skill body is thin** (~200 lines max). Phase ladder, hard rules, gate steps live in `references/`, lazy-loaded.
2. **Enforcement scripts live under `tools/`**, not `.claude/`. Skill = behavioral contract; tools = enforcement code.
3. **Tracker is machine-written only.** `prime_refresh.py` is the sole writer. Model never edits tracker fields.
4. **Two-tier surfacing.** BRIEF (~1 line, ≤72 chars) for path-trigger; FULL (~25 lines max) for explicit/keyword/phase-close.
5. **No always-on conversation start.** Auto-trigger fires only on phase-relevant context.
6. **Multi-signal staleness check.** Plan SHA, git HEAD, evidence path existence, audit JSON SHA, 24h age, complete-without-successor invariant.
7. **D1 4-line header is enforced**, not advisory.
8. **Out-of-phase work has a sanctioned audit-trail path** (`out_of_phase_tasks[]`), not a hotfix boolean.
9. **Phase close gate is 11 ordered steps**, blocked at step 11 commit until 1–10 each have a recorded artifact.

## Resolved disagreement: turn-tax

Gemini argued running `prime_guard.py` before every edit doubles tool calls. Opus + Codex argued guard is mandatory. Resolution: **scope the guard to high-risk paths only**.

- Substrate (`src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`, `src/audio_driver.asm`) → guard MANDATORY before write.
- `src/game/<subsystem>/` → guard MANDATORY (D1 header check + scope-lock).
- `build.bat`, `tools/builder/` → guard MANDATORY (whatif emission check).
- `Title.md`, `RoomRom.md`, `Final.md` build artifacts → guard MANDATORY.
- Lua probes, doc edits, RoomRom worktree files, generated assets → no guard.

Guard scope is enumerated in `tools/gates/prime_guard.py` itself, not in SKILL.md prose. The skill says "run guard before edit if path matches the high-risk list defined in prime_guard.py".

## Resolved disagreement: stored vs derived tracker

Sonnet pure-derived; Opus stored + derived hybrid; Gemini converged on hybrid in R2. Codex always wanted hybrid. Winner: **hybrid cache**.

- **Stored fields** (decision artifacts, can't be re-derived): `phases[i].close_gate.<step>` booleans, `deferrals[]`, `out_of_phase_tasks[]`, `scope_lock`, `phases[i].evidence[]` paths.
- **Derived fields** (recomputed every `prime_status.py` call): `active.phase_id`, `active.task_id`, `active.worktree`, `freshness.*`, `blockers[]`.
- **Cross-check invariant**: if derived `active.phase_id` disagrees with stored `phases[i].status` map, exit STALE.

## Final architecture

```
.claude/skills/primedirective/
  SKILL.md                       behavioral contract, ~200 lines
  references/
    prime-directive.md           canonical NES-spec / Genesis-impl text
    phase-ladder.md              0..17 with one-line summaries + plan offsets
    hard-rules.md                SGDK-1..5, WT-1..4, D1
    phase-close-gate.md          11-step ordered checklist
    targets.md                   Title.md / RoomRom.md / Final.md / tools/builder/

tools/audit/primedirective/
  prime_status.py                read-only; FRESH | STALE | BLOCKED; BRIEF | FULL
  prime_refresh.py               mutating; --refresh; rebuilds tracker
  schema.json                    jsonschema for tracker

tools/gates/
  prime_guard.py                 --intent edit|build|close-phase --paths <p>

docs/superpowers/
  prime_directive_tracker.json   hybrid cache (machine-written)
  prime_directive_status.md      generated human report
```

## Activation

| Source | Tier | Notes |
|---|---|---|
| `/primedirective` | FULL | explicit |
| `/primedirective --brief` | BRIEF | scripted |
| Keyword: "phase close / what's blocking / next task / what phase / close phase / prime directive" | FULL | semantic |
| First tool call in session matching phase-relevant path glob | BRIEF | once per session |
| Conversation start | none unless first user message matches phase-relevant context | reduces token waste |

## Tracker JSON (final shape)

```json
{
  "$schema": "tools/audit/primedirective/schema.json",
  "schema_version": 1,
  "generated_at": "ISO-8601",
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
    "worktree": {
      "path": "<abs path>",
      "branch": "main",
      "is_substrate_writer": true
    },
    "next_concrete_action": "..."
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
        {"id": "1.5.2", "title": "Capture baseline reference",
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

  "scope_lock": {
    "active_task_only": true,
    "allowed_escape_hatches": ["blocking_fix", "phase_close_gate", "user_interrupt"],
    "requires_tracker_note": true
  },

  "out_of_phase_tasks": [],
  "deferrals": [],

  "freshness": {
    "active_scope_md": {"path": "docs/audit/active_scope.md", "sha256": "<h>", "ok": true},
    "drain_coverage_json": {"path": "tools/audit/drain_coverage.json", "sha256": "<h>", "ok": true},
    "git_head": "<sha>",
    "dirty_paths_relevant": [],
    "evidence_paths_present": true,
    "complete_phase_invariant_ok": true,
    "last_refresh_at": "ISO-8601",
    "stale_reasons": []
  },

  "blockers": []
}
```

## BRIEF format (literal, hard limit ≤72 chars)

```
[PD] Ph{N} · task {T} · WT {worktree} · {p}/{t} gates · {n} blocking
```

Append ` ← CHECK` if `{n} > 0`. Append ` ← STALE` if freshness fails. Append ` ← OUT-OF-PHASE` if active out_of_phase_tasks entry.

## Top 5 enforcement mechanisms (final)

1. **Multi-signal freshness** (`prime_status.py`) — STALE = no progress claim allowed.
2. **Pre-edit guard for high-risk paths** (`prime_guard.py --intent edit`) — substrate, src/game/, build.bat, build artifacts.
3. **D1 4-line header content check** (`prime_guard.py --check-content`) — regex on first 8 lines of `src/game/**/*` writes.
4. **Phase-close gate runner** (`prime_guard.py --intent close-phase`) — 11 steps, ordered, artifact-required.
5. **Scope lock** (tracker `scope_lock` + guard) — warns when edits fall outside active task scope unless escape hatch declared.

## Top 5 failure modes (final, with mitigations)

1. **Stale tracker pinned to wrong phase** → multi-signal freshness, evidence-path existence check, complete-without-successor invariant, auto-rerun `prime_refresh.py` on STALE.
2. **Skill becomes a tax → users disable** → BRIEF tier ~30 tokens, guard scoped to high-risk paths only, refs lazy-loaded.
3. **False-positive GREENFIELD block on legal new-subsystem work** → guard reads `coverage` field of drain_coverage row; missing row = legal GREENFIELD; only `coverage != NONE && stance == GREENFIELD` → BLOCK.
4. **Out-of-phase work hidden in unrelated commits** → `out_of_phase_tasks[]` array required entry; regression matrix run mandatory before next FRESH status.
5. **Skill claims tool-call interception it cannot enforce** → SKILL.md states "guard is a pre-action contract"; real interception via pre-commit hooks calling `prime_guard.py`; CI calls also for substrate, no-whatif, frontend boundary.

## Build order

1. Skill body + frontmatter (`SKILL.md`).
2. Five reference files (`references/*.md`).
3. Tracker JSON schema (`tools/audit/primedirective/schema.json`).
4. Initial tracker bootstrap (`docs/superpowers/prime_directive_tracker.json`) — minimal, derived from current state.
5. `prime_status.py` (read-only, multi-signal freshness, BRIEF/FULL output).
6. `prime_refresh.py` (mutating, rebuilds tracker from authoritative inputs).
7. `prime_guard.py` (pre-edit / pre-build / pre-close-phase guard, scoped to high-risk paths).
8. Generated `prime_directive_status.md` rendered from tracker.
9. Smoke test: `python tools/audit/primedirective/prime_status.py --brief` returns FRESH + a one-line BRIEF.
10. Commit.
