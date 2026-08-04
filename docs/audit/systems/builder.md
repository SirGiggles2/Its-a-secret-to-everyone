# System audit — builder

> Status is derived from the signed evidence blocks below, never from
> this file's existence. No blocks = all five cells RED. See
> `docs/superpowers/specs/2026-08-03-completion-tracker-design.md`.

**Audited:** 2026-08-03. First system audited per spec §6 ordering.

## Scope

The builder owns the path from *a user's own NES ROM* to
`builds/Debug.md`, plus the gates that decide whether a build may be
packaged and shipped.

Owns:

- `tools/builder/build.py` — drag-and-drop entry point (ROM → ROM)
- `tools/builder/from_scratch_gate.py` — from-scratch reproducibility
- `tools/builder/determinism_gate.py` — deterministic-rebuild gate
- `tools/builder/package_check.py` — release include/exclude policy
- `tools/builder/release_gate.py` — gate orchestrator
- `tools/builder/strict_build_check.py` — generated-only build gate
- `tools/builder/completion_gate.py` — completion-tracker gate
- `tools/debug/build_debug.py` — the single build script
- `tools/sgdk_pin.json` — pinned toolchain

Does NOT own:

- The correctness of any extracted asset. Each asset is audited on the
  DATA axis of the system that consumes it.
- Gameplay behaviour of the ROM it produces.

## Axis verdicts

```yaml evidence
- system: builder
  axis: LEGAL
  verdict: GREEN
  artifact: docs/audit/package_check_status.md
  artifact_sha256: 09ce5a9f7ca128545d3a57e1739893d56a8e3b2820b75ebb81d7c55e53eca4f9
  command: python tools/builder/package_check.py --emit-evidence builder
  verdict_line: 'package_check: 107 banned file(s) excluded, 12576 would ship'
  manifest_emitted_by: tools/builder/package_check.py
  run_signature: 624b06a2e50713e891a0f0f71450108502179850ae2ece17b78b1b3938dd344e
  inputs:
  - path: tools/builder/package_check.py
    sha256: c3d3e8fc1669dd15d60f19cd25530de9d1ad1b677d07358d1a0c031d9fb87498
```

```yaml evidence
- system: builder
  axis: BEHAVIOR
  verdict: GREEN
  artifact: docs/audit/determinism_status.md
  artifact_sha256: e05a9f2aee5889a4b64e1d4e9f7b1d6d3934dd7d4b3232c4312a3e88ab647465
  command: python tools/builder/determinism_gate.py --emit-evidence builder
  verdict_line: 'determinism_gate: deterministic rebuild byte-identical, 2097152 bytes,
    sha256 0b176550f8df15173dfb8c65d8c31e2d376bf4ef8e27a1ee950e5bfac33f71be (NOT from-scratch
    reproduction; see from_scratch_gate.py)'
  manifest_emitted_by: tools/builder/determinism_gate.py
  run_signature: 3bc2ff0dba0eb14b73488213a9d487d81de767cd291aab0f4942527efc905569
  tolerance: 'Zero tolerance: the two builds must be byte-identical. No accepted deltas.
    Scope is deterministic rebuild only; from-scratch reproduction from a user ROM
    is unproven and tracked as a RED gap on the PLAYABLE axis.'
  inputs:
  - path: tools/debug/build_debug.py
    sha256: 683e37c905276f82ecdb7b662c024d32beaf688f0bbaeb58b6b7e762238c2ee3
  - path: tools/builder/determinism_gate.py
    sha256: 01ec4f64664bf0f0563751b175baa2e6377d5c4f4cb216c44936521c21c58fb1
  - path: tools/sgdk_pin.json
    sha256: cd9d3071b25c8801e4f01376d7a5ca32f60bfe31b97bd2e2567969e817ce34a8
```

