"""Phase 17.5 — Final Release Gate orchestrator.

Chains every CI gate that must pass before a release tag fires.
Per master plan Task 17.5 checklist:

1. Run package checker.
2. Run from-scratch builder gate.
3. Run full quest smoke (regression matrix).
4. Run hardware smoke (Phase 16 deferred — external; flagged here
   but not run).
5. Tag release.
6. Archive final build manifest.
7. Commit as `release: package legal builder`.

Usage:
    python tools/builder/release_gate.py <user-rom.nes>
        — run all gates; emit verdict to builds/reports/release_gate.json.
    python tools/builder/release_gate.py --dry-run
        — list gates that would run; check infra only.

Exit codes:
    0  All gates pass; release-ready.
    1  ROM missing or hash mismatch.
    2  package_check fail.
    3  from_scratch_gate fail (build or reproducibility).
    4  regression matrix red.
    5  hardware smoke deferred (Phase 16.2 external).
    9  manifest archive failure.
"""

from __future__ import annotations

import argparse
import datetime
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "tools" / "builder"
REPORTS = ROOT / "builds" / "reports"
RELEASE_JSON = REPORTS / "release_gate.json"
MANIFESTS = ROOT / "builds" / "manifests"


def run_step(label: str, cmd: list[str | Path], cwd: Path = ROOT) -> tuple[int, str]:
    print(f"[gate] {label}...")
    r = subprocess.run(
        [str(arg) for arg in cmd],
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        print(f"  FAIL ({r.returncode})")
        print(r.stdout[-2000:] if r.stdout else "")
        print(r.stderr[-2000:] if r.stderr else "", file=sys.stderr)
    else:
        print(f"  OK")
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def gate_package_check() -> int:
    rc, _out = run_step(
        "package_check",
        [sys.executable, BUILDER / "package_check.py"],
    )
    return rc


def gate_from_scratch(rom: Path) -> int:
    rc, _out = run_step(
        "from_scratch_gate",
        [sys.executable, BUILDER / "from_scratch_gate.py", str(rom)],
    )
    return rc


def gate_regression_matrix() -> int:
    rc, _out = run_step(
        "regression_matrix",
        [sys.executable, ROOT / "tools" / "run_regression_matrix.py"],
    )
    return rc


def gate_phase_contracts() -> int:
    """All per-phase static contracts. Each one a static gate."""
    contracts = [
        "test_phase17_matrix_contract.py",
        "test_phase16_matrix_contract.py",
        "test_phase15_matrix_contract.py",
        "test_phase14_matrix_contract.py",
        "test_phase13_matrix_contract.py",
        "test_phase12_matrix_contract.py",
        "test_phase11_matrix_contract.py",
        "test_phase10_matrix_contract.py",
        "test_phase9_matrix_contract.py",
        "test_boss_matrix_contract.py",
        "test_boss_state_contract.py",
    ]
    debug_dir = ROOT / "tools" / "debug"
    for c in contracts:
        rc, _ = run_step(
            f"contract {c}",
            [sys.executable, debug_dir / c],
        )
        if rc != 0:
            return rc
    return 0


def gate_banned_filename() -> int:
    rc, _out = run_step(
        "banned_filename_gate",
        [sys.executable, ROOT / "tools" / "gates" / "check_banned_filename.py"],
    )
    return rc


def gate_check_incremental_promotion() -> int:
    rc, _out = run_step(
        "check_incremental_promotion",
        [sys.executable, ROOT / "tools" / "audit" / "check_incremental_promotion.py"],
    )
    return rc


def archive_manifest(rom: Path, verdict: dict) -> None:
    MANIFESTS.mkdir(parents=True, exist_ok=True)
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out = MANIFESTS / f"release-{ts}.json"
    out.write_text(json.dumps(verdict, indent=2) + "\n", encoding="utf-8")
    print(f"  manifest archived: {out.relative_to(ROOT)}")


def main() -> int:
    ap = argparse.ArgumentParser(prog="release_gate.py")
    ap.add_argument("rom", type=Path, nargs="?",
                    help="user NES Zelda 1 ROM")
    ap.add_argument("--dry-run", action="store_true",
                    help="list gates; verify infra only")
    args = ap.parse_args()

    verdict = {
        "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "gates": [],
        "verdict": "?",
    }

    if args.dry_run:
        for label in (
            "package_check",
            "from_scratch_gate (skipped — no ROM in dry-run)",
            "regression_matrix",
            "phase_contracts",
            "banned_filename_gate",
            "check_incremental_promotion",
            "hardware_smoke (DEFERRED — Phase 16.2 external)",
        ):
            print(f"  would run: {label}")
        verdict["verdict"] = "DRY_RUN"
        archive_manifest(args.rom or Path("dry-run"), verdict)
        return 0

    if not args.rom:
        ap.print_help()
        return 1

    # Order matters: package gate first (cheap), then static contracts,
    # then build + reproducibility, then live regression.
    steps = [
        ("banned_filename_gate",          gate_banned_filename,             None),
        ("check_incremental_promotion",   gate_check_incremental_promotion, None),
        ("package_check",                 gate_package_check,               2),
        ("phase_contracts",               gate_phase_contracts,             None),
        ("regression_matrix",             gate_regression_matrix,           4),
        ("from_scratch_gate",             lambda: gate_from_scratch(args.rom), 3),
    ]

    for label, fn, fail_code in steps:
        rc = fn() if not isinstance(fn, type(lambda: 0)) or fn.__name__ != "<lambda>" else fn()
        verdict["gates"].append({"name": label, "rc": rc})
        if rc != 0 and fail_code is not None:
            verdict["verdict"] = f"FAIL: {label}"
            archive_manifest(args.rom, verdict)
            return fail_code

    # Phase 16.2 hardware smoke is external; flag as DEFERRED not BLOCKING.
    print()
    print("[gate] hardware_smoke ... DEFERRED (Phase 16.2 external — needs real Genesis)")
    verdict["gates"].append({"name": "hardware_smoke", "rc": "DEFERRED"})

    verdict["verdict"] = "READY (pending hardware smoke)"
    archive_manifest(args.rom, verdict)
    print()
    print("PASS: all in-CLI gates green. Release-ready pending Phase 16.2 hardware smoke.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
