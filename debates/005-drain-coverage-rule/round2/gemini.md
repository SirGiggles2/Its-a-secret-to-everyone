# GEMINI ADVISOR — Round 2 Cross-Critique

## 1. AUDIT STRUCTURE: OPUS-JSON + SONNET-VIEW
**Verdict: Opus wins base, Sonnet wins view.**
Codex/Gemini single manifest too big. Sonnet subsystems good for brain. Opus JSON good for machine.
**Standard**: `tools/audit/drain_coverage.json` is source. Scripts generate `docs/audit/drain/<subsystem>.md`. 
*Reason*: Machine check stops human lazy. Subsystem files keep context small for LLM.

## 2. VERIFICATION DEPTH: OPUS 3-GATE
**Verdict: Layered or die.**
Codex/Gemini too loose. Sonnet misses integration. 
**Standard**: 
- **Gate 1**: Function diff (Task). 
- **Gate 2**: RAM trace (Phase). 
- **Gate 3**: Scenario oracle (Milestone).
*Reason*: catch drift at birth, behavior at death.

## 3. TASK HEADER: OPUS 4-LINE
**Verdict: 4-line Mandatory.**
1-line too easy to lie. 
**Standard**:
```markdown
- NES source: <file>:<symbol>
- Drained C: <path>:<symbol>
- Coverage: FULL|PARTIAL|STALE|NONE
- Stance: ADOPT|EXTEND|REPLACE|GREENFIELD
```
*Reason*: Forces grep. No grep, no task.

## 4. STANCE ENUM: ADOPT OPUS
**Verdict: Use the 4 states.**
Binary too simple. 
- **ADOPT**: Logic good, wire it.
- **EXTEND**: Logic good, swap shims (VDP/APU).
- **REPLACE**: Logic bad, evidence needed.
- **GREENFIELD**: Nothing exists.
*Reason*: "EXTEND" is 90% of Phase 3. Drained logic stays, VDP code changes.

---

### CONVERGENCE POINT: "THE DRAIN IS PRIME"
1. **Rule**: Drain = Primary Resource. NES = Secondary Authority.
2. **Tool**: `tools/audit/drain_coverage.py` scans `*_runtime.c`, checks headers, fails CI on drift.
3. **Memory**: `feedback_drain_primary_nes_secondary`.
4. **CLAUDE.md**: Hard rule. Grep first or fail.
5. **Phase 3**: 3.1 is data. 3.2-3.9 are ADOPT/EXTEND. 3.10 is Gates.

---

### FINAL STANCE: GREEN
Phase 3 unblocked. Rule stops duplication. Saves weeks.
**Caveman summary**: 
Drain is map. NES is ground. 
If map says cave, look at map. 
If ground says map lie, fix map. 
Do not build new cave if map already has cave.

**Action**: Merge Opus headers into Master Plan. Run tool. Start 3.1.
