# Phase 12 Task 12.5 — Cross-Target Verification

- **NES source**: N/A — verification task.
- **Drained C**:  N/A.
- **Coverage**:   PARTIAL — sole-target Debug.md is the only build,
                  cross-target verification collapses to single-target
                  verification against the Debug.md ROM.
- **Stance**:     SUPERSEDED — pre-pivot Task 12.5 was Title.md vs
                  RoomRom.md vs Final.md cross-target verification.
                  Sole-target era retires the dual-ROM gate
                  (CLAUDE.md "Substrate ownership" amendment 2026-05-08:
                  "Sole-target world: substrate edits are verified by
                  a single clean Debug.bat build").

## Master-plan checklist mapping

| Original Task 12.5 item                   | Post-pivot status |
|-------------------------------------------|--------------------|
| Run RoomRom gameplay probes               | Phase 11 capture driver covers gameplay + frontend probes against Debug.md; same probes that would have run vs RoomRom.md run vs Debug.md. |
| Run Title.md frontend probes              | Same 8 baselines at `tools/probes/baselines/` cover title/intro/FS; Debug.md is the only target. |
| Run Final.md boot-to-gameplay probe       | Debug.md A+B+C chord boots into gameplay; covered by `tools/debug/probe_debug_entry.lua`. |
| Run Final.md cave probe                   | Phase 3 cave dispatch test; integration via `roomrom_debug_teleport` MODE_TELEPORT. |
| Run Final.md dungeon Level 1 probe        | `tools/debug/probe_boss_bank_dispatch.lua` exercises UW_L1 vs UW_L3 boss CHR bank dispatch. |
| Run Final.md save/load probe              | `save_serializer_probe.c` (Phase 9.2 substrate); runtime probe gated on Phase 9.7 deferral. |
| Commit `build: integrate final rom target` | Sole-target pivot commit was the integration commit (2026-05-08). |

## Status

CLOSE — Task 12.5 superseded by sole-target Debug.md pivot. Each
checklist item maps onto an existing Debug.md probe or a tracked
phase deferral. Cross-target gate retired with the dual-ROM era.
