# Debate 008 R001 — SONNET (Pragmatic Implementer)

**Position: Option D (Repurpose into Task 4.2) with B (Keep+Relabel) as its first commit.**

---

## 1. Which disposition wins, and why from the builder's seat

Option A (revert) is a non-starter. You don't throw away 70 drain-MATCH functions with NES asm citations just because the commit message said "phase 4n" instead of "phase 4.2". The code is correct. The label is wrong. Fix the label.

Option C (flip NATIVE_ROOM ON) is premature and high-risk right now. NATIVE_ROOM in `src/gen/z_07.c` already wires 17 functions through the gate (lines 306–444). But the 5 newest batches — door flags, secret triggers, touch-door variants, mode-7 scroll, mode-11 death sub2/sub_c, mode-12 end-level — have **zero z07_ wrappers**. `room_set_door_flag`, `room_check_secret_trigger_ringleader`, `room_touch_door_bombable`, `room_update_mode11_death_sub_c` are declared in `src/game/room/room_dispatch.h` lines 246–288 but are **not wired in z_07.c at all**. Flipping NATIVE_ROOM ON would silently keep those 35+ new functions dead while the old oracle paths continue to run. The parity risk is not "regen baselines" — it's "nothing changes, you wasted the flip."

Option D is the correct move: the ~35 door/trigger/touch/death functions that landed in the last 3 of the 5 commits are **exactly the substrate Task 4.2 (Bombable Walls) needs**. `room_set_door_flag`, `room_reset_door_flag`, `room_trigger_open_door`, `room_touch_door_bombable`, and `room_check_secret_trigger_*` (6 variants) are the precise call sites that a bombable-wall detonation sequence exercises. They already have NES asm citations in their `room_dispatch.c` comments. The execution path is:
1. Bomb entity collision hits wall tile → `room_check_secret_trigger_*` dispatch.
2. Reveal: clear tile, set flag → `room_set_door_flag` / `room_trigger_open_door`.
3. Persist: write SRAM flag bit → `room_mark_room_visited` family (already wired via `z07_mark_room_visited`).

That is three of the seven Task 4.2 checklist items (`Add bomb explosion collision`, `Reveal cave/stairs`, `Persist reveal flag`) with substrate already in place.

---

## 2. Hidden gotchas

**NATIVE_ROOM flip rot:** 17 functions are wired in z_07.c but 35+ new ones are not. If someone flips NATIVE_ROOM without first adding z07_ wrappers for the new batch, the new native code compiles and links but is **never called**. That is the worst outcome: you think you're running native but the oracle path still owns execution. The gate pattern in z_07.c is the integration seam — the drain ports do not self-wire.

**Unused function rot:** Leave these 70 functions dark for 2-4 weeks and you will get: (a) compiler dead-code warnings silenced by habit, (b) the oracle drains getting "light maintenance" patches that diverge from the native implementations with nobody noticing, and (c) the next developer reading room_dispatch.c and having no idea which functions are actually live. The comments say "drain MATCH" but without a caller, nobody verifies that at runtime. Drain MATCH is a static claim. It rots the moment room_runtime.c receives a bugfix commit that isn't mirrored.

**The 4n label problem is real but it is a documentation debt, not a code defect.** The `tools/audit/drain_coverage.py` `Stance:` header system only validates what's in master plan task headers. These commits have no task headers at all — they are orphaned from the plan. That is the actual CI debt. It means `drain_coverage.json` cannot account for these functions, and the per-function diff gate (Gate 1) has no `drain_findings/` markdown entry for any of them.

---

## 3. Concrete effort estimate: Phase 4 Task 4.2 from today's substrate

- **Day 1 (2-3h):** Write the `drain_findings/phase4_task4.2.md` Gate 1 entries for the 6 functions Task 4.2 actually calls. Verify `room_touch_door_bombable` at `room_dispatch.c` against NES `TouchDoor_Bombable` in `reference/aldonunez/`. Add the 5 missing z07_ wrappers in `z_07.c` (door_flag, trigger_open_door, touch_door_bombable, check_secret_trigger_block_door, reset_door_flag). Write the task header in the master plan.
- **Day 2 (3-4h):** Bomb entity collision detection — this is **not in today's drain** and is the actual new work. Tile-metadata extraction for bombable walls from the NES ROM (`tools/builder/`). Hook into existing enemy collision path.
- **Day 3 (2h):** SRAM persist wire-up, reveal sound routing via `room_go_to_next_mode_play_level_song`, BizHawk probe to verify the detonation + reveal + SRAM flag sequence.
- **Gate close (2h):** Gate 2 RAM trace, Gate 3 screenshot oracle, commit.

**Total: ~10-12 hours of focused work.** That is 2 working days. The substrate already covers the state mutation side. The new work is the physics/collision trigger and asset extraction, which would have been needed regardless of whether the drain ports existed.

Without today's substrate, Task 4.2 would have been 3 days minimum because the state mutation layer would need to be designed from scratch.

---

## 4. What the strategic advisors miss

The context.md table maps today's functions to Phase 4 tasks. That mapping is correct but it undersells the **integration gap**. Gemini's framing ("substrate is real, drain MATCH") treats drain MATCH as sufficient for deployment. It is not. A function in `room_dispatch.c` with a correct NES comment is not reachable until it has a z07_ wrapper in `z_07.c` **and** a calling site in the ASM trampoline layer (`src/c_shims.asm` or equivalent). Codex's analysis will likely verify the drain MATCH claim by reading the oracle sources, which is valid but still static. Neither sees the runtime gap: 35 new functions compile but are unreachable today.

The PrimeDirective answer is not "which option sounds cleanest" — it is "which option ships working, verified code fastest." That is Option D, starting tomorrow with the Gate 1 drain_findings file as the first artifact, not the last.

**Clear position: Keep the code (B), immediately relabel commits in the master plan's task headers (B), and start Task 4.2 using today's substrate as the implementation foundation (D). Do not flip NATIVE_ROOM globally until z07_ wrappers exist for all 70 functions — that is a separate integration task estimated at 4-6 hours.**
