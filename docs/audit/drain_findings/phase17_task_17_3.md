# Phase 17 Task 17.3 — From-Scratch Build Gate

- **NES source**: N/A — reproducibility gate.
- **Drained C**:  N/A — release-pipeline test.
- **Coverage**:   NONE — from-scratch build gate not yet automated.
- **Stance**:     DEFERRED_RELEASE — Task 17.3 requires:
                  (1) clean public package (Task 17.1 partial),
                  (2) builder UX shell (Task 17.2 partial),
                  (3) reproducibility test infra not yet authored.

## Reproducibility requirements

1. Clone clean public package → no generated asset cache present.
2. Run builder with user NES ROM (sha256 pinned in manifest).
3. Generated cache appears locally (under `build/generated/` and
   `data/audio/`, `src/data/`, etc.).
4. Final `.md` ROM appears at `builds/Debug.md`.
5. Final ROM hash recorded in build manifest.
6. Smoke probe runs against final ROM.
7. Delete cache; rebuild from same inputs.
8. Byte-compare rebuilt `Debug.md` vs prior `Debug.md` — require
   diff = 0.
9. Fail release if manifest inputs match but ROM bytes differ.

## Deferral

`phase17_from_scratch_build_gate` — author
`tools/builder/from_scratch_gate.py` that automates the 9-step
reproducibility test. Gated on Phase 17.1 + 17.2 completion.

## Status

DEFERRED_RELEASE — Task 17.3 reproducibility gate deferred end-to-end.
