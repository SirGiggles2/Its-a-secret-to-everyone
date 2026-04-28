# Build Chain Decision (S1 Phase C, Task C1)

**Date:** 2026-04-28
**Spec ref:** [`2026-04-27-native-genesis-rewrite-design.md`](../superpowers/specs/2026-04-27-native-genesis-rewrite-design.md) Section 7 stage S1
**Plan ref:** [`2026-04-28-s1-reorg-sgdk-integration.md`](../superpowers/plans/2026-04-28-s1-reorg-sgdk-integration.md) Phase C
**Plan recommendation:** adopt `sgdk/makefile.gen`
**SGDK audit recommendation:** adopt `sgdk/makefile.gen`
**Decision:** **EXTEND `build.bat`** — keep owned build harness, add SGDK lib link only. Reject `makefile.gen` adoption for S1.

---

## Options surveyed

### A. Adopt `sgdk/makefile.gen` (plan/audit recommendation)

234-line GNU makefile shipped with SGDK 2.11. Drives every SGDK sample build. Auto-discovers `*.c` / `*.s` / `*.asm` via `$(wildcard $(SRC)/*/*.c)` etc., emits link cmd file, builds via `m68k-elf-gcc -O3 -flto -ffunction-sections -fdata-sections -fuse-linker-plugin`, links against `libmd.a` + `sega.s` boot + `rom_head.c` header, post-processes with `sizebnd.jar -checksum`.

**Pros:**
- Battle-tested across SGDK ecosystem.
- ResComp / XGM2 / LZ4W resource pipeline integrated for free.
- Standard `release` / `debug` / `asm` targets.
- Less long-term maintenance once adopted.

**Cons:**
- **Boot-path conflict.** `makefile.gen` builds against SGDK's `sega.s` boot + `rom_head.c` header. We own `genesis_shell.asm` as the entry point and ROM header source. Adopting the SGDK boot path means rewriting/replacing `genesis_shell.asm` first — which is exactly the work S1 Phase F is meant to enable on a stable build chain, not the precondition for it.
- **No transpile / extract / lint hook points.** Our `build.bat` runs `tools/transpile_6502.py`, `tools/extract_intro_assets.py`, `tools/extract_fs_assets.py`, `tools/emit_gen_wrappers.py --check`, `tools/probes/lint_legacy_symbols.py`, `tools/probes/phase_sequence_probe.py`. None of these are makefile.gen targets. Re-wrapping them as makefile rules is doable but is its own multi-day refactor.
- **Auto-discovery would catch unwanted files.** `$(wildcard $(SRC)/*/*.c $(SRC)/*/*/*.c)` would pick up `src/zelda_translated/*.asm` and any future stray .c — link-order unpredictable. Hash-stability requires deterministic file ordering, which the wildcard expansion gives in practice (sorted by `make`) but couples ROM bytes to filesystem layout.
- **`-O3 -flto -ffunction-sections --gc-sections` differs from current `-O2`.** ROM bytes will drift to a new baseline. Anticipated by plan C2 step 5 ("ROM hash will likely DIFFER from baseline... acceptable IF visual movies still play"), but a forced drift before canonical movies exist (Phase F1) means visual verification is the only safety net during the rewire — and BizHawk-Lua probes against undefined "expected" output cannot catch regressions.
- **Make tooling dep.** Adds `sgdk/bin/make.exe` to the chain on Windows. Fine in practice (the bin is already vendored) but another moving part.

### B. Extend current `build.bat`, add SGDK lib link only (this decision)

Current `build.bat` (415 lines) drives the full pipeline today. Phase B left it with ~17 compile loops, ~10 source variables (split for link-order preservation), and a working ROM at hash `b8d6542d…`. Two consecutive builds at the post-B7 tip produce byte-identical output.

