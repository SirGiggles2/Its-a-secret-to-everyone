# SONNET ADVISOR — Round 1

## Position: Drain-first is non-negotiable. Phase 3 as written burns weeks rebuilding shipped code.

Prime Directive says max efficient + best long-term. Memory `feedback_source_first_then_nes` already mandates "read source before capture". Drained C IS source. Master plan Phase 3 ignoring `cavert_*` violates both.

---

## Answers

### 1. Phase header line format
```
**Drain coverage**: `src/game/<subsystem>/<file>.c` — functions: `foo_*`, `bar_*` | NES ref: `reference/aldonunez/<file>.asm` lines NNN-MMM
```
Mandatory. Empty = "verified greenfield" with audit link.

### 2. Phase 3 Task 3.4 rewrite
**OLD**: "Render Cave Interior — implement BG draw + person sprite"
**NEW**: 
```
Task 3.4 — Verify + wire Cave Interior render
Drain coverage: src/game/cave/cave_runtime.c::cavert_draw_cave_person, cavert_draw_cave_items
NES spec: reference/aldonunez/z1.asm DrawCavePerson + DrawCaveItems
Steps:
  a. Read drained C, list outputs (VRAM writes, OAM, palette).
  b. Diff vs NES disasm — flag deltas in audit.
  c. If parity: wire into mode dispatch, ship.
  d. If drift: fix drain (don't rewrite), re-verify.
```

### 3. Audit deliverable structure
**Pick: per-subsystem files** under `docs/audit/drain/<subsystem>.md` (cave.md, world.md, items.md, etc.). 
- Per-phase = stale the moment scope shifts.
- Per-NES-file = too granular, NES file boundaries don't match Genesis subsystems.
- Per-subsystem = matches `src/game/*/` layout, matches how Codex/Claude navigate, survives re-phasing.

Index file `docs/audit/drain/INDEX.md` maps subsystem → phases that touch it.

### 4. Verification step
**Pick: per-function diff** as gate, per-scenario parity oracle as smoke test.
- Per-RAM-cell trace = too noisy, drowns signal.
- Per-scenario alone = misses dead-code drift.
- Per-function: read drained C signature + body, read NES asm sub, write 3-line "matches/diverges/unknown" verdict in audit. Cheap, repeatable, LLM-friendly.

### 5. `tools/audit/drain_coverage.py`
Scans: `src/game/**/*.c` for function defs matching drain naming (`*_init_*`, `*_draw_*`, `*_update_*`, `cavert_*`, `uwpers_*`, etc.); cross-refs `reference/aldonunez/**.asm` symbol table; cross-refs master plan task files for "Drain coverage:" headers.
Emits: 
- `docs/audit/drain/<subsystem>.md` skeleton per subsystem
- `docs/audit/drain/MISSING.md` — drained funcs with no phase reference (orphans)
- `docs/audit/drain/PHANTOM.md` — phase tasks claiming greenfield where drain exists
- exit nonzero if PHANTOM nonempty (CI gate)

### 6. Master plan per-phase rule (copy-paste)
```
RULE D1 (drain-aware planning): Every task MUST declare "Drain coverage" 
header citing src/game/**/*.c functions OR explicit "verified greenfield 
via tools/audit/drain_coverage.py run YYYY-MM-DD". NES disassembly cited 
as secondary spec for verification. Tasks failing audit = blocked.
```

### 7. Memory entry sketch
Title: `feedback_drain_first_disasm_second`
Body: "Master plan tasks must check `src/game/**/*.c` BEFORE claiming greenfield. Drained C = primary resource, NES asm = verification spec. Run `tools/audit/drain_coverage.py` before drafting any phase task. Phase 3 caves taught this — `cavert_*` shipped pre-S0, plan ignored it."

### 8. CLAUDE.md addition
```
## Drain awareness (HARD)
Before drafting/executing any task: grep src/game/**/*.c for matching 
function names. Cite drain coverage in task header. NES disasm is 
verification spec, drained C is implementation source. Re-implementing 
what's drained = banned without audit proving drift.
```

### 9. Phase 3 minimum rewrite (3.1-3.10)
- 3.1 — DELETE "Generate caves.json from scratch". REPLACE: "Audit cave_runtime.c data tables, extract to caves.json IF not already in src/game/cave/data."
- 3.2 — Audit `cavert_init_cave` vs NES `InitCave`.
- 3.3 — Audit `cavert_draw_cave_person` vs NES.
- 3.4 — Wire (not implement) cave render into mode dispatch.
- 3.5 — Audit `cavert_update_person_state_textbox` (textbox flow).
- 3.6 — Audit `cavert_update_transfer_prices` + `cavert_try_take_item`.
- 3.7 — Audit `cavert_update_talk_shop_or_door_charge` (shops EXIST).
- 3.8 — Audit `cavert_update_hint_or_money_game` (gambling EXISTS).
- 3.9 — UW NPC: audit `uw_person_runtime.c` (293 lines drained).
- 3.10 — Integration test + parity oracle scenarios.

### 10. GREEN/YELLOW/RED
**RED**. Phase 3 as written will: (a) duplicate 686 lines of working code, (b) introduce drift between new impl and shipped `cavert_*`, (c) waste 2-3 weeks of Codex/Claude tokens, (d) violate Prime Directive items 3+4 (efficiency + NES accuracy — drift = lost parity). Cannot proceed without RULE D1.

---

Caveman summary: **drain exists. read drain. fix drain. don't rewrite drain.** NES asm tells you when drain lies. That's the whole rule.
