# Build Targets

**Authority:** Master plan `docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md` Task 0.4 deliverable. Phase 0 rename.

## Targets

| Target | Output | Role | Build |
|---|---|---|---|
| `Title.md` | `builds/Title.md` | Release-facing frontend (title loop, intro, file select, options, save menus) | `build.bat` |
| `RoomRom.md` | `RoomRom/out/RoomRom.md` | Fast gameplay harness, direct-boots into gameplay scenes, no frontend traversal | `RoomRom/build.bat` (in `FINAL TRY-roomrom-s1` worktree) |
| `Final.md` | `builds/Final.md` | Final integrated ROM (frontend + promoted RoomRom core); introduced Phase 12 | TBD Phase 12 task |

## Compatibility aliases

Phase 0 Task 0.2 keeps `builds/whatif.md` and `builds/whatif.lst` as compatibility copies of `builds/Title.md` and `builds/Title.lst`. Live probe scripts hardcode the `whatif` path; alias copies are produced by `build.bat` after each Title build. Aliases removed in Phase 16.5 polish pass once every active probe migrates.

## Direct boot

`RoomRom.md` direct-boots into the gameplay scene under test. Set the boot scene via `RoomRom/build.bat` flags or RoomRom-local environment vars. No frontend state required to reach gameplay code; this is the cost-saving primitive for parallel agent dispatch on enemy/boss families.

## Frontend ownership

`Title.md` owns: title screen, intro fade, story scroll, item showcase, file-select static + cursor + name entry + options + copy/erase, save handoff to gameplay. Memory rule `project_title_screen_goal`: title + FS deliberately diverge from NES; cross-platform parity diff is for gameplay scenes only.

## Promotion contract

Gameplay modules written in `RoomRom/src/` migrate to `src/game/<subsystem>/` per master plan Task 12.0 (Incremental Promotion Gate). Promotion gate cited at master plan Phase 12. State contract for promoted modules: typed C structs per `docs/audit/state_contract.md`.

## Worktree rule

Active RoomRom development happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1` (branch `roomrom-s1`). Main worktree lacks RoomRom S2+ features. See `docs/audit/worktree_merge_protocol.md` for cross-worktree merge.

## Phase 0 completion

Phase 0 considered complete when:
- `build.bat` produces `builds/Title.md` and `builds/Title.lst` ✓
- Compatibility alias copies `builds/whatif.md` and `builds/whatif.lst` are produced ✓
- This document exists ✓
- `RoomRom/build.bat` still produces `RoomRom/out/RoomRom.md` (verify with `cmd /c RoomRom\build.bat` in worktree) — DEFERRED
- One title/frontend probe smoke-tests the new build with `Title.md` directly OR via `whatif.md` alias — DEFERRED to first BizHawk session
