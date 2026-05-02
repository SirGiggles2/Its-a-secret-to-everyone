# Debate: Improve plan to ship NES Zelda → Genesis port aligned with Prime Directive

**Started:** 2026-05-02
**Rounds:** 2 (cross-critique)
**Style:** thorough
**Mode:** cross-critique
**Advisors:** Codex CLI, Gemini CLI, Sonnet (Agent), Claude/Opus (moderator)
**Word limit:** ~400 per response

## Question

How can we improve the existing two-document plan so that Claude (and Codex / other CLIs) can actually finish this port and stay aligned with the Prime Directive?

## Prime Directive (binding rule)

For this project we MUST do what is best long term, maximally efficient, use best coding practices, match the NES, utilize Genesis strengths, and choose plans that best suit the strengths of Codex + Claude (or other CLIs).

User priority: NES accuracy as spec, plus selected new features (Redux options, optional 4-player Genesis-enhanced mode). Distribution must be a legal builder that extracts from a user-supplied NES ROM.

## Plans Under Review

1. `docs/superpowers/specs/2026-05-02-title-roomrom-full-port-roadmap-design.md` — strategic spec (~470 lines).
2. `docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md` — implementation index, 17 phases plus cross-cutting workstreams (~1800 lines).

Together they define:

- Two-ROM dev split: `Title.md` (frontend) + `RoomRom.md` (gameplay harness), merged into `Final.md` in Phase 12.
- Phase ordering: 0 rename → 1 legal builder → 2 graphics registry → 3 caves → 4 secrets/traversal → 5 dungeon core → 6 Link/items/combat → 7 enemies (parallelizable by family) → 8 bosses (parallelizable per boss) → 9 HUD/options/save → 10 audio → 11 Title.md gap-fill → 12 promotion + Final.md → 13 optional 4-player → 14 quest completion → 15 Genesis optimization (15a inline, 15b post-quest) → 16 hardware/polish → 17 public builder release.
- Probe contract: 1 BizHawk launch per probe, bundled screenshot/SAT/CRAM/plane/state/input log, source ROM SHA + manifest hash + emulator core/version + frame number + target ROM hash + probe script hash recorded.
- Phase close gate: build → probe → screenshot → `superpowers:requesting-code-review` → fix → re-probe → commit.
- Subagent strategy: parallel families for extractors, enemy families, bosses, multiplayer subsystems, builder release shards.
- Promotion gate (Phase 12): module promoted only after 2 green probe runs, no RoomRom-only globals, typed `src/state/` struct, `src/game/<subsystem>/` header, NES provenance recorded.
- 4-player save isolation: NES save slot bytes unchanged, multiplayer-only state in separate versioned SRAM region.
- Reproducibility gate (Phase 17): same NES + same git SHA must produce byte-identical `Final.md`.
- Audio driver decision: keep current custom driver, revisit only if Phase 15 measurements force change.
- Phase 11 reframed as "frontend gap-fill + regression lock" since title/FS already mostly built.

## Codebase / agent constraints

- RoomRom development MUST happen in worktree `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1` (branch `roomrom-s1`); main worktree lacks RoomRom S2+ features. Memory rule `feedback_check_worktree_first` is hard.
- One BizHawk launch per probe, bundled artifacts (memory rule `feedback_one_big_probe`).
- I (Claude) build, launch BizHawk, capture screenshots — never ask user (memory rule `feedback_builder_role`).
- Dispatch parallelism via `superpowers:dispatching-parallel-agents` and `superpowers:subagent-driven-development`.
- Code/data classification: owned C = real code, `gen/` is passive, ASM only for boot/IO/hot paths, promote by family (memory rule `project_best_practices`).

## Asks of each debater

- Identify the highest-impact gaps in current plan.
- Identify risks that could block shipping or break NES parity.
- Recommend concrete additions/changes (specific phase, specific task).
- Call out parts that align with Codex+Claude strengths poorly and propose better task shapes.
- Cross-critique: in round 2, name specific points from other debaters you agree/disagree with and why.
