# Genesis Cycle Budget Baseline

**Status:** Placeholder — Phase 15.2 measures and fills in all values.

**Policy:** Every budget must be measured before any optimization claim is accepted.
Submitting a performance improvement without a pre-measurement baseline is not accepted.
Per-subsystem `PROBE_CYCLE_LIMIT` enforcement runs inline from Phase 6 onward
(master plan Workstream F + debate 002 hybrid, Phase Close Gate step 7).

---

## Budget Envelope Policy

> "Budget envelope: TBD — must be measured before any optimization claim."

- **Baseline TBD** = actual cycle count measured from a known-good build at a
  reference scene. Phase 15.2 establishes all baselines by running
  `tools/cycle_probe.lua` + `tools/cycle_profile_report.py` against a stable
  Phase 14 ROM across the canonical scene set.
- **Budget TBD** = target ceiling. Typically set at 10–20 % above the baseline
  to allow headroom without regressing. Phase 15.2 negotiates all budget ceilings.
- Once established, values are locked here. Changing a budget requires a comment
  citing the commit that changed it and the reason.

---

## Subsystem Budget Table

| subsystem | baseline_cycles | budget_cycles | note |
|-----------|-----------------|---------------|------|
| cpu_frame | TBD | TBD | Total CPU cycles consumed per visible frame (non-VBlank). Covers game logic, collision, AI, scroll update. |
| vblank | TBD | TBD | CPU cycles spent inside the VBlank interrupt handler. Must fit in ~7500 master-clock cycles for PAL or ~6840 for NTSC timing window. |
| dma_queue | TBD | TBD | Cycles to flush the DMA queue at VBlank start. Includes VRAM upload and SAT DMA. |
| sat | TBD | TBD | Cycles to build and DMA the Sprite Attribute Table (80 entries). |
| sprite_count | TBD | TBD | Visible sprite count per frame. Hard ceiling: 80 hardware sprites. Practical budget TBD. |
| vram_upload | TBD | TBD | Cycles spent on VRAM tile writes per frame (CHR streaming, room load). |
| cram_writes | TBD | TBD | Cycles spent on CRAM palette writes per frame (flash toggle, room transition). |
| audio_tick | TBD | TBD | Cycles consumed by the audio driver tick (YM2612 + PSG register writes + MIDI sequencer). |

---

## Perf Measurement File Format

Each phase that has cycle-budget probes emits files to:

    builds/reports/perf/<phase>_<scene>.json

Expected JSON schema:

```json
{
  "phase": "6",
  "scene": "uw_l1_room0",
  "timestamp": "2026-05-02T00:00:00Z",
  "builder_version": "s1",
  "subsystems": {
    "cpu_frame": 12345,
    "vblank": 3200,
    "dma_queue": 800,
    "sat": 400,
    "sprite_count": 18,
    "vram_upload": 1600,
    "cram_writes": 64,
    "audio_tick": 1100
  }
}
```

The `subsystems` dict keys must match the `subsystem` column above (lowercase,
underscores). Unknown keys are reported as SKIP by `per_subsystem_cycle_check.py`.

---

## Canonical Scene Set for Baseline Measurement

Phase 15.2 measures these scenes and records the results above:

| Scene ID | Description |
|----------|-------------|
| `ow_room_00` | Overworld spawn room, Link idle |
| `ow_room_77` | Death Mountain overworld, Peahat stress |
| `uw_l1_room0` | Dungeon L1 entry room |
| `uw_l4_darknut_room` | Dungeon L4 Darknut room (enemy AI stress) |
| `uw_l7_gibdo_room` | Dungeon L7 Gibdo room |
| `uw_l9_ganon_room` | Ganon darkness room (enemy + projectile stress) |
| `cave_sword` | Cave room with old man |
| `title_idle` | Title screen idle (no gameplay) |
| `file_select_3slots` | File Select with 3 populated slots |

---

## Integration with Workstream F

`tools/per_subsystem_cycle_check.py` reads this file and compares against
`builds/reports/perf/*.json` measurements. The tool exits 0 if all measured
subsystems are within budget, 1 if any exceed budget.

It is called at Phase Close Gate step 7 (from Phase 6 onward):

```
7. Confirm per-subsystem PROBE_CYCLE_LIMIT envelope was not exceeded (Workstream F cycle gate).
```

See `tools/regression_matrix_README.md` for the full integration specification.
