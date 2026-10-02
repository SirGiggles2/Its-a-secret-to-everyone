"""Compare captured UW room attrs (uw_room_blob.c) with NES FillPlayAreaAttrs
computed from the ROM level-block attributes (data/rooms/dungeons.c)."""
import re
src = open('RoomRom/src/uw_room_blob.c', encoding='utf-8').read()
def arr(name):
    i = src.index('=', src.index(name)); j = src.index('};', i)
    return [int(v, 16) for v in re.findall(r'0x([0-9a-fA-F]+)', src[i:j])]
idx = arr('g_uw_room_index[649][4]')
attr = arr('g_uw_room_attr[649][64]')
d = open('data/rooms/dungeons.c', encoding='utf-8').read()
body = d[d.index('{', d.index('rooms_dungeons')) + 1:]
body = body[:body.index('}')]
dun = [int(v, 0) for v in re.findall(r'0x[0-9A-Fa-f]+|\d+', body)]
SEL = [0x00, 0x55, 0xAA, 0xFF]
def fill(block, room):
    a = dun[block * 768 + room]; b = dun[block * 768 + 128 + room]
    pa = [SEL[a & 3]] * 0x30
    for y in range(9, 0x27):
        if (y & 7) in (0, 7): continue
        if y >= 0x21: pa[y] = (SEL[b & 3] & 0x0F) | (pa[y] & 0xF0)
        else: pa[y] = SEL[b & 3]
    return pa
bad = 0; tot = 0
for e in range(649):
    mp, q, lv, rm = idx[e*4:e*4+4]
    if mp != 0 or lv == 0: continue
    block = (0 if lv <= 6 else 1) + (2 if q == 2 else 0)
    want = fill(block, rm)
    got = attr[e*64+16:e*64+64]
    tot += 1
    if want != got:
        bad += 1
        if bad <= 12:
            diffs = [k for k in range(48) if want[k] != got[k]]
            print(f'q{q} L{lv} room {rm:02X}: {len(diffs)} bytes differ, e.g. +{diffs[0]:02X} want {want[diffs[0]]:02X} got {got[diffs[0]]:02X}')
print(f'{bad}/{tot} captured rooms differ from FillPlayAreaAttrs')
