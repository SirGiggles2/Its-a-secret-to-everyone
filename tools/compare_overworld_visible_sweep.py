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


def palette_matrix(val):
    """Palette-row matrix: values are 0..3 palette indices, 22x32."""
    if not isinstance(val, list) or len(val) != ROWS:
        raise ValueError("bad palette matrix")
    out = []
    for row in val:
        if not isinstance(row, list) or len(row) != COLS:
            raise ValueError("bad palette row")
        out.append([int(x) & 3 for x in row])
    return out


def compare_palette_rows(a, b):
    mismatches = []
    for r in range(ROWS):
        for c in range(COLS):
            if (a[r][c] & 3) != (b[r][c] & 3):
                mismatches.append({"row": r, "col": c, "gen_pal": a[r][c] & 3, "nes_pal": b[r][c] & 3})
    return mismatches


# Genesis CRAM word format: 0BGR (bits 0..2 R, 4..6 G, 8..10 B), 3-bit per channel.
# NES PPU palette index → RGB via the standard NES master palette. We only need
# to validate that the 16 BG CRAM words match the 16 BG PPU palette slots after
# running both through a common 8-bit RGB representation.
NES_RGB = [
    (0x62,0x62,0x62),(0x00,0x1F,0xB2),(0x24,0x04,0xC8),(0x52,0x00,0xB2),
    (0x73,0x00,0x76),(0x80,0x00,0x24),(0x73,0x0B,0x00),(0x52,0x28,0x00),
    (0x24,0x44,0x00),(0x00,0x57,0x00),(0x00,0x5C,0x00),(0x00,0x53,0x24),
    (0x00,0x3C,0x76),(0x00,0x00,0x00),(0x00,0x00,0x00),(0x00,0x00,0x00),
    (0xAB,0xAB,0xAB),(0x0D,0x57,0xFF),(0x4B,0x30,0xFF),(0x8A,0x13,0xFF),
    (0xBC,0x08,0xD6),(0xD2,0x12,0x69),(0xC7,0x2E,0x00),(0x9D,0x54,0x00),
    (0x60,0x7B,0x00),(0x20,0x98,0x00),(0x00,0xA3,0x00),(0x00,0x99,0x42),
    (0x00,0x7D,0xB4),(0x00,0x00,0x00),(0x00,0x00,0x00),(0x00,0x00,0x00),
    (0xFF,0xFF,0xFF),(0x53,0xAE,0xFF),(0x90,0x85,0xFF),(0xD3,0x65,0xFF),
    (0xFF,0x57,0xFF),(0xFF,0x5D,0xCF),(0xFF,0x77,0x57),(0xFA,0x9E,0x00),
    (0xBD,0xC7,0x00),(0x7A,0xE7,0x00),(0x43,0xF6,0x11),(0x26,0xEF,0x7E),
    (0x2C,0xD5,0xF6),(0x4E,0x4E,0x4E),(0x00,0x00,0x00),(0x00,0x00,0x00),
    (0xFF,0xFF,0xFF),(0xB6,0xE1,0xFF),(0xCE,0xD1,0xFF),(0xE9,0xC3,0xFF),
    (0xFF,0xBC,0xFF),(0xFF,0xBD,0xF4),(0xFF,0xC6,0xC3),(0xFF,0xD5,0x9A),
    (0xE9,0xE6,0x81),(0xCE,0xF4,0x81),(0xB6,0xFB,0x9A),(0xA9,0xFA,0xC3),
    (0xA9,0xF0,0xF4),(0xB8,0xB8,0xB8),(0x00,0x00,0x00),(0x00,0x00,0x00),
]


def nes_color_to_rgb(idx):
    return NES_RGB[idx & 0x3F]


def cram_word_to_rgb(word):
    # Genesis CRAM word 0BBB0GGG0RRR → expand each 3-bit channel to 8-bit.
    r3 = (word >> 1) & 0x7
    g3 = (word >> 5) & 0x7
    b3 = (word >> 9) & 0x7
    def expand(c3):
        # Official Genesis 3→8 ladder (VDP outputs 9 distinct levels).
        return (c3 * 0x24) & 0xFF
    return (expand(r3), expand(g3), expand(b3))


