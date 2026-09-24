#!/usr/bin/env python3
"""For EVERY captured blob room, brute-force the uid whose RoomLayoutsUW decode
byte-matches the blob floor; report delta = true_uid - dungeons_uid grouped by
block (UW1=L1-6, UW2=L7-9) x quest. If delta is a single per-block constant, the
LayoutUWFloor generator generalizes to uncaptured rooms. Offline; no ROM."""
import re, pathlib, sys, collections
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "builder"))
import extract_uw_collision as X

txt = (ROOT / "RoomRom" / "src" / "uw_room_blob.c").read_text(errors="replace")
def grab(name):
    m = re.search(r"\b" + name + r"\b[^{]*\{", txt); i = m.end(); d = 1; s = i
    while d:
        c = txt[i]
        if c == '{': d += 1
        elif c == '}': d -= 1
        i += 1
    return txt[s:i-1]
index = [[int(x, 16) for x in re.findall(r"0x[0-9a-fA-F]+", r)] for r in re.findall(r"\{([^}]*)\}", grab("g_uw_room_index"))]
nt_rows = re.findall(r"\{([^{}]*)\}", grab("g_uw_room_nt"))
def nt_of(e): return [int(x, 16) for x in re.findall(r"0x[0-9a-fA-F]+", nt_rows[e])]

data = X.parse_dungeons_c(ROOT / "data" / "rooms" / "dungeons.c")
tables, _ = X.load_manifest(ROOT / "data" / "rooms" / "MANIFEST.json")
lay_off, _ = tables["RoomLayoutsUW"]

def dec(heap, ci):
    pos = 0; rem = ci
    while True:
        bb = heap[pos]; pos += 1
        if bb & 0x80:
            if rem == 0: pos -= 1; break
            rem -= 1
    t = []; rep = 0; r = 0
    while r < 7:
        d = heap[pos]; t.append(X.PRIMARY_SQUARES_UW[d & 7]); cnt = (d & 0x70) >> 4
        if cnt == rep: rep = 0; pos += 1
        else: rep += 1
        r += 1
    return t
def expand(p):
    if 0x70 <= p < 0xF3: return {(0,0):p,(0,1):(p+1)&255,(1,0):(p+2)&255,(1,1):(p+3)&255}
    return {(0,0):p,(0,1):p,(1,0):p,(1,1):p}
def decode_cols(uid):
    lay = data[lay_off + uid*12: lay_off + uid*12 + 12]
    return [dec(X.get_table(data, tables, f"ColumnHeapUW{(d>>4)&0xF}"), d & 0xF) for d in lay]
def match(nt, uid):
    def b(r,c): return nt[r*32+c]
    cols = decode_cols(uid); m = 0
    for ci in range(12):
        for ri in range(7):
            for (dc,dr),tile in expand(cols[ci][ri]).items():
                if b(4+2*ri+dr, 4+2*ci+dc) == tile: m += 1
    return m

# uid source = the CORRECT LevelBlock's sub-table D (+0x180), per (block,quest).
def lb_name(block, q): return f"LevelBlock{block}Q{q}"
def dungeons_uid(block, q, room):
    off, _ = tables[lb_name(block, q)]
    return data[off + 0x180 + room] & 0x3F

deltas = collections.defaultdict(collections.Counter)
exact = collections.Counter(); total = collections.Counter()
rows = []
for e, row in enumerate(index):
    if len(row) != 4: continue
    mp, q, lv, room = row
    block = "UW1" if lv <= 6 else "UW2"
    key = (block, q)
    nt = nt_of(e)
    # brute-force best uid + also test dungeons_uid+offset candidates
    best = (-1, -1)
    for uid in range(64):
        try: m = match(nt, uid)
        except Exception: continue
        if m > best[0]: best = (m, uid)
    m, tu = best
    du = dungeons_uid(block, q, room)
    total[key] += 1
    if m == 336:
        exact[key] += 1
        deltas[key][(tu - du) & 0x3F] += 1
    rows.append((block, q, lv, room, du, tu, m))

print("=== delta (true_uid - dungeons_uid) distribution per (block,quest), EXACT-match rooms only ===")
for key in sorted(deltas):
    print("  %s Q%d: exact %d/%d  deltas=%s" % (key[0], key[1], exact[key], total[key], dict(deltas[key])))
print("\n=== non-exact rooms (door/variant; check delta still holds via prediction) ===")
for block, q, lv, room, du, tu, m in rows:
    if m != 336:
        print("  %s Q%d L%d room=0x%02X  dungeons_uid=%d best_uid=%d match=%d/336  (du+const?)" % (block, q, lv, room, du, tu, m))
