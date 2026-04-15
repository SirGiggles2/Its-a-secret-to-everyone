#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / "builds" / "reports"
GEN_JSON = REPORTS / "ow_visible_sweep_gen.json"
NES_JSON = REPORTS / "ow_visible_sweep_nes.json"
OUT_TXT = REPORTS / "ow_visible_sweep_report.txt"
OUT_JSON = REPORTS / "ow_visible_sweep_report.json"

ROWS = 22
COLS = 32


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def matrix(val):
    if not isinstance(val, list) or len(val) != ROWS:
        raise ValueError("bad matrix")
    out = []
    for row in val:
        if not isinstance(row, list) or len(row) != COLS:
            raise ValueError("bad row")
        out.append([int(x) & 0xFF for x in row])
    return out


def compare_rows(a, b):
    mismatches = []
    for r in range(ROWS):
        for c in range(COLS):
            if (a[r][c] & 0xFF) != (b[r][c] & 0xFF):
                mismatches.append({"row": r, "col": c, "a": a[r][c] & 0xFF, "b": b[r][c] & 0xFF})
    return mismatches


def route_guess(playmap_rows, nt_cache_rows, visible_rows):
    playmap_mm = compare_rows(playmap_rows, visible_rows)
    nt_mm = compare_rows(nt_cache_rows, visible_rows)
    if not nt_mm:
        return "NONE"
    if not playmap_mm:
        return "TRANSFER_PRODUCER_OR_INTERPRETER"
    if len(playmap_mm) > len(nt_mm):
        return "TRANSFER_PATH"
    if len(playmap_mm) == len(nt_mm):
        return "SOURCE_DECODE_OR_SHARED"
    return "UNKNOWN"


def main() -> int:
    gen = load(GEN_JSON)
    nes = load(NES_JSON)
    gen_rooms = {int(r["room_id"]) & 0xFF: r for r in gen.get("rooms", [])}
    nes_rooms = {int(r["room_id"]) & 0xFF: r for r in nes.get("rooms", [])}
    common = sorted(set(gen_rooms) & set(nes_rooms))

    verdicts = []
    pass_count = 0
    fail_count = 0
    for room_id in common:
        g = gen_rooms[room_id]
        n = nes_rooms[room_id]
        playmap_rows = matrix(g["playmap_rows"])
        nt_cache_rows = matrix(g["nt_cache_rows"])
        visible_rows = matrix(n["visible_rows"])
        mismatches = compare_rows(nt_cache_rows, visible_rows)
        if mismatches:
            fail_count += 1
        else:
            pass_count += 1
        verdicts.append(
            {
                "room_id": room_id,
                "tile_mismatches": len(mismatches),
                "palette_mismatches": 0,
                "route_guess": route_guess(playmap_rows, nt_cache_rows, visible_rows),
                "first_mismatch": mismatches[0] if mismatches else None,
            }
        )

    lines = []
    lines.append("OW VISIBLE SWEEP REPORT")
    lines.append("=" * 72)
    lines.append(f"gen_room_count: {len(gen.get('rooms', []))}")
    lines.append(f"nes_room_count: {len(nes.get('rooms', []))}")
    lines.append(f"common_room_count: {len(common)}")
    lines.append(f"pass_count: {pass_count}")
    lines.append(f"fail_count: {fail_count}")
    lines.append("")
    lines.append("Per-room verdicts:")
    for v in verdicts:
        line = f"  room ${v['room_id']:02X}: tiles={v['tile_mismatches']} pals={v['palette_mismatches']} route={v['route_guess']}"
        if v["first_mismatch"]:
            fm = v["first_mismatch"]
            line += f" first=row{fm['row']:02d} col{fm['col']:02d} gen=${fm['a']:02X} nes=${fm['b']:02X}"
        lines.append(line)

    OUT_TXT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    OUT_JSON.write_text(json.dumps({"verdicts": verdicts}, indent=2) + "\n", encoding="utf-8")
    print(OUT_TXT.read_text(encoding="utf-8"), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
