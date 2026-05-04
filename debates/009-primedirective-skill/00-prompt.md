# Debate 009: /primedirective Mega-Skill Design

## Context

Project: Sega Genesis port of NES Zelda 1. Main worktree at `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY`. Master plan: `docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md` (2171 lines, 18 phases: 0..17).

User wants a single mega-skill named `/primedirective` that:

1. Bundles the **Prime Directive** (NES Zelda 1 = behavioral spec; Genesis-native = implementation; match palette/layout/timing/RAM/sprite-prio/scroll/animation; dump NES ROM ground truth when unclear; long-term root-cause fix; no asking — execute).
2. Bundles the **Master Plan ladder** (Phase 0 → 17, with 1.5 inserted), **Hard Rules** (SGDK-1..5, WT-1..4, D1), **Phase Close Gate**, **Targets** (`Title.md`, `RoomRom.md`, `Final.md`, `tools/builder/`).
3. **Constantly tracks progress** through the master plan — either by **maintaining** a tracker file or by **checking** an existing one each invocation. Must surface: which phase is active, which task within it, what gates are passed/pending, what's blocking, and the next concrete action.
4. Activates on `/primedirective` slash and ALSO auto-loads at conversation start (or anytime work touches phase-relevant paths).

Skill location: `.claude/skills/primedirective/SKILL.md` (project-scoped). Format: Claude Code skill — frontmatter (`name`, `description`, `argument-hint`, `user-invocable`, `disable-model-invocation`) + body.

## Source Material (Authoritative)

### Prime Directive (from `CLAUDE.md` project file)
- NES accuracy is the spec; Genesis-native is the implementation.
- Always pick: best long-term outcome → best coding practice → maximal efficiency → NES accuracy.
- No multi-choice prompts. No "OK to proceed?". User interrupts if wrong.
- When in doubt, dump NES ROM ground truth (CHR/OAM/NT/PALRAM/RAM tables).
- Worktree rule: `git worktree list` before any RoomRom build/edit.
- Active scope pointer: consult `docs/audit/active_scope.md` before edits.
- Substrate ownership: `src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`, `src/audio_driver.asm` edited from `main` only.
- No `whatif.*` emission. `build.bat` emits only `Title.*`.
- Drain coverage: drained C in `src/game/<subsystem>/*_runtime.c` is PRIMARY; NES disasm is SECONDARY (wins ties). 4-line task header: NES source / Drained C / Coverage / Stance. 3-gate verification.

### Master Plan Phases
- **0** Target Rename and Split
- **1** Legal Builder Foundation
- **1.5** NES Reference Capture Harness
- **2** RoomRom Graphics Registry + No-Clobber Foundation
- **3** Overworld Caves
- **4** Overworld Secrets, Traversal, State
- **5** Dungeon Core
- **6** Link, Inventory, Items, Combat
- **7** Enemies by Behavior Family
- **8** Bosses
- **9** HUD, Options, Save, Menus
- **10** Audio Finalization
- **11** Title.md Frontend Gap-Fill + Regression Lock
- **12** Promote RoomRom Core, Integrate Final ROM
- **13** Optional 4-Player Genesis Mode
- **14** Full Quest Completion
- **15** Genesis-Specific Optimization
- **16** Hardware, Performance, Polish
- **17** Public Builder Release

### Hard Rules (Enforcement)
- **SGDK-1..5**: adapter boundary, version pin, hand-rolled VDP gate, audio migration trigger, fork policy.
- **WT-1..4**: substrate single-writer (main only), active-scope pointer, frontend boundary, no-whatif emission.
- **D1**: drain-first, NES-disasm-second, 4-line task header, 3-gate verification.

### Phase Close Gate (Mandatory Order)
1. Build with `REQUIRE_GENERATED_ASSETS=1`.
2. Run focused probe set.
3. Capture screenshot/state evidence; emit parity-oracle-schema instance.
4. Diff schema instances vs `build/generated/nes_reference/`.
5. Run `tools/run_regression_matrix.py` — green required.
6. `tools/state/verify_no_alias_collisions.py --scope <subsystems>` if `src/state/` touched.
7. Confirm `PROBE_CYCLE_LIMIT` envelope.
8. Run `superpowers:requesting-code-review`.
9. Fix findings or record deferrals.
10. Re-run probes + regression matrix.
11. Commit with phase report paths in commit body.

### Targets
- `Title.md` — release frontend
- `RoomRom.md` — gameplay harness
- `Final.md` — phase 12 merged target
- `tools/builder/` — public legal builder pipeline

### Existing Tooling
- `tools/audit/active_scope.py` — emits `.active_scope` + `docs/audit/active_scope.md`
- `tools/audit/drain_coverage.py` — emits `tools/audit/drain_coverage.json`
- `tools/gates/check_substrate_dual_rom.py` — defense-in-depth dual-ROM build
- `tools/gates/check_no_whatif.py` — CI gate
- `tools/gates/check_frontend_boundary.py` — phase 12 hard fail
- `tools/run_regression_matrix.py`
- `tools/parity/diff.py` — RAM/screenshot diff
- `tools/state/verify_no_alias_collisions.py`

## The Question Being Debated

**How should `/primedirective` be designed to MAXIMALLY enforce the Prime Directive AND constantly track master-plan progress, without being so heavyweight that Claude resists invoking it?**

Specifically debate:

1. **Tracker storage format** — single JSON file? Per-phase markdown? Auto-derived from `tools/audit/*.json` + git log? Hybrid?
2. **Tracker freshness check** — when is it stale? How does the skill detect staleness and refresh?
3. **Skill activation pattern** — slash-only? Auto-on-conversation-start? Hook-driven? Triggered by file paths in tool-call context?
4. **Behavioral enforcement** — what specific guardrails does the skill install? How does it block or warn on directive violations (e.g., editing substrate from a non-main worktree, GREENFIELD claim with candidate drain, missing 4-line task header)?
5. **Self-update on phase close** — does the skill itself update the tracker after phase close gate passes? Or does that responsibility live in `tools/`?
6. **Failure modes** — what's the worst way this skill could backfire (false-positive blocking, stale tracker pinning Claude to wrong phase, overhead burnout, etc.)?

## Deliverable

Each provider returns a concrete proposed design including:

- Skill file structure (SKILL.md frontmatter + body outline + any helper files)
- Tracker file schema (literal JSON or markdown template)
- Activation/invocation pattern
- Top 3 enforcement mechanisms
- Top 3 failure modes + mitigations
- Diff against the other providers' designs (Round 2)
