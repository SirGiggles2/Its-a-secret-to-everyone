# CODEX — Round 2

I still disagree with **Gemini’s commit-to-XGM2** recommendation. Gemini is right that XGM2 is more LLM-friendly and better documented, but audio here is not generic Genesis audio; it is NES-behavior preservation. **Sonnet** and **Opus** both framed the custom driver as accuracy-critical because frame counter, sweep, envelope, and length behavior are part of parity. I keep my Round 1 stance: custom remains default, XGM2 remains fallback. Migration should trigger only if custom fails parity on multiple songs/effects, exceeds a measured CPU/frame budget, blocks tooling, or repeatedly needs hand fixes XGM2 already solves.

I also update my Phase 15 position. **Sonnet’s 15% threshold** is more practical than my unquantified “measured hot path” language, and I prefer it over **Opus’s 20%** because VDP work can be tight enough that 15% is already material. New rule: hand-rolled VDP outside boot/shim/adapter requires a profiled hot path, at least **15% cycle/frame or bandwidth improvement**, adapter test coverage, and a note in `docs/handrolled_vdp.md`. A number is useful because otherwise “measured” becomes vibes.

On Phase 12, no dispute remains. **Gemini, Sonnet, Opus, and I converge** on both greps: `<genesis.h>` catches API boundary leaks; raw VDP scans catch the real hostile pattern. `intro_title.c` proves the include-only gate is insufficient.

Peers exposed three gaps in my Round 1 answer. First, I did not quantify the raw VDP threshold; fixed above. Second, **Sonnet** gave the clearest promotion order: refactor `intro_title.c` before locking the rule. I agree. The code should be made compliant first, then the gate becomes non-controversial. Third, **Opus** and **Sonnet** were more explicit about the audit artifact: pinning should not just be “a checker,” but a documented SHA/tag/date/reason plus manifest enforcement.

Refined top 5 plan changes:

1. Refactor `src/frontend/intro/intro_title.c` through `src/sgdk_adapter/` before enabling hard failure.
2. Add Phase 12 gates for both `<genesis.h>` and raw VDP/register literals outside adapter/approved low-level files.
3. Pin SGDK `ef9292c...` / v2.11 in a doc plus machine-readable manifest; fail Phase 17/build drift.
4. Update stale memory from SGDK v2.00 to v2.11 everywhere it influences planning.
5. Codify Phase 15: SGDK API default; raw VDP only for boot/shim/adapter or measured 15% hot-path wins.

Final stance: **YELLOW**, but close to green once the leak, pin, and gates land.
