#!/usr/bin/env python3
"""verify_no_alias_collisions.py — Phase 6 Task 6.1 alias-collision gate.

`src/state/link_state.h` keeps a small set of legacy `RAM(...)` macro
shims while drained C consumers migrate. RoomRom in parallel ships
typed enums whose tokens (e.g. `LINK_FACE_DOWN`, `LINK_DIR_RIGHT`)
share the `LINK_*` namespace.

If a macro `#define` ever lands with the same identifier as an enum
member, the preprocessor mangles the enum body at parse time and the
build either fails cryptically or — worse — silently miscompiles.

This script scans:
  - macro names in `src/state/link_state.h` (and any other state header
    that consumes RAM() shims),
  - enum tokens in `RoomRom/src/roomrom_sprites.h` and `RoomRom/src/main.c`
    that start with `LINK_`,
and refuses to exit 0 if any name appears in both sets.

Exit codes:
  0  no collisions
  1  collision(s) found
  2  invocation error (missing file)

Phase 6 close-gate step `verify_no_alias_collisions` consumes this.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

STATE_HEADERS = [
    REPO / "src" / "state" / "link_state.h",
]

ENUM_SOURCES = [
    REPO / "RoomRom" / "src" / "roomrom_sprites.h",
    REPO / "RoomRom" / "src" / "main.c",
]

MACRO_RE = re.compile(r"^\s*#\s*define\s+(LINK_[A-Z0-9_]+)\b", re.MULTILINE)
ENUM_TOKEN_RE = re.compile(r"\b(LINK_[A-Z0-9_]+)\s*=", re.MULTILINE)


def collect_macros() -> dict[str, Path]:
    out: dict[str, Path] = {}
    for p in STATE_HEADERS:
        if not p.exists():
            print(f"ERROR: missing state header {p}", file=sys.stderr)
            sys.exit(2)
        text = p.read_text(encoding="utf-8", errors="ignore")
        for m in MACRO_RE.finditer(text):
            out[m.group(1)] = p
    return out


def collect_enum_tokens() -> dict[str, Path]:
    out: dict[str, Path] = {}
    for p in ENUM_SOURCES:
        if not p.exists():
            print(f"ERROR: missing enum source {p}", file=sys.stderr)
            sys.exit(2)
        text = p.read_text(encoding="utf-8", errors="ignore")
        for m in ENUM_TOKEN_RE.finditer(text):
            out.setdefault(m.group(1), p)
    return out


def main() -> int:
    macros = collect_macros()
    enums = collect_enum_tokens()
    collisions = sorted(set(macros) & set(enums))
    if collisions:
        print("ALIAS COLLISION — Phase 6 Task 6.1 invariant violated", file=sys.stderr)
        for name in collisions:
            print(
                f"  {name}: defined in {macros[name].relative_to(REPO)} "
                f"AND enum-named in {enums[name].relative_to(REPO)}",
                file=sys.stderr,
            )
        return 1
    print(
        f"OK  link_state macros={len(macros)}  enum tokens={len(enums)}  "
        f"collisions=0"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
