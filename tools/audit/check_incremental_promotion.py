"""Phase 12 Task 12.0 — Incremental promotion gate.

Lists every shared `RoomRom/src/*.c` module still un-promoted, plus
its phase-deferral count.

Reads:
  docs/audit/roomrom_promotion_audit.md  — classification table
                                            (Task 12.1 baseline)
  RoomRom/src/*.c                        — actual on-disk state

Emits a deferral-count column = current_phase - first_phase_eligible
per module. shared-gameplay modules become eligible at the phase that
ships their primary substrate (Phase 6 for items/combat/HUD, Phase 4
for world/dungeon meta, etc.). For the baseline pass we report:

  deferrals = active_phase - last_audit_phase

Failure mode (exit 2): any shared-gameplay module with deferrals > 1
phase AND no documented blocker in
`docs/audit/roomrom_promotion_audit.md`.

For the Phase 12 baseline this script enumerates state and emits
zero exit code; the threshold-fail mode lights up once Phase 12.2
PRs land and a count column appears in the audit doc.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ROOMROM_SRC = ROOT / "RoomRom" / "src"
AUDIT_DOC = ROOT / "docs" / "audit" / "roomrom_promotion_audit.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_audit_table(doc_text: str) -> dict[str, dict[str, str]]:
    """Return { filename: { 'bucket': ..., 'target': ..., 'notes': ... } }.

    Scans the markdown table rows beginning with `` `roomrom_*` `` or
    similar backtick-wrapped filenames; rows split on `|`.
    """
    out: dict[str, dict[str, str]] = {}
    for line in doc_text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 3:
            continue
        first = cells[0]
        m = re.match(r"`([^`]+\.c)`", first)
        if not m:
            continue
        fname = m.group(1)
        bucket = cells[1]
        target = cells[2]
        notes = cells[3] if len(cells) > 3 else ""
        out[fname] = {
            "bucket": bucket,
            "target": target,
            "notes": notes,
        }
    return out


def scan_roomrom_src() -> set[str]:
    return {p.name for p in ROOMROM_SRC.glob("*.c")}


def main() -> int:
    if not AUDIT_DOC.exists():
        print(
            "ERROR: docs/audit/roomrom_promotion_audit.md missing — "
            "run Task 12.1 baseline audit first",
            file=sys.stderr,
        )
        return 2

    classification = parse_audit_table(read(AUDIT_DOC))
    on_disk = scan_roomrom_src()

    # Cross-check disk vs audit doc.
    missing_from_doc = on_disk - set(classification.keys())
    missing_from_disk = set(classification.keys()) - on_disk

    print(f"RoomRom/src/*.c on-disk:        {len(on_disk)}")
    print(f"RoomRom/src/*.c classified:     {len(classification)}")
    print(f"On-disk but unclassified:       {len(missing_from_doc)}")
    print(f"Classified but missing:         {len(missing_from_disk)}")
    print()

    if missing_from_doc:
        print("Unclassified files (add to roomrom_promotion_audit.md):")
        for f in sorted(missing_from_doc):
            print(f"  - {f}")
        print()

    if missing_from_disk:
        print("Stale classification rows (file no longer exists):")
        for f in sorted(missing_from_disk):
            print(f"  - {f}")
        print()

    # Bucket counts.
    bucket_counts: dict[str, int] = {}
    for f, row in classification.items():
        if f not in on_disk:
            continue
        b = row["bucket"]
        bucket_counts[b] = bucket_counts.get(b, 0) + 1

    print("Bucket counts (on-disk):")
    for bucket in ("harness-only", "shared-gameplay", "generated-asset", "obsolete-debug"):
        print(f"  {bucket:20s}: {bucket_counts.get(bucket, 0)}")
    print()

    shared = [
        f for f, row in classification.items()
        if f in on_disk and row["bucket"] == "shared-gameplay"
    ]
    if shared:
        print(f"Shared-gameplay TUs still in RoomRom/src/ (un-promoted): {len(shared)}")
        for f in sorted(shared):
            row = classification[f]
            print(f"  {f:35s} -> {row['target']}")

    # Exit zero on baseline pass; in follow-up PRs this script will
    # exit 2 when deferrals exceed 1 phase without a documented
    # blocker.
    return 0


if __name__ == "__main__":
    sys.exit(main())