def color_distance(a, b):
    return max(abs(a[0]-b[0]), abs(a[1]-b[1]), abs(a[2]-b[2]))


def compare_palette_ram(gen_cram_bg, nes_palette_ram):
    """Compare 16 BG CRAM words vs 16 PPU palette bytes through RGB.

    Returns list of mismatches {"slot": i, "gen_rgb": (r,g,b), "nes_rgb": (r,g,b), "delta": int}.
    A non-zero delta on slot 0 is expected (universal bg — sometimes tracked separately);
    delta > 48 (one full 3-bit Gen step) on any other slot is considered a mismatch.
    """
    mismatches = []
    for i in range(16):
        if i >= len(gen_cram_bg) or i >= len(nes_palette_ram):
            continue
        g_word = int(gen_cram_bg[i])
        n_idx = int(nes_palette_ram[i])
        g_rgb = cram_word_to_rgb(g_word)
        n_rgb = nes_color_to_rgb(n_idx)
        d = color_distance(g_rgb, n_rgb)
        if d > 48:
            mismatches.append({"slot": i, "gen_rgb": g_rgb, "nes_rgb": n_rgb, "delta": d})
    return mismatches


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

        # Palette parity: per-tile palette-line bits (0..3) plus 16-word
        # CRAM → NES-PPU-palette-RAM RGB comparison. Either of these may be
        # missing on old captures; treat as zero in that case.
        pal_mm = []
        if "palette_rows" in g and "palette_rows" in n:
            try:
                g_pal = palette_matrix(g["palette_rows"])
                n_pal = palette_matrix(n["palette_rows"])
                pal_mm = compare_palette_rows(g_pal, n_pal)
            except ValueError:
                pal_mm = []
        cram_mm = []
        if "cram_bg" in g and "palette_ram" in n:
            try:
                cram_mm = compare_palette_ram(g["cram_bg"], n["palette_ram"])
            except Exception:
                cram_mm = []

        failed = bool(mismatches) or bool(pal_mm) or bool(cram_mm)
        if failed:
            fail_count += 1
        else:
            pass_count += 1
        verdicts.append(
            {
                "room_id": room_id,
                "tile_mismatches": len(mismatches),
                "palette_mismatches": len(pal_mm),
                "cram_mismatches": len(cram_mm),
                "route_guess": route_guess(playmap_rows, nt_cache_rows, visible_rows),
                "first_mismatch": mismatches[0] if mismatches else None,
                "first_palette_mismatch": pal_mm[0] if pal_mm else None,
                "first_cram_mismatch": cram_mm[0] if cram_mm else None,
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
        cram = v.get("cram_mismatches", 0)
        line = (
            f"  room ${v['room_id']:02X}: tiles={v['tile_mismatches']} "
            f"pals={v['palette_mismatches']} cram={cram} route={v['route_guess']}"
        )
        if v["first_mismatch"]:
            fm = v["first_mismatch"]
            line += f" tile@row{fm['row']:02d}c{fm['col']:02d}:gen=${fm['a']:02X}/nes=${fm['b']:02X}"
        if v.get("first_palette_mismatch"):
            pm = v["first_palette_mismatch"]
            line += f" pal@row{pm['row']:02d}c{pm['col']:02d}:gen={pm['gen_pal']}/nes={pm['nes_pal']}"
        if v.get("first_cram_mismatch"):
            cm = v["first_cram_mismatch"]
            line += (
                f" cram[{cm['slot']}]:gen_rgb={cm['gen_rgb']}/"
                f"nes_rgb={cm['nes_rgb']}(Δ{cm['delta']})"
            )
        lines.append(line)

    OUT_TXT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    OUT_JSON.write_text(json.dumps({"verdicts": verdicts}, indent=2) + "\n", encoding="utf-8")
    print(OUT_TXT.read_text(encoding="utf-8"), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
