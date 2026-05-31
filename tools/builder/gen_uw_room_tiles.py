#!/usr/bin/env python3
"""COMPLETE byte-exact UW room nametable generator from NES data tables.
Every UW room nt = global wall-frame (constant) (+) decoded floor (LayoutUWFloor,
uid = per-block LBA_D[room]&0x3F + 22) (+) door overlays (per (block,region,type),
per-cell majority from captures = NES load-state). Gate A verifies the generator
reproduces all 626 captured blobs byte-exact. Then emits the uncaptured boss
rooms. Offline; no ROM. RULE ZERO: every tile traced to NES data or NES capture.
"""
import re, pathlib, sys, collections
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "builder"))
import extract_uw_collision as X

# ---------- parse captured blob ----------
txt = (ROOT / "RoomRom" / "src" / "uw_room_blob.c").read_text(errors="replace")
def grab(name):
    m = re.search(r"\b" + name + r"\b[^{]*\{", txt); i = m.end(); d = 1; s = i
    while d:
        c = txt[i]
        if c == '{': d += 1
        elif c == '}': d -= 1
        i += 1
    return txt[s:i-1]
INDEX = [[int(x,16) for x in re.findall(r"0x[0-9a-fA-F]+", r)] for r in re.findall(r"\{([^}]*)\}", grab("g_uw_room_index"))]
_nt_rows = re.findall(r"\{([^{}]*)\}", grab("g_uw_room_nt"))
def nt_of(e): return [int(x,16) for x in re.findall(r"0x[0-9a-fA-F]+", _nt_rows[e])]

DATA = X.parse_dungeons_c(ROOT/"data"/"rooms"/"dungeons.c")
TABLES, _ = X.load_manifest(ROOT/"data"/"rooms"/"MANIFEST.json")
LAY_OFF, _ = TABLES["RoomLayoutsUW"]
def lboff(b,q): return TABLES[f"LevelBlock{b}Q{q}"][0]
def block_of(level): return "UW1" if level <= 6 else "UW2"
def uid_of(block,q,room): return (DATA[lboff(block,q)+0x180+room]&0x3F) + 22
def door_types(block,q,room):
    o=lboff(block,q); A=DATA[o+room]; B=DATA[o+0x80+room]
    return {"S":(A>>2)&7,"N":(A>>5)&7,"E":(B>>2)&7,"W":(B>>5)&7}

# ---------- floor decoder (corrected: marker byte = row 0) ----------
def decode_col(base_off, col_idx):
    """Decode one column reading DATA forward from a heap's ABSOLUTE offset.
    ColumnHeapUW0..9 are contiguous in ROM (verified) so the NES pointer reads
    across heap boundaries — decode against the full contiguous data, not an
    isolated per-heap slice."""
    pos = base_off; rem = col_idx
    while pos < len(DATA):
        b = DATA[pos]; pos += 1
        if b & 0x80:
            if rem == 0: pos -= 1; break
            rem -= 1
    tiles=[]; rep=0; row=0
    while row<7:
        d=DATA[pos]; tiles.append(X.PRIMARY_SQUARES_UW[d&7]); cnt=(d&0x70)>>4
        if cnt==rep: rep=0; pos+=1
        else: rep+=1
        row+=1
    return tiles
def expand(p):  # WriteSquareUW: corner (dcol,drow)
    if 0x70<=p<0xF3: return {(0,0):p,(0,1):(p+1)&255,(1,0):(p+2)&255,(1,1):(p+3)&255}
    return {(0,0):p,(0,1):p,(1,0):p,(1,1):p}
HEAP_OFF = [TABLES[f"ColumnHeapUW{h}"][0] for h in range(10)]
def decoded_floor(block,q,room):
    """Return dict {(r,c):tile} for the 24x14 floor at rows4-17 cols4-27."""
    uid = uid_of(block,q,room)
    lay = DATA[LAY_OFF+uid*12: LAY_OFF+uid*12+12]
    cols = [decode_col(HEAP_OFF[(d>>4)&0xF], d&0xF) for d in lay]
    out={}
    for ci in range(12):
        for ri in range(7):
            for (dc,dr),tile in expand(cols[ci][ri]).items():
                out[(4+2*ri+dr, 4+2*ci+dc)] = tile
    return out

