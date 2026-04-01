#!/usr/bin/env python3
"""
check_room_fidelity.py - Compare BizHawk room dumps against the offline reference.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def first_matrix_mismatch(expected: list[list[int]], actual: list[list[int]]) -> tuple[int, int, int, int] | None:
    for row, (expected_row, actual_row) in enumerate(zip(expected, actual)):
        for col, (expected_value, actual_value) in enumerate(zip(expected_row, actual_row)):
            if expected_value != actual_value:
                return row, col, expected_value, actual_value
    return None


def first_cram_mismatch(expected: list[int], actual: list[int]) -> tuple[int, int, int] | None:
    # The frozen Phase 3 scene intentionally overrides palette line 0 colors 1-3
    # with the placeholder Link sprite palette after the room palette is loaded.
    # Keep validating the room-owned background palette lines and ignore that
    # sprite-specific override.
    skip_indices = {1, 2, 3}
    for index, (expected_word, actual_word) in enumerate(zip(expected, actual)):
        if index in skip_indices:
            continue
        if expected_word != actual_word:
            return index, expected_word, actual_word
    return None


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    reports_dir = root / "builds" / "reports"
    reference_path = reports_dir / "overworld_start_room_reference.json"
    probe_path = reports_dir / "bizhawk_phase3_room_fidelity_probe.json"
    report_path = reports_dir / "bizhawk_phase3_room_fidelity.txt"

    reference = json.loads(reference_path.read_text())
    probe = json.loads(probe_path.read_text())

    lines: list[str] = []
    status = 0

    if "error" in probe:
        lines.append(f"FAIL: BizHawk probe error: {probe['error']}")
        status = 1
    elif probe["room_id"] != reference["room_id"]:
        lines.append(
            f"FAIL: room id mismatch expected=${reference['room_id']:04X} actual=${probe['room_id']:04X}"
        )
        status = 1
    else:
        cram_mismatch = first_cram_mismatch(reference["cram_words"], probe["cram_words"])
        if cram_mismatch is not None:
            index, expected_word, actual_word = cram_mismatch
            lines.append(
                f"FAIL: CRAM mismatch at word {index}: expected=${expected_word:04X} actual=${actual_word:04X}"
            )
            status = 1
        else:
            ram_mismatch = first_matrix_mismatch(reference["tile_words"], probe["room_rows"])
            if ram_mismatch is not None:
                row, col, expected_word, actual_word = ram_mismatch
                lines.append(
                    f"FAIL: RAM room mismatch at row {row:02d} col {col:02d}: expected=${expected_word:04X} actual=${actual_word:04X}"
                )
                status = 1
            else:
                vram_mismatch = first_matrix_mismatch(reference["tile_words"], probe["vram_rows"])
                if vram_mismatch is not None:
                    row, col, expected_word, actual_word = vram_mismatch
                    lines.append(
                        f"FAIL: Plane A VRAM mismatch at row {row:02d} col {col:02d}: expected=${expected_word:04X} actual=${actual_word:04X}"
                    )
                    status = 1
    if status == 0:
        lines.append(f"PASS: room=${reference['room_id']:04X}")
        lines.append("Room palette lines 1-3, room buffer, and Plane A VRAM match the offline reference.")

    report_path.write_text("\n".join(lines) + "\n")
    print(report_path.read_text(), end="")
    return status


if __name__ == "__main__":
    sys.exit(main())
