<!-- docs/audit/parity_schema_check.md -->
# Normalized Parity Schema — S1 Validation

The spec's Section 0 normalized scene schema (`bg_tile`, `bg_palette`,
`bg_priority`, `sprite[]`, `scroll`, `state`) is **specified at S0**, but the
manual NES-vs-Genesis sanity check that proves the schema is sufficient on a
known-equivalent screen pair is **deferred to S1**. Reason: the check
requires BizHawk capture runs of both ROMs and side-by-side schema diff
tooling; S0 was scoped to documentation/audit work and explicitly skips
emulator runs.

## Plan for S1

1. First S1 milestone after the build pipeline is rewired: capture the
   title-screen-idle frame from both NES (`Zelda1-Redux/Legend of Zelda, The
   (USA).nes`) and Genesis (`builds/whatif.md`, hash `4bcfc1d916f44f31f36ee5bc0862b6b696313a264ffcc8373abde87d318befb4`).
2. Implement minimal `tools/probes/normalize_nes.py` and
   `tools/probes/normalize_gen.py` that emit the schema for the chosen
   frame.
3. Run `tools/probes/diff_normalized.py` and confirm the schema fields match
   on the title-screen-idle pair.
4. If any schema field cannot be produced cleanly (e.g. sprite priority
   semantics differ), record the gap and amend Section 0 of the spec
   before locking S1.

## Risk if deferred

Low. The schema is well-specified textually; the deferred work is empirical
validation, not design. If the schema turns out insufficient at S1, the
amendment cost is updating Section 0 fields plus the normalize scripts —
work that S1 does anyway.
