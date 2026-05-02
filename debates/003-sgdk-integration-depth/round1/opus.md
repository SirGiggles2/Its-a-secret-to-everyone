# OPUS ADVISOR — Round 1: SGDK Integration Depth

## Architectural Stance
SGDK is a **third-party runtime dependency**, not a library we own. Treat it like Linux treats glibc: bounded, versioned, replaceable. The adapter discipline is already de facto enforced (zero `<genesis.h>` leaks) — codify it before drift makes it expensive.

## Answers

**1. Adapter boundary — HARD rule.** `<genesis.h>`, `VDP_*`, `XGM_*`, `JOY_*`, `SYS_*` symbols permitted ONLY under `src/sgdk_adapter/`, `src/genesis_shell.asm`, `src/nes_io.asm`. CI fails on violation. Zero leaks today is a free win — lock it.

**2. Version policy — PIN the SHA.** Submodule pinned to `ef9292c` (v2.11). Update memory: v2.00 is stale. Upgrade requires: (a) ADR documenting why, (b) full reproducibility re-baseline, (c) parity oracle re-run. No rolling. Fork only if we patch SGDK; until then, upstream pin.

**3. Audio — KEEP custom driver default, XGM2 as fallback.** Custom driver is NES-accuracy spec material (envelope cadence, sweep, frame counter). XGM2 is Genesis-native sample/PCM path. Measurement trigger: if custom driver costs >15% frame budget OR fails parity oracle on >2 songs, promote XGM2 for that subsystem. Document in audio ADR.

**4. Phase 15 — HYBRID per-subsystem with default = SGDK.** Per Prime Directive item 6 (LLM efficiency), SGDK API is default. Hand-rolled VDP only when: profiler shows hot path AND benchmark proves >20% gain AND covered by adapter unit test. Rationale: maintenance + review-ability outweigh micro-perf for non-hot paths.

**5. Phase 12 promotion gate — BOTH grep checks.** `grep -rn '<genesis.h>\|VDP_DATA\|VDP_CTRL\|0x00C00000\|\$C00000' src/ --exclude-dir=sgdk_adapter`. `intro_title.c` is the canary — fails today, must be refactored to call `render_adapter` before any further promotions.

**6. Phase 17 — YES, record SGDK SHA in manifest, refuse on drift.** `MANIFEST.sha256` gains `SGDK_COMMIT=ef9292c...` line. Build script reads submodule HEAD, compares to pinned value, hard-fails on mismatch. Final.md byte-identity requires deterministic toolchain — SGDK bump invalidates all prior baselines.

**7. Rule additions:**
- Master plan Execution Rules: *"No `<genesis.h>` outside `src/sgdk_adapter/`. SGDK SHA pinned in `tools/sgdk_pin.txt`; bumps require ADR + baseline regen."*
- Roadmap Development Rules: *"All Genesis hardware access flows through adapter API. Raw VDP writes only in three legacy files; expansion requires architecture review."*

**8. tools/ additions:**
- `tools/check_adapter_boundary.py` — greps forbidden symbols outside whitelist, exit 1 on violation
- `tools/check_raw_vdp.py` — detects `$C00000`, `VDP_DATA`, `VDP_CTRL` outside whitelist
- `tools/check_sgdk_pin.py` — reads `git -C sgdk rev-parse HEAD`, compares to `tools/sgdk_pin.txt`, fails on drift
- Wire all three into `build.bat` pre-link and Phase 12/17 gates

**9. Plan adequacy: YELLOW.** Boundary discipline exists in code but not in policy. Version pin missing. Reproducibility gate has a silent SGDK hole. Not RED (zero leaks today), not GREEN (no enforcement).

**10. Top 5 changes ranked:**
1. **Pin SGDK SHA + manifest record** (high impact, near-zero risk) — closes Phase 17 hole
2. **Add three tools/ checkers + wire to build** (high impact, low risk) — converts de facto to de jure
3. **Refactor `intro_title.c` raw VDP → adapter** (medium impact, low risk) — removes only canary leak
4. **Update memory v2.00 → v2.11 + ADR for SGDK policy** (low impact, zero risk) — corrects stale state
5. **Phase 15 hybrid policy doc with hot-path gate** (medium impact, medium risk) — prevents premature hand-rolling
