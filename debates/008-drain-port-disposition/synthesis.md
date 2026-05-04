# Debate 008 — Final Synthesis

**Question:** What do we do with all the drain ports done past several days under the invented "phase 4n" label?

**Mode:** Cross-critique, single round, three substantive voices (Sonnet, Gemini, Opus). Codex round-1 output was transcript noise — re-prompt deferred; not blocking decision.

---

## Summary of perspectives

### 🟠 Sonnet — Pragmatic implementer
Position: **Option B+D hybrid, with a hard precondition**.
Critical finding (no other advisor saw this): 35 of today's 70 functions have **zero** `z07_` wrapper entries in `src/gen/z_07.c`. They compile and link but are unreachable. Flipping `NATIVE_ROOM` ON does nothing for the new batch. Concrete substrate map: `room_set_door_flag`, `room_trigger_open_door`, `room_touch_door_bombable`, `room_check_secret_trigger_*` (6 variants) are precisely the call sites Task 4.2 (Bombable Walls) needs. Effort estimate: 10-12h / 2 days.

### 🟡 Gemini — Strategist
Position: **Option B (Keep + Relabel) with "Substrate Quarantine"**.
Frames the failure as "hallucinated momentum" — agents prioritize mechanism (draining) over mission (phase). Proposes "Phase-Lock Protocol": every session reads `.active_scope` + relevant Phase block first. Warns that `Drain MATCH` accuracy is necessary but insufficient; code must be timely + contextually valid. Challenges Sonnet's "ship Task 4.2 fast" as feature-first thinking that risks rework when the real persistence layer (Task 4.0 SRAM map, Task 4.1 World State) lands.

### 🐙 Opus — Moderator
Position: **B+D hybrid, gated, with 4 specific deltas to Sonnet's plan**.
- Disagrees with Gemini's "quarantine is benign" framing — un-called natives rot when oracle drains receive bugfixes.
- Disagrees with Sonnet's effort estimate — secret-trigger jump table dispatch is non-mechanical; realistic is 14-18h / 3 days.
- Rejects Option C entirely — flipping NATIVE_ROOM globally is Phase 12 work, not Phase 4 work. Conflating them is the same drift that produced "phase 4n".
- Adds systemic fix: precommit gate `tools/gates/check_phase_label.py` rejects commit subjects without master-plan task ID.
- Refuses to rewrite the 5 "phase 4n" commit messages — git history is evidence of the failure mode the new gate prevents.

---

## Areas of agreement (3-of-3)

1. **Option A (revert) is wrong.** 70 drain-MATCH NES-accurate functions are real assets; throwing them away is sunk-cost-fallacy-in-reverse.
2. **Option C (flip NATIVE_ROOM globally now) is wrong.** Either premature (Sonnet/Opus) or out of scope (Opus/Gemini).
3. **Option B alone is insufficient.** Keeping code without using it incurs rot.
4. **Master-plan-first session contract needs systemic enforcement**, not just feedback memory.

## Areas of disagreement

| Question | Sonnet | Gemini | Opus |
|---|---|---|---|
| Are 35 unwired functions a problem? | Yes — biggest hidden risk | Implicit no (treats as quarantine) | Yes — concrete rot vector |
| Effort to ship Task 4.2 from substrate? | 10-12h | Wrong question — Task 4.0/4.1 must land first | 14-18h |
| Should "phase 4n" commits be relabeled? | Implicit yes | Yes (Substrate Quarantine relabel) | No — keep history honest |
| Order of next moves? | Wrappers → Task 4.2 → Gate close | Task 4.0 SRAM first → THEN consume substrate | Drain findings → wrappers → Task 4.2 → precommit gate |

The Gemini-vs-Sonnet/Opus disagreement is the substantive one: **does Task 4.2 require Task 4.0 (SRAM map) to land first?** Sonnet says no — `room_mark_room_visited` already wires through `z07_mark_room_visited` and SRAM persistence works today. Gemini says yes — without a typed `save_state.h` struct, Task 4.2's "Persist reveal flag" item will be rewritten when Task 4.0 lands. Opus sides with Sonnet on technical grounds: SRAM byte 0x6BAF / 0x6BB0 ROOM_FLAGS_PTR is already canonical and used by 17 wired natives; adding bombable-wall reveal flag at bit 5 of the existing flag byte is additive, not breaking.

---

## Recommended path forward (PrimeDirective resolution)

**Disposition:** Option B+D hybrid, ordered as follows:

1. **No revert. No relabel of past commits.** Git history stays as-is — evidence of the drift mode the new gate prevents.

2. **Tomorrow's first commit (substrate audit + Gate 1):**
   - Write `tools/audit/drain_findings/phase_4_task_4.2.md` with task header (NES source / Drained C / Coverage / Stance) for the 6 substrate functions Task 4.2 will call.
   - Add `tools/gates/check_phase_label.py` to `build.bat` precommit chain.
   - Update master plan `## Phase 4 - Task 4.2: Bombable Walls` checklist with substrate citation pointing at the new drain_findings file.

3. **Second commit batch (z07 wrappers):** Add minimum 5 `z07_` wrappers for the door-flag/secret-trigger/touch-door cluster the bombable wall path needs. Title.md sha must remain 56f1e2f7681562fc (gates default OFF preserves byte-identical).

4. **Third commit batch (Task 4.2 feature):** Bomb collision detection + bombable wall asset extraction + reveal sound routing. Use today's substrate as the call substrate. ~3 days work.

5. **Defer NATIVE_ROOM global flip to Phase 12.** This is documented promotion gate work, not bombable-wall work.

6. **Future sessions:** First action = read master plan + `.active_scope`. Backstopped by `feedback_follow_master_plan` memory + new precommit gate.

---

## Next steps (concrete)

| Step | Owner | Estimate | Output |
|---|---|---|---|
| 1. Write Task 4.2 drain_findings + master-plan task header | Next session | 1h | `tools/audit/drain_findings/phase_4_task_4.2.md` |
| 2. Add precommit gate | Next session | 1h | `tools/gates/check_phase_label.py` |
| 3. z07 wrappers for door/secret/touch cluster | Next session | 2-3h | `src/gen/z_07.c` +5 wrappers |
| 4. Bomb-tile metadata extractor | Next session | 3-4h | `tools/builder/extract_bombable_walls.py` |
| 5. Bomb collision → reveal flow | Next session | 4-5h | RoomRom + native room_dispatch wired |
| 6. Gate 2 + Gate 3 + commit `phase 4 task 4.2: bombable walls` | Next session | 2h | screenshot + RAM trace + commit |

**Total Task 4.2 closure: ~14-16 hours / 3 working days.** Today's 70 substrate functions save approximately 8 hours of state-mutation infrastructure that would otherwise have been written from scratch.

---

## Honest answer to user's "have we been wasting time"

**No, but yes-and.** The code is real and reusable. The labeling failure is real and costly — it cost a session of token spend on substrate that should have been one of three commits in a larger Task 4.2 sequence. Going forward, the precommit gate + memory rule + master-plan-first contract make this exact failure mode hard to repeat.
