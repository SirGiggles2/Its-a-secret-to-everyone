#!/usr/bin/env python3
"""Pre-commit gate: warn on Title-only path changes without RoomRom mirror.

Per debate roomrom-default-rule (2026-05-04, ACTION pre-commit) +
master plan Rule BT-1: anything done to Title.md should also be done to
RoomRom unless explicitly allowlisted as Title-only.

Mechanism:
  1. Read changed files from `git diff --cached --name-only` (or stdin
     when --staged-from-stdin given, for hook integration that pre-reads).
  2. For each changed path: classify as title-only / roomrom-only / shared
     / allowlisted using tools/gates/title_only_allowlist.txt.
  3. If commit touches Title-only paths (NOT allowlisted) without also
     touching RoomRom/, fail with a message listing the unmirrored paths.

This is a forced acknowledgment, not a hard block — operator can either
add a RoomRom mirror commit, or extend the allowlist with a comment
explaining why the path is Title-only.

Usage:
    python tools/gates/check_title_roomrom_parity.py        # hook mode
    python tools/gates/check_title_roomrom_parity.py --all  # check whole tree

Wire as a pre-commit hook in .git/hooks/pre-commit (or via plugin manager).
"""

from __future__ import annotations

import argparse
import fnmatch
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ALLOWLIST = REPO_ROOT / "tools" / "gates" / "title_only_allowlist.txt"

# Paths that classify as "Title-only domain" — anything under these,
# unless allowlisted, triggers the parity check.
TITLE_DOMAINS = [
    "build.bat",
    "data/intro/**",
    "data/fs/**",
    "data/chr/bosses.c",
    "data/chr/demo.c",
    "data/enemies/**",
    "data/misc/**",
    "data/text/**",
    "data/audio/**",
    "src/frontend/**",
    "src/oracle/**",
    "src/zelda_translated/**",
    "tools/intro_test/**",
    "tools/file_select_test/**",
    "tools/file_select_demo/**",
]

ROOMROM_DOMAIN = "RoomRom/**"


def load_allowlist() -> list[str]:
    if not ALLOWLIST.exists():
        return []
    out: list[str] = []
    for line in ALLOWLIST.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        out.append(line)
    return out


def is_title_domain(path: str) -> bool:
    return any(fnmatch.fnmatch(path, pat) for pat in TITLE_DOMAINS)


def is_roomrom_domain(path: str) -> bool:
    return fnmatch.fnmatch(path, ROOMROM_DOMAIN)


def is_allowlisted(path: str, allowlist: list[str]) -> bool:
    return any(fnmatch.fnmatch(path, pat) for pat in allowlist)


def changed_files_staged() -> list[str]:
    try:
        out = subprocess.check_output(
            ["git", "diff", "--cached", "--name-only"],
            cwd=REPO_ROOT, encoding="utf-8")
        return [ln.strip() for ln in out.splitlines() if ln.strip()]
    except subprocess.CalledProcessError as e:
        print(f"[check_title_roomrom_parity] git diff failed: {e}", file=sys.stderr)
        return []


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--all", action="store_true",
                    help="audit whole tree (else uses staged changes)")
    args = ap.parse_args(argv[1:])

    allowlist = load_allowlist()

    if args.all:
        # Audit current tree — list all Title-only files NOT allowlisted.
        try:
            out = subprocess.check_output(
                ["git", "ls-files"], cwd=REPO_ROOT, encoding="utf-8")
            files = [ln.strip() for ln in out.splitlines() if ln.strip()]
        except subprocess.CalledProcessError:
            files = []
        unmirrored = [
            f for f in files
            if is_title_domain(f) and not is_allowlisted(f, allowlist)
        ]
        if not unmirrored:
            print("[check_title_roomrom_parity] OK (no Title-only files outside allowlist)")
            return 0
        print(f"[check_title_roomrom_parity] {len(unmirrored)} Title-only files not allowlisted:",
              file=sys.stderr)
        for f in unmirrored[:30]:
            print(f"  {f}", file=sys.stderr)
        if len(unmirrored) > 30:
            print(f"  ...+{len(unmirrored) - 30}", file=sys.stderr)
        return 1

    # Staged-changes mode (pre-commit).
    files = changed_files_staged()
    if not files:
        return 0

    title_only_unmirrored = [
        f for f in files
        if is_title_domain(f) and not is_allowlisted(f, allowlist)
    ]
    touches_roomrom = any(is_roomrom_domain(f) for f in files)

    if title_only_unmirrored and not touches_roomrom:
        print("[check_title_roomrom_parity] WARN: Title-only paths changed without RoomRom mirror:",
              file=sys.stderr)
        for f in title_only_unmirrored[:20]:
            print(f"  {f}", file=sys.stderr)
        if len(title_only_unmirrored) > 20:
            print(f"  ...+{len(title_only_unmirrored) - 20}", file=sys.stderr)
        print("", file=sys.stderr)
        print("Either:", file=sys.stderr)
        print("  - Land a RoomRom-side mirror commit (touch RoomRom/ in this commit)", file=sys.stderr)
        print("  - Add path to tools/gates/title_only_allowlist.txt with a comment", file=sys.stderr)
        print("    explaining why the path is legitimately Title-only.", file=sys.stderr)
        print("", file=sys.stderr)
        print("Per master plan Rule BT-1 + debate roomrom-default-rule.", file=sys.stderr)
        return 1

    print(f"[check_title_roomrom_parity] OK ({len(files)} staged paths)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
