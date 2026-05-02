# SONNET — Round 2 (cross-critique)

## 1. Disagreements

**Audio (vs Gemini's "commit to XGM2"):** I stand by custom-default. Gemini's "XGM2 IS WIN" because "training data big like mammoth" optimizes for *LLM comfort*, not NES accuracy — which the project rules (`feedback_nes_feel_genesis_native`) explicitly subordinate. The F3-era audit (`project_midi_substrate_works`) proved the custom driver works end-to-end; rewriting to XGM2 throws away frame-counter / sweep / length-counter parity for ergonomics. Codex and Opus both land in the same camp with measurement triggers — that's the right gate. Gemini's CPU>15% spike trigger is fine *as one signal*, but a single signal is a hair trigger; my round-1 "any 2 of {3 unfixable bugs / >8KB / >10% CPU}" stands.

**Hand-rolled VDP threshold:** Opus at 20%, me at 15%, Codex/Gemini unquantified. I'll defend 15%: at 20% you exclude a real class of inner-loop wins (DMA-queue micro-optimizations, sprite-list packing) that genuinely matter on 7.6MHz 68k. At <15% the maintenance/LLM-debug cost dominates per Prime Directive #6. Codex's "exception-only" without a number is a loophole — somebody will argue every case is the exception. **Final: ≥15% measured win on a profiled hot path, listed in `docs/handrolled_vdp.md`, with the SGDK call it replaced cited inline.**

## 2. Gaps peers exposed

**Opus's MANIFEST.sha256 line vs my separate `docs/sgdk_pin.md`:** Opus is right — adding `SGDK_COMMIT=...` to the existing `MANIFEST.sha256` is one fewer file, one fewer thing to drift, and reuses the manifest infrastructure that already gates Final.md. Conceding: pin lives in `MANIFEST.sha256`, ADR/audit note lives in `docs/sgdk_pin.md` for the *why*.

**Codex's audit doc framing:** I called it `docs/sgdk_pin.md` (mechanical); Codex's "SGDK audit note" is better — it forces *reasoning* (why this SHA, what was tested, what broke last time). Adopting.

**Gemini's `build.bat` SHA check:** I had it in `tools/check_sgdk_pin.py` only. Wiring directly into `build.bat` (not just CI) catches local drift before a bad ROM ships. Adopting.

## 3. Refined TOP 5

1. **Add raw-VDP grep to Phase 12 promotion gate** + `<genesis.h>` include grep (belt + suspenders; `intro_title.c` is the canary).
2. **Pin SGDK SHA in `MANIFEST.sha256`** (per Opus) + `docs/sgdk_audit.md` reasoning (per Codex); `build.bat` hard-fails on drift (per Gemini).
3. **Refactor `intro_title.c` through adapter BEFORE Phase 12 lock-in** (panel converges).
4. **Codify SGDK-1/2/3 rules** in master plan + roadmap (boundary / pin / hand-rolled-VDP-≥15%-gate).
5. **Update `project_what_if` memory v2.00 → v2.11** (panel converges).

## 4. Final stance: **YELLOW**

Substrate is GREEN (zero include leaks, SGDK accidentally pinned, custom audio works). Plan is YELLOW (no codified policy, no manifest pin enforcement, `intro_title.c` raw-VDP leak, stale memory). Three tools + three rules + one refactor closes it.

## 5. Convergence verified
- Phase 12 BOTH greps: confirmed (Codex/Gemini/Opus/me all agree).
- `intro_title.c` refactor BEFORE lock-in: confirmed.
- Memory v2.00→v2.11 update: confirmed.
