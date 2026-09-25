"""OW room layout + walkability from the extracted ROM data, for planning
lockstep routes (which edge columns/rows Link can cross between rooms).

Mirrors src/game/world/render/ow_render.c (NES LayoutRoomOW column walk and
the OW walkable-primary set). Planning aid only: routes it proposes are
verified by the captures themselves.

    python tools/lockstep/ow_map.py 77          # print room $77 grid
    python tools/lockstep/ow_map.py route 77 39 # edge crossings along a path
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ATTRS_D, LAYOUTS, HEAP = 384, 1166, 3150
HEAP_OFFSETS = [0, 53, 102, 168, 236, 286, 346, 405, 464, 526, 591, 660, 721, 775, 841, 893]
PRIMARY = [
    0x24, 0x6F, 0xF3, 0xFA, 0x98, 0x90, 0x8F, 0x95, 0x8E, 0x90, 0x74, 0x76, 0xF3, 0x24, 0x26, 0x89,
    0x03, 0x04, 0x70, 0xC8, 0xBC, 0x8D, 0x8F, 0x93, 0x95, 0xC4, 0xCE, 0xD8, 0xB0, 0xB4, 0xAA, 0xAC,
    0xB8, 0x9C, 0xA6, 0x9A, 0xA2, 0xA0, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xC0, 0xE0, 0x78, 0x7A,
    0x7E, 0x80, 0xCC, 0xD0, 0xD4, 0xDC, 0x89, 0x84, 0x24, 0x24, 0x24, 0x24, 0x6F, 0x6F, 0x6F, 0x6F]
SECONDARY_TL = [0x24, 0x6F, 0xF3, 0xFA, 0x98, 0x90, 0x8F, 0x95, 0x8E, 0x90, 0x74, 0x76, 0xF3, 0x24, 0x26, 0x89]
TILE_OBJ = {0xE5: 0xC8, 0xE6: 0xD8, 0xE7: 0xC4, 0xE8: 0xBC, 0xE9: 0xC0, 0xEA: 0xC0}
WALK = {0x03, 0x04, 0x24, 0x26, 0x54, 0x56, 0x58, 0x5C, 0x6F, 0x70, 0x74, 0x75, 0x76, 0x77,
        0x84, 0x8D, 0x91, 0x9C, 0xAC, 0xAD, 0xCC, 0xD2, 0xD5, 0xDF, 0xF3}


def blob():
    s = (ROOT / "data" / "rooms" / "overworld.c").read_text()
    i = s.index("rooms_overworld[")
    body = s[s.index("{", i):s.index("};", i)]
    return bytes(int(x, 16) for x in re.findall(r"0x([0-9A-Fa-f]{2})", body))


B = blob()


def room_grid(room):
    uid = B[ATTRS_D + room] & 0x7F
    grid = [[0] * 11 for _ in range(16)]
    for col in range(16):
        desc = B[LAYOUTS + uid * 16 + col]
        ptr = HEAP + HEAP_OFFSETS[desc >> 4]
        found, y = desc & 0x0F, 0
        while True:
            if B[ptr + y] & 0x80:
                if found == 0:
                    break
                found -= 1
            y += 1
        ptr += y
        row, rep = 0, 0
        while row < 11:
            sq = B[ptr] & 0x3F
            tl = PRIMARY[sq] if sq >= 0x10 else SECONDARY_TL[sq]
            grid[col][row] = TILE_OBJ.get(tl, tl)
            row += 1
            if B[ptr] & 0x40:
                rep ^= 0x40
                if rep:
                    continue
            ptr += 1
    return grid


def walkable(room):
    g = room_grid(room)
    return [[g[c][r] in WALK for r in range(11)] for c in range(16)]


def show(room):
    w = walkable(room)
    print(f"room ${room:02X}  (. walkable, # blocked)")
    for r in range(11):
        print(f"  Y{r * 16 + 0x40:02X} " + "".join("." if w[c][r] else "#" for c in range(16)))


def crossing(a, b):
    """Edge crossings from room a to adjacent room b: list of (col,row)
    metatile positions on a's edge whose neighbour cell in b is walkable."""
    wa, wb = walkable(a), walkable(b)
    d = b - a
    if d == 1:
        return [(15, r) for r in range(11) if wa[15][r] and wb[0][r]]
    if d == -1:
        return [(0, r) for r in range(11) if wa[0][r] and wb[15][r]]
    if d == -16:
        return [(c, 0) for c in range(16) if wa[c][0] and wb[c][10]]
    if d == 16:
        return [(c, 10) for c in range(16) if wa[c][10] and wb[c][0]]
    raise SystemExit("rooms not adjacent")


if __name__ == "__main__":
    if sys.argv[1] == "route":
        rooms = [int(x, 16) for x in sys.argv[2:]]
        for a, b in zip(rooms, rooms[1:]):
            print(f"${a:02X} -> ${b:02X}: {crossing(a, b)}")
    else:
        for r in sys.argv[1:]:
            show(int(r, 16))
