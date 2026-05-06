#!/usr/bin/env python3
"""Audit RoomRom UW walkability coverage for all captured rooms.

This pins the collision contract that fixed room $73:
  - captured blob rooms use the visible 8px tile threshold from NES
    PlayAreaTiles/ObjectFirstUnwalkableTile: tile < $78;
  - door state never broad-opens collision cells; real tile patches update the
    exact rendered 8px tiles, while doorway traversal is handled separately;
  - generated LayoutUWFloor collision remains a fallback for non-blob rooms.

The script does not emulate movement. It verifies the data and source-level
invariants that determine every captured UW room's walkability mask.
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AGG = ROOT / "RoomRom" / "out" / "nes_uw_aggregate.json"
UW_BLOB_C = ROOT / "RoomRom" / "src" / "uw_room_blob.c"
UW_RENDER_C = ROOT / "RoomRom" / "src" / "uw_room_render_roomrom.c"
DUNGEONS_C = ROOT / "data" / "rooms" / "dungeons.c"
OUT = ROOT / "build" / "reports" / "uw_walkability" / "all_rooms_summary.json"

DOOR_E = 0
DOOR_W = 1
DOOR_S = 2
DOOR_N = 3

DOOR_WALL = 1
DOOR_OPEN = 0

WALK_MT = {
    DOOR_E: ((14, 5), (15, 5)),
    DOOR_W: ((1, 5), (0, 5)),
    DOOR_S: ((8, 9), (8, 10)),
    DOOR_N: ((8, 1), (8, 0)),
}

OPEN_PATCHES = {
    DOOR_E: ((28, 10), (29, 10), (28, 11), (29, 11)),
    DOOR_W: ((2, 10), (3, 10), (2, 11), (3, 11)),
    DOOR_S: ((15, 18), (16, 18), (15, 19), (16, 19)),
    DOOR_N: ((15, 2), (16, 2), (15, 3), (16, 3)),
}


def fail(message: str) -> None:
    raise AssertionError(message)


def read_json(path: Path) -> dict:
    if not path.exists():
        fail(f"missing {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def parse_dungeon_bytes() -> list[int]:
    text = DUNGEONS_C.read_text(encoding="utf-8")
    return [int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{2})", text)]


def level_block_base(level: int, quest: int) -> int:
    base = 0 if level <= 6 else 768
    if quest == 2:
        base += 1536
    return base


def door_types(data: list[int], level: int, quest: int, room_id: int) -> tuple[int, int, int, int]:
    base = level_block_base(level, quest)
    attrs_a = data[base + room_id]
    attrs_b = data[base + 128 + room_id]
    east = (attrs_b >> 2) & 7
    west = (attrs_b >> 5) & 7
    south = (attrs_a >> 2) & 7
    north = (attrs_a >> 5) & 7
    return east, west, south, north


def parse_blob_index() -> tuple[int, list[tuple[int, int, int, int]]]:
    text = UW_BLOB_C.read_text(encoding="utf-8")
    count_m = re.search(r"g_uw_room_count\s*=\s*(\d+)u", text)
    if not count_m:
        fail("missing g_uw_room_count")
    count = int(count_m.group(1))
    block_m = re.search(
        r"g_uw_room_index\[[^\]]+\]\[4\]\s*=\s*\{(?P<body>.*?)\n\};",
        text,
        re.S,
    )
    if not block_m:
        fail("missing g_uw_room_index body")
    entries = [
        tuple(int(part, 16) for part in match)
        for match in re.findall(
            r"\{\s*(0x[0-9a-fA-F]+),\s*(0x[0-9a-fA-F]+),\s*"
            r"(0x[0-9a-fA-F]+),\s*(0x[0-9a-fA-F]+)\s*\}",
            block_m.group("body"),
        )
    ]
    return count, entries


def assert_runtime_contract() -> dict[str, bool]:
    text = UW_RENDER_C.read_text(encoding="utf-8")
    checks = {
        "tile_threshold_classifier": "return (t < 0x78u) ? 1u : 0u;" in text,
        "blob_writes_exact_tile_mask": re.search(
            r"s_uw_tile_walkable\[col\]\[row\]\s*=\s*uw_walkable_tile_id\(raw\)",
            text,
        ) is not None,
        "blob_col_writes_exact_tile_mask": re.search(
            r"s_uw_tile_walkable\[dst_p0\]\[row\]\s*=\s*uw_walkable_tile_id\(raw0\)",
            text,
        ) is not None,
        "blob_not_generated_grid": re.search(
            r"uw_room_walkable\(s_uw_level,\s*s_uw_quest,\s*"
            r"\(unsigned char\)g_uw_room_index\[idx\]\[3\]",
            text,
        ) is None,
        "fallback_uses_generated_grid": re.search(
            r"uw_room_walkable\(s_uw_level,\s*s_uw_quest,\s*room_id",
            text,
        ) is not None,
        "door_metatile_diagnostic_only": re.search(
            r"void roomrom_uw_room_render_set_walkable[\s\S]*?"
            r"set_walkable_metatile_only\(col, row, val\)",
            text,
        ) is not None,
    }
    missing = [name for name, ok in checks.items() if not ok]
    if missing:
        fail(f"runtime contract failed: {missing}")
    return checks


def base_mask_from_nt(nt: list[list[int]]) -> list[list[int]]:
    if len(nt) != 30 or any(len(row) != 32 for row in nt):
        fail("bad nt dimensions")
    mask = [[0 for _row in range(22)] for _col in range(32)]
    for col in range(32):
        for row in range(22):
            mask[col][row] = 1 if nt[row + 8][col] < 0x78 else 0
    return mask


def apply_door_overrides(mask: list[list[int]], doors: tuple[int, int, int, int]) -> None:
    _ = mask
    for door_dir, _door_type in enumerate(doors):
        for col, row in OPEN_PATCHES[door_dir]:
            if col < 0 or col > 31 or row < 0 or row > 21:
                fail(f"door tile OOB dir={door_dir} tile=({col},{row})")


def mask_counts(mask: list[list[int]]) -> tuple[int, int]:
    walk = sum(mask[col][row] for col in range(32) for row in range(22))
    return walk, 704 - walk


def main() -> int:
    contract = assert_runtime_contract()
    agg = read_json(AGG)
    entries = list(agg.get("entries") or [])
    if not entries:
        fail("aggregate has no UW entries")

    count, blob_entries = parse_blob_index()
    agg_keys = {
        (int(e["map_id"]), int(e["quest"]), int(e["level"]), int(e["room_id"]))
        for e in entries
    }
    blob_keys = set(blob_entries)
    if count != len(blob_entries):
        fail(f"g_uw_room_count={count} but parsed {len(blob_entries)} index rows")
    if agg_keys != blob_keys:
        missing = sorted(agg_keys - blob_keys)[:10]
        extra = sorted(blob_keys - agg_keys)[:10]
        fail(f"blob index mismatch missing={missing} extra={extra}")

    data = parse_dungeon_bytes()
    groups: dict[tuple[int, int, int], int] = defaultdict(int)
    door_hist: Counter[int] = Counter()
    walk_counts: list[int] = []
    all_walkable: list[tuple[int, int, int, int]] = []
    all_blocked: list[tuple[int, int, int, int]] = []
    samples: dict[str, dict[str, object]] = {}

    for e in entries:
        key = (int(e["map_id"]), int(e["quest"]), int(e["level"]), int(e["room_id"]))
        groups[key[:3]] += 1
        doors = door_types(data, key[2], key[1], key[3])
        door_hist.update(doors)
        mask = base_mask_from_nt(e["nt"])
        apply_door_overrides(mask, doors)
        walk, block = mask_counts(mask)
        walk_counts.append(walk)
        if walk == 704:
            all_walkable.append(key)
        if block == 704:
            all_blocked.append(key)
        if key in {
            (0, 1, 1, 0x73),
            (0, 1, 4, 0x00),
            (0, 2, 9, 0x7B),
            (1, 1, 1, 0x73),
        }:
            samples[f"map{key[0]}_q{key[1]}_l{key[2]}_r{key[3]:02x}"] = {
                "doors": doors,
                "walkable": walk,
                "blocked": block,
            }

    report = {
        "pass": True,
        "runtime_contract": contract,
        "aggregate_entries": len(entries),
        "blob_index_entries": len(blob_entries),
        "groups": len(groups),
        "rooms_per_group_min": min(groups.values()),
        "rooms_per_group_max": max(groups.values()),
        "walkable_min": min(walk_counts),
        "walkable_max": max(walk_counts),
        "walkable_avg": round(sum(walk_counts) / len(walk_counts), 2),
        "all_walkable_rooms": [
            f"map{m}_q{q}_l{lvl}_r{rid:02x}" for m, q, lvl, rid in all_walkable
        ],
        "all_blocked_rooms": [
            f"map{m}_q{q}_l{lvl}_r{rid:02x}" for m, q, lvl, rid in all_blocked
        ],
        "door_type_histogram": {str(k): door_hist[k] for k in sorted(door_hist)},
        "samples": samples,
        "output": str(OUT),
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"UW WALKABILITY AUDIT FAIL: {exc}", file=sys.stderr)
        raise SystemExit(2)
