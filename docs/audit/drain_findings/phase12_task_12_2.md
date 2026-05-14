# Phase 12 Task 12.2 — Move Shared Gameplay Modules

- **NES source**: N/A — migration work; the moved bodies still
                  point at the NES references they did under
                  `RoomRom/src/`.
- **Drained C**:  Each migrated TU retains its existing drain stance
                  + NES asm cites; only the path changes.
- **Coverage**:   PARTIAL (planning) — Task 12.2 migration not yet
                  executed; family-ordered plan ready to ride
                  Task 12.0 gate tool.
- **Stance**:     PARTIAL — substrate target directories already
                  exist (`src/game/cave/`, `src/game/combat/`,
                  `src/game/world/`, `src/game/dungeon/`,
                  `src/game/items/`, `src/game/hud/`,
                  `src/game/enemies/`, `src/state/`). Per-family
                  migration PRs land subsequent commits.

## Target directory landscape (already in tree)

`src/game/` subsystem dirs already exist per master plan:

```
src/game/cave/      — Phase 3 cave subsystem
src/game/combat/    — Phase 6 combat dispatch
src/game/world/     — Phase 4 world subsystem
src/game/dungeon/   — Phase 5 dungeon subsystem
src/game/items/     — Phase 6 items subsystem
src/game/hud/       — Phase 9 HUD dispatch
src/game/enemies/   — Phase 7 enemies + Phase 8 bosses
src/game/options/   — Phase 9 options
src/state/          — substrate singletons
```

Target dirs ready; migrations land into the existing tree without
new top-level structure.

## Family migration PR template (per master plan rule)

Each Phase 12.2 family PR does:

1. `git mv RoomRom/src/<file>.c src/game/<sub>/<new>.c`.
2. Update include paths in moved file + every consumer.
3. Update `tools/debug/build_debug.py` TU list — move entry from
   `ROOMROM_C_SOURCES` to a new `SRC_GAME_C_SOURCES` (or extend
   the existing list).
4. If RoomRom callers still reference the symbol, leave a thin
   wrapper header at `RoomRom/src/<file>.h` that forwards to the
   promoted location.
5. `Debug.bat` — must build green.
6. `python tools/audit/check_incremental_promotion.py` — count
   must decrement for shared-gameplay bucket.
7. Update `docs/audit/roomrom_promotion_audit.md` — move file row
   to a "Migrated" section with commit hash.

## Promotion order (recap)

1. substrate-singletons → `src/state/` (3 TUs).
2. palette → `src/state/` + `src/game/world/` (3 TUs).
3. items → `src/game/items/` (5 TUs).
4. combat → `src/game/combat/` (2 TUs).
5. HUD → `src/game/hud/` (1 TU).
6. world → `src/game/world/` (6 TUs).
7. dungeon → `src/game/dungeon/` (7 TUs).
8. generated-asset → `data/` (7 TUs).

Total: 8 family PRs.

## Status

CLOSE (with execution deferral) — Task 12.2 plan + target tree +
gate tool ready. Execution lands as `phase12_family_migration` PR
series; recorded as deferral so Phase 12 close-status reflects
honest state (plan ready, execution incremental).
