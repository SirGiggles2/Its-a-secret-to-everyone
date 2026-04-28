# S0 — Inventory + Guardrails Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the audit documents, ABI proof, lint guardrail, and locked Reference Contract values that gate S1 of the Native Genesis Rewrite spec. No source code is moved or rewritten in S0; only inventory, probes, and spec updates.

**Architecture:** Generate everything via Python scripts in `tools/probes/` whose outputs are committed under `docs/audit/`. Hook the legacy-symbol lint into `build.bat` as warning-only. Use the existing toolchain (m68k-elf-gcc from SGDK, vasmm68k_mot, Python 3.12+) to build a tiny ABI probe whose listing is inspected to fill Section 4.5 placeholders. Update the design spec inline as values become known.

**Tech Stack:** Python 3.12+, m68k-elf-gcc (SGDK), vasmm68k_mot, BizHawk 2.11, Windows batch build.

**Reference spec:** [docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md](../specs/2026-04-27-native-genesis-rewrite-design.md)

---

## File Structure

**Created:**

- `tools/probes/__init__.py` — empty marker for package
- `tools/probes/_common.py` — shared helpers (path roots, file scanning, classifier rules)
- `tools/probes/snapshot_repo_tree.py` — produces `docs/audit/repo_tree.txt`
- `tools/probes/scan_legacy_callers.py` — produces `docs/audit/legacy_callers.md`
- `tools/probes/scan_frontend_deps.py` — produces `docs/audit/frontend_deps.md`
- `tools/probes/scan_build_order.py` — produces `docs/audit/build_order.md`
- `tools/probes/classify_files.py` — produces `docs/audit/file_classification.md`
- `tools/probes/scan_redux_touchpoints.py` — produces `docs/audit/redux_touchpoints.md`
- `tools/probes/lint_legacy_symbols.py` — warning-only lint, hooks into build.bat
- `tools/probes/abi_probe.c` — ABI smoke test
- `tools/probes/abi_probe.build.bat` — standalone build script for the probe (uses m68k-elf-gcc)
- `tools/probes/locate_reference_rom.py` — NES ROM resolver with SHA256 verify
- `tools/probes/test_lint_legacy_symbols.py` — unit test for the lint
- `tools/probes/test_classify_files.py` — unit test for the classifier
- `docs/audit/repo_tree.txt`
- `docs/audit/legacy_callers.md`
- `docs/audit/frontend_deps.md`
- `docs/audit/build_order.md`
- `docs/audit/file_classification.md`
- `docs/audit/redux_touchpoints.md`
- `docs/audit/sram_map.md`
- `docs/audit/abi_probe.md`
- `docs/audit/s0_close.md` — final summary, links audit artifacts and resolved Section 12 questions
- `docs/audit/README.md` — short index of what each audit doc contains

**Modified:**

- `build.bat` — add post-build call to `lint_legacy_symbols.py` (warn-only)
- `.gitignore` — ensure NES ROM never gets committed
- `docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md` — fill Section 0 + Section 4.5 placeholders, reduce Section 12 to "None" or a residual list

---

## Task 1: Bootstrap audit infrastructure

**Files:**

- Create: `tools/probes/__init__.py`
- Create: `tools/probes/_common.py`
- Create: `docs/audit/README.md`

- [ ] **Step 1: Create empty package marker**

```python
# tools/probes/__init__.py
"""S0 audit + lint probes.

Each module in this package is invoked from the command line and writes its
output under docs/audit/. Modules share helpers via _common.py.
"""
```

- [ ] **Step 2: Create shared helpers module**

```python
# tools/probes/_common.py
"""Shared helpers for S0 audit probes."""

from __future__ import annotations

import hashlib
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SRC = REPO_ROOT / "src"
DOCS_AUDIT = REPO_ROOT / "docs" / "audit"
TOOLS_PROBES = REPO_ROOT / "tools" / "probes"


def iter_source_files(extensions: tuple[str, ...] = (".c", ".h", ".asm", ".inc")) -> list[Path]:
    """Return every source file under src/, sorted, excluding *.bak and copies."""
    out: list[Path] = []
    for path in SRC.rglob("*"):
        if not path.is_file():
            continue
        name = path.name
        if name.endswith(".bak") or " - Copy" in name or name.endswith(".txt"):
            continue
        if path.suffix in extensions:
            out.append(path)
    out.sort()
    return out


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(64 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def write_audit(filename: str, contents: str) -> Path:
    """Write a file under docs/audit/, creating the directory if needed."""
    DOCS_AUDIT.mkdir(parents=True, exist_ok=True)
    out = DOCS_AUDIT / filename
    out.write_text(contents, encoding="utf-8")
    return out


def relative_to_repo(path: Path) -> str:
    return str(path.relative_to(REPO_ROOT)).replace(os.sep, "/")
```

- [ ] **Step 3: Create audit index README**

```markdown
<!-- docs/audit/README.md -->
# S0 Audit Artifacts

Each file is generated by a script under `tools/probes/`. Regenerate via the
matching script; do not hand-edit.

| File | Generator | Purpose |
|---|---|---|
| `repo_tree.txt` | `snapshot_repo_tree.py` | Current source tree snapshot |
| `legacy_callers.md` | `scan_legacy_callers.py` | Every call site of legacy shim and z01_*..z07_* symbols |
| `frontend_deps.md` | `scan_frontend_deps.py` | Frontend (intro/FS/title) include + extern graph |
| `build_order.md` | `scan_build_order.py` | Compile/link order, exported symbols per .o |
| `file_classification.md` | `classify_files.py` | Per-file role classification |
| `redux_touchpoints.md` | `scan_redux_touchpoints.py` | Redux feature inventory + flag mapping |
| `sram_map.md` | hand-written | Locked SRAM byte ranges (save slots + OptionsState) |
| `abi_probe.md` | hand-recorded from `abi_probe.c` listing | Compiler ABI proof |
| `s0_close.md` | hand-written | S0 close-out summary, resolved Section 12 questions |
```

- [ ] **Step 4: Verify directory structure**

Run: `ls tools/probes/ docs/audit/`
Expected: shows the three created files.

- [ ] **Step 5: Commit**

```bash
git add tools/probes/__init__.py tools/probes/_common.py docs/audit/README.md
git commit -m "s0: bootstrap audit + probes infrastructure"
```

---

## Task 2: Snapshot current repo tree

**Files:**

- Create: `tools/probes/snapshot_repo_tree.py`
- Create (output): `docs/audit/repo_tree.txt`

- [ ] **Step 1: Write the snapshot script**

```python
# tools/probes/snapshot_repo_tree.py
"""Generate docs/audit/repo_tree.txt — sorted file list under src/."""

from __future__ import annotations

import sys
from pathlib import Path

from _common import REPO_ROOT, SRC, write_audit, relative_to_repo


def main() -> int:
    lines: list[str] = ["# Repository source tree snapshot", ""]
    lines.append(f"Root: `{relative_to_repo(REPO_ROOT)}/`")
    lines.append("")
    lines.append("```")

    paths = sorted(p for p in SRC.rglob("*") if p.is_file())
    for path in paths:
        lines.append(relative_to_repo(path))

    lines.append("```")
    lines.append("")
    lines.append(f"Total files: {len(paths)}")

    out = write_audit("repo_tree.txt", "\n".join(lines) + "\n")
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run the script**

Run: `cd tools/probes && python snapshot_repo_tree.py`
Expected output: `wrote <repo>/docs/audit/repo_tree.txt`

- [ ] **Step 3: Verify the output exists and is non-empty**

Run: `wc -l docs/audit/repo_tree.txt`
Expected: > 100 lines (the codebase has ~123 files in src/).

- [ ] **Step 4: Commit**

```bash
git add tools/probes/snapshot_repo_tree.py docs/audit/repo_tree.txt
git commit -m "s0: snapshot repo source tree"
```

---

## Task 3: Identify build toolchain (toolchain inventory)

**Files:**

- Modify: `docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md` (Section 4.5 toolchain placeholders)
- Create: `docs/audit/toolchain.md`

- [ ] **Step 1: Resolve `vasmm68k_mot.exe` location and version**

Run: locate the binary using the same logic build.bat uses, then run it without args.

```bash
# From repo root
"$VASM_PATH" 2>&1 | head -3
```

