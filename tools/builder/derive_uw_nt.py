#!/usr/bin/env python3
"""Derive the UW square->nametable transform by brute-force aligning a decoded
room's WriteSquareUW expansion against the real NES CIRAM (room $73). Offline."""
import sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "builder"))
import extract_uw_collision as X

data = X.parse_dungeons_c(ROOT / "data" / "rooms" / "dungeons.c")
tables, _ = X.load_manifest(ROOT / "data" / "rooms" / "MANIFEST.json")
ROOM = 0x73
uid = data[0x180 + ROOM] & 0x3F
lay_off, _ = tables["RoomLayoutsUW"]
layout = data[lay_off + uid*12 : lay_off + uid*12 + 12]
cols = []
for desc in layout:
    heap = X.get_table(data, tables, f"ColumnHeapUW{(desc>>4)&0xF}")
    cols.append(X.decode_heap_column(heap, desc & 0xF))   # 7 primary tiles

def expand(p):  # WriteSquareUW: returns (TL,TR,BL,BR)
    if 0x70 <= p < 0xF3:
        return (p, (p+2)&0xFF, (p+1)&0xFF, (p+3)&0xFF)  # T1: TL,TR,BL,BR = p,p+2,p+1,p+3
    return (p, p, p, p)                                  # T2: all p

# build 14x24 tile block, two orientations: col-major (square-col=room col) and
# its transpose, to catch row/col ordering.
def block_colmajor():  # b[2r+..][2c+..]
    b = [[None]*24 for _ in range(14)]
    for c in range(12):
        for r in range(7):
            tl,tr,bl,br = expand(cols[c][r])
            b[2*r][2*c]=tl; b[2*r][2*c+1]=tr; b[2*r+1][2*c]=bl; b[2*r+1][2*c+1]=br
    return b

bin_ = pathlib.Path(r"C:/tmp/cave_golden/nes_L1Q1_R73/f120.bin").read_bytes()
ci_off = 8+256+32+8192+1
nt0 = bin_[ci_off:ci_off+1024]
def ci(r,c): return nt0[r*32+c]

blk = block_colmajor()
best=None
for r0 in range(0,17):
    for c0 in range(0,9):
        if r0+14>30 or c0+24>32: continue
        m=0; t=0
        for i in range(14):
            for j in range(24):
                if blk[i][j] is None: continue
                t+=1
                if blk[i][j]==ci(r0+i,c0+j): m+=1
        if best is None or m>best[0]: best=(m,t,r0,c0)
print("colmajor best: match=%d/%d at row0=%d col0=%d"%best)
# also try transpose (square-row=room col)
def block_rowmajor():
    b=[[None]*14 for _ in range(24)]
    for c in range(12):
        for r in range(7):
            tl,tr,bl,br=expand(cols[c][r])
            b[2*c][2*r]=tl; b[2*c][2*r+1]=tr; b[2*c+1][2*r]=bl; b[2*c+1][2*r+1]=br
    return b
blk2=block_rowmajor(); best2=None
for r0 in range(0,7):
    for c0 in range(0,9):
        if r0+24>30 or c0+14>32: continue
        m=0;t=0
        for i in range(24):
            for j in range(14):
                if blk2[i][j] is None: continue
                t+=1
                if blk2[i][j]==ci(r0+i,c0+j): m+=1
        if best2 is None or m>best2[0]: best2=(m,t,r0,c0)
print("rowmajor(transpose) best: match=%d/%d at row0=%d col0=%d"%best2)
