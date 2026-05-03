# Debate 005 — Drain-First / Disassembly-Second Rule: Synthesis

**Date:** 2026-05-02
**Participants:** Codex (CLI), Gemini (CLI), Sonnet (Agent), Opus (architecture lens)
**Mode:** thorough cross-critique, 2 rounds, ~400 words/advisor
**Caveman mode:** active

---

## TL;DR

**RED on current Phase 3** (would duplicate 686 LOC of shipped `cavert_*` + `uw_person_*` drain).
**GREEN on the panel-converged governance** (4-line header + 4-stance enum + 3-gate verification + drain_coverage.py + per-NES-file JSON + per-subsystem .md views).

Unanimous adoption of Opus's r1 framework after r2 cross-critique. Cleanest debate convergence yet.

---

## Resolved divergences (round 2 — Opus framework adopted 4-0)

### 1. Audit structure — **per-NES-source-file JSON canonical + per-subsystem .md views**
- Canonical: `tools/audit/drain_coverage.json` (NES symbol = row; phase, subsystem, drained-C path, coverage, stance = columns)
- Generated views: `docs/audit/drain/<subsystem>.md` for navigation; `docs/audit/drain/by_phase/<N>.md` per planning context
- Companion: `docs/audit/drain/INDEX.md` cross-referencing both projections

Why per-NES-source-file canonical: NES asm is the immutable Prime-Directive spec axis. Phases re-shuffle (S0→S13 already superseded T1→T14 per memory). Subsystem boundaries are our invention. NES symbols are Nintendo's. Anchor to the immutable axis.

### 2. Verification depth — **3-gate LAYERED**
| Gate | When | What | Tool |
|------|------|------|------|
| **Gate 1 (per-function diff)** | Every commit touching drained C | `MATCH \| DIFF(<line>:<asm> vs <line>:<c>) \| UNKNOWN` per drained function vs NES asm | `tools/audit/drain_findings/<phase>_<task>.md` (manual or LLM-assisted) |
| **Gate 2 (per-RAM-cell trace)** | Phase exit | Snapshot named NES RAM cells after N frames; diff Genesis vs NES capture | Existing parity oracle schema (`b476a2a5`); add `ram_cells: [<name>]` per scenario |
| **Gate 3 (per-scenario parity oracle)** | Milestone tag (S2-closed etc.) | End-to-end input scripts; checkpoint screenshot + RAM diff | `tools/parity/diff.py` + Phase 1.5 capture artifacts |

Layered = catches drift at birth (gate 1), state-machine drift mid-flow (gate 2), behavior drift end-to-end (gate 3). Existing infrastructure (parity oracle + capture harness) plugs into governance instead of being ad-hoc.

### 3. Task header format — **4-line machine-checkable**

```markdown
### Task N.M — <name>

- **NES source**: <file>:<symbol> [, <file>:<symbol>...]
- **Drained C**: <path>:<symbol> | NONE
- **Coverage**: FULL | PARTIAL(<what's missing>) | STALE(<what changed>) | NONE
- **Stance**: ADOPT | EXTEND | REPLACE | GREENFIELD
```

