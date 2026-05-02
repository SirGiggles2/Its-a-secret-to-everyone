# Sonnet Round 2 Cross-Critique

## 1. Points from CODEX, GEMINI, OPUS I AGREE with

**Codex — Task 1.11 strict no-fallback build gate:** Codex's addition of a hard-fail gate (no silent fallback to checked-in derived assets) directly solves the gap I identified in Phase 1: Task 1.10 is too soft. From an implementer's view, a warning that is skippable at 2am is no gate at all. Correct.

**Codex — Task 2.8 parity oracle schema (frame/input/RNG/room/link state/enemy slots/RAM bytes/CRAM/SAT/plane/screenshot hash):** My Round 1 flagged Phase 7/8 probes as dangerously vague. Codex's schema spec is the concrete fix. Every field in that schema maps to something an implementer actually needs to diff. Actionable and correct.

**Opus — Task 0.6 worktree merge protocol:** Opus named a protocol for the worktree hand-off that I flagged as missing. The precise fix — a committed merge protocol doc before Phase 12 promotion begins — is exactly right. The memory rule `feedback_check_worktree_first` is already the hardest gate in the project; without a written protocol, agents will keep violating it at promotion time.

**Opus — Phase 1.5 NES Reference Capture Harness:** Every "compare to NES" task in the plan currently reinvents the capture. A single `tools/nes_capture/` producing deterministic `build/generated/nes_reference/<rom_hash>/` outputs is the right infrastructure investment. I agree this is a Phase 1 deliverable, not a Phase 7+ improvisation.

**Gemini — Move SRAM/save core from Phase 9 to Phase 3:** NES Zelda 1 is entirely state-driven. Building 6 phases of gameplay on top of an SRAM layout that hasn't been committed is exactly the integration hell scenario I flagged via the "unless" parenthetical in Task 9.2. Moving SRAM foundation earlier is correct.

---

## 2. Points from CODEX, GEMINI, OPUS I DISAGREE with

**Gemini — "Clean room trap" warning about 6502→C behavior map at `docs/logic/` (Phase 0.5):** Gemini argues that implementing by visual reference instead of 1:1 6502→C logic port produces hitbox/timing drift and proposes a new Phase 0.5 behavior map doc. This conflates two things. The existing codebase is already a transpiled 6502→M68K codebase (see `tools/transpile_6502.py`, `src/abi/platform_abi.h` line 25: `register volatile unsigned char *nes_ram asm("a4")`). The state headers are NES RAM macro shims precisely because the transpiler already ported the logic. Adding a Phase 0.5 behavior map doc adds documentation work but does not prevent visual-reference drift for the portions of the plan that are NOT transpiled — specifically Phase 7/8 enemy rewrites and Phase 6 collision. The right gate is Codex's Task 2.8 parity oracle schema + Opus's Phase 1.5 NES capture harness, not a prose behavior map that no agent will reference at the point of maximum divergence risk.

**Opus — Phase 14 "18 parallel per-dungeon canonical movie agents":** Opus's counter to manual playthrough (18 parallel agents each running a per-dungeon input movie) is not executable either. BizHawk input movies require a precisely seeded starting state or they desync immediately. Without the per-dungeon save-state injection harness I proposed in Round 1 (Task 14.0, `tools/dungeon_harness/`), parallel movie agents will produce 18 desync failures. The save-state-first approach must precede any parallel movie strategy. Opus's proposal skips the precondition.

**Gemini — "Dangerous bifurcation" for two-ROM split (Title.md / RoomRom.md):** Gemini calls the two-ROM split dangerous because it delays shared `genesis_shell.asm` / IRQ handler unification. But the existing codebase already has this split: `builds/whatif.elf` and `builds/vgmrom/` are separate build targets right now (see git status). The split is not a new risk introduced by the plan — it is the current state. Gemini's warning is correct in principle but the fix (shared IRQ handlers by Phase 3) ignores that RoomRom S1 work lives in a separate worktree. Forcing shared IRQ handlers before Phase 12 means cross-worktree header dependency, which triggers the exact worktree divergence risk Opus correctly flagged.

---

## 3. The Single Highest-Impact Change to Make

**Commit the SRAM map and state contract audit before Phase 2 Task 2.1.**

Everything else — parity probes, enemy dispatch, promotion, options, multiplayer — reads from state. Right now, every `src/state/*.h` is a raw NES RAM macro shim over `nes_ram[]` (confirmed: `room_state.h` line 7 through 77, `enemy_state.h` line 9 through 134 — every single entry is `RAM()` or `OBJ()`). Phase 12's promotion gate says "typed src/state/ struct." That gate is structurally broken today. If the plan lands as-is, Phase 12 will be the first moment anyone discovers the state contract was never defined. By then, 11 phases of code will be written against macro shims. Locking down whether macro shims ARE the contract (and why that is acceptable for Genesis-native NES-accuracy work) or whether they must be migrated to typed structs unlocks every downstream phase gate without requiring retroactive rewrites.

---

## 4. Updated Stance

**YELLOW** — The plan's structure is sound and the convergence across all four advisors on parity oracle + builder gate + state contract confirms the highest-risk items are correctly identified, but the state contract gap is live in the repo today and must be resolved before Phase 2 code lands.

---

## 5. One Decision the User MUST Make Before More Code Lands

**Are NES RAM macro shims the permanent state contract for owned C modules, or must they migrate to typed structs before Phase 12 promotion?**

This is not an architectural preference question. It is a gate definition question. The plan's Phase 12 promotion gate says "typed src/state/ struct ownership." Every existing `src/state/*.h` file is pure `RAM()`/`OBJ()` macros. If shims are the contract, the Phase 12 gate must be rewritten to say "named macro shim ownership." If typed structs are required, a migration plan must exist before Phase 2. No agent can resolve this — only the user can declare which contract is correct.

---

## 6. New Evidence from File Reads (if any)

**`src/state/collision_state.h` line 6-11:** This file is empty except for a comment: "No raw cells required at Plan W time. This header exists so future drains have a named home for collision-owned cells." This means the collision subsystem state header is a placeholder stub with zero macro definitions — confirming that the collision grid derivation in Task 5.2 has no existing state contract to build against. This is additive evidence for my Round 1 Risk 1 (Task 5.2 collision-from-renderer is wrong) and makes the collision state gap more acute than my original read suggested.

**`src/abi/platform_abi.h` line 25-32:** The `RAM()` macro is `nes_ram[(off)]` where `nes_ram` is an A4-register pointer (`register volatile unsigned char *nes_ram asm("a4")`). This means every state header field is a single-byte NES RAM access at a fixed 6502 offset. There are no struct field names, no type information, no width information beyond `unsigned char`. Gemini's "clean room trap" concern about drift is real, but the mechanism is macro aliasing collisions, not visual-reference implementation — several enemy state macros share the same offset under different names (e.g., `ENEMY_FLYER_SPEED_FRAC` and `ENEMY_PUSH_TIMER` both alias `OBJ(0x0412, slot)` per `enemy_state.h` lines 17 and 21). This alias collision is a latent bug that will surface in Phase 7 parallel enemy dispatch when two family agents read different semantic meanings from the same NES RAM byte. This was not called out by any other advisor.
