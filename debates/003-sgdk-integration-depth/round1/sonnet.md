# SONNET — Round 1

**Stance: GREEN-LEANING-YELLOW.** Adapter discipline already de facto holds (zero `<genesis.h>` leaks; one VDP leak in `intro_title.c`). Plan needs codification, not redesign.

## 1. Adapter boundary — HARD RULE.
Owned `src/game/` + `src/frontend/` MUST route through `src/sgdk_adapter/`. Cost is zero today (no leaks to fix), value is permanent. Adapter layer wraps SGDK, so LLMs still get SGDK ergonomics inside the adapter; game code gets stable, named, NES-semantic primitives (`render_sprite_nes()`, not `SPR_addSprite()`). Single chokepoint = single place to swap impl, mock for tests, instrument for perf. Permissive boundary leaks SGDK types into game logic and makes the adapter cosmetic.

## 2. Version policy — PIN THE SHA, doc the bump.
Submodule pinned to `ef9292c0` (v2.11). Update `project_what_if` memory immediately — v2.00 is wrong. Policy: pinned SHA + `docs/sgdk_pin.md` recording (SHA, tag, date, reason, smoke-test result). Bumps require a PR with regenerated parity baselines and Final.md re-checksum. No rolling. No fork — fork = we own bug-fix backports forever, bad ROI for solo+LLM team.

## 3. Audio — KEEP custom driver default, DEFINE migration trigger.
Custom driver works (F3 audit confirmed). XGM2 is LLM-friendlier but rewrites lose hard-won NES timing parity (frame counter, sweep, length). **Trigger to migrate**: any 2 of {3 unfixable bugs in 90 days, ROM size pressure >8KB driver footprint, perf regression >10% CPU in audio_tick}. Until trigger, custom stays.

## 4. Phase 15 optimization — HYBRID, default SGDK.
Default: SGDK API. Hand-rolled VDP requires (a) measured perf win >15% on a profiled hot path AND (b) inline comment citing the SGDK call replaced AND (c) listed in `docs/handrolled_vdp.md`. Per Prime Directive #6, raw `$C00000` writes burn LLM accuracy at 2am — pay that cost only with evidence.

## 5. Phase 12 promotion gate — BOTH greps, raw-VDP is the real test.
`intro_title.c` is the proof: it has zero `<genesis.h>` includes but raw `$C00000` writes — the include grep would have passed it falsely. Raw VDP register addresses are the LLM-hostile pattern. Gate = `<genesis.h>` include grep (cheap belt) + `$C00000`/`VDP_DATA`/`VDP_CTRL` literal grep (real suspenders). Promotion blocked if either trips outside `src/sgdk_adapter/`, `src/genesis_shell.asm`, `src/nes_io.asm`.

## 6. Phase 17 reproducibility — YES, record + enforce.
`tools/build_manifest.py` writes `sgdk_sha`, `vasm_version`, `gcc_version`. Build refuses if recorded SHA ≠ submodule HEAD. Bumping SHA = explicit `--accept-sgdk-bump` flag + manifest regen + Final.md re-checksum committed.

## 7. Master plan prose additions.
> **Rule SGDK-1 (Adapter Boundary):** Code under `src/game/` and `src/frontend/` MUST NOT `#include <genesis.h>` and MUST NOT write VDP registers directly. All Genesis hardware access routes through `src/sgdk_adapter/`. Exceptions: `src/genesis_shell.asm`, `src/nes_io.asm`, the adapter itself.
>
> **Rule SGDK-2 (Version Pin):** SGDK submodule SHA is pinned. Bumps require updating `docs/sgdk_pin.md` and regenerating parity + Final.md baselines in the same commit.
>
> **Rule SGDK-3 (Hand-Rolled VDP):** Default to SGDK API. Hand-rolled VDP register writes require profiled >15% win, listed in `docs/handrolled_vdp.md`, justified inline.

## 8. Tooling.
- `tools/check_adapter_boundary.py` — greps `src/game/`, `src/frontend/` for `<genesis.h>` includes. Allowlist for adapter, shell, nes_io. Exit nonzero on hit.
- `tools/check_raw_vdp.py` — greps for `$C00000`, `0xC00000`, `VDP_DATA_PORT`, `VDP_CTRL_PORT` literals outside allowlist. Catches `intro_title.c` today.
- `tools/check_sgdk_pin.py` — reads pinned SHA from `docs/sgdk_pin.md`, compares to `git -C SGDK rev-parse HEAD`. Exit nonzero on drift.
- All three wired into `build.bat` pre-build and Phase 12/17 gates.

## 9. Stance: GREEN-LEANING-YELLOW.
Substrate is good (adapter exists, leaks ~zero, SGDK pinned by accident). Plan is silent on policy. Three small tools + three rules close it.

## 10. Top 5 ranked changes.
1. **Add raw-VDP grep to Phase 12** — catches `intro_title.c`-class leaks the include grep misses. (high impact, zero risk)
2. **Pin SGDK SHA in build manifest + Phase 17 gate** — kills silent reproducibility breaks. (high impact, low risk)
3. **Refactor `intro_title.c` through adapter** — only existing leak, fix before locking the rule. (medium impact, low risk)
4. **Update `project_what_if` memory v2.00 → v2.11** — stale memory poisons future planning. (low impact, zero risk)
5. **Write SGDK-1/2/3 rules into master plan + roadmap** — codify what is already true. (medium impact, zero risk)
