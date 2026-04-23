# Best Practices

## North Star

- Owned subsystem C is the real codebase.
- `gen/` is adapter layer only.
- ASM stays only for boot/reset/interrupt entry, hardware/IO primitives,
  bank/window glue, and truly hot code that proves timing-sensitive.

## Core Rules

- Promote logic into hand-owned C modules, not deeper into generated bank files.
- Preserve thin compatibility wrappers in `src/gen/` so old entrypoints still work.
- Treat generated C as staging/reference, not long-term ownership.
- Do not grow ASM unless there is a real hardware, ABI, or timing reason.
- Favor subsystem ownership over bank ownership.

## Construction Conventions

Define these once and keep them stable:

- naming conventions for state, enums, constants, helpers, and wrappers
- wrapper pattern for promoted bank entrypoints
- layout/comment conventions
- where assertions belong vs. where recovery/logging belongs
- what must happen before code is considered ready to check in
- what toolchain/compiler features are allowed or disallowed

Program into this codebase, not merely in C:
when the language/toolchain is missing structure you need, add local conventions,
headers, typedefs, helper layers, and wrapper tooling rather than letting the
lowest-level environment dictate the architecture.

## Highest-Leverage Workflow

### 1. Build migration infrastructure first

Invest early in tools and shared headers that make every later conversion cheaper:

- state-map headers
- subsystem private headers
- wrapper-generation tooling
- shared primitive typedefs if desired (`u8`, `u16`, `u32`)
- smoke/probe helpers
- debug assertions for owned runtime code

This is the biggest efficiency multiplier.

### 2. Convert by behavior family, not by random function

Good batch shapes:

- enemy walker family
- enemy flyer family
- enemy projectile/spawn family
- cave/person family
- link/world-transition family

This gives cleaner ownership, easier parity checks, and better optimization surfaces.

### 3. Automate wrapper emission

Generated bank wrappers are repetitive and should be machine-generated where possible:

- one-line `z_0x` forwarders
- declarations
- promotion boundary tables
- wrapper stubs for compatibility entrypoints

Human time should go into owned module design, naming, behavior cleanup, and optimization,
not wrapper boilerplate.

### 4. Expand symbolic RAM naming aggressively

This is critical path.

Build subsystem maps like:

- `enemy_state.h`
- `link_state.h`
- `cave_state.h`
- `world_state.h`
- `item_state.h`

Also add:

- direction enums
- item/type/state enums
- named scratch/temp fields where stable
- named constants instead of repeated literals
- temporary aliases when meaning is partial but usage is recurring

Without names, every future move is slower and riskier.

### 5. Keep `gen/` passive

Rule:

- no real fixes in `gen/` except emergency unblockers
- real fixes go into owned C modules
- generated bank files become wrappers and compatibility glue only

This prevents split ownership drift.

### 6. Verify per subsystem milestone

Use milestone-sized verification:

- promote one family
- build
- run focused probe or smoke
- continue

Do not stop on every tiny helper if the subsystem boundary is already clear.

### 7. Split large owned files early

Do not let promoted C turn into new giant dumps.

Split as soon as a family is visible:

- `enemy_walker_runtime.c`
- `enemy_flyer_runtime.c`
- `enemy_boss_runtime.c`
- `enemy_projectile_runtime.c`

Architecture should improve while converting, not merely change languages.

### 8. Optimize after ownership and naming are clear

Real optimization should happen after:

- module boundaries are clear
- state names are clear
- wrappers are thin
- subsystem ownership is stable

Then hot-path cleanup becomes much easier:

- remove redundant RAM loads/stores
- simplify state transitions
- tighten helpers
- identify true hot loops worth special treatment

## Promotion Checklist

Before promoting a function or behavior family:

- [ ] Is the long-term owning subsystem identified?
- [ ] Is the destination owned module identified?
- [ ] Is the compatibility wrapper plan identified?
- [ ] Are the touched raw RAM fields already named?
- [ ] If not named yet, is there a temporary alias plan so literals do not spread?
- [ ] Is the behavior being moved as part of a coherent family rather than randomly?
- [ ] Is there a focused smoke/probe plan for this batch?
- [ ] Is there a rollback point or saved baseline?

A promotion is not complete just because it compiles.

## Design Checklist for Promotion Batches

For each subsystem-sized batch:

- [ ] Have you considered more than one decomposition before choosing one?
- [ ] Is the design stratified into layers?
- [ ] Does this change move code upward into subsystem/problem-domain terms?
- [ ] Are hardware/ABI details kept below the owned runtime layer?
- [ ] Are subsystem interfaces narrow and intentional?
- [ ] Is coupling reduced rather than preserved?
- [ ] Is the result easier to maintain than the source form?
- [ ] Is the design lean, with no unnecessary new abstraction?
- [ ] Does the change reduce accidental complexity?

