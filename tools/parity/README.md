# Parity Oracle — tools/parity/

Canonical infrastructure for comparing NES Zelda 1 behavior against the Genesis port.
Every "compare against NES" claim in a phase close report must cite `diff.py` output.

---

## Purpose

Before this directory existed, every verification task invented its own comparison.
Compare functions were duplicated, tolerances were inconsistent, and "visually similar"
was accepted without measurement. The Parity Oracle makes every diff mechanical and
deterministic:

1. Capture a NES reference frame → convert to schema instance via `nes_to_schema.py`.
2. Run a Genesis probe → emit a schema instance via `genesis_probe.lua`.
3. Diff the two instances via `diff.py` → get a structured PASS/FAIL/WARN report.
4. The phase close gate requires `diff.py` exit code 0 for every scenario.

---

## Files

| File | Purpose |
|------|---------|
| `schema.json` | JSON Schema (draft-07) defining every field in a parity instance. 17 top-level fields. |
| `diff.py` | Loads two instances, validates against schema, applies tolerances, emits JSON or human diff. |
| `genesis_probe.lua` | BizHawk Lua skeleton that emits a schema instance from a Genesis run. |
| `nes_to_schema.py` | Converts a Phase 1.5 NES capture bundle directory into a schema instance. |
| `tolerances.yaml` | Per-field tolerance policies (exact, window, functional, per_scenario). |
| `expected_failures.yaml` | Known intentional divergences (title screen, FS, Redux options). |

---

## Schema Fields (17 required)

| Field | Type | Description |
|-------|------|-------------|
| `frame` | int | Frame counter at capture. Must match within ±1. |
| `input_bitmask` | u8 | Controller 1 bitmask. Exact. |
| `rng_seed` | u16 | Injected scenario seed. Exact. |
| `rng_current` | u16 | Live RNG state at capture. Exact. |
| `room_id` | u8 | Current room ($EB). Exact. |
| `quest` | u8 | Quest 0 or 1 ($10C). Exact. |
| `link` | object | Link state: x/y/dir/action/anim_frame/hp/invuln_timer/b_item. Exact. |
| `enemies` | array[16] | Enemy object slots. Exact per slot. |
| `items` | array[8] | Floor item slots. Exact per slot. |
| `ram_bytes` | object | 4 named hex-string RAM buckets: globals/link_state_block/enemy_state_block/save_buffer. |
| `cram` | array[64] | Genesis CRAM dump (12-bit words). Byte-exact after NES PALRAM conversion. |
| `sat` | array[80] | Genesis SAT entries. Functional equivalence under sprite-collapse rules. |
| `oam` | array[64] | NES OAM entries. Reference for SAT functional comparator. |
| `plane_a_excerpt` | array[896] | Genesis Plane A nametable (32×28 tiles). Exact after NT conversion. |
| `plane_b_excerpt` | array[896] | Genesis Plane B nametable (32×28 tiles). Exact. |
| `nametable_excerpt` | array[0-960] | NES nametable bytes (32×30 tiles). NES-vs-NES regression only. |
| `screenshot_sha256` | hex64 | SHA-256 of PNG screenshot. Exact for static scenes; L1 threshold for animated. |

---

## Integration with Phase 1.5 NES Captures

Phase 1.5 NES capture harness writes bundles to:
```
build/generated/nes_reference/<rom_sha256>/<scenario_id>/
    screenshot.png
    oam.bin         (256 bytes: 64 × 4)
    palram.bin      (32 bytes: $3F00-$3F1F)
    ciram.bin       (2048 bytes: $2000-$27FF)
    ram.bin         (2048 bytes: $0000-$07FF)
    frame.txt       (decimal frame number)
    input_log.txt   (hex byte, controller 1 bitmask)
    rng_seed.txt    (hex u16)
```

Convert a bundle to a schema instance:
```
python tools/parity/nes_to_schema.py \
    build/generated/nes_reference/<hash>/<scenario_id>/ \
    --out build/generated/parity/<scenario_id>_nes.json
```

---

## Integration with Genesis Probes

The `genesis_probe.lua` skeleton runs inside BizHawk (Genesis/Blast Mode core).
Set `GEN_PROBE_OUT` to the output path before launching:

```
set GEN_PROBE_OUT=build/generated/parity/<scenario_id>_gen.json
# Launch via bizhawkScript skill (memory: feedback_use_bizhawk_skill)
```

