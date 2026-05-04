# Round 2 — SONNET critique + revised position
# Debate 009: /primedirective Mega-Skill Design

---

## Critiques of the other three positions

---

### CODEX R1

**Concrete flaw:** Codex puts `prime_guard.py`, `prime_status.py`, and `prime_refresh.py` under `.claude/skills/primedirective/scripts/` — inside the skill directory itself. This violates substrate locality and creates a maintenance seam: tools that enforce project-level invariants (substrate ownership, drain coverage, gate ordering) should live under `tools/audit/` or `tools/gates/` alongside their sibling scripts (`check_substrate_dual_rom.py`, `check_no_whatif.py`, `check_frontend_boundary.py`). Putting enforcement scripts inside `.claude/` means they run under CI only if CI explicitly knows to look in `.claude/`, which it currently does not. Gate scripts placed inside `.claude/` are effectively invisible to `build.bat` and `tools/run_regression_matrix.py`. Codex's own text says "For actual blocking, rely on scripts and CI gates" — but the scripts can't participate in CI from that location.

**What Codex got right that beats my R1:** The freshness-check signal list is materially more complete than mine. Codex enumerates: plan hash, git HEAD, dirty paths hash, active scope hash, drain coverage hash, evidence file existence check (referenced paths no longer exist), and the 24-hour age rule. My R1 only called out "generation timestamp vs. most recent phase-close commit." Codex's multi-signal staleness detection is strictly more robust — a tracker can be freshly timestamped but reference a deleted evidence file, and my timestamp-only check misses that.

**Single change I adopt:** Add evidence-file existence check to staleness detection. The derived state (`active_scope.md`) is not sufficient alone; if a gate says `evidence: ["tools/parity/schema.json"]` and that file has been deleted, the tracker is stale regardless of timestamp. I will incorporate this into my revised staleness logic.

---

### GEMINI R1

**Concrete flaw:** Gemini's SKILL.md body tells the model to run `tools/audit/active_scope.py` "on every invocation" as an **invocation-time side-effect that mutates project state**. This conflates read and write. `active_scope.py` regenerates `.active_scope` and `docs/audit/active_scope.md` — it is a mutating tool, not a status reader. Running a mutating tool on every `/primedirective` call, including mid-task calls, is incorrect: the active scope is locked by phase and should only regenerate on phase transitions, not on arbitrary skill invocations. Triggering it every time also races with any other process that reads `.active_scope` (e.g., a running build). The mechanism Gemini describes (line: "On every invocation, run `tools/audit/active_scope.py` to sync `.active_scope`") would thrash the file during active sessions.

**What Gemini got right that beats my R1:** Gemini explicitly calls out the `Hotfix` state problem — a rigid phase lock that prevents emergency bug fixes in a closed phase. My R1 does not address this at all. The scenario is real: a shipping blocker in Phase 2 code needs to be fixed during Phase 4 work. Without a sanctioned path, the model either breaks the phase lock (losing the audit trail) or refuses to fix the bug (blocking the project). Gemini's mitigation — a `Hotfix` state that runs regression but doesn't trigger full re-validation — identifies the right tension. My R1's "PARTIAL stance + explicit deferral record" (borrowed by Opus) is a correct alternative, but I failed to document it as a first-class design element.

**Single change I adopt:** Add explicit documentation to the tracker schema for "out-of-phase surgical edits" — not a special `Hotfix` boolean (Opus correctly rejects that), but a first-class `out_of_phase_tasks` array under the active phase entry, with mandatory fields: `target_phase_id` (the phase whose code is being touched), `reason`, `stance` (MUST be PARTIAL or REPLACE, never GREENFIELD), `regression_matrix_required: true`. This gives the audit trail Gemini wants without the hidden-state problem of a boolean flag.

---

### OPUS R1

**Concrete flaw:** Opus's SKILL.md `description` frontmatter includes a very long path glob list intended to trigger auto-invocation via `disable-model-invocation: false`. The problem is that Claude Code's auto-invocation for skills is triggered by the `description` field matching the context — but the skill runtime does not do glob-pattern matching on file paths in tool calls. The `disable-model-invocation: false` flag allows the model to invoke the skill, but the model must decide to do so based on the `description` text. Opus's description is written as if the runtime will mechanically match `src/**` paths to trigger the skill; in practice, the model reads the description and uses judgment. This means the "auto-trigger on first tool call hitting a phase-relevant path" behavior Opus describes is not mechanically guaranteed — it depends on the model noticing and deciding to invoke, which is exactly the unreliable mechanism both Opus and I said we wanted to replace. Opus correctly names this in the failure modes section ("Skill becomes a tax users disable") but does not resolve the fundamental unreliability of description-text-based path matching.

**What Opus got right that beats my R1:** The two-tier surfacing (BRIEF vs FULL) is more precisely specified than my R1. Opus defines BRIEF as a single formatted line: `[PD] Phase {id} {name} · task {tid} · WT {worktree} · gates {p}/{t} · blocking {n}`. My R1 has the same concept but never commits to a literal format. Opus also separates trigger sources by verbosity tier in a table, which makes the behavior predictable: path-glob auto = BRIEF, keyword + explicit = FULL, conversation start = none unless relevant. This is cleaner than my R1's informal description. The concrete token budget "~30 tokens for BRIEF" is the right design discipline.