## Routine and State Checklist

For owned C code:

- [ ] Does each routine do one well-defined job?
- [ ] Is each routine named for behavior, not for historical bank origin?
- [ ] Is the interface obvious?
- [ ] Are wrappers boring and thin?
- [ ] Are input parameters treated as inputs, not working scratch?
- [ ] Are extra locals introduced when they clarify transformations?
- [ ] Are variables used only for the purpose their names imply?
- [ ] Are enums and named constants used instead of ad hoc flags or magic values?
- [ ] Are loop counters and scratch variables named clearly when they persist beyond a tiny scope?
- [ ] Does the code read in problem-domain terms where possible?

## Boundary / Barricade Rule

Treat the hardware/ABI/generated boundary as the dirty edge.

At the dirty edge:

- translate calling convention concerns
- translate raw offsets and compatibility entrypoints
- validate or normalize data when needed
- preserve legacy ABI behavior

Inside owned runtime code:

- assume cleaner invariants
- use assertions to catch broken assumptions early
- avoid repeating low-level defensive clutter everywhere

Do not leak dirty-edge conventions deep into owned subsystem code.

## Integration and Verification Checklist

- [ ] Is the integration order intentional?
- [ ] Does construction order support integration order?
- [ ] Are interfaces between participating components specified clearly enough?
- [ ] Are you integrating incrementally rather than in one giant phase?
- [ ] Are promotions happening in visible slices or feature families?
- [ ] Is the project building frequently?
- [ ] Is a smoke/probe run with each meaningful batch?
- [ ] Are build and smoke steps automated where practical?
- [ ] Is a broken build treated as top priority?
- [ ] Is the smoke/probe suite kept current as the port evolves?
- [ ] Are regression notes kept for what was verified?

## Refactoring Safely Checklist

When cleaning or restructuring code:

- [ ] Is each change part of a deliberate strategy?
- [ ] Did you save the starting state?
- [ ] Are refactors small?
- [ ] Are you doing one refactor at a time?
- [ ] Do you have a list of intended steps?
- [ ] Do you have a parking lot for side ideas discovered mid-refactor?
- [ ] Are you retesting after each meaningful change?
- [ ] Are risky changes reviewed?
- [ ] Is the change improving internal quality?
- [ ] Are you avoiding “refactor” as a label for unrelated behavior changes?

## What To Preserve In ASM

- boot/reset/interrupt entry
- bank/window copy and hard ABI glue
- direct VDP/PPU/IO primitives
- truly hot blit/transfer code that proves timing-sensitive

## What To Keep Moving Into C

- gameplay state machines
- collision/combat/item logic
- enemy AI and updates
- room/cave/person logic
- movement rules, as long as frame budget stays fine

## Performance Exception Rule

Do not keep something low-level based on instinct.

A lower-level implementation should have at least one of:

- measured frame-time impact
- hard timing requirement
- ABI/hardware requirement

If performance is the reason, document:

- hotspot
- symptom or measurement
- why the clearer owned-C version was insufficient
- why the chosen lower-level solution is justified

## Split Trigger

Split an owned runtime file when any of these becomes true:

- multiple behavior families are visible
- the file is hard to scan in one sitting
- unrelated state maps appear together
- the review surface is too broad
- dependency surface keeps growing

Split by behavior family or subsystem responsibility, not arbitrary file size alone.

## Done Definition

A migration batch is done when:

- behavior still matches expectations for the targeted area
- ownership is clearer than before
- wrappers preserve compatibility entrypoints
- raw offsets touched by the batch have names or controlled aliases
- smoke/probe coverage exists for the batch
- the change leaves behind less coupling, less magic state, or less generated ownership than before

Compilation alone is not done.
Language change alone is not progress.
Readability, ownership clarity, and safer future change are the goal.

## Best Immediate Priorities

1. Keep splitting enemy code by behavior family.
2. Expand subsystem RAM/state headers aggressively.
3. Build wrapper-generation helper so manual drain work speeds up.
4. Replace raw `extern` walls with real subsystem headers.
5. Add a promotion checklist to every substantial migration PR or batch note.
6. Add an integration/smoke rule so each subsystem batch proves it still works.

## Decision Filter

When choosing between two approaches, prefer the one that:

- leaves behind clearer owned C ownership
- reduces dependence on generated bank files
- reduces raw magic RAM offsets
- avoids new ASM growth
- makes future optimization easier
- keeps verification practical
- makes the code more self-documenting
- reduces coupling across subsystem boundaries

That is the long-term path with best efficiency and best engineering payoff.