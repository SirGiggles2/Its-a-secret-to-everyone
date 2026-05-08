#!/usr/bin/env python3
"""check_banned_filename.py — block legacy build-alias tokens in active code paths.

Per Sole Build Target Amendment 2026-05-08:
the only ROM is `Debug.md`. The aliases below are permanently retired
and MUST NOT appear as a build target, output filename, staging copy,
variable, identifier, comment, or active-doc reference:

  - whatif.*                             (retired 2026-05-02)
  - Title.md / Title.lst / Title.elf / Title.o   (retired 2026-05-08)
  - RoomRom.md                           (retired 2026-05-08)
  - CombinedDebug.md / CombinedDebug.bat (renamed 2026-05-08)
  - combined_debug                       (renamed to debug 2026-05-08)

Note: the `RoomRom/` source tree is still authoritative — only the ROM
file `RoomRom.md` is banned. The token regex uses `\\b...\\b` boundaries
so `RoomRom/src/main.c` does not trip.

Scans active code (build/probes/source) plus a curated set of active
*.md documentation. Historical evidence trees (`debates/`,
`docs/archive/`, `docs/superpowers/{specs,plans,decisions,captures}/`,
`docs/audit/`) are allowlisted — they preserve the rename history.

Comment-aware for .py/.bat/.lua/.c/.h/.asm. Exits 1 on any hit.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

# Files / dirs scanned. Active code paths plus active top-level docs.
SCAN_GLOBS = [
    "Debug.bat",
    "tools/**/*.bat",
    "tools/**/*.py",
    "tools/**/*.lua",
    "tools/**/*.ps1",
    "RoomRom/tools/**/*.py",
    "RoomRom/tools/**/*.bat",
    "RoomRom/tools/**/*.lua",
    "src/**/*.c",
    "src/**/*.h",
    "src/**/*.asm",
    "src/**/*.s",
    "src/**/*.S",
    "RoomRom/src/**/*.c",
    "RoomRom/src/**/*.h",
    # Active docs (historical doc trees are allowlisted below).
    "CLAUDE.md",
    "README.md",
    "docs/SPEC.md",
    "docs/targets.md",
    "builds/BUILDS.md",
    # Active skills (behavioral contracts; legacy aliases here would
    # silently re-teach Claude to use them).
    ".claude/skills/**/*.md",
]

# Allowlist (substring match against repo-relative path). Files in this
# list are not scanned — they exist to enforce the rule (so they
# necessarily contain the banned tokens) or they preserve historical
# provenance.
ALLOWLIST_PARTS = [
    "debates/",                                  # debate provenance
    "docs/archive/",                             # frozen historical docs
    "docs/superpowers/specs/",                   # phase specs (frozen)
    "docs/superpowers/plans/",                   # master plan amendments inline
    "docs/superpowers/decisions/",               # frozen decisions
    "docs/superpowers/captures/",                # frozen probe captures
    "docs/audit/",                               # drain findings reference old names
    "tools/gates/check_banned_filename.py",      # this file (regex source)
    "tools/gates/prime_guard.py",                # sister enforcement gate
    ".git/",                                     # git internals
    "node_modules/",
    "build/",                                    # transient build outputs
    "builds/obj/",
    "builds/archive/",
    "builds/reports/",
]

# Allowed-context patterns (regex). Lines matching these are NOT failures
# even if they include a banned token — used for prose explaining the
# rename / retirement. Allowlist only what's necessary.
ALLOWED_CONTEXTS = [
    re.compile(r"\b(removed|retired|renamed|deprecated|banned|legacy|dead|killed|superseded)\b", re.IGNORECASE),
    re.compile(r"REMOVED.*whatif", re.IGNORECASE),
    re.compile(r"whatif.*REMOVED", re.IGNORECASE),
    re.compile(r"NEVER.*emit", re.IGNORECASE),
    re.compile(r"banned.*token", re.IGNORECASE),
    re.compile(r"banned.*filename", re.IGNORECASE),
    re.compile(r"banned.*alias", re.IGNORECASE),
    re.compile(r"sole.*target", re.IGNORECASE),
    re.compile(r"renamed\s+(to|from)\s+", re.IGNORECASE),
    re.compile(r"\(was\s+(Title|RoomRom|CombinedDebug)", re.IGNORECASE),
]

# The banned-token regex. All retired aliases live here.
BANNED_TOKEN = re.compile(
    r"\b("
    r"whatif"
    r"|Title\.md|Title\.lst|Title\.elf|Title\.o(?![A-Za-z_])"
    r"|RoomRom\.md"
    r"|CombinedDebug\.md|CombinedDebug\.bat|CombinedDebug\.lst"
    r"|CombinedDebug\.elf|CombinedDebug\.out"
    r"|combined_debug"
    r")\b",
    re.IGNORECASE,
)


def is_allowlisted(path: Path) -> bool:
    rel = path.relative_to(REPO).as_posix().lower()
    return any(p.lower() in rel for p in ALLOWLIST_PARTS)


def strip_comment(line: str, ext: str) -> str:
    """Return the non-comment portion of a line (best-effort, per file type)."""
    if ext in (".py", ".lua"):
        idx = line.find("#" if ext == ".py" else "--")
        return line if idx < 0 else line[:idx]
    if ext == ".bat":
        s = line.lstrip()
        if s.lower().startswith("rem "):
            return ""
        if s.startswith("::"):
            return ""
        return line
    if ext == ".ps1":
        idx = line.find("#")
        return line if idx < 0 else line[:idx]
    if ext in (".c", ".h"):
        idx = line.find("//")
        out = line if idx < 0 else line[:idx]
        out = re.sub(r"/\*.*?\*/", "", out)
        return out
    if ext in (".asm", ".s", ".S"):
        idx = line.find(";")
        return line if idx < 0 else line[:idx]
    if ext == ".md":
        # Markdown has no comment syntax we care about; whole line is body.
        return line
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
        if BANNED_TOKEN.search(body):
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
        print(
            "FAIL: banned legacy-alias token found in active code paths:",
            file=sys.stderr,
        )
        for path, line_no, body in failures:
            rel = path.relative_to(REPO).as_posix()
            print(f"  {rel}:{line_no}  {body[:120]}", file=sys.stderr)
        print(
            "\n  Sole-target rule (2026-05-08): the only ROM is Debug.md.\n"
            "  whatif / Title.md / RoomRom.md / CombinedDebug.* / combined_debug\n"
            "  are retired. Migrate the reference to Debug.md / Debug.bat\n"
            "  or move it under docs/archive/ (or another historical doc tree).",
            file=sys.stderr,
        )
        return 1

    print(
        f"OK: scanned {scanned} active code files; "
        "no banned legacy-alias token found."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
