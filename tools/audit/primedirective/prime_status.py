#!/usr/bin/env python3
"""prime_status.py — read-only Prime Directive tracker freshness check.

Exit codes:
  0  FRESH
  1  STALE (re-run prime_refresh.py)
  2  BLOCKED (active blocker; user must clear)

Output modes:
  --brief  one-line BRIEF status (≤72 chars)
  --full   multi-line FULL status (≤25 lines)
  --json   raw tracker JSON
  default = --brief
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, OSError):
        pass

REPO = Path(__file__).resolve().parents[3]
TRACKER = REPO / "docs" / "superpowers" / "prime_directive_tracker.json"
PLAN = REPO / "docs" / "superpowers" / "plans" / "2026-05-02-title-roomrom-full-port-master-plan.md"
ACTIVE_SCOPE_MD = REPO / "docs" / "audit" / "active_scope.md"
DRAIN_COVERAGE = REPO / "tools" / "audit" / "drain_coverage.json"
STATUS_MD = REPO / "docs" / "superpowers" / "prime_directive_status.md"

STALE_AGE_HOURS = 24


def sha256_path(p: Path) -> str | None:
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def git(*args: str) -> str:
    r = subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True, check=False)
    return r.stdout.strip()


def load_tracker() -> dict | None:
    if not TRACKER.exists():
        return None
    try:
        return json.loads(TRACKER.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def detect_staleness(tr: dict) -> list[str]:
    reasons: list[str] = []

    plan_sha = sha256_path(PLAN)
    if plan_sha and plan_sha != tr.get("plan", {}).get("sha256"):
        reasons.append("plan_sha_drift")

    active_scope_check = tr.get("freshness", {}).get("active_scope_md", {})
    cur_active_sha = sha256_path(ACTIVE_SCOPE_MD)
    if cur_active_sha and cur_active_sha != active_scope_check.get("sha256"):
        reasons.append("active_scope_md_drift")
    if active_scope_check.get("path") and not ACTIVE_SCOPE_MD.exists():
        reasons.append("active_scope_md_missing")

    drain_check = tr.get("freshness", {}).get("drain_coverage_json", {})
    cur_drain_sha = sha256_path(DRAIN_COVERAGE)
    if cur_drain_sha and cur_drain_sha != drain_check.get("sha256"):
        reasons.append("drain_coverage_drift")

    cur_head = git("rev-parse", "HEAD")
    if cur_head and cur_head != tr.get("freshness", {}).get("git_head"):
        reasons.append("git_head_advanced")

    last = tr.get("freshness", {}).get("last_refresh_at")
    if last:
        try:
            last_dt = dt.datetime.fromisoformat(last.replace("Z", "+00:00"))
            now = dt.datetime.now(dt.timezone.utc)
            if (now - last_dt).total_seconds() > STALE_AGE_HOURS * 3600:
                reasons.append(f"age_exceeds_{STALE_AGE_HOURS}h")
        except (ValueError, TypeError):
            reasons.append("last_refresh_unparseable")

    for ph in tr.get("phases", []):
        for ev in ph.get("evidence", []):
            if not isinstance(ev, str):
                continue
            if ev.startswith("commit:"):
                continue
            # Format: "<step>|<path-or-note>" — strip step prefix, then take
            # everything up to first space (path) and verify if it looks like
            # a repo path. Notes (containing parens) are skipped.
            payload = ev.split("|", 1)[-1] if "|" in ev else ev
            head = payload.split()[0] if payload else ""
            if not head or "(" in head or "/" not in head:
                continue
            if not (REPO / head).exists():
                reasons.append(f"evidence_missing:{head}")

    seen_complete = False
    seen_active = False
    for ph in tr.get("phases", []):
        if ph.get("status") == "complete":
            seen_complete = True
        if ph.get("status") == "active":
            seen_active = True
    if seen_complete and not seen_active and len(tr.get("phases", [])) < 18:
        reasons.append("complete_without_successor_active")

    return reasons


def format_brief(tr: dict, stale: list[str]) -> str:
    if not tr:
        return "[PD] tracker_missing ← run prime_refresh.py"
    a = tr.get("active", {})
    phase = a.get("phase_id", "?")
    task = a.get("task_id", "?")
    wt = a.get("worktree", {}).get("branch", "?")
    gate = next((p for p in tr.get("phases", []) if p.get("id") == phase), {}).get("close_gate", {})
    passed = sum(1 for v in gate.values() if v == "passed")
    total = sum(1 for v in gate.values() if v not in ("not_applicable", None))
    nblock = len(tr.get("blockers", []))
    line = f"[PD] Ph{phase} | task {task} | WT {wt} | {passed}/{total} gates | {nblock} blocking"
    suffixes = []
    if nblock > 0:
        suffixes.append("← CHECK")
    if stale:
        suffixes.append("← STALE")
    if tr.get("out_of_phase_tasks"):
        suffixes.append("← OUT-OF-PHASE")
    if suffixes:
        line += " " + " ".join(suffixes)
    return line


def format_full(tr: dict, stale: list[str]) -> str:
    if not tr:
        return "PRIME DIRECTIVE TRACKER MISSING - run: python tools/audit/primedirective/prime_refresh.py"
    a = tr.get("active", {})
    out = [
        "+========== PRIME DIRECTIVE STATUS ==========+",
        f"  Phase:      {a.get('phase_id','?')} - {a.get('phase_name','?')}",
        f"  Task:       {a.get('task_id','?')} - {a.get('task_title','?')}",
        f"  Worktree:   {a.get('worktree',{}).get('branch','?')}  ({a.get('worktree',{}).get('path','?')})",
    ]
    phase = next((p for p in tr.get("phases", []) if p.get("id") == a.get("phase_id")), {})
    gate = phase.get("close_gate", {})
    if gate:
        passed = [k for k, v in gate.items() if v == "passed"]
        pending = [k for k, v in gate.items() if v == "pending"]
        out.append(f"  Gates pass: {len(passed)}/{len(gate)}")
        if pending:
            out.append(f"  Pending:    {', '.join(pending[:3])}{'...' if len(pending) > 3 else ''}")
    blockers = tr.get("blockers", [])
    if blockers:
        out.append("  BLOCKERS:")
        for b in blockers[:3]:
            out.append(f"    - {b.get('kind','?')}: {b.get('description','?')[:50]}")
    oop = tr.get("out_of_phase_tasks", [])
    if oop:
        out.append(f"  Out-of-phase tasks: {len(oop)}")
    if stale:
        out.append(f"  STALE: {', '.join(stale[:3])}{'...' if len(stale) > 3 else ''}")
    out.append(f"  Next:       {a.get('next_concrete_action','?')[:50]}")
    out.append("+============================================+")
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--brief", action="store_const", const="brief", dest="mode")
    g.add_argument("--full", action="store_const", const="full", dest="mode")
    g.add_argument("--json", action="store_const", const="json", dest="mode")
    ap.set_defaults(mode="brief")
    args = ap.parse_args()

    tr = load_tracker()
    if tr is None:
        if args.mode == "json":
            print(json.dumps({"state": "MISSING"}))
        else:
            print(format_brief(None, ["tracker_missing"]) if args.mode == "brief" else format_full(None, []))
        return 1

    stale = detect_staleness(tr)
    blocked = bool(tr.get("blockers"))

    if args.mode == "json":
        print(json.dumps({
            "state": "BLOCKED" if blocked else ("STALE" if stale else "FRESH"),
            "stale_reasons": stale,
            "blockers": tr.get("blockers", []),
            "tracker": tr,
        }, indent=2))
    elif args.mode == "full":
        print(format_full(tr, stale))
    else:
        print(format_brief(tr, stale))

    if blocked:
        return 2
    if stale:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