Each field is a distinct invariant the tool validates independently. Coverage describes the world (what exists); Stance describes the decision (what you'll do). Collapsing them allows incoherent combinations (e.g., `Coverage: NONE | Stance: ADOPT`).

### 4. Stance enum — **ADOPT / EXTEND / REPLACE / GREENFIELD**
- **ADOPT** — drain logic correct + already wired or trivially wirable. Task body = integration only, no logic rewrite.
- **EXTEND** — drain logic correct, needs Genesis-native swap (replace `_ppu_*` shims with `vdp_*` calls; preserve behavior).
- **REPLACE** — drain demonstrably wrong. Requires evidence pointer: RAM trace, oracle scenario id, or NES asm line number. "I think it's cleaner" is NOT evidence.
- **GREENFIELD** — legal ONLY when `Coverage: NONE` (no candidate drain).

Phase 3 reality: ~90% of cave tasks are EXTEND (drain logic correct, shims need swapping for Genesis VDP). One is GREENFIELD (Task 3.1 data extraction).

---

## Convergence (no dispute, 4-0)

| Item | Resolution |
|------|-----------|
| Master plan per-phase rule | Drained C is PRIMARY implementation evidence; NES disasm is SECONDARY verification + final authority. Drain wins ties on existence; NES wins ties on correctness. |
| `tools/audit/drain_coverage.py` | Scans `src/game/**/*_runtime.c` + `reference/aldonunez/*.asm` + `src/zelda_translated/*.asm` + master plan task headers; emits canonical JSON + Markdown views; fails CI on malformed headers or illegal `Stance: GREENFIELD` where drain exists. |
| Memory entry | `feedback_drain_primary_nes_secondary` |
| CLAUDE.md HARD section | Drop next to existing "Worktree rule (HARD)"; same enforcement bar. |
| Phase 3 rewrite | Only Task 3.1 (data extraction) stays GREENFIELD; 3.2-3.10 become ADOPT/EXTEND with 4-line headers; Task 3.10 = verification-only. |

---

## Concrete deliverables (priority order)

1. **`tools/audit/drain_coverage.py`** — scanner + emitter (canonical JSON + per-subsystem .md views)
2. **Master plan rule (RULE D1)** — per-phase rule + standard 4-line header format
3. **Phase 3 task list rewrite** — apply 4-line headers + ADOPT/EXTEND/REPLACE/GREENFIELD stance to Tasks 3.1-3.10
4. **CLAUDE.md HARD section** — "Drain coverage (HARD)" next to existing rules
5. **Memory entry** — `feedback_drain_primary_nes_secondary`
6. **Initial drain_coverage.json** — first run of the tool, populates per-NES-source-file rows
7. **Per-subsystem .md views** — generated from JSON, one per src/game/<subsystem>/

Phases 4-9 get the same rewrite treatment when each opens — auditor Phase 8/9/10 worktree spec already landed (debate 004); add 4-line headers to those phases too.

---

## Per-task pattern (Task 3.4 example, full)

```markdown
### Task 3.4 — Render Cave Interior

- **NES source**: reference/aldonunez/z1.asm:DrawCave, :DrawCaveContents,
  :Cave_BlitWalls; src/zelda_translated/cave.asm:CaveDraw_*
- **Drained C**: src/game/cave/cave_runtime.c:cavert_init_cave,
  cavert_draw_cave_person, cavert_draw_cave_items;
  src/game/cave/uw_person_runtime.c:uw_person_draw
- **Coverage**: PARTIAL — drain covers wall/floor blit, NPC + item slot
  positions, palette load. MISSING: Genesis VDP plane writes (drain still
  calls `_ppu_write_*` shims), CRAM palette lane assignment for cave
  PAL2/3, scroll register init for cave's fixed-camera mode.
- **Stance**: EXTEND
- **Body**:
  1. Read cavert_draw_cave_person + cavert_draw_cave_items end-to-end.
     Diff against DrawCave / DrawCaveContents in NES asm. Log deltas to
     tools/audit/drain_findings/cave_3_4.md.
  2. Replace `_ppu_write_*` shim calls with `vdp_plane_a_write` /
     `vdp_dma_chr` (Genesis-native swap, behavior preserved).
  3. Wire cavert_init_cave + cavert_draw_* into Phase 3 cave gamemode
     dispatch.
  4. Verify against parity oracle scenario `cave_enter_take_any`.
  5. Gate 1 (per-function diff) green before commit.
  6. If diff in step 1 found drain wrong, file sub-task 3.4a (REPLACE
     that specific function with evidence pointer) — do NOT silently
     rewrite cave_draw_room wholesale.
```

---

## Final stance

| Vote | Stance |
|------|--------|
| Codex | RED on Phase 3 as-is → GREEN with rule |
| Gemini | RED → GREEN with rule |
| Sonnet | RED → GREEN with rule |
| Opus | RED on Phase 3 → GREEN on the framework |

Unanimous: phase 3 (and 4-9 by extension) cannot proceed correctly without RULE D1. The framework is small (4-line header + 4 enums + 1 Python tool + 3-gate verification reusing existing infra) and high-leverage (eliminates duplicate-source-of-truth bugs, plugs existing parity oracle into governance, scales naturally across the four LLM advisors).

---

## Cost / artifacts

- 4 advisors × 2 rounds = 8 advisor outputs
- Round files: `debates/005-drain-coverage-rule/round{1,2}/{codex,gemini,sonnet,opus}.md`
- Synthesis: this file
