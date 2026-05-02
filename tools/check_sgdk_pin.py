#!/usr/bin/env python3
"""check_sgdk_pin.py — verify SGDK submodule SHA matches the pin.

Per debate 003 Rule SGDK-2. Source of truth: tools/sgdk_pin.json.
Exit 1 on drift unless --accept-sgdk-bump is passed.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
PIN_PATH = REPO / "tools" / "sgdk_pin.json"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument(
        "--accept-sgdk-bump",
        action="store_true",
        help="Skip drift check (use only when intentionally bumping the pin).",
    )
    args = ap.parse_args()

    if not PIN_PATH.exists():
        print(f"FAIL: missing {PIN_PATH}", file=sys.stderr)
        return 1

    pin = json.loads(PIN_PATH.read_text())
    pinned_sha = pin["pinned_sha"]
    submodule_path = REPO / pin["submodule_path"]

    if not submodule_path.exists():
        print(f"FAIL: SGDK submodule not present at {submodule_path}", file=sys.stderr)
        return 1

    try:
        head = subprocess.check_output(
            ["git", "-C", str(submodule_path), "rev-parse", "HEAD"],
            text=True,
        ).strip()
    except subprocess.CalledProcessError as e:
        print(f"FAIL: git rev-parse failed: {e}", file=sys.stderr)
        return 1

    if head != pinned_sha:
        msg = (
            f"SGDK submodule HEAD {head[:8]} != pinned {pinned_sha[:8]} "
            f"({pin['pinned_tag']}, {pin['pinned_date']})."
        )
        if args.accept_sgdk_bump:
            print(f"WARN (--accept-sgdk-bump): {msg}", file=sys.stderr)
            print(
                "  Remember to update tools/sgdk_pin.json + docs/sgdk_audit.md "
                "+ regen parity baselines + regen Final.md checksum in the same commit.",
                file=sys.stderr,
            )
            return 0
        print(f"FAIL: {msg}", file=sys.stderr)
        print(
            "  To intentionally bump: pass --accept-sgdk-bump after updating "
            "tools/sgdk_pin.json and docs/sgdk_audit.md.",
            file=sys.stderr,
        )
        return 1

    print(f"OK: SGDK pinned to {pinned_sha[:8]} ({pin['pinned_tag']}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
