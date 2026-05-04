# Repository targets

Source: master plan "Repository Targets" section.

## Active build targets

| Target | Role | Owned by | Notes |
|---|---|---|---|
| `Title.md` | Release-facing frontend ROM | `main` worktree | Title, intro, story, file-select, regression-locked at Phase 11. |
| `RoomRom.md` | Fast gameplay harness ROM | RoomRom worktree | Active gameplay-core development; promoted into `Final.md` at Phase 12. |
| `Final.md` | Final integrated ROM | `main` worktree | Introduced at Phase 12 — promotes proven RoomRom systems into `src/game/`. |
| `tools/builder/` | Public legal builder pipeline | `main` worktree | Becomes strict public release at Phase 17. |

## Generated assets

- **`build/generated/`** or **`generated/`** — local generated asset cache, gitignored. All Nintendo-derived content lives here, never in the public release package.
- **`build/generated/nes_reference/`** — Phase 1.5 capture harness output. Parity oracle baseline.

## Documentation

- **`docs/superpowers/specs/`** — durable specs.
- **`docs/superpowers/plans/`** — implementation plans.
- **`docs/audit/`** — audit reports + active scope pointer.
- **`docs/superpowers/prime_directive_tracker.json`** — machine tracker (this skill).
- **`docs/superpowers/prime_directive_status.md`** — human status (rendered).

## Forbidden output

- `whatif.*` — legacy alias dead per WT-4. `build.bat` MUST emit only `Title.*`.
- Nintendo-derived data baked into public release packages.
- Hand-edited generated assets as the permanent solution.
