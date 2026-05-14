# Phase 17 Task 17.1 — Clean Public Package

- **NES source**: N/A — release packaging policy.
- **Drained C**:  N/A.
- **Coverage**:   PARTIAL — package policy locked under Phase 10
                  legal-policy (CHR-model rule); per-file include /
                  exclude rules per task spec. `tools/builder/`
                  partial (3 helper TUs); package_check.py NOT YET
                  shipped.
- **Stance**:     PARTIAL — policy ADOPT (Phase 10.1.1 legal model
                  + Phase 10.2 audio extraction + CHR extraction
                  precedent); package_check tool deferred.

## Include / exclude rules

### Include

- Source code (`src/`, `RoomRom/src/`, `data/` non-generated).
- Extraction scripts (`tools/extract_audio.py`,
  `tools/extract_uw_collision.py`, CHR extractors).
- Build scripts (`Debug.bat`, `tools/debug/build_debug.py`).
- Docs (`docs/`, `README.md`, `CLAUDE.md`).
- Tests that do not require bundled ROM assets.

### Exclude

- `.nes` files (user supplies own ROM).
- `.ips` files (unless license permits).
- Private screenshots / videos containing copyrighted frames.
- Generated Nintendo-derived assets (CHR / songs / SFX / room
  blobs — these are extracted at build time on the user's machine
  per CHR-model legal ruling).

## Deferral

`phase17_package_check_tool` — author `tools/builder/package_check.py`
that enforces include/exclude rules. Per Phase 10.1.1 plan: refuse
to ship audio binaries (or any generated Nintendo-derived asset)
unless generated from user ROM at build time.

## Status

PARTIAL — Task 17.1 policy locked + include/exclude rules
documented; package_check tool deferred.
