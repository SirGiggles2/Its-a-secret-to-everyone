#!/usr/bin/env python3
"""Phase 1 root-cause differentiator for the boss-spawn gap (#1).

Compares, per level, the UW LevelBlockAttrs (LBA) the port INSTALLS vs the
.dat ROM source vs the LIVE NES capture (from probe_nes_boss_spawn.lua), and
derives the AUTHORITATIVE level->block map. Emits an H1/H2/H3 verdict:

  H1 — extraction byte-error: data/rooms/dungeons.c block != reference .dat
       -> fix = regen `python tools/extract_rooms.py`.
  H2 — routing/derivation bug: dungeons.c == .dat, but the live NES installs
       a DIFFERENT block per level than level_info_install.c picks
       -> fix = correct the level->block mapping in level_info_install.c.
  H3 — neither: data + routing match but boss still absent -> special path.

Inputs (all read-only):
  data/rooms/dungeons.c                     port blob (hex C-array)
  reference/aldonunez/dat/LevelBlockUW{1,2}Q{1,2}.dat   ROM source blocks
  tools/parity/out/nes_boss_spawn_L*_Q*_*.json          live NES (S1/S2)

Block layout (src/game/world/level_info_install.c + extract_rooms.py):
  dungeons.c offsets: 0=UW1Q1, 768=UW2Q1, 1536=UW1Q2, 2304=UW2Q2.
  Within a 768B block: A@0 B@128 C@256 D@384 E@512 F@640.
  Port routing (level_info_install_uw): Q1 -> L<=6:UW1Q1(0), L>6:UW2Q1(768);
                                        Q2 -> L<=6:UW1Q2(1536), L>6:UW2Q2(2304).
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DUNGEONS_C = REPO / "data" / "rooms" / "dungeons.c"
DAT = REPO / "reference" / "aldonunez" / "dat"
OUT = REPO / "tools" / "parity" / "out"

BLOCK = 768
LBA_C_OFF, LBA_D_OFF = 256, 384
PORT_BLOCK_OFF = {  # (quest, level<=6) -> dungeons.c byte offset
    (1, True): 0, (1, False): 768, (2, True): 1536, (2, False): 2304,
}
DAT_FOR = {(1, True): "LevelBlockUW1Q1.dat", (1, False): "LevelBlockUW2Q1.dat",
           (2, True): "LevelBlockUW1Q2.dat", (2, False): "LevelBlockUW2Q2.dat"}
# L5 Digdogger spawns as $39 (Digdogger2, morphs->$38 at runtime via
# InitDigdogger2); L6 Gohma as $34 (blue, $33=red variant). Include both
# so the LBA list_id match ($39/$34) AND a post-morph slot check ($38) hit.
BOSS_OT = {1: [0x3D], 2: [0x31], 3: [0x3C], 4: [0x43], 5: [0x39, 0x38],
           6: [0x34, 0x33], 7: [0x3D], 8: [0x45], 9: [0x47, 0x3E]}


def load_dungeons_blob():
    txt = DUNGEONS_C.read_text(encoding="utf-8")
    return bytes(int(b, 16) for b in re.findall(r"0x([0-9a-fA-F]{2})", txt))


def lba_from_block(blob, block_off):
    c = blob[block_off + LBA_C_OFF: block_off + LBA_C_OFF + 128]
    d = blob[block_off + LBA_D_OFF: block_off + LBA_D_OFF + 128]
    return c, d


def list_ids(c, d):
    return [((c[r] & 0x3F) | (0x40 if (d[r] & 0x80) else 0)) for r in range(128)]


def load_dat(name):
    p = DAT / name
    if not p.exists():
        return None
    return p.read_bytes()


def load_live(level, quest, rom_id):
    p = OUT / f"nes_boss_spawn_L{level}_Q{quest}_{rom_id}.json"
    if not p.exists():
        return None
    d = json.loads(p.read_text(encoding="utf-8"))
    if not d.get("warp_ok"):
        return None
    return d


def main(argv):
    rom_id = argv[1] if len(argv) > 1 else "orig"
    blob = load_dungeons_blob()
    print(f"# dungeons.c = {len(blob)} bytes; map={rom_id}")
    print(f"# {'lvl/q':6} {'boss_ot':22} {'dungeons.c==.dat':18} {'live matches block':22} {'verdict'}")

    overall = []
    # which DAT block does the live per-level LBA match? -> authoritative routing
    for quest in (1, 2):
        for level in range(1, 10):
            sub6 = level <= 6
            port_off = PORT_BLOCK_OFF[(quest, sub6)]
            port_c, port_d = lba_from_block(blob, port_off)
            # H1: dungeons.c block vs its .dat source
            dat = load_dat(DAT_FOR[(quest, sub6)])
            h1_ok = (dat is not None and
                     dat[port_off and 0 or 0:0]  # noop guard
                     is not None)
            dat_c = dat[LBA_C_OFF:LBA_C_OFF + 128] if dat else None
            dat_d = dat[LBA_D_OFF:LBA_D_OFF + 128] if dat else None
            extraction_ok = (dat_c == port_c and dat_d == port_d) if dat else None

            live = load_live(level, quest, rom_id)
            live_lid = None
            matched_block = None
            if live:
                lc = bytes(live["lba_c"]); ld = bytes(live["lba_d"])
                live_lid = list_ids(lc, ld)
                # which of the 4 .dat blocks matches the live LBA?
                for (q2, s6), name in DAT_FOR.items():
                    bd = load_dat(name)
                    if bd and bd[LBA_C_OFF:LBA_C_OFF + 128] == lc and bd[LBA_D_OFF:LBA_D_OFF + 128] == ld:
                        matched_block = name
                        break

            # does the boss objtype appear in the live per-level LBA?
            boss_present = None
            if live_lid is not None:
                boss_present = any(live_lid[r] in BOSS_OT[level] for r in range(128))

            verdict = "?"
            if extraction_ok is False:
                verdict = "H1 (dungeons.c != .dat -> regen extract_rooms)"
            elif live and matched_block and matched_block != DAT_FOR[(quest, sub6)]:
                verdict = f"H2 (NES uses {matched_block}, port installs {DAT_FOR[(quest,sub6)]})"
            elif live and boss_present is False:
                verdict = "H3 (boss objtype absent from live LBA -> special spawn)"
            elif live and boss_present:
                verdict = "OK (boss in live LBA; spawn should work with correct block)"
            elif not live:
                verdict = "(no live capture yet)"

            print(f"  L{level}Q{quest}  ${','.join('%02X'%o for o in BOSS_OT[level]):20} "
                  f"{str(extraction_ok):18} {str(matched_block):22} {verdict}")
            overall.append(verdict)

    print("\n# Authoritative level->block map (from live NES, orig Q1):")
    for level in range(1, 10):
        live = load_live(level, 1, rom_id)
        if not live:
            print(f"  L{level}: (no capture)")
            continue
        lc = bytes(live["lba_c"]); ld = bytes(live["lba_d"])
        mb = None
        for (q2, s6), name in DAT_FOR.items():
            bd = load_dat(name)
            if bd and bd[LBA_C_OFF:LBA_C_OFF + 128] == lc and bd[LBA_D_OFF:LBA_D_OFF + 128] == ld:
                mb = name; break
        port_blk = DAT_FOR[(1, level <= 6)]
        flag = "" if mb == port_blk else "  <-- ROUTING MISMATCH"
        # boss room(s) from live LBA
        lid = list_ids(lc, ld)
        rooms = {ot: [f"${r:02X}" for r in range(128) if lid[r] == ot] for ot in BOSS_OT[level]}
        print(f"  L{level}: live LBA == {mb} (port installs {port_blk}){flag}  boss rooms {rooms}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
