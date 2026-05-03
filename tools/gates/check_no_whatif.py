#!/usr/bin/env python3
"""check_no_whatif.py — block all legacy-alias references in active code paths.

Per debate 004 + user hard rule (2026-05-02): build.bat must NEVER emit
the legacy alias artifacts again. Source files and active probes must
reference Title.* exclusively.

Scans: build.bat, tools/**/*.{bat,py,lua}, RoomRom/build.bat, RoomRom/tools/**.
Allowlists: debates/ (provenance), docs/archive/ (historical), CLAUDE.md
(rule statements), this file, status docs that document the rule, and
existing whatif.* artifacts in builds/ if any survived (they should be gone).

Comment-aware for .py/.bat/.lua. Exits 1 on any hit.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

# Files / dirs scanned. Active code paths only.
SCAN_GLOBS = [
    "build.bat",
    "RoomRom/build.bat",
    "tools/**/*.bat",
    "tools/**/*.py",
    "tools/**/*.lua",
    "RoomRom/tools/**/*.py",
    "RoomRom/tools/**/*.bat",
    "src/**/*.c",
    "src/**/*.h",
    "src/**/*.asm",
]

# Allowlist (substring match against repo-relative path).
ALLOWLIST_PARTS = [
    "debates/",                              # debate provenance
    "docs/archive/",                         # historical
    "docs/audit/autonomous_session_",        # session status docs that quote the rule
    "tools/gates/check_no_whatif.py",        # this file
    ".git/",                                 # git internals
    "node_modules/",
]

# Allowed-context patterns (regex). Lines matching are NOT failures even
# if they mention whatif — used for prose explaining the historical alias.
ALLOWED_CONTEXTS = [
    re.compile(r"REMOVED.*whatif", re.IGNORECASE),
    re.compile(r"whatif.*REMOVED", re.IGNORECASE),
    re.compile(r"NEVER.*emit.*whatif", re.IGNORECASE),
    re.compile(r"# .*whatif.*alias", re.IGNORECASE),
    re.compile(r"rem .*whatif.*alias", re.IGNORECASE),
    re.compile(r"-- .*whatif", re.IGNORECASE),  # lua comment
]

WHATIF_PATTERN = re.compile(r"\bwhatif", re.IGNORECASE)


def is_allowlisted(path: Path) -> bool:
    rel = path.relative_to(REPO).as_posix().lower()
    return any(p.lower() in rel for p in ALLOWLIST_PARTS)


def strip_comment(line: str, ext: str) -> str:
    """Return the non-comment portion of a line (best-effort, per file type)."""
    if ext in (".py", ".lua"):
        idx = line.find("#" if ext == ".py" else "--")
        return line if idx < 0 else line[:idx]
    if ext == ".bat":
        # BAT line comments: 'rem ' (case-insensitive) at line start, or '::'.
        s = line.lstrip()
        if s.lower().startswith("rem "):
            return ""
        if s.startswith("::"):
            return ""
        return line
    if ext in (".c", ".h"):
        # crude: strip // and /* */ on same line
        idx = line.find("//")
        out = line if idx < 0 else line[:idx]
        out = re.sub(r"/\*.*?\*/", "", out)
        return out
    if ext == ".asm":
        idx = line.find(";")
        return line if idx < 0 else line[:idx]
    return line


def scan_file(path: Path) -> list[tuple[int, str]]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        print(f"WARN: cannot read {path}: {e}", file=sys.stderr)
        return []
    ext = path.suffix.lower()
    hits: list[tuple[int, str]] = []
    for line_no, raw in enumerate(text.splitlines(), start=1):
        if any(ctx.search(raw) for ctx in ALLOWED_CONTEXTS):
            continue
        body = strip_comment(raw, ext)
        if WHATIF_PATTERN.search(body):
            hits.append((line_no, raw.rstrip()))
    return hits


def main() -> int:
    failures: list[tuple[Path, int, str]] = []
    scanned = 0
    seen: set[Path] = set()
    for pattern in SCAN_GLOBS:
        for path in REPO.glob(pattern):
            if not path.is_file():
                continue
            if path in seen:
                continue
            seen.add(path)
            if is_allowlisted(path):
                continue
            scanned += 1
            for line_no, body in scan_file(path):
                failures.append((path, line_no, body))

    if failures:
        print("FAIL: whatif references found in active code paths:", file=sys.stderr)
        for path, line_no, body in failures:
            rel = path.relative_to(REPO).as_posix()
            print(f"  {rel}:{line_no}  {body[:100]}", file=sys.stderr)
        print(
            "\n  User hard rule: build.bat must NEVER emit whatif.*. "
            "Migrate the reference to Title.* or move it to docs/archive/.",
            file=sys.stderr,
        )
        return 1

    print(f"OK: scanned {scanned} active code files; no whatif references.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
