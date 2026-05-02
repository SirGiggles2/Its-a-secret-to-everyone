# Regression Matrix — tools/run_regression_matrix.py

Workstream F infrastructure for detecting cross-phase regressions in the
NES Zelda → Sega Genesis port.

---

## Purpose

Per-phase gates close phases independently, but Phase N can silently break
Phase M's probe. Without a global regression matrix, drift is invisible until
release. The regression matrix runs every discovered probe against the current
build and emits a green/red verdict per probe.

---

## How the Matrix Discovers Probes

The matrix discovers probes from four sources, in priority order:

### 1. Parity-oracle probe pairs (`build/generated/parity/`)

The canonical source. Any file matching `*_nes.json` that has a corresponding
`*_gen.json` in the same directory is a parity-oracle probe.

- NES side: produced by `tools/parity/nes_to_schema.py` from a Phase 1.5 NES
  capture bundle (`build/generated/nes_reference/<hash>/<scenario_id>/`).
- Genesis side: produced by `tools/parity/genesis_probe.lua` running in BizHawk.
- Diff: `tools/parity/diff.py --nes <nes.json> --gen <gen.json>`.
- Verdict: diff.py exit code 0 = GREEN, exit code 1 = RED.

### 2. Archived report probe pairs (`builds/reports/`)

Any `*_gen.json` file under `builds/reports/` that has a matching `*_nes.json`
sibling is treated as an archived parity-oracle probe. This catches older reports
that were written before the `build/generated/parity/` convention was established.

### 3. Binary baseline probes (`tools/probes/baselines/*.bin`)

