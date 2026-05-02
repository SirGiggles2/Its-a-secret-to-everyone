#!/usr/bin/env python3
"""check_raw_vdp.py — enforce no raw VDP register touches in owned/transpiled code.

Per debate 003 Rule SGDK-1 + per-directory matrix in §8.

Per-directory matrix:
  ENFORCE   src/game/, src/frontend/, src/zelda_translated/
            (transpiler must not emit raw VDP into transpiled output)
  WHITELIST src/sgdk_adapter/, src/genesis_shell.asm, src/nes_io.asm,
            src/c_shims.asm, src/audio_driver.asm, src/gen/

Detects: raw VDP register addresses ($C00000 / 0xC00000 / 0x00C00000) and
the VDP_DATA / VDP_CTRL symbol names (which resolve to those addresses in
genesis_shell.asm equ block).

Comment-aware: strips C/C++ // and /* */ comments and assembly ; comments
before scanning, so header-comment mentions of VDP_DATA in prose do not
trip the gate.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SRC = REPO / "src"

ENFORCED_DIRS = ["game", "frontend", "zelda_translated"]

# Raw VDP literal patterns. \b boundary so VDP_DATA_PORT also matches but
# tokens like MyVDP_DATA do not.
PATTERNS = [
    re.compile(r"\b0x0*[Cc]00000\b"),         # 0xC00000, 0x00C00000
    re.compile(r"\$0*C00000\b"),              # $C00000, $00C00000
    re.compile(r"\bVDP_DATA(?:_PORT|_WORD)?\b"),
    re.compile(r"\bVDP_CTRL(?:_PORT|_WORD)?\b"),
]


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


def strip_asm_comments(src: str) -> str:
    out_lines = []
    for line in src.splitlines(keepends=True):
        # vasm uses ';' for line comments. Keep everything before the first ';'.
        idx = line.find(";")
        out_lines.append(line if idx < 0 else line[:idx] + ("\n" if line.endswith("\n") else ""))
    return "".join(out_lines)


def scan_file(path: Path) -> list[tuple[int, str]]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        print(f"WARN: cannot read {path}: {e}", file=sys.stderr)
        return []
    if path.suffix.lower() in (".c", ".h", ".cc", ".cpp", ".hpp"):
        stripped = strip_c_comments(text)
    elif path.suffix.lower() in (".s", ".asm"):
        stripped = strip_asm_comments(text)
    else:
        return []
    hits: list[tuple[int, str]] = []
    for line_no, line in enumerate(stripped.splitlines(), start=1):
        for pat in PATTERNS:
            m = pat.search(line)
            if m:
                hits.append((line_no, m.group(0)))
                break
    return hits


def main() -> int:
    failures: list[tuple[Path, int, str]] = []
    scanned = 0
    for sub in ENFORCED_DIRS:
        root = SRC / sub
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.suffix.lower() not in (".c", ".h", ".cc", ".cpp", ".hpp", ".s", ".asm"):
                continue
            scanned += 1
            for line_no, token in scan_file(path):
                failures.append((path, line_no, token))

    if failures:
        print("FAIL: raw VDP register touches outside the adapter:", file=sys.stderr)
        for path, line_no, token in failures:
            rel = path.relative_to(REPO)
            print(f"  {rel}:{line_no}  {token}", file=sys.stderr)
        print(
            "\n  Route Genesis hardware access through src/sgdk_adapter/. "
            "If this is a measured hot path, see Rule SGDK-3 in the master plan.",
            file=sys.stderr,
        )
        return 1

    print(
        f"OK: scanned {scanned} files in src/{{{','.join(ENFORCED_DIRS)}}}; no raw VDP touches."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
