# Build Target

**Authority:** User pivot 2026-05-08 — single sole ROM: `Debug.md`.
Master plan reference:
`docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md`
(see "Sole build target" amendment).

## Sole target

| Target | Output | Build |
|---|---|---|
| `Debug.md` | `builds/Debug.md` | `Debug.bat` |

`Debug.bat` is the only build script. It wraps
`tools/debug/build_debug.py`, links the SGDK boot, the Title A4 RAM ABI
(intro / file select / story), and the RoomRom runtime exports into one
ROM. All daily work — gameplay, sprite, palette, scene, parity probes —
hits `Debug.md`.

## Banned legacy aliases

Permanently retired. No build target, output filename, staging copy,
variable, identifier, comment, or active documentation may mention any
of these:

- `whatif.*` (legacy alias removed 2026-05-02)
- `Title.md` / `Title.lst` / `Title.elf` / `Title.o` — retired 2026-05-08
  (frontend-only ROM; the Title A4 RAM ABI lives on as a link path
  inside `Debug.md`)
- `RoomRom.md` (dev harness ROM retired 2026-05-08; gameplay sources in
  `RoomRom/src/` are still authoritative and link into `Debug.md`)
- `CombinedDebug.md` / `CombinedDebug.bat` / `combined_debug` (renamed
  2026-05-08 to `Debug.md` / `Debug.bat` / `debug`)

The banned-token regex lives in
`tools/gates/check_banned_filename.py`. CI fails on any active-code
hit. Historical evidence stays in `debates/`, `docs/archive/`,
`docs/superpowers/specs/`, `docs/superpowers/plans/`,
`docs/superpowers/decisions/`, and `docs/superpowers/captures/`.

## Direct boot + chord entry

`Debug.md` boots through the real Title (intro phase machine,
title display, file select). The A+B+C chord at PHASE_TITLE_DISPLAY
drops directly into the RoomRom runtime so gameplay scenes are reachable
without frontend traversal. Probe scripts press the chord automatically.
This replaces the old "RoomRom standalone ROM" cost-saving primitive —
chord-into-runtime is faster and removes ABI drift.

## Frontend ownership

The Title path owns: title screen, intro fade, story scroll, item
showcase, file-select static + cursor + name entry + options +
copy/erase, save handoff to gameplay. Memory rule
`project_title_screen_goal`: title + FS deliberately diverge from NES;
cross-platform parity diff is for gameplay scenes only.

## Promotion contract

Gameplay modules written in `RoomRom/src/` migrate to
`src/game/<subsystem>/` per master plan Task 12.0 (Incremental Promotion
Gate). Promotion still happens; the destination ROM is now always
`Debug.md`. State contract for promoted modules: typed C structs per
`docs/audit/state_contract.md`.

## Worktree rule

RoomRom S0–S2 work merged into `main` (tags `roomrom-s1-closed`,
`roomrom-s2-closed`). Active edits happen in `main` unless
`git worktree list` shows a parallel branch with newer commits. See
`docs/audit/worktree_merge_protocol.md` for cross-worktree merge.
