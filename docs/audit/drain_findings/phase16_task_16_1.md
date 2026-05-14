# Phase 16 Task 16.1 — Performance Gates

- **NES source**: N/A — Genesis hardware performance gating.
- **Drained C**:  N/A — gating layer over Phase 15 instrumentation.
- **Coverage**:   PARTIAL — Phase 15 instrumentation ratified;
                  worst-case enemy/boss-room tests + per-frame CPU
                  budget gate live but baseline values pending Phase
                  14 GREEN.
- **Stance**:     PARTIAL — gate framework ADOPT (PROBE_CYCLE_LIMIT
                  + per-subsystem ceiling enforced since Phase 6);
                  worst-case stress probes deferred to phase15
                  measurement-driven pass.

## Coverage

| Master plan item                       | Status |
|----------------------------------------|--------|
| Per-frame CPU budget measurement       | ✓ (proxy via perf_probe.lua FPS gap) |
| VBlank DMA budget measurement          | ✓ (cycle_probe.lua) |
| Sprite count measurement               | ✓ (perf_probe.lua) |
| Audio tick measurement                 | DEFERRED (Phase 10 audio link) |
| Worst-case enemy/boss room tests       | DEFERRED (phase15 stress probes) |
| Optimize only measured hot spots       | ✓ (master-plan policy enforced) |

## Status

CLOSE (with carry-forward deferrals) — Task 16.1 gates active;
worst-case measurement deferred with phase15 stress probes.
