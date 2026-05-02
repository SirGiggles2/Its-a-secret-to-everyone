# Claude (Opus) Round 2 Cross-Critique

## 1. Points from other advisors I AGREE with

**Sonnet's `src/state/link_state.h` finding is the single most important contribution of this debate.** Every "field" is `RAM(NES_LINK_MOVING_DIR)` — a macro indexing raw NES RAM, not a typed struct. The Phase 12 promotion gate I helped harden requires "typed `src/state/` struct ownership." That gate fails the moment any agent reads the actual header. My Round 1 listed implicit state migration as gap G2; Sonnet proved it is worse than implicit — the contract listed in the gate **does not exist in code**. This kills my Phase 1.5 capture harness too if state diff is supposed to validate captures: macro RAM reads work fine but cross-target promotion stalls.

**Codex's Task 1.11 strict generated-only gate is correct and complementary to my Phase 1.5 capture harness.** Reproducibility is unprovable without both: harness produces the NES reference, strict gate proves no checked-in derived data slipped past. Together they make the legal builder argument enforceable.

**Gemini's "1:1 logic port from 6502 ASM" call** is correct on parity grounds and matches the project memory rule `feedback_full_native_rewrite`. My capture harness validates output but does not constrain implementation. Logic port + capture harness = belt and suspenders.

## 2. Points I DISAGREE with

**Gemini's claim that the two-ROM split is "dangerous bifurcation"** is wrong. The split is the only reason RoomRom can iterate without a 30-second title boot. The merge contract is the risk, not the split. Codex/Sonnet/Opus all accepted the split correctly. Gemini's underlying concern (memory schism) is real but the fix is shared `include/memory_map.h`, not collapsing the targets.

**Gemini's Phase 0.5 6502-to-C behavior map** is overcost for the slice the project already has. `reference/aldonunez/*.asm` plus the existing transpiled NES code already provides this mapping. A new `docs/logic/` deliverable triples the doc burden without adding new ground truth. Better: enforce a citation rule — every owned C function must cite the reference file + offset it derives from, in a comment header, no separate doc.

**Codex's "push Phase 13 4-player after Phase 17"** is too aggressive. The architectural decision (PlayerState[4], input adapter shape, sprite budget) must land in Phase 6 because Link state shape is set there. Implementation can defer to post-17, but the `PlayerState` shape cannot be retrofitted later without rewriting Link. Gemini was right on the architectural part; Codex on the implementation timing.

## 3. Single highest-impact change

**Add Phase 1.5 (NES Reference Capture Harness) AND Phase 2.0 (State Contract Decision).** Sonnet's gap is fatal until the state contract is decided in writing — typed struct, macro shim, or hybrid. Once decided, Phase 12 promotion gate either gets satisfiable (typed) or rewritten (shim). My capture harness then has a target to diff against. Without both, every later phase compounds the wrong assumption.

## 4. Updated stance

**YELLOW.** No advisor moved to GREEN; no advisor went RED; convergence on Phase 12 + parity + Phase 14 says the plan is salvageable but not currently shippable. The four concrete additions (Phase 1.5 capture, Phase 2.0 state contract, Task 1.11 strict gate, Task 14 save-state harness) together flip to GREEN.

## 5. One decision the user MUST make

**State contract: typed C struct migration before Phase 6, OR explicit macro-shim contract that the Phase 12 promotion gate is rewritten to accept.**

This is binary, blocking, and must be decided before any new state field lands. Everything else can be derived from the answer. Recommended default under Prime Directive: **typed struct migration**, because long-term maintenance of macro RAM aliases scales worse than typed struct + thin RAM-mirror layer. But the user owns this call.
