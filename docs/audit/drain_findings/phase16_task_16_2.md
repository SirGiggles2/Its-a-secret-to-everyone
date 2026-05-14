# Phase 16 Task 16.2 — Hardware Tests

- **NES source**: N/A — physical-hardware verification.
- **Drained C**:  N/A.
- **Coverage**:   NONE — physical hardware not in CLI scope.
- **Stance**:     DEFERRED_HARDWARE — Task 16.2 requires real Genesis
                  / Mega Drive + flash cart + controller hardware
                  available to a human tester. Out of CLI scope.

## Required hardware

| Item                  | Purpose                             |
|-----------------------|-------------------------------------|
| Genesis / Mega Drive  | Native CPU + VDP + Z80 verification |
| Flash cart            | Run `builds/Debug.md` on hardware   |
| SRAM-capable cart     | Save persistence verification       |
| Controllers (2-4 +    | Input + multitap (Phase 13 gate)    |
|  multitap/teamplayer) |                                      |
| Capture device        | Hardware-vs-emulator comparison     |

## Test checklist (when hardware available)

- Test on real Genesis / Mega Drive — boot + gameplay.
- Test with flash cart — load + run from cart.
- Test SRAM persistence — write save, power-cycle, verify load.
- Test reset behavior — reset button mid-gameplay.
- Test controller combinations — 1P / 2P / multitap.
- Record hardware notes at `docs/audit/hardware_test_log.md`.

## Status

DEFERRED_HARDWARE — Task 16.2 awaits physical-hardware test pass.
Tracked as `phase16_hardware_tests` for future external verification.
