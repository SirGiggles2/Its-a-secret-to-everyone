# SaveRAM Migration Note (Phase 16.5)

**Status:** ACTIVE — migration note for local development.
**Date:** 2026-05-14
**Authority:** Master plan Task 16.5 polish pass + memory
`feedback_combined_debug_only` (sole-target Debug.md amendment
2026-05-08).

## What changed

Pre-2026-05-08, the project shipped multiple ROM targets:
`whatif.md` (initial), `Title.md` (frontend-only), `CombinedDebug.md`
(merged frontend + RoomRom runtime). Each had its own SRAM-backed
save file alongside the ROM:

- `whatif.SaveRAM` (retired with the first alias retirement)
- `Title.SaveRAM` (retired with the dual-ROM era)
- `CombinedDebug.SaveRAM` (renamed to `Debug.SaveRAM` 2026-05-08)

## Current state

Only **`Debug.md`** is built. BizHawk and other emulators save SRAM
alongside the ROM file with matching basename. Per the
sole-target pivot:

- BizHawk: `Debug.md` → `Debug.SaveRAM` (located next to ROM in
  whatever directory you ran it from).
- Genesis Plus GX standalone: same convention.
- BlastEm: same convention (file extension may vary by emulator).
- Flash cart on real hardware: cart-side SRAM, not file-based.

## Migration steps for older local copies

If your local working tree predates 2026-05-08, you may have stale
SRAM files:

1. **Backup** any `*.SaveRAM` file you want to keep:
   ```bash
   cp <emu-dir>/whatif.SaveRAM <emu-dir>/whatif.SaveRAM.bak
   cp <emu-dir>/Title.SaveRAM <emu-dir>/Title.SaveRAM.bak
   cp <emu-dir>/CombinedDebug.SaveRAM <emu-dir>/CombinedDebug.SaveRAM.bak
   ```

2. **Rename** to the current ROM name:
   ```bash
   mv <emu-dir>/CombinedDebug.SaveRAM <emu-dir>/Debug.SaveRAM
   ```
   The on-disk format is identical (NES SRAM at `$6000-$7FFF` mapped
   through `nes_ram[]`); only the filename changed.

3. **Delete** the retired-alias files once you've confirmed the
   rename worked:
   ```bash
   rm <emu-dir>/whatif.SaveRAM
   rm <emu-dir>/Title.SaveRAM
   rm <emu-dir>/CombinedDebug.SaveRAM
   ```

## SRAM layout (Phase 9.2 substrate)

Per `src/state/save_serializer.h`:

- `$800..$81F` — Redux options state (32 bytes, magic `OP` + version
  + bool_bits + radio enums + checksum).
- `$000..$7FF` — three save slots @ 682 bytes each (43-byte payload
  + alignment).
  - Magic: `$5A $A5` (matches NES `Z_05.asm:7375 InitSaveRam`).
  - Slot stride: `682` bytes.
  - Inventory mirror: 40 bytes from NES `$0657..$067E`.
  - Per-slot XOR checksum (Redux extension over NES contract).

## Tooling

`tools/builder/package_check.py` enforces that no `*.SaveRAM` file
ships in the public release tarball (saves contain user-specific
state and copyrighted RAM contents from gameplay).

## Source of truth

Authoritative SRAM serialization: `src/state/save_serializer.c`.
Authoritative legal model: `docs/audit/audio_legal_policy.md`
(CHR-model rule extended to SRAM as user-derived state).

## Status

CLOSE — Task 16.5 SaveRAM migration note documented. Local-dev
rename procedure published. CI gate via `package_check.py` already
in place. No code changes required.
