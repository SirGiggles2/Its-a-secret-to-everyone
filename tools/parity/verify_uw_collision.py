#!/usr/bin/env python3
"""verify_uw_collision.py — compare generated UW collision grids against NES BizHawk captures.

Usage:
    python tools/parity/verify_uw_collision.py [--capture PATH] [--level N] [--room R]

Compares:
  1. Generated grid from extract_uw_collision.py output
  2. NES BizHawk RAM probe (PlayAreaTiles at $6530 + walkable threshold at $034A)

The NES PlayAreaTiles layout stores tile IDs at $6530 with 22-byte column stride.
A tile is walkable if tile_id < ObjectFirstUnwalkableTile ($034A, set to $78 for UW).

BizHawk capture format (JSON, produced by probe_uw_collision_nes.lua):
  {
    "level": 1, "quest": 1, "room_id": 0,
    "play_area_tiles": [<704 tile bytes, col-major stride-22>],
    "first_unwalkable": 120
  }

NES source:  reference/aldonunez/Z_05.asm:LayoutUWFloor + ObjectRoomBoundsUW
Drained C:   src/oracle/room/room_load_runtime.c:roomld_setup_obj_room_bounds
Coverage:    PARTIAL
Stance:      EXTEND
"""

import json
import sys
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "builder"))
from extract_uw_collision import (
    parse_dungeons_c, load_manifest, build_room_grid,
    GRID_COLS, GRID_ROWS, FLOOR_COL_OFFSET, FLOOR_ROW_OFFSET,
    FLOOR_COLS, FLOOR_ROWS, WALKABLE_THRESHOLD,
)

DUNGEONS_C  = REPO / "data" / "rooms" / "dungeons.c"
MANIFEST    = REPO / "data" / "rooms" / "MANIFEST.json"

# NES PlayAreaTiles: 32 columns × 22 rows in tile space.
# For UW, column stride = 22 bytes. Cols 0..31, rows 0..21.
# Metatile col C (0..15) = tile cols 2C, 2C+1.
# Metatile row R (0..10) = tile rows 2R, 2R+1 (within the 22-row column layout).
# UW floor region: metatile rows 2..8 (tile rows 4..17), metatile cols 2..13 (tile cols 4..27).
NES_COLS = 32
NES_ROWS = 22
NES_STRIDE = 22   # column stride in PlayAreaTiles (bytes per column)


def nes_tiles_to_grid(play_area_tiles: list[int], first_unwalkable: int = 0x78) -> list[list[int]]:
    """Convert 704-byte PlayAreaTiles array to 16×11 walkable grid.

    play_area_tiles is column-major: index = col * NES_STRIDE + row.
    Tile at (col, row) = play_area_tiles[col * NES_STRIDE + row].
    A metatile (mc, mr) covers tile cols (2mc, 2mc+1), tile rows (2mr, 2mr+1).
    All 4 tiles must be walkable for the metatile to be walkable.
    """
    grid = [[0] * GRID_ROWS for _ in range(GRID_COLS)]
    for mc in range(GRID_COLS):
        for mr in range(GRID_ROWS):
            # Check all 4 tiles in the metatile
            walkable = True
            for dc in range(2):
                for dr in range(2):
                    tc = mc * 2 + dc
                    tr = mr * 2 + dr
                    if tc >= NES_COLS or tr >= NES_ROWS:
                        walkable = False
                        break
                    tile = play_area_tiles[tc * NES_STRIDE + tr]
                    if tile >= first_unwalkable:
                        walkable = False
                        break
                if not walkable:
                    break
            grid[mc][mr] = 1 if walkable else 0
    return grid


def compare_grids(gen_grid: list[list[int]], nes_grid: list[list[int]],
                  label: str) -> list[str]:
    """Return list of mismatch descriptions (empty = match)."""
    mismatches = []
    for col in range(GRID_COLS):
        for row in range(GRID_ROWS):
            g = gen_grid[col][row]
            n = nes_grid[col][row]
            if g != n:
                mismatches.append(
                    f"  col={col:2d} row={row:2d}: gen={g} nes={n}"
                )
    return mismatches


