# OPUS ADVISOR — Round 3: Final Resolution (Architecture-First)

## 1. AUDIO TRIGGER FORMULA — adopt Sonnet's 2-of-N, refined.

**Pick:** *Migrate (or escalate to ADR) when ANY 2 of the following fire within a rolling 90-day window:*
- `audio_tick` profile sample > **10% of frame budget** (measured by `tools/cycle_envelope.py` against the regression matrix, run nightly + on every audio commit).
- **Parity-oracle song failure** that survives one full debug cycle (one fix attempt, re-run `tools/parity_oracle_diff.py`; failure persists → counts).
- **Driver footprint > 8KB** (measured at link time from `builds/Title.lst` symbol table; gated in `tools/check_audio_footprint.py`).
- **3 unfixable parity bugs** (issues open >30d with `audio-parity` label) accumulated in 90d.

I withdraw my r2 single-signal proposal — Sonnet is right that one signal is hair-trigger and burns the one-way door prematurely. I reject Gemini's "freeze legacy / new = XGM2" because it bifurcates the audio path, doubles surface area, and creates a permanent translation seam that no measurement justifies today. **Measurement cadence:** nightly CI (cycle envelope + parity oracle), weekly footprint check, manual 90-day issue-label sweep on the first of each month.

## 2. FORK POLICY.

- **WHO decides:** *project owner only*. Fork is a supply-chain commitment (we own backports forever). Solo+LLM team cannot afford ADR-by-committee here. Any contributor may *propose* via ADR draft; owner ratifies.
- **QUALIFIES as fork-worthy:** (a) security CVE with no upstream patch in 14d, (b) parity blocker that fails the parity oracle and upstream PR is rejected/stalled >30d, (c) reproducibility break (toolchain non-determinism) upstream refuses to fix. **Performance alone is not fork-worthy** — hand-roll behind the adapter instead.
- **DOWNGRADE path:** when upstream merges an equivalent fix OR the patched subsystem is rewritten to no longer need the patch, fork is abandoned within one release cycle. ADR records the un-fork. `tools/check_sgdk_pin.py` flips back to upstream SHA + `--accept-sgdk-bump` regen.

## 3. src/zelda_translated/, src/gen/, src/c_shims.asm, src/audio_driver.asm — gate scope.

Architecture lens: the boundary checker enforces the **rule that owned C code must not import SGDK directly**. It does not enforce "no Genesis hardware ever touches this directory." Per-directory:

- **`src/zelda_translated/`** — WHITELIST from `<genesis.h>` check; ENFORCE raw-VDP check. Transpiled code is code-gen output, not owned, but it must not invent new raw VDP writes (those would come from the transpiler, which is owned). Gate the *transpiler*, not the output.
- **`src/gen/`** — WHITELIST both checks (passive generated data per `project_best_practices`). Gate the *generator script* in `tools/`.
- **`src/c_shims.asm`** — WHITELIST (boot/IO/hot, per best-practices ASM carve-out).
- **`src/audio_driver.asm`** — WHITELIST (boot/IO/hot; this *is* the spec carrier per Divergence 1).
- **`src/sgdk_adapter/`, `src/genesis_shell.asm`, `src/nes_io.asm`** — WHITELIST (the adapter itself).
- **Everything else under `src/game/`, `src/frontend/`** — ENFORCE both greps. No exceptions.

## 4. ADAPTER SIGNATURE STYLE — **C (Hybrid)**.

Per Prime Directive: NES accuracy is spec, Genesis-native is impl, LLM-friendly is tiebreaker. Pure-A (Sonnet-leaning) over-abstracts the Genesis-native paths SGDK already nails (sprite/DMA/joypad) — pays code cost for swappability we will never exercise. Pure-B (Gemini-leaning) leaks SGDK semantics into game code, defeating the boundary's whole purpose. **Hybrid:** NES-semantic primitives where parity is the contract (`audio_write_apu_reg(reg, val)`, `oam_write_nes(slot, y, tile, attr, x)`, `palram_write(idx, nes_color)`); thin SGDK wrappers where Genesis is the spec (`render_sprite(x, y, tile, attr)` → `SPR_addSprite`, `dma_queue_tiles`, `joypad_read`). Disagreeing with Sonnet's implicit pure-A: maximal swappability is not free — it costs LLM-debug clarity at 2am, the very thing we are optimizing for.

## FINAL STANCE: **GREEN**.

Panel converged on substrate (boundary, pin, gates, refactor order, memory update). The four R3 unresolveds are policy-shaped, not architecture-shaped — once codified as above, the plan is adequate for execution. Ship it.
