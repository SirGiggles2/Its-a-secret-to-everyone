# Repository targets

Source: master plan "Repository Targets" section + Sole Build Target
Amendment 2026-05-08.

## Active build target

| Target | Role | Owned by | Notes |
|---|---|---|---|
| `Debug.md` | Sole Genesis ROM (Title boot + gameplay runtime in one binary) | `main` worktree | Title intro / file-select / story scroll + RoomRom runtime linked together. A+B+C chord at `PHASE_TITLE_DISPLAY` enters the runtime in-ROM. |
| `Debug.bat` | Sole build script | `main` worktree | Wraps `tools/debug/build_debug.py` → emits `builds/Debug.md`. |
| `tools/builder/` | Public legal builder pipeline | `main` worktree | Becomes strict public release at Phase 17 (still emits a `Debug.md`-shaped artifact). |

## Generated assets

- **`build/generated/`** or **`generated/`** — local generated asset cache, gitignored. All Nintendo-derived content lives here, never in the public release package.
- **`build/generated/nes_reference/`** — Phase 1.5 capture harness output. Parity oracle baseline.

## Documentation

- **`docs/superpowers/specs/`** — durable specs.
- **`docs/superpowers/plans/`** — implementation plans.
- **`docs/audit/`** — audit reports + active scope pointer.
- **`docs/superpowers/prime_directive_tracker.json`** — machine tracker (this skill).
- **`docs/superpowers/prime_directive_status.md`** — human status (rendered).

## Forbidden output (banned legacy aliases)

Per WT-4, these are permanently retired. No build target, output filename,
staging copy, variable, identifier, comment, or active documentation may
reintroduce any of them:

- `whatif.*` (legacy alias removed 2026-05-02)
- `Title.md` / `Title.lst` / `Title.elf` / `Title.o` — retired 2026-05-08 (frontend-only ROM; the Title A4 RAM ABI lives on as a link path inside `Debug.md`)
- `RoomRom.md` (dev harness ROM retired 2026-05-08; gameplay sources in `RoomRom/src/` still link into `Debug.md`)
- `CombinedDebug.md` / `CombinedDebug.bat` / `combined_debug` (renamed 2026-05-08 to `Debug.md` / `Debug.bat` / `debug`)

Banned-token regex lives in `tools/gates/check_banned_filename.py` and
fails CI on any active-code hit. Historical evidence is allowlisted under
`debates/`, `docs/archive/`, `docs/superpowers/{specs,plans,decisions,captures}/`,
and `docs/audit/`.

Also forbidden:
- Nintendo-derived data baked into public release packages.
- Hand-edited generated assets as the permanent solution.
