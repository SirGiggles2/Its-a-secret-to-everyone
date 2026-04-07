#!/usr/bin/env python3
from __future__ import annotations

import csv
from pathlib import Path

from PIL import Image

ROOT = Path(r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY")
REPORT_DIR = ROOT / "builds" / "reports" / "intro_window"
DIFF_PATH = ROOT / "builds" / "reports" / "intro_diff.txt"
NES_TRACE = ROOT / "builds" / "reports" / "intro_nes" / "nes_trace.txt"
GEN_TRACE = ROOT / "builds" / "reports" / "intro_gen" / "gen_trace.txt"
PROBE_CSV = REPORT_DIR / "intro_window_probe.csv"
OUT_CSV = REPORT_DIR / "intro_scroll_window.csv"
OUT_MD = REPORT_DIR / "intro_scroll_window.md"

TITLE_X0 = 16
TITLE_X1 = 240
TITLE_TEMPLATE_Y0 = 32
TITLE_TEMPLATE_Y1 = 56
TITLE_SEARCH_MAX = 96
MASK_OK = 0.03


def load_trace(path: Path) -> dict[int, dict[str, int]]:
    rows: dict[int, dict[str, int]] = {}
    cols: list[str] | None = None
    with path.open() as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            if line.startswith("# frame,"):
                cols = [part.strip() for part in line[2:].split(",")]
                continue
            if line.startswith("#"):
                continue
            parts = line.split(",")
            if not cols or len(parts) < len(cols):
                continue
            rec: dict[str, int] = {"frame": int(parts[0])}
            for i, col in enumerate(cols[1:], start=1):
                rec[col] = int(parts[i], 16)
            rows[rec["frame"]] = rec
    return rows


def load_probe(path: Path) -> dict[int, dict[str, int]]:
    out: dict[int, dict[str, int]] = {}
    with path.open(newline="") as fh:
        for row in csv.DictReader(fh):
            frame = int(row["frame"])
            out[frame] = {
                key: int(value, 16)
                for key, value in row.items()
                if key != "frame"
            }
    return out


def load_diff(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as fh:
        first = fh.readline()
        if not first.startswith("#"):
            fh.seek(0)
        return list(csv.DictReader(fh))


def mean_abs_delta(a: Image.Image, b: Image.Image) -> float:
    pa = a.tobytes()
    pb = b.tobytes()
    total = 0
    for i in range(len(pa)):
        total += abs(pa[i] - pb[i])
    return total / len(pa)


def first_non_black_row(img: Image.Image) -> int:
    pix = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if pix[x, y] != 0:
                return y
    return -1


def find_title_row(img: Image.Image, title_template: Image.Image) -> tuple[int, float]:
    tpl_h = title_template.size[1]
    best_y = -1
    best_score = float("inf")
    for y in range(0, TITLE_SEARCH_MAX + 1):
        crop = img.crop((TITLE_X0, y, TITLE_X1, y + tpl_h))
        score = mean_abs_delta(crop, title_template)
        if score < best_score:
            best_score = score
            best_y = y
    return best_y, best_score


def image_metrics(cache: dict[Path, tuple[int, int, float]], path: Path, template: Image.Image) -> tuple[int, int, float]:
    cached = cache.get(path)
    if cached is not None:
        return cached
    img = Image.open(path).convert("L")
    first = first_non_black_row(img)
    title_y, score = find_title_row(img, template)
    cache[path] = (first, title_y, score)
    return cache[path]


def frame_state(rec: dict[str, int]) -> tuple[int, int, int]:
    return rec.get("gameMode", 0xFF), rec.get("phase", 0xFF), rec.get("subphase", 0xFF)


def main() -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    nes_trace = load_trace(NES_TRACE)
    gen_trace = load_trace(GEN_TRACE)
    gen_probe = load_probe(PROBE_CSV)
    diff_rows = load_diff(DIFF_PATH)

    template_img = Image.open(ROOT / "builds" / "reports" / "intro_nes" / "nes_f01508.png").convert("L")
    title_template = template_img.crop((TITLE_X0, TITLE_TEMPLATE_Y0, TITLE_X1, TITLE_TEMPLATE_Y1))
    img_cache: dict[Path, tuple[int, int, float]] = {}

    rows: list[dict[str, object]] = []
    last_pinned = False
    for diff_row in diff_rows:
        nes_frame = int(diff_row["nes_f"])
        gen_frame = int(diff_row["gen_f"])
        nes_rec = nes_trace.get(nes_frame)
        gen_rec = gen_trace.get(gen_frame)
        probe_rec = gen_probe.get(gen_frame)
        if not nes_rec or not gen_rec or not probe_rec:
            continue
        if frame_state(nes_rec) != (0, 1, 2):
            continue
        if frame_state(gen_rec) != (0, 1, 2):
            continue

        nes_img = ROOT / "builds" / "reports" / "intro_nes" / f"nes_f{nes_frame:05d}.png"
        gen_img = ROOT / "builds" / "reports" / "intro_gen" / f"gen_f{gen_frame:05d}.png"
        nes_first, nes_title, _ = image_metrics(img_cache, nes_img, title_template)
        gen_first, gen_title, _ = image_metrics(img_cache, gen_img, title_template)

        line_dst_n = (nes_rec["lineDstHi"] << 8) | nes_rec["lineDstLo"]
        line_dst_g = (gen_rec["lineDstHi"] << 8) | gen_rec["lineDstLo"]
        attr_dst_n = (nes_rec["attrDstHi"] << 8) | nes_rec["attrDstLo"]
        attr_dst_g = (gen_rec["attrDstHi"] << 8) | gen_rec["attrDstLo"]

        content_match = all(
            nes_rec.get(field) == gen_rec.get(field)
            for field in (
                "curVScroll",
                "switchReq",
                "demoLineTextIndex",
                "demoNTWraps",
                "lineCounter",
                "lineAttrIndex",
                "lineDstLo",
                "lineDstHi",
                "attrDstLo",
                "attrDstHi",
            )
        )

        mask_raw = float(diff_row["maskRaw"])
        if mask_raw <= MASK_OK:
            classification = "ok"
        elif content_match:
            classification = "display_bug"
        elif abs(gen_title - nes_title) <= 2 and abs(gen_first - nes_first) <= 2:
            classification = "content_bug"
        else:
            classification = "both"

        pinned = probe_rec["hintPendSplit"] != 0
        if pinned:
            segment = "title_pinned"
        elif last_pinned:
            segment = "title_release"
        else:
            segment = "full_scroll"
        last_pinned = pinned

        rows.append({
            "nesFrame": nes_frame,
            "genFrame": gen_frame,
            "segment": segment,
            "classification": classification,
            "maskRaw": mask_raw,
            "curVScroll": gen_rec["curVScroll"],
            "demoLineTextIndex": gen_rec["demoLineTextIndex"],
            "lineCounter": gen_rec["lineCounter"],
            "lineDst": line_dst_g,
            "attrDst": attr_dst_g,
            "switchReq": gen_rec["switchReq"],
            "vsram0": probe_rec["vsram0"],
            "hintQCount": probe_rec["hintQCount"],
            "hintPendSplit": probe_rec["hintPendSplit"],
            "introScrollMode": probe_rec["introScrollMode"],
            "genFirstRow": gen_first,
            "genTitleRow": gen_title,
            "nesFirstRow": nes_first,
            "nesTitleRow": nes_title,
            "contentMatch": 1 if content_match else 0,
            "lineDstNes": line_dst_n,
            "attrDstNes": attr_dst_n,
        })

    rows.sort(key=lambda row: (row["maskRaw"], row["genFrame"]), reverse=True)

    with OUT_CSV.open("w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow([
            "nesFrame", "genFrame", "segment", "classification", "maskRaw",
            "curVScroll", "demoLineTextIndex", "lineCounter", "lineDst",
            "attrDst", "switchReq", "vsram0", "hintQCount", "hintPendSplit",
            "introScrollMode", "genFirstRow", "genTitleRow", "nesFirstRow",
            "nesTitleRow", "contentMatch", "lineDstNes", "attrDstNes",
        ])
        for row in rows:
            writer.writerow([
                row["nesFrame"],
                row["genFrame"],
                row["segment"],
                row["classification"],
                f'{row["maskRaw"]:.5f}',
                f'{row["curVScroll"]:02X}',
                f'{row["demoLineTextIndex"]:02X}',
                f'{row["lineCounter"]:02X}',
                f'{row["lineDst"]:04X}',
                f'{row["attrDst"]:04X}',
                f'{row["switchReq"]:02X}',
                f'{row["vsram0"]:04X}',
                f'{row["hintQCount"]:02X}',
                f'{row["hintPendSplit"]:02X}',
                f'{row["introScrollMode"]:02X}',
                row["genFirstRow"],
                row["genTitleRow"],
                row["nesFirstRow"],
                row["nesTitleRow"],
                row["contentMatch"],
                f'{row["lineDstNes"]:04X}',
                f'{row["attrDstNes"]:04X}',
            ])

    class_counts: dict[str, int] = {}
    for row in rows:
        class_counts[row["classification"]] = class_counts.get(row["classification"], 0) + 1

    with OUT_MD.open("w", newline="") as fh:
        fh.write("# Intro Scroll Window Report\n\n")
        fh.write(f"- Active paired frames: {len(rows)}\n")
        fh.write(f"- Classification counts: {class_counts}\n")
        fh.write(f"- Display-bug frames: {sum(1 for row in rows if row['classification'] == 'display_bug')}\n")
        fh.write("\n## Worst 20 Active-Window Frames\n\n")
        fh.write("| nes | gen | segment | class | maskRaw | CurV | line | ctr | lineDst | attrDst | VSRAM0 | HQ | HP | mode | NES first/title | GEN first/title |\n")
        fh.write("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n")
        for row in rows[:20]:
            fh.write(
                f'| {row["nesFrame"]} | {row["genFrame"]} | {row["segment"]} | '
                f'{row["classification"]} | {row["maskRaw"]:.5f} | {row["curVScroll"]:02X} | '
                f'{row["demoLineTextIndex"]:02X} | {row["lineCounter"]:02X} | '
                f'{row["lineDst"]:04X} | {row["attrDst"]:04X} | {row["vsram0"]:04X} | '
                f'{row["hintQCount"]:02X} | {row["hintPendSplit"]:02X} | {row["introScrollMode"]:02X} | '
                f'{row["nesFirstRow"]}/{row["nesTitleRow"]} | {row["genFirstRow"]}/{row["genTitleRow"]} |\n'
            )


if __name__ == "__main__":
    main()
