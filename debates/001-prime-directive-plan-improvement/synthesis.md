# Final Synthesis: Improve plan to ship NES Zelda → Genesis port aligned with Prime Directive

**Date:** 2026-05-02
**Rounds:** 2 (cross-critique)
**Participants:** 🔴 Codex, 🟡 Gemini, 🟠 Sonnet, 🐙 Claude/Opus
**Final stances:** All four YELLOW after both rounds. None went GREEN. None went RED.

---

## Summary of Perspectives

### 🔴 Codex
Frame: rigorous gate engineering. Round 1 named soft builder gate, late bulk promotion, vague enemy/boss probes. Round 2 anchored to "contracts and oracle gate before Phase 3" combining Sonnet's state audit, Opus's capture harness, his own parity oracle schema, and his own strict generated-only build gate. Disagreed with collapsing two-ROM split. Disagreed with replacing Phase 14 with parallel movie agents — preferred Sonnet's save-state harness as base.

### 🟡 Gemini
Frame: ecosystem and architectural risk. Round 1 named memory schism between Title.md/RoomRom, late SRAM, weak VRAM budget, called two-ROM split "dangerous bifurcation." Round 2 dropped the bifurcation insistence after Sonnet showed the split already lives in the repo. Reaffirmed early SRAM, Phase 1.5 capture harness, hard 1.11 gate. Proposed unifying capture + oracle + headers into "Phase 2.5 Universal Parity Manifest" (`docs/parity_manifest.json`).

### 🟠 Sonnet
Frame: pragmatic implementer with file-grounded reads. Round 1 named the dispositive evidence — `src/state/link_state.h`, `enemy_state.h`, `room_state.h`, `save_state.h` are pure `RAM()`/`OBJ()` macro shims, not typed C structs. The Phase 12 promotion gate is structurally broken in the repo today. Round 1 also disqualified Task 5.2 (collision-from-renderer is wrong: NES collision derives from attribute byte + metatile tables) and Phase 14 manual playthrough (unexecutable for CLIs without `tools/dungeon_harness/` save-state injection). Round 2 surfaced new evidence: `enemy_state.h` lines 17/21 have name-aliased macros (`ENEMY_FLYER_SPEED_FRAC` and `ENEMY_PUSH_TIMER` both map to `OBJ(0x0412, slot)`) — latent collision when parallel enemy agents fan out.

### 🐙 Claude/Opus
Frame: moderator + independent voice. Round 1 named no NES golden-master capture pipeline, no regression matrix between phases, FS-song-bleeds risk, CHR-vs-frame-cadence palette risk, missing worktree merge protocol. Round 2 conceded Sonnet's `link_state.h` finding is the single most important contribution, agreed Codex's Task 1.11 is complementary to capture harness, disagreed with Gemini's two-ROM-split-is-dangerous framing, and conceded that Sonnet's `tools/dungeon_harness/` is the proper precondition for "18 movie agents."

---

## Areas of Strong Agreement (3 or 4 advisors)

