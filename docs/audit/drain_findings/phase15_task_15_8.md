# Phase 15 Task 15.8 — 68K-Friendly Data Layout

- **NES source**: NES uses 6502 byte-oriented data tables. Genesis
                  68K reads word/long efficiently with aligned access.
                  Precompute room / collision / enemy spawn / animation
                  tables in 68K-friendly order at build time.
- **Drained C**:  Phase 4-7 inline 15a work generated optimized
                  tables under `data/rooms/`, `data/chr/`, plus
                  builder tools at `tools/builder/`. Hash checks
                  pin source-of-truth NES inputs per
                  `tools/builder/package_check.py`.
- **Coverage**:   PARTIAL — most per-subsystem tables already
                  precomputed inline. Unified `build/generated/tables/`
                  directory + per-table hash-proof manifest NOT yet
                  shipped.
- **Stance**:     PARTIAL — table precompute ADOPT (in tree per
                  subsystem); unified generated-tables manifest
                  + hash-proof deferred.

## Deferral

`phase15_generated_tables_unification` — unified
`build/generated/tables/` directory with per-table hash-proof
manifest proving every optimized 68K-friendly table derives from
the same NES source bytes.

## Status

CLOSE (with unified-manifest deferral).
