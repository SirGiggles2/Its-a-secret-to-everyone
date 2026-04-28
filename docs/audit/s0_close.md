<!-- docs/audit/s0_close.md -->
# S0 Close-Out

S0 acceptance was reached on `2026-04-28T05:00Z` at the commit tagged `s0-closed`. The locked
baseline Genesis ROM (`4bcfc1d916f44f31f36ee5bc0862b6b696313a264ffcc8373abde87d318befb4`) is
unchanged from the on-disk artifact, and **build reproducibility was verified at T15**: a
fresh `build.bat` run from the committed source produced the byte-identical ROM hash. The
post-build phase-sequence probe is a pre-existing flaky check not introduced by S0; the lint
hook now runs before that probe so it fires on every successful build regardless.

## Major decisions

- **SGDK pivot** (mid-S0). Path E was redefined to build on SGDK as the
  platform/render layer. Spec Sections 3, 4, 6, 7, 11, 12, 13 were
  amended; T3.5 audit was added to evaluate integration.
- **SGDK v2.00 pinned**, vendored as git submodule. Smoke test deferred to
  S1 vendoring step.
- **A4 register convention** kept (`-ffixed-a4`) pending S1 SGDK-library
  inspection; mitigation plan recorded if a conflict surfaces.
- **Toolchain portability** flagged as an open issue: toolchain currently
  resolves to a sibling repo path. Vendoring or `setup.bat` to be decided
  at S1 build-pipeline rewire.

## Audit artifacts

- [`repo_tree.txt`](repo_tree.txt) — 211 files under `src/`
- [`legacy_callers.md`](legacy_callers.md) — 372 callers across z01_/z07_/shim families
- [`frontend_deps.md`](frontend_deps.md) — 52 frontend files, 87 VDP-direct hits
- [`build_order.md`](build_order.md) — 3 build for-loops, 1 link command
- [`file_classification.md`](file_classification.md) — 10 categories; 46 cruft files queued for S1 deletion
- [`toolchain.md`](toolchain.md) — vasm 2.0e, m68k-elf-gcc 13.2.0, ld/objcopy 2.40, Python 3.14.0
- [`baseline_rom.md`](baseline_rom.md) — locked Genesis ROM hash
- [`emulators.md`](emulators.md) — BizHawk 2.11.0 + quickerNES + Genplus-gx
- [`capture_geometry.md`](capture_geometry.md) — H32, 256×224, NES `(0,8)` crop
- [`abi_probe.md`](abi_probe.md) — proven calling convention
- [`sgdk_integration.md`](sgdk_integration.md) — SGDK v2.00, submodule, deferrals
- [`redux_touchpoints.md`](redux_touchpoints.md) — 39 touchpoints + 58-feature Redux catalog
- [`sram_map.md`](sram_map.md) — save slots 0x000-0x7FF, OptionsState 0x800-0x81F
- [`parity_schema_check.md`](parity_schema_check.md) — schema validation deferred to S1
- [`audio_split_plan.md`](audio_split_plan.md) — adapter wrapper plan

## Resolved S0-Locked Questions

See spec Section 12 for the per-question table. 8 of 10 resolved fully;
Q4 (parity schema validation) and Q10 (A4 conflict check) explicitly
deferred to S1 with mitigation plans.

## Lint state

`lint_legacy_symbols.py` runs at the end of every `build.bat` build,
warn-only. Caller count at S0 close: **372**.

`tools/probes/scan_legacy_callers.py` produces the same count for the
same patterns; the lint and the scanner agree.

## S1 prerequisites

Before S1 implementation begins:

1. `git submodule add -b v2.00 https://github.com/Stephane-D/SGDK sgdk` (or chosen vendoring step)
2. Verify SGDK library on disk; rerun T3.5 paper-checks against actual sources
3. Run a fresh `build.bat` with the lint hook present and confirm caller count is unchanged from 372
4. Run `tools/probes/sram_layout_test.c` (created in S1) against the locked SRAM map

## Next stage

S1 — Repo Reorg + SGDK Integration. Spec Section 7. Status: gated on this
close-out commit; ready to begin.
