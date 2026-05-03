# OPUS ADVISOR — Round 1

**Lens**: architecture-first (dependency graph, source-of-truth hierarchy, drift detection)
**Prime Directive anchors**: best long-term outcome, best practices, NES accuracy as spec, Genesis-native impl, plans suiting Codex+Claude+Gemini+Copilot strengths.

---

## Framing — the architectural problem

The master plan was written assuming a clean dependency graph:

```
NES disasm (spec)  ──►  master plan task  ──►  new C/ASM (impl)  ──►  ROM
```

Reality has a hidden node already wired in:

```
NES disasm (spec)
      │
      ▼
  drained C  ◄── (pre-S0/S1, transpile_6502.py + manual cleanup)
      │
      ▼
  master plan task pretends this doesn't exist  ──►  duplicate impl  ──►  ROM with two cave renderers
```

Two source-of-truth nodes for the same behavior is the worst long-term outcome: drift, double-maintenance, and silent divergence when one is patched and the other isn't. The fix is **not** to delete the drain — drained C is the closest thing we have to a proven Genesis-native port — but to make the master plan **address** it: every task either *adopts*, *replaces*, or *rejects* the drained version, with evidence.

Source-of-truth hierarchy I am proposing:

1. **NES disassembly** (`reference/aldonunez/*.asm`, `src/zelda_translated/*.asm`) — spec, immutable.
2. **Drained C** (`src/game/<subsystem>/<file>_runtime.c`) — primary impl candidate; presumed correct until proven wrong against (1).
3. **New native code** — only when drain is missing OR drain fails verification against (1).

Drain is *primary resource* (you read it first, you build on it) but *secondary authority* (NES asm wins ties).

---

## ASK 1 — Phase N task header standard line format

Every task gets a four-line drain-coverage header before the body:

```markdown
### Task N.M — <name>

- **NES source**: <file>:<symbol> [, <file>:<symbol>...]
- **Drained C**: <path>:<symbol> | NONE
- **Coverage**: FULL | PARTIAL(<what's missing>) | STALE(<what changed in NES since drain>) | NONE
- **Stance**: ADOPT | EXTEND | REPLACE | GREENFIELD  (justify if not ADOPT)
```

Rules:
- `Coverage: NONE` is the **only** legal precondition for `Stance: GREENFIELD`. Anything else = you must read the drain first.
- `Stance: REPLACE` requires a one-line evidence pointer (RAM-cell trace, parity-oracle scenario id, or NES-asm line number) showing the drain is wrong.
- `Stance: EXTEND` is the default when `Coverage: PARTIAL`.
- `ADOPT` means task body is integration/wiring only — no rewriting drained logic.

This header is machine-checkable (see ASK 5).

---

## ASK 2 — Convert Phase 3 Task 3.4 into drain-aware shape

**Before** (current master plan, paraphrased):
> Task 3.4 — Render Cave Interior. Implement cave room rendering: walls, floor tiles, NPC sprite slots, item-for-sale slots. Use `caves.json` from Task 3.1.

**After** (drain-aware):

```markdown
### Task 3.4 — Render Cave Interior

- **NES source**: reference/aldonunez/z1.asm:DrawCave, :DrawCaveContents,
  :Cave_BlitWalls; src/zelda_translated/cave.asm:CaveDraw_*
- **Drained C**: src/game/cave/cave_runtime.c:cave_draw_room (393 lines covers
  blit + NPC slot layout + item slot layout); src/game/cave/uw_person_runtime.c
  :uw_person_draw (293 lines covers NPC sprite resolution).
- **Coverage**: PARTIAL — drain covers wall/floor blit, NPC+item slot
  positions, palette load. MISSING: Genesis VDP plane writes (drain still
  calls `_ppu_write_*` shims), CRAM palette lane assignment for cave PAL2/3,
  scroll register init for cave's fixed-camera mode.
- **Stance**: EXTEND
- **Body**:
  1. Read `cave_draw_room` end-to-end. Diff against `DrawCave` in NES asm —
     log any divergence to `tools/audit/drain_findings/cave_3_4.md`.
  2. Replace `_ppu_write_*` shim calls with `vdp_plane_a_write` /
     `vdp_dma_chr` (Genesis-native swap, behavior preserved).
  3. Wire `cave_draw_room` into the Phase 3 cave gamemode dispatch (Task 3.2).
  4. Verify against parity oracle scenario `cave_enter_take_any` (ASK 4).
  5. If diff in step 1 found drain-wrong, file sub-task 3.4a (REPLACE that
     specific function) — do NOT silently rewrite cave_draw_room wholesale.
```

