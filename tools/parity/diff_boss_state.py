#!/usr/bin/env python3
"""Diff per-boss spawned state (ObjType + HP) NES golden vs Genesis live.

NES golden: tools/parity/out/nes_boss_spawn_L<lv>_Q1_orig.json (probe_nes_boss_spawn).
Genesis:    gen_boss_direct/<name>/state.txt (probe_gen_boss_direct).

ObjType + HP are the boss's init-state invariants (must byte-match). X/Y/timers
are RNG/frame-driven (the boss moves) so they're reported but not gated.
"""
import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "tools" / "parity" / "out"
GEN = REPO / "gen_boss_direct"

# level -> (genesis dir name, expected boss objtype)
M = [(1, "aquamentus", 0x3D), (2, "dodongo", 0x31), (3, "manhandla", 0x3C),
     (4, "gleeok_2head", 0x43), (5, "digdogger", 0x38), (6, "gohma", 0x34),
     (7, "aquamentus_2", 0x3D), (8, "gleeok_4head", 0x45),
     (9, "patra_red", 0x47), (9, "ganon", 0x3E)]


def nes_boss_slot1(level, ot):
    """Find the spawned-boss capture whose slot-1 ObjType == ot (a level can
    hold multiple bosses, e.g. L9 Patra $47 + Ganon $3E)."""
    p = OUT / f"nes_boss_spawn_L{level}_Q1_orig.json"
    if not p.exists():
        return None
    d = json.loads(p.read_text())
    fallback = None
    for cap in d.get("captures", []):
        if not cap.get("spawned_boss"):
            continue
        s1 = next((s for s in cap.get("slots", []) if s.get("slot") == 1), None)
        if not s1:
            continue
        rec = (s1.get("t"), s1.get("hp"), s1.get("x"), s1.get("y"))
        if s1.get("t") == ot:
            return rec
        if fallback is None:
            fallback = rec
    return fallback


def gen_boss_slot1(name):
    p = GEN / name / "state.txt"
    if not p.exists():
        return None
    m = re.search(r"s01 t=\$([0-9A-Fa-f]{2}).*?x=\$([0-9A-Fa-f]{2}) "
                  r"y=\$([0-9A-Fa-f]{2}).*?hp=\$([0-9A-Fa-f]{2})", p.read_text())
    if not m:
        return None
    return (int(m.group(1), 16), int(m.group(4), 16),
            int(m.group(2), 16), int(m.group(3), 16))


print(f"{'lvl boss':22} {'NES t/hp/x/y':18} {'GEN t/hp/x/y':18} verdict")
for lv, name, ot in M:
    n = nes_boss_slot1(lv, ot)
    g = gen_boss_slot1(name)
    if not n or not g:
        print(f"L{lv} {name:18} {'(no NES)' if not n else '(no GEN)'}")
        continue
    nt, nh, nx, ny = n
    gt, gh, gx, gy = g
    type_ok = (nt == gt)
    hp_ok = (nh == gh)
    v = "MATCH (type+HP)" if (type_ok and hp_ok) else \
        ("TYPE-OK, HP differ" if type_ok else "MISMATCH")
    print(f"L{lv} {name:18} ${nt:02X}/${nh:02X}/${nx:02X}/${ny:02X}      "
          f"${gt:02X}/${gh:02X}/${gx:02X}/${gy:02X}      {v}")
