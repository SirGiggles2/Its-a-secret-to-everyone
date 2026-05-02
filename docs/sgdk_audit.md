# SGDK Audit — pinned dependency record

**Source of truth for the pinned SGDK SHA. See `tools/sgdk_pin.json` for the machine-readable form.**

## Current pin

| Field | Value |
|-------|-------|
| Submodule path | `sgdk/` |
| Pinned SHA | `ef9292c03fe33a2f8af3a2589ab856a53dcef35c` |
| Short SHA | `ef9292c0` |
| Tag | `v2.11` |
| Upstream commit date | 2025-04-03 |
| Upstream subject | Fixed incorrect naming of some methods + updated to SGDK 2.11 |
| Pinned by | debate 003 (2026-05-02), execution Step 2 |

## Why this SHA

- **v2.11** is the latest tagged SGDK release at the time of pin.
- The S0 pivot (project memory `project_what_if`) originally said "v2.00"; that memory was stale by 11 minor releases. The submodule had drifted forward unnoticed. The debate-003 audit caught the divergence.
- The pinned SHA is the actual submodule HEAD as measured on 2026-05-02; nothing was rolled back. We rebaseline against current reality.
- v2.11 ships the API surface used by `src/sgdk_adapter/` (render, audio/XGM, joy, sram). All four adapter modules compile clean against this SHA per `build.bat` runs in the post-S0 worktree.

## Tested matrix at this SHA

| Surface | Status |
|---------|--------|
| `src/sgdk_adapter/render_adapter.c` | builds, used by intro_title.c via render_abi.h |
| `src/sgdk_adapter/audio_adapter.c` | builds, XGM-wired (per audio_driver.asm + Phase 10 fallback policy) |
| `src/sgdk_adapter/joy_adapter.c` | compile-only |
| `src/sgdk_adapter/sram_adapter.c` | compile-only |
| Owned `src/game/` (92 files) | zero `<genesis.h>` includes (verified by `tools/check_adapter_boundary.py`) |
| Owned `src/frontend/` | zero `<genesis.h>` includes |
| Owned + transpiled (100 files across `src/game`, `src/frontend`, `src/zelda_translated`) | zero raw VDP touches (verified by `tools/check_raw_vdp.py`) |

## Bump policy (Rule SGDK-2)

Bumping the pin requires ALL of:

1. Pass `--accept-sgdk-bump` to `build.bat` (the SGDK pin checker honors this flag and exits 0 with a warning).
2. Update `tools/sgdk_pin.json` with the new SHA, tag, date, subject.
3. Update this doc (`docs/sgdk_audit.md`) with the new pin record + reason for the bump (security, parity, build break, owner-approved feature need) + tested matrix at the new SHA.
4. Regenerate parity oracle baselines (Rule SGDK-2).
5. Regenerate `Final.md` checksum (Rule SGDK-2).
6. All of the above land in a single commit.

## Drift detection

`tools/check_sgdk_pin.py`, run from `build.bat` pre-link, reads `git -C sgdk rev-parse HEAD` and compares to `tools/sgdk_pin.json`. Drift = build hard-fail with the actionable bump instructions.

## Fork policy (Rule SGDK-5 — for completeness)

We do not maintain a fork today. Forking is owner-decided and only triggered by:
- Security CVE with no upstream patch in 14 days
- Parity blocker, upstream PR rejected/stalled >30 days
- Reproducibility break (toolchain non-determinism), upstream refuses fix
- Build-breaking SGDK bug blocking a milestone gate, upstream PR open >14 days with no maintainer response

Patch must be <200 LOC AND touch no SGDK public ABI. Performance alone is not fork-worthy — hand-roll behind the adapter under Rule SGDK-3 instead.

If a fork is created, it lives at `vendor/sgdk-fork/` with `PATCHES/*.patch`. Every release attempts clean `git am` against the latest upstream tag; first clean apply auto-opens a PR to drop the fork and revert to upstream pin.
