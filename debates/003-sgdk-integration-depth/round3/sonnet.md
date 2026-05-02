# SONNET ADVISOR — Round 3 (Final Resolution)

## 1. AUDIO TRIGGER FORMULA — adopt Opus's tightened formula, with my safety valve

**Decision: `>10% audio_tick CPU OR any parity-oracle song failure surviving 1 debug cycle OR >8KB driver footprint`.**

I concede my Round 1 "2-of-3" gate to Opus's tighter OR-formula on the first two clauses — a parity-oracle song failure that survives one debug cycle is, by definition, a structural defect, and gating migration on *three* of those is malpractice. But I keep the >8KB footprint clause as a third independent OR: ROM pressure is a real failure mode that neither CPU nor parity oracle catches. Gemini's "frozen legacy / new tracks XGM2" splits the runtime in two and doubles the surface area we have to keep NES-accurate — rejected.

**Measurement:** `tools/audio_perf_probe.lua` runs once per release on the parity matrix (overworld, dungeon, item-get, death, intro, item-scroll); records `audio_tick` cycles via Z80 PC-sampling and driver `.bss+.data` size from the linker map. Trigger evaluated in CI on every tagged build. Migration is an ADR-gated one-way door, not an automatic flip.

## 2. FORK POLICY

- **Who decides:** the human (project owner). LLMs propose with evidence (failing test + minimal reproducer + upstream issue link); human signs off via ADR.
- **Qualifies:** (a) a build-breaking SGDK bug blocking a milestone gate, AND (b) an upstream PR/issue exists and has been open >14 days with no maintainer response or has been explicitly rejected, AND (c) the patch is <200 LOC and touches no SGDK public ABI. Anything bigger means we picked the wrong dependency — escalate, don't fork.
- **Downgrade path:** fork lives at `vendor/sgdk-fork/` with a `PATCHES/` directory of `.patch` files rebased on the pinned upstream SHA. Every release attempts a clean `git am` against latest upstream tag; first clean apply auto-opens a PR to drop the fork and revert to upstream pin. No silent perma-forks.

## 3. src/zelda_translated/, src/gen/, src/c_shims.asm, src/audio_driver.asm SCOPE

**Whitelist, not enforcement gate.** All four are explicit exceptions in `tools/check_adapter_boundary.py` and `tools/check_raw_vdp.py` allowlist. Rationale: `src/zelda_translated/` is mechanically generated 6502→m68k output (transpiler is the real source); `src/gen/` is passive generated data per `project_best_practices`; `src/c_shims.asm` and `src/audio_driver.asm` are explicitly the boot/IO/hot-path ASM the north-star permits. Forcing them through the adapter would either (a) require the transpiler to emit adapter calls (massive scope creep, breaks determinism) or (b) hand-edit generated files (violates "gen/ passive"). Whitelist these four paths in the checker; the rule still bites where it matters: owned C under `src/game/` and `src/frontend/`.

## 4. ADAPTER SIGNATURE STYLE — Option C (Hybrid), per Prime Directive

**NES-semantic for parity-critical (audio/APU/PPU register semantics), thin SGDK wrappers for Genesis-native (sprite/DMA/scroll).**

The Prime Directive is "NES accuracy as spec; Genesis-native as implementation." Audio is *spec-carrier* — `apu_write($4015, mask)` preserves the 6502 mental model that the parity oracle, the F3 audit, and the MIDI pipeline all share. Pure NES-semantic for sprite/DMA discards what SGDK gives us for free (sprite engine, DMA queue, tile cache) and creates a translation layer that re-introduces every bug it claims to abstract — Opus's exact argument against XGM2, applied symmetrically. Codex's Round 1 "boot/shim/adapter exception" framing supports this split. Gemini's API-first instinct is honored on the Genesis-native half.

## FINAL STANCE: **GREEN**

Substrate is clean (zero include leaks, SGDK pinned by accident at v2.11, custom audio works per F3 audit). All four unresolved issues now have measurable triggers, named owners, and concrete tooling. Three checker scripts + three SGDK rules + `intro_title.c` refactor + memory v2.00→v2.11 update closes the gap. No redesign required. Ship it.
