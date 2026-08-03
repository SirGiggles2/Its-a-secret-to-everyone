# System audit — builder

> Status is derived from the signed evidence blocks below, never from
> this file's existence. No blocks = all five cells RED. See
> `docs/superpowers/specs/2026-08-03-completion-tracker-design.md`.

## Scope

NOT YET AUDITED. Define what this system owns, and what it explicitly
does not, during the audit pass.

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

## Gap list

- DATA / BEHAVIOR / PLAYABLE / CODE not yet audited for `builder`.
- LEGAL is GREEN for the exclude-policy scan only. `from_scratch_gate.py`
  has never run — it needs a user-supplied NES ROM — so byte-identical
  reproduction from a fresh clone is still unproven.

## Tolerance

Not applicable until the BEHAVIOR axis has evidence.
