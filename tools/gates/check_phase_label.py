#!/usr/bin/env python3
"""check_phase_label.py — enforce master-plan task ID in commit messages.

Per debate 008 (2026-05-04): commits must cite a real master-plan label,
not invented sub-phases like "phase 4n". This gate runs against either
HEAD's commit message (precommit hook) or against a range of commits
(CI: HEAD~N..HEAD).

Master plan source-of-truth:
  docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md

Accepted commit-subject prefixes (case-insensitive):
  phase N           (master-plan Phase 0..17)
  phase N.M         (master-plan Task X.Y)
  phase N task N.M  (explicit task form)
  sN                (RoomRom milestone S0..S13)
  sN.N              (sub-milestone, e.g. s5.5)
  substrate         (Rule WT-1 main-only edits)
  docs              (documentation-only commits)
  state             (state contract / SRAM layout commits)
  tools             (tooling commits — gates, scripts, audits)
  fix               (bugfixes — must include phase pointer in body)
  revert            (revert commits)
  merge             (merge commits)
  debate NNN        (debate folder commits)
  gate              (gate / verification commits)

REJECTED:
  phase 4n / phase 5n / "phase Xn" — invented sub-labels not on master plan
  feat / chore / refactor — generic conventional-commit prefixes that
    don't point to the master plan
  bare commit messages with no project-scope label

Usage:
  python tools/gates/check_phase_label.py             # check HEAD only
  python tools/gates/check_phase_label.py --range N   # check HEAD~N..HEAD
  python tools/gates/check_phase_label.py --msg-file FILE  # precommit hook

Exit 0 if all checked commits match. Exit 1 with detailed report otherwise.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

# Pattern that ACCEPTS valid master-plan-aligned subject prefixes.
# Anchored at start, case-insensitive, allows leading "phase X task X.Y" form.
ACCEPT_PATTERN = re.compile(
    r"""^(
        phase\s+\d+(\.\d+)?(\s+task\s+\d+\.\d+)?  # phase N | phase N.M | phase N task N.M
      | s\d+(\.\d+[a-z]?)?                         # sN | sN.M | sN.Mb (RoomRom milestones)
      | substrate                                  # Rule WT-1 substrate edits
      | docs                                       # docs-only
      | state                                      # state contract
      | tools                                      # tooling
      | fix                                        # bugfixes
      | revert                                     # reverts
      | merge                                      # merges
      | debate\s+\d+                               # debate commits
      | gate                                       # gate / verification
    )\b""",
    re.IGNORECASE | re.VERBOSE,
)

# Pattern that REJECTS known bad sub-labels even if they look phase-like.
# "phase 4n" matches phase\s+\d+ partially but the trailing letter is the tell.
REJECT_PATTERN = re.compile(
    r"^phase\s+\d+[a-z]\b",
    re.IGNORECASE,
)


def get_subject_for_ref(ref: str) -> str:
    """git log -1 --format=%s <ref>."""
    out = subprocess.check_output(
        ["git", "log", "-1", "--format=%s", ref],
        cwd=REPO,
        text=True,
    )
    return out.strip()


def get_subjects_in_range(n: int) -> list[tuple[str, str]]:
    """Return [(sha, subject)] for HEAD~N..HEAD."""
    out = subprocess.check_output(
        ["git", "log", f"HEAD~{n}..HEAD", "--format=%H%x09%s"],
        cwd=REPO,
        text=True,
    )
    pairs: list[tuple[str, str]] = []
    for line in out.strip().splitlines():
        if "\t" in line:
            sha, subject = line.split("\t", 1)
            pairs.append((sha[:8], subject.strip()))
    return pairs


def check_subject(subject: str) -> tuple[bool, str]:
    """Return (ok, reason)."""
    if REJECT_PATTERN.match(subject):
        return False, (
            f"INVENTED SUB-LABEL — subject starts with 'phase Nx' which is "
            f"NOT on the master plan. Use 'phase N task N.M:' or 'phase N:' "
            f"or 'substrate:' / 'tools:' / 'docs:' instead."
        )
    if not ACCEPT_PATTERN.match(subject):
        return False, (
            f"NO MASTER-PLAN POINTER — subject does not start with a "
            f"recognized prefix. Allowed: 'phase N(.M) [task N.M]:', 'sN[.M]:', "
            f"'substrate:', 'docs:', 'state:', 'tools:', 'fix:', 'gate:', "
            f"'debate NNN:', 'revert:', 'merge:'."
        )
    return True, "ok"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument(
        "--range",
        type=int,
        default=0,
        help="check HEAD~N..HEAD instead of HEAD only",
    )
    ap.add_argument(
        "--msg-file",
        type=Path,
        default=None,
        help="path to a commit message file (precommit hook mode)",
    )
    args = ap.parse_args()

    if args.msg_file:
        subject = args.msg_file.read_text(encoding="utf-8").strip().splitlines()[0]
        ok, reason = check_subject(subject)
        if not ok:
            print(
                f"check_phase_label: REJECT precommit subject\n"
                f"  subject: {subject!r}\n"
                f"  reason : {reason}\n"
                f"  fix    : edit COMMIT_EDITMSG to start with a master-plan label\n"
                f"  ref    : docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md",
                file=sys.stderr,
            )
            return 1
        return 0

    if args.range > 0:
        pairs = get_subjects_in_range(args.range)
    else:
        subject = get_subject_for_ref("HEAD")
        sha = subprocess.check_output(
            ["git", "rev-parse", "--short=8", "HEAD"], cwd=REPO, text=True
        ).strip()
        pairs = [(sha, subject)]

    failed = []
    for sha, subject in pairs:
        ok, reason = check_subject(subject)
        if not ok:
            failed.append((sha, subject, reason))

    if failed:
        print("check_phase_label: REJECTED commits", file=sys.stderr)
        for sha, subject, reason in failed:
            print(f"  {sha}  {subject}", file=sys.stderr)
            print(f"          -> {reason}", file=sys.stderr)
        print(
            f"\nFix: amend / rewrite commit messages to cite a master-plan task ID.\n"
            f"Master plan: docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md",
            file=sys.stderr,
        )
        return 1

    if args.range > 0:
        print(f"check_phase_label: OK ({len(pairs)} commits)")
    else:
        print(f"check_phase_label: OK ({pairs[0][0]} {pairs[0][1]!r})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
