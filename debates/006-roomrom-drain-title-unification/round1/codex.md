1. **Pick: A.** Unify now: move RoomRom into `src/game/`. B is wrong long-term because it infects the clean Genesis-native path with `nes_ram`, helper shims, and transpile ABI debt. C is just delayed failure. Prime Directive says best long-term, NES accuracy as spec, Genesis-native impl, and agent-efficient planning. A is the only path satisfying all four.

2. **Plan / commits:**
   1. `commit 1`: add Title.md debug boot flag: skip intro/title/story crash path and jump straight to gameplay. Cite `memory project_title_story_crash`.
   2. `commit 2`: move RoomRom files into `src/game/{room,hud,combat,items,world,cave,...}/`; preserve names where possible.
   3. `commit 3`: update main `build.bat`/make inputs to compile moved native modules, not RoomRom separately.
   4. `commit 4`: mark drained runtime as reference-only under `tools/audit/drain_findings/`; ensure no production link dependency on A4 bridge.
   5. `commit 5`: cave end-to-end: native cave module uses `src/state/` typed structs while checking behavior against `cave_runtime.c`.

3. **Top risks:**
   **Build breakage:** move in thin slices; compile after each subsystem.
   **Behavior drift from NES:** use drained MATCH functions as oracle before replacing behavior.
   **Title.md complexity:** debug boot must be one guarded path, not another frontend architecture.

4. **Rule D1 reconciliation:** D1 stays mandatory, but “drain-first” means **spec-first**, not **ship transpile bridge**. For each subsystem: read drain, document NES behavior, port Genesis-native, verify against drain/NES.

5. **`feedback_full_native_rewrite`:** A directly follows it. B violates it by reintroducing `nes_ram`, shim helpers, and A4-era assumptions.

6. **Phase 12 gate:** A simplifies it. Phase 12 becomes “delete remaining transpile path and prove parity,” not “merge two architectures under deadline.”

7. **Fast iteration:** preserve it. Recreate RoomRom’s value inside Title.md via debug boot and gameplay entry points. Do not preserve the separate tree.

8. **Estimate:** first commit: same day, likely 2-4 hours. Cave unified end-to-end: 1-2 days if build friction is normal; 2-3 if RoomRom assumptions are tangled.

9. **Master plan changes:** Rule D1 becomes “Drain-as-oracle before native implementation.” Phase 3 task list starts with debug boot, RoomRom move, cave native integration, then subsystem-by-subsystem replacement. Phase 12 gate changes to deletion/parity audit only.

10. **Autonomous achievability: GREEN/YELLOW.** Green technically. Yellow because file moves plus build scripts can expose hidden coupling, but Codex/Claude/Gemini/Copilot strengths fit A best: Codex moves/builds, Claude audits behavior, Gemini cross-checks NES intent, Copilot assists localized edits.
