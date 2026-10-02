# T-177 — probe completion and immutable identity (2026-10-01)

Reproduction: `lag_scan.py nonexistent_t177_case` previously silently skipped
the missing directory and printed LAG PASS with zero cases. Empty/misaligned
video streams were truncated to the shorter length. Screen sweep ignored runner
exit codes and returned success with zero checked screens. `run_lockstep` ignored
the Genesis runner failure; `diff` could accept equal truncated captures or bless
one when the NES reference was also short. `run_probe` hashed the shared source
ROM after capture, so a concurrent rebuild could label old evidence as new.

Owners: `tools/debug/run_probe.py`, `tools/lockstep/{capture_evidence,diff,
run_lockstep,lag_scan,screen_sweep}.py`. Stance: EXTEND existing runners/gates;
no emulator/process lifecycle replacement. Required behaviors: completed case
records, script coverage, matched frame records, honest missing-evidence failure,
and identity of the payload actually launched. This task does not close the
whole legacy-launcher inventory in P0.17.

- One shared validator requires no .err, one positive final `frames=N`, and
  exactly N 2048-byte RAM records. Cached NES records are also validated.
- Lag scanner rejects absent/empty/truncated/mismatched/out-of-order video,
  missing ticks except explicitly declared fast-transition padding, unequal
  completion counts and zero comparable cases. It reports completed case count.
- RAM gate requires both captures to reach the required script duration with
  equal lengths and no fail-fast termination; partial diagnostics cannot pass
  or update a baseline. Runner failure blocks acceptance even if files exist.
- Screen sweep propagates capture/validation errors and rejects zero checked
  screens. Pixel differences remain triage candidates, including previously
  accepted sprite overlap; they are not automatically classified as game bugs.
- Probe identity is SHA-256 of private staged ROM/script/seed before launch,
  with staged ROM path recorded. Owned-process-only cleanup remains unchanged.
- `run_lockstep --rom PATH --report-suffix _codex_CASE` now supports frozen
  inputs and unique reports directly, preserving the preset's baseline name.
  Suffix accepts only ASCII letters, digits, underscores and hyphens.

Focused tests: `python tools/lockstep/test_capture_evidence.py`, 11/11 PASS.
They cover absent/zero cases, completion markers, malformed video, missing ticks,
unequal counts, declared padding, errors, RAM lengths, partial baseline refusal,
runner failure, screen errors and concurrent source mutation while the executed
copy stays correctly identified. Portable fixture uses mocked Windows launch;
actual emulator process cleanup is unmodified. Python compile and diff check PASS.

Live Windows BizHawk consumer `t110_bomb_enemy_codex_t177`: 401/401 GATE,
unchanged baseline, complete frame trace LAG PASS (one completed case). NES
staged hash8f72dc2e and Genesis staged hash2ed27ffb each rechecked against the
launched private file. Tick330 differs only at two accepted OAM-overlap pixels.
Direct new CLI consumer `t121_ring1_codex_t177_live`: 192/192 GATE on frozen
`builds/playtests/Debug-T178.md`; task changes no game code or ROM.

Prior Patra and OW completed traces still LAG PASS, explicitly two checked cases.
The missing lag case and missing screen case now exit1; no baselines changed.
Unchanged Windows game build is T-178 SHA-256
`2ED27FFB37E315C03132ED0D51CC0C9DC0A333EBDAA1EA1954AF4231C40112B5`.
