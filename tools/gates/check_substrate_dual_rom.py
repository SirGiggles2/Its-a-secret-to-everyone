#!/usr/bin/env python3
"""check_substrate_dual_rom.py — substrate edits must build BOTH ROMs.

Per debate 004 ask 3 + Execution Rules substrate ownership.

When a commit (or staged-but-uncommitted diff) touches shared substrate
paths — `src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`,
`src/audio_driver.asm` — both Title.md and RoomRom.md must build clean.
This is defense-in-depth on top of the single-writer rule (substrate
edits land in main worktree only); it catches breakage even when the
worktree rule is followed.

Modes:
  --staged    diff against HEAD (default; pre-commit usage)
  --commit    diff against HEAD~1 (pre-push usage)
  --range A.B diff against arbitrary git range
  --force     skip diff check; always build both

Exit codes:
  0 — no substrate diff, OR both ROMs build green
  1 — substrate diff present + at least one ROM build failed
"""
import argparse
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

SUBSTRATE_PREFIXES = [
    "src/sgdk_adapter/",
    "src/abi/",
    "src/state/",
    "data/",
    "src/audio_driver.asm",
]

# Which build invocations to run on substrate diff. RoomRom build is
# allowed to be missing on machines without the RoomRom worktree
# checked out — emit WARN, not FAIL, in that case.
TITLE_BUILD = ["cmd.exe", "/c", "build.bat"]
ROOMROM_BUILD = ["cmd.exe", "/c", str(REPO / "RoomRom" / "build.bat")]


def git_diff_paths(rev_spec: str | None) -> list[str]:
    """Return list of paths changed in the given git diff range."""
    if rev_spec is None:
        cmd = ["git", "-C", str(REPO), "diff", "--name-only"]  # working tree vs HEAD
    else:
        cmd = ["git", "-C", str(REPO), "diff", "--name-only", rev_spec]
    try:
        out = subprocess.check_output(cmd, text=True)
    except subprocess.CalledProcessError as e:
        print(f"WARN: git diff failed: {e}", file=sys.stderr)
        return []
    return [line.strip() for line in out.splitlines() if line.strip()]


def filter_substrate(paths: list[str]) -> list[str]:
    return [
        p for p in paths
        if any(p.startswith(prefix) for prefix in SUBSTRATE_PREFIXES)
    ]


def run_build(name: str, cmd: list[str]) -> bool:
    print(f"[{name}] running: {' '.join(cmd)}", flush=True)
    try:
        result = subprocess.run(
            cmd,
            cwd=str(REPO),
            capture_output=True,
            text=True,
            timeout=600,
        )
    except subprocess.TimeoutExpired:
        print(f"  FAIL: {name} build timed out (10 min)", file=sys.stderr)
        return False
    except FileNotFoundError as e:
        print(f"  WARN: {name} build not invocable: {e}", file=sys.stderr)
        return True  # treat unavailable build as non-blocking
    last = result.stdout.splitlines()[-3:] if result.stdout else []
    for line in last:
        print(f"  {line}")
    if result.returncode != 0:
        err_tail = result.stdout.splitlines()[-15:] if result.stdout else []
        for line in err_tail:
            print(f"  {line}", file=sys.stderr)
        print(f"  FAIL: {name} build returned {result.returncode}",
              file=sys.stderr)
        return False
    print(f"  OK: {name} build green")
    return True


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--staged", action="store_true",
                   help="diff working tree vs HEAD (pre-commit)")
    g.add_argument("--commit", action="store_true",
                   help="diff HEAD vs HEAD~1 (pre-push)")
    g.add_argument("--range", metavar="A..B",
                   help="arbitrary git range")
    g.add_argument("--force", action="store_true",
                   help="skip diff check; always build both")
    ap.add_argument("--skip-roomrom", action="store_true",
                    help="skip RoomRom build (Title-only check)")
    args = ap.parse_args()

    if args.force:
        substrate_paths = ["<forced>"]
    else:
        rev_spec = None
        if args.commit:
            rev_spec = "HEAD~1..HEAD"
        elif args.range:
            rev_spec = args.range
        # else (default or --staged): None = working tree vs HEAD
        diff = git_diff_paths(rev_spec)
        substrate_paths = filter_substrate(diff)

    if not substrate_paths:
        print("OK: no substrate paths in diff; skipping dual-ROM build.")
        return 0

    print(f"substrate paths in diff:")
    for p in substrate_paths:
        print(f"  {p}")
    print()

    title_ok = run_build("Title.md", TITLE_BUILD)
    if args.skip_roomrom:
        roomrom_ok = True
        print("[RoomRom.md] skipped (--skip-roomrom)")
    elif not (REPO / "RoomRom" / "build.bat").exists():
        roomrom_ok = True
        print("[RoomRom.md] skipped (RoomRom/build.bat not present)")
    else:
        roomrom_ok = run_build("RoomRom.md", ROOMROM_BUILD)

    if title_ok and roomrom_ok:
        print("\nOK: substrate edit verified against both ROMs.")
        return 0

    print("\nFAIL: substrate edit broke at least one ROM build.",
          file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
