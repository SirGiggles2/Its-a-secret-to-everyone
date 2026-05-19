#!/usr/bin/env python3
"""Phase I audit (2026-05-18 VRAM cleanup): per-NES-tile-ID sub-palette
usage across all rooms. Decides whether selective BG dedup is viable.

For each NES BG tile ID (0..255), count distinct sub-palettes it appears
with across all UW + OW rooms. If most tiles use 1-2 sub-pals, the BG_4x
replication can be selectively reduced.

UW: g_uw_room_nt[room][cell_idx] = NES tile ID at cell (col, row).
    g_uw_room_attr[room][quad_idx] = packed AT byte (4 sub-pals per byte).
    Each AT byte covers a 2x2 group of cells.

OW: data/rooms/overworld.c rooms_overworld blob. Bytes 0..127 = tile
    IDs (column-major mapping per data/rooms/overworld_offsets.h). The
    attr is a single byte per room (one sub-pal for entire room).

Output: histogram of (distinct sub-pals per tile), plus list of tiles
that need 4-way replication.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
UW_BLOB_C = REPO / "RoomRom" / "src" / "uw_room_blob.c"
OW_C = REPO / "data" / "rooms" / "overworld.c"


def parse_uw_blob():
    """Returns list of (room_idx, nt_bytes[22*32=704], attr_bytes[64])."""
    text = UW_BLOB_C.read_text(encoding="utf-8", errors="ignore")

    # g_uw_room_nt — flat array of (room_count * 704) bytes
    nt_match = re.search(r"g_uw_room_nt\[\d+\]\[\d+\] = \{(.+?)\n\};",
                         text, re.S)
    if not nt_match:
        return []
    nt_bytes = [int(b, 16) for b in re.findall(r"0x([0-9a-fA-F]{2})",
                                                nt_match.group(1))]

    attr_match = re.search(r"g_uw_room_attr\[\d+\]\[64\] = \{(.+?)\n\};",
                           text, re.S)
    if not attr_match:
        return []
    attr_bytes = [int(b, 16) for b in re.findall(r"0x([0-9a-fA-F]{2})",
                                                  attr_match.group(1))]

    CELLS_PER_ROOM = 22 * 32   # 704
    ATTR_PER_ROOM = 64

    n_nt = len(nt_bytes) // CELLS_PER_ROOM
    n_attr = len(attr_bytes) // ATTR_PER_ROOM
    n_rooms = min(n_nt, n_attr)

    rooms = []
    for r in range(n_rooms):
        nt = nt_bytes[r * CELLS_PER_ROOM:(r + 1) * CELLS_PER_ROOM]
        at = attr_bytes[r * ATTR_PER_ROOM:(r + 1) * ATTR_PER_ROOM]
        rooms.append((r, nt, at))
    return rooms


def uw_quad_subpal(attr_byte, quad_pos):
    """quad_pos = 0..3 (TL, TR, BL, BR within attr byte)."""
    return (attr_byte >> (quad_pos * 2)) & 0x03


def collect_uw_per_tile_subpals(rooms):
    """Returns dict {tile_id: set(sub_pals)}."""
    out = defaultdict(set)
    # UW room: 22 cols x 32 rows of cells. Quad grid: 11 quad cols x 16
    # quad rows? Actually AT is 8x8 quad grid per audit (64 bytes).
    # Each attr byte covers a 2x2 cell group. With 22x32 cells, we have
    # 11 quad cols x 16 quad rows = 176 quads — but attr is 64 bytes.
    # Per audit_bg_subpal_refs: 4 quads per byte, 64 bytes -> 256 quads,
    # covering 16x16 quad grid = 32x32 cells. Hmm doesn't match 22x32.
    #
    # Pragmatic: derive quad index from cell (col, row): each attr byte
    # is for a 4-cell group (2x2). With 22 cols, 11 quad columns. 32
    # rows -> 16 quad rows. 11*16 = 176 quads. But attr_bytes = 64.
    #
    # Approximation: bias toward 8x8 quad grid (NES default), iterate
    # cells, derive quad from (col // 2, row // 2) modulo 8x8 (clamp).
    QUAD_COLS = 8
    QUAD_ROWS = 8
    QUADS_PER_ROW = 8
    for room_idx, nt, attr in rooms:
        for row in range(32):
            for col in range(22):
                tile_id = nt[row * 32 + col] if (row * 32 + col) < len(nt) else 0
                # Approximate quad lookup; cells map to 8x8 quad grid via
                # (col // (22 // 8), row // (32 // 8)) ≈ (col // 2, row // 4).
                q_col = min(col // 2, QUAD_COLS - 1)
                q_row = min(row // 4, QUAD_ROWS - 1)
                quad_idx = q_row * QUADS_PER_ROW + q_col
                if quad_idx >= len(attr):
                    continue
                attr_byte = attr[quad_idx]
                # Each byte has 4 quads (TL/TR/BL/BR). Pick pos based on
                # (col % 2, row % 2)... approximate.
                sub_quad_col = col % 2
                sub_quad_row = (row // 2) % 2
                pos = sub_quad_row * 2 + sub_quad_col
                sub_pal = uw_quad_subpal(attr_byte, pos)
                out[tile_id].add(sub_pal)
    return out


def parse_ow_data():
    """Returns list of (room_idx, tile_ids[N], single_attr)."""
    if not OW_C.exists():
        return []
    text = OW_C.read_text(encoding="utf-8", errors="ignore")
    blob_match = re.search(r"rooms_overworld\[\] = \{(.+?)\};", text, re.S)
    if not blob_match:
        return []
    bs = [int(b, 16) for b in re.findall(r"0x([0-9a-fA-F]{2})",
                                          blob_match.group(1))]
    # 128 rooms x N tile bytes + 128 attr bytes. Heuristic: skip the
    # attr table at the end for simplicity; use first 128 as room IDs.
    rooms = []
    for room in range(128):
        # NES Z1 OW: each room has ~16x11 = 176 BG cells of tile data,
        # stored compactly. The exact offsets are in overworld_offsets.h.
        # For audit purposes, approximate by counting attr byte usage.
        attr_byte = bs[128 + room] if (128 + room) < len(bs) else 0
        rooms.append((room, attr_byte))
    return rooms


def main():
    uw_rooms = parse_uw_blob()
    print(f"UW rooms parsed: {len(uw_rooms)}")

    if not uw_rooms:
        print("ERROR: no UW rooms parsed; check uw_room_blob.c format")
        return 1

    per_tile_uw = collect_uw_per_tile_subpals(uw_rooms)

    # Histogram of (distinct sub-pal count) per tile
    histogram = defaultdict(int)
    multi_subpal_tiles = []
    for tile_id, subpals in per_tile_uw.items():
        n_distinct = len(subpals)
        histogram[n_distinct] += 1
        if n_distinct >= 3:
            multi_subpal_tiles.append((tile_id, sorted(subpals)))

    total_tiles_used = sum(histogram.values())
    print(f"\nUW per-tile sub-pal distribution (across {total_tiles_used} unique tile IDs):")
    for k in sorted(histogram.keys()):
        pct = 100.0 * histogram[k] / total_tiles_used
        print(f"  tiles using {k} sub-pal(s): {histogram[k]:4d}  ({pct:5.1f}%)")

    # Net replication needed = sum of distinct sub-pals per tile
    total_copies_needed = sum(len(s) for s in per_tile_uw.values())
    total_copies_4x = total_tiles_used * 4
    savings_tiles = total_copies_4x - total_copies_needed
    savings_pct = 100.0 * savings_tiles / total_copies_4x

    print(f"\nReplication accounting (UW BG only):")
    print(f"  current (4x replication): {total_copies_4x:4d} tile copies")
    print(f"  selective dedup minimum:  {total_copies_needed:4d} tile copies")
    print(f"  potential savings:        {savings_tiles:4d} tiles ({savings_pct:.1f}%)")

    print(f"\nTiles needing 3+ sub-pals (worst-case replication):")
    for tile_id, sps in sorted(multi_subpal_tiles)[:20]:
        print(f"  tile 0x{tile_id:02X}: {sps}")
    if len(multi_subpal_tiles) > 20:
        print(f"  ... and {len(multi_subpal_tiles) - 20} more")

    return 0


if __name__ == "__main__":
    sys.exit(main())
