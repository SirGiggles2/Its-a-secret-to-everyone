**ADVISOR 4 (Prime/Synthesis) — Round 2 Verdict**

1. **Pick D2 (Unified Pointer, No A4 Pinning).**  
   Path A is dead by user decree. D2 is the only choice that honors "Best Long Term." A4-register pinning is transpile-era radiation. It forces `-ffixed-a4` across the whole tree, poisoning clean code. D2 kills the debt. `nes_ram` becomes a standard `extern u8*`. Title.md loses a tiny perf edge; the codebase gains a soul.

2. **Concrete Plan Adjustments:**  
   - **Commit 1:** Refactor `platform_abi.h`. Change `nes_ram` from `asm("a4")` to a standard global pointer. Remove `-ffixed-a4` from compiler flags.  
   - **Commit 2:** Move `RoomRom/src/` logic into `src/game/`. RoomRom becomes a specific *build target* of the main tree, not a separate folder.  
   - **Commit 3:** Update `build.bat` to output two binaries: `title.bin` (full game/shell) and `roomrom.bin` (gameplay-only).

3. **Fast Iteration:**  
   `roomrom.bin` remains the speed king. It links the shared `src/game/` logic but uses the RoomRom boot-path to skip the Title.md intro/FS crash. We keep the sub-second compile-to-gameplay loop without the dual-tree headache.

4. **Rule D1 + Native Rewrite:**  
   D2 *is* the `feedback_full_native_rewrite`. Moving away from register-pinned globals is the transition from "transpiled mess" to "Genesis native." Drain remains the oracle; we just change the substrate it runs on.

5. **Phase 12 Gate:**  
   The "combine" deliverable is now the **Unified Source Tree**. Phase 12 is successful when `src/game/` compiles for both targets with zero duplicated logic. The ROMs stay separate for testing, but their brains are identical.

6. **Ranking:**  
   - **D2 (Elite):** Clean C. No compiler hacks. Highest maintainability.  
   - **D3 (Acceptable):** `#ifdef` mess. Keeps A4 rot alive.  
   - **D1 (Failure):** Parallel header hell. Guaranteed drift.

7. **Autonomous Achievability: GREEN.**  
   Refactoring `nes_ram` and updating build targets are mechanical tasks perfectly suited for AI orchestration. No complex logic porting required yet.

8. **New Top Risk:**  
   **Pointer Initialization.** If `nes_ram` isn't set to `$FF0000` (Title) or a local buffer (RoomRom) in the first 10 instructions, the CPU hits the void. 

9. **Final Stance:**  
   **D2.** We are building a Genesis game, not a transpiled NES emulator. Kill the A4 pinning, unify the source, and ship two ROMs.

**Convergence:** Drain-as-oracle (not runtime), debug boot is mandatory, first commit is the `nes_ram` pointer refactor.
