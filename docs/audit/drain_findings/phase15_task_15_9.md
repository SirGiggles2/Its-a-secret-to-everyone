# Phase 15 Task 15.9 — Hot Path C/ASM Policy

- **NES source**: N/A — Genesis-side compiler/asm policy.
- **Drained C**:  Policy lives in CLAUDE.md "best practices" north
                  star + memory `project_best_practices` ("owned C =
                  real code, ASM only boot/IO/hot, promote by family,
                  name RAM, verify per subsystem").
- **Coverage**:   PARTIAL — policy ADOPT; per-hotpath profile-driven
                  rewrite gates NOT shipped. Existing ASM paths
                  (genesis_shell.asm boot/VBlank, c_shims.asm callee
                  shims, audio_driver.asm — Phase 11 deferral) are
                  pre-existing boot/IO/hot legitimately-ASM bodies.
- **Stance**:     PARTIAL — policy ADOPT; per-hot-path profile +
                  rewrite gate deferred.

## Policy (from memory)

- C for any path inside budget (PROBE_CYCLE_LIMIT envelope).
- Inline / static C helpers before assembly.
- Assembly only for **measured over-budget hot paths**.
- Document every ASM optimization with hotspot + measurement +
  fallback C behavior.

## Profile targets

| Target          | Status                                          |
|-----------------|-------------------------------------------------|
| Room render     | profile gated on Phase 14 GREEN                |
| Collision       | Phase 5/6 inline; profile gated                 |
| Sprite list assembly | inline Phase 6                              |
| Enemy update    | Phase 7 family73 probe runs at 6 slots; full-density profile gated on Phase 8 boss + 11-slot enemy load |
| Boss update     | Phase 8 in tree; profile gated                  |
| Audio tick      | Phase 10 deferral (audio not yet linked)        |

## Deferral

`phase15_hot_path_profile_gate` — per-hotpath profile sample
collection + per-target ASM-rewrite gate (only fires after measured
budget breach).

## Status

CLOSE (with profile-gate deferral) — Task 15.9 policy in tree;
profile-driven gate deferred.
