#!/usr/bin/env python3
"""
verify_worktree_state.py — Worktree merge protocol verifier.

Checks:
  1. Both worktrees (main + RoomRom) are registered with git.
  2. Both worktrees have no dirty files.
  3. roomrom-s1 has rebased cleanly on main (no commits behind, or ahead only).

Exit 0: WORKTREE STATE: GREEN
Exit 1: WORKTREE STATE: RED  (reason printed)

See docs/audit/worktree_merge_protocol.md for the full protocol.
"""

import subprocess
import sys
import os
import re

# ---------------------------------------------------------------------------
# Expected worktree paths (normalised to forward-slash, lower-case for match)
# ---------------------------------------------------------------------------
MAIN_BRANCH = "main"
ROOMROM_BRANCH = "roomrom-s1"

# Canonical path fragments that identify each worktree (case-insensitive)
MAIN_PATH_FRAGMENT = "FINAL TRY"
ROOMROM_PATH_FRAGMENT = "FINAL TRY-roomrom-s1"


def run(cmd, cwd=None, check=False):
    """Run a shell command and return (stdout, stderr, returncode)."""
    result = subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
        shell=False,
    )
    return result.stdout.strip(), result.stderr.strip(), result.returncode


def parse_worktree_list():
    """
    Run `git worktree list --porcelain` and return a list of dicts:
      { 'path': str, 'HEAD': str, 'branch': str }
    branch may be None for detached HEAD.
    """
    stdout, stderr, rc = run(["git", "worktree", "list", "--porcelain"])
    if rc != 0:
        return None, f"git worktree list failed: {stderr}"

    worktrees = []
    current = {}
    for line in stdout.splitlines():
        if line.startswith("worktree "):
            if current:
                worktrees.append(current)
            current = {"path": line[len("worktree "):], "HEAD": None, "branch": None}
        elif line.startswith("HEAD "):
            current["HEAD"] = line[5:]
        elif line.startswith("branch "):
            # branch refs/heads/main  →  main
            ref = line[7:]
            current["branch"] = ref.replace("refs/heads/", "")
        elif line == "bare":
            current["bare"] = True
    if current:
        worktrees.append(current)

    return worktrees, None


def find_worktree(worktrees, path_fragment):
    """Find a worktree whose path contains path_fragment (case-insensitive)."""
    fragment_lower = path_fragment.lower()
    for wt in worktrees:
        # Normalise separators for comparison
        norm = wt["path"].replace("\\", "/").lower()
        if fragment_lower.lower() in norm:
            return wt
    return None


def check_dirty(worktree_path):
    """
    Return list of dirty files in the given worktree path.
    Empty list means clean.
    """
    stdout, stderr, rc = run(
        ["git", "-C", worktree_path, "status", "--porcelain"]
    )
    if rc != 0:
        return None, f"git status failed in {worktree_path}: {stderr}"
    lines = [l for l in stdout.splitlines() if l.strip()]
    return lines, None


def check_rebase_state(roomrom_path, main_wt):
    """
    Check whether roomrom-s1 is up-to-date with (or ahead of) main.
    Returns (is_clean: bool, reason: str).

    Strategy: compare commit graphs.
      - Count commits in roomrom-s1 that are NOT in main  → ahead
      - Count commits in main that are NOT in roomrom-s1  → behind (bad)
    We use git rev-list with the main worktree's HEAD as the base.
    """
    main_head = main_wt.get("HEAD")
    if not main_head:
        return False, "Could not determine main worktree HEAD commit."

    # How many commits is roomrom-s1 behind main?
    stdout, stderr, rc = run(
        ["git", "-C", roomrom_path, "rev-list", "--count",
         f"HEAD..{main_head}"]
    )
    if rc != 0:
        # main_head may not be reachable from the RoomRom worktree's remote
        # refs — try fetching.
        return False, (
            f"Could not compare roomrom-s1 HEAD to main HEAD ({main_head}). "
            f"Ensure both worktrees share git object history. "
            f"Error: {stderr}"
        )

    behind_count = int(stdout.strip() or "0")

    # How many commits is roomrom-s1 ahead of main?
    stdout2, _, rc2 = run(
        ["git", "-C", roomrom_path, "rev-list", "--count",
         f"{main_head}..HEAD"]
    )
    ahead_count = int(stdout2.strip() or "0") if rc2 == 0 else -1

    if behind_count > 0:
        return False, (
            f"roomrom-s1 is {behind_count} commit(s) behind main. "
            f"Run: git rebase origin/main  (from the RoomRom worktree)."
        )

    return True, f"roomrom-s1 is {ahead_count} commit(s) ahead of main (rebase clean)."


