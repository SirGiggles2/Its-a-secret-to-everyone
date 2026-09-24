# Dungeon scenario runner

Runs selected probes in a separate BizHawk process and records a fresh result
under builds/reports/dungeon_harness/L<level>Q<quest>-<run-id>/.

## Current verified scope

L1Q1 supports an **ENTRY_ONLY** scenario: boot, debug chord, synthetic room
warp, verify room/level/quest and an advancing gameplay counter, screenshot,
and savestate. This does not prove ordinary dungeon entry, combat, reward
collection, or quest completion.

Legacy dungeon probes are still load-only scaffolds. Completion mode refuses
them until their state is pinned to the current ROM and their probe explicitly
implements the completion contract. Other rows are populated as needed.

## Run

PowerShell, from the repository root:

~~~powershell
$env:BIZHAWK_EXE = 'C:\path\to\BizHawk\EmuHawk.exe'
python tools/dungeon_harness/run_all.py --level 1 --quest 1 --entry-only
python tools/dungeon_harness/run_all.py --level 1 --quest 1 --dry-run
~~~

Use --rom to choose a local output, --emuhawk instead of the environment
variable, and --timeout to set a positive per-scenario wall-clock limit
(default 120 seconds).

The second command checks completion inputs only. Missing/unpinned states are
ERROR, including with --dry-run. DRY_OK never means gameplay passed.

Exit codes: 0 = selected scope succeeded (ENTRY_ONLY, PASS or DRY_OK);
1 = scenario FAIL; 2 = setup/report ERROR. Read the named scope, not just exit 0.

## Result contract

The runner provides HARNESS to Lua and loads report.lua. A probe calls
HARNESS.finish(verdict, fields). The envelope binds run_id, ROM SHA256, level,
quest and scope; result.json includes accepted data and a scope note.

- entry requires ENTRY_ONLY and matching room/level/quest plus positive frame_delta.
- completion requires PASS and explicit entered, boss_killed and reward_collected
  events. The implementing probe must observe these events from actual gameplay;
  injecting completion flags is not evidence.
- FAIL and ERROR remain unsuccessful.
- Missing/old reports, mismatched identity/scope and unfinished legacy results
  cannot satisfy a run.

Completion rows require save_state_sha256, state_rom_sha256 and
probe_scope: completion. A current-ROM entry snapshot is a useful setup asset,
not a completed dungeon. Never transplant an old-build Genesis savestate into
changed code without validating/recreating it.

## Isolation and diagnostics

The runner copies the installation's working config into private temporary
staging, disables auto-loading and audio output, isolates SRAM/state/screenshot
paths, and starts a hidden owned process. It uses GDI and full Windows short
paths for CLI arguments. Install BizHawk/ROM in a space-free path if 8.3 paths
are unavailable. It never kills all emulator processes.

context.json, launch.json, emuhawk.log, probe.json and result.json describe the
run. Successful entry captures include entry.png, title.png and entry.State.
Temporary staging is retained for failure diagnosis; its path is in launch.json
after normal exit. Missing reports/timeouts are errors, not automatic retries.

The config and Lua CLI switches are documented in the
[upstream argument parser](https://github.com/TASEmulators/BizHawk/blob/master/src/BizHawk.Client.Common/ArgParser.cs).
This runner was exercised with BizHawk 2.11 / GPGX.

## Focused contract checks

~~~powershell
python -m unittest discover -s tools/dungeon_harness -p test_run_all.py -v
~~~

These check stale identity, missing state, entry/completion separation, and
required completion events. Do not run all dungeon probes for a local fix.
