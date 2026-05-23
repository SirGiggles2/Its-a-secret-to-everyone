#!/usr/bin/env python3
"""Filter dual-dump diff to ONLY real-bug cells (excluding timing
noise + Gen-only/NES-only sections).

Reads C:/tmp/dual/{nes,gen}/lv*_rm*/static.txt
Reads tools/parity/expected_divergence.json
Emits C:/tmp/dual/diff/REAL_BUGS.md — per-room actionable diffs only.
"""
import json
import re
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[2]
NES_DIR  = Path("C:/tmp/dual/nes")
GEN_DIR  = Path("C:/tmp/dual/gen")
DIFF_DIR = Path("C:/tmp/dual/diff")
EXPECTED = ROOT / "tools/parity/expected_divergence.json"

REAL_BUG_SECTIONS = {"PALRAM", "OAM", "SLOTS", "LINK", "SCENE"}

def load_expected():
    with open(EXPECTED) as f:
        return json.load(f)

def parse_dump(path):
    out = {}
    cur = None
    if not path.exists():
        return out
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            cur = m.group(1)
            out.setdefault(cur, {})
            continue
        if cur is None:
            continue
        m = re.match(r"^([^=]+)=(.*)$", line)
        if m:
            out[cur][m.group(1).strip()] = m.group(2).strip()
    return out


def parse_slot_cells(value):
    """Parse 't:$XX x:$XX ...' into {cell: value} dict."""
    cells = {}
    for tok in value.split():
        m = re.match(r"^([a-zA-Z]+):(.+)$", tok)
        if m:
            cells[m.group(1)] = m.group(2)
    return cells


def section_real_diffs(section, nes_kv, gen_kv, expected):
    """Return list of (key, nes_v, gen_v, why) for cells that are
    real bugs (not in expected divergence list)."""
    real = []
    section_expected = expected["expected"].get(section, {})
    all_keys = sorted(set(nes_kv.keys()) | set(gen_kv.keys()))
    for k in all_keys:
        nv = nes_kv.get(k, "<MISSING>")
        gv = gen_kv.get(k, "<MISSING>")
        if nv == gv:
            continue
        if section == "SLOTS":
            # Per-cell filter within slot blob
            nes_cells = parse_slot_cells(nv)
            gen_cells = parse_slot_cells(gv)
            slot_real = []
            real_cell_names = set(expected["real_bugs_focus"]["SLOTS_real_cells"])
            for cell, nc in nes_cells.items():
                gc = gen_cells.get(cell)
                if gc is None or gc == nc:
                    continue
                if cell not in real_cell_names:
                    continue
                slot_real.append(f"{cell}:{nc}→{gc}")
            if slot_real:
                real.append((k, " ".join(slot_real), "", "slot-cells"))
            continue
        # Other sections: check if key listed as expected
        if isinstance(section_expected, dict) and k in section_expected:
            continue
        why = "real-diff"
        real.append((k, nv, gv, why))
    return real


def list_rooms():
    rooms = set()
    for d in NES_DIR.iterdir():
        m = re.match(r"^lv([0-9A-Fa-f]{2})_rm([0-9A-Fa-f]{2})$", d.name)
        if not m: continue
        if (GEN_DIR / d.name).exists():
            rooms.add((m.group(1).upper(), m.group(2).upper()))
    return sorted(rooms)


def main():
    expected = load_expected()
    rooms = list_rooms()
    DIFF_DIR.mkdir(parents=True, exist_ok=True)

    summary = defaultdict(int)
    out_lines = ["# Real-bug-only divergence (timing noise filtered)\n"]
    out_lines.append(f"_Common rooms: {len(rooms)}_\n")
    out_lines.append(f"_Sections checked: {', '.join(sorted(REAL_BUG_SECTIONS))}_\n")
    out_lines.append("| Level | Room | Real diffs |")
    out_lines.append("|---|---|---:|")

    per_room_diffs = {}
    for lv, rm in rooms:
        nes = parse_dump(NES_DIR / f"lv{lv}_rm{rm}" / "static.txt")
        gen = parse_dump(GEN_DIR / f"lv{lv}_rm{rm}" / "static.txt")
        room_diffs = {}
        total = 0
        for sec in REAL_BUG_SECTIONS:
            d = section_real_diffs(sec, nes.get(sec, {}), gen.get(sec, {}), expected)
            if d:
                room_diffs[sec] = d
                total += len(d)
                summary[f"{sec}_real_diffs"] += len(d)
        per_room_diffs[(lv, rm)] = (total, room_diffs)
        out_lines.append(f"| ${lv} | ${rm} | {total} |")

    # Top 10 worst rooms detail
    worst = sorted(per_room_diffs.items(), key=lambda x: -x[1][0])[:10]
    out_lines.append("\n## Top 10 worst rooms — real bugs only\n")
    for (lv, rm), (total, room_diffs) in worst:
        out_lines.append(f"\n### lv${lv} rm${rm} — {total} real diffs\n")
        for sec, items in room_diffs.items():
            out_lines.append(f"\n**[{sec}]**\n")
            for k, nv, gv, _ in items[:20]:
                out_lines.append(f"- `{k}`: NES `{nv}`  Gen `{gv}`")
            if len(items) > 20:
                out_lines.append(f"- ... +{len(items)-20} more")

    out_lines.append("\n## Section totals\n")
    for k, v in sorted(summary.items()):
        out_lines.append(f"- {k}: {v}")

    out_path = DIFF_DIR / "REAL_BUGS.md"
    out_path.write_text("\n".join(out_lines), encoding="utf-8")
    print(f"Real-bug diff: {out_path}")
    print(f"Total real diffs: {sum(summary.values())}")


if __name__ == "__main__":
    main()
