# T-139 — overworld tile object at room entry

- **NES source:** `reference/aldonunez/Z_05.asm:SetupTileObjectOW`, `CheckTileObject`
- **Drained C:** `src/game/enemies/enemy_loop.c:ow_tile_object_room_setup`; `src/game/room/room_dispatch.c:room_setup_tile_object_ow`
- **Coverage:** FULL for room-entry slot-11 type and position; broader tile-object interactions remain in their own tasks.
- **Stance:** ADOPT. Current path already installs the object on the NES entry tick.

The T-139 row came from an earlier `t123_slow_tiles` capture (and `t129_enemy_sweep`): slot 11 appeared one game tick late. Rechecked the specific transition against live NES and Genesis BizHawk captures on 2026-09-28. Current `builds/Debug.md` SHA-256: `276a015a9b6f709bd0b6bb2ab616ae4aa512388ac236a5ce4f4f5a2a8b9faf6a`.

Repro: `python tools/lockstep/run_lockstep.py tools/lockstep/presets/t139_entry.json --frames 145 --full --no-cache`. Captures: `builds/reports/lockstep/t139_entry/nes.ram`, `gen.ram`, `diff.json`, and `run_gen/launch.json`. NES and Genesis runner exit codes were both zero; both captured 145 game ticks. The newly named focused preset has no full-RAM ratchet baseline, so its overall GATE is `FAIL` for 76 pre-existing unmasked cells, mostly initialization/PPU scratch. Its KEY cells have **zero mismatches**. That GATE is not cited as a pass.

| Game tick | Entry | NES slot 11 type/X/Y/state | Genesis slot 11 type/X/Y/state |
|---:|---|---|---|
| 31 | before `$77→$78` | `00/00/00/00` | `00/00/00/00` |
| 32 | `$78` entry | `64/40/A0/00` | `64/40/A0/00` |
| 33 | next tick | `64/40/A0/00` | `64/40/A0/00` |
| 129 | before `$78→$68` | `64/40/A0/00` | `64/40/A0/00` |
| 130 | `$68` entry | `64/20/A0/00` | `64/20/A0/00` |
| 132 | prior reported mismatch tick | `64/20/A0/00` | `64/20/A0/00` |

The entry tick is exact, so the previously observed one-tick lag no longer exists in this build. No production change or broader regression run is warranted. This evidence establishes room-entry type/position/state only; object collision and secret behavior retain separate coverage.
