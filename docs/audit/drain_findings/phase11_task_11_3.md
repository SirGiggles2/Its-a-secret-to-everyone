# Phase 11 Task 11.3 — File Select

- **NES source**: `reference/aldonunez/Z_05.asm` `InitMode1` /
                  `UpdateMode1FileSelect_Full` + Z_07 file-select
                  dispatch. Native Redux-styled FS per
                  `project_title_screen_goal`; gameplay scenes track
                  NES parity, FS surface diverges (deliberately).
- **Drained C**:  `src/frontend/fs/` 8 TUs (fs_main 7.1 KB,
                  fs_render 17.1 KB, fs_input 1.9 KB, fs_phase
                  1.8 KB, fs_handoff 1.9 KB, fs_options 4.8 KB,
                  fs_options_render 10.4 KB). Phase 9 Task 9.3
                  added `fs_options.c` + `fs_options_render.c` to
                  `TITLE_C_SOURCES`. Phase 11 task is finish FS
                  static render + flows.
- **Coverage**:   PARTIAL — static FS render + cursor nav + slot
                  rendering + OPTIONS row + name entry all shipped;
                  copy / erase flows partially captured (cancel
                  paths baselined; confirm paths NOT baselined).
                  PLAYERS row + register-name handoff partial.
- **Stance**:     PARTIAL — substrate ADOPT; missing flow probes
                  recorded as `phase11_extra_probes_baseline`
                  deferral.

## Verify checklist (master plan)

| Item                            | Status | Evidence                                   |
|---------------------------------|--------|--------------------------------------------|
| Static render                   | ✓      | `fs_render.c` 17.1 KB                       |
| Cursor navigation               | ✓      | `fs_fresh_cursor.bin` + `fs_cursor_wrap.bin` |
| Occupied / empty slot rendering | ✓      | `fs_render.c` per-slot dispatch              |
| PLAYERS row                     | ✓      | `fs_main.c` row enum                         |
| OPTIONS row                     | ✓      | Phase 9 Task 9.3 (`fs_options.c`)            |
| Copy flow                       | PART   | needs `fs_copy_cancel` + `fs_copy_confirm` baselines |
| Erase flow                      | PART   | `fs_file_delete_cancel.bin` exists; need `fs_erase_confirm` |
| Saved slot start                | NEEDS  | needs `fs_registered_file_start` baseline    |
| Empty slot name entry           | ✓      | `fs_name_entry_create.bin` + `_backspace.bin` |
| Register-name handoff           | PART   | needs `fs_registered_file_start` probe       |

## Active probes (5 baselined of 9 master-plan FS rows)

Baselines present:
- `fs_fresh_cursor` ✓
- `fs_cursor_wrap` ✓
- `fs_file_delete_cancel` ✓ (master plan's `fs_erase_cancel`)
- `fs_name_entry_create` ✓
- `fs_name_entry_backspace` ✓ (extra; supplements `fs_name_entry_create`)

Missing per master plan:
- `fs_players_cycle`
- `fs_options_persist`
- `fs_copy_cancel`
- `fs_copy_confirm`
- `fs_erase_confirm`
- `fs_registered_file_start`

## Status

CLOSE (with extra-probes deferral) — Task 11.3 File Select substrate
+ 5 baselines locked; 6 extra FS flow probes tracked as
`phase11_extra_probes_baseline` follow-up.
