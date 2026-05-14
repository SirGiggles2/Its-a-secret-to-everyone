# Phase 9 Task 9.3 — File Select Options Menu

- **NES source**: NONE — NES Zelda 1 file select has no OPTIONS row.
                  Redux extension only, layered on top of the native
                  file-select shell at `src/frontend/fs/fs_main.c` (the
                  drained file-select runtime owns rows 0..5; Redux
                  inserts a sixth `FS_ROW_OPTIONS = 6` row).
- **Drained C**:  NONE for the OPTIONS submenu itself. Underlying file
                  select shell (`fs_main.c`, `fs_render.c`, `fs_input.c`,
                  `fs_phase.c`) draws on already-drained NES file-select
                  logic from `Z_05.asm` / `Z_07.asm`; the OPTIONS row
                  composes onto that surface but introduces no new NES
                  surface.
- **Coverage**:   N/A for the OPTIONS submenu (no NES surface).
                  Underlying shell coverage tracked separately under
                  Phase 6 / earlier file-select drain.
- **Stance**:     GREENFIELD (sanctioned by debate 004; Rule D1
                  exception identical to Task 9.1 — no drain candidate
                  row).

## Substrate (`src/frontend/fs/`)

`fs_options.c` / `fs_options.h` — submenu phase machine. Owns no SRAM
region; commits live state via `options_persistence_commit()` on B
press or A on the SAVE row. Cursor state is a single `uint8_t`
`s_cursor`; header rows skipped via per-row "is selectable" predicate.

`fs_options_render.c` / `fs_options_render.h` — pure draw layer. Pulls
the in-flight `options_state` values from `options_runtime` getters and
renders:
- Category headers (non-selectable).
- Boolean toggles (rendered via `OPT 0/1` glyph pair).
- Radio rows (rendered via labeled enum-value glyph).
- SAVE row at the bottom.

Insertion into existing FS shell:
- `fs_main.c` adds `FS_ROW_OPTIONS = 6` (one slot past the three save
  slots + REGISTER + ELIMINATION rows).
- `fs_input.c` routes A on `FS_ROW_OPTIONS` to `fs_options_enter()`.
- `fs_phase.c` adds `FS_PHASE_OPTIONS` to the FS phase enum and
  dispatches input + render to `fs_options.c` / `fs_options_render.c`
  while phase is held.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

`fs_options.o` + `fs_options_render.o` linked into `Debug.md`. Build
clean.

## Status

CLOSE — Task 9.3 OPTIONS submenu shipped (GREENFIELD per debate 004).
Cursor + header-skip + toggle + radio + SAVE row all rendered; A / B
commit routes through `options_persistence_commit()` so writes hit
SRAM `$800..$81F` (Task 9.2 substrate).
