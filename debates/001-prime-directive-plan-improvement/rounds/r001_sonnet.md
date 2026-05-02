# Sonnet Round 1 Analysis

## 1. Top 3 Highest-Impact Gaps

**Gap 1: Phase 6/12 — `src/state/` headers are macro shims, not typed structs**

The plan's promotion gate (Phase 12) requires "typed `src/state/` struct" ownership before a RoomRom module can move to `src/game/`. But reading the actual files shows this contract is already broken:

- `src/state/link_state.h` (line 9–13): every field is `#define LINK_MOVING_DIR RAM(NES_LINK_MOVING_DIR)` — raw NES address macros, not C struct fields.
- `src/state/save_state.h` (line 8): `SAVE_BYTE(off)` is a raw NES SRAM offset accessor.

Phase 12 promotion will deadlock the moment an implementer tries to satisfy `"typed src/state/ struct"` and discovers that the entire state layer is NES RAM macro-land. This must be called out and resolved before Phase 3 or every task that calls `src/state/` headers is building on sand. Neither the spec nor the master plan mentions that the existing state headers are address-indexed macros rather than typed structs.

**Gap 2: Phase 3/4/5 — No extraction stub gating, so phases can start before builder data exists**

Task 1.5 says "for missing extractors, create stub commands that fail with an explicit named missing extractor error." But Phase 3 through Phase 5 reach for extracted data (`caves.json`, UW door metadata, overworld secret tables) without requiring Phase 1 to be fully green first. Phase 1 Task 1.10 closes with a commit, but the plan's dependency graph in the preamble does not hard-gate Phase 3 on builder phase completion. An agent implementing caves in Phase 3 will silently fall back to checked-in generated assets (which Task 1.6 says will produce a warning, not a hard failure). The legal builder benefit is real but the gate is too soft to enforce it during development.

**Gap 3: Phase 7/8 — No enemy RNG seed injection contract defined before parallel dispatch**

Task 7.1 says "define RNG interface" but the probe contract in the plan says "deterministic probes expose RNG seed injection or record the exact seeded state before first gameplay frame." There is no named harness, no API contract, and no shared enum for seeds before five parallel enemy-family agents fan out. When the walker agent and the flyer agent both implement "deterministic seed harness" independently, they will produce incompatible seeding — and you will not discover this until Task 7.7 tries to do the full room matrix. The RNG seed injection interface must exist as a committed header before Task 7.2 begins.

---

## 2. Top 3 Risks That Block Shipping or Break NES Parity

**Risk 1: Phase 5/6 — Dungeon collision extracted from rendered tile data breaks on room variants**

Task 5.2 says "expose UW collision grid from renderer." The NES Zelda collision grid is not derived from the rendered tilemap — it is derived from the room attribute byte and metatile definition tables. Deriving collision from rendered tiles is common but wrong: palette attributes and rendering attributes share bits in the NES PPU, and several dungeon rooms have tiles that look passable but are solid, or vice versa (push-block rooms, water tiles, and the black-border tiles all have special-case attribute handling). If an agent implements Task 5.2 by pixel- or tile-reading the Genesis plane and classifying walkability from rendered tile index, it will produce a collision grid that diverges from NES behavior on at least eight known room types. Observable symptom: Link walks through walls or clips solid blocks in specific dungeon rooms. Recovery: full audit and rewrite against NES attribute tables — costly after all combat and enemy code has been built on top of the wrong collision model.

**Risk 2: Phase 12 integration — Worktree hand-off has no merge protocol, parallel probes may not cross-verify**

Phase 12 Task 12.2 says "move shared modules one family at a time" and "build RoomRom after each family move." But the RoomRom worktree is `FINAL TRY-roomrom-s1` (branch `roomrom-s1`) and the main worktree is `main`. The plan says `src/game/` modules live in main. There is no stated merge/cherry-pick protocol for how RoomRom-authored modules cross the worktree boundary into `main/src/game/` while RoomRom continues building against them. If an agent promotes a module by copying files from roomrom-s1 into main without a corresponding patch to roomrom-s1 to include the shared header from `src/game/`, the worktree immediately diverges. This is not a hypothetical — the worktree rule is already the hardest memory rule in the project (`feedback_check_worktree_first`). One wrong promotion sequence and the RoomRom build is broken in roomrom-s1 while main has the "promoted" module.

