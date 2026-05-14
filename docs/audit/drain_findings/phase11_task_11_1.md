# Phase 11 Task 11.1 — Title Loop

- **NES source**: `reference/aldonunez/Z_05.asm` `Mode_Title` (`$00`)
                  — title display + waterfall sprite animation +
                  palette glow + Start-input edge to FS. Native
                  rewrite per memory `project_title_screen_goal`
                  (title deliberately diverges from NES — Title and
                  FS are Redux-styled; gameplay scenes still NES-parity).
- **Drained C**:  `src/frontend/intro/intro_title.c` (13.2 KB) +
                  `intro_phase.c` (2.1 KB) + `intro_common.c` (633 B)
                  + `intro_handoff.c` (2.5 KB) + `intro_main.c`
                  (3.7 KB). All linked into Debug.md via
                  `TITLE_C_SOURCES`.
- **Coverage**:   FULL (substrate) — title render TU, sprite TU,
                  palette glow TU, waterfall animation TU, fade TU
                  all shipped. Phase 11 task is verify-only.
- **Stance**:     ADOPT — title surface is finalized Redux art per
                  memory `project_title_screen_goal`; verify mode
                  asserts existing behavior is regression-locked, not
                  rewritten.

## Verify checklist (master plan)

| Item                         | Probe / Evidence                                |
|------------------------------|--------------------------------------------------|
| Title render                 | `tools/probes/baselines/title_idle.bin` (17.1 KB) |
| Title sprites                | bundled in `title_idle.bin` capture              |
| Palette glow                 | bundled (per-frame palette table)                |
| Waterfall / animation        | bundled (multi-frame VRAM/SAT capture)           |
| Start input                  | `tools/probes/baselines/title_to_fs.bin`         |
| No frame stalls              | `tools/probes/capture_canonical.lua` runs ≥200 frames |

## Active probes

`title_idle` + `title_to_fs` baselines present at
`tools/probes/baselines/`. Live capture wiring runs through
`tools/probes/capture_canonical.lua` (pass-A cold boot, capture
frame 200 = title_idle; pass-B reboot + Start press, capture frame
180 = title_to_fs).

Regression matrix lists these as SKIP — current probe output BIN not
generated at matrix time. The skip cause is "current probe output
missing" per `builds/reports/regression_matrix.md`; baselines exist,
captures need a live BizHawk launch + probe run to populate
`builds/reports/baselines/title_idle.bin` for comparison. Live probe
run is the verify-step that closes this task.

## Status

CLOSE (with live-capture deferral) — Task 11.1 Title Loop substrate
landed + baselines locked. Live BizHawk capture run gated on
`phase11_live_capture_pass` deferral.
