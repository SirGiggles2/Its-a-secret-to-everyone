# Debug Builds

Sole Build Target Amendment 2026-05-08: there is exactly one ROM and
one build script.

## Current outputs

- `builds/Debug.md` — sole Genesis ROM (Title boot + gameplay runtime
  linked into one binary; A+B+C chord at `PHASE_TITLE_DISPLAY` enters
  the gameplay runtime in-ROM)
- `builds/Debug.lst` — assembly listing / symbol addresses (when
  emitted by `tools/debug/build_debug.py`)
- `builds/archive/` — historical phase-tagged build snapshots, kept for
  bisection. Snapshots taken before the 2026-05-08 sole-target pivot
  carry the dual-target era filenames; do not cite them as current.

## Build pipeline

1. `Debug.bat` (repo root) wraps `tools/debug/build_debug.py`.
2. `tools/debug/build_debug.py` compiles the SGDK boot, the Title-side
   ABI (intro / file select / story scroll), and the gameplay runtime
   exports, then links them into a single ELF.
3. `tools/fix_checksum.py` patches the Genesis header checksum.
4. Output lands at `builds/Debug.md`.

The retired aliases (`whatif.*`, `Title.*`, `RoomRom.md`,
`CombinedDebug.*`) are blocked from active code paths by
`tools/gates/check_banned_filename.py`.

## Emulator probes

Generic launcher: `tools/launch_bizhawk.ps1` (defaults to
`builds/Debug.md`).

Active probes live under `tools/debug/` and `tools/probes/`. Phase
2/3/4-era probe wrappers (`tools/run_bizhawk_phase{2,3,4}_*.bat`,
`tools/run_t{34,35,36,37,38}_*.bat`, `tools/run_record_*.bat`,
`tools/run_scroll*.bat`) were retired with the dual-ROM era.