**Risk 3: Phase 10 — Audio extraction legal compliance is undefined for NES song data**

Task 10.2 says "ensure title music data comes from legal extraction or authored transformation." The NES Zelda music data (square wave sequences, DMC samples, envelope/tempo tables) is copyrighted. "Legal extraction" is not legally defined in the spec or the plan. The builder model works for CHR/room/palette data because those are displayed as-is — the user extracts their own copy. But Genesis music from NES APU data requires transformation. Is a 1:1 binary extraction of NSF/sequence tables legal? Is it a derived work? Is it only legal if transformed through a sufficiently transformative authoring pass? The spec says "authored transformation" is an acceptable path but never defines what counts. If this is left ambiguous until Phase 10, the release could be blocked at Phase 17 Task 17.1 when the package checker discovers NES-derived audio binary blobs in the release package that are functionally identical to the source data.

---

## 3. Five Concrete Additions/Changes

**Change 1 — Phase 2, add Task 2.0 before Task 2.1:**

```
### Task 2.0: Define Shared State Contract Before Any Phase 2 Work

- [ ] Audit every file under src/state/*.h.
- [ ] Classify each as: (a) NES-address macro shim, (b) typed C struct, (c) hybrid.
- [ ] For every shim-only header, create a migration plan to a typed struct before Phase 6
      or document that the macro shim IS the stable state contract.
- [ ] Decision must be committed to docs/audit/state_contract.md before Task 2.1 begins.
- [ ] Any new state fields added in Phase 2 must follow whichever contract is chosen.
```

This prevents Phase 12 promotion gate from requiring typed structs that have never existed in this codebase.

**Change 2 — Phase 1, add to Task 1.10:**

```
- [ ] After Task 1.10 commits, add a build-gate flag REQUIRE_GENERATED_ASSETS=1 to build.bat.
- [ ] When REQUIRE_GENERATED_ASSETS=1, the build fails (not warns) if any file under
      data/ or src/data/ is used without a corresponding entry in the generated manifest.
- [ ] Phases 3-5 task preambles must state: "Do not begin if builder Phase 1 is not green
      and REQUIRE_GENERATED_ASSETS=1 is not tested."
```

This enforces the builder dependency in practice, not just in prose.

**Change 3 — Phase 7, add to Task 7.1:**

```
- [ ] Define and commit RoomRom/src/roomrom_rng.h before Task 7.2 begins.
- [ ] Header must export: rng_seed(u16 seed), rng_next(void), and rng_peek(void).
- [ ] Header must expose a PROBE_RNG_SEED macro the Lua probe can set via memory write
      before the first gameplay frame.
- [ ] All five parallel family agents must include this header, not implement their own.
- [ ] No family agent may commit with a local seed variable not backed by roomrom_rng.h.
```

**Change 4 — Phase 5, replace Task 5.2 first bullet:**

Replace:
`- [ ] Expose UW collision grid from renderer.`

With:
```
- [ ] Extract UW collision grid from NES room attribute byte + metatile definition tables,
      NOT from rendered tile indices. Source: reference/aldonunez/ attribute decoding + 
      NES ROM metatile tables at PRG bank offsets documented in the NES disassembly.
- [ ] Generate collision_grid[room_id][row][col] as a pre-computed table from the NES data.
- [ ] Add a verifier comparing generated grids against NES BizHawk RAM probe at $6100+ range.
```

**Change 5 — Phase 10, add to Task 10.1:**

```
- [ ] Before any audio extraction begins, create docs/audit/audio_legal_policy.md.
- [ ] Define: which NES audio data elements are "extracted as-is" (permissible) vs.
      "must be transformed" (requires authored composition or sufficiently transformative change).
- [ ] Decision by PrimeDirective default: NES sequence/pattern tables extracted as-is are
      treated the same as CHR — user-supplied ROM, user-extracted data, legally equivalent
      to CHR extraction. Document this ruling and the rationale.
- [ ] If the ruling is challenged, fallback path is to author Genesis-native music tracks
      separately as the only legally unambiguous path.
- [ ] Package check must explicitly pass on audio extracted data or author-composed data
      and fail on bundled NES binary audio blobs that come from the repo, not the user ROM.
```

