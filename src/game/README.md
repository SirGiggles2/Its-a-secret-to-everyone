# `src/game/` — Native gameplay implementation (debate 006 D3 destination)

This directory is the **NEW native rewrite destination** for gameplay code. Per debate 006 synthesis:

- Drained transpile-bridge C lives at `src/oracle/` (read-only reference role; renamed from previous `src/game/` location 2026-05-03).
- `src/game/` (here) is for **fresh Genesis-native implementations** that consume `src/state/` typed structs + `src/sgdk_adapter/` API.
- Both ROMs (Title.md + RoomRom.md) link `src/game/` modules. Title links via A4-pinned ABI (default); RoomRom links via non-A4 ABI (`-DROOMROM_BUILD`).
- Per Rule D1 (debate 005): read `src/oracle/` reference + NES asm spec BEFORE writing any new file here. Native impl matches NES; oracle is the C-readable bridge documenting what NES does.

## Subsystem layout (mirror `src/oracle/` for navigation)

```
src/game/
  cave/        # native impl mirrors src/oracle/cave/cave_runtime.c reference
  combat/      # mirrors src/oracle/combat/
  enemies/     # mirrors src/oracle/enemies/
  hud/         # mirrors src/oracle/hud/
  items/       # mirrors src/oracle/items/
  room/        # mirrors src/oracle/room/
  world/       # mirrors src/oracle/world/
```

## Phase 12 close-gate

`src/oracle/` empty + both ROMs pass parity oracle harness on shared `src/game/`. At that point oracle/ retires, drain becomes pure git history.

## Per-file workflow (per Rule D1 + debate 006)

1. Identify subsystem function to port (start with cave; smallest verified-MATCH leaf).
2. Read `src/oracle/<subsystem>/<file>_runtime.c` end-to-end + cite NES asm reference (`reference/aldonunez/Z_*.asm`).
3. Open Gate 1 finding doc at `tools/audit/drain_findings/<phase>_<task>_<func>.md`.
4. Write native `src/game/<subsystem>/<func>.c` using typed structs + SGDK adapter calls.
5. Wire into BOTH ROMs (Title.md `src/gen/z_01.c` cutover via `#ifdef NATIVE_<func>`; RoomRom direct call from `RoomRom/src/main.c`).
6. Verify: `build_all.ps1` GREEN + per-RAM-cell parity oracle trace.
