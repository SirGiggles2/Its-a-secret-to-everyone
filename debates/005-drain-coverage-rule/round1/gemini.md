**Debate 005: The Drain-First Mandate**

**Purist:** "Transpiler is lie! C code is dirty water! Only 6502 is pure truth!"
**Pragmatist:** "6502 is dead rocks! Drained C is alive, builds, links. Use it or we fail date!"
**Architect:** "Mapping is key. `z_01.asm` is the soul, `cave_runtime.c` is the body. We must unite them."
**Tooler:** "Python script go *brrr*. RAM state parity is the only god I serve."

---

### The 10 Commandments of Drain-First

1. **Phase Task Header:**
   Standard: `[DRAIN: {C_PATH}] | [SPEC: {ASM_PATH}]`
   Example: `[DRAIN: src/game/cave/cave_runtime.c] | [SPEC: src/zelda_translated/Bank4/z_01.asm]`

2. **Task 3.4 Rewrite:**
   "Hook `cavert_draw_cave_person`. Bind SGDK tile rendering to its internal state. Verification: Parity check logic against `z_01.asm:0x8A12`."

3. **Audit Deliverable:**
   `docs/audit/drain_coverage.md` — A living manifest mapping every `src/game/` C file to its NES Bank/Label origin.

4. **Verification Step:**
   **Logic Parity Oracle:** Run C logic vs. NES 6502 trace. If `cave_state.room_items` differs from NES RAM after `cavert_try_take_item`, NES wins. Fix C.

5. **Tool:** `tools/audit/drain_coverage.py`
   Scans `src/game/` for `cavert_`, `uw_`, `hud_` prefixes. Matches against `src/zelda_translated/` symbols. Outputs % coverage of 'Drained' vs 'Required'.

6. **Master Plan Rule:**
   "ZERO GREENFIELD. If subsystem exists in `src/game/`, you MUST use it. Drain is Primary. Disasm is Secondary Verification. New code is for Frontend/Glue only."

7. **Memory Sketch:**
   `feedback_source_first_then_nes`: Always audit `src/game/` before implementation. Drained C is the source of truth for logic; NES Disasm is the source of truth for correctness.

8. **CLAUDE.md Addition:**
   `- **DRAIN-FIRST:** Prioritize existing \`src/game/\` logic. Hook SGDK to C-drained state. Greenfield is only for missing glue/VDP.`

9. **Phase 3 Task List (Min-Rewrite):**
   - 3.1: Map `cave_runtime.c` + `uw_person_runtime.c` symbols.
   - 3.4: Hook `cavert_draw_cave_person`.
   - 3.7: Bind `cavert_update_talk_shop_or_door_charge`.
   - 3.8: Bind `cavert_update_hint_or_money_game`.
   - 3.10: Final parity audit vs NES disassembly.

10. **GREEN/YELLOW/RED:**
    **RED.** Phase 3 is currently Hallucination-Mode. It ignores 400 lines of shipping logic. STOP. Refit Phase 3 to the Drain or die to duplication.

---

**GEMINI Advisor Verdict:** Follow the Drain. It is the Prime Directive. Max efficiency, max accuracy. Use the C as the engine; use the ASM as the dyno.
et Memory Citation:** `feedback_source_first_then_nes` — Look at our code first. Then look at Nintendo's code. If our code looks like a drunk transpiler wrote it, trust the Nintendo code.
