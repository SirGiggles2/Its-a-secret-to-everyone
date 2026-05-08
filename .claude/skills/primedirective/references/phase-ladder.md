# Master plan phase ladder (0..17)

Source: `docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md`

| Phase | Name | One-line scope |
|---|---|---|
| 0 | Target Rename and Split | Establish `Debug.md` sole-target boundary; retire all legacy aliases (whatif/Title/RoomRom/CombinedDebug). |
| 1 | Legal Builder Foundation | `tools/builder/` skeleton; user-supplied NES ROM extraction pipeline. |
| 1.5 | NES Reference Capture Harness | Deterministic NES capture into `build/generated/nes_reference/`; baseline parity oracle schema instances. |
| 2 | RoomRom Graphics Registry + No-Clobber Foundation | Per-subsystem VRAM/CRAM ownership map; collision-free tile/palette allocation. |
| 3 | Overworld Caves | Cave entrance + interior runtime, dialog, item-give. |
| 4 | Overworld Secrets, Traversal, State | Bombable walls, push-block, recorder, raft, ladder; secret triggers. |
| 5 | Dungeon Core | Dungeon room runtime, doors, key/lock, dungeon item set. |
| 6 | Link, Inventory, Items, Combat | Link state machine, sword/shield/items, hit detection, item use. |
| 7 | Enemies by Behavior Family | Walkers, flyers/jumpers, projectiles, special, aquatic/terrain — one parallel agent per family. |
| 8 | Bosses | Per-boss runtime; framework first, then parallel agent per boss. |
| 9 | HUD, Options, Save, Menus | Score/heart bar, item select, save/load, pause, options runtime. |
| 10 | Audio Finalization | Driver pin or XGM2 migration per Rule SGDK-4 trigger. |
| 11 | Debug Frontend Gap-Fill + Regression Lock | Title intro/story/file-select polished inside `Debug.md`; freeze regression matrix. |
| 12 | Promote Runtime Core, Integrate Release Build | Promote proven systems → `src/game/`; final release build is still `Debug.md` (sole target). |
| 13 | Optional 4-Player Genesis Mode | `PlayerState[4]`, parallel input/render/state agents. |
| 14 | Full Quest Completion | Second quest data + parity. |
| 15 | Genesis-Specific Optimization | Hand-rolled VDP per Rule SGDK-3; cycle/bandwidth gates. |
| 16 | Hardware, Performance, Polish | Real-hardware validation, audio polish, final tuning. |
| 17 | Public Builder Release | Drag-and-drop builder UX, package checker, reproducibility gate, docs. |

## Phase status sources

- **Active phase + task** — `docs/audit/active_scope.md` (written by `tools/audit/active_scope.py`).
- **Drain coverage** — `tools/audit/drain_coverage.json` (written by `tools/audit/drain_coverage.py`).
- **Gate state** — `docs/superpowers/prime_directive_tracker.json` (written by `tools/audit/primedirective/prime_refresh.py`).

## Subagent dispatch shapes (per master plan)

- **Phase 1 extractors** — one agent per asset class: `intro/fs`, `rooms`, `CHR/palette`, `enemies/items`, `audio/text`; plus one verifier.
- **Phase 7 enemies** — one agent per behavior family.
- **Phase 8 bosses** — one agent per boss after framework.
- **Phase 13 multiplayer** — separate agents for input adapter, render/sprite budget, player state, combat rules.
- **Phase 17 release** — separate agents for package checker, drag/drop UX, reproducibility gate, docs.

Rules:
- Each parallel agent owns a disjoint file/module set.
- Shared headers + state structs land before parallel dispatch.
- Workers do not edit RoomRom files unless their worktree is the active RoomRom worktree.
- Each worker returns changed paths, build/probe evidence, unresolved risks.
- Parent session integrates and runs the phase close gate.
