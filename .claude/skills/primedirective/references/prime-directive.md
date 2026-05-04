# Prime Directive — canonical text

## Spec vs implementation

**NES Zelda 1 = behavioral spec.** Behavior, layout, palettes, timing, scroll, sprite priority, RAM offsets, animation cadence — all should match NES Zelda 1 exactly unless explicitly told otherwise.

**Genesis-native = implementation.** Native Sega Genesis code via SGDK. No transpile-patches for visual sequences. No NES emulation in the runtime. The Genesis runs Genesis code; only the *behavior* is NES.

## Decision priority

For every unresolved choice, pick in this order:

1. **Best long-term outcome** — root-cause fix, not symptom mask.
2. **Best coding practice** — owned C as real code, gen/ passive, ASM only for boot/IO/hot loops, named RAM, per-subsystem verification.
3. **Maximal efficiency** — both runtime cycles and engineering throughput.
4. **NES accuracy** — exact match unless user explicitly approves divergence.

## Ground-truth discipline

When NES behavior is unclear, **dump from the NES ROM before changing anything**:

- **CHR** — character/tile ROM contents
- **OAM** — object attribute memory (sprite list)
- **NT** — nametable
- **PALRAM** — palette RAM
- **RAM** — work RAM tables
- **Live capture** — BizHawk Lua probes for runtime behavior (timing, scroll, sprite priority).

NES disasm references:
- `reference/aldonunez/*.asm` — community disassembly
- `src/zelda_translated/*.asm` — project translation

When drained C exists in `src/game/<subsystem>/*_runtime.c`, it is **PRIMARY** evidence. NES disasm is **SECONDARY** + final authority — it wins ties when drain is wrong.

## Execution rule

**No multi-choice prompts. No "OK to proceed?". No filler hedging.** Pick the path and execute. The user interrupts if wrong — that is faster than gating every step.

Exceptions (these still require user input):
- Destructive operations on shared state (force-push, branch deletion, dropping a database, `rm -rf` outside the repo).
- Anything publishing to GitHub or external services (PR, push, comment).
- Genuinely unrecoverable ambiguity — but exhaust memory + manifests + git log + NES ROM dump FIRST.

## Build / verify

- I build, I launch BizHawk, I screenshot. Never ask the user to do those.
- One probe per BizHawk launch — bundle screenshot + plane + SAT + CRAM + VRAM + regs in a single Lua.
- Always commit working state before starting next task.

## Project status pointer

The project's master plan lives at:

```
docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md
```

Active phase, task, gate state, blockers are tracked in:

```
docs/superpowers/prime_directive_tracker.json
docs/superpowers/prime_directive_status.md   (human-readable render)
```
