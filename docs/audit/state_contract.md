# State Contract Decision

**Date:** 2026-05-02
**Status:** DECIDED. Binding on every owned C module from Phase 2 forward.
**Decision authority:** User invocation of PrimeDirective ("what is best long term?").
**Source:** Four-way AI debate at `debates/001-prime-directive-plan-improvement/synthesis.md`.

## Decision

**Owned C modules use typed C structs.** Raw NES RAM access remains available through a thin mirror layer for transpiled / boot code only.

## Rationale (PrimeDirective scorecard)

1. **Best long-term outcome.** Typed structs scale; macro shims fight every modern tool. Renames, refactors, and cross-target promotions become greppable type changes instead of multi-file macro hunts.
2. **Maximally efficient.** One-time migration cost replaces recurring confusion at every promotion, every code review, every bug. Sonnet's evidence (`enemy_state.h:17,21` aliases `OBJ(0x0412, slot)` under two different names) is exactly the failure that vanishes with typed structs.
3. **Best coding practices.** Typed structs are the C standard. Static analysis, debuggers, IDE go-to-definition, and compiler warnings all work on structs and silently degrade on `RAM(addr)` macros.
4. **Match NES.** Zero loss. NES RAM bytes still live at correct offsets via the mirror layer; struct fields are added on top, not in place of.
5. **Use Genesis strengths.** 68K compiler can register-allocate struct fields when typed; volatile macro RAM access cannot be optimized.
6. **Best fit for Codex + Claude + other CLIs.** LLMs read typed structs reliably; macro mazes hide intent. Sonnet's debate-decisive find was only possible because Sonnet read the actual files — the alias collision would have been invisible in a typed-struct world.

## Architecture

```
+----------------------------------+
| Owned C modules (src/game/, ...) |
| Read/write typed struct fields    |
+----------------+-----------------+
                 |
                 v
+----------------------------------+
| Typed state structs              |
| src/state/*_state.h              |
| LinkState, RoomState, EnemyState |
| ItemState, SaveState, OptionsState
+----------------+-----------------+
                 |
                 v  (where parity matters)
+----------------------------------+
| NES RAM mirror layer              |
| src/abi/nes_ram_mirror.h          |
| Thin wrappers that read/write    |
| nes_ram[off] for transpiled code  |
+----------------+-----------------+
                 |
                 v
+----------------------------------+
| nes_ram[]  (A4 register pointer) |
| Existing transpiled NES RAM image|
+----------------------------------+
```

- Owned C never touches `nes_ram[]` directly.
- Transpiled NES code keeps using `nes_ram[]` and the existing `RAM()`/`OBJ()` macros until that subsystem is promoted; at promotion time, a typed struct view is added and the old macros become deprecated aliases.
- Cross-subsystem reads always go through the typed struct.

## Migration Rules

1. **No new code may add a `RAM()` or `OBJ()` macro definition.** Every new state field is a typed struct field.
2. **At each phase, the subsystem being touched migrates its state header to typed structs first**, before any new behavior is implemented. This is the per-phase incremental promotion gate (debate Tier 2 item).
3. **Existing alias collisions (e.g., `enemy_state.h:17,21`) must be resolved during migration**, not deferred. Each NES RAM byte gets exactly one canonical struct field name.
4. **A `tools/state/verify_no_alias_collisions.py` script** scans all `*_state.h` files and fails if two macros map to the same offset under different names. Required green in the phase close gate.
5. **The Phase 12 promotion gate "typed `src/state/` struct ownership"** stands as written; this decision makes the gate satisfiable.

## Migration Order (matches phase plan)

| Phase | Subsystem | State header migrated |
|-------|-----------|----------------------|
| 2     | Graphics registry | `vram_map_state.h` (new), `palette_state.h` |
| 3     | Caves | `cave_state.h` (new) |
| 4     | Overworld | `world_state.h` |
| 5     | Dungeon | `room_state.h`, `collision_state.h` |
| 6     | Link/items/combat | `link_state.h` (refactor from shims), `item_state.h` |
| 7     | Enemies | `enemy_state.h` (resolves `OBJ(0x0412)` alias collision) |
| 8     | Bosses | `boss_state.h` (new) |
| 9     | HUD/options/save | `save_state.h` (refactor), `options_state.h` |
| 13    | Multiplayer | `link_state.h` → `player_state.h` array generalization |

Each migration step:
1. Define typed struct in the header.
2. Add inline accessors that map struct field reads/writes to existing `nes_ram[]` offsets where parity requires the same byte location.
3. Update consumers in that subsystem to use struct field names.
4. Mark old `RAM()`/`OBJ()` macros for that subsystem as `[[deprecated]]` and remove after the next subsystem's migration confirms no caller remains.
5. Run `verify_no_alias_collisions.py`.
6. Run subsystem probe set to confirm no behavior change.

## Non-Goals

- Do not rewrite transpiled code. Transpiled code keeps using `nes_ram[]` until that file is replaced by a native rewrite.
- Do not eliminate the `nes_ram[]` array. NES RAM image stays as-is for transpiled co-existence.
- Do not reorder NES RAM bytes. Struct field offsets must match NES offsets where the field exists at a fixed NES location.

## Acceptance Test

Phase 12 promotion gate passes when:
- Every promoted module's state lives in a typed struct.
- `verify_no_alias_collisions.py` is green.
- No owned C source contains `RAM(` or `OBJ(` outside the mirror layer header itself.
- Every struct field that mirrors an NES RAM byte cites the NES offset in a comment or via a `_Static_assert` against `offsetof`.

## Open Items

- Implemented at `tools/state/verify_no_alias_collisions.py` — scans `src/state/*.h`, exits 1 with detailed collision report, exits 0 if clean. Required green in phase close gate per master plan Task 2.0.
- Inventory of existing `RAM(` / `OBJ(` callsites is at [`docs/audit/state_macro_inventory.md`](state_macro_inventory.md) — 398 macros across 17 headers; 199 alias collisions recorded in "Known Alias Collisions" section. Generated by `tools/state/audit_macro_shims.py`.
- Decide whether `[[deprecated]]` warnings become errors at Phase 12 or stay as warnings. PrimeDirective default: errors at Phase 12.
