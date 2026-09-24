#!/usr/bin/env python3
"""Discover the door-field -> physical-region map and verify door-region tiles
are constant per (block, region, door_type) across all captured rooms. If
consistent, boss-room doors can be synthesized byte-exact by overlay. Offline."""
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
index = [[int(x,16) for x in re.findall(r"0x[0-9a-fA-F]+", r)] for r in re.findall(r"\{([^}]*)\}", grab("g_uw_room_index"))]
nt_rows = re.findall(r"\{([^{}]*)\}", grab("g_uw_room_nt"))
def nt_of(e): return [int(x,16) for x in re.findall(r"0x[0-9a-fA-F]+", nt_rows[e])]
data = X.parse_dungeons_c(ROOT/"data"/"rooms"/"dungeons.c"); tables,_ = X.load_manifest(ROOT/"data"/"rooms"/"MANIFEST.json")
def lboff(b,q): return tables[f"LevelBlock{b}Q{q}"][0]
def door_fields(b,q,room):
    o=lboff(b,q); A=data[o+0x00+room]; B=data[o+0x80+room]
    return {"A2":(A>>2)&7,"A5":(A>>5)&7,"B2":(B>>2)&7,"B5":(B>>5)&7}

# physical door regions (row,col cells)
REGIONS = {
 "N":[(r,c) for r in (1,2,3) for c in (14,15,16,17)],
 "S":[(r,c) for r in (18,19,20) for c in (14,15,16,17)],
 "W":[(r,c) for r in (9,10,11,12) for c in (1,2,3)],
 "E":[(r,c) for r in (9,10,11,12) for c in (28,29,30)],
}
def region_tiles(nt, reg): return tuple(nt[r*32+c] for r,c in REGIONS[reg])

# For each candidate (field -> region), check tile consistency per (block,value).
fields=["A2","A5","B2","B5"]; regions=["N","S","W","E"]
rooms=[]
for e,r in enumerate(index):
    if len(r)!=4: continue
    mp,q,lv,room=r; blk="UW1" if lv<=6 else "UW2"
    rooms.append((blk,q,room,door_fields(blk,q,room),nt_of(e)))

print("=== consistency score: for each (field,region), is region-tiles constant per (block,field_value)? ===")
for f in fields:
    for reg in regions:
        groups=collections.defaultdict(set)
        for blk,q,room,df,nt in rooms:
            groups[(blk,df[f])].add(region_tiles(nt,reg))
        consistent=sum(1 for v in groups.values() if len(v)==1)
        tot=len(groups)
        print("  field %s -> region %s : %d/%d (block,value) groups have ONE tile-set"%(f,reg,consistent,tot))
