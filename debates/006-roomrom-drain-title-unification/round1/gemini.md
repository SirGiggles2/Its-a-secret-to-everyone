**ADVISOR 1 (Grok/Architecture):** Two trees bad. One tree good. RoomRom is clean Genesis-native. Drain is verified NES logic but chained to ugly `a4` transpile bridge. Pick A.

**ADVISOR 2 (Rex/Process):** B pollutes our clean RoomRom with transpile debt. C builds a time bomb for Phase 12. Path A is only way to survive. "Best long term."

**ADVISOR 3 (Zog/Speed):** Fast iteration is lifeblood. If we move RoomRom into main `src/`, we MUST build a debug boot flag to skip the Title.md crash and jump straight to gameplay.

**ADVISOR 4 (Prime/Synthesis - THE ANSWERS):**

1. **Pick A.** Unify RoomRom into `src/` NOW. Main tree becomes the single source of truth. B drags transpile debt into clean scaffolding. C guarantees a Phase 12 mass-merge disaster. 
2. **Plan:**
   - Commit 1: Add `DEBUG_BOOT_GAMEPLAY` flag in main `genesis_shell.asm` or frontend `main.c`. 
   - Commit 2: Wire flag to skip intro/title and jump straight to a dummy gameplay init.
   - Commit 3: Move `RoomRom/src/*.c` into `src/game/` (room, hud, combat).
   - Commit 4: Update main `build.bat` and `md.ld`. Delete `RoomRom/`.
3. **Risks & Mitigation:**
   - *Risk 1:* Main build breaks from duplicate symbols. *Mitigation:* Namespace or isolate RoomRom files during move.
   - *Risk 2:* Debug boot state differs from real boot. *Mitigation:* Use exact same `state/` struct initialization.
   - *Risk 3:* Lose transpile drain connection. *Mitigation:* Drain files stay in `src/game/` as reference until overwritten natively.
4. **Reconcile D1 (Drain-first):** Unification makes D1 actionable. Drain files live next to native files in one tree. Read drain C -> write Genesis native C -> verify.
5. **Reconcile `feedback_full_native_rewrite`:** Path A *is* the vehicle for the native rewrite. RoomRom provides the clean native architecture; main tree provides the destination.
6. **Phase 12 Gate:** Simplifies drastically. Instead of "Merge two parallel universes," Phase 12 becomes "Delete dead transpile bridge files."
7. **Fast-iteration:** RECREATED in main tree via debug boot. We keep the sub-second compile-to-gameplay loop without the dual-tree headache.
8. **Time:** 1-2 days. First commit (debug boot) in 2 hours. Cave unified end-to-end within 48 hours.
9. **Master Plan:** Insert Phase 3.0: Unify RoomRom into Main. Update D1: "Use unified tree for drain-first reference." Change Phase 12 to purely cleanup.
10. **GREEN.** File moves, `#ifdef` boot flags, and build script updates are perfect tasks for autonomous AI orchestration. Easy win.
