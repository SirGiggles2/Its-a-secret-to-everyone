#!/usr/bin/env python3
"""Compare NES enemy dumps vs Genesis enemy dumps per type.
Reads state.json from both, diffs slot 1 cells + OAM + palette.
Emits markdown report."""
import json
from pathlib import Path

NES_ROOT = Path("C:/tmp/nes_v4")
GEN_ROOT = Path("C:/tmp/enemy_dumps")
OUT_MD   = Path("C:/tmp/enemy_parity_diff.md")

# Slot-1 cells to compare (NES + Gen both capture)
SLOT_CELLS = ["t","x","y","dir","qspd","st","ms","tm","hp","inv","attr"]

def find_dirs():
    """Find type dirs present in both NES and Gen dumps."""
    nes_types = {}
    for d in sorted(NES_ROOT.iterdir()):
        if d.is_dir() and "_" in d.name and not d.name.startswith(("00","ZZ","boot")):
            key = d.name.split("_")[0]
            nes_types[key] = d
    gen_types = {}
    for d in sorted(GEN_ROOT.iterdir()):
        if d.is_dir() and "_" in d.name and not d.name.startswith(("00","ZZ")):
            key = d.name.split("_")[0]
            gen_types[key] = d
    common = sorted(set(nes_types) & set(gen_types))
    return [(k, nes_types[k], gen_types[k]) for k in common]

def load_json(p):
    try:
        return json.loads(p.read_text())
    except Exception as e:
        return None

def gen_slot1(g):
    """Genesis state.json has slot1 in 'slots' array."""
    if not g: return None
    for s in g.get("slots", []):
        if s.get("slot") == 1:
            return s
    return None

def nes_slot1(n):
    """NES state.json (newer compact format)."""
    if not n: return None
    for s in n.get("slots", []):
        if s.get("s") == 1:
            return s
    return None

def diff_cells(nes_s, gen_s):
    """Return per-cell diff. List of (cell, nes, gen, match)."""
    if not nes_s or not gen_s:
        return [(c, None, None, False) for c in SLOT_CELLS]
    out = []
    # Genesis uses different key names: type/state/metastate/obj_timer/hit_react/shove_dir/shove_dist/inv_mask
    gen_map = {
        "t": "type", "x": "x", "y": "y", "dir": "dir",
        "qspd": "qspd", "st": "state", "ms": "metastate", "tm": "obj_timer",
        "hp": "hp", "inv": "inv_mask", "attr": "attr"
    }
    for c in SLOT_CELLS:
        nes_v = nes_s.get(c)
        gen_k = gen_map.get(c, c)
        gen_v = gen_s.get(gen_k)
        match = (nes_v is not None and nes_v == gen_v)
        out.append((c, nes_v, gen_v, match))
    return out

def palram_short(hex_str):
    """First 32 hex bytes."""
    return hex_str[:64] if hex_str else "(none)"

# === Main ===
results = []
for key, nes_dir, gen_dir in find_dirs():
    nes_json = load_json(nes_dir / "state.json")
    gen_json = load_json(gen_dir / "state.json")
    nes_s = nes_slot1(nes_json)
    gen_s = gen_slot1(gen_json)
    cells = diff_cells(nes_s, gen_s)
    label = nes_dir.name
    match_count = sum(1 for c in cells if c[3])
    total = len(cells)
    results.append({
        "key": key,
        "label": label,
        "match_count": match_count,
        "total": total,
        "cells": cells,
        "nes_palram": (nes_json or {}).get("palram_hex"),
        "gen_cram": (gen_json or {}).get("cram_hex"),
        "nes_oam": (nes_json or {}).get("oam_hex"),
        "gen_oam": (gen_json or {}).get("oam_mirror_hex"),
    })

# === Report ===
with OUT_MD.open("w", encoding="utf-8") as f:
    f.write("# NES vs Genesis Enemy Parity Diff\n\n")
    f.write(f"Types compared: {len(results)}\n\n")
    f.write("## Per-cell summary\n\n")
    f.write("| Type | Name | Cell matches | Score |\n|---|---|---|---|\n")
    for r in results:
        f.write(f"| ${r['key']} | {r['label']} | {r['match_count']}/{r['total']} | {'GREEN' if r['match_count']==r['total'] else 'PARTIAL'} |\n")
    f.write("\n## Per-cell detail\n\n")
    for r in results:
        f.write(f"### {r['label']} ({r['match_count']}/{r['total']})\n\n")
        f.write("| Cell | NES | Gen | Match |\n|---|---|---|---|\n")
        for c, nv, gv, m in r["cells"]:
            mark = "✓" if m else "✗"
            f.write(f"| {c} | {nv} | {gv} | {mark} |\n")
        f.write("\n")
        # OAM byte-diff: count differing bytes
        if r["nes_oam"] and r["gen_oam"]:
            n_oam = bytes.fromhex(r["nes_oam"])
            g_oam = bytes.fromhex(r["gen_oam"])
            diff_bytes = sum(1 for i in range(min(len(n_oam), len(g_oam))) if n_oam[i] != g_oam[i])
            f.write(f"- OAM diff: {diff_bytes}/{min(len(n_oam), len(g_oam))} bytes differ\n")
        f.write(f"- NES palram: `{palram_short(r['nes_palram'])}`\n")
        f.write(f"- Gen cram:   `{palram_short(r['gen_cram'])}`\n\n")

# Top-line summary
print(f"Diffed {len(results)} types. Report: {OUT_MD}")
total_cells = sum(r["total"] for r in results)
match_cells = sum(r["match_count"] for r in results)
print(f"Total cells: {match_cells}/{total_cells} match ({100*match_cells//max(total_cells,1)}%)")
print()
print("Per-type:")
for r in results:
    print(f"  ${r['key']} {r['label']:25s} {r['match_count']:2d}/{r['total']}")