```yaml evidence
- system: builder
  axis: CODE
  verdict: GREEN
  artifact: docs/audit/extractor_coverage_status.md
  artifact_sha256: daa13bfefcdf0be8ef060585dc41cb4619e220767717be76696986348290bffd
  command: python tools/builder/extractor_coverage_gate.py --emit-evidence builder
  verdict_line: 'extractor_coverage: 11 extractor(s) wired into build.py, 1 documented
    as manual, 12 on disk, 0 unwired'
  manifest_emitted_by: tools/builder/extractor_coverage_gate.py
  run_signature: 6b973c63349a009cb704d1b54e843d410f7de45d1570368b270e0d53a052cbb3
  inputs:
  - path: tools/builder/build.py
    sha256: f4e8f69eaa867bce0c09d97eee6613f07191a413b2a79fa214bd4d58d62bdf78
  - path: tools/builder/extractor_coverage_gate.py
    sha256: 51c4a9d63b3bcd5c27b158ee2c1023dbbc6bb084ba79bf308e377c3ccadb9024
  - path: tools/extract_nes_banks.py
    sha256: 22d99e39ae057889bd546b24f5402321d33be1d6e9d778bfaed4e4fb15d04a84
  - path: tools/extract_dat_sidecars.py
    sha256: 9ff900d17c8a6c3975e7f7cb7a8893e0e7eb44b1624fa25de8fde3c51ffac0e7
  - path: tools/extract_chr.py
    sha256: c9719abfd1cfecb5a1e4bf22a486c722efc91e43a630bd1848e1150c5b1b7f22
  - path: tools/extract_rooms.py
    sha256: ba73a748709ee5a5685c040a5672576f4573b9596768dfe52a8ef69d1730f3f0
  - path: tools/extract_enemies.py
    sha256: 7ead21ef8f1734c827844a030d4d21c7c461b637ffdb5490231b5bef67c0da47
  - path: tools/extract_audio.py
    sha256: 004ef3b4124cab8923919c8d629ad45bc29f70abe62180003e18abc1a829034b
  - path: tools/extract_dmc_samples.py
    sha256: 12cb80af69fac7bb2dbfe7545b854bd3fb6df1b229ad5477649210604fe234be
  - path: tools/extract_frontend.py
    sha256: b72c6b659a99f0654e3a6f04dbb144ed64af2f1f427dfbadd9af49925fd4c532
  - path: tools/extract_misc.py
    sha256: 4dcd1bd924984e492ba417f95ab8b926a37f580ab6f1909c5b9663d213956bb8
  - path: tools/extract_demo_text.py
    sha256: 802b96e7d4f8f7e281d20ae624c03fe1bfde8d668b71e29554e10224adf08269
  - path: tools/extract_intro_assets.py
    sha256: 9f6a32a741efcafb953e9afe37540983735f86ee6bcee1738d67abed3f36b8dc
```

```yaml evidence
- system: builder
  axis: DATA
  verdict: N/A
  reason: The builder produces NES-derived assets, it does not own any. Every asset
    it emits is audited on the DATA axis of the consuming system.
```

PLAYABLE has no evidence block. It is RED — see the gap list. That is
deliberate: RED with a named gap is the honest state, and inventing an
N/A allowlist entry to make the grid look better is exactly what the
allowlist mechanism exists to prevent.

## Gap list

### PLAYABLE — RED. The drag-and-drop path has never been executed.

`from_scratch_gate.py` has never run. It requires a user-supplied NES
ROM, which is correctly absent from the repo, so this cannot be closed
without one from Jake.

Blocked on: a NES Zelda 1 ROM at a known path.

### CODE — CLOSED 2026-08-03.

Was RED: `build.py` wired 1 extractor of 12, and passed `--rom` to it —
a flag only `extract_nes_banks.py` accepts. The argparse-less scripts
silently ignored it and fell back to their own lookup, so the user's ROM
never reached them. `build.py:112` called its own dispatch a
"placeholder".

Fixed:

- All 11 ROM-relevant extractors wired, each with the calling convention
  probed from its source rather than assumed. Three conventions exist:
  `ZELDA_NES_ROM` env (8), `sys.argv[1]` (1), `--rom` (1), plus one that
  needs no ROM and reads the committed disassembly tree.
- `run_extractors()` sets `ZELDA_NES_ROM` for the subprocess environment,
  so the env-convention extractors see the ROM the user actually supplied
  instead of whatever sits at the repo-root fallback path.
- Four extractors that only had the hardcoded fallback
  (`extract_dat_sidecars`, `extract_demo_text`, `extract_frontend`,
  `extract_misc`) now honour `ZELDA_NES_ROM` like the rest.
- `extract_nes_banks.py:12` defaulted to an absolute path on one
  developer's machine — impossible in a shipped builder. Now env-then-
  repo-root.
- `extract_fs_assets.py` is documented as manual: it needs a live CHR-RAM
  dump from Zelda Redux, not the base ROM, so it cannot run unattended.
- `extractor_coverage_gate.py` guards against recurrence. Adding
  `tools/extract_foo.py` without wiring it turns the cell RED. Verified
  by adding a canary extractor: gate exited 1, naming it.

The CODE evidence hashes all 11 extractors plus `build.py`, so editing
any of them drops the cell to RED until re-verified.

### Still open beyond this system

`strict_build_check.py` has not been run against a tree with the
generated assets deleted. That belongs to PLAYABLE, since it needs a
real ROM to regenerate them.

## Tolerance

BEHAVIOR accepts zero deltas: the two builds must be byte-identical.
There is no accepted-divergence list for this system.
