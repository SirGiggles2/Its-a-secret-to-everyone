#!/usr/bin/env python3
from __future__ import annotations

import csv
from pathlib import Path

from PIL import Image

ROOT = Path(r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY")
REPORT_DIR = ROOT / "builds" / "reports" / "intro_late_probe"
STATE_CSV = REPORT_DIR / "intro_late_probe_state.csv"
OUT_MD = REPORT_DIR / "intro_late_probe_summary.md"
OUT_CSV = REPORT_DIR / "intro_late_probe_summary.csv"

TITLE_X0 = 16
TITLE_X1 = 240
TITLE_TEMPLATE_Y0 = 32
TITLE_TEMPLATE_Y1 = 56
TITLE_SEARCH_MAX = 96


def load_rows() -> list[dict[str, str]]:
    with STATE_CSV.open(newline="") as fh:
        return list(csv.DictReader(fh))


def first_non_black_row(img: Image.Image) -> int:
    pix = img.load()
    w, h = img.size
    for y in range(h):
      for x in range(w):
        if pix[x, y] != 0:
          return y
    return -1


def last_non_black_row(img: Image.Image) -> int:
    pix = img.load()
    w, h = img.size
    for y in range(h - 1, -1, -1):
      for x in range(w):
        if pix[x, y] != 0:
          return y
    return -1


def mean_abs_delta(a: Image.Image, b: Image.Image) -> float:
    pa = a.tobytes()
    pb = b.tobytes()
    total = 0
    for i in range(len(pa)):
        total += abs(pa[i] - pb[i])
    return total / len(pa)


def find_title_row(img: Image.Image, title_template: Image.Image) -> tuple[int, float]:
    best_y = -1
    best_score = float("inf")
    tpl_h = title_template.size[1]
    for y in range(0, TITLE_SEARCH_MAX + 1):
        crop = img.crop((TITLE_X0, y, TITLE_X1, y + tpl_h))
        score = mean_abs_delta(crop, title_template)
        if score < best_score:
            best_score = score
            best_y = y
    return best_y, best_score


def to_int(row: dict[str, str], key: str) -> int:
    return int(row[key], 16)


def main() -> None:
    rows = load_rows()
    if not rows:
        raise SystemExit("late probe state CSV is empty")

    control_path = Path(rows[0]["screenshot"])
    control_img = Image.open(control_path).convert("L")
    title_template = control_img.crop((TITLE_X0, TITLE_TEMPLATE_Y0, TITLE_X1, TITLE_TEMPLATE_Y1))

    enriched: list[dict[str, object]] = []
    for row in rows:
        img = Image.open(Path(row["screenshot"])).convert("L")
        first_row = first_non_black_row(img)
        last_row = last_non_black_row(img)
        title_row, title_score = find_title_row(img, title_template)
        enriched.append({
            "frame": int(row["frame"]),
            "curVScroll": to_int(row, "curVScroll"),
            "demoLineTextIndex": to_int(row, "demoLineTextIndex"),
            "lineCounter": to_int(row, "lineCounter"),
            "vsram0": to_int(row, "vsram0"),
            "ppuScrlY": to_int(row, "ppuScrlY"),
            "hintQCount": to_int(row, "hintQCount"),
            "hintPendSplit": to_int(row, "hintPendSplit"),
            "vdpR00": to_int(row, "vdpR00"),
            "vdpR10": to_int(row, "vdpR10"),
            "vdpR11": to_int(row, "vdpR11"),
            "vdpR17": to_int(row, "vdpR17"),
            "vdpR18": to_int(row, "vdpR18"),
            "agsFlushHits": int(row["agsFlushHits"]),
            "agsPrearmHits": int(row["agsPrearmHits"]),
            "hblankHits": int(row["hblankHits"]),
            "agsFlushFirstRel": int(row["agsFlushFirstRel"]),
            "agsPrearmFirstRel": int(row["agsPrearmFirstRel"]),
            "hblankFirstRel": int(row["hblankFirstRel"]),
            "firstNonBlackRow": first_row,
            "lastNonBlackRow": last_row,
            "titleBandRow": title_row,
            "titleBandScore": title_score,
            "screenshot": row["screenshot"],
        })

    with OUT_CSV.open("w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow([
            "frame", "curVScroll", "demoLineTextIndex", "lineCounter", "vsram0",
            "ppuScrlY", "hintQCount", "hintPendSplit", "vdpR00", "vdpR10",
            "vdpR11", "vdpR17", "vdpR18", "agsFlushHits", "agsPrearmHits",
            "hblankHits", "agsFlushFirstRel", "agsPrearmFirstRel",
            "hblankFirstRel", "firstNonBlackRow", "lastNonBlackRow",
            "titleBandRow", "titleBandScore", "screenshot",
        ])
        for row in enriched:
            writer.writerow([
                row["frame"],
                f'{row["curVScroll"]:02X}',
                f'{row["demoLineTextIndex"]:02X}',
                f'{row["lineCounter"]:02X}',
                f'{row["vsram0"]:04X}',
                f'{row["ppuScrlY"]:02X}',
                f'{row["hintQCount"]:02X}',
                f'{row["hintPendSplit"]:02X}',
                f'{row["vdpR00"]:02X}',
                f'{row["vdpR10"]:02X}',
                f'{row["vdpR11"]:02X}',
                f'{row["vdpR17"]:02X}',
                f'{row["vdpR18"]:02X}',
                row["agsFlushHits"],
                row["agsPrearmHits"],
                row["hblankHits"],
                row["agsFlushFirstRel"],
                row["agsPrearmFirstRel"],
                row["hblankFirstRel"],
                row["firstNonBlackRow"],
                row["lastNonBlackRow"],
                row["titleBandRow"],
                f'{row["titleBandScore"]:.2f}',
                row["screenshot"],
            ])

    with OUT_MD.open("w", newline="") as fh:
        fh.write("# Intro Late Probe Summary\n\n")
        fh.write("| frame | CurV | demoLine | lineCtr | VSRAM0 | PPU_Y | HQ | HP | R00 | R10 | R11 | R17 | R18 | flush | prearm | hblank | firstRow | lastRow | titleRow |\n")
        fh.write("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n")
        for row in enriched:
            fh.write(
                f'| {row["frame"]} | {row["curVScroll"]:02X} | {row["demoLineTextIndex"]:02X} | '
                f'{row["lineCounter"]:02X} | {row["vsram0"]:04X} | {row["ppuScrlY"]:02X} | '
                f'{row["hintQCount"]:02X} | {row["hintPendSplit"]:02X} | {row["vdpR00"]:02X} | '
                f'{row["vdpR10"]:02X} | {row["vdpR11"]:02X} | {row["vdpR17"]:02X} | '
                f'{row["vdpR18"]:02X} | {row["agsFlushHits"]} | {row["agsPrearmHits"]} | '
                f'{row["hblankHits"]} | {row["firstNonBlackRow"]} | {row["lastNonBlackRow"]} | '
                f'{row["titleBandRow"]} |\n'
            )


if __name__ == "__main__":
    main()