The shape is: *read drain → diff vs NES → swap shims, not logic → verify → only rewrite under evidence*. This is the same discipline already encoded in `feedback_long_term_fix` and `feedback_check_dont_guess`.

---

## ASK 3 — Audit deliverable: granularity choice

Three candidates:

| Granularity | Pro | Con |
|---|---|---|
| Per-phase | Cheap, one row per master plan phase | Hides which subsystem within a phase is covered |
| **Per-NES-source-file** | Matches the spec axis (NES asm is source of truth); each row is "is `cave.asm` covered, by what?" | Some NES files span multiple phases — needs cross-ref column |
| Per-subsystem | Matches our `src/game/<subsystem>/` layout | Subsystem boundaries are *our* invention, not NES's; risk of mis-binning |

**Pick: per-NES-source-file, with phase + subsystem as columns.** Rationale: NES disasm is the immutable axis (Prime Directive: "NES accuracy as spec"). Phases and subsystems are our choices that may shift; the audit shouldn't have to be rewritten when we re-shuffle phases.

Sketch (`tools/audit/drain_coverage.json`, regenerated by ASK 5 tool):

```json
{
  "schema_version": 1,
  "generated_at": "2026-05-02T...",
  "rows": [
    {
      "nes_file": "reference/aldonunez/z1.asm",
      "nes_symbol": "DrawCave",
      "nes_lines": "12044-12198",
      "drained_c": "src/game/cave/cave_runtime.c:cave_draw_room",
      "drained_loc": 154,
      "coverage": "PARTIAL",
      "missing": ["vdp_writes", "cram_pal2_assign"],
      "phase": "3",
      "task": "3.4",
      "subsystem": "cave",
      "stance": "EXTEND",
      "last_diff_audit": "2026-05-02"
    },
    ...
  ]
}
```

Companion human-readable view: `tools/audit/drain_coverage.md` — one section per phase, one table per subsystem, generated from the JSON.

---

## ASK 4 — Verification: which parity layer?

Three candidate layers, all useful, but cost differs:

1. **Per-function diff** (drained C semantics vs NES asm semantics) — cheap, narrow, catches drain-bugs but not integration bugs.
2. **Per-RAM-cell trace** (run NES + Genesis side-by-side, snapshot named RAM after N frames, diff) — medium cost, catches state-machine drift.
3. **Per-scenario parity oracle** (full input script: "boot → enter cave 1 → buy candle → exit", screenshot + RAM diff at checkpoints) — expensive, catches behavior drift.

**Pick: layered, in this order, per task.**

- **Gate 1 (mandatory, every drain-aware task):** per-function diff in the task header's audit step. Output: `tools/audit/drain_findings/<phase>_<task>.md` with `MATCH | DIFF(<line>:<asm> vs <line>:<c>)`.
- **Gate 2 (mandatory before phase exit):** per-RAM-cell trace for the named RAM the phase touches. We already have the parity-oracle schema (`commit b476a2a5`) — extend it with a `ram_cells: [<name>]` field per scenario.
- **Gate 3 (mandatory before milestone tag, e.g. S2-closed):** per-scenario parity oracle for ≥1 end-to-end scenario per subsystem.

