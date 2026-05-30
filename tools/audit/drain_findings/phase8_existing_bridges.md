# Phase 0.B — Existing native boss bridge drift audit

**Date:** 2026-05-30
**Phase:** 8 (boss completion)
**Scope:** Per-function extern resolution + stub enumeration across 8
native bridge files vs `src/oracle/enemies/*_runtime.c` drains.

## Method

Per bridge:
1. List every `extern` decl (forward-decl to drained func or other dispatch).
2. Verify each target exists in `src/oracle/enemies/` or
   `src/game/<subsystem>/<...>_dispatch.c`.
3. Check signature matches.
4. Enumerate stub bodies (`return 0u;` / `return;` / empty markers).

## Summary

| Bridge | Status | Stubs | Drift |
|---|---|---|---|
| `boss_dodongo.c` | CLEAN | 0 | 0 |
| `boss_gleeok.c` | CLEAN | 0 | 0 |
| `boss_gohma.c` | CLEAN | 0 | 0 |
| `boss_manhandla.c` | CLEAN | 0 | 0 |
| `boss_patra.c` | CLEAN | 0 | 0 |
| `enemy_boss_bridge.c` (Aqua + Vire + Digdogger init) | CLEAN | 0 | 0 |
| `enemy_lamnola_bridge.c` | 1 STUB | 1 | 0 |
| `enemy_ganon_bridge.c` | 4 STUBS | 4 | 0 |

**Zero drift across 8 bridges.** All non-stub externs resolve to live
drained or dispatch symbols with matching signatures.

## Stubs requiring close

### enemy_lamnola_bridge.c

- **Line 33** `c_anim_write_sprite` — empty body. OAM router not yet
  wired. Comment marks TODO Phase 9. Phase B.9b (Task #15) closes.

### enemy_ganon_bridge.c

- **Line 61** `sprrt_anim_fetch_obj_pos(slot)` — `return 0u;`. Phase
  B.10 (Task #16) closes by forwarding to
  `world/sprite_dispatch.c:sprite_anim_fetch_obj_pos`.
- **Line 67** `lcrt_check_link_collision_preinit(monster_slot)` —
  empty body. Phase B.10 closes by forwarding to
  `link_collision_dispatch.c:52 link_collision_link_be_harmed`.
- **Line 72** `colrt_check_monster_sword_collision(monster, weapon)`
  — empty body. Phase B.10 closes by forwarding to
  `collision_dispatch.c collision_check_monster_sword_collision`.
- **Line 79** `colrt_check_monster_arrow_or_rod_collision(monster,
  weapon)` — empty body. Phase B.10 closes by forwarding to the new
  function added in Phase B0 (Task #6).

## Phase B implications

- **Tasks #7-13 (Aquamentus, Dodongo, Manhandla, Gleeok, Digdogger,
  Gohma, Patra)** — bridges CLEAN, atomic close = drain diff vs NES
  asm + targeted edits if probe reveals divergence. No stub-removal
  burden.
- **Task #14 (Moldorm)** — NO existing bridge. Creates
  `src/game/enemies/bosses/boss_moldorm.c` from scratch forwarding to
  `src/oracle/enemies/enemy_moldorm_runtime.c` callees.
- **Task #15 (Lamnola)** — 1 stub close + drain diff.
- **Task #16 (Ganon)** — 4 stubs close + drain diff. Largest per-boss
  surface.

## Verdict

Drift audit gate **PASS**. No silent bridge drift to repair before
Phase B begins. Stubs are known-and-tracked, not hidden surprises.
Plan B tasks may proceed against this baseline.
