#!/usr/bin/env python3
"""Byte-diff LBA-C/D for each boss room across THREE sources, to localize why
the Genesis port spawns wrong ObjTypes in boss rooms:

  A) reference/aldonunez/dat/LevelBlockUW{1,2}Q1.dat  -- NES ROM truth
  B) data/rooms/dungeons.c rooms_dungeons[]           -- port static data
  C) gen_boss_direct/<boss>/m68k_ram.bin              -- live runtime read

Runtime LBA cell = nes_ram[$697E+room] (C) / nes_ram[$69FE+room] (D); the dump
is the full RAM domain, NES mirror at offset $8000 -> dump[$8000+$697E+room].

list_id = (C & 0x3F) | (0x40 if D&0x80 else 0). template_id==list_id;
[$32,$62) => boss (count forced 1); <$32 => repeat ObjType; >=$62 => ObjList.
"""
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DUNGEONS_C = REPO / "data" / "rooms" / "dungeons.c"
DAT = REPO / "reference" / "aldonunez" / "dat"
GEN = REPO / "gen_boss_direct"

BLOCK = 768
C_OFF, D_OFF = 256, 384
RT_C, RT_D = 0x8000 + 0x697E, 0x8000 + 0x69FE  # dump offsets

# boss -> (room, dungeons.c block byte-offset, .dat filename)
BOSSES = [
    ("aquamentus",   0x35, 0,   "LevelBlockUW1Q1.dat"),
    ("dodongo",      0x56, 0,   "LevelBlockUW1Q1.dat"),
    ("manhandla",    0x10, 0,   "LevelBlockUW1Q1.dat"),
    ("gleeok_2head", 0x13, 0,   "LevelBlockUW1Q1.dat"),
    ("digdogger",    0x24, 0,   "LevelBlockUW1Q1.dat"),
    ("gohma",        0x1C, 0,   "LevelBlockUW1Q1.dat"),
    ("aquamentus_2", 0x2A, 768, "LevelBlockUW2Q1.dat"),
    ("gleeok_4head", 0x3C, 768, "LevelBlockUW2Q1.dat"),
    ("patra_red",    0x52, 768, "LevelBlockUW2Q1.dat"),
    ("ganon",        0x42, 768, "LevelBlockUW2Q1.dat"),
]


def load_dungeons():
    txt = DUNGEONS_C.read_text(encoding="utf-8")
    return bytes(int(b, 16) for b in re.findall(r"0x([0-9a-fA-F]{2})", txt))


def list_id(c, d):
    return (c & 0x3F) | (0x40 if (d & 0x80) else 0)


def kind(lid):
    if lid == 0:
        return "empty"
    if lid < 0x32:
        return "repeat(<$32)"
    if lid < 0x62:
        return "BOSS/uniq[$32,$62)"
    return "ObjList(>=$62)"


def main():
    blob = load_dungeons()
    print(f"# dungeons.c = {len(blob)} bytes\n")
    hdr = f"{'boss':14} {'rm':4} {'src':10} {'C':3} {'D':3} {'list_id':8} {'kind'}"
    for name, room, blk, datname in BOSSES:
        dat = (DAT / datname).read_bytes()
        a_c, a_d = dat[C_OFF + room], dat[D_OFF + room]
        b_c, b_d = blob[blk + C_OFF + room], blob[blk + D_OFF + room]
        rt = GEN / name / "m68k_ram.bin"
        if rt.exists():
            raw = rt.read_bytes()
            c_c, c_d = raw[RT_C + room], raw[RT_D + room]
        else:
            c_c = c_d = -1
        print(hdr)
        for tag, c, d in (("A .dat", a_c, a_d), ("B dung.c", b_c, b_d),
                          ("C runtime", c_c, c_d)):
            if c < 0:
                print(f"{name:14} ${room:02X}  {tag:10} (no dump)")
                continue
            lid = list_id(c, d)
            print(f"{name:14} ${room:02X}  {tag:10} ${c:02X} ${d:02X} "
                  f"${lid:02X}     {kind(lid)}")
        # verdict
        a, b = list_id(a_c, a_d), list_id(b_c, b_d)
        c_lid = list_id(c_c, c_d) if c_c >= 0 else None
        v = []
        if a != b:
            v.append(f"DAT!=DUNGEONS (extraction: $%02X vs $%02X)" % (a, b))
        if c_lid is not None and c_lid != b:
            v.append(f"RUNTIME!=DUNGEONS (install: $%02X vs $%02X)" % (c_lid, b))
        if c_lid is not None and c_lid == b == a:
            v.append("all three agree")
        print(f"  -> {'; '.join(v) if v else 'see above'}\n")


