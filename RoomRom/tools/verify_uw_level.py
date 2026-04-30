#!/usr/bin/env python3
"""Per-run verifier for a single (level, quest, rom) NES UW dump.

Usage: python RoomRom/tools/verify_uw_level.py <level> <quest> <rom_id>

Checks:
  - JSON parses, has required fields.
  - rooms_captured + rooms_failed == |reachability.rooms|.
  - No duplicate room_id within results.
  - manifest.border_fill_tile != null (else manifest_incomplete).
  - Per non-timeout room: palram[0] == manifest.palette_baseline[0].
  - Per non-passage room: outer NT frame tiles in
    {border_fill_tile} | wall_tiles | door_tiles.
"""

import json
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DATA = REPO_ROOT / "RoomRom" / "data"
OUT = REPO_ROOT / "RoomRom" / "out"


def fail(msg: str) -> None:
    print(f"VERIFY FAIL: {msg}", file=sys.stderr)
    sys.exit(2)


def hex_set(strs: list[str]) -> set[int]:
    out = set()
    for s in strs:
        if isinstance(s, str) and s.startswith("0x"):
            out.add(int(s, 16))
    return out


def main(argv: list[str]) -> int:
    if len(argv) < 4:
        sys.exit("usage: verify_uw_level.py <level> <quest> <rom_id>")
    level = int(argv[1])
    quest = int(argv[2])
    rom_id = argv[3]

    probe_p = OUT / f"nes_uw_level{level}_quest{quest}_{rom_id}.json"
    rooms_p = DATA / f"uw_level{level}_quest{quest}_rooms.json"
    manifest_p = DATA / f"uw_level{level}_quest{quest}_manifest.json"

    for p in (probe_p, rooms_p, manifest_p):
        if not p.exists():
            fail(f"missing {p}")

    try:
        probe = json.loads(probe_p.read_text(encoding="utf-8"))
    except Exception as e:
        fail(f"probe JSON parse error: {e}")
    rooms_data = json.loads(rooms_p.read_text(encoding="utf-8"))
    manifest = json.loads(manifest_p.read_text(encoding="utf-8"))

    border = manifest.get("border_fill_tile")
    if border is None:
        fail("manifest_incomplete: border_fill_tile is null")
    palette = manifest.get("palette_baseline") or [None]
    pal0 = palette[0] if palette else None
    door_tiles = set(manifest.get("door_tiles") or [])
    wall_tiles = set(manifest.get("wall_tiles") or [])
    stair_tiles = set(manifest.get("stair_tiles") or [])
    legal_border = {border} | door_tiles | wall_tiles | stair_tiles

    expected_rooms = hex_set(rooms_data.get("rooms") or [])
    passage_rooms = hex_set(rooms_data.get("passage_rooms") or [])

    if not probe.get("boot_ok"):
        fail(f"boot_ok=false (fatal_error={probe.get('fatal_error')})")
    if not probe.get("warp_ok"):
        fail(f"warp_ok=false (fatal_error={probe.get('fatal_error')})")

    results = probe.get("results") or []
    seen_rooms = set()
    captured = 0
    timed_out = 0
    for r in results:
        rid = r.get("room_id")
        if rid in seen_rooms:
            fail(f"duplicate room_id 0x{rid:02X} in results")
        seen_rooms.add(rid)
        if r.get("code") == "settle_timeout":
            timed_out += 1
            continue
        captured += 1

        # palram[0] check
        pal = r.get("palram") or []
        if pal0 is not None and pal and pal[0] != pal0:
            fail(
                f"room 0x{rid:02X}: palram[0]=0x{pal[0]:02X} != "
                f"manifest.palette[0]=0x{pal0:02X}"
            )

        # Outer-frame tile membership (non-passage rooms only)
        if rid in passage_rooms:
            continue
        nt = r.get("nt")
        if not nt or len(nt) < 30 or len(nt[0]) < 32:
            fail(f"room 0x{rid:02X}: nt missing/short")
        # Border check: top/bottom rows of play area (rows 8 and 29)
        # and left/right columns (cols 0 and 31) within those rows.
        bad = []
        for c in range(32):
            for r_idx in (8, 29):
                v = nt[r_idx][c]
                if v not in legal_border:
                    bad.append((r_idx, c, v))
        for r_idx in range(8, 30):
            for c in (0, 31):
                v = nt[r_idx][c]
                if v not in legal_border:
                    bad.append((r_idx, c, v))
        if bad:
            sample = bad[:5]
            fail(
                f"room 0x{rid:02X}: {len(bad)} border tile(s) outside legal set; "
                f"e.g. {sample}"
            )

    expected_count = len(expected_rooms)
    total_in_probe = captured + timed_out
    if total_in_probe != expected_count:
        fail(
            f"results count {total_in_probe} != reachability.rooms count "
            f"{expected_count} (captured={captured}, timed_out={timed_out})"
        )

    if timed_out > 0:
        print(
            f"VERIFY OK with timeouts: L{level} Q{quest} {rom_id} "
            f"captured={captured} timed_out={timed_out}/{expected_count}"
        )
    else:
        print(
            f"VERIFY OK: L{level} Q{quest} {rom_id} "
            f"captured={captured}/{expected_count}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