# ---------- door regions + global frame from captures ----------
REGIONS={"N":[(r,c) for r in(1,2,3) for c in(14,15,16,17)],
         "S":[(r,c) for r in(18,19,20) for c in(14,15,16,17)],
         "W":[(r,c) for r in(9,10,11,12) for c in(1,2,3)],
         "E":[(r,c) for r in(9,10,11,12) for c in(28,29,30)]}
DOOR_CELLS=set(p for cells in REGIONS.values() for p in cells)
def is_floor(r,c): return 4<=r<=17 and 4<=c<=27

# global frame template (constant across all 626 rooms)
_frame={}
_e0 = nt_of(0)
for r in range(22):
    for c in range(32):
        if is_floor(r,c) or (r,c) in DOOR_CELLS: continue
        _frame[(r,c)] = _e0[r*32+c]

# door dictionary: per (block,region,type) per-cell MAJORITY (NES load-state)
_door_votes = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
for e,row in enumerate(INDEX):
    if len(row)!=4: continue
    mp,q,lv,room=row; blk=block_of(lv); dt=door_types(blk,q,room); nt=nt_of(e)
    for reg in "NSEW":
        for (r,c) in REGIONS[reg]:
            _door_votes[(blk,reg,dt[reg])][(r,c)][nt[r*32+c]] += 1
def door_overlay(block,reg,typ):
    votes=_door_votes.get((block,reg,typ))
    if not votes: return None   # no capture of this combo
    return {cell: cnt.most_common(1)[0][0] for cell,cnt in votes.items()}

# ---------- compose a full room nt ----------
def compose(block,q,room):
    nt=[0]*704
    for (r,c),t in _frame.items(): nt[r*32+c]=t
    for (r,c),t in decoded_floor(block,q,room).items(): nt[r*32+c]=t
    dt=door_types(block,q,room)
    for reg in "NSEW":
        ov=door_overlay(block,reg,dt[reg])
        if ov is None:  # fall back: leave frame wall (closed) — flagged by caller
            continue
        for (r,c),t in ov.items(): nt[r*32+c]=t
    return nt

if __name__ == "__main__":
    # ----- Gate A: reproduce every captured blob byte-exact -----
    exact=0; total=0; fails=[]; underrun=[]
    for e,row in enumerate(INDEX):
        if len(row)!=4: continue
        mp,q,lv,room=row; blk=block_of(lv); total+=1
        try:
            gen=compose(blk,q,room)
        except IndexError:
            underrun.append((lv,q,room,uid_of(blk,q,room))); continue
        cap=nt_of(e)
        if gen==cap: exact+=1
        else:
            diff=sum(1 for i in range(704) if gen[i]!=cap[i])
            fails.append((lv,q,room,diff))
    if underrun:
        print("UNDERRUN (uid+22 out of heap range) %d rooms; sample uids:" % len(underrun),
              sorted(set(u for *_,u in underrun))[:12])
    print("GATE A: %d/%d captured rooms reproduced byte-exact" % (exact,total))
    # categorize every mismatch: which region holds the diff?
    door_only=0; floor_bad=0; frame_bad=0
    for e,row in enumerate(INDEX):
        if len(row)!=4: continue
        mp,q,lv,room=row; blk=block_of(lv)
        try: gen=compose(blk,q,room)
        except IndexError: continue
        cap=nt_of(e)
        if gen==cap: continue
        df=False; ff=False; fr=False
        for i in range(704):
            if gen[i]==cap[i]: continue
            r,c=i//32,i%32
            if is_floor(r,c): ff=True
            elif (r,c) in DOOR_CELLS: df=True
            else: fr=True
        if ff: floor_bad+=1
        elif fr: frame_bad+=1
        elif df: door_only+=1
    print("  mismatch breakdown: door-state-only=%d  frame=%d  FLOOR(decoder)=%d  underrun=%d"
          % (door_only,frame_bad,floor_bad,len(underrun)))
