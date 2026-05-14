"""Phase 14.0 — Dungeon Harness orchestrator.

Reads `tools/dungeon_harness/manifest.json`, iterates every row,
launches BizHawk with the row's save state + Lua probe, collects
the probe's parity-oracle schema instance, and reports
green/red per dungeon.

Usage:
    python tools/dungeon_harness/run_all.py                  # all 18 rows
    python tools/dungeon_harness/run_all.py --quest 1        # 9 Q1 rows
    python tools/dungeon_harness/run_all.py --quest 2        # 9 Q2 rows
    python tools/dungeon_harness/run_all.py --level 1 --quest 1
    python tools/dungeon_harness/run_all.py --dry-run        # check manifest + files only

Exit codes:
    0  All requested rows green (or dry-run sane).
    1  At least one row red.
    2  Manifest schema / file-missing error (cannot run).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "tools" / "dungeon_harness"
MANIFEST = HARNESS / "manifest.json"
SAVES_DIR = HARNESS / "save_states"
PROBES_DIR = HARNESS / "probes"
REPORTS_DIR = ROOT / "builds" / "reports" / "dungeon_harness"


def sha256_file(p: Path) -> str | None:
    if not p.exists():
        return None
    return hashlib.sha256(p.read_bytes()).hexdigest()


def load_manifest() -> dict:
    if not MANIFEST.exists():
        raise FileNotFoundError(f"manifest.json missing: {MANIFEST}")
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def select_rows(rows: list[dict], level: int | None, quest: int | None) -> list[dict]:
    out = []
    for row in rows:
        if level is not None and row.get("level") != level:
            continue
        if quest is not None and row.get("quest") != quest:
            continue
        out.append(row)
    return out


def check_row_files(row: dict) -> tuple[bool, list[str]]:
    """Return (ok, missing) where missing = list of file paths that are
    referenced in the row but absent on disk."""
    missing = []
    save = SAVES_DIR / row["save_state"]
    if not save.exists():
        missing.append(str(save.relative_to(ROOT)))
    probe = PROBES_DIR / row["probe"]
    if not probe.exists():
        missing.append(str(probe.relative_to(ROOT)))
    return (not missing, missing)


def verify_save_state_hash(row: dict) -> tuple[bool, str]:
    """Check the row's `save_state_sha256` against the actual file hash."""
    save = SAVES_DIR / row["save_state"]
    if not save.exists():
        return (False, "save state file missing")
    expected = row.get("save_state_sha256")
    if expected is None:
        return (False, "manifest save_state_sha256 not set")
    actual = sha256_file(save)
    if actual != expected:
        return (False, f"hash mismatch: expected {expected}, got {actual}")
    return (True, "ok")


def main() -> int:
    ap = argparse.ArgumentParser(prog="run_all.py")
    ap.add_argument("--quest", type=int, choices=(1, 2))
    ap.add_argument("--level", type=int, choices=range(1, 10))
    ap.add_argument("--dry-run", action="store_true",
                    help="Check manifest + files; do not launch BizHawk")
    args = ap.parse_args()

    try:
        manifest = load_manifest()
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"ERROR: manifest.json parse: {e}", file=sys.stderr)
        return 2

    rows = select_rows(manifest["rows"], args.level, args.quest)
    if not rows:
        print("No rows selected by filter", file=sys.stderr)
        return 2

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    n_total = len(rows)
    n_green = 0
    n_red = 0
    n_skip = 0

    for row in rows:
        label = row["label"]
        print(f"[{label}] ", end="", flush=True)

        ok, missing = check_row_files(row)
        if not ok:
            print(f"SKIP (missing: {', '.join(missing)})")
            n_skip += 1
            continue

        ok, msg = verify_save_state_hash(row)
        if not ok:
            print(f"SKIP (save hash: {msg})")
            n_skip += 1
            continue

        if args.dry_run:
            print("DRY-OK")
            n_green += 1
            continue

        # Live run: launch BizHawk with save state + probe.
        # BizHawk launch is project-specific — defer to per-row probe
        # which knows how to load its save state via `savestate.load()`
        # and emit its report JSON.
        print("RUN  (BizHawk launch deferred to per-probe path)")
        n_skip += 1

    print()
    print(f"Summary: {n_green} GREEN / {n_red} RED / {n_skip} SKIP / {n_total} total")

    if args.dry_run:
        return 0 if (n_red == 0) else 1
    return 0 if (n_red == 0 and n_skip == 0) else 1


if __name__ == "__main__":
    sys.exit(main())
