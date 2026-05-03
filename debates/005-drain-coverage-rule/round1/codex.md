1. Task header format:

`Drain coverage: PRIMARY src/game/cave/cave_runtime.c::{cavert_*}; src/game/cave/uw_person_runtime.c::{...}. NES verify: SECONDARY reference/aldonunez/{z_XX.asm labels} + src/zelda_translated/*.asm. Status: GREEN|YELLOW|RED. Rule: drain first, NES wins on mismatch.`

2. Rewrite Task 3.4:

`Task 3.4 Render Cave Interior`
Use existing `cavert_init_cave`, `cavert_draw_cave_person`, `cavert_draw_cave_items` as primary behavior source. Map output to Genesis-native tile/sprite/text systems. Verify against NES disassembly labels for cave load/draw flow. Do not reimplement cave rendering from scratch. Acceptance: scenario oracle passes for item cave, hint cave, shop cave, gambling cave; mismatches documented with NES-wins decision.

3. Audit structure: one canonical `docs/audit/drain_coverage.md`, organized per master-plan phase. Strong no on per-NES-source-file as primary; planners think in phases, not `z_01.asm`. Per-subsystem files rot. Use phase rows with subsystem/function/source/verification/status/gaps.

4. Mechanical check: per-scenario parity oracle, backed by selective RAM-cell/event traces. Per-function diff is fake precision; C and 6502 differ structurally. Full RAM trace is noisy. Best check: known scenario inputs, expected state transitions, key RAM cells, draw/event outputs, then NES disasm used to resolve disputes.

5. `tools/audit/drain_coverage.py`: scan `src/game/**/*.c`, extract functions, prefixes like `cavert_`, comments/labels if present, map to phase keywords, scan `reference/aldonunez/` and `src/zelda_translated/*.asm` for labels/symbols, emit Markdown table plus JSON cache: phase, drained files, functions, probable NES refs, status placeholders, missing verification.

6. Master plan rule:

`Every phase MUST start from drained C coverage as PRIMARY implementation evidence. NES disassembly/translated ASM is SECONDARY verification and final authority. If drained C conflicts with NES behavior, NES wins. Do not create greenfield tasks until audit marks drain coverage RED or missing.`

7. Memory entry sketch:

`Zelda port planning: drain-first. Existing drained C in src/game/** is primary resource for implementation. NES disassembly in reference/aldonunez/ and src/zelda_translated/*.asm is secondary verification/final spec. Follow Sonnet pattern feedback_source_first_then_nes: read C first, verify against NES, NES wins mismatch.`

8. `CLAUDE.md` addition:

`For master-plan work, treat drained C as primary source. Before proposing implementation, audit src/game/** for existing drained runtime. Use NES disassembly only after source-first review, as verification/final authority. Never label work greenfield until drain coverage is checked.`

9. Phase 3 minimum rewrite:

3.1 Audit cave drain coverage, not generate `caves.json` first.  
3.2 Map cave data/constants from drained C to Genesis data needs.  
3.3 Verify cave entry/exit behavior against NES.  
3.4 Render cave interior using `cavert_draw_*`.  
3.5 Wire cave person state/textbox via `cavert_update_person_state_textbox`.  
3.6 Wire transfer/door prices via `cavert_update_transfer_prices`.  
3.7 Implement shop caves from `cavert_update_talk_shop_or_door_charge`.  
3.8 Implement gambling from `cavert_update_hint_or_money_game`.  
3.9 Implement item pickup via `cavert_try_take_item` / room item path.  
3.10 Scenario parity: item, hint, shop, money game, door charge.

10. Status: Phase 3 without this rule = RED. It will duplicate shipped code. Phases 4-9 = YELLOW trending RED until audited. Prime Directive demands max efficiency and NES accuracy; drain-first satisfies both, with `feedback_source_first_then_nes` preventing blind trust.