Expected: a banner line like `vasm 1.9c (c) ... Volker Barthelmann ... m68k cpu module 2.x ... motorola syntax module 4.x`. Record the exact version strings.

- [ ] **Step 2: Resolve `m68k-elf-gcc` location and version**

Run:

```bash
"$M68K_BIN/gcc.exe" --version
```

Expected: a line like `m68k-elf-gcc.exe (GCC) X.Y.Z`. Record the version.

Also run:

```bash
"$M68K_BIN/ld.exe" --version | head -1
"$M68K_BIN/objcopy.exe" --version | head -1
```

Record both.

- [ ] **Step 3: Resolve Python version**

Run: `python --version` (or whichever Python `build.bat` resolves to).
Record.

- [ ] **Step 4: Write toolchain audit doc**

Create `docs/audit/toolchain.md` with a markdown table containing:

```markdown
# Toolchain Inventory (locked at S0)

| Tool | Path resolution rule | Resolved version |
|---|---|---|
| `vasmm68k_mot.exe` | `build.bat` Locate vasmm68k_mot block | <recorded> |
| `m68k-elf-gcc.exe` | `build/toolchain/sgdk_bin/bin/gcc.exe` | <recorded> |
| `m68k-elf-ld.exe`  | same dir | <recorded> |
| `m68k-elf-objcopy.exe` | same dir | <recorded> |
| `python` | `build.bat` Locate Python block | <recorded> |
| BizHawk (NES core) | <see Reference Contract> | filled in Task 6 |
| BizHawk (Genesis core) | <see Reference Contract> | filled in Task 6 |

## Notes

- vasmm68k uses **Motorola syntax** (`vasmm68k_mot`), not Mit/GAS.
- m68k-elf-gcc is the SGDK 1.x distribution (`build/toolchain/sgdk_bin/`).
- The `-fcall-saved-a4` flag in `build.bat` enforces the existing A4 = NES_RAM
  base contract; that flag will be reviewed during the RAM-convention migration
  but stays untouched in S0.
```

- [ ] **Step 5: Update spec Section 4.5 toolchain placeholders**

Open `docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md`. In Section 4.5 (ABI Contract), replace the toolchain `<filled at S0>` markers with the recorded versions, e.g. `m68k-elf-gcc.exe (GCC) 6.3.0` (use whatever version was recorded).

- [ ] **Step 6: Commit**

```bash
git add docs/audit/toolchain.md docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md
git commit -m "s0: lock toolchain versions in spec"
```

---

## Task 4: NES reference ROM resolver + SHA256 lock

**Files:**

- Create: `tools/probes/locate_reference_rom.py`
- Create: `tools/probes/test_locate_reference_rom.py`
- Modify: `.gitignore`
- Modify: `docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md` (Section 0 NES ROM SHA256)

- [ ] **Step 1: Verify NES ROM is not currently committed**

Run:

```bash
git ls-files | grep -iE "\.nes$"
```

Expected: empty (no NES ROM in git).

- [ ] **Step 2: Add ROM extension to `.gitignore` if missing**

Open `.gitignore`. If `*.nes` (or the specific filename) is not already excluded, add this section:

```
# Reference ROMs — never committed
*.nes
*.NES
reference/*.nes
```

- [ ] **Step 3: Write the test for the resolver**

```python
# tools/probes/test_locate_reference_rom.py
"""Tests for locate_reference_rom.py."""

import hashlib
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from locate_reference_rom import resolve_rom, RomNotFoundError, RomHashMismatchError


def test_resolves_via_env_var(tmp_path: Path, monkeypatch) -> None:
    fake = tmp_path / "rom.nes"
    fake.write_bytes(b"hello")
    expected = hashlib.sha256(b"hello").hexdigest()
    monkeypatch.setenv("ZELDA_NES_ROM", str(fake))
    out = resolve_rom(expected_sha256=expected)
    assert out == fake


def test_raises_on_missing(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setenv("ZELDA_NES_ROM", str(tmp_path / "no_such.nes"))
    with pytest.raises(RomNotFoundError):
        resolve_rom(expected_sha256="0" * 64)


def test_raises_on_hash_mismatch(tmp_path: Path, monkeypatch) -> None:
    fake = tmp_path / "rom.nes"
    fake.write_bytes(b"hello")
    monkeypatch.setenv("ZELDA_NES_ROM", str(fake))
    with pytest.raises(RomHashMismatchError):
        resolve_rom(expected_sha256="0" * 64)
```

