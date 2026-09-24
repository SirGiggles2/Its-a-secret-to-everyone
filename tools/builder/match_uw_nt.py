#!/usr/bin/env python3
"""RULE ZERO: align the LayoutUWFloor decode to the CAPTURED blob (the truth).
Parses RoomRom/src/uw_room_blob.c for a room's 22x32 nt, decodes the same room
via extract_uw_collision, emulates the exact WriteSquareUW col-major buffer, and
brute-forces the (row0,col0) offset + orientation that maximizes the match using
DISTINCTIVE primaries (not the ubiquitous $74). Offline; no ROM."""
import sys, re, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "builder"))
import extract_uw_collision as X

BLOB = ROOT / "RoomRom" / "src" / "uw_room_blob.c"
ROOM = int(sys.argv[1], 0) if len(sys.argv) > 1 else 0x73
LEVEL = int(sys.argv[2], 0) if len(sys.argv) > 2 else 1

# ---- parse blob: index + nt ----
txt = BLOB.read_text(errors="replace")
def grab_array(name):
    m = re.search(r"\b" + name + r"\b[^{]*\{", txt)
    if not m: raise RuntimeError("no array " + name)
    i = m.end(); depth = 1; start = i
    while depth:
        c = txt[i]
        if c == '{': depth += 1
        elif c == '}': depth -= 1
        i += 1
    return txt[start:i-1]

idx_body = grab_array("g_uw_room_index")
# each row {a,b,c,d}
idx_rows = re.findall(r"\{([^}]*)\}", idx_body)
index = [[int(x, 16) for x in re.findall(r"0x[0-9a-fA-F]+", r)] for r in idx_rows]

nt_body = grab_array("g_uw_room_nt")
nt_rows = re.findall(r"\{([^{}]*)\}", nt_body)   # each room is a flat brace group
def parse_nt(s):
    return [int(x, 16) for x in re.findall(r"0x[0-9a-fA-F]+", s)]

# find entry: room_id==ROOM, level==LEVEL  (index row = {map,quest,level,room})
entry = None
for i, r in enumerate(index):
    if len(r) == 4 and r[3] == ROOM and r[2] == LEVEL:
        entry = i; break
if entry is None:
    for i, r in enumerate(index):
        if len(r) == 4 and r[3] == ROOM:
            entry = i; print("note: no level match, using first room_id hit map=%02X q=%d L=%d" % (r[0], r[1], r[2])); break
if entry is None: raise RuntimeError("room not in blob")
nt = parse_nt(nt_rows[entry])
assert len(nt) == 704, len(nt)
def blob(r, c): return nt[r*32 + c]
print("blob entry %d  index=%s" % (entry, index[entry]))

# ---- decode room via extract_uw_collision ----
data = X.parse_dungeons_c(ROOT / "data" / "rooms" / "dungeons.c")
tables, _ = X.load_manifest(ROOT / "data" / "rooms" / "MANIFEST.json")
uid = data[0x180 + ROOM] & 0x3F
lay_off, _ = tables["RoomLayoutsUW"]
layout = data[lay_off + uid*12: lay_off + uid*12 + 12]
def decode_col_asm(heap, col_idx):
    """Exact LayoutUWFloor: marker (high-bit) byte IS row-0 descriptor."""
    pos = 0; remaining = col_idx
    while True:
        b = heap[pos]; pos += 1
        if b & 0x80:
            if remaining == 0:
                pos -= 1   # back up: marker byte is the first row descriptor
                break
            remaining -= 1
    tiles = []; rep = 0; row = 0
    while row < 7:
        d = heap[pos]
        tiles.append(X.PRIMARY_SQUARES_UW[d & 0x07])
        cnt = (d & 0x70) >> 4
        if cnt == rep: rep = 0; pos += 1
        else: rep += 1
        row += 1
    return tiles

cols = []
for desc in layout:
    heap = X.get_table(data, tables, f"ColumnHeapUW{(desc>>4)&0xF}")
    cols.append(decode_col_asm(heap, desc & 0xF))
print("uid=%d (=$%02X)  layout=%s" % (uid, uid, " ".join("%02X" % d for d in layout)))
for ci in range(12):
    print("  col%2d: %s" % (ci, " ".join("%02X" % t for t in cols[ci])))

def expand(p):  # WriteSquareUW; corner key=(dcol,drow). asm: TL=p +0; BL=p+1 down(+1); TR=p+2 right(+$16); BR=p+3
    if 0x70 <= p < 0xF3:
        return {(0,0):p,(0,1):(p+1)&0xFF,(1,0):(p+2)&0xFF,(1,1):(p+3)&0xFF}
    return {(0,0):p,(0,1):p,(1,0):p,(1,1):p}

# ---- emulate exact col-major buffer (offset = bcol*22 + brow) ----
# TL buffer offset = $8C + c*$2C + r*2 ; +1 down, +22 right.
buf = {}
for ci in range(12):
    for ri in range(7):
        base = 0x8C + ci*0x2C + ri*2
        e = expand(cols[ci][ri])
        for (dc, dr), tile in e.items():
            off = base + dr*1 + dc*22
            bcol, brow = off // 22, off % 22
            buf[(bcol, brow)] = tile
bcols = [k[0] for k in buf]; brows = [k[1] for k in buf]
print("buffer bcol %d..%d  brow %d..%d" % (min(bcols), max(bcols), min(brows), max(brows)))

# ---- brute force blob[r][c] = buffer(bcol = a*c+b, brow = ...) over simple offsets+transpose ----
DISTINCT = lambda t: t not in (0x74,)   # de-weight ubiquitous floor
best = []
for transpose in (False, True):
    for roff in range(-30, 31):
        for coff in range(-30, 31):
            m = t = md = td = 0
            for (bcol, brow), tile in buf.items():
                if transpose:
                    r, c = bcol + roff, brow + coff
                else:
                    r, c = brow + roff, bcol + coff
                if not (0 <= r < 22 and 0 <= c < 32):
                    t = -10000; break
                bt = blob(r, c); t += 1
                if bt == tile: m += 1
                if DISTINCT(tile):
                    td += 1
                    if bt == tile: md += 1
            if t > 0:
                best.append((md, m, td, t, transpose, roff, coff))
best.sort(reverse=True)
print("\nTOP matches (md=distinct-match, m=all-match, transpose,roff,coff):")
for md, m, td, t, tr, ro, co in best[:6]:
    print("  distinct %d/%d  all %d/%d  transpose=%s roff=%+d coff=%+d" % (md, td, m, t, tr, ro, co))