Why layered: gate 1 is fast enough to run on every commit (drain didn't drift). Gate 2 is the existing oracle pipeline. Gate 3 is the BizHawk + screenshot ritual we already do but unstructured. Codifying the layers stops "I diffed the function, looks fine, ship it" — which is how the drain *got* the shim-coupling problem in the first place.

---

## ASK 5 — `tools/audit/drain_coverage.py` — what scans + emits

**Inputs:**
- `src/game/**/*_runtime.c` (drained C corpus)
- `reference/aldonunez/*.asm`, `src/zelda_translated/*.asm` (NES spec)
- `master_plan.md` (or wherever Phase tasks live)
- `tools/canonical_structure.json` (existing, from `commit 8d557543`) for symbol cross-ref
- Existing `tools/parity_oracle/scenarios/*.json` for gate-2/3 cross-ref

**Scans:**
1. For every `*_runtime.c`: extract function symbols, line counts, and any `// NES: <symbol>` provenance comments.
2. For every NES asm symbol called out in canonical structure: check if a drained-C function names it in a provenance comment OR matches by name heuristic (`DrawCave` ↔ `cave_draw_room`).
3. For every master-plan task with the four-line header: verify `Drained C:` path exists, `NES source:` symbol exists in asm, `Coverage:` field is one of the legal enum values, `Stance:` matches the rules in ASK 1.
4. For every drained-C function: check whether it still calls `_ppu_*` / `_apu_*` shims (= still needs Genesis-native swap, contributes to `Coverage: PARTIAL → missing: [vdp_writes]`).
5. Cross-ref against parity oracle: which drained functions are exercised by which scenarios?

**Emits:**
- `tools/audit/drain_coverage.json` (machine, schema in ASK 3)
- `tools/audit/drain_coverage.md` (human, per-phase per-subsystem tables)
- `tools/audit/drain_orphans.md` — drained C with no master plan task pointing at it (= dead code or hidden coverage we forgot)
- `tools/audit/master_plan_orphans.md` — master plan tasks claiming `Coverage: NONE` where the tool found a candidate drain (= header is wrong, task author didn't grep)
- Exit code: non-zero if any header is malformed or any `Stance: GREENFIELD` has a candidate drain — wire into pre-commit later.

This is the drift-detection node the architecture is missing.

---

## ASK 6 — Master plan per-phase rule (copy-paste)

```markdown
## Drain-coverage rule (applies to every Phase and every Task)

Before opening any task in this phase:

1. Run `python tools/audit/drain_coverage.py --phase <N>`. Read the
   per-subsystem table.
2. For each task, fill the four-line drain-aware header (NES source /
   Drained C / Coverage / Stance) BEFORE writing the task body. The header
   is machine-checked; malformed headers fail CI.
3. Drained C in `src/game/<subsystem>/*_runtime.c` is the **primary
   resource** — read it first, build on it. NES disassembly is the
   **secondary authority** — it wins ties and overrides drain when
   verification finds drift.
4. `Stance: GREENFIELD` is legal only when `drain_coverage.py` reports
   no candidate drain for the NES source. Otherwise pick ADOPT, EXTEND,
   or REPLACE.
5. `Stance: REPLACE` requires a one-line evidence pointer (RAM trace,
   oracle scenario id, or NES asm line number) demonstrating the drain
   is wrong. "I think it's cleaner to rewrite" is not evidence.
6. Phase exit gate: per-function diff (gate 1) green for every task in
   this phase, AND per-RAM-cell trace (gate 2) green for the phase's
   named RAM cells. Milestone exit gate adds gate 3 (per-scenario oracle).
```

---

## ASK 7 — Memory entry sketch

```
- [Drain is primary resource, NES disasm is secondary authority](feedback_drain_primary_nes_secondary.md)
  — every master plan task fills the four-line drain-aware header before
  body; `tools/audit/drain_coverage.py` enforces it; drained C in
  src/game/<subsystem>/*_runtime.c presumed correct until per-function
  diff vs reference/aldonunez/*.asm shows drift; GREENFIELD stance illegal
  when a candidate drain exists; cave_runtime.c (393 LOC) +
  uw_person_runtime.c (293 LOC) cover most of Phase 3, do not duplicate.
```

The bullet form fits the existing MEMORY.md cadence and points at a longer note for evidence.

---

## ASK 8 — CLAUDE.md addition (copy-paste, drop under existing "Decisions" or new "Drain coverage" section)

```markdown
## Drain coverage (HARD)

Drained C in `src/game/<subsystem>/*_runtime.c` is the **primary resource**.
NES disassembly (`reference/aldonunez/*.asm`,
`src/zelda_translated/*.asm`) is the **secondary authority** — it wins
ties.

Before any task that touches a subsystem with drained C:

1. `git grep -l _runtime.c src/game/<subsystem>/` — list candidates.
2. Read the drain end-to-end. Do not skim.
3. Fill the four-line task header (NES source / Drained C / Coverage /
   Stance). `GREENFIELD` is illegal when a candidate drain exists.
4. Per-function diff vs NES asm before any rewrite. `REPLACE` requires
   evidence (RAM trace, oracle scenario, or NES line number).

Violations = duplicated implementations + silent drift. See memory:
`feedback_drain_primary_nes_secondary`,
`feedback_long_term_fix`, `feedback_check_dont_guess`.
```

This sits next to the existing "Worktree rule (HARD)" — same tone, same enforcement bar.

---

## ASK 9 — Phase 3 minimum rewrite (Tasks 3.1–3.10)

Headers only (bodies grow per ASK 1). Coverage claims are *initial estimates* — gate 0 of Phase 3 is to run `drain_coverage.py` and correct these.

```markdown
### Task 3.1 — Cave data extraction (caves.json)
- NES source: reference/aldonunez/z1.asm:CaveSpec_*, :CavePalettes,
  :CaveItemPrices, :CaveTextIds
- Drained C: NONE (data extraction, not behavior)
- Coverage: NONE
- Stance: GREENFIELD (legal — pure data pipeline)

### Task 3.2 — Cave gamemode dispatch
- NES source: z1.asm:GameMode_Cave, :CaveInit, :CaveTick
- Drained C: src/game/cave/cave_runtime.c:cave_init, cave_tick
- Coverage: FULL (init + tick), PARTIAL on dispatch wiring
- Stance: ADOPT (init/tick) + EXTEND (wire into Genesis gamemode table)

### Task 3.3 — Cave entry/exit transition
- NES source: z1.asm:EnterCave, :ExitCave; cave.asm:CaveScrollIn
- Drained C: src/game/cave/cave_runtime.c:cave_enter, cave_exit
- Coverage: PARTIAL (logic present, missing Genesis VDP scroll fade)
- Stance: EXTEND

### Task 3.4 — Render Cave Interior
(see ASK 2 — full expanded form)

### Task 3.5 — Cave NPC dialog + text box
- NES source: z1.asm:CaveText_*, :TextBox_Render
- Drained C: src/game/cave/uw_person_runtime.c:uw_person_dialog (partial),
  src/game/hud/text_runtime.c:text_box_draw
- Coverage: PARTIAL (dialog dispatch present, text box renderer drained
  separately in HUD subsystem)
- Stance: EXTEND (cross-subsystem wire-up)

### Task 3.6 — Cave item-for-sale slots + price tags
- NES source: z1.asm:CaveItemSlot, :DrawPrice; cave.asm:CavePriceDigits
- Drained C: src/game/cave/cave_runtime.c:cave_draw_item_slot,
  cave_draw_price; src/game/items/item_runtime.c:item_sprite_resolve
- Coverage: PARTIAL (slot layout + price digits drained; item sprite
  resolution drained but in items subsystem)
- Stance: EXTEND (cross-subsystem)

### Task 3.7 — Cave purchase + rupee deduction
- NES source: z1.asm:CavePurchase, :DeductRupees
- Drained C: src/game/cave/cave_runtime.c:cave_try_purchase;
  src/game/items/inventory_runtime.c:rupee_deduct
- Coverage: FULL (logic), PARTIAL (HUD redraw hook)
- Stance: ADOPT + EXTEND HUD hook

### Task 3.8 — "Take any one" / "Pay me for the door" / "Money making
game" cave variants
- NES source: z1.asm:CaveType_TakeAny, :CaveType_DoorRepair,
  :CaveType_MoneyGame
- Drained C: src/game/cave/cave_runtime.c:cave_variant_dispatch +
  three handlers
- Coverage: FULL — verify against drain_findings/cave_variants.md
- Stance: ADOPT (verification only)

### Task 3.9 — Cave palette load (PAL2/PAL3 lanes)
- NES source: z1.asm:LoadCavePalettes
- Drained C: src/game/cave/cave_runtime.c:cave_load_palettes (uses
  _ppu_palette shim)
- Coverage: PARTIAL (logic correct, needs Genesis CRAM swap)
- Stance: EXTEND (shim swap + lane assignment per CHR-expansion plan)

### Task 3.10 — Phase 3 verification gates
- NES source: N/A (verification phase)
- Drained C: N/A
- Coverage: N/A
- Stance: GREENFIELD
- Gates:
  * Gate 1: drain_coverage.py exit 0 for phase 3
  * Gate 2: parity oracle ram-cell trace green for $00EB (RoomId),
    $0656 (CavePurchaseFlags), $066D (RupeeCount), $0070-$007F (CaveSlots)
  * Gate 3: parity oracle scenarios `cave_enter_take_any`,
    `cave_buy_candle`, `cave_door_repair_pay`, `cave_money_game_win`,
    `cave_money_game_lose` — all green
```

Notable: roughly 6 of 10 tasks change from GREENFIELD to ADOPT/EXTEND. That's the savings.

---

## ASK 10 — GREEN / YELLOW / RED stance

**GREEN.** Strongly.

Reasons (architecture-first):

1. **Eliminates a duplicate-source-of-truth class of bug.** Today's plan would have produced two cave renderers (drain + Phase 3.4 new). One would silently drift. Fixing this *after* shipping = full audit + delete-or-merge migration. Fixing it *now* = a header format and one Python tool.
2. **Makes the dependency graph explicit.** NES asm → drain → impl is the actual graph; the plan was drawn as NES asm → impl. You cannot build correct verification on a wrong graph.
3. **Cheap to enforce.** `drain_coverage.py` is a few hundred lines of grep + AST. Header is four lines. This is the cheapest possible governance for the highest-value invariant ("don't reinvent what's already drained").
4. **Aligns with Prime Directive.** "Best long-term outcome" + "best practices" + "max efficiency" all point the same way: read what exists, verify against spec, swap shims, don't rewrite without evidence.
5. **Aligns with model strengths.** Codex is great at per-function diffs and shim-swaps (ADOPT/EXTEND work). Claude is great at the per-RAM-cell trace logic and oracle scenario design (Gate 2). Gemini is great at the wide audit pass over `*_runtime.c` (Gate 1 batch). Copilot is great at the inline header completion in master_plan.md. The four-line header + four gates split *naturally* across the four agents — that is itself architectural evidence the design is right-shaped.

Risks worth flagging (not blockers):

- **R1: Drain may be wronger than we think.** Mitigation: Gate 1 is mandatory and runs before any ADOPT lands. If drain fails, header flips to REPLACE with evidence — that is the system working, not failing.
- **R2: Header bureaucracy fatigue.** Mitigation: tool fills 80% of the header from the canonical-structure cross-ref; humans only write the Stance line and justification.
- **R3: Cross-subsystem drains (e.g. HUD text box used by cave dialog) need cross-ref.** Mitigation: schema already has `subsystem` column; add `also_used_by: [<task>]`.

No yellow. No red. The cost of *not* doing this is paying for cave_runtime.c twice, then debugging which copy is canonical for the next year.

---

## One-paragraph close

The drain is an unacknowledged node in the project's dependency graph. The master plan currently routes around it, which guarantees duplication and drift. The four-line header + `drain_coverage.py` + three-layer verification gates promote the drain from "hidden inheritance" to "first-class primary resource, NES-asm-checked". This costs ~1 day to set up, saves weeks of rework across phases 3–10, and turns the existing canonical-structure + parity-oracle infrastructure (already committed) into a real governance loop. Ship it.