- [ ] **Step 4: Run test to verify it fails (module doesn't exist yet)**

Run: `cd tools/probes && python -m pytest test_locate_reference_rom.py -v`
Expected: ImportError or collection error.

- [ ] **Step 5: Implement the resolver**

```python
# tools/probes/locate_reference_rom.py
"""Resolve NES reference ROM via local config or env var, verify SHA256.

The ROM is never committed to the repository. Probes call resolve_rom() with
the expected SHA256 (locked in the design spec) before any extraction.
"""

from __future__ import annotations

import hashlib
import os
from pathlib import Path

ENV_VAR = "ZELDA_NES_ROM"


class RomNotFoundError(FileNotFoundError):
    pass


class RomHashMismatchError(ValueError):
    pass


def resolve_rom(expected_sha256: str) -> Path:
    """Return the NES ROM path. Raises if missing or if hash mismatches."""
    raw = os.environ.get(ENV_VAR)
    if not raw:
        raise RomNotFoundError(
            f"Set {ENV_VAR} to the path of Legend of Zelda, The (USA).nes"
        )
    path = Path(raw)
    if not path.is_file():
        raise RomNotFoundError(f"{ENV_VAR}={raw} does not point to a file")

    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(64 * 1024), b""):
            h.update(chunk)
    actual = h.hexdigest()
    if actual.lower() != expected_sha256.lower():
        raise RomHashMismatchError(
            f"NES ROM hash mismatch: expected {expected_sha256}, got {actual}"
        )
    return path


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <expected-sha256>", file=sys.stderr)
        sys.exit(2)
    try:
        path = resolve_rom(sys.argv[1])
    except (RomNotFoundError, RomHashMismatchError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    print(path)
```

- [ ] **Step 6: Run tests, expect pass**

Run: `cd tools/probes && python -m pytest test_locate_reference_rom.py -v`
Expected: 3 passed.

- [ ] **Step 7: Compute the actual NES ROM SHA256**

User must point `ZELDA_NES_ROM` at their local copy of `Legend of Zelda, The (USA).nes`, then:

```bash
python -c "import hashlib,os,sys; p=os.environ['ZELDA_NES_ROM']; h=hashlib.sha256(open(p,'rb').read()).hexdigest(); print(h)"
```

Record the printed hash. The expected canonical USA-release hash is widely documented; cross-reference with any known good source before locking.

- [ ] **Step 8: Update spec Section 0 with the recorded hash**

In Section 0, replace the `<filled at S0 — Legend of Zelda, The (USA).nes>` placeholder with the actual SHA256.

- [ ] **Step 9: Commit**

```bash
git add tools/probes/locate_reference_rom.py tools/probes/test_locate_reference_rom.py .gitignore docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md
git commit -m "s0: NES ROM resolver with SHA256 verify; lock ROM hash in spec"
```

---

## Task 5: Snapshot current Genesis baseline ROM

**Files:**

- Modify: `docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md` (Section 0 baseline ROM SHA256)
- Create: `docs/audit/baseline_rom.md`

- [ ] **Step 1: Run a fresh build to ensure baseline reproducibility**

Run: `build.bat`
Expected: a `builds/whatif.md` (or current ROM artifact) is produced without errors. If errors occur, fix or escalate before continuing — S0 acceptance requires the current build still works.

- [ ] **Step 2: Compute SHA256 of the produced ROM**

Run:

```bash
python -c "import hashlib; print(hashlib.sha256(open('builds/whatif.md','rb').read()).hexdigest())"
```

Record the hash.

- [ ] **Step 3: Write baseline audit doc**

```markdown
<!-- docs/audit/baseline_rom.md -->
# Baseline Genesis ROM (locked at S0)

| Field | Value |
|---|---|
| Path | `builds/whatif.md` |
| SHA256 | `<recorded hash>` |
| Build date | `<UTC timestamp>` |
| Commit | `<git rev-parse HEAD>` |

This is the **FINAL TRY known-good ROM** referenced by the design spec
(Section 0). All Genesis-vs-Genesis logical parity checks in S1 diff against
captures from this exact ROM.

WHAT IF builds are **not** the parity baseline.
```

Run `git rev-parse HEAD` to fill the commit field.

- [ ] **Step 4: Update spec Section 0**

Replace the `<filled at S0 — current FINAL TRY known-good ROM>` placeholder with the recorded SHA256.

- [ ] **Step 5: Commit**

```bash
git add docs/audit/baseline_rom.md docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md
git commit -m "s0: lock baseline Genesis ROM SHA256"
```

---

## Task 6: Identify emulator versions and palette

**Files:**

- Modify: `docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md` (Section 0 emulator + palette)
- Create: `docs/audit/emulators.md`

- [ ] **Step 1: Identify BizHawk version present on this system**

Run BizHawk once and record:

- BizHawk overall version (e.g. `2.11.0`)
- NES core in use (typically `NesHawk` or `QuickNES`) and its version string
- Genesis core in use (typically `Gambatte`/`Genplus-gx`) and its version string
- The active NES palette name (`Help → About` or core settings; record the palette display name)

- [ ] **Step 2: Write emulator audit doc**

```markdown
<!-- docs/audit/emulators.md -->
# Emulator Versions (locked at S0)

| Field | Value |
|---|---|
| BizHawk version | `<recorded>` |
| NES core | `<recorded core name + version>` |
| Genesis core | `<recorded core name + version>` |
| NES palette | `<recorded palette name>` |

Probes invoke BizHawk via the cmd.exe pattern documented in the
`bizhawkScript` skill (memory: `skill_bizhawk_script.md`).
```

- [ ] **Step 3: Update spec Section 0**

Replace the four emulator/palette placeholders with the recorded values.

- [ ] **Step 4: Commit**

```bash
git add docs/audit/emulators.md docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md
git commit -m "s0: lock emulator versions and NES palette"
```

---

## Task 7: Lock viewport and capture geometry

**Files:**

- Modify: `docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md` (Section 0 capture geometry)
- Create: `docs/audit/capture_geometry.md`

- [ ] **Step 1: Decide H32 vs H40 mode**

Inspect the current ROM's VDP register-1 init in `genesis_shell.asm` (and any current `vdp_init` paths). Record whether the project is using H32 (256-pixel) or H40 (320-pixel) display mode.

Run: `grep -n "h40\|H40\|h32\|H32\|\$8C" src/genesis_shell.asm` to find the relevant register write.

- [ ] **Step 2: Decide viewport, crop, overscan, backdrop policy**

Record the values to be used for **all** RGB parity captures:

- Viewport size in pixels (typically `256x224` for NES-aligned H32 with 28 visible rows)
- Crop origin (top-left pixel relative to full-frame BizHawk capture)
- Overscan policy: ignored or included (simpler: ignored)
- Backdrop / transparent color: NES backdrop `$3F00` mapped to a fixed Genesis CRAM index recorded here

- [ ] **Step 3: Write capture geometry audit doc**

```markdown
<!-- docs/audit/capture_geometry.md -->
# Capture Geometry (locked at S0)

| Field | Value |
|---|---|
| Genesis display mode | H32 / H40 — `<recorded>` |
| RGB viewport size (px) | `<recorded, e.g. 256x224>` |
| Crop origin (top-left in BizHawk full frame) | `<recorded x,y>` |
| Overscan policy | ignored / included — `<recorded>` |
| Backdrop CRAM mapping | `<recorded NES $3F00 → Genesis CRAM index>` |
| Screenshot scaling | none (1:1) |

These values are inputs to `tools/probes/diff_capture.py` and any RGB-parity
probe added in S1+. Changing any of them requires a spec amendment and a
re-baseline of every stored capture under `builds/reports/`.
```

- [ ] **Step 4: Update spec Section 0**

Replace the five capture-geometry placeholders.

- [ ] **Step 5: Commit**

```bash
git add docs/audit/capture_geometry.md docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md
git commit -m "s0: lock capture geometry and viewport policy"
```

---

## Task 8: Build ABI probe

**Files:**

- Create: `tools/probes/abi_probe.c`
- Create: `tools/probes/abi_probe.build.bat`
- Create: `docs/audit/abi_probe.md`
- Modify: `docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md` (Section 4.5 calling convention placeholders)

- [ ] **Step 1: Write the probe source**

```c
/* tools/probes/abi_probe.c
 *
 * S0 ABI proof. Compile with the SAME flags build.bat uses for src/*.c
 * (especially -fcall-saved-a4) and inspect the listing to record:
 *   - return-value register usage for u32 vs pointer
 *   - argument-passing for mixed (u16, u32, void*) signatures
 *   - callee-saved register set actually emitted
 */

typedef unsigned int   u32;
typedef unsigned short u16;
typedef unsigned char  u8;

/* Force out-of-line by putting in its own translation unit and avoiding inline. */
__attribute__((noinline)) u32 abi_ret_u32(void) {
    return 0xDEADBEEFu;
}

__attribute__((noinline)) void *abi_ret_ptr(void) {
    return (void *)0xC0FFEE00u;
}

__attribute__((noinline)) u32 abi_arg_mix(u16 a, u32 b, void *p) {
    return (u32)a + b + (u32)(unsigned long)p;
}

/* Reference all three so the compiler emits them. */
u32 (*const abi_probe_table[3])(void) = {
    (u32 (*)(void))abi_ret_u32,
    (u32 (*)(void))abi_ret_ptr,
    (u32 (*)(void))abi_arg_mix,
};
```

- [ ] **Step 2: Write the standalone build script**

```bat
@echo off
rem tools/probes/abi_probe.build.bat — compile the ABI probe and emit a listing.
rem Mirrors the flags build.bat uses for src/*.c.
setlocal EnableExtensions

for %%I in ("%~dp0..\..") do set "ROOT=%%~fI"
set "M68K_BIN=%ROOT%\build\toolchain\sgdk_bin\bin"
set "GCC=%M68K_BIN%\gcc.exe"
set "OUT=%ROOT%\builds\abi_probe"

if not exist "%GCC%" (
    echo ERROR: m68k-elf-gcc not found at %GCC%
    exit /b 1
)

if not exist "%OUT%" mkdir "%OUT%"

echo [1/2] Compiling abi_probe.c with -S to produce assembly listing...
"%GCC%" -B "%M68K_BIN%\\" -m68000 -fcall-saved-a4 -O1 -S ^
    "%~dp0abi_probe.c" -o "%OUT%\abi_probe.s"
if errorlevel 1 exit /b 1

echo [2/2] Compiling abi_probe.c to .o and dumping with objdump...
"%GCC%" -B "%M68K_BIN%\\" -m68000 -fcall-saved-a4 -O1 -c ^
    "%~dp0abi_probe.c" -o "%OUT%\abi_probe.o"
if errorlevel 1 exit /b 1

"%M68K_BIN%\objdump.exe" -d "%OUT%\abi_probe.o" > "%OUT%\abi_probe.disasm.txt"

echo Listing:  %OUT%\abi_probe.s
echo Disasm:   %OUT%\abi_probe.disasm.txt
exit /b 0
```

- [ ] **Step 3: Run the probe build**

Run: `tools\probes\abi_probe.build.bat`
Expected: produces `builds/abi_probe/abi_probe.s` and `builds/abi_probe/abi_probe.disasm.txt`. No errors.

- [ ] **Step 4: Inspect the listing for register usage**

Open `builds/abi_probe/abi_probe.s`. Record:

- For `abi_ret_u32`: which register holds `#0xDEADBEEF` at exit? (Expect D0.)
- For `abi_ret_ptr`: which register holds the pointer at exit? (D0 or A0 — record exactly.)
- For `abi_arg_mix`:
  - Where is `a` (u16) on entry? (likely on the stack, sign-/zero-extended)
  - Where is `b` (u32) on entry?
  - Where is `p` (void *) on entry?
  - Which registers does the function clobber besides D0?
- Look for `movem.l ...,-(sp)` at function entry to identify callee-saved registers actually preserved.

- [ ] **Step 5: Write `docs/audit/abi_probe.md`**

```markdown
<!-- docs/audit/abi_probe.md -->
# ABI Probe Results (locked at S0)

Source: `tools/probes/abi_probe.c`
Listing: `builds/abi_probe/abi_probe.s`
Disasm:  `builds/abi_probe/abi_probe.disasm.txt`
Compiler flags: `-m68000 -fcall-saved-a4 -O1`

## Return registers

| Function | Return register | Notes |
|---|---|---|
| `u32 abi_ret_u32(void)` | `<D0 / A0>` | <recorded> |
| `void *abi_ret_ptr(void)` | `<D0 / A0>` | <recorded> |

## Argument passing — `u32 abi_arg_mix(u16 a, u32 b, void *p)`

| Param | Type | Location on entry |
|---|---|---|
| `a` | u16 | <recorded — stack offset / register> |
| `b` | u32 | <recorded> |
| `p` | void * | <recorded> |

## Callee-saved set (from MOVEM at entry)

`<recorded list, e.g. D2-D7/A2-A6>`

## Caller-saved set (proven by clobber)

`<recorded — typically D0,D1,A0,A1>`

## Struct return policy

Aggregates are forbidden in C↔asm signatures (spec rule). Probe does not
exercise struct returns; the rule stands by spec, not by probe.

## A4 contract

`-fcall-saved-a4` is in effect: A4 is treated as callee-saved by GCC. This
matches the existing NES_RAM-base contract and is preserved through cutover.
```

- [ ] **Step 6: Update spec Section 4.5**

Replace the calling-convention `<filled at S0>` markers with the recorded values, and remove the "unless compiler convention dictates otherwise" wording (already removed in spec round 3, verify).

- [ ] **Step 7: Commit**

```bash
git add tools/probes/abi_probe.c tools/probes/abi_probe.build.bat docs/audit/abi_probe.md docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md
git commit -m "s0: ABI probe + listing recorded; lock calling convention"
```

---

## Task 9: Build legacy symbol scanner

**Files:**

- Create: `tools/probes/scan_legacy_callers.py`
- Create (output): `docs/audit/legacy_callers.md`

- [ ] **Step 1: Write the scanner**

```python
# tools/probes/scan_legacy_callers.py
"""Generate docs/audit/legacy_callers.md.

Reports every call site of the legacy shim and transpiled-bank symbols that
S1+ stages must drain or replace:

  _ppu_*, _oam_*, _apu_*, _ctrl_*, _mmc1_*
  z00_*, z01_*, z02_*, z03_*, z04_*, z05_*, z06_*, z07_*

Output is grouped by symbol family with file:line references.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

from _common import SRC, write_audit, relative_to_repo

FAMILIES: list[tuple[str, re.Pattern]] = [
    ("_ppu_*",   re.compile(r"\b_ppu_[A-Za-z0-9_]+")),
    ("_oam_*",   re.compile(r"\b_oam_[A-Za-z0-9_]+")),
    ("_apu_*",   re.compile(r"\b_apu_[A-Za-z0-9_]+")),
    ("_ctrl_*",  re.compile(r"\b_ctrl_[A-Za-z0-9_]+")),
    ("_mmc1_*",  re.compile(r"\b_mmc1_[A-Za-z0-9_]+")),
    ("z01_*",    re.compile(r"\bz01_[A-Za-z0-9_]+")),
    ("z02_*",    re.compile(r"\bz02_[A-Za-z0-9_]+")),
    ("z03_*",    re.compile(r"\bz03_[A-Za-z0-9_]+")),
    ("z04_*",    re.compile(r"\bz04_[A-Za-z0-9_]+")),
    ("z05_*",    re.compile(r"\bz05_[A-Za-z0-9_]+")),
    ("z06_*",    re.compile(r"\bz06_[A-Za-z0-9_]+")),
    ("z07_*",    re.compile(r"\bz07_[A-Za-z0-9_]+")),
]

# Skip files that are themselves the source of truth for these symbols.
SKIP_FILES = {
    "src/zelda_translated",        # transpiled bank source
    "src/gen/z_",                  # transpile adapters
    "src/nes_io.asm",              # shim definitions
    "src/c_shims.asm",             # shim definitions
    "src/genesis_shell.asm",       # boot/IO definitions
}


def is_skipped(rel: str) -> bool:
    return any(rel.startswith(s) or s in rel for s in SKIP_FILES)


def main() -> int:
    hits: dict[str, list[tuple[str, int, str, str]]] = defaultdict(list)

    for path in sorted(SRC.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix not in (".c", ".h", ".asm", ".inc"):
            continue
        rel = relative_to_repo(path)
        if is_skipped(rel):
            continue

        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        for lineno, line in enumerate(text.splitlines(), start=1):
            stripped = line.strip()
            if not stripped or stripped.startswith(("/*", "*", "//", ";", "#")):
                # Still scan — comments mentioning symbols are also signal.
                pass
            for family, pat in FAMILIES:
                for m in pat.finditer(line):
                    hits[family].append((rel, lineno, m.group(0), stripped[:120]))

    lines: list[str] = ["# Legacy Symbol Caller Report", ""]
    lines.append("Generated by `tools/probes/scan_legacy_callers.py`. Regenerate after every drain.")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append("| Family | Call sites |")
    lines.append("|---|---|")
    for family, _ in FAMILIES:
        lines.append(f"| `{family}` | {len(hits[family])} |")
    lines.append("")

    for family, _ in FAMILIES:
        lines.append(f"## `{family}`")
        lines.append("")
        if not hits[family]:
            lines.append("_No callers._")
            lines.append("")
            continue
        for rel, lineno, sym, snippet in hits[family]:
            lines.append(f"- `{rel}:{lineno}` — `{sym}` — `{snippet}`")
        lines.append("")

    out = write_audit("legacy_callers.md", "\n".join(lines) + "\n")
    print(f"wrote {out}")
    print(f"total call sites: {sum(len(v) for v in hits.values())}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run the scanner**

Run: `cd tools/probes && python scan_legacy_callers.py`
Expected: writes `docs/audit/legacy_callers.md`. Total call site count printed; cross-check against earlier ad-hoc grep (~282 hits across 7 z-bank files plus shim families).

- [ ] **Step 3: Verify the report has non-empty sections**

Run: `grep -c "^- \`" docs/audit/legacy_callers.md`
Expected: > 50 (representative subset of ~282 across non-skipped files).

- [ ] **Step 4: Commit**

```bash
git add tools/probes/scan_legacy_callers.py docs/audit/legacy_callers.md
git commit -m "s0: legacy symbol caller report"
```

---

## Task 10: Build frontend dependency scanner

**Files:**

- Create: `tools/probes/scan_frontend_deps.py`
- Create (output): `docs/audit/frontend_deps.md`

- [ ] **Step 1: Write the scanner**

```python
# tools/probes/scan_frontend_deps.py
"""Generate docs/audit/frontend_deps.md.

For every file under src/ whose name matches frontend prefixes (intro_*, fs_*,
frontend_*, intro/, fs/), report:

  - all #include directives
  - all extern function/data declarations consumed
  - all VDP-direct register writes (VDP_DATA / VDP_CTRL_WORD / 0xC00000)

This is the input to S1's frontend re-pointing onto the new render API.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from _common import SRC, write_audit, relative_to_repo

FRONTEND_NAME = re.compile(r"^(intro|fs|frontend)_", re.IGNORECASE)

INCLUDE = re.compile(r'^\s*#\s*include\s+["<]([^">]+)[">]')
EXTERN  = re.compile(r"^\s*extern\s+([^;]+);")
VDP_DIRECT = re.compile(r"VDP_(DATA|CTRL)_WORD|0x00C0000[0-9A-F]|0xC0000[0-9A-F]")


def is_frontend(path: Path) -> bool:
    return bool(FRONTEND_NAME.match(path.name))


def main() -> int:
    lines: list[str] = ["# Frontend Dependency Report", ""]
    lines.append("Generated by `tools/probes/scan_frontend_deps.py`.")
    lines.append("")
    lines.append("Frontend = files matching `^(intro|fs|frontend)_` under `src/`.")
    lines.append("")

    files = [p for p in sorted(SRC.rglob("*")) if p.is_file() and is_frontend(p) and p.suffix in (".c", ".h")]

    for path in files:
        rel = relative_to_repo(path)
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        includes: list[str] = []
        externs: list[str] = []
        vdp_direct: list[tuple[int, str]] = []

        for lineno, line in enumerate(text.splitlines(), start=1):
            m = INCLUDE.match(line)
            if m:
                includes.append(m.group(1))
                continue
            m = EXTERN.match(line)
            if m:
                externs.append(m.group(1).strip())
                continue
            if VDP_DIRECT.search(line):
                vdp_direct.append((lineno, line.strip()[:120]))

        lines.append(f"## `{rel}`")
        lines.append("")
        lines.append("**Includes:**")
        if includes:
            for inc in includes:
                lines.append(f"- `{inc}`")
        else:
            lines.append("_(none)_")
        lines.append("")
        lines.append("**Externs declared:**")
        if externs:
            for ext in externs:
                lines.append(f"- `{ext}`")
        else:
            lines.append("_(none)_")
        lines.append("")
        lines.append("**VDP-direct register access:**")
        if vdp_direct:
            for lineno, snippet in vdp_direct:
                lines.append(f"- `{rel}:{lineno}` — `{snippet}`")
        else:
            lines.append("_(none)_")
        lines.append("")

    out = write_audit("frontend_deps.md", "\n".join(lines) + "\n")
    print(f"wrote {out} ({len(files)} frontend files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run the scanner**

Run: `cd tools/probes && python scan_frontend_deps.py`
Expected: writes `docs/audit/frontend_deps.md`. Reports a non-zero file count (~30 frontend files including intro_* and fs_*).

- [ ] **Step 3: Spot-check the output**

Run: `grep -c "^## \`" docs/audit/frontend_deps.md`
Expected: matches the file count printed above.

- [ ] **Step 4: Commit**

```bash
git add tools/probes/scan_frontend_deps.py docs/audit/frontend_deps.md
git commit -m "s0: frontend dependency report"
```

---

## Task 11: Build build-order analyzer

**Files:**

- Create: `tools/probes/scan_build_order.py`
- Create (output): `docs/audit/build_order.md`

- [ ] **Step 1: Read `build.bat` and identify per-file actions**

The script parses `build.bat` line-by-line to extract:

- Which `.c` files are passed to gcc (look for `gcc ... -c %%F.c`)
- Which `.asm` files are passed to vasm (look for `vasm ... %%G.asm`)
- The order they appear in the loop variables (the `for %%F in (...)` lists)
- The link order (the `.o` files passed to `m68k-elf-ld`)

- [ ] **Step 2: Write the analyzer**

```python
# tools/probes/scan_build_order.py
"""Generate docs/audit/build_order.md by parsing build.bat.

Extracts compile-order and link-order from the for-loops and link command in
build.bat. Output is a markdown report listing:

  - Stage 2a: C compilation order
  - Stage 2b: ASM assembly order
  - Stage 2c: link order
  - Stage 3:  objcopy / strip
"""

from __future__ import annotations

import re
import sys

from _common import REPO_ROOT, write_audit


FOR_LOOP = re.compile(r"^\s*for\s+%%(\w)\s+in\s+\(([^)]*)\)\s+do\b", re.IGNORECASE)
LINK_LINE = re.compile(r"m68k-elf-ld[^\n]*", re.IGNORECASE)


def main() -> int:
    bat = (REPO_ROOT / "build.bat").read_text(encoding="utf-8", errors="replace")
    lines = bat.splitlines()

    loops: list[tuple[int, str, str]] = []  # (lineno, var, items_raw)
    for i, line in enumerate(lines, start=1):
        m = FOR_LOOP.match(line)
        if m:
            loops.append((i, m.group(1), m.group(2).strip()))

    link_lines = [(i, l.strip()) for i, l in enumerate(lines, start=1) if LINK_LINE.search(l)]

    out: list[str] = ["# Build Order Report", ""]
    out.append("Generated by `tools/probes/scan_build_order.py` from `build.bat`.")
    out.append("")
    out.append("## For-loops in build.bat")
    out.append("")
    if not loops:
        out.append("_No for-loops found. Inspect build.bat directly._")
    for lineno, var, items in loops:
        out.append(f"### `for %%{var}` at line {lineno}")
        out.append("")
        out.append("Items (in declaration order):")
        out.append("")
        for tok in items.split():
            out.append(f"- `{tok}`")
        out.append("")

    out.append("## Link command(s)")
    out.append("")
    if not link_lines:
        out.append("_No `m68k-elf-ld` invocations found._")
    for lineno, line in link_lines:
        out.append(f"- line {lineno}: `{line}`")
    out.append("")

    written = write_audit("build_order.md", "\n".join(out) + "\n")
    print(f"wrote {written}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: Run the analyzer**

Run: `cd tools/probes && python scan_build_order.py`
Expected: writes `docs/audit/build_order.md`.

- [ ] **Step 4: Verify the report captured the for-loops**

Run: `grep -c "^### \`for" docs/audit/build_order.md`
Expected: ≥ 2 (build.bat has at least a C-compile loop and an ASM-assemble loop).

- [ ] **Step 5: Commit**

```bash
git add tools/probes/scan_build_order.py docs/audit/build_order.md
git commit -m "s0: build order report"
```

---

## Task 12: Build file classifier

**Files:**

- Create: `tools/probes/classify_files.py`
- Create: `tools/probes/test_classify_files.py`
- Create (output): `docs/audit/file_classification.md`

- [ ] **Step 1: Write the classifier test**

```python
# tools/probes/test_classify_files.py
"""Tests for classify_files.py."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from classify_files import classify


@pytest.mark.parametrize("rel,expected", [
    ("src/enemy_runtime.c",                "owned_c"),
    ("src/enemy_walker_runtime.c",         "owned_c"),
    ("src/intro_main.c",                   "owned_c_frontend"),
    ("src/fs_main.c",                      "owned_c_frontend"),
    ("src/gen/intro_title_bg_chr.c",       "generated_data"),
    ("src/gen/fs_palette.c",               "generated_data"),
    ("src/gen/z_07.c",                     "transpile_adapter"),
    ("src/zelda_translated/z_07.asm",      "transpiled_asm"),
    ("src/nes_io.asm",                     "shim_asm"),
    ("src/c_shims.asm",                    "shim_asm"),
    ("src/genesis_shell.asm",              "platform_asm"),
    ("src/audio_driver.asm",               "platform_asm"),
    ("src/c_move_object.c",                "compat_wrapper"),
    ("src/c_wanderer.c",                   "compat_wrapper"),
    ("src/genesis_shell.asm.bak",          "cruft"),
    ("src/nes_io - Copy.txt",              "cruft"),
])
def test_classification(rel: str, expected: str) -> None:
    assert classify(rel) == expected
```

- [ ] **Step 2: Run test, expect failure**

Run: `cd tools/probes && python -m pytest test_classify_files.py -v`
Expected: ImportError (module not yet written).

- [ ] **Step 3: Implement the classifier**

```python
# tools/probes/classify_files.py
"""Classify every src/ file by role, emit docs/audit/file_classification.md."""

from __future__ import annotations

import sys
from pathlib import Path

from _common import SRC, write_audit, relative_to_repo


CATEGORIES = [
    "owned_c",
    "owned_c_frontend",
    "generated_data",
    "transpile_adapter",
    "transpiled_asm",
    "shim_asm",
    "platform_asm",
    "compat_wrapper",
    "header",
    "cruft",
]

FRONTEND_PREFIXES = ("src/intro_", "src/fs_", "src/frontend_")
COMPAT_NAMES = {"src/c_move_object.c", "src/c_wanderer.c"}
SHIM_NAMES = {"src/nes_io.asm", "src/c_shims.asm"}
PLATFORM_ASM_NAMES = {"src/genesis_shell.asm", "src/audio_driver.asm"}


def classify(rel: str) -> str:
    rel_norm = rel.replace("\\", "/")
    if rel_norm.endswith(".bak") or " - Copy" in rel_norm or rel_norm.endswith(".txt"):
        return "cruft"
    if rel_norm in COMPAT_NAMES:
        return "compat_wrapper"
    if rel_norm in SHIM_NAMES:
        return "shim_asm"
    if rel_norm in PLATFORM_ASM_NAMES:
        return "platform_asm"
    if rel_norm.startswith("src/zelda_translated/"):
        return "transpiled_asm"
    if rel_norm.startswith("src/gen/"):
        if "/z_" in rel_norm and rel_norm.endswith(".c"):
            return "transpile_adapter"
        return "generated_data"
    if rel_norm.endswith(".h"):
        return "header"
    if rel_norm.endswith(".c"):
        if any(rel_norm.startswith(p) for p in FRONTEND_PREFIXES):
            return "owned_c_frontend"
        return "owned_c"
    if rel_norm.endswith((".asm", ".inc")):
        # Anything else under src/ that is asm but unclassified — bucket as cruft.
        return "cruft"
    return "cruft"


def main() -> int:
    buckets: dict[str, list[str]] = {c: [] for c in CATEGORIES}

    for path in sorted(SRC.rglob("*")):
        if not path.is_file():
            continue
        rel = relative_to_repo(path)
        cat = classify(rel)
        buckets.setdefault(cat, []).append(rel)

    lines: list[str] = ["# File Classification", ""]
    lines.append("Generated by `tools/probes/classify_files.py`.")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append("| Category | Count |")
    lines.append("|---|---|")
    for cat in CATEGORIES:
        lines.append(f"| `{cat}` | {len(buckets.get(cat, []))} |")
    lines.append("")

    for cat in CATEGORIES:
        files = buckets.get(cat, [])
        lines.append(f"## `{cat}` ({len(files)})")
        lines.append("")
        if not files:
            lines.append("_(none)_")
            lines.append("")
            continue
        for rel in files:
            lines.append(f"- `{rel}`")
        lines.append("")

    out = write_audit("file_classification.md", "\n".join(lines) + "\n")
    print(f"wrote {out}")
    for cat in CATEGORIES:
        print(f"  {cat:24s} {len(buckets.get(cat, []))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test, expect pass**

Run: `cd tools/probes && python -m pytest test_classify_files.py -v`
Expected: 16 passed.

- [ ] **Step 5: Run the classifier on the live tree**

Run: `cd tools/probes && python classify_files.py`
Expected: writes `docs/audit/file_classification.md`. Per-category counts printed.

- [ ] **Step 6: Commit**

```bash
git add tools/probes/classify_files.py tools/probes/test_classify_files.py docs/audit/file_classification.md
git commit -m "s0: file classification report"
```

---

## Task 12.5: Inventory Redux feature touchpoints + lock SRAM map

The native rewrite includes a real preferences subsystem (`src/game/options/`, spec Section 4.6). To future-proof it we need to:

1. Inventory every place the current build already implements a Zelda-Redux feature (so the rewrite preserves them, doesn't lose them in the cutover).
2. Lock the SRAM byte range allocation now (before any reorg moves files), so the new OPTIONS persistence range is reserved alongside the existing save slots without collision.

**Files:**

- Create: `tools/probes/scan_redux_touchpoints.py`
- Create (output): `docs/audit/redux_touchpoints.md`
- Create: `docs/audit/sram_map.md`

- [ ] **Step 1: Write the Redux touchpoint scanner**

```python
# tools/probes/scan_redux_touchpoints.py
"""Generate docs/audit/redux_touchpoints.md.

Reports every existing reference to Zelda-Redux behavior in the FINAL TRY
codebase: comments mentioning Redux, palette overrides borrowed from Redux,
FS extensions (PLAYERS / OPTIONS rows), silent-FS handling, and any other
deviation from vanilla NES Zelda 1 that the rewrite must preserve.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from _common import SRC, write_audit, relative_to_repo

REDUX_PAT = re.compile(r"redux", re.IGNORECASE)
OPTIONS_PAT = re.compile(r"\bOPTIONS\b|\bopt_|FS_OPTIONS")
PLAYERS_PAT = re.compile(r"\bPLAYERS\b")


def main() -> int:
    hits: list[tuple[str, int, str, str]] = []  # (rel, lineno, tag, snippet)

    for path in sorted(SRC.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix not in (".c", ".h", ".asm", ".inc"):
            continue
        rel = relative_to_repo(path)
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            tags: list[str] = []
            if REDUX_PAT.search(line):
                tags.append("Redux")
            if OPTIONS_PAT.search(line):
                tags.append("OPTIONS")
            if PLAYERS_PAT.search(line):
                tags.append("PLAYERS")
            if not tags:
                continue
            hits.append((rel, lineno, ",".join(tags), line.strip()[:160]))

    lines: list[str] = ["# Zelda Redux Touchpoint Inventory", ""]
    lines.append("Generated by `tools/probes/scan_redux_touchpoints.py`.")
    lines.append("")
    lines.append("Every site below is preserved (or re-implemented natively) by the rewrite.")
    lines.append("S8a wires these into the OPTIONS subsystem (`src/game/options/`).")
    lines.append("")
    lines.append(f"Total touchpoints: **{len(hits)}**")
    lines.append("")
    lines.append("| File | Line | Tags | Snippet |")
    lines.append("|---|---|---|---|")
    for rel, lineno, tags, snippet in hits:
        safe = snippet.replace("|", "\\|")
        lines.append(f"| `{rel}` | {lineno} | {tags} | `{safe}` |")

    out = write_audit("redux_touchpoints.md", "\n".join(lines) + "\n")
    print(f"wrote {out} ({len(hits)} touchpoints)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run the scanner**

Run: `cd tools/probes && python scan_redux_touchpoints.py`
Expected: writes `docs/audit/redux_touchpoints.md`. Touchpoint count > 0 (the FS render code already references Redux for palette, PLAYERS row, OPTIONS row).

- [ ] **Step 3: Inspect `Zelda1-Redux/` to enumerate available Redux features**

The repo includes a top-level `Zelda1-Redux/` directory containing `optional/` patches and `src/code/menus/` source. Walk these once to extract the feature list that exists in upstream Redux but isn't yet implemented in FINAL TRY. Goal: confirm Section 4.6's flag table covers everything the user might want.

Run: `ls Zelda1-Redux/optional/ Zelda1-Redux/src/code/ 2>/dev/null`
Then read each interesting file's first 30 lines to identify what feature it adds.

For each Redux feature found, mark it in `docs/audit/redux_touchpoints.md` as one of:

- **already-in-FINAL-TRY** — preserved by the rewrite as-is
- **planned-flag** — covered by Section 4.6's initial flag set
- **future-flag** — viable Redux feature not in the initial flag set; recorded as a future enhancement (no spec amendment needed; the future-proofing rule says new flags are single-file additions)
- **out-of-scope** — Redux feature we explicitly don't want (e.g. mechanic changes that conflict with parity goals)

Append a section to `redux_touchpoints.md`:

```markdown
## Redux feature catalog

| Feature | Status | Section 4.6 flag (if any) | Notes |
|---|---|---|---|
| Faded Link palette for empty save slot | already-in-FINAL-TRY | `OPT_REDUX_LINK_TINT` | preserved verbatim |
| PLAYERS row on FS | already-in-FINAL-TRY | (UI only, not a flag) | preserved |
| OPTIONS row on FS | already-in-FINAL-TRY (label only) | wired in S8a | submenu added in S8a |
| Silent FS music | already-in-FINAL-TRY | `OPT_FS_MUSIC` (default off = silent) | toggleable in S8a |
| <feature from Zelda1-Redux/optional/> | <status> | <flag if any> | <notes> |
| ... | ... | ... | ... |
```

- [ ] **Step 4: Lock SRAM byte-range map**

Inspect the current SRAM layout. The existing FS save format uses a defined byte range; the new OPTIONS persistence needs a separate non-overlapping range.

Run:

```bash
grep -n "SRAM\|NES_SRAM\|sram" src/room_runtime.c src/fs_*.c src/fs_*.h 2>/dev/null | head -30
```

Identify the byte range currently used by save slots (likely the NES original 0x6000-based range mirrored through the SRAM shim). Then choose a free range for `OptionsState`.

Write the SRAM map:

```markdown
<!-- docs/audit/sram_map.md -->
# SRAM Map (locked at S0)

The Genesis SRAM region is divided into named ranges. The native rewrite must
preserve existing ranges byte-for-byte to keep saves loadable. New ranges
allocated at S0 stay reserved and unwritten until the relevant subsystem
lands.

| Range (byte offset) | Size | Owner | Status |
|---|---|---|---|
| `0x000` – `<recorded end>` | `<recorded>` | NES save slots (3 files) | preserved verbatim by rewrite |
| `<existing checksum/footer if any>` | | | preserved |
| `<chosen new offset>` – `<offset + sizeof(OptionsState)>` | ~32 bytes | `OptionsState` (Section 4.6) | reserved at S0; written first time in S8a |
| `<remaining free>` | | unallocated | reserved for future use |

### OptionsState SRAM layout

Per spec Section 4.6:

```c
struct OptionsState {
    u8  version;          // schema version
    u8  flags[N];         // packed flag bytes
    u8  reserved[16];     // future expansion, zero
    u8  checksum;         // simple XOR of preceding bytes
};
```

`N` is fixed at S0 to **8** (room for 64 bool flags or 8 enum byte-values). Bumping `N` in the future requires a `version` bump and a new persistence migration step.

### Invariant

S1's SRAM fixture test (`tools/probes/sram_layout_test.c`) asserts:

- existing save slot offsets are unchanged
- the OptionsState range is initialized to all-zero on a fresh SRAM
- on re-read, an all-zero `OptionsState` is detected as invalid (checksum fails) and the runtime falls back to defaults
```

- [ ] **Step 5: Commit**

```bash
git add tools/probes/scan_redux_touchpoints.py docs/audit/redux_touchpoints.md docs/audit/sram_map.md
git commit -m "s0: Redux touchpoint inventory + SRAM map (OptionsState range)"
```

---

## Task 13: Build legacy symbol lint (warn-only) + hook into build.bat

**Files:**

- Create: `tools/probes/lint_legacy_symbols.py`
- Create: `tools/probes/test_lint_legacy_symbols.py`
- Modify: `build.bat` (add post-build call)

- [ ] **Step 1: Write the lint test**

```python
# tools/probes/test_lint_legacy_symbols.py
"""Tests for lint_legacy_symbols.py."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from lint_legacy_symbols import lint_text


def test_clean_text_returns_no_findings() -> None:
    findings = lint_text("path.c", "void foo(void) { return; }\n")
    assert findings == []


def test_ppu_caller_is_flagged() -> None:
    findings = lint_text("src/foo.c", "  jsr _ppu_write_2006\n")
    assert len(findings) == 1
    f = findings[0]
    assert f.symbol == "_ppu_write_2006"
    assert f.lineno == 1
    assert f.path == "src/foo.c"


def test_z07_caller_is_flagged() -> None:
    findings = lint_text("src/c.c", "z07_anim_advance_and_fetch(0, slot);\n")
    assert len(findings) == 1
    assert findings[0].symbol == "z07_anim_advance_and_fetch"


def test_legacy_bridge_is_exempt() -> None:
    findings = lint_text(
        "src/abi/legacy_bridge.h",
        "extern void z07_anim_advance_and_fetch(unsigned, unsigned);\n",
    )
    assert findings == []


def test_zelda_translated_dir_is_exempt() -> None:
    findings = lint_text(
        "src/zelda_translated/z_07.asm",
        "  jsr _ppu_write_2006\n",
    )
    assert findings == []
```

- [ ] **Step 2: Run test, expect failure**

Run: `cd tools/probes && python -m pytest test_lint_legacy_symbols.py -v`
Expected: ImportError (module not yet written).

- [ ] **Step 3: Implement the lint**

```python
# tools/probes/lint_legacy_symbols.py
"""Warning-only lint for legacy shim and transpile symbols.

At S0: prints a warning summary; never fails the build.
At S1+: same families graduate to hard failure per spec Section 8.1.

Exemptions:
  - src/abi/legacy_bridge.h   (transitional declarations only)
  - src/zelda_translated/     (legacy bank source — these define the symbols)
  - src/gen/z_*.c             (transpile adapters)
  - src/nes_io.asm, src/c_shims.asm, src/genesis_shell.asm (definitions)
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

from _common import REPO_ROOT, SRC, relative_to_repo


PATTERNS: list[tuple[str, re.Pattern]] = [
    ("_ppu_*",  re.compile(r"\b_ppu_[A-Za-z0-9_]+")),
    ("_oam_*",  re.compile(r"\b_oam_[A-Za-z0-9_]+")),
    ("_apu_*",  re.compile(r"\b_apu_[A-Za-z0-9_]+")),
    ("_ctrl_*", re.compile(r"\b_ctrl_[A-Za-z0-9_]+")),
    ("_mmc1_*", re.compile(r"\b_mmc1_[A-Za-z0-9_]+")),
    ("z00_*..z07_*", re.compile(r"\bz0[0-7]_[A-Za-z0-9_]+")),
]

EXEMPT_PATH_PREFIXES = (
    "src/zelda_translated/",
    "src/gen/",
    "src/abi/legacy_bridge.h",
)
EXEMPT_PATH_EXACT = {
    "src/nes_io.asm",
    "src/c_shims.asm",
    "src/genesis_shell.asm",
}


@dataclass
class Finding:
    path: str
    lineno: int
    symbol: str


def is_exempt(rel: str) -> bool:
    rel_norm = rel.replace("\\", "/")
    if rel_norm in EXEMPT_PATH_EXACT:
        return True
    return any(rel_norm.startswith(p) for p in EXEMPT_PATH_PREFIXES)


def lint_text(rel: str, text: str) -> list[Finding]:
    if is_exempt(rel):
        return []
    out: list[Finding] = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        for _family, pat in PATTERNS:
            for m in pat.finditer(line):
                out.append(Finding(path=rel, lineno=lineno, symbol=m.group(0)))
    return out


def main() -> int:
    findings: list[Finding] = []
    for path in sorted(SRC.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix not in (".c", ".h", ".asm", ".inc"):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        findings.extend(lint_text(relative_to_repo(path), text))

    if findings:
        print(f"[lint_legacy_symbols] WARNING: {len(findings)} legacy callers found (S0 warn-only):", file=sys.stderr)
        for f in findings[:50]:
            print(f"  {f.path}:{f.lineno}  {f.symbol}", file=sys.stderr)
        if len(findings) > 50:
            print(f"  ... and {len(findings) - 50} more", file=sys.stderr)
    else:
        print("[lint_legacy_symbols] no legacy callers in non-exempt files.")
    # Warn-only at S0; always exit 0.
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run tests, expect pass**

Run: `cd tools/probes && python -m pytest test_lint_legacy_symbols.py -v`
Expected: 5 passed.

- [ ] **Step 5: Run the lint on the live tree**

Run: `cd tools/probes && python lint_legacy_symbols.py`
Expected: prints a warning with up to 50 representative findings (most callers should be in non-exempt owned-C runtimes that still call into transpiled banks).

- [ ] **Step 6: Hook into `build.bat`**

Open `build.bat`. At the very end, just before the final `exit /b 0` of the success path, add:

```bat
rem ---------------------------------------------------------------------------
rem [S0] Warning-only legacy symbol lint
rem ---------------------------------------------------------------------------
"%PYTHON%" "%ROOT%\tools\probes\lint_legacy_symbols.py"
rem (intentionally not gating on errorlevel — S0 lint is warn-only)
```

- [ ] **Step 7: Re-run a full build to verify the hook fires**

Run: `build.bat`
Expected: build succeeds, and the lint warning summary appears at the end of the output.

- [ ] **Step 8: Commit**

```bash
git add tools/probes/lint_legacy_symbols.py tools/probes/test_lint_legacy_symbols.py build.bat
git commit -m "s0: warn-only legacy symbol lint hooked into build.bat"
```

---

## Task 14: Resolve S0-Locked Questions in spec

**Files:**

- Modify: `docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md` (Section 12)
- Create: `docs/audit/s0_close.md`

- [ ] **Step 1: Walk Section 12 questions one by one**

Open the spec at Section 12. For each of the 7 S0-Locked Questions, record the resolution drawing from the audit artifacts produced in Tasks 3–13:

1. **Active Genesis baseline ROM** — resolved by Task 5; record the SHA256.
2. **Capture geometry** — resolved by Task 7; cite `docs/audit/capture_geometry.md`.
3. **ABI proof** — resolved by Task 8; cite `docs/audit/abi_probe.md`.
4. **Normalized parity schema lock** — see Step 2 below.
5. **Audio responsibility split** — see Step 3 below.
6. **Render-API public boundary** — confirmed by spec Section 6 conventions; lint will enforce starting S1. Mark **resolved**.
7. **Reference ROM provenance** — resolved by Task 4; ROM not committed, resolver verifies SHA256.

- [ ] **Step 2: Sanity-check the normalized parity schema (Q4)**

Pick a single screen pair where current FINAL TRY ROM and NES ROM agree visually (e.g. title-screen-idle frame 60). Manually capture both via BizHawk: PNG screenshot + RAM/VRAM/CRAM/SAT dump. Walk the schema fields by hand and confirm a normalized representation can be produced from both that matches on `bg_tile`, `bg_palette`, `sprite[]`, `scroll`. Record the result in `docs/audit/parity_schema_check.md` (one-page note).

If the manual check reveals the schema is insufficient (e.g. NES sprite priority and Genesis sprite priority don't map cleanly), record the gap and propose the smallest schema extension needed. Update Section 0 of the spec to reflect any extension before closing S0.

- [ ] **Step 3: Confirm the audio split (Q5)**

Inspect the existing audio path:

- VBlank handler in `src/genesis_shell.asm` calls `music_tick`.
- `audio_driver.asm` is standalone.
- Frontend (`fs_main.c`, `intro_main.c`) calls `music_play`.

Confirm that a thin `audio_tick_vblank()` C wrapper around the existing `music_tick` is feasible without invasive driver changes. Confirm `audio_music_play(u8)` and `audio_sfx_play(u8)` can wrap existing entrypoints. Record the wrapping plan (one paragraph) in `docs/audit/audio_split_plan.md`.

This is a **plan**, not an implementation; the actual wrapper lands in S1.

- [ ] **Step 4: Update Section 12 of the spec**

Replace each `<filled at S0>` or unresolved item with the recorded resolution. After all 7 questions are resolved, the section body becomes:

```markdown
## 12. S0-Locked Questions

**Resolved at S0** (commit `<git rev-parse HEAD>`). See `docs/audit/s0_close.md`
for the full close-out summary.

None remaining.
```

If any question revealed a residual issue requiring spec amendment, list it here instead of "None remaining" and treat it as a blocker for S1.

- [ ] **Step 5: Write the S0 close-out summary**

```markdown
<!-- docs/audit/s0_close.md -->
# S0 Close-Out

S0 acceptance was reached on `<UTC date>` at commit `<sha>`. Build is green;
behavior is unchanged versus the locked baseline ROM.

## Audit artifacts

- [`repo_tree.txt`](repo_tree.txt)
- [`legacy_callers.md`](legacy_callers.md)
- [`frontend_deps.md`](frontend_deps.md)
- [`build_order.md`](build_order.md)
- [`file_classification.md`](file_classification.md)
- [`toolchain.md`](toolchain.md)
- [`baseline_rom.md`](baseline_rom.md)
- [`emulators.md`](emulators.md)
- [`capture_geometry.md`](capture_geometry.md)
- [`abi_probe.md`](abi_probe.md)
- [`redux_touchpoints.md`](redux_touchpoints.md)
- [`sram_map.md`](sram_map.md)
- [`parity_schema_check.md`](parity_schema_check.md)
- [`audio_split_plan.md`](audio_split_plan.md)

## Resolved S0-Locked Questions

1. Active Genesis baseline ROM: `<SHA256>`
2. Capture geometry: see `capture_geometry.md`
3. ABI proof: see `abi_probe.md`
4. Normalized parity schema: confirmed sufficient (or extended; see `parity_schema_check.md`)
5. Audio split: wrapper plan recorded in `audio_split_plan.md`
6. Render-API public boundary: locked to `src/abi/render_abi.h`
7. NES ROM provenance: not committed; resolver verifies SHA256

## Lint state

`lint_legacy_symbols.py` runs at the end of every `build.bat` build,
warning-only. Caller count at S0 close: `<recorded>`.

## Next stage

S1 — Repo Reorg + Render Floor. Spec Section 7. Status: gated on this
close-out commit; ready to begin.
```

- [ ] **Step 6: Commit**

```bash
git add docs/audit/s0_close.md docs/audit/parity_schema_check.md docs/audit/audio_split_plan.md docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md
git commit -m "s0: resolve S0-Locked Questions; write close-out summary"
```

---

## Task 15: Verify build still produces working ROM

**Files:**

- _(no source modifications)_
- Optional: `docs/audit/s0_smoke_test.md`

- [ ] **Step 1: Clean build directory and rebuild**

Run:

```bash
rm -rf builds/obj/*
build.bat
```

Expected: build succeeds, lint warning appears, final ROM is produced.

- [ ] **Step 2: Verify the produced ROM hash matches the locked baseline**

Run:

```bash
python -c "import hashlib; print(hashlib.sha256(open('builds/whatif.md','rb').read()).hexdigest())"
```

Expected: identical to the SHA256 recorded in Task 5 (Section 0 baseline).

If the hash differs, S0 has accidentally introduced a behavior change. Bisect — likely culprits are the `build.bat` lint hook (must not affect compilation), or accidental edits to source files during audit. Resolve before continuing.

- [ ] **Step 3: Smoke-test the ROM in BizHawk**

Use the `bizhawkScript` skill pattern (memory `skill_bizhawk_script.md`). Boot the ROM, observe:

- Title screen renders (matches current known-good behavior)
- Press Start; intro story plays
- Reach file-select screen
- Cursor moves between slots
- Music plays through the whole sequence

No new regressions versus pre-S0. Record any observations in `docs/audit/s0_smoke_test.md` if helpful.

- [ ] **Step 4: Commit (only if smoke-test notes were written)**

```bash
git add docs/audit/s0_smoke_test.md
git commit -m "s0: smoke-test notes (post-audit)"
```

If no notes written, skip the commit; the previous commit is the close-out.

---

## Task 16: Tag S0 close

**Files:**

- _(git only)_

- [ ] **Step 1: Verify all expected audit files exist**

Run:

```bash
ls docs/audit/
```

Expected to see at minimum:

- `README.md`
- `repo_tree.txt`
- `legacy_callers.md`
- `frontend_deps.md`
- `build_order.md`
- `file_classification.md`
- `redux_touchpoints.md`
- `sram_map.md`
- `toolchain.md`
- `baseline_rom.md`
- `emulators.md`
- `capture_geometry.md`
- `abi_probe.md`
- `parity_schema_check.md`
- `audio_split_plan.md`
- `s0_close.md`

- [ ] **Step 2: Verify spec has no remaining `<filled at S0>` placeholders**

Run:

```bash
grep -n "<filled at S0" docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md
```

Expected: no matches.

- [ ] **Step 3: Verify Section 12 is reduced**

Run:

```bash
grep -A 4 "^## 12\." docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md | head -10
```

Expected: shows the resolved-state body ("None remaining" or a residual list).

- [ ] **Step 4: Tag the close-out commit**

```bash
git tag -a s0-closed -m "S0 (Inventory + Guardrails) complete. Spec ready for S1."
```

- [ ] **Step 5: Final verification — run the full audit pipeline once more**

Run all generators in sequence to confirm they're all green and produce identical output (idempotency check):

```bash
cd tools/probes
python snapshot_repo_tree.py
python scan_legacy_callers.py
python scan_frontend_deps.py
python scan_build_order.py
python classify_files.py
python lint_legacy_symbols.py
python -m pytest -v
```

Expected: every script writes its file with no error, all tests pass, lint exits 0.

Run `git status`. Expected: clean working tree (re-runs produced byte-identical output to what was already committed).

---

## Self-Review Checklist (run before handing off to executor)

- [ ] Every spec deliverable in S0 has a matching task: repo tree (T2), legacy callers (T9), frontend deps (T10), build order (T11), file classification (T12), Redux touchpoints + SRAM map (T12.5), lint (T13), abi probe (T8), locate_reference_rom (T4), Section 0 placeholders filled (T3, T4, T5, T6, T7), Section 4.5 placeholders filled (T3, T8), Section 12 resolved (T14).
- [ ] No `TBD`, `TODO`, "implement later", "fill in details" in any task body.
- [ ] Every code-emitting step contains the actual code or command.
- [ ] Type and method consistency: `Finding` is defined in T13, used only in T13. `classify(rel)` in T12 returns one of the categories listed in `CATEGORIES`. `resolve_rom` in T4 raises `RomNotFoundError` and `RomHashMismatchError`, both defined.
- [ ] Build still works after S0 (T15).
- [ ] No source code outside `tools/probes/`, `docs/audit/`, the spec, `.gitignore`, and one `build.bat` line is modified.
