#!/usr/bin/env python3
"""check_adapter_boundary.py — enforce SGDK adapter boundary in owned C/H code.

Per debate 003 Rule SGDK-1.

Owned code under src/game/ and src/frontend/ MUST NOT include SGDK public
headers. All Genesis hardware access must route through src/sgdk_adapter/.

Per-directory matrix (debate 003 §8):
  ENFORCE   src/game/, src/frontend/
  WHITELIST src/sgdk_adapter/, src/genesis_shell.asm, src/nes_io.asm,
            src/c_shims.asm, src/audio_driver.asm, src/zelda_translated/, src/gen/

Comment-aware: ignores SGDK header names that appear inside C/C++ comments.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SRC = REPO / "src"

# Directories under src/ that MUST go through the adapter.
ENFORCED_DIRS = ["game", "frontend"]

# SGDK public header names. If owned code includes any of these, fail.
SGDK_HEADERS = [
    "genesis.h",
    "sprite.h",
    "vdp.h",
    "vdp_bg.h",
    "vdp_dma.h",
    "vdp_pal.h",
    "vdp_spr.h",
    "vdp_tile.h",
    "dma.h",
    "pal.h",
    "joy.h",
    "sys.h",
    "memory.h",  # SGDK's memory.h, not standard libc
    "z80_ctrl.h",
    "ym2612.h",
    "psg.h",
    "sound.h",
    "sound/xgm.h",
    "sound/xgm2.h",
    "sound/pcm.h",
]

# `#include <header>` or `#include "header"` — only at line start (after
# optional whitespace), so a header name inside a comment is ignored.
INCLUDE_RE = re.compile(
    r'^\s*#\s*include\s*[<"]([^>"]+)[>"]',
    re.MULTILINE,
)

# Strip C/C++ comments before scanning. Cheap state machine: handles //
# line comments and /* ... */ block comments. No string-literal handling
# is necessary because we only inspect #include lines, which never put
# header names inside strings.
def strip_comments(src: str) -> str:
    out = []
    i, n = 0, len(src)
    in_block = False
    in_line = False
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if in_block:
            if c == "*" and nxt == "/":
                in_block = False
                i += 2
                continue
            i += 1
            continue
        if in_line:
            if c == "\n":
                in_line = False
                out.append(c)
            i += 1
            continue
        if c == "/" and nxt == "/":
            in_line = True
            i += 2
            continue
        if c == "/" and nxt == "*":
            in_block = True
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def scan_file(path: Path) -> list[tuple[int, str]]:
    """Return list of (line_no, header) violations found in path."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        print(f"WARN: cannot read {path}: {e}", file=sys.stderr)
        return []
    stripped = strip_comments(text)
    violations: list[tuple[int, str]] = []
    for m in INCLUDE_RE.finditer(stripped):
        header = m.group(1).strip()
        if header in SGDK_HEADERS:
            line_no = stripped.count("\n", 0, m.start()) + 1
            violations.append((line_no, header))
    return violations


def main() -> int:
    failures: list[tuple[Path, int, str]] = []
    scanned = 0
    for sub in ENFORCED_DIRS:
        root = SRC / sub
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.suffix.lower() not in (".c", ".h", ".cc", ".cpp", ".hpp"):
                continue
            scanned += 1
            for line_no, header in scan_file(path):
                failures.append((path, line_no, header))

    if failures:
        print("FAIL: SGDK adapter boundary violations:", file=sys.stderr)
        for path, line_no, header in failures:
            rel = path.relative_to(REPO)
            print(f"  {rel}:{line_no}  #include <{header}>", file=sys.stderr)
        print(
            f"\n  Owned code must route hardware access through src/sgdk_adapter/.",
            file=sys.stderr,
        )
        return 1

    print(f"OK: scanned {scanned} files in src/{{{','.join(ENFORCED_DIRS)}}}; no SGDK header leaks.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