The probe emits a schema instance at the target frame, then pauses BizHawk.

---

## Running a Diff

```bash
# Machine-readable JSON diff (for regression matrix)
python tools/parity/diff.py \
    --nes build/generated/parity/<scenario_id>_nes.json \
    --gen build/generated/parity/<scenario_id>_gen.json \
    --scenario-id <scenario_id>

# Human-readable terminal summary
python tools/parity/diff.py \
    --nes build/generated/parity/<scenario_id>_nes.json \
    --gen build/generated/parity/<scenario_id>_gen.json \
    --scenario-id <scenario_id> \
    --human
```

Exit code 0 = all fields within tolerance (PASS or WARN only).
Exit code 1 = one or more hard failures (FAIL).
Exit code 2 = schema validation error.
Exit code 3 = file I/O error.

---

## Phase Close Gate

Every implementation phase closes with this sequence (from master plan Phase Close Gate):

1. Build the touched target with `REQUIRE_GENERATED_ASSETS=1`.
2. Run the focused probe set.
3. **Capture screenshot/state evidence; emit a parity-oracle-schema instance per probe.**
4. **Diff each schema instance against the matching `build/generated/nes_reference/` capture.**
5. Run `tools/run_regression_matrix.py`; require green.

Step 3 = `genesis_probe.lua` + `nes_to_schema.py`.
Step 4 = `diff.py`. Exit code must be 0 to close the phase.

Every phase report must include the `diff.py --human` output for at least the canonical
scenario (room_id 0x77 for overworld, room_id 0x80 for dungeon L1, etc.).

---

## Workstream F Regression Matrix Integration

`tools/run_regression_matrix.py` (Workstream F) calls `diff.py` for each (scenario, phase)
pair in the regression suite. The regression matrix:

- Reads the scenario list from `builds/reports/regression_scenarios.yaml`.
- For each scenario: runs genesis probe, runs nes_to_schema, runs diff.
- Collects exit codes; fails if any non-expected hard failure is present.
- Writes `builds/reports/regression_matrix_<date>.json` with per-scenario results.

---

## Tolerances Summary

See `tolerances.yaml` for full policy. Key rules:

| Field group | Policy |
|------------|--------|
| CRAM | Byte-exact after NES PALRAM → Genesis CRAM conversion via `misc_palettes` LUT |
| SAT vs OAM | Functional equivalence under Genesis sprite-collapse rules (stub until Phase 2) |
| Screenshot (static) | Byte-exact SHA-256 match (whitelist in tolerances.yaml) |
| Screenshot (animated) | Per-pixel L1 distance ≤ 512 total |
| Frame counter | Match within ±1 |
| RAM globals/link/enemy | Byte-exact hex |
| RAM save_buffer | Structural (field-level, tolerates Genesis layout differences) |
| All game state scalars | Exact |

---

## Expected Failures

`expected_failures.yaml` lists known intentional divergences. `diff.py` downgrades
matching failures from FAIL to WARN. Warnings do not fail the gate.

Current documented divergences:
- `title_screen_*` — deliberately customized (not NES-faithful). See memory: `project_title_screen_goal`.
- `file_select_*` — deliberately customized. Same memory reference.
- `redux_*` — option-driven divergences (CHR expansion, palette PAL2/PAL3, automap).
- `multiplayer_*` — Phase 13 design divergence; excluded from NES parity gate entirely.
- `t34_movement_*` — TURBO_LINK debug flag (genesis_shell.asm:44); flip to 0 for real parity.

To add a new expected failure, append to `expected_failures.yaml` with a `reason` and
`owner_phase` (0 = permanent; N = revisit at phase N). Document the memory reference if
one exists.

---

## Dependencies

- Python 3.8+
- `jsonschema` (optional but recommended; `pip install jsonschema`). Without it, a
  hand-rolled minimal validator is used.
- `pyyaml` (optional; `pip install pyyaml`). Without it, a hand-rolled minimal YAML
  parser handles the simple list-of-dicts structure in the config files.
- BizHawk with Genesis/Blast Mode core for `genesis_probe.lua`.
- `build/generated/palettes/misc_palettes.bin` — generated by `tools/builder/` from
  the user-supplied NES ROM. Required for accurate CRAM comparison.