def print_grid(grid: list[list[int]], label: str) -> None:
    print(f"{label}:")
    for row in range(GRID_ROWS):
        line = "".join("." if grid[col][row] else "#" for col in range(GRID_COLS))
        print(f"  row{row:02d}: {line}")


def load_capture(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


def get_unique_room_id(data: bytes, tables: dict, level: int, quest: int, room_id: int) -> int:
    if level <= 6:
        block_name = f"LevelBlockUW1Q{quest}"
    else:
        block_name = f"LevelBlockUW2Q{quest}"
    off, _ = tables[block_name]
    return data[off + 0x180 + room_id] & 0x3F


def verify_single(data: bytes, tables: dict,
                  level: int, quest: int, room_id: int,
                  capture: dict | None = None) -> bool:
    uid = get_unique_room_id(data, tables, level, quest, room_id)
    gen_grid = build_room_grid(data, tables, uid)

    print(f"Level {level} Q{quest} Room {room_id:#04x} (uid={uid})")
    print_grid(gen_grid, "  Generated")

    if capture is None:
        print("  [no NES capture — skipping comparison]")
        return True

    nes_tiles = capture["play_area_tiles"]
    first_unwalkable = capture.get("first_unwalkable", WALKABLE_THRESHOLD)
    nes_grid = nes_tiles_to_grid(nes_tiles, first_unwalkable)
    print_grid(nes_grid, "  NES BizHawk")

    mismatches = compare_grids(gen_grid, nes_grid, f"L{level}Q{quest}R{room_id:#04x}")
    if mismatches:
        print(f"  FAIL: {len(mismatches)} mismatches:")
        for m in mismatches[:20]:
            print(m)
        return False
    else:
        print("  OK: grids match")
        return True


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description="Verify UW collision grids against NES captures")
    parser.add_argument("--capture", help="Path to BizHawk JSON capture file")
    parser.add_argument("--captures-dir", help="Directory of JSON captures to batch-verify")
    parser.add_argument("--level", type=int, default=1, help="Dungeon level (1-9)")
    parser.add_argument("--quest", type=int, default=1, help="Quest (1-2)")
    parser.add_argument("--room", type=lambda x: int(x, 0), default=0, help="Room ID (hex ok)")
    parser.add_argument("--all-rooms", action="store_true",
                        help="Verify all 128 rooms for given level/quest (no captures)")
    args = parser.parse_args()

    data = parse_dungeons_c(DUNGEONS_C)
    tables, _sha = load_manifest(MANIFEST)

    failures = 0

    if args.captures_dir:
        cap_dir = Path(args.captures_dir)
        captures = sorted(cap_dir.glob("*.json"))
        if not captures:
            print(f"No JSON files in {cap_dir}", file=sys.stderr)
            return 1
        for cap_path in captures:
            cap = load_capture(cap_path)
            ok = verify_single(data, tables,
                                cap["level"], cap["quest"], cap["room_id"], cap)
            if not ok:
                failures += 1
    elif args.capture:
        cap = load_capture(Path(args.capture))
        level = cap.get("level", args.level)
        quest = cap.get("quest", args.quest)
        room_id = cap.get("room_id", args.room)
        ok = verify_single(data, tables, level, quest, room_id, cap)
        if not ok:
            failures += 1
    elif args.all_rooms:
        for room_id in range(128):
            ok = verify_single(data, tables, args.level, args.quest, room_id, None)
            if not ok:
                failures += 1
    else:
        ok = verify_single(data, tables, args.level, args.quest, args.room, None)
        if not ok:
            failures += 1

    if failures:
        print(f"\nFAIL: {failures} room(s) mismatched")
        return 1
    print("\nOK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
