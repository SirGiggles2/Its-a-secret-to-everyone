# Strict Generated-Only Build Gate

**Master plan reference:** Task 1.11  
**Debate record:** debate-002, Tier-1 GREEN path  
**Status as of 2026-05-02:** Infrastructure wired; gate EXPECTED TO FAIL (see below).  
**Mandatory green by:** Phase 1.10 close.

---

## What the gate enforces

Every file under `data/`, `src/data/`, `src/gen/`, or `RoomRom/data/` that is
compiled into a Genesis ROM is Nintendo-derived — it was extracted or
transpiled from the NES ROM.  These files must **never** be bundled in a
distributable build; they must be reproduced at build time from a
user-supplied NES ROM.

The gate enforces this by:

1. Checking, for each Nintendo-derived source file compiled during the build,
   whether that file is present in (or mentioned by) the manifest at
   `GENERATED_ASSET_ROOT`.
2. If the file is **not** in the manifest, printing `STRICT GATE FAIL: <path>`
   and aborting the build.
3. Collecting all such failures and reporting them as a group so one run
   reveals all missing extractors at once.

In **soft-warning mode** (default, `REQUIRE_GENERATED_ASSETS` unset) the
checks are skipped entirely — the existing checked-in fallback data is
silently accepted and the build succeeds.  This is the normal developer
workflow while Phase 1 extractors are still being written.

---

## When phases must run it

| Milestone | Requirement |
|-----------|-------------|
| Phase 1.10 close | Gate MUST be green (no FAIL lines) for all assets used by Title.md and RoomRom.md. |
| Phase 3–9 task preamble | Do not start a phase if the strict gate is not green for the specific assets that phase consumes. |
| Release packaging (Phase 17) | Gate MUST be green for every Nintendo-derived file in the public package. |
| Recommended per phase close | Run gate and record pass/fail in the phase report; failures are acceptable if the blocking extractor is listed in `docs/audit/extractor_blockers.md`. |

The Tier-1 contracts gate (master plan execution rules) lists Task 1.11 as one
of four contracts that must be green before any feature phase (3+) touches code.

---

## How to invoke locally

### Soft-warning mode (default — runs normally, no gate)

```
build.bat
RoomRom\build.bat
```

### Strict mode — single target

```
set REQUIRE_GENERATED_ASSETS=1
build.bat
```

or

```
set REQUIRE_GENERATED_ASSETS=1
RoomRom\build.bat
```

### Strict mode — both targets via the runner script

```
python tools\builder\strict_build_check.py
```

Options:

```
--title-only    Run Title.md build only.
--roomrom-only  Run RoomRom.md build only.
```

The script exits 0 on green (no FAIL lines), 1 on red.  All `STRICT GATE
FAIL: <path>` lines are collected and printed in a summary at the end.

### With a pre-generated asset root

```
set GENERATED_ASSET_ROOT=C:\path\to\generated
set REQUIRE_GENERATED_ASSETS=1
python tools\builder\strict_build_check.py
```

The checker looks for each file's basename either directly under
`GENERATED_ASSET_ROOT` or inside `GENERATED_ASSET_ROOT\manifest.json`.

---

## How the gate works inside build.bat

`build.bat` and `RoomRom/build.bat` both contain a `GATE_FAIL` variable and a
`:check_generated` subroutine.  The subroutine is called in `if defined
REQUIRE_GENERATED_ASSETS` blocks that guard each Nintendo-derived compile
group.  If any check fails, `GATE_FAIL` is set and the build aborts before the
link step with a single diagnostic block listing the problem.

In soft-warning mode the subroutine is never called (zero overhead).

---

## Known acceptable fallback windows

The following extractors are **not yet written** as of Phase 1 open.  Until
they exist, the gate will fail for the listed files.  Each row records the
planned extractor and the phase that owns it.

| File(s) | Blocking extractor | Owning phase |
|---------|--------------------|--------------|
| `data/intro/*.c` | `tools/builder/extract_intro_assets.py` (exists, covers some files) — full coverage pending | Phase 1.1–1.4 |
| `data/fs/*.c` | `tools/builder/extract_fs_assets.py` (exists, covers some files) — full coverage pending | Phase 1.1–1.4 |
| `data/chr/overworld_bg.c`, `data/chr/underworld_bg.c` | `tools/extract_chr.py` — overworld/underworld BG extraction | Phase 1.3 |
| `data/chr/common.c`, `data/chr/sprites.c` | `tools/extract_chr.py` — sprite CHR extraction | Phase 1.3 |
| `data/rooms/overworld.c`, `data/rooms/dungeons.c` | `tools/extract_rooms.py` — room map extraction | Phase 1.2 |
| `data/misc/palettes.c` | `tools/extract_misc.py` — palette extraction | Phase 1.4 |
| `src/gen/z_01.c` … `src/gen/z_07.c` | `tools/transpile_6502.py` (exists) — transpiler output lives in `src/gen/`; manifest integration pending | Phase 1 |

Once an extractor is complete and writes its outputs into `GENERATED_ASSET_ROOT`
with a matching `manifest.json` entry, the corresponding row should be removed
from this table.

Add new rows to `docs/audit/extractor_blockers.md` (per Task 1.10 policy) for
any file that is still silently served from a checked-in fallback after Phase
1.10 close.

---

## Gate failure anatomy

A failing strict-mode build emits lines like:

```
STRICT GATE FAIL: C:\...\data\chr\common.c
STRICT GATE FAIL: C:\...\data\chr\sprites.c
STRICT GATE FAIL: C:\...\src\gen\z_01.c
...
STRICT GATE FAIL: one or more Nintendo-derived source files are not covered
by the generated manifest at GENERATED_ASSET_ROOT.  Run the Phase 1
extractors first, or unset REQUIRE_GENERATED_ASSETS for soft-warning mode.
```

The runner script (`strict_build_check.py`) collects all per-file FAIL lines
from both targets and prints a deduplicated summary at exit.

---

## CI job

A manual CI job "Strict Builder Gate" should:

1. Set `REQUIRE_GENERATED_ASSETS=1` and `GENERATED_ASSET_ROOT` to the
   pre-populated generated cache directory.
2. Run `python tools\builder\strict_build_check.py`.
3. Fail the job if exit code != 0.

This job is **required green before release packaging** and **recommended
green per phase close** from Phase 3 onward.
