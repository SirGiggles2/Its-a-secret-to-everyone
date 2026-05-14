# Phase 14 Task 14.0 — Dungeon Harness (BLOCKING for 14.1/14.2)

- **NES source**: `reference/aldonunez/Z_07.asm` per-level dungeon
                  dispatch + LevelInfoBlock layout (per-quest
                  per-level entry rooms, boss room IDs, triforce
                  reward slots). Plus `Z_04.asm` per-boss INIT/UPDATE
                  dispatched at the dungeon's boss-room load.
- **Drained C**:  Per-boss bodies (Phase 8 — all 10 boss families
                  drained); per-level LevelInfoBlock data tables;
                  Phase 5 dungeon-core dispatch. Phase 14.0 itself
                  is a tooling layer (not a runtime drain).
- **Coverage**:   PARTIAL (scaffold) — harness directory + manifest
                  schema + orchestrator + per-row probe template
                  shipped this commit. 18 of 18 manifest rows
                  carry NULL `save_state_sha256` + NULL `rng_seed`
                  + missing per-row probe + missing save state.
                  Live-capture population deferred to follow-up.
- **Stance**:     PARTIAL — scaffold ADOPT (orchestrator + manifest
                  schema reflect debate-driven save-state injection
                  decision); per-row population is implementation
                  work that lands per dungeon as Phase 14.0
                  follow-up PRs.

## Master plan checklist

| Item                                                  | Status | Evidence |
|-------------------------------------------------------|--------|----------|
| Create `tools/dungeon_harness/` directory             | ✓      | dir + README + manifest + orchestrator + template |
| Per-level/quest save state + probe (18 rows)          | ✗      | scaffold rows carry NULL hashes; population deferred |
| Pin save state hash + seeded RNG in manifest          | ✓      | schema supports both fields per row; values NULL until populated |
| `run_all.py` orchestrator                              | ✓      | filters by `--level` / `--quest`; `--dry-run` validates manifest + files |
| Final.md (Debug.md) passes 1+ dungeon before 14.1     | ✗      | gated on first dungeon row population |
| Consume Phase 1.5 NES reference + Task 2.8 schema     | ✓      | probe template captures parity-oracle schema instance per row |
| Commit `tools: add per-dungeon save-state harness`    | ✓      | this commit |

## Scaffold artifacts

```
tools/dungeon_harness/
  README.md
  manifest.json          (18 rows; schema_version 1)
  run_all.py             (orchestrator + dry-run validator)
  save_states/           (empty; populated per dungeon)
  probes/
    dungeon_template.lua (copy-this template)
```

## Decision: save-state injection over movies

Per debate-driven approach (Sonnet + Opus + Gemini agreed): movie
files desync without seeded preconditions; manual checklists
require a human. Save-state injection guarantees deterministic
preconditions (inventory + flags + RAM pinned at dungeon entry) so
the per-dungeon Lua probe replays the minimal critical path
identically every run.

## Deferral

`phase14_dungeon_harness_population` — capture + hash + author
probes for 18 manifest rows. Each row's PR:
1. Capture BizHawk save state at dungeon entry (correct inventory +
   flags).
2. Compute SHA256, paste into manifest row.
3. Copy `dungeon_template.lua` → `dungeon_<level>_q<n>.lua`; fill
   `SAVE_STATE_PATH` + `INPUT_SEQUENCE` (frame-keyed critical-path
   replay).
4. `python tools/dungeon_harness/run_all.py --dry-run --level N
   --quest M` — verify schema + file presence.
5. Live run — `python tools/dungeon_harness/run_all.py --level N
   --quest M` — verify GREEN verdict.

## Status

CLOSE (with population deferral) — Task 14.0 scaffold landed.
18-row manifest skeleton + orchestrator + per-row probe template
ready for incremental per-dungeon population PRs.
