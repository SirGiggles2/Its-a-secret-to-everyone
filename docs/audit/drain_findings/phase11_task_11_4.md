# Phase 11 Task 11.4 — Frontend Probes

- **NES source**: N/A — regression probe pass; verifies Phase 11.1
                  / 11.2 / 11.3 substrate against locked-in baselines.
- **Drained C**:  Probe harness in
                  `tools/probes/capture_canonical.lua` (frame-driven
                  capture script) + `tools/run_regression_matrix.py`
                  (matrix runner) + `tools/parity/diff.py` (binary
                  diff with tolerance support).
- **Coverage**:   PARTIAL — 8 baselines of 14 master-plan probes
                  shipped. Live capture wiring exists; capture step
                  needs a BizHawk launch to populate
                  `builds/reports/baselines/` per-run.
- **Stance**:     ADOPT — probe harness shipped; remaining 6
                  master-plan probes tracked as
                  `phase11_extra_probes_baseline` deferral.

## Probe inventory matrix

| Master plan probe                  | Baselined?         | Driver source                       |
|------------------------------------|--------------------|--------------------------------------|
| `title_idle`                       | ✓                  | `capture_canonical.lua` frame 200   |
| `title_to_file_select`             | ✓ (as `title_to_fs`) | `capture_canonical.lua` frame 180 |
| `intro_story_page_1`               | ✓ (as `intro_story_p1`) | `capture_canonical.lua` frame 700 |
| `intro_story_loop`                 | ✗                  | needs longer-attract-loop driver    |
| `fs_fresh_cursor`                  | ✓                  | `capture_canonical.lua` frame 260   |
| `fs_cursor_wrap`                   | ✓                  | `capture_canonical.lua` frame 320   |
| `fs_players_cycle`                 | ✗                  | needs PLAYERS row cycle driver      |
| `fs_options_persist`               | ✗                  | needs OPTIONS edit + power-cycle driver |
| `fs_copy_cancel`                   | ✗                  | needs copy mode driver              |
| `fs_copy_confirm`                  | ✗                  | needs copy confirm driver           |
| `fs_erase_cancel`                  | ✓ (as `fs_file_delete_cancel`) | `capture_canonical.lua` frame 650 |
| `fs_erase_confirm`                 | ✗                  | needs erase confirm driver          |
| `fs_name_entry_create`             | ✓                  | `capture_canonical.lua` frame 400   |
| `fs_registered_file_start`         | ✗                  | needs registered-slot start driver  |

8 of 14 baselined. 6 missing.

`fs_name_entry_backspace` is an extra baseline (supplements
`fs_name_entry_create`) — useful regression evidence, not in master
plan list.

## Regression matrix state

`builds/reports/regression_matrix.md` (run 2026-05-14T05:26:00Z):

- OVERALL = GREEN
- 0 GREEN / 0 RED / 8 SKIP
- 0 unexpected_red

The 8 SKIP entries are the baselined probes. SKIP reason: current
probe output BIN not generated at matrix time. Closing the SKIP →
GREEN transition requires a BizHawk run that re-captures each probe
into `builds/reports/baselines/<name>.bin`; the diff against
`tools/probes/baselines/<name>.bin` then runs. This is the
`phase11_live_capture_pass` deferral.

## Deferrals (Phase 11 close-status)

| Deferral                              | Scope                                                |
|---------------------------------------|------------------------------------------------------|
| `phase11_extra_probes_baseline`       | Author 6 missing master-plan probes + baseline each.  |
| `phase11_live_capture_pass`           | BizHawk run that populates `builds/reports/baselines/` so SKIP → GREEN. |
| `task_10_3_audio_link_into_debug_md`  | Phase 10 deferral; audio TUs into Debug.md (per `docs/audit/audio_link_engineering_plan.md`). |
| `task_10_5_audio_probes_runtime`      | Phase 10 deferral; gated on audio link.               |

## Status

CLOSE (with deferrals) — Task 11.4 Frontend Probes substrate +
8/14 baselines locked. Remaining 6 baselines + live capture pass +
audio-link work tracked as Phase 11 deferrals.
