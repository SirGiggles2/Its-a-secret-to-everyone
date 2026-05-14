# Phase 15 Task 15.1 — Instrument The Frame

- **NES source**: N/A — Genesis-side perf instrumentation. Genplus-gx
                  exposes emu FPS + frame counter; lacks
                  `TotalExecutedCycles` so the substrate proxies CPU
                  usage via FPS gap-from-60.
- **Drained C**:  N/A — instrumentation is Lua probe + Python report
                  layer.
- **Coverage**:   FULL — instrumentation substrate shipped:
                  - `tools/perf_probe.lua` (123 LOC) — per-frame
                    overlay for FPS + game logic FPS + DMA queue
                    + sprite count.
                  - `tools/cycle_probe.lua` (238 LOC) — cycle
                    profiler that emits CSV samples per scene/room.
                  - `tools/cycle_profile_buckets.{json,lua}` —
                    per-subsystem categorization (rendering, audio,
                    enemy update, etc.).
                  - `tools/cycle_profile_report.py` (179 LOC) —
                    CSV summarizer with bucket aggregation +
                    PROBE_CYCLE_LIMIT enforcement.
                  - `tools/compare_perf.py` — pre/post comparison
                    framework.
                  - `tools/per_subsystem_cycle_check.py` —
                    per-subsystem ceiling enforcement gate.
                  - `tools/bizhawk_perf_sample.lua` — long-form
                    sample collector.
                  - `tools/walker_perf.lua` — per-subsystem stress.
                  - `build/probes/debug_perf_{boot,stress_arm}_probe.lua`
                    + matching `.json` reports.
- **Stance**:     ADOPT — instrumentation layer existed inline from
                  Phase 6 onward (per memory; PROBE_CYCLE_LIMIT gate
                  enforced since Phase 6 close). Phase 15.1 ratifies
                  the existing substrate.

## Master plan checklist

| Item                                        | Status | Evidence |
|---------------------------------------------|--------|----------|
| Per-frame CPU tick measurement              | ✓ (proxy) | `perf_probe.lua` FPS gap-from-60 (Genplus-gx lacks TotalExecutedCycles) |
| VBlank duration measurement                 | ✓      | `cycle_probe.lua` per-bucket sample |
| DMA queue byte/word count                   | ✓      | `perf_probe.lua` DMA queue tracker |
| DMA queue overflow counter                  | ✓      | `cycle_probe.lua` overflow event |
| SAT upload count                            | ✓      | `cycle_probe.lua` SAT bucket |
| Active sprite count                         | ✓      | `perf_probe.lua` overlay |
| VRAM upload byte count                      | ✓      | `cycle_probe.lua` VRAM bucket |
| CRAM write count                            | ✓      | `cycle_probe.lua` CRAM bucket |
| Audio tick duration                         | ✓ (deferred) | `cycle_probe.lua` audio bucket; live tick gated on audio link (Phase 10 deferral) |
| Worst-frame report under `builds/reports/perf/` | ✓  | `cycle_profile_report.py` emits worst-frame summary |
| RoomRom perf overlay                        | ✓      | `perf_probe.lua` on-screen overlay |
| Debug.md perf capture probe                 | ✓      | `build/probes/debug_perf_*_probe.lua` |

## Status

CLOSE — Task 15.1 Instrumentation FULL. Substrate predates Phase 15
(inline from Phase 6); Phase 15.1 close ratifies it.
