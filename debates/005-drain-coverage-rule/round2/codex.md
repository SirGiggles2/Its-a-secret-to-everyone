**Round 2 Resolution**

1. **Audit Structure: pick Opus.**  
Canonical source should be `tools/audit/drain_coverage.json`, organized by NES source file/symbol, with generated human views by phase and subsystem. This absorbs the best parts of the other proposals: Codex gets per-phase tables, Sonnet gets subsystem views, Gemini gets a living C-to-NES manifest. But the canonical axis must be NES source because that is the immutable spec.

2. **Verification Depth: pick Opus layered.**  
Use the 3-gate model, with one clarification: Gate 1 is not “prove C equals 6502 instruction-for-instruction.” It is a documented per-function semantic diff: `MATCH`, `DIFF`, or `UNKNOWN`, with evidence. Then Gate 2 checks selective RAM-cell traces before phase exit. Gate 3 runs per-scenario parity oracles before milestone tags. Codex is right that scenarios catch real behavior; Sonnet is right that function review catches drift early. Layering resolves both.

3. **Task Header Format: pick Opus 4-line.**  
Use:

```markdown
- NES source:
- Drained C:
- Coverage:
- Stance:
```

The 1-line formats are readable but too easy to fudge. The 4-line header is machine-checkable, supports CI, and forces the author to state whether they are adopting, extending, replacing, or going greenfield.

4. **Stance Enum: adopt Opus enum for everyone.**  
Use `ADOPT / EXTEND / REPLACE / GREENFIELD`. Do not simplify to `REUSE / NEW`; that loses the most important distinction, which is `EXTEND` versus `REPLACE`. `REPLACE` must require evidence: RAM trace, oracle failure, NES line/symbol mismatch, or documented drain defect. `GREENFIELD` is legal only when coverage is `NONE`.

**Confirmed convergence**

Yes on the master plan per-phase rule: drained C is primary implementation evidence; NES disassembly is secondary verification and final authority.

Yes on `tools/audit/drain_coverage.py`, producing canonical JSON plus generated Markdown views and failing on malformed headers or illegal greenfield claims.

Yes on memory entry: `feedback_drain_primary_nes_secondary`.

Yes on `CLAUDE.md` HARD section.

Yes on Phase 3 rewrite: most tasks become `ADOPT` or `EXTEND`; only Task 3.1 remains true `GREENFIELD` because it is a data pipeline.

**Final stance: GREEN.**

The panel-resolved rule unblocks Phase 3. Without it, Phase 3 remains RED because it duplicates existing cave logic. With the Opus structure, layered verification, and stance enum, the plan becomes enforceable instead of advisory. This is the right governance layer: small enough to implement, strong enough to prevent drift.
