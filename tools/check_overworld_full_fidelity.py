#!/usr/bin/env python3
"""
check_overworld_full_fidelity.py - Compare full-runtime overworld room dumps
against the offline all-rooms reference.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


REPORT_NAME = "bizhawk_phase3_overworld_full_probe.txt"


def first_matrix_mismatch(expected: list[list[int]], actual: list[list[int]]) -> tuple[int, int, int, int] | None:
    for row, (expected_row, actual_row) in enumerate(zip(expected, actual)):
        for col, (expected_value, actual_value) in enumerate(zip(expected_row, actual_row)):
            if expected_value != actual_value:
                return row, col, expected_value, actual_value
    return None


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    reports_dir = root / "builds" / "reports"
    reference_path = reports_dir / "overworld_all_rooms_reference.json"
    probe_path = reports_dir / "bizhawk_phase3_overworld_full_probe.json"
    report_path = reports_dir / REPORT_NAME

    reference = json.loads(reference_path.read_text())
    probe = json.loads(probe_path.read_text())

    lines: list[str] = []

    if "error" in probe:
        lines.append(f"FAIL: BizHawk probe error: {probe['error']}")
        report_path.write_text("\n".join(lines) + "\n")
        print(report_path.read_text(), end="")
        return 1

    reference_rooms = {int(room["room_id"]): room for room in reference["rooms"]}
    probe_rooms = {int(room["room_id"]): room for room in probe["rooms"]}

    status = 0

    missing = sorted(set(reference_rooms.keys()) - set(probe_rooms.keys()))
    extras = sorted(set(probe_rooms.keys()) - set(reference_rooms.keys()))
    if missing:
        lines.append("FAIL: missing probed rooms: " + ", ".join(f"{rid:02X}" for rid in missing[:32]))
        status = 1
    if extras:
        lines.append("FAIL: unexpected probed rooms: " + ", ".join(f"{rid:02X}" for rid in extras[:32]))
        status = 1

    mismatch_count = 0
    mismatch_samples: list[str] = []

    for room_id in sorted(set(reference_rooms.keys()) & set(probe_rooms.keys())):
        expected = reference_rooms[room_id]["tile_words"]
        actual = probe_rooms[room_id]["room_rows"]
        mismatch = first_matrix_mismatch(expected, actual)
        if mismatch is None:
            continue
        mismatch_count += 1
        if len(mismatch_samples) < 24:
            row, col, exp, got = mismatch
            mismatch_samples.append(
                f"room {room_id:02X} row {row:02d} col {col:02d}: expected=${exp:04X} actual=${got:04X}"
            )

    if mismatch_count > 0:
        lines.append(f"FAIL: room tile mismatches in {mismatch_count} rooms")
        lines.extend(mismatch_samples)
        status = 1

    if status == 0:
        room_count = len(reference_rooms)
        lines.append(f"PASS: all {room_count} overworld rooms match offline reference")

    report_path.write_text("\n".join(lines) + "\n")
    print(report_path.read_text(), end="")
    return status


if __name__ == "__main__":
    sys.exit(main())
