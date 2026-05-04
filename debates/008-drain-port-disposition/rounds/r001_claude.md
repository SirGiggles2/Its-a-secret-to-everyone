# Debate 008 R001 — CLAUDE OPUS (Moderator + participant)

**Position: B+D hybrid, with a hard precondition Sonnet identified that Gemini missed.**

---

## 1. The precondition both external advisors underweighted

Sonnet caught what Gemini did not: **35 of today's 70 functions have no `z07_` wrapper in `src/gen/z_07.c`**. The cutover gate `NATIVE_ROOM` only flips the 17 functions wired in lines 306–444. Door-flag mutators (`room_set_door_flag`, `room_reset_door_flag`), secret-trigger predicates (6 variants), touch-door variants (`room_touch_door_bombable`, `room_touch_door_shutter`, `room_touch_door_false`), and the entire mode-7/11/12 sub-mode batch are declared in `room_dispatch.h` lines 246–289 but unreachable through any caller path.

This invalidates Codex's likely "drain MATCH proves correctness" framing and Gemini's "substrate is valid, just out-of-order" framing. Drain MATCH is necessary but not sufficient. Drain MATCH + dispatched call site is sufficient. Today's batch has the first, lacks the second.

## 2. Why Option C is the wrong move regardless

Even if the wrappers existed, flipping `NATIVE_ROOM` for `Title.md` violates two project invariants:
- Title.md byte-identical preservation (sha 56f1e2f7681562fc — currently the only proof of regression-free progression through 50+ commits).
- The Phase Close Gate (master plan lines 56–73) requires probe + screenshot evidence + parity oracle + regression matrix BEFORE promotion. None of that has been run for these 70 functions.

Option C is `Phase 12: Promote RoomRom Core` work, not Phase 4 work. Conflating them is exactly the master-plan-drift mistake that produced "phase 4n" in the first place.

## 3. Where I disagree with Gemini

Gemini's "Substrate Quarantine" frames the unused state as benign. It isn't. Sonnet's rot warning is concrete: oracle drains will receive bugfixes the natives won't see. `tools/audit/drain_coverage.py` does not detect "wrote a native, never called it" — it only detects "missing native for an asm symbol." Today's batch will silently diverge from oracle the next time `room_runtime.c` gets touched. This is a real maintenance liability, not a strategic one.

## 4. Where I disagree with Sonnet's effort estimate

Sonnet's "10-12 hours / 2 days" assumes the 5 missing z07_ wrappers are mechanical. Two of them aren't:
- `room_check_secret_trigger_*` (6 variants) replaces an ASM jump-table dispatch in NES `Z_05.asm` around line 2400. The wrapper has to know which variant to call based on `ROOM_SECRET_DISPATCH_INDEX` cell. That's a 30-minute design decision, not a 5-minute wrapper.
- `room_update_mode2_load` already has a wrapper (z07_update_mode2_load) but the new natives `room_init_mode3_sub2..7` don't — and they're called from a different jump table in the room mode dispatch loop.

Realistic estimate: **14-18 hours, 3 working days for Task 4.2 end-to-end**, with the first 4 hours spent on z07 wrapper integration before any bombable-wall feature work begins.

## 5. The systemic fix Gemini gestured at but didn't operationalize

The reason "phase 4n" happened is that no tooling enforces master-plan-task-ID in commit messages. `tools/audit/active_scope.py` emits a per-phase scope pointer (Rule WT-2) but doesn't validate commit subject lines.

**Concrete proposal:** Add `tools/gates/check_phase_label.py` to `build.bat` precommit chain. Reject commits whose subject does not match `(phase \d+(\.\d+)?|s\d+|substrate|docs):`. This would have hard-failed all 5 "phase 4n" commits at write time.

This is the kind of gate that pays for itself in 30 days. Memory `feedback_follow_master_plan` (saved this session) catches it at session-start; the precommit gate catches it at commit-time. Defense in depth.

## 6. Final position

**B+D hybrid, gated:**
1. Tomorrow's first action: write `tools/audit/drain_findings/phase_4_task_4.2.md` — task header for the 6 substrate functions Task 4.2 will actually call. This is the missing Gate 1 artifact.
2. Add 5 minimum-viable z07_ wrappers for the door-flag / secret-trigger / touch-door cluster (the rest can wait).
3. Begin Task 4.2 implementation calling those wrappers.
4. Add the precommit gate (#5) before any other phase 4 task starts.
5. Defer Option C (NATIVE_ROOM flip globally) to Phase 12 explicitly.

**Do NOT relabel the existing 5 "phase 4n" commits.** Git history is immutable evidence; rewriting it hides the failure mode that the new precommit gate exists to prevent. Future commits cite Task 4.2.
