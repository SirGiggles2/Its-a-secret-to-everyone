# Fast test loop — design (2026-09-27)

## Goal

Cut the verify loop (build → NES/Genesis lockstep → byte-diff → verdict)
from minutes to seconds per iteration without weakening RULE V1: the
verdict stays a byte comparison of NES vs Genesis RAM every game tick.

## Measured baseline (2026-09-27)

- `Debug.bat`: 24 s, ~200 C files compiled serially every run, no reuse.
- `run_lockstep.py`: NES capture, then Genesis capture, serially, from
  boot to script end, every run. The NES side is a pure function of
  (NES ROM, preset Lua, capture.lua, BizHawk) and never changes between
  Genesis builds, but is replayed each time.
- t013_route full lockstep 106 s; suite (46 presets, 3 jobs) 338 s on a
  12-core host.
- `diff.py` verdict is DIVERGE on all 46 presets (82–447 cells): load-path
  residue at tick 0 plus real but non-gating differences. The working gate
  was an ad-hoc scratch script (key cells, active slots only). A verdict
  nobody can read as PASS/FAIL is not a gate.

## Design

### 1. NES golden cache (`run_lockstep.py`)

Key = SHA-256 over: NES ROM bytes, generated `preset.lua` text (bot.lua is
inlined into it), `capture.lua` text, `run_probe.py` text, EmuHawk.exe
size + mtime, MAXF. Cache dir `build/lockstep_cache/<key>/` (untracked
build output). Hit: copy every `nes.*` file into the report dir, skip the
NES launch. Miss: run NES, and store only when the run produced `nes.ram`
and no `nes.err`. `--no-cache` forces a fresh NES run. launch.json-style
record `nes.cache` names the key and hit/miss so a verdict states its
NES source.

### 2. One gate, shared by Lua and Python (`tools/lockstep/gate.py`)

- KEY cells (gating, every tick): GameMode $12, submode $13, FrameCounter
  $15, Random $18..$24, RoomId $EB, Link HP $66F/$670, inventory
  $657..$67E, Link invincibility $4F0; per object slot 0..11: X $70+i,
  Y $84+i, dir $98+i; per slot 1..11 type $34F+i. Object cells of slot
  i>0 gate only while that slot's type is nonzero on either console
  (empty-slot leftovers are not game state).
- Padded rows (a Genesis FrameCounter jump that replays skipped NES frames,
  T-137; capture writes their tick numbers to `<OUT>.pad`) are not
  compared: by design they hold the post-jump state.
- `allow` in the preset: `[addr, nes, gen, first_tick, last_tick, "T-###"]`
  — one exact value pair over one tick window, each tied to an open
  tracker row. Nothing broader exists.
- Full-RAM ratchet: every other unmasked cell is compared too. Its set of
  (cell → first diverging tick) is stored per preset in
  `tools/lockstep/baselines/<preset>.json`. A cell NOT in the baseline, or
  diverging earlier than its baseline tick, FAILS. A baseline cell that no
  longer diverges is reported IMPROVED; `diff.py --bless` rewrites the
  baseline (a commit shows every change). Residue burn-down is its own
  tracker row.
- Verdict line: `GATE: PASS|FAIL key=<n cells x ticks> ratchet=<new>/<baseline> allow=<hits>`;
  it says exactly what was checked.

### 3. Fail-fast Genesis capture (`capture.lua`)

Genesis loads the NES golden `nes.ram` (substitution `@GOLD@`) and the
gate tables (emitted into preset.lua by `presets.to_lua` from gate.py —
single source). At each new tick it checks KEY cells against the golden
row. First non-allowed mismatch at tick t: log it, schedule a full video
snapshot at t+1 (screen drawn from t on), set total = t+30, stop there.
The runner then reruns the NES (cached per key incl. snap) only up to
t+2 with the same snapshot, so NES OAM/PAL/CHR/NT and Genesis
VRAM/CRAM/VSRAM of the failing tick exist without a manual re-drive.
`--full` disables fail-fast (milestone evidence, bot route merges).

### 4. Parallel suite (`run_suite.py`)

Default jobs = cpu_count − 2 (10 here). Presets start longest-first
(previous run's tick count) so the tail is short. Suite output = one
GATE line per preset + totals; exit 1 on any FAIL.

### 5. Incremental parallel build (`build_debug.py`)

C compiles run in a thread pool (cpu_count jobs). Each object is reused
when its `.d` depfile (`-MMD`) shows no newer input and its flag stamp
matches. `Debug.bat` stays the only build; a clean build is the same
command after deleting `build/debug_project/out`.

### 6. Route segments — dropped (measured)

With the NES cached, the full t013_route (7768 ticks) runs on the
Genesis in 20 s, and fail-fast reaches its first mismatch in 5 s.
Splitting routes into card-started segments would save seconds at the
cost of staging; not built.

### 7. Deterministic capture start (found during rollout)

EmuHawk runs a load-dependent number of frames before the Lua script
attaches (one parallel batch gave FrameCounter $2D instead of $2C at
sync). capture.lua now reboots the core and runs exactly one input-free
frame, the attach timing every recorded route was built with.

### 8. Presets on the play clock (found during rollout)

Tick-clock presets misaligned after any load the Genesis finishes in
fewer ticks. All but save_roundtrip were converted exactly: an old
tick's input is kept iff that tick started in play; stage ticks are
remapped. Proof: every NES golden is byte-identical to the old capture
mapped to play ticks.

## Results (2026-09-27)

| | before | after |
|---|---|---|
| Debug.bat | 24 s | 12 s clean, 9 s no change (ROM SHA identical) |
| t013_route to first mismatch | 106 s | 5 s |
| t013_route full | 106 s | 20 s |
| suite (46 presets) | 338 s, all DIVERGE | 60 s, 30/46 PASS + 16 real failures as tracker rows |

## Test levels

| When | Command | Scope |
|---|---|---|
| every edit | `run_suite.py <tag> --only <presets>` | touched presets, fail-fast |
| every commit | `run_suite.py <tag>` | all presets, fail-fast, cached NES |
| milestone | `run_lockstep.py <route> --full` | connected routes, full captures |

## Verification of the change itself

- Gate calibrated offline first against the saved t013b suite output
  (same bytes, no emulator): must reproduce the known t013 findings
  (tick 7726 GameMode 5/6, ticks 63–79 fire ObjDir) and nothing else.
- Cache: two runs of one preset — second is a hit; `nes.*` byte-identical
  to the miss run.
- Fail-fast: a preset with a deliberately wrong allow window must stop at
  the expected tick with both snapshots written.
- Before/after timings recorded in the tracker handoff.
- capture.lua changes reviewed before running (RULE V2).
