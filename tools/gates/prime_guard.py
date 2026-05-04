#!/usr/bin/env python3
"""prime_guard.py — pre-action enforcement for the Prime Directive.

Intents:
  edit         — pre-edit check for high-risk paths (substrate, src/game, build.bat, src/frontend)
  build        — pre-build check (no whatif emission, SGDK pin)
  close-phase  — phase-close gate runner; walks 11 steps, blocks on missing artifacts

Exit codes:
  0  PROCEED
  1  WARN (proceed with explicit reason)
  2  BLOCK (refuse action)

Examples:
  python tools/gates/prime_guard.py --intent edit --paths src/state/foo.c
  python tools/gates/prime_guard.py --intent edit --check-content src/game/hud/hud_runtime.c
  python tools/gates/prime_guard.py --intent build
  python tools/gates/prime_guard.py --intent close-phase --phase 1.5
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, OSError):
        pass

REPO = Path(__file__).resolve().parents[2]
TRACKER = REPO / "docs" / "superpowers" / "prime_directive_tracker.json"
DRAIN_COVERAGE = REPO / "tools" / "audit" / "drain_coverage.json"
BUILD_BAT = REPO / "build.bat"

SUBSTRATE_PATHS = (
    "src/sgdk_adapter/",
    "src/abi/",
    "src/state/",
    "data/",
    "src/audio_driver.asm",
)

HIGH_RISK_PATHS = SUBSTRATE_PATHS + (
    "src/game/",
    "src/frontend/",
    "build.bat",
    "tools/builder/",
    "Title.md",
    "RoomRom.md",
    "Final.md",
)

D1_HEADER_RE = re.compile(
    r"NES\s*source\s*[:=].*?\n.*?Drained\s*C\s*[:=].*?\n.*?Coverage\s*[:=].*?\n.*?Stance\s*[:=]",
    re.IGNORECASE | re.DOTALL,
)


def git(*args: str) -> str:
    r = subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True, check=False)
    return r.stdout.strip()


def load_tracker() -> dict:
    if not TRACKER.exists():
        return {}
    try:
        return json.loads(TRACKER.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def load_drain() -> dict:
    if not DRAIN_COVERAGE.exists():
        return {}
    try:
        return json.loads(DRAIN_COVERAGE.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def matches_any(p: str, prefixes: tuple[str, ...]) -> bool:
    return any(p == pref or p.startswith(pref) for pref in prefixes)


def cmd_edit(paths: list[str], check_content: list[str]) -> tuple[int, list[str]]:
    msgs: list[str] = []
    rc = 0
    tr = load_tracker()
    branch = tr.get("active", {}).get("worktree", {}).get("branch") or git("rev-parse", "--abbrev-ref", "HEAD")
    is_substrate_writer = branch == "main"

    for p in paths:
        norm = p.replace("\\", "/")
        if matches_any(norm, SUBSTRATE_PATHS) and not is_substrate_writer:
            msgs.append(f"BLOCK: substrate edit on non-main worktree (branch={branch}): {norm}  [WT-1]")
            rc = max(rc, 2)
        if "whatif" in norm.lower():
            msgs.append(f"BLOCK: whatif path forbidden: {norm}  [WT-4]")
            rc = max(rc, 2)
        if norm.startswith("src/game/") and not matches_any(norm, HIGH_RISK_PATHS[:0]):
            msgs.append(f"NOTE: src/game path requires D1 4-line header — see references/hard-rules.md")

    for f in check_content:
        path = REPO / f
        if not path.exists():
            msgs.append(f"WARN: --check-content path missing: {f}")
            rc = max(rc, 1)
            continue
        head = "\n".join(path.read_text(encoding="utf-8", errors="ignore").splitlines()[:30])
        if f.replace("\\", "/").startswith("src/game/") and not D1_HEADER_RE.search(head):
            msgs.append(f"BLOCK: D1 4-line header missing in {f}  [D1]")
            rc = max(rc, 2)

    return rc, msgs


def cmd_build() -> tuple[int, list[str]]:
    msgs: list[str] = []
    rc = 0
    # Rule BT-1 banner — always emit on build-intent invocations so the
    # operator (or Claude) reads "default = RoomRom" before any build runs.
    msgs.append(
        "NOTE [Rule BT-1]: active build target = RoomRom\\build.bat. "
        "Root build.bat (Title.md) is gated and refuses without "
        "TITLE_BUILD_APPROVED=1 — Phase 11-12 only, explicit user approval."
    )
    if BUILD_BAT.exists():
        for ln in BUILD_BAT.read_text(encoding="utf-8", errors="ignore").splitlines():
            stripped = ln.strip().lower()
            if not stripped or stripped.startswith("rem ") or stripped.startswith("::") or stripped.startswith("echo "):
                continue
            if "check_no_whatif" in stripped:
                continue
            if re.search(r"\bwhatif\b", stripped):
                msgs.append(f"BLOCK: build.bat emits whatif (must be Title.*) [WT-4]: {ln.strip()[:80]}")
                rc = 2
    return rc, msgs


def cmd_close_phase(phase_id: str) -> tuple[int, list[str]]:
    tr = load_tracker()
    msgs: list[str] = []
    if not tr:
        return 2, ["BLOCK: tracker missing — run prime_refresh.py"]
    phase = next((p for p in tr.get("phases", []) if p["id"] == phase_id), None)
    if not phase:
        return 2, [f"BLOCK: unknown phase {phase_id}"]
    gate = phase.get("close_gate", {})
    pending = [k for k, v in gate.items() if v == "pending"]
    if pending:
        msgs.append(f"BLOCK: phase {phase_id} has {len(pending)} pending gate step(s):")
        for k in pending:
            msgs.append(f"  - {k}")
        return 2, msgs
    msgs.append(f"PROCEED: phase {phase_id} all 11 gate steps satisfied; safe to commit phase-close.")
    return 0, msgs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--intent", required=True, choices=["edit", "build", "close-phase"])
    ap.add_argument("--paths", nargs="*", default=[])
    ap.add_argument("--check-content", nargs="*", default=[])
    ap.add_argument("--phase")
    args = ap.parse_args()

    if args.intent == "edit":
        rc, msgs = cmd_edit(args.paths, args.check_content)
    elif args.intent == "build":
        rc, msgs = cmd_build()
    elif args.intent == "close-phase":
        if not args.phase:
            print("ERROR: --phase required for close-phase", file=sys.stderr)
            return 2
        rc, msgs = cmd_close_phase(args.phase)
    else:
        return 2

    for m in msgs:
        print(m)
    if not msgs:
        print("PROCEED")
    return rc


if __name__ == "__main__":
    sys.exit(main())
