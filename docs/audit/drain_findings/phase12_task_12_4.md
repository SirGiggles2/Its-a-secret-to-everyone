# Phase 12 Task 12.4 — Introduce Final Target

- **NES source**: N/A — build-target structural task.
- **Drained C**:  N/A.
- **Coverage**:   N/A — superseded by sole-target pivot.
- **Stance**:     SUPERSEDED — Task 12.4 belongs to the pre-pivot
                  dual-target world (Title.md frontend + RoomRom
                  runtime → merge to Final.md). Per CLAUDE.md
                  "Sole build target — Debug.md" amendment
                  (2026-05-08), the dual-ROM era is retired and
                  Debug.md IS the merged target the original Task
                  12.4 described.

## Master-plan checklist mapping (pre-pivot → post-pivot)

| Original Task 12.4 item             | Post-pivot status |
|-------------------------------------|--------------------|
| Add `Final.md` build output         | **Debug.md** is the merged build output. Sole target per CLAUDE.md. |
| Link Title frontend                 | `TITLE_C_SOURCES` in `tools/debug/build_debug.py` (24 TUs linked). |
| Link shared gameplay core           | `ROOMROM_C_SOURCES` (now naming-historical) + `src/game/<sub>/*` (49 src/game refs in build). |
| Link save/options/audio adapters    | Save serializer + options runtime linked. Audio adapter pending Phase 11 deferral. |
| Add mode dispatcher                 | `intro_phase.c` + `fs_phase.c` + RoomRom main dispatch already wired. |
| Add file-select → gameplay handoff  | `src/frontend/fs/fs_handoff.c` (shipped). |
| Add gameplay → FS / game-over handoff | Phase 9.7 deferral (Mode 6/7/8 dispatch). |
| Add final ROM probes                | `tools/probes/baselines/` 8 baselines + Phase 11 capture driver. |

## Status

CLOSE — Task 12.4 superseded by sole-target Debug.md pivot. The
original Final.md target IS the current Debug.md. Frontend-to-
gameplay handoff (FS → gameplay direction) is wired; reverse
direction (gameplay → FS / game-over) is tracked under Phase 9.7
deferral `phase97_death_continue_modes`.
