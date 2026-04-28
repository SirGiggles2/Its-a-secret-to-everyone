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
- **SGDK v2.11 vendored** post-S0 (2026-04-28) as git submodule at `sgdk/`,
  commit `ef9292c0`. Bumped from original v2.00 paper-pin to current stable
  to avoid carrying upgrade debt into S1+.
- **Build chain verified** end-to-end via `sgdk/sample/basics/hello-world`
  (produced 128 KB Genesis ROM with no errors, SHA prefix `8d57bee7…`).
- **A4 register convention SAFE** — verified post-S0 by inspecting SGDK
  boot/runtime: only A4 reference is a debug exception display in
  `sys.c::showValueU32U32U32` which does not modify A4. `-ffixed-a4` and
  the existing NES_RAM=A4=`$FF0000` convention are preserved into S1.
- **Toolchain portability** flagged as an open issue: existing toolchain
  resolves to a sibling repo path (`<sibling>/NES-TO-SEGA-GENESIS/build/
  toolchain/`). The SGDK submodule now also bundles its own toolchain at
  `sgdk/bin/`, which is self-contained per repo. S1 build-pipeline rewire
  picks one (likely SGDK's bundled toolchain via `makefile.gen`).

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
- [`sgdk_integration.md`](sgdk_integration.md) — SGDK v2.11 vendored, submodule + smoke test verified, A4 SAFE
- [`redux_touchpoints.md`](redux_touchpoints.md) — 39 touchpoints + 58-feature Redux catalog
- [`sram_map.md`](sram_map.md) — save slots 0x000-0x7FF, OptionsState 0x800-0x81F
- [`parity_schema_check.md`](parity_schema_check.md) — schema validation deferred to S1
- [`audio_split_plan.md`](audio_split_plan.md) — adapter wrapper plan

## Resolved S0-Locked Questions

See spec Section 12 for the per-question table. **9 of 10 resolved fully**
(post-S0 SGDK vendoring closed Q8/Q9/Q10). Only Q4 (parity schema
validation) remains deferred — it requires BizHawk capture pairs and is
the first S1 acceptance milestone with the mitigation plan in
`parity_schema_check.md`.

## Lint state

`lint_legacy_symbols.py` runs at the end of every `build.bat` build,
warn-only. Caller count at S0 close: **372**.

`tools/probes/scan_legacy_callers.py` produces the same count for the
same patterns; the lint and the scanner agree.

## S1 prerequisites

1. ~~Vendor SGDK as submodule.~~ **DONE 2026-04-28** — `sgdk/` at v2.11 (`ef9292c0`).
2. ~~Verify SGDK library on disk; rerun T3.5 paper-checks against actual sources.~~ **DONE** — API surface confirmed; A4 SAFE; build chain works.
3. **Open:** Run a fresh `build.bat` and confirm lint caller count unchanged from 372 (cheap, do at S1 start).
4. **Open:** Build `sgdk/sample/basics/hello-world/out/rom.bin` in BizHawk to confirm SGDK runtime boots cleanly (visual confirmation, needs user steering).
5. **Open:** Resolve Q4 — capture title-screen-idle frame from both NES and current FINAL TRY ROM, run normalized schema diff to confirm sufficiency (S1 acceptance gate).
6. **Open:** Run `tools/probes/sram_layout_test.c` (created in S1) against the locked SRAM map (S1 deliverable).

## Next stage

S1 — Repo Reorg + SGDK Integration. Spec Section 7. Status: gated on this
close-out commit; ready to begin.
