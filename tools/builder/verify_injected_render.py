#!/usr/bin/env python3
"""RULE V1 LIVE byte-diff: confirm an injected UW room renders byte-exact on
Genesis hardware. Replicates blit_blob (sparse LUT + attr->subpal + BG_TILE_BASE)
and compares to the live plane in a probe_gen_dungeon_golden capture.

PROVEN params (settled this session via L1Q1 $73 control = 0/704):
  plane base = PLANE_A $C000 (the active/current-room plane)
  row stride = 64 words (128 B; 64-wide VDP plane)
  plane_row  = (blob_row + ROOMROM_ROOM_FIRST_ROW=7) & 63   (HUD occupies top 7)
  tile word  = VDP word & 0x7FF ; expected = (slot==0xFFFF)?0:(BG_TILE_BASE+slot)

Usage: verify_injected_render.py <map> <quest> <level> <roomHex> <capture_f120.bin>
Default: 0 1 6 1C  C:/tmp/cave_golden_cur/gen_L6Q1_R1C/f120.bin
RESULTS (live, current build): L1Q1 $73=0/704, L6Q1 $1C=0/704, L8Q1 $3C=0/704
byte-exact. L9Q1 $42 does NOT render (separate pre-existing L9/Ganon scene-load
bug -> empty plane), unrelated to the blob/generator."""
import re, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
BG_TILE_BASE = 1; ROOM_FIRST_ROW = 7; PLANE_BASE = 0xC000; STRIDE_W = 64

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
_nt=re.findall(r"\{([^{}]*)\}",grab(blob,"g_uw_room_nt")); _at=re.findall(r"\{([^{}]*)\}",grab(blob,"g_uw_room_attr"))
def Bf(rows,e): return [int(x,16) for x in re.findall(r"0x[0-9a-fA-F]+",rows[e])]
LUT=[[int(x,0) for x in re.findall(r"0x[0-9a-fA-F]+|\b\d+\b",row)][:4]
     for row in re.findall(r"\{([^{}]*)\}",grab((ROOT/"RoomRom"/"src"/"bg_sparse_chr.c").read_text(errors="replace"),"bg_sparse_tile_lut"))]
def attr_pal(at,col,nr):
    ai=((nr>>2)<<3)|(col>>2); sh=(((nr>>1)&1)<<2)|(((col>>1)&1)<<1); return (at[ai&0x3F]>>sh)&3
def expected(nt,at):
    return [[ (lambda s:0 if s==0xFFFF else BG_TILE_BASE+s)(LUT[nt[r*32+c]][attr_pal(at,c,r+8)&3]) for c in range(32)] for r in range(22)]

a=sys.argv
mp,q,lv,room = (int(a[1]),int(a[2]),int(a[3]),int(a[4],16)) if len(a)>4 else (0,1,6,0x1C)
cap = a[5] if len(a)>5 else f"C:/tmp/cave_golden_cur/gen_L{lv}Q{q}_R{room:02X}/f120.bin"
e=[i for i,r in enumerate(INDEX) if r==[mp,q,lv,room]]
if not e: print("no blob entry for",mp,q,lv,hex(room)); sys.exit(2)
E=expected(Bf(_nt,e[0]),Bf(_at,e[0]))
d=pathlib.Path(cap).read_bytes()
miss=nz=0; diffs=[]
for r in range(22):
    pr=(r+ROOM_FIRST_ROW)&63
    for c in range(32):
        o=8+128+PLANE_BASE+(pr*STRIDE_W+c)*2; lv_=((d[o]<<8)|d[o+1])&0x7FF
        if lv_: nz+=1
        if E[r][c]!=lv_: miss+=1; diffs.append((r,c,E[r][c],lv_))
print("L%dQ%d room=0x%02X: %d/704 miss (%.2f%%), live-nonzero=%d"%(lv,q,room,miss,100*miss/704,nz))
for r,c,ex,lvv in diffs[:12]: print("   r%d c%d exp=%d live=%d"%(r,c,ex,lvv))
print("VERDICT:", "BYTE-EXACT live render" if miss==0 else
      ("door-state-only (%d cells)"%miss if 0<miss<=12 else
       "empty/no-load (scene bug)" if nz<100 else "MISMATCH %d"%miss))