Byte-exact binary comparison. Baseline is the `.bin` file checked in under
`tools/probes/baselines/`. Current output is expected at
`builds/reports/baselines/<probe_id>.bin` (emitted by the phase's probe runner).

These are used for probes that capture a RAM slice, save-buffer, or other binary
snapshot that does not yet have a parity-oracle schema instance.

### 4. Screenshot baseline probes (`tools/probes/baselines/*.png`)

SHA-256 comparison (byte-exact for static scenes). Current output expected at
`builds/reports/screenshots/<probe_id>.png`.

If PIL/Pillow is available, falls back to pixel L1 comparison with a threshold
of 512 for animated scenes (same threshold as `tools/parity/tolerances.yaml`).

---

## When to Add a Probe to the Matrix

Add a probe when:

1. A new phase closes and the phase has at least one verifiable visual or
   behavioral claim (every phase that emits a parity-oracle schema instance
   automatically lands in the matrix).
2. A bug is found that a probe would have caught. Add the probe before fixing
   the bug so the fix is regression-protected.
3. A new subsystem is promoted from RoomRom to shared `src/game/` (Phase 12
   promotion gate). Each promoted subsystem must have at least one probe in
   the matrix.

Do NOT add probes for:
- Development artifacts (temporary Lua scripts, one-off capture dumps).
- Redundant probes that test the same logical invariant as an existing probe
  (prefer parity-oracle over binary baseline; prefer parity-oracle over screenshot).

---

## When to Add an Entry to `expected_failures.yaml` vs Fix the Regression

Use `tools/parity/expected_failures.yaml` when:

- The divergence is **intentional** and documented in MEMORY.md or the master plan
  (e.g., title screen is deliberately Genesis-custom, not NES-faithful).
- The divergence is **option-driven** (Redux CHR expansion, Redux palette PAL2/PAL3).
- A Phase N TURBO_LINK or debug flag is known to cause a temporary divergence
  that will be removed at Phase N close.
- Multiplayer mode (Phase 13+) introduces by-design PlayerState divergences.

**Fix the regression** when:
- The divergence is unexpected and no MEMORY.md entry justifies it.
- The `owner_phase` of an existing expected-failure entry has been reached
  (the owner phase must either resolve the entry or extend it with a new
  `owner_phase`).
- The probe was previously GREEN and a code change made it RED.

Entry format in `expected_failures.yaml`:

```yaml
- scenario_id: "title_screen_*"
  field_path: /screenshot_sha256
  reason: >
    Title screen visuals are deliberately customized for the Genesis port.
    See memory entry project_title_screen_goal.
  owner_phase: 0       # 0 = permanent; N = revisit at phase N
  memory_ref: project_title_screen_goal
```

---

## Phase Close Gate Integration

The regression matrix is Phase Close Gate step 5 (master plan):

```
Phase Close Gate (every phase):
  1. Build touched target with REQUIRE_GENERATED_ASSETS=1 (Task 1.11 strict gate).
  2. Run focused probe set.
  3. Capture screenshot/state evidence; emit parity-oracle-schema instance per probe.
  4. Diff each schema instance against build/generated/nes_reference/ capture.
  5. Run tools/run_regression_matrix.py; require green (Workstream F).   ← HERE
  6. Run tools/state/verify_no_alias_collisions.py if phase touched src/state/.
  7. Confirm per-subsystem PROBE_CYCLE_LIMIT envelope not exceeded (Workstream F
     cycle gate, required from Phase 6 onward).
  8-11. Code review, fix, re-run, commit.
```

The cycle gate (step 7) is `tools/per_subsystem_cycle_check.py`. See
`builds/reports/perf/genesis_budget_baseline.md` for budget values.

---

## Running the Matrix

```bash
# Full matrix (all probes):
python tools/run_regression_matrix.py

# Phase-scoped (only probes relevant to Phase 3):
python tools/run_regression_matrix.py --phase 3

# Quiet mode (one verdict line, suitable for CI log):
python tools/run_regression_matrix.py --quiet

# Custom output path:
python tools/run_regression_matrix.py --out builds/reports/phase3_matrix.md

# Also emit JSON for CI consumption:
python tools/run_regression_matrix.py --json-out builds/reports/regression_matrix.json
```

Exit codes:
- `0` — all green, OR all red probes are in `expected_failures.yaml`.
- `1` — one or more unexpected red probes.

---

## CI Job Specification

Recommended CI job (add to `.github/workflows/regression_matrix.yml` or equivalent):

```yaml
name: Regression Matrix

on:
  push:
    branches: [main, roomrom-s1]
  pull_request:

jobs:
  regression-matrix:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install optional dependencies
        run: pip install pyyaml jsonschema pillow
        continue-on-error: true   # matrix runs without them; accuracy improves with them

      - name: Run regression matrix
        run: python tools/run_regression_matrix.py --quiet --json-out builds/reports/regression_matrix.json
        # Exit 0 if all green or all red are expected failures.
        # Exit 1 on unexpected red — blocks the PR.

      - name: Run cycle budget check (Phase 6+)
        run: python tools/per_subsystem_cycle_check.py --quiet
        # Vacuously green when no perf JSON files exist (before Phase 6).

      - name: Upload matrix report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: regression-matrix
          path: builds/reports/regression_matrix.*
```

**Note:** The CI job skips probes when the current ROM is not present
(`SKIP: ROM missing`). The matrix is vacuously green in that case. This is
intentional — CI without a user-supplied NES ROM cannot build the Genesis ROM,
so skip-heavy runs are expected on public CI. Full green requires a local run
with the NES ROM present.

---

## Output Files

| File | Description |
|------|-------------|
| `builds/reports/regression_matrix.md` | Human-readable Markdown report (default output) |
| `builds/reports/regression_matrix.json` | Machine-readable JSON companion (always emitted alongside .md) |

---

## Dependencies

- Python 3.8+
- `pyyaml` (optional; built-in minimal parser used if absent)
- `jsonschema` (optional; used by `tools/parity/diff.py`)
- `pillow` (optional; enables pixel L1 screenshot comparison)

---

## Related Files

| File | Role |
|------|------|
| `tools/parity/diff.py` | Parity-oracle diff engine (called for every parity-oracle probe) |
| `tools/parity/tolerances.yaml` | Per-field tolerance policies |
| `tools/parity/expected_failures.yaml` | Known intentional divergences |
| `tools/parity/schema.json` | Parity-oracle schema (17 required fields) |
| `tools/per_subsystem_cycle_check.py` | Cycle budget checker (Phase Close Gate step 7) |
| `docs/audit/genesis_budget_baseline.md` | Budget baseline table (source-controlled; Phase 15.2 fills this in) |
| `tools/builder/strict_build_check.py` | Strict build gate (Phase Close Gate step 1) |
| `tools/nes_capture/run_capture.py` | Phase 1.5 NES reference capture driver |
| `tools/parity/nes_to_schema.py` | Converts NES capture bundle to schema instance |
| `tools/parity/genesis_probe.lua` | BizHawk Lua skeleton for Genesis probe output |