---

## 4. Plan Part That Maps Poorly to Codex+Claude Strengths

**Phase 14 (Full Quest Completion) with "input/movie segments or manual checklist per dungeon"**

Task 14.1 says "create input/movie segments or manual checklist per dungeon." This is the worst task shape for coding CLIs. LLMs cannot play games, cannot generate valid BizHawk input movies without a pre-seeded known state, and a "manual checklist" requires a human to physically play through 9 dungeons. This is a 50-100 hour manual testing task hidden inside a plan that otherwise says "I build, I launch BizHawk, I screenshot."

Better task shape: replace movie-segment aspirations with a dungeon completion state injection harness. For each dungeon, create a BizHawk save state at dungeon entry with correct inventory and flag preconditions. Probes load the save state, inject inputs for the minimal critical-path sequence (enter boss room, deliver required hit, capture room-clear flag), and verify the state diff. This is a task Codex and Claude can execute: write a deterministic state-injection harness per dungeon, verify boss-kill flag, verify reward state, verify dungeon-clear bit. That replaces "complete the dungeon manually" with "prove the dungeon's critical path mechanically."

Specifically: Phase 14 Task 14.1, change "input/movie segments or manual checklist per dungeon" to "per-dungeon save-state harness with critical-path state injection probes." Add Task 14.0 to create a `tools/dungeon_harness/` directory with one save state and one Lua probe script per dungeon.

---

## 5. Final Stance

**YELLOW** — The plan's phase structure and probe contract are correct, but it will stall at Phase 12 promotion because the `src/state/` layer is macro shims (not typed structs as the gate requires) and Phase 14's manual-play assumption is unexecutable for coding CLIs without the save-state harness fix above.

---

## 6. Builder Gotchas You Will Hit at 2am

- `src/state/link_state.h` line 9: every "typed struct field" is `RAM(NES_LINK_MOVING_DIR)` — a macro over a raw NES address. Phase 12's promotion gate will fail the first time an agent reads it and tries to satisfy "typed struct ownership." Decide the contract before Phase 2, not at Phase 12.

- `docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md` Task 0.2, line 121-124: the compatibility alias copies `Title.md` to `whatif.md` after every build. The task says "delete alias in Phase 16.5." But Phase 16, Task 16.5 (line 1721) only says "Delete `whatif.md` ... after every active probe and launcher uses `Title.*` or `Final.*`." There is no task that audits probe scripts for `whatif` references before pulling the alias. An agent that deletes the alias before all probe scripts are updated will break every probe silently. Add a required `rg "whatif" tools/` gate to Task 16.5 before the alias deletion.

- `docs/superpowers/specs/2026-05-02-title-roomrom-full-port-roadmap-design.md` line 489: "one BizHawk launch per probe report per `feedback_one_big_probe`." The spec's verification strategy defines this as a hard rule but the Phase 7 parallel family dispatch (5 agents, each with their own probe) means 5 separate BizHawk launches in sequence. This is fine but the parent session integrating their reports must do a single full-room smoke, not 5 independent launches that each cover only their own family. If the integration re-launch is skipped, you will miss cross-family interactions (e.g., walker+projectile cross-collision) that only appear when both families are loaded in the same room.

- Task 9.2 line 1154: "Use locked SRAM range `0x800-0x81F` for OptionsState unless existing implementation has moved under a documented migration." The SRAM layout has never been formally audited and committed — the parenthetical "unless" quietly allows an undocumented migration to silently break save compatibility. Before Phase 9, the SRAM map needs a committed table at `docs/audit/sram_map.md` so all three targets (Title.md, RoomRom.md, Final.md) agree on byte layout. Without this, Phase 9's "options migrate by version" probe may pass on one target and silently corrupt saves on another.
