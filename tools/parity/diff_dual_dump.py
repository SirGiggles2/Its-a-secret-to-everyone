#!/usr/bin/env python3
"""Plan v5 Phase D3 — diff matched per-room dumps from
C:/tmp/dual/{nes,gen}/lv*_rm*/static.txt.

For each room present on both sides:
  - Parse [SECTION] key=value blocks
  - Per-line diff
  - Emit markdown report listing divergent keys

For rooms present on only one side: list as missing.

Output:
  C:/tmp/dual/diff/lv<LV>_rm<RM>.md   — per-room divergence list
  C:/tmp/dual/diff/MATRIX.md          — full grid by (level, room) × section
  C:/tmp/dual/diff/SUMMARY.md         — top-line counts + worst rooms
"""
import os
import re
from pathlib import Path
from collections import defaultdict

NES_DIR  = Path("C:/tmp/dual/nes")
GEN_DIR  = Path("C:/tmp/dual/gen")
DIFF_DIR = Path("C:/tmp/dual/diff")


def parse_dump(path):
    """Parse [SECTION] key=value file into {section: {key: value}}."""
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


def list_rooms(base):
    """Return set of (lvHEX, rmHEX) tuples present under base/lvXX_rmYY/."""
    rooms = set()
    if not base.exists():
        return rooms
    for d in base.iterdir():
        if not d.is_dir():
            continue
        m = re.match(r"^lv([0-9A-Fa-f]{2})_rm([0-9A-Fa-f]{2})$", d.name)
        if m:
            rooms.add((m.group(1).upper(), m.group(2).upper()))
    return rooms


def diff_room(lv, rm):
    nes_path = NES_DIR / f"lv{lv}_rm{rm}" / "static.txt"
    gen_path = GEN_DIR / f"lv{lv}_rm{rm}" / "static.txt"
    nes = parse_dump(nes_path)
    gen = parse_dump(gen_path)
    sections = sorted(set(nes.keys()) | set(gen.keys()))
    diffs = []
    section_summary = {}  # section -> (total, equal, diff)
    for sec in sections:
        nes_keys = nes.get(sec, {})
        gen_keys = gen.get(sec, {})
        all_keys = sorted(set(nes_keys.keys()) | set(gen_keys.keys()))
        total = len(all_keys)
        equal = 0
        sec_diffs = []
        for k in all_keys:
            nv = nes_keys.get(k, "<MISSING>")
            gv = gen_keys.get(k, "<MISSING>")
            if nv == gv:
                equal += 1
            else:
                sec_diffs.append((k, nv, gv))
        section_summary[sec] = (total, equal, len(sec_diffs))
        if sec_diffs:
            diffs.append((sec, sec_diffs))
    return diffs, section_summary


def render_room_md(lv, rm, diffs, section_summary):
    out = [f"# lv${lv} rm${rm} divergence\n"]
    out.append("## Section summary\n")
    out.append("| Section | total | equal | divergent |")
    out.append("|---|---:|---:|---:|")
    for sec, (t, e, d) in section_summary.items():
        flag = " RED" if d > 0 else " GREEN"
        out.append(f"| {sec} | {t} | {e} | {d}{flag} |")
    out.append("")
    if not diffs:
        out.append("## All sections match\n")
        return "\n".join(out)
    out.append("## Divergent cells\n")
    for sec, items in diffs:
        out.append(f"### [{sec}]\n")
        out.append("| key | NES | Gen |")
        out.append("|---|---|---|")
        for k, nv, gv in items[:200]:  # cap per section
            out.append(f"| `{k}` | `{nv}` | `{gv}` |")
        if len(items) > 200:
            out.append(f"\n... {len(items) - 200} more cells truncated\n")
        out.append("")
    return "\n".join(out)


def main():
    DIFF_DIR.mkdir(parents=True, exist_ok=True)
    nes_rooms = list_rooms(NES_DIR)
    gen_rooms = list_rooms(GEN_DIR)
    common = nes_rooms & gen_rooms
    nes_only = nes_rooms - gen_rooms
    gen_only = gen_rooms - nes_rooms

    matrix_rows = []
    summary_counts = defaultdict(int)
    worst_rooms = []  # (divergence_count, lv, rm)

    for lv, rm in sorted(common):
        diffs, section_summary = diff_room(lv, rm)
        room_md = render_room_md(lv, rm, diffs, section_summary)
        (DIFF_DIR / f"lv{lv}_rm{rm}.md").write_text(room_md, encoding="utf-8")
        total_div = sum(d for (_, _, d) in section_summary.values())
        worst_rooms.append((total_div, lv, rm))
        for sec, (_, _, d) in section_summary.items():
            summary_counts[f"section.{sec}.divergent"] += d
        if total_div == 0:
            summary_counts["rooms_all_green"] += 1
        else:
            summary_counts["rooms_with_divergence"] += 1
        sec_flags = []
        for sec, (_, _, d) in section_summary.items():
            sec_flags.append(f"{sec}:{'R' if d>0 else 'G'}")
        matrix_rows.append((lv, rm, total_div, " ".join(sec_flags)))

    # MATRIX
    mat = ["# Per-room divergence matrix\n",
           "| Level | Room | Total divs | Sections (R=red G=green) |",
           "|---|---|---:|---|"]
    for lv, rm, td, flags in matrix_rows:
        mat.append(f"| ${lv} | ${rm} | {td} | {flags} |")
    if nes_only:
        mat.append("\n## NES-only rooms (missing on Gen)\n")
        for lv, rm in sorted(nes_only):
            mat.append(f"- ${lv} / ${rm}")
    if gen_only:
        mat.append("\n## Gen-only rooms (missing on NES)\n")
        for lv, rm in sorted(gen_only):
            mat.append(f"- ${lv} / ${rm}")
    (DIFF_DIR / "MATRIX.md").write_text("\n".join(mat), encoding="utf-8")

    # SUMMARY
    worst_rooms.sort(reverse=True)
    summ = ["# Diff summary\n",
            f"- NES rooms: {len(nes_rooms)}",
            f"- Gen rooms: {len(gen_rooms)}",
            f"- Common:    {len(common)}",
            f"- NES-only:  {len(nes_only)}",
            f"- Gen-only:  {len(gen_only)}",
            ""]
    for k, v in sorted(summary_counts.items()):
        summ.append(f"- {k}: {v}")
    summ.append("\n## Top 10 most-divergent rooms\n")
    for td, lv, rm in worst_rooms[:10]:
        summ.append(f"- ${lv}/${rm} → {td} divergent cells")
    (DIFF_DIR / "SUMMARY.md").write_text("\n".join(summ), encoding="utf-8")

    print(f"Diff complete: {len(common)} rooms compared")
    print(f"Output: {DIFF_DIR}")


if __name__ == "__main__":
    main()
