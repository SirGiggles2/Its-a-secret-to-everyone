#!/usr/bin/env python3
"""PR-1 preflight: scan all RoomRom UW + OW room AT bytes for distinct
NES BG sub-palette references per screen.

NES Z1 BG attribute byte: 8 bits packed as 4 quads × 2 bits each
(bit pairs 0-1=TL, 2-3=TR, 4-5=BL, 6-7=BR). Each room: 64 AT bytes
covering 32x32-tile quad grid (8 cols × 8 rows of quads).

Output: list of (room_set, room_id) → set of distinct sub-pal indices
used. Aggregate: max distinct per screen across all rooms.

Decision gate:
- max_distinct ≤ 2  → BG_2x viable.
- max_distinct >= 3 → BG_2x rejected; fallback BG_3x or static-SPR-split.

Usage:
    python tools/probes/audit_bg_subpal_refs.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
UW_BLOB_C = REPO / "RoomRom" / "src" / "uw_room_blob.c"
OW_C = REPO / "data" / "rooms" / "overworld.c"
OUT_DIR = REPO / "build" / "probes" / "ph5" / "task_chr"
OUT_REPORT = OUT_DIR / "audit_bg_subpal_refs.json"


def parse_uw_attrs() -> list[tuple[int, int, int, int, list[int]]]:
    """Returns [(map, quest, level, room_id, attr_bytes[64]), ...]
    for every UW blob entry."""
    text = UW_BLOB_C.read_text(encoding="utf-8", errors="ignore")

    idx_match = re.search(r"g_uw_room_index\[\d+\]\[4\] = \{(.+?)\};",
                          text, re.S)
    if not idx_match:
        sys.exit("g_uw_room_index not found")
    indices = []
    for m in re.finditer(
        r"\{\s*0x([0-9a-fA-F]+),\s*0x([0-9a-fA-F]+),\s*0x([0-9a-fA-F]+),\s*0x([0-9a-fA-F]+)\s*\}",
        idx_match.group(1),
    ):
        indices.append(tuple(int(x, 16) for x in m.groups()))

    attr_match = re.search(r"g_uw_room_attr\[\d+\]\[64\] = \{(.+?)\n\};",
                           text, re.S)
    if not attr_match:
        sys.exit("g_uw_room_attr not found")
    bs = [int(b, 16) for b in re.findall(r"0x([0-9a-fA-F]{2})",
                                          attr_match.group(1))]
    if len(bs) % 64 != 0:
        sys.exit(f"attr byte count {len(bs)} not divisible by 64")
    rows = []
    for i, idx in enumerate(indices):
        attr = bs[i * 64:(i + 1) * 64]
        rows.append((idx[0], idx[1], idx[2], idx[3], attr))
    return rows


def distinct_subpals(attr_bytes: list[int]) -> set[int]:
    """Extract distinct sub-pal indices (0..3) from packed AT bytes."""
    out: set[int] = set()
    for byte in attr_bytes:
        out.add(byte & 0x03)
        out.add((byte >> 2) & 0x03)
        out.add((byte >> 4) & 0x03)
        out.add((byte >> 6) & 0x03)
    return out


def parse_ow_attrs() -> list[tuple[int, list[int]]]:
    """OW LevelBlock attr_b stores 4 quads per room. NES Z1 OW
    attribute model differs from UW (HUD only spans rows 0-3,
    sub-pal selector embedded). Pull rooms_overworld bytes for
    the attr_b sub-table (offset 128 within first 768-byte
    LevelBlock per data/rooms/overworld_offsets.h).

    Returns [(room_id, attr_byte_value), ...] — single byte per
    room since OW uses single-attr flat encoding."""
    if not OW_C.exists():
        return []
    text = OW_C.read_text(encoding="utf-8", errors="ignore")
    blob_match = re.search(r"rooms_overworld\[\] = \{(.+?)\};", text, re.S)
    if not blob_match:
        return []
    bs = [int(b, 16) for b in re.findall(r"0x([0-9a-fA-F]{2})",
                                          blob_match.group(1))]
    # AttrsB sub-table: bytes 128..255 (128 rooms in OW LevelBlock).
    rows = []
    for room in range(128):
        rows.append((room, bs[128 + room]))
    return rows


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    uw_rows = parse_uw_attrs()
    ow_rows = parse_ow_attrs()

    uw_subpal_per_room = []
    max_uw_distinct = 0
    rooms_with_3plus_uw = []
    for (mp, q, lvl, rid, attr) in uw_rows:
        sp = distinct_subpals(attr)
        uw_subpal_per_room.append({
            "map": mp, "quest": q, "level": lvl, "room": rid,
            "distinct_subpals": sorted(sp),
            "count": len(sp),
        })
        if len(sp) > max_uw_distinct:
            max_uw_distinct = len(sp)
        if len(sp) >= 3:
            rooms_with_3plus_uw.append({
                "map": mp, "quest": q, "level": lvl,
                "room": f"0x{rid:02X}", "distinct": sorted(sp)
            })

    ow_subpal_per_room = []
    max_ow_distinct = 0
    rooms_with_3plus_ow = []
    for (rid, byte) in ow_rows:
        sp = distinct_subpals([byte])
        ow_subpal_per_room.append({
            "room": rid,
            "distinct_subpals": sorted(sp),
            "count": len(sp),
        })
        if len(sp) > max_ow_distinct:
            max_ow_distinct = len(sp)
        if len(sp) >= 3:
            rooms_with_3plus_ow.append({
                "room": f"0x{rid:02X}", "distinct": sorted(sp)
            })

    bg2x_viable = (max_uw_distinct <= 2 and max_ow_distinct <= 2)

    report = {
        "verdict": "BG_2x_VIABLE" if bg2x_viable else "BG_2x_REJECTED",
        "uw_total_rooms": len(uw_rows),
        "uw_max_distinct_subpals_per_room": max_uw_distinct,
        "uw_rooms_with_3plus": rooms_with_3plus_uw[:50],
        "uw_rooms_with_3plus_count": len(rooms_with_3plus_uw),
        "ow_total_rooms": len(ow_rows),
        "ow_max_distinct_subpals_per_room": max_ow_distinct,
        "ow_rooms_with_3plus": rooms_with_3plus_ow[:50],
        "ow_rooms_with_3plus_count": len(rooms_with_3plus_ow),
        "decision_implication": (
            "BG_2x rebudget viable: 512 tiles freed, no per-room remap "
            "needed beyond existing 0/1 indexing."
            if bg2x_viable else
            "BG_2x rejected. Fallback: BG_3x (768 tiles, NPC scope cut) "
            "OR SPR-split + shared SCENE_OBJ transient (preserves "
            "BG_4x). Per-room remap table required if BG_3x chosen."
        ),
    }
    OUT_REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"verdict: {report['verdict']}")
    print(f"  UW: {len(uw_rows)} rooms; max distinct sub-pals = {max_uw_distinct}")
    print(f"  UW rooms with 3+: {len(rooms_with_3plus_uw)}")
    print(f"  OW: {len(ow_rows)} rooms; max distinct sub-pals = {max_ow_distinct}")
    print(f"  OW rooms with 3+: {len(rooms_with_3plus_ow)}")
    print(f"report: {OUT_REPORT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
