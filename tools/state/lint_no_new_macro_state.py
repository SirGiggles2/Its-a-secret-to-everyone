#!/usr/bin/env python3
"""
lint_no_new_macro_state.py — Workstream G: Pre-commit Hook

Fails if any staged diff ADDS a RAM() or OBJ() callsite in a file that is
not one of the two sanctioned headers:

    src/abi/nes_ram_mirror.h
    src/abi/platform_abi.h

Per state_contract.md Migration Rule 1:
  "No new code may add a RAM() or OBJ() macro definition. Every new state
   field is a typed struct field."

Usage (standalone):
    python tools/state/lint_no_new_macro_state.py [--repo-root PATH]

Usage as a pre-commit hook (add to .git/hooks/pre-commit or via
.pre-commit-config.yaml):
    python tools/state/lint_no_new_macro_state.py

Exit codes:
    0 — clean (no new RAM()/OBJ() callsites in disallowed files)
    1 — violation found (detailed report on stdout)
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Sanctioned files where RAM() / OBJ() definitions ARE allowed
# ---------------------------------------------------------------------------
ALLOWED_PATHS = frozenset({
    "src/abi/nes_ram_mirror.h",
    "src/abi/platform_abi.h",
})

# Pattern: a line that ADDS (starts with +) a RAM( or OBJ( token.
# We look for the macro call site, not just the word "RAM" or "OBJ".
_ADDED_LINE = re.compile(r"^\+(?!\+\+)")           # diff added line, not the +++ header
_CALLSITE = re.compile(r"\b(RAM|OBJ)\s*\(")        # RAM( or OBJ( token

# ---------------------------------------------------------------------------
# Diff parser
# ---------------------------------------------------------------------------

def get_staged_diff(repo_root: Path) -> str:
    result = subprocess.run(
        ["git", "diff", "--cached", "--unified=0"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    return result.stdout


def parse_violations(diff: str) -> list[dict]:
    """
    Walk the unified diff and collect every added line that contains a
    RAM()/OBJ() callsite in a file not in ALLOWED_PATHS.
    Returns a list of {file, lineno, content} dicts.
    """
    violations: list[dict] = []
    current_file: str | None = None
    current_new_lineno = 0

    for raw_line in diff.splitlines():
        # Track current file
        if raw_line.startswith("+++ b/"):
            current_file = raw_line[6:]  # strip "+++ b/"
            current_new_lineno = 0
            continue
        if raw_line.startswith("@@"):
            # @@ -a,b +c,d @@  — extract c
            m = re.search(r"\+(\d+)", raw_line)
            if m:
                current_new_lineno = int(m.group(1)) - 1
            continue

        # Track line numbers on new-file side
        if not raw_line.startswith("-"):
            current_new_lineno += 1

        # Only care about added lines
        if not _ADDED_LINE.match(raw_line):
            continue

        content = raw_line[1:]  # strip the leading '+'

        # Skip comment-only lines
        stripped = content.strip()
        if stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/*"):
            continue

        if not _CALLSITE.search(content):
            continue

        # Check whether this file is in the allowed list.
        # Normalize path separators for comparison.
        norm_file = (current_file or "").replace("\\", "/")
        if any(norm_file.endswith(a) for a in ALLOWED_PATHS):
            continue

        violations.append({
            "file": current_file or "(unknown)",
            "lineno": current_new_lineno,
            "content": content.rstrip(),
        })

    return violations


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=None,
        help="Repository root (default: two levels up from this script's directory)",
    )
    args = parser.parse_args()

    if args.repo_root:
        repo_root = Path(args.repo_root).resolve()
    else:
        repo_root = Path(__file__).resolve().parent.parent.parent

    diff = get_staged_diff(repo_root)
    violations = parse_violations(diff)

    if not violations:
        print("OK: no new RAM()/OBJ() callsites outside sanctioned headers.")
        return 0

    print(f"FAIL: {len(violations)} new RAM()/OBJ() callsite(s) found outside sanctioned headers.\n")
    print("Per state_contract.md Migration Rule 1: no new code may add a RAM() or")
    print("OBJ() macro definition. Every new state field must be a typed struct field.")
    print(f"\nSanctioned headers (exempt): {', '.join(sorted(ALLOWED_PATHS))}\n")

    for v in violations:
        print(f"  {v['file']}:{v['lineno']}")
        print(f"    {v['content']}")
        print()

    print("To fix: define a typed struct field in the appropriate src/state/*.h instead.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
