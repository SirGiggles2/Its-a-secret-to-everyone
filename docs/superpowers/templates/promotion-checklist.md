# Promotion Checklist Template

Copy this list into every batch note (plan doc, PR description, or commit
trailer) that promotes code out of `src/gen/` into an owned runtime module,
or that moves behavior between owned modules.

Source: `best practices.md` §Promotion Checklist, §Design Checklist for
Promotion Batches, §Routine and State Checklist, §Done Definition.

## Before starting the batch

- [ ] Long-term owning subsystem identified.
- [ ] Destination owned module identified (existing or new split).
- [ ] Compatibility wrapper plan identified (bank forwarder stays, symbol
      preserved).
- [ ] Touched raw RAM fields are already named in `nes_abi.h` or a
      `*_state.h` header. If not, name them first.
- [ ] Behavior is being moved as part of a coherent family, not at random.
- [ ] Focused smoke/probe plan named (T34, cave, enemy spawn, etc.).
- [ ] Rollback point captured: baseline ROM hash stored under
      `builds/reports/`.

## Design quality

- [ ] More than one decomposition considered before choosing.
- [ ] Change moves code upward into subsystem / problem-domain terms.
- [ ] Hardware/ABI details stay below the owned runtime layer.
- [ ] Subsystem interface is narrow and intentional.
- [ ] Coupling reduced rather than preserved.
- [ ] Design is lean; no unnecessary new abstraction.

## Routine / state quality

- [ ] Each routine does one well-defined job.
- [ ] Routine names describe behavior, not historical bank origin.
- [ ] Wrappers remain thin and boring.
- [ ] Input parameters not used as working scratch.
- [ ] Enums / named constants replace ad-hoc flags and magic values.

## Verification

- [ ] `build.bat` passes green.
- [ ] `tools/emit_gen_wrappers.py --check` exits 0.
- [ ] Targeted parity probe passes (T34 or subsystem-specific).
- [ ] `tools/compare_perf.py` reports `0 FAIL`.
- [ ] ROM diff vs baseline is expected (same when no behavior change
      intended; documented delta otherwise).

## Done definition

- [ ] Behavior matches expectations for the targeted area.
- [ ] Ownership is clearer than before.
- [ ] Wrappers preserve compatibility entrypoints.
- [ ] Raw offsets touched by the batch have names or controlled aliases.
- [ ] Smoke/probe coverage exists for the batch.
- [ ] Change leaves behind less coupling, less magic state, or less
      generated ownership than before.

Compilation alone is not done. Language change alone is not progress.
