#!/usr/bin/env python3
"""WIP RULE V1 byte-diff: replicate blit_blob OFFLINE for the injected boss room
and compare to its LIVE Genesis plane capture. Deterministic — same sparse LUT,
attr->subpal math, BG_TILE_BASE as the ROM. VDP plane is 64 cols wide.

STATUS: LUT parse + plane-width fixed; the live VDP plane BASE for UW is not yet
pinned (brute force over $C000/$E000 + offsets did not align -> needs the actual
VDP reg2/reg4 nametable base read live, or plane_write's VRAM base traced). Until
then this verifier is not authoritative. Injection correctness rests on: generator
Gate-A byte-exact (0 floor/frame errors, 636 rooms), lookup resolves all 12 rooms,
and the blit_blob path proven byte-exact on the 171-room Q1 sweep."""
import re, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
CAP = pathlib.Path("C:/tmp/cave_golden")
BG_TILE_BASE = 1; BLANK = 0; PLANE_W = 64

def grab(txt,name):
    m=re.search(r"\b"+name+r"\b[^{]*\{",txt); i=m.end(); d=1; s=i
    while d:
        c=txt[i]
        if c=='{': d+=1
        elif c=='}': d-=1
        i+=1
    return txt[s:i-1]
blob=(ROOT/"RoomRom"/"src"/"uw_room_blob.c").read_text(errors="replace")
INDEX=[[int(x,16) for x in re.findall(r"0x[0-9a-fA-F]+",r)] for r in re.findall(r"\{([^}]*)\}",grab(blob,"g_uw_room_index"))]
_nt=re.findall(r"\{([^{}]*)\}",grab(blob,"g_uw_room_nt"))
_at=re.findall(r"\{([^{}]*)\}",grab(blob,"g_uw_room_attr"))
def bytes_of(rows,e): return [int(x,16) for x in re.findall(r"0x[0-9a-fA-F]+",rows[e])]

# parse LUT[256][4]: each inner {a,b,c,d} -> first 4 ints (ignore trailing comments)
lut_txt=(ROOT/"RoomRom"/"src"/"bg_sparse_chr.c").read_text(errors="replace")
inner=re.findall(r"\{([^{}]*)\}",grab(lut_txt,"bg_sparse_tile_lut"))
LUT=[]
for row in inner:
    v=[int(x,0) for x in re.findall(r"0x[0-9a-fA-F]+|\b\d+\b",row)][:4]
    if len(v)==4: LUT.append(v)
assert len(LUT)>=256, len(LUT)
print("LUT rows=%d  LUT[0x74]=%s"%(len(LUT),LUT[0x74]))

def attr_pal(attr,nt_col,nt_row):
    at_idx=((nt_row>>2)<<3)|(nt_col>>2); byte=attr[at_idx & 0x3F]
    shift=(((nt_row>>1)&1)<<2)|(((nt_col>>1)&1)<<1)
    return (byte>>shift)&3
def expected(nt,attr):
    g=[[0]*32 for _ in range(22)]
    for r in range(22):
        for c in range(32):
            raw=nt[r*32+c]; pal=attr_pal(attr,c,r+8); slot=LUT[raw][pal&3]
            g[r][c]= BLANK if slot==0xFFFF else (BG_TILE_BASE+slot)
    return g
def plane(base):
    d=pathlib.Path(CAP/"gen_L9Q1_R42"/"f120.bin").read_bytes(); o=8+128+base
    return [[((d[o+(r*PLANE_W+c)*2]<<8)|d[o+(r*PLANE_W+c)*2+1])&0x7FF for c in range(PLANE_W)] for r in range(32)]

e=[i for i,r in enumerate(INDEX) if r==[0,1,9,0x42]][0]
exp=expected(bytes_of(_nt,e),bytes_of(_at,e))
best=None
for base in (0xC000,0xE000):
    P=plane(base)
    for roff in range(0,11):
        for coff in range(0,34):
            miss=tot=0
            for r in range(22):
                for c in range(32):
                    if r+roff>=32 or c+coff>=PLANE_W: continue
                    tot+=1
                    if exp[r][c]!=P[r+roff][c+coff]: miss+=1
            if tot>600 and (best is None or miss<best[0]): best=(miss,tot,base,roff,coff)
miss,tot,base,roff,coff=best
print("injected L9 $42: best base=$%04X roff=%d coff=%d -> %d/%d mismatch (%.1f%%)"%(base,roff,coff,miss,tot,100*miss/tot))
print("VERDICT:", "BYTE-EXACT — live Gen plane == blit_blob(injected nt+attr)" if miss==0 else "%d cells differ"%miss)
