# Phase 16 Task 16.5 — Polish Pass

- **NES source**: N/A — release-polish task.
- **Drained C**:  N/A — repo audit.
- **Coverage**:   FULL (alias retirement) + PARTIAL (debug code
                  pruning).
- **Stance**:     PARTIAL — alias-retirement work (`whatif.*` +
                  prior frontend-only ROM + CombinedDebug rename →
                  Debug) ALREADY DONE per CLAUDE.md "Sole build
                  target" amendment 2026-05-08. Polish-naming +
                  debug-code-pruning deferred to release-prep PR.

## Master plan checklist

| Item                                                       | Status |
|------------------------------------------------------------|--------|
| Audit naming                                               | ✓ (tools/gates/check_banned_filename.py enforces; 985 active code files scanned clean) |
| Remove dead debug code from release build                  | DEFERRED (release-prep PR) |
| Keep debug build diagnostics                               | ✓ (debug build IS the only target per CLAUDE.md) |
| Remove obsolete aliases (whatif.*, Title.*, CombinedDebug.*) | ✓ (CLAUDE.md 2026-05-08 amendment; check_banned_filename gate enforces) |
| Delete whatif.* compatibility aliases                      | ✓ (banned-name regex active) |
| Migration note for old SaveRAM aliases                     | DEFERRED (release-prep PR) |
| `RoomRom` still builds                                     | ✓ (compile-only path; RoomRom/build.bat stub aborts pointing at Debug.bat) |
| `Title.md` still builds                                    | n/a — Title.md retired 2026-05-08; TITLE_C_SOURCES still links into Debug.md |
| `Final.md` builds                                          | n/a — superseded by Debug.md (Phase 12.4 SUPERSEDED) |
| Commit `release: hardware and polish pass`                 | DEFERRED (release-prep PR) |

## Sole-target supersession

Per CLAUDE.md "Sole build target — Debug.md" amendment, three of
the original Task 16.5 items are SUPERSEDED (Title.md / Final.md /
CombinedDebug.md no longer separate targets). Debug.md is the
canonical build output. RoomRom/build.bat is a stub redirecting to
Debug.bat per memory `feedback_combined_debug_only`.

## Status

PARTIAL — Task 16.5 alias retirement + naming audit FULL via
`check_banned_filename.py`; remaining polish (debug-code prune,
SaveRAM migration note) deferred to release-prep PR
(`phase16_release_prep_polish`).
