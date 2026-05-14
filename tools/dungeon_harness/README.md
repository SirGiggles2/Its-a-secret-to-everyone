# Dungeon Harness (Phase 14.0)

Deterministic per-dungeon save-state-injection harness for proving
NES Zelda 1 end-to-end completion on Debug.md.

## Layout

```
tools/dungeon_harness/
  README.md                 — this file
  manifest.json             — 18-row pinned save-state + RNG + probe map
  run_all.py                — orchestrator (filters by --level / --quest)
  save_states/              — BizHawk save states (1 per row)
    L1Q1.State              — checked in once captured + hashed
    L2Q1.State
    …
    L9Q2.State
  probes/
    dungeon_template.lua    — copy-this template for per-row probes
    dungeon_1_q1.lua        — L1Q1 critical-path input replay
    dungeon_2_q1.lua
    …
    dungeon_9_q2.lua
```

## How a row gets populated

1. **Capture save state**: load Debug.md in BizHawk, play (or
   inject) up to the dungeon entry. Save state. Drop in
   `save_states/L<level>Q<quest>.State`.
2. **Hash + seed**: compute SHA256, paste into `manifest.json` row.
   Note BizHawk RNG seed if applicable.
3. **Author probe**: copy `dungeon_template.lua` →
   `dungeon_<level>_q<n>.lua`. Fill in `SAVE_STATE_PATH`,
   `INPUT_SEQUENCE` (frame-keyed `joypad.set(...)` events for the
   minimal critical path from entry to boss kill).
4. **Dry-run**: `python tools/dungeon_harness/run_all.py --dry-run
   --level 1 --quest 1` — verifies files + hash match manifest.
5. **Live run**: launch BizHawk with the probe; verify it emits
   `builds/reports/dungeon_harness/<label>.json` with verdict
   GREEN.

## Run

```
python tools/dungeon_harness/run_all.py             # all 18 rows
python tools/dungeon_harness/run_all.py --quest 1   # 9 Q1 rows
python tools/dungeon_harness/run_all.py --level 1   # both quests, L1
python tools/dungeon_harness/run_all.py --dry-run   # checks only
```

Exit codes:
- 0 — all selected rows GREEN (or dry-run sane)
- 1 — at least one row RED
- 2 — manifest schema or file-missing error

## Why save-state injection (not movies)

Per debate-driven approach (Sonnet + Opus + Gemini), movies desync
without seeded preconditions. CLIs can't realistically replay a
4-hour 1-quest playthrough. Per-dungeon save-state injection
guarantees deterministic preconditions (inventory + flags + RAM all
pinned at entry) so the probe's critical-path input replays
identically every run.

## Schema

Each row emits `<label>.json` under `builds/reports/dungeon_harness/`
with:

```json
{
  "label": "L1Q1 Eagle",
  "level": 1, "quest": 1,
  "entry": { "frame": ..., "room": ..., "level": ...,
             "hearts": ..., "keys": ..., "bombs": ... },
  "kill":  { "frame": ..., "room": ..., "kill_count": ...,
             "boss_clear_frame": ..., "room_item_state": ... },
  "verdict": "GREEN" | "RED"
}
```

`boss_clear_frame > 0` AND `room_item_state == 0x00` (active item
visible) = GREEN. Otherwise RED.

## Phase 14.0 status

Scaffold shipped this commit:
- `manifest.json` — schema + 18-row skeleton with all save-state
  hashes + RNG seeds NULL pending live capture.
- `run_all.py` — orchestrator + manifest validator + dry-run mode.
- `probes/dungeon_template.lua` — per-row probe template.

Save states + per-row probes land as Phase 14.0 implementation PRs.
Tracked as deferral `phase14_dungeon_harness_population`.