**Single change I adopt:** Commit the BRIEF format literally in my design, and add an explicit budget constraint: BRIEF MUST fit in one line, ≤ 60 characters excluding the `[PD]` prefix. Full status block MUST stay under 25 lines. If either limit would be violated, truncate gate list to "N passed, M pending" rather than enumerating. This prevents status block creep as gates multiply across the 18 phases.

---

## REVISED POSITION (delta from R1 only)

My core thesis from R1 is unchanged: **thin skill, auto-derived state, no hand-maintained tracker, tools maintain state not the skill**. The four specific changes below are what R1 lacked.

---

### Delta 1: Multi-signal staleness (from Codex critique)

R1 staleness detection relied on: `active_scope.md` generation timestamp vs. newest phase-close commit in `git log`.

**Revised staleness signals** (all must pass; any failure = STALE):
1. `active_scope.md` generation timestamp newer than newest `git log --grep="phase.*close"` entry. *(R1)*
2. `drain_coverage.json` SHA unchanged since last status check. *(new)*
3. Master plan file SHA unchanged — if the plan changes, derived phase names may be wrong. *(new)*
4. All evidence file paths referenced in the derived gate state actually exist on disk. *(new — from Codex)*
5. `git_head` unchanged — any commit since last status may have altered phase-relevant files. *(new)*

The derived-state approach still wins over a hand-maintained tracker, but I was under-specifying what "fresh" means. `check_phase.sh` (my R1 helper) is promoted to `check_phase.py` and gains the multi-signal check. It remains read-only; it never mutates.

---

### Delta 2: Out-of-phase surgical edit path (from Gemini critique)

R1 had no sanctioned path for "Phase N work needs a bug fix in Phase N-2 code." This silence forces the model to either break the phase lock silently or refuse valid work.

**Revised**: The derived state surface gains a first-class concept of `out_of_phase_tasks`. When the model detects it needs to edit a closed-phase path:

1. It must emit: `[PD] OUT-OF-PHASE EDIT · target_phase={id} · reason={one line} · stance=REPLACE|PARTIAL · regression required`.
2. The stance MUST be REPLACE or PARTIAL. GREENFIELD and ADOPT are prohibited for closed-phase edits.
3. After the edit, `python tools/run_regression_matrix.py` is mandatory before the next conversation-start `/primedirective` invocation is considered FRESH.
4. The edit is logged as a deferral row in the active phase's derived state, annotated with the target phase ID. `active_scope.py` is updated to write these deferral rows when it detects cross-phase path violations in git blame since the last phase-close tag.

This is **not** a hotfix boolean. It is a recoverable audit trail path, discoverable from git history, not stored in a separate flag field.

---

### Delta 3: BRIEF format hardened (from Opus critique)

R1 defined the abbreviated trigger form informally.

**Revised BRIEF format** (literal, mandatory):
```
[PD] Ph{N} · task {T} · WT {worktree} · {p}/{t} gates · {n} blocking
```
Maximum 72 characters total. If `{n} > 0`, append ` ← CHECK` as a visual alarm. Examples:
```
[PD] Ph2 · task 2.3 · WT RoomRom · 0/11 gates · 0 blocking
[PD] Ph4 · task 4.7 · WT main · 3/11 gates · 1 blocking ← CHECK
```

Full status block is capped at 25 lines. Gate list in the full block shows "N passed (see tracker), M pending: [first 3 gate names]..." if total exceeds 6 items. This prevents the status block from becoming a scrollable wall as the project matures.

---

### Delta 4: Enforcement scripts placed under `tools/` not `.claude/` (from Codex critique)

R1 had `helpers/check_phase.sh` and `helpers/fmt_status.py` under `.claude/skills/primedirective/helpers/`. This was already a concession; Codex's flaw points to the correct placement.

**Revised placement**:
```
tools/audit/primedirective/
  prime_status.py        read-only; multi-signal freshness check
  prime_refresh.py       mutating; NOT called on every invocation (only on STALE)
tools/gates/
  prime_guard.py         pre-edit enforcement; called before Edit/Write to phase-relevant paths
```

SKILL.md references these as `python tools/audit/primedirective/prime_status.py` and `python tools/gates/prime_guard.py`. This makes them visible to `build.bat`, `tools/run_regression_matrix.py`, and any future CI that walks `tools/gates/`. The `.claude/skills/primedirective/` directory contains only SKILL.md and `references/` (lazy-loaded documents, not scripts). Clean separation: skills = behavioral contracts; tools = enforcement machinery.

---

### What did NOT change from R1

- No hand-maintained tracker.json written by the model or the skill. Only `prime_refresh.py` writes state, and only when invoked explicitly (STALE condition) or by the post-commit hook.
- Activation: explicit + threshold-trigger + keyword, NOT always-on at conversation start.
- GREENFIELD block logic: missing row = no constraint; row with `coverage != NONE` + `stance == GREENFIELD` = BLOCK.
- Phase close: 11-step gate, ordered, step 11 commit required before phase marked closed.
- No duplicate of the 18-phase ladder inside SKILL.md. Reference file only, loaded lazily.
- No regex-based D1 header check inside SKILL.md. That lives in `prime_guard.py`.
