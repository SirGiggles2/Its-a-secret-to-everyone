#!/usr/bin/env python3
"""Compare NES + Gen enemy behavior results, emit GREEN/RED matrix."""
import json
from pathlib import Path

GEN = Path("C:/tmp/enemy_behavior_gen.json")
NES = Path("C:/tmp/enemy_behavior_nes.json")
OUT = Path("C:/tmp/enemy_behavior_matrix.md")

DIMS = ['spawn','move','shoot','damage','knockback','death','drop','anim']

def load(p):
    try:
        return {e['type']: e for e in json.loads(p.read_text())}
    except Exception:
        return {}

gen = load(GEN)
nes = load(NES)
keys = sorted(set(gen) | set(nes))

with OUT.open('w', encoding='utf-8') as f:
    f.write("# NES vs Gen enemy behavior matrix\n\n")
    f.write(f"Gen: {len(gen)} enemies. NES: {len(nes)} enemies.\n\n")
    f.write("## Matrix (per enemy × dimension)\n\n")
    hdr = "| Type | Name | " + " | ".join(f"{d}\nNES/Gen" for d in DIMS) + " | Score |\n"
    f.write(hdr)
    f.write("|" + "|".join(["---"] * (len(DIMS) + 3)) + "|\n")
    gen_pass_total = 0
    gen_total = 0
    parity_match = 0
    parity_total = 0
    for k in keys:
        g = gen.get(k, {})
        n = nes.get(k, {})
        name = g.get('name', n.get('name', '?'))
        cells = []
        gscore = 0
        for d in DIMS:
            gv = g.get(d)
            nv = n.get(d)
            gen_total += 1
            if gv: gen_pass_total += 1
            if gv: gscore += 1
            if gv is not None and nv is not None:
                parity_total += 1
                if gv == nv: parity_match += 1
            gm = 'Y' if gv else ('-' if gv is None else 'n')
            nm = 'Y' if nv else ('-' if nv is None else 'n')
            cells.append(f"{nm}/{gm}")
        f.write(f"| {k} | {name} | " + " | ".join(cells) + f" | {gscore}/8 |\n")
    f.write(f"\n**Gen PASS: {gen_pass_total}/{gen_total} = {100*gen_pass_total//max(gen_total,1)}%**\n\n")
    if parity_total:
        f.write(f"**NES↔Gen parity (both tested): {parity_match}/{parity_total} = {100*parity_match//parity_total}%**\n")

print(f"Report: {OUT}")
print(f"Gen PASS: {gen_pass_total}/{gen_total} = {100*gen_pass_total//max(gen_total,1)}%")
if parity_total:
    print(f"Parity: {parity_match}/{parity_total} = {100*parity_match//parity_total}%")
