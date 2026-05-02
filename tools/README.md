# tools/ Canonical Structure

**Authority:** Master plan `docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md` + debate 002 synthesis `debates/002-codebase-cleanup-prep/synthesis.md`.

## Canonical layout

```
tools/
├── builder/          # Phase 1 legal-builder pipeline (build_from_rom.py, roms.py, extract_all.py, manifest.py, package_check.py, gui_drop.ps1, strict_build_check.py)
├── nes_capture/      # Phase 1.5 deterministic NES capture harness (captures.json, run_capture.py, lua/capture_bundle.lua, verify_capture.py)
├── parity/           # Task 2.8 parity oracle schema + diff (schema.json, diff.py, genesis_probe.lua, nes_to_schema.py, tolerances.yaml, expected_failures.yaml)
├── state/            # Task 2.0 state contract enforcement (audit_macro_shims.py, verify_no_alias_collisions.py, lint_no_new_macro_state.py)
├── probes/           # Canonical BizHawk probes — promoted from root tools/*.lua per phase
│   ├── baselines/    # *.bin baseline snapshots
│   ├── movies/       # BizHawk input movies for canonical scenarios
│   └── _common.py
├── extractors/       # NES asset extractors (extract_*.py); promoted from root tools/extract_*.py per phase
├── tests/            # Python unit tests (test_*.py)
├── debug/            # Debugging utilities, drain helpers
├── drain_batches/    # Drain JSON batch inputs (formerly tools/plans/)
├── gen_wrappers/     # Manifest store for gen/ forwarder system; load-bearing per build.bat
├── file_select_demo/ # Frontend demo build (kept until Phase 11 completion)
├── file_select_test/ # FS regression test harness
├── intro_demo/       # Intro-loop demo
├── intro_test/       # Intro probe harness (active; build.bat references)
├── midi_demo/        # MIDI integration demo
├── music_test/       # Audio test harness
├── verify_worktree_state.py  # Task 0.6 helper
├── run_regression_matrix.py  # Workstream F entrypoint
└── per_subsystem_cycle_check.py  # Workstream F cycle envelope check
```

## Migration policy

Existing scripts at the root of `tools/` (255 Lua + 123 Python) keep working — they are referenced by 39+ launchers and the live probe fleet hardcodes paths. Bulk migration would break the harness.

New scripts MUST land in the appropriate canonical subdir from day one. Per-phase migration of root scripts happens when:
- A subsystem promotion (Phase 12 incremental gate) touches the script's owners.
- A launcher is rewritten and its referenced scripts move with it.
- Phase 16.5 polish pass runs the final sweep.

## Where new work goes

| New work | Location |
|---|---|
| New extractor | `tools/extractors/extract_<asset>.py` |
| New BizHawk probe | `tools/probes/<probe_name>.lua` (Lua) or `tools/probes/<probe_name>.py` (driver) |
| New parity comparator | `tools/parity/comparators/<subsystem>.py` |
| New capture scenario | append to `tools/nes_capture/captures.json`, no new Python file |
| New unit test | `tools/tests/test_<subject>.py` |
| New state-contract verifier | `tools/state/<verifier>.py` |
| Debug one-shot script | `tools/debug/<name>.py` (no commitment to keep) |
| Drain batch | `tools/drain_batches/<batch>.json` |

## Forbidden patterns

- New Python or Lua at `tools/` root (anchor your script in a subdir).
- Hardcoded paths to `tools/<root>.lua` in new launchers — pass paths via env var or relative-to-repo expansion.
- Cross-subdir imports without a canonical entrypoint.
- Test artifacts checked into `tools/tests/` (use `build/generated/test_outputs/`).

## Removal sweep schedule

Phase 16.5 polish pass deletes:
- `tools/_*.bat`, `tools/_*.py` (underscored scratch wrappers from old workflows).
- Any `tools/<root>.lua` not promoted to `tools/probes/` or referenced by a current launcher.
- Any `tools/<root>.py` not imported by a canonical entrypoint.

Migrations between now and Phase 16.5 happen organically per phase; no bulk rename pass.
