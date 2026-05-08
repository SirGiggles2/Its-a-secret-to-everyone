#!/usr/bin/env python3
"""check_frontend_boundary.py — block gameplay code from including frontend code.

Per debate 004 ask 5 + Phase 12 promotion gate.

Scans owned gameplay code paths for any include of a frontend header. The
shipping ROM (Debug.md) calls into gameplay through a flat ABI; gameplay
must never know that frontend exists.

Scoped paths (gameplay-side):
  ENFORCE   src/game/, RoomRom/src/

Forbidden include patterns:
  #include "frontend/...
  #include "../frontend/...
  #include "src/frontend/...
  #include "<basename of any file under src/frontend>"

Comment-aware. Exits 1 on any hit.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SRC_FRONTEND = REPO / "src" / "frontend"

ENFORCED_DIRS = [REPO / "src" / "game", REPO / "RoomRom" / "src"]

INCLUDE_RE = re.compile(r'^\s*#\s*include\s*[<"]([^>"]+)[>"]', re.MULTILINE)


def strip_c_comments(src: str) -> str:
    out = []
    i, n = 0, len(src)
    in_block, in_line = False, False
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if in_block:
            if c == "*" and nxt == "/":
                in_block = False
                i += 2
                continue
            if c == "\n":
                out.append(c)
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


def collect_frontend_headers() -> set[str]:
    """Return basenames of every header under src/frontend/."""
    if not SRC_FRONTEND.exists():
        return set()
    return {p.name for p in SRC_FRONTEND.rglob("*.h")}


def scan_file(path: Path, frontend_headers: set[str]) -> list[tuple[int, str]]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        print(f"WARN: cannot read {path}: {e}", file=sys.stderr)
        return []
    stripped = strip_c_comments(text)
    hits: list[tuple[int, str]] = []
    for m in INCLUDE_RE.finditer(stripped):
        inc = m.group(1).strip()
        bad = (
            inc.startswith("frontend/")
            or inc.startswith("../frontend/")
            or inc.startswith("src/frontend/")
            or inc in frontend_headers
        )
        if bad:
            line_no = stripped.count("\n", 0, m.start()) + 1
            hits.append((line_no, inc))
    return hits


def main() -> int:
    frontend_headers = collect_frontend_headers()
    failures: list[tuple[Path, int, str]] = []
    scanned = 0
    for root in ENFORCED_DIRS:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.suffix.lower() not in (".c", ".h", ".cc", ".cpp", ".hpp"):
                continue
            scanned += 1
            for line_no, inc in scan_file(path, frontend_headers):
                failures.append((path, line_no, inc))

    if failures:
        print("FAIL: frontend boundary violations in gameplay code:", file=sys.stderr)
        for path, line_no, inc in failures:
            rel = path.relative_to(REPO).as_posix()
            print(f"  {rel}:{line_no}  #include \"{inc}\"", file=sys.stderr)
        print(
            "\n  Gameplay code in src/game/ and RoomRom/src/ MUST NOT include "
            "frontend headers. Phase 12 promotion blocks until removed. Move "
            "shared types to src/state/ or src/abi/ instead.",
            file=sys.stderr,
        )
        return 1

    print(
        f"OK: scanned {scanned} gameplay files; "
        f"{len(frontend_headers)} frontend headers known; no boundary violations."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