**Required Phase C extensions:**
1. Add `-I "%ROOT%\sgdk\inc"` to every C compile loop (or a single shared CFLAGS variable to dedupe).
2. Add `-L "%ROOT%\sgdk\lib" -lmd` (and `-lgcc` for the libgcc helpers SGDK uses) to the linker invocation at line ~148. This makes SGDK's `VDP_*`, `DMA_*`, `SPR_*`, `JOY_*`, `PAL_*`, `XGM2_*`, `SYS_*`, `MEM_*` symbols available to owned C without dragging in SGDK's boot path.
3. Verify `-ffixed-a4` stays compatible with libmd.a (SGDK was confirmed A4-SAFE in `docs/audit/sgdk_integration.md`; smoke test: link a no-op SGDK call and confirm A4 isn't clobbered).
4. Optionally hoist the duplicated `-I` flag block + GCC flag block into shared `set "CFLAGS=…"` / `set "INCLUDES=…"` variables to cut the 17-loop churn on future moves.

**Pros:**
- **Zero hash drift expected.** Lib link adds new symbols to the linker's table but only the symbols actually referenced by owned C end up in the ROM (`-Wl,--gc-sections` not in use; ld pulls only referenced .o from `libmd.a`). Until Phase F retargets frontend onto `VDP_*`, no SGDK code lands in the ROM. Hash should hold at `b8d6542d…` through C2 → F1.
- **Boot path unchanged.** `genesis_shell.asm` keeps owning entry, vectors, IRQ. F-phase frontend cutover migrates *individual call sites* from raw VDP writes onto SGDK API without touching boot.
- **All transpile / extract / lint / probe hooks intact.** No re-plumbing.
- **Determinism guarantees preserved.** Manual C_SOURCES variables explicit about link order; B5 already proved sensitivity matters.
- **Lower-risk per the SGDK audit's own constraints.** Audit Open Issue #6 says "battle-tested, knows about ResComp / XGM2 packaging, less to maintain" — but ResComp/XGM2 are not in scope until S11. Until S11 the ResComp argument is theoretical.

**Cons:**
- ~17 compile loops with duplicated -I flag blocks. Maintenance smell. Mitigation: shared CFLAGS variable in C2.
- Reinvents pieces of `makefile.gen` (link cmd file generation, OBJ list assembly). Mitigation: it already works; the reinvention is paid for.
- Migration to `makefile.gen` later is its own task. Mitigation: revisit at S11 when XGM2 audio packaging makes makefile.gen genuinely valuable.

### C. Hybrid (rejected)

Keep `build.bat` as the orchestrator; have it invoke `make -f sgdk/makefile.gen` for a subset (e.g. SGDK sample compilation as a smoke test). Doesn't solve the boot-path conflict; adds make as an inner dependency. No upside vs. B.

---

## Decision

**Option B — extend `build.bat`, add SGDK include path + libmd link.**

Rationale:
1. Boot path conflict is the dealbreaker. `makefile.gen` requires SGDK's `sega.s` as the entry. We own `genesis_shell.asm`. Replacing it before Phase F frontend cutover means rewriting boot + frontend in the same change, which is exactly what plan Section 9 risk R1 ("Render API design wrong") and R6 ("Two render code paths drift") were sequenced to avoid.
2. Hash stability through C2 is high-value. Phase F's parity acceptance is "Genesis-vs-Genesis byte-identical" against the locked baseline (spec Section 0). Drifting the baseline at C2 (as plan C2 step 5 anticipates) replaces a reliable equality check with a "looks right in BizHawk" judgement call. We should defer all baseline drift to Phase F where the change is intentional and per-call-site verifiable, not bundle it with build-chain swaps.
3. SGDK lib link is sufficient. We need SGDK's `VDP_*` / `SPR_*` / etc. symbols available to owned C in Phase F — that's what `-L sgdk/lib -lmd` delivers. No other piece of `makefile.gen` is load-bearing for S1.
4. Plan/audit recommendations are not load-bearing. Both said "adopt makefile.gen" but neither weighed the boot-path or hash-stability tradeoffs against an extension that achieves the same Phase F prerequisite (SGDK API reachable) with lower risk.

**Revisit trigger:** S11 (audio integration). XGM2 driver ships with `makefile.gen` integration; if our owned audio-data conversion pipeline can't match, switching to `makefile.gen` may become net-positive then.

## C2 implementation plan (revised)

Plan Phase C2 as written ("Adopt SGDK makefile.gen") is replaced by:

**C2a. Add SGDK include path to every C compile loop.**
- Insert `-I "%ROOT%\sgdk\inc"` into the existing CFLAGS-equivalent block in each of the ~17 compile loops.
- Optional: refactor to a shared `set "INCLUDES=…"` + `set "CFLAGS=…"` variable to cut duplication.

**C2b. Add SGDK lib link.**
- Modify the linker invocation at `build.bat:148` (`"%M68K_LD%" -T "%LD_SCRIPT%" -o "%ELF_OUT%" "%ELF_OBJ%" @"%LD_RESP%"`) to append `-L "%ROOT%\sgdk\lib" -lmd -lgcc` (or `-Wl,--start-group -lmd -lgcc -Wl,--end-group` if symbol resolution order trips).
- Verify `genesis.ld` script is compatible with libmd.a sections (SGDK uses standard `.text` / `.data` / `.bss` sections — should work, but check).

**C2c. SGDK reachability smoke test.**
- Add a tiny throwaway TU that calls `VDP_drawText` (or any exported SGDK symbol) and confirm the build links cleanly.
- Verify ROM hash unchanged from baseline `b8d6542d…` (the throwaway TU + SGDK code should not be live-reachable from the entry — verify via `nm` or `objdump` that `VDP_drawText` is in the symbol table but its callers are dead-stripped if we later drop it). *Actually* — without `--gc-sections`, the dead-code function lands in the ROM and shifts the hash. Either: (a) add `-Wl,--gc-sections` plus `-ffunction-sections -fdata-sections` to preserve hash via dead-strip (changes overall codegen — risky); (b) accept the throwaway TU only as a transient verification that's removed before commit.

Pick option (b) — verify, remove, commit.

**C2d. Commit.**
- One commit: `s1.C2: extend build.bat with SGDK include + libmd link`. Body documents the plan-deviation (option B not A) and references this doc.
- ROM hash: must match `b8d6542d…` post-removal of the throwaway smoke TU.

**C3 (SRAM static-assert fixture) is unchanged** — independent of the build-chain decision.
