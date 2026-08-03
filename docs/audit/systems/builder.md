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
  axis: DATA
  verdict: N/A
  reason: The builder produces NES-derived assets, it does not own any. Every asset
    it emits is audited on the DATA axis of the consuming system.
```

PLAYABLE and CODE have no evidence block. Both are RED — see the gap
list. That is deliberate: RED with a named gap is the honest state, and
inventing an N/A allowlist entry to make the grid look better is exactly
what the allowlist mechanism exists to prevent.

## Gap list

### PLAYABLE — RED. The drag-and-drop path has never been executed.

`from_scratch_gate.py` has never run. It requires a user-supplied NES
ROM, which is correctly absent from the repo, so this cannot be closed
without one from Jake.

Blocked on: a NES Zelda 1 ROM at a known path.

### CODE — RED. `build.py` wires 1 extractor of 12.

`tools/builder/build.py:102-105` lists exactly one extractor:

```python
extractors = [
    ROOT / "tools" / "extract_audio.py",
    # Add CHR extractor + room blob extractor as they land.
]
```

Twelve extractors exist under `tools/`: `extract_audio`, `extract_chr`,
`extract_dat_sidecars`, `extract_demo_text`, `extract_dmc_samples`,
`extract_enemies`, `extract_frontend`, `extract_fs_assets`,
`extract_intro_assets`, `extract_misc`, `extract_nes_banks`,
`extract_rooms`.

Consequence, and it is the product-defining one: the shipped package
excludes generated Nintendo-derived assets (correctly — `package_check`
blocks 107 files), but `build.py` can only regenerate the audio subset
from the user's ROM. A user who unpacks the public package and drags in
their ROM cannot reconstruct CHR, rooms, enemies, frontend, intro, or
file-select assets. `build.py:112` still calls its dispatch a
"placeholder".

This was invisible because the two gates that would have caught it —
`from_scratch_gate.py` and `strict_build_check.py` — have never been run
together against a clean tree.

To close:

1. Wire the remaining 11 extractors into `run_extractors()`, with the
   argument convention each one actually takes (they are not uniform —
   `build.py` currently assumes `--rom`, which needs verifying per tool).
2. Replace the placeholder dispatch with per-extractor invocation.
3. Run `strict_build_check.py` on a tree with generated assets deleted;
   require zero `STRICT GATE FAIL` lines.
4. Run `from_scratch_gate.py <rom>` and require byte-identical A/B.

## Tolerance

BEHAVIOR accepts zero deltas: the two builds must be byte-identical.
There is no accepted-divergence list for this system.