def main():
    red_reasons = []

    # ------------------------------------------------------------------
    # 1. Parse worktree list
    # ------------------------------------------------------------------
    worktrees, err = parse_worktree_list()
    if err:
        print(f"ERROR: {err}")
        print("WORKTREE STATE: RED — could not enumerate worktrees.")
        sys.exit(1)

    print("Registered worktrees:")
    for wt in worktrees:
        branch_label = wt.get("branch") or "(detached)"
        print(f"  {wt['path']}  [{branch_label}]  HEAD={wt.get('HEAD','?')[:12]}")
    print()

    # ------------------------------------------------------------------
    # 2. Identify main and RoomRom worktrees
    # ------------------------------------------------------------------
    main_wt = find_worktree(worktrees, MAIN_PATH_FRAGMENT)
    roomrom_wt = find_worktree(worktrees, ROOMROM_PATH_FRAGMENT)

    # Disambiguate: main worktree must not match the roomrom fragment
    if main_wt and ROOMROM_PATH_FRAGMENT.lower() in main_wt["path"].replace("\\", "/").lower():
        # find_worktree found roomrom for main — pick the other one
        main_wt = next(
            (wt for wt in worktrees
             if ROOMROM_PATH_FRAGMENT.lower() not in wt["path"].replace("\\", "/").lower()
             and wt.get("branch") == MAIN_BRANCH),
            None,
        )

    if main_wt is None:
        red_reasons.append(
            f"Main worktree (branch '{MAIN_BRANCH}') not found in worktree list."
        )
    else:
        print(f"Main worktree  : {main_wt['path']}")

    if roomrom_wt is None:
        red_reasons.append(
            f"RoomRom worktree (path fragment '{ROOMROM_PATH_FRAGMENT}') not found. "
            f"Re-add with: git worktree add "
            f"\"C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY-roomrom-s1\" roomrom-s1"
        )
    else:
        print(f"RoomRom worktree: {roomrom_wt['path']}")
    print()

    # ------------------------------------------------------------------
    # 3. Dirty file check — main worktree
    # ------------------------------------------------------------------
    if main_wt:
        dirty, err = check_dirty(main_wt["path"])
        if err:
            red_reasons.append(f"Main dirty-check error: {err}")
        elif dirty:
            red_reasons.append(
                f"Main worktree has {len(dirty)} dirty file(s):\n"
                + "\n".join(f"  {l}" for l in dirty)
            )
        else:
            print("Main worktree    : clean")

    # ------------------------------------------------------------------
    # 4. Dirty file check — RoomRom worktree
    # ------------------------------------------------------------------
    if roomrom_wt:
        dirty, err = check_dirty(roomrom_wt["path"])
        if err:
            red_reasons.append(f"RoomRom dirty-check error: {err}")
        elif dirty:
            red_reasons.append(
                f"RoomRom worktree has {len(dirty)} dirty file(s):\n"
                + "\n".join(f"  {l}" for l in dirty)
            )
        else:
            print("RoomRom worktree : clean")

    # ------------------------------------------------------------------
    # 5. Rebase state: roomrom-s1 up-to-date with main
    # ------------------------------------------------------------------
    if main_wt and roomrom_wt:
        ok, msg = check_rebase_state(roomrom_wt["path"], main_wt)
        if ok:
            print(f"Rebase state     : {msg}")
        else:
            red_reasons.append(f"Rebase state: {msg}")

    print()

    # ------------------------------------------------------------------
    # 6. Verdict
    # ------------------------------------------------------------------
    if not red_reasons:
        print("WORKTREE STATE: GREEN — RoomRom up-to-date with main, both clean")
        sys.exit(0)
    else:
        print("WORKTREE STATE: RED")
        for i, reason in enumerate(red_reasons, 1):
            print(f"  [{i}] {reason}")
        sys.exit(1)


if __name__ == "__main__":
    main()