1. **State contract is broken in code right now.** All four agreed. Sonnet proved it; Gemini and Opus predicted it; Codex confirmed Phase 12 invalid without an early state audit. Phase 12 promotion gate cannot stand without a decision.
2. **Parity verification is too vague to enforce NES accuracy.** All four agreed. Convergent fix: Codex's parity oracle schema (Task 2.8) + Opus's NES reference capture harness (new Phase 1.5) + Codex's per-family parity matrix (Task 7.1).
3. **Builder gate is too soft for the legal distribution requirement.** Codex + Sonnet + Gemini agreed. Convergent fix: Codex's strict no-fallback gate (Task 1.11) with `REQUIRE_GENERATED_ASSETS=1` build flag failing not warning.
4. **Phase 14 manual playthrough is not executable for CLIs.** Sonnet + Opus + Gemini agreed (Codex neutral but supportive). Convergent fix: Sonnet's `tools/dungeon_harness/` save-state injection harness as the base. Opus's parallel movie agents become consumers of the harness, not a replacement for it.
5. **Worktree merge protocol is missing.** Sonnet + Opus + Codex agreed. Convergent fix: Opus's Task 0.6 worktree merge protocol, committed before any Phase 12 promotion attempt.
6. **SRAM map is undocumented and that is a save-corruption vector.** Sonnet + Gemini agreed. Convergent fix: committed `docs/audit/sram_map.md` before Phase 9 (Sonnet) or Phase 3 (Gemini's stronger version).

---

## Areas of Disagreement (after round 2)

1. **Phase 13 4-player timing.**
   - Codex: defer all 4-player work after Phase 17, run only a feasibility spike now.
   - Gemini: must architect VDP/sprite/PlayerState[4] in Phase 6 or rewrite renderer twice.
   - Opus: split — architectural shape in Phase 6, implementation deferred.
   - Sonnet: did not take a strong position.
   - **Resolution:** Opus's split position is the synthesis. Define `PlayerState[4]` shape and sprite budget envelope in Phase 6; defer non-architectural multiplayer implementation post-Phase-17.

2. **Phase 0.5 6502→C behavior map (Gemini's proposal).**
   - Gemini: build it; Phase 0.5 dedicated mapping doc.
   - Opus: project already has `reference/aldonunez/*.asm` and transpiled code; new doc is overcost.
   - Sonnet: existing transpiled code already does the mapping; visual-reference drift is bounded by parity oracle, not by prose docs.
   - Codex: did not adopt.
   - **Resolution:** Reject as a separate phase. Replace with citation rule — every owned C function must comment-cite the reference file/offset it derives from.

3. **Two-ROM split safety (Gemini's round 1 concern).**
   - Gemini round 1: dangerous bifurcation.
   - Round 2: dropped after Sonnet showed split already lives in the repo.
   - **Resolution:** Two-ROM split stands. Risk lives in merge protocol, not in the split itself.

4. **Phase 15a inline opts placement.**
   - Gemini: move into Phase 6 with cycle budgets in close gate.
   - Codex: keep 15a/15b split but make 15b regression-matrix driven; adopt per-subsystem `PROBE_CYCLE_LIMIT` in close gate from Gemini.
   - Opus + Sonnet: accept current split.
   - **Resolution:** Adopt Codex's hybrid — keep 15a inline / 15b post-quest, but add per-subsystem `PROBE_CYCLE_LIMIT` to the phase close gate from Phase 6 onward.

5. **Phase 14 movies-vs-harness primacy.**
   - Opus round 1: 18 parallel canonical movie agents.
   - Sonnet: save-state injection harness first; movies desync without it.
   - Codex + Gemini: side with Sonnet on harness primacy.
   - Opus round 2: conceded harness is the precondition.
   - **Resolution:** Sonnet's `tools/dungeon_harness/` is the base. Movies become consumers later.

---

## Convergent User Decision (THE Block)

**Three of four advisors closed Round 2 with the same blocking question:**

**Are `RAM()` / `OBJ()` macro shims the permanent state contract for owned C modules, or must they migrate to typed C structs before Phase 12 promotion?**

Until this is answered:
- Phase 12 promotion gate ("typed `src/state/` struct ownership") is structurally broken.
- Every state field added in Phases 2–11 builds on whichever answer is wrong.
- Macro alias collisions (Sonnet round 2 evidence at `enemy_state.h:17,21`) cannot be resolved without picking a contract.

**PrimeDirective default recommendation (Opus + Codex + Gemini lean):** Typed C structs with documented NES address shims. Long-term maintenance scales worse with raw `RAM()` macros; type information aids LLM accuracy and review.

**PrimeDirective alternative (Sonnet implementer view):** Macro shims ARE the contract; rewrite Phase 12 gate to say "named macro shim ownership" and add an alias-collision verifier.

**Either answer unlocks the rest.** No advisor said keep ambiguous.

---

## Recommended Path Forward — Ranked Plan Changes

### Tier 1 — BLOCK on these before more code lands

1. **User answers the state contract question.** Typed structs vs named shims. Document at `docs/audit/state_contract.md`.
2. **New Phase 1.5: NES Reference Capture Harness.** `tools/nes_capture/` produces deterministic `build/generated/nes_reference/<rom_hash>/` containing screenshots, PPU/OAM/PALRAM/CIRAM dumps, RAM snapshots, frame-aligned, with seeded RNG. Manifest hashed.
3. **New Task 2.0: State Contract Audit.** Audit every `src/state/*.h`. Classify shim vs typed vs hybrid. Commit migration plan if typed; commit alias-collision verifier if shim. Block Task 2.1 until committed.
4. **New Task 1.11: Strict Generated-Only Build Gate.** `REQUIRE_GENERATED_ASSETS=1` build flag. Fail (not warn) when checked-in derived data is read. Phases 3+ task preambles state "do not begin if Phase 1 not green."
5. **New Task 0.6: Worktree Merge Protocol.** Document command sequence to merge `roomrom-s1` into main pre-promotion. Block Phase 12 until protocol committed.

### Tier 2 — Add early but not strictly blocking

6. **New Task 2.8: Parity Oracle Schema.** Shared NES↔Genesis probe schema (frame, input, RNG seed, room id, Link state, enemy slots, item slots, RAM bytes, CRAM/SAT/plane dumps, screenshot hash). Every later "compare to NES" task references this schema.
7. **Move SRAM/save core from Phase 9 to Phase 3.** Commit `docs/audit/sram_map.md`. NES Zelda is state-driven; cannot wait until Phase 9.
8. **New Task 12.0: Incremental Promotion Gate.** After Phases 3, 4, 5, 6, 7, 8, 9, promote that subsystem's shared module immediately or document why it remains harness-only. No bulk Phase 12.2 promotion.
9. **Replace Task 5.2 first bullet:** "extract UW collision from NES room attribute byte + metatile definition tables, NOT rendered tile indices." Add NES RAM probe verifier.
10. **New Task 7.1 sub-bullet:** Commit `RoomRom/src/roomrom_rng.h` with `rng_seed`/`rng_next`/`rng_peek` + `PROBE_RNG_SEED` macro before any family agent dispatches. All five family agents must include, not reimplement.

### Tier 3 — Adopt during build, not blocking

11. **Phase 14: replace movie/manual checklist with `tools/dungeon_harness/` save-state injection harness.** One save state + one Lua probe per dungeon. Movies become consumers later.
12. **New Task 10.1 sub-bullet:** Create `docs/audit/audio_legal_policy.md`. Decide extracted-as-is vs transformed audio policy by PrimeDirective default before any audio extraction. Package check enforces.
13. **New Task 2.6.5:** Preserve NES frame-cadence palette toggles list (intro item flash, low-health, boss palette, hit-invuln) post-CHR-expansion. Add `intro_item_flash_8frame_cycle` probe.
14. **New Task 9.0 (or 10.0):** Define FS audio routing decision (`gamemode == 0x01`, NOT bitmap) before wiring music events. Add `fs_silent_or_explicit_song` probe.
15. **New Workstream F: Regression Matrix.** `tools/run_regression_matrix.py` runs every archived probe. Required green before any phase-close commit.
16. **Per-subsystem `PROBE_CYCLE_LIMIT` added to phase close gate from Phase 6 onward** (Gemini's idea, Codex's hybrid). 15a inline opts stay; 15b post-quest stays.
17. **Phase 6 architectural sub-bullet:** Define `PlayerState[4]` shape and Genesis sprite-per-line budget envelope at Link state design time. Defer multiplayer implementation post-Phase-17 (Codex's timing).

---

## Final Recommendation

The plan is structurally correct but contains four hidden cracks that would surface at Phase 12, Phase 14, Phase 17, and the first parallel enemy dispatch. The four-way debate found all four cracks, named concrete fixes, and converged on one user decision that unlocks everything else: **state contract policy**.

**Adopt Tier 1 (5 items) before the next code-touching task.** Tier 2 (5 items) layers in during early phases. Tier 3 (7 items) layers in as phases reach them.

**Updated stance with all Tier 1 + Tier 2 changes adopted: GREEN.**
**Without Tier 1: stays YELLOW. Without state contract decision: silent slide toward RED at Phase 12.**

---

## Cost / Quality Notes

- 8 advisor responses across 2 rounds (Codex×2, Gemini×2, Sonnet×2, Opus×2).
- All four scored ≥75 on quality (length, citations, code/file references, engagement).
- Sonnet's grounded file-reads provided the most expensive single insight (state-contract-broken-in-repo).
- Codex's gate engineering provided the most reusable framework (parity oracle + strict gate).
- Gemini's strategic challenge forced the two-ROM split discussion; outcome was reaffirmation, not abandonment.
- Opus's capture harness + worktree protocol filled cross-cutting infrastructure gaps the others did not name.

Total user decision points: 1 (state contract). Total recommended plan changes: 17 (5 blocking, 5 early, 7 adopt-during).