def investigate_layout():
    """Where does the CORRECT .dat UW1Q1 data live in dungeons.c (if at all)?"""
    blob = load_dungeons()
    dat = (DAT / "LevelBlockUW1Q1.dat").read_bytes()
    print("\n=== LAYOUT INVESTIGATION (UW1Q1) ===")
    # 1. full-block diff at offset 0
    blk = blob[0:768]
    nmis = sum(1 for i in range(768) if blk[i] != dat[i])
    print(f"dungeons.c[0:768] vs .dat[0:768]: {nmis}/768 bytes differ")
    # 2. is the full 768 .dat block a substring of dungeons.c anywhere?
    idx = bytes(blob).find(dat)
    print(f"full .dat block found in dungeons.c at offset: {idx}")
    # 3. is the C sub-table (.dat[256:384]) a substring anywhere?
    ctab = dat[256:384]
    ci = bytes(blob).find(ctab)
    print(f".dat C-table (128B) found in dungeons.c at offset: {ci}")
    dtab = dat[384:512]
    di = bytes(blob).find(dtab)
    print(f".dat D-table (128B) found in dungeons.c at offset: {di}")
    # 4. room-major hypothesis: C[$35] at blk + $35*6 + 2 ?
    room = 0x35
    for sub in range(6):
        v = blob[room * 6 + sub]
        print(f"room-major guess blk0 room$35 sub{sub} = dungeons[{room*6+sub}] = ${v:02X}"
              + ("   <-- $3D match!" if v == 0x3D else ""))
    # 5. where does $3D (aqua list_id) appear in first 768 bytes?
    hits = [i for i in range(768) if blob[i] == 0x3D]
    print(f"$3D appears in dungeons.c[0:768] at offsets: {hits[:20]}")


def compare_all_blocks():
    """Full byte-diff of every LevelBlock + LevelInfoUW: C-array vs .dat,
    to scope the extraction corruption."""
    print("\n=== FULL BLOCK DIFF (C-array vs .dat) ===")
    ow = bytes(int(b, 16) for b in re.findall(
        r"0x([0-9a-fA-F]{2})", (REPO / "data" / "rooms" / "overworld.c").read_text()))
    dg = load_dungeons()

    def diff(name, arr, off, datname, n):
        dat = (DAT / datname).read_bytes()[:n]
        seg = bytes(arr[off:off + n])
        nmis = sum(1 for i in range(n) if seg[i] != dat[i])
        tag = "IDENTICAL" if nmis == 0 else f"{nmis}/{n} DIFFER"
        print(f"  {name:22} {datname:22} {tag}")
        return nmis

    diff("OW LevelBlock", ow, 0, "LevelBlockOW.dat", 768)
    diff("OW LevelInfo", ow, 768, "LevelInfoOW.dat", 256)
    diff("UW1Q1 LevelBlock", dg, 0, "LevelBlockUW1Q1.dat", 768)
    diff("UW2Q1 LevelBlock", dg, 768, "LevelBlockUW2Q1.dat", 768)
    diff("UW1Q2 LevelBlock", dg, 1536, "LevelBlockUW1Q2.dat", 768)
    diff("UW2Q2 LevelBlock", dg, 2304, "LevelBlockUW2Q2.dat", 768)
    for n in range(1, 10):
        diff(f"UW LevelInfo L{n}", dg, 3072 + (n - 1) * 256,
             f"LevelInfoUW{n}.dat", 256)


def cross_match():
    """What .dat (if any) does each PRG-extracted UW block actually equal?"""
    print("\n=== CROSS-MATCH (which .dat does each dungeons.c block equal?) ===")
    dg = load_dungeons()
    dats = {name: (DAT / f"LevelBlock{name}.dat").read_bytes()
            for name in ("UW1Q1", "UW2Q1", "UW1Q2", "UW2Q2", "OW")}
    for label, off in (("dungeons[0:768] (lbl UW1Q1)", 0),
                       ("dungeons[768:1536] (lbl UW2Q1)", 768),
                       ("dungeons[1536:2304] (lbl UW1Q2)", 1536),
                       ("dungeons[2304:3072] (lbl UW2Q2)", 2304)):
        seg = bytes(dg[off:off + 768])
        best = None
        for name, d in dats.items():
            nmis = sum(1 for i in range(768) if seg[i] != d[i])
            if best is None or nmis < best[1]:
                best = (name, nmis)
        eq = [name for name, d in dats.items() if bytes(d) == seg]
        print(f"  {label:32} best=.dat {best[0]} ({best[1]}/768 diff)"
              + (f"  EXACT={eq}" if eq else ""))


if __name__ == "__main__":
    main()
    investigate_layout()
    compare_all_blocks()
    cross_match()
