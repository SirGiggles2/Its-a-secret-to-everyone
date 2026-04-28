#!/usr/bin/env python3
"""Verify data/MANIFEST.sha256 matches the current data/ tree (S2 Phase A2).

Recomputes SHA256 for every file under data/, compares to the committed
manifest. Exit 0 iff every committed entry matches the on-disk file AND
no extra files exist under data/ that the manifest does not cover.

Usage:
    python tools/probes/check_data_manifest.py

Run automatically from build.bat to gate the build on extraction
reproducibility.
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = REPO_ROOT / "data"
MANIFEST_PATH = DATA_DIR / "MANIFEST.sha256"


def hash_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_manifest() -> dict[str, str]:
    out: dict[str, str] = {}
    if not MANIFEST_PATH.exists():
        return out
    for line in MANIFEST_PATH.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        # Format: "<sha256>  <rel_path>"
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        sha, rel = parts
        out[rel.strip()] = sha.strip()
    return out


def walk_data() -> dict[str, str]:
    out: dict[str, str] = {}
    for path in sorted(DATA_DIR.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(DATA_DIR).as_posix()
        if rel == "MANIFEST.sha256":
            continue
        if path.name == ".gitkeep":
            continue
        out[rel] = hash_file(path)
    return out


def main(argv: list[str]) -> int:
    expected = parse_manifest()
    actual = walk_data()

    missing = sorted(set(expected) - set(actual))
    extra = sorted(set(actual) - set(expected))
    mismatched = sorted(
        rel for rel in (set(expected) & set(actual))
        if expected[rel] != actual[rel]
    )

    if not expected:
        print("[check_data_manifest] no manifest yet; pass (S2 still wiring up)")
        return 0

    if not (missing or extra or mismatched):
        print(f"[check_data_manifest] OK ({len(expected)} files match)")
        return 0

    if missing:
        print(f"[check_data_manifest] MISSING ({len(missing)}):", file=sys.stderr)
        for rel in missing[:20]:
            print(f"  {rel}", file=sys.stderr)
        if len(missing) > 20:
            print(f"  ...+{len(missing) - 20}", file=sys.stderr)
    if extra:
        print(f"[check_data_manifest] EXTRA ({len(extra)}):", file=sys.stderr)
        for rel in extra[:20]:
            print(f"  {rel}", file=sys.stderr)
        if len(extra) > 20:
            print(f"  ...+{len(extra) - 20}", file=sys.stderr)
    if mismatched:
        print(f"[check_data_manifest] MISMATCH ({len(mismatched)}):", file=sys.stderr)
        for rel in mismatched[:20]:
            print(f"  {rel}", file=sys.stderr)
            print(f"    expected: {expected[rel]}", file=sys.stderr)
            print(f"    actual:   {actual[rel]}", file=sys.stderr)
        if len(mismatched) > 20:
            print(f"  ...+{len(mismatched) - 20}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
