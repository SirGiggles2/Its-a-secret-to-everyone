#!/usr/bin/env python3
from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path

from PIL import Image

ROOT = Path(r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY")
REPORT_DIR = ROOT / "builds" / "reports" / "intro_continuity"

NES_TRACE = ROOT / "builds" / "reports" / "intro_nes" / "nes_trace.txt"
GEN_TRACE = ROOT / "builds" / "reports" / "intro_gen" / "gen_trace.txt"
GEN_ROWWRITE = ROOT / "builds" / "reports" / "intro_window" / "intro_rowwrite_probe.csv"

NES_DIR = ROOT / "builds" / "reports" / "intro_nes"
GEN_DIR = ROOT / "builds" / "reports" / "intro_gen"

OUT_NES = REPORT_DIR / "nes_continuity.csv"
OUT_GEN = REPORT_DIR / "gen_continuity.csv"
OUT_COMPARE = REPORT_DIR / "continuity_compare.csv"
OUT_MD = REPORT_DIR / "continuity_summary.md"

ACTIVE_STATE = (0, 1, 2)
FIRST_SECTION_MAX_LINE = 0x08
SHIFT_RANGE = range(-4, 5)

TITLE_BOX = (16, 24, 240, 56)
STORY_BOX = (16, 56, 240, 216)


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


def load_rowwrite(path: Path) -> dict[int, dict[str, int]]:
    rows: dict[int, dict[str, int]] = {}
    if not path.exists():
        return rows
    with path.open(newline="") as fh:
        for row in csv.DictReader(fh):
            frame = int(row["frame"])
            rec: dict[str, int] = {}
            for key, value in row.items():
                if key == "frame":
                    continue
                if value == "":
                    rec[key] = 0
                elif key in {"lineDst", "attrDst", "planeLineDst", "attrLineDst"}:
                    rec[key] = int(value, 16)
                else:
                    rec[key] = int(value, 16) if len(value) > 1 and all(c in "0123456789ABCDEFabcdef" for c in value) and key not in {
                        "subphase2Hits",
                        "lineRecordHit",
                        "attrRecordHit",
                        "lineAdvanced",
                        "attrAdvanced",
                        "ntWrapped",
                    } else int(value)
            rows[frame] = rec
    return rows


def frame_state(rec: dict[str, int]) -> tuple[int, int, int]:
    return rec.get("gameMode", 0xFF), rec.get("phase", 0xFF), rec.get("subphase", 0xFF)


def line_dst(rec: dict[str, int]) -> int:
    return (rec.get("lineDstHi", 0) << 8) | rec.get("lineDstLo", 0)


def mean_abs_delta(a: Image.Image, b: Image.Image) -> float:
    pa = a.tobytes()
    pb = b.tobytes()
    total = 0
    for i in range(len(pa)):
        total += abs(pa[i] - pb[i])
    return total / len(pa) / 255.0


def best_vertical_shift(img_a: Image.Image, img_b: Image.Image, box: tuple[int, int, int, int]) -> tuple[int, float]:
    x0, y0, x1, y1 = box
    best_shift = 0
    best_score = float("inf")
    for shift in SHIFT_RANGE:
        if shift >= 0:
            top_a = y0
            top_b = y0 + shift
            bottom_a = y1 - shift
            bottom_b = y1
        else:
            top_a = y0 - shift
            top_b = y0
            bottom_a = y1
            bottom_b = y1 + shift
        if bottom_a - top_a < 8 or bottom_b - top_b < 8:
            continue
        crop_a = img_a.crop((x0, top_a, x1, bottom_a))
        crop_b = img_b.crop((x0, top_b, x1, bottom_b))
        score = mean_abs_delta(crop_a, crop_b)
        if (score, abs(shift), shift) < (best_score, abs(best_shift), best_shift):
            best_score = score
            best_shift = shift
    return best_shift, best_score


def load_image(cache: dict[Path, Image.Image], path: Path) -> Image.Image:
    img = cache.get(path)
    if img is not None:
        return img
    img = Image.open(path).convert("L")
    cache[path] = img
    return img


def segment_for_transition(from_rec: dict[str, int], to_rec: dict[str, int], wrote_line: bool) -> str:
    if frame_state(from_rec) != ACTIVE_STATE and frame_state(to_rec) == ACTIVE_STATE:
        return "subphase_entry"
    if to_rec.get("demoLineTextIndex", 0xFF) <= FIRST_SECTION_MAX_LINE:
        return "first_section_line_write" if wrote_line else "first_section_scroll"
    return "later_line_write" if wrote_line else "later_scroll"


def transition_key(from_rec: dict[str, int], to_rec: dict[str, int]) -> tuple[int, int, int, int, int, int]:
    return (
        from_rec.get("curVScroll", 0xFF),
        to_rec.get("curVScroll", 0xFF),
        from_rec.get("demoLineTextIndex", 0xFF),
        to_rec.get("demoLineTextIndex", 0xFF),
        to_rec.get("lineCounter", 0xFF),
        line_dst(to_rec),
        to_rec.get("switchReq", 0xFF),
    )


def build_transitions(
    system: str,
    trace: dict[int, dict[str, int]],
    image_dir: Path,
    rowwrite: dict[int, dict[str, int]] | None,
) -> list[dict[str, object]]:
    frames = sorted(trace)
    img_cache: dict[Path, Image.Image] = {}
    rows: list[dict[str, object]] = []

    for prev_frame, frame in zip(frames, frames[1:]):
        if frame != prev_frame + 1:
            continue
        from_rec = trace[prev_frame]
        to_rec = trace[frame]
        if frame_state(to_rec) != ACTIVE_STATE:
            continue

        prev_img = load_image(img_cache, image_dir / f"{system}_f{prev_frame:05d}.png")
        img = load_image(img_cache, image_dir / f"{system}_f{frame:05d}.png")

        story_shift, story_residual = best_vertical_shift(prev_img, img, STORY_BOX)
        title_shift, title_residual = best_vertical_shift(prev_img, img, TITLE_BOX)

        inferred_line_write = (
            line_dst(to_rec) != line_dst(from_rec)
            or to_rec.get("demoLineTextIndex", 0xFF) != from_rec.get("demoLineTextIndex", 0xFF)
        )
        probe_rec = rowwrite.get(frame) if rowwrite else None
        probe_line_write = 0
        if probe_rec:
            probe_line_write = int(
                probe_rec.get("lineRecordHit", 0) > 0
                or probe_rec.get("lineAdvanced", 0) > 0
                or probe_rec.get("subphase2Hits", 0) > 1
            )
        wrote_line = int(inferred_line_write or probe_line_write)

        rows.append({
            "system": system,
            "fromFrame": prev_frame,
            "toFrame": frame,
            "curVScroll": to_rec.get("curVScroll", 0xFF),
            "demoLineTextIndex": to_rec.get("demoLineTextIndex", 0xFF),
            "lineCounter": to_rec.get("lineCounter", 0xFF),
            "lineDst": line_dst(to_rec),
            "switchReq": to_rec.get("switchReq", 0xFF),
            "bestShiftY": story_shift,
            "residual": story_residual,
            "titleShiftY": title_shift,
            "titleResidual": title_residual,
            "lineWrite": wrote_line,
            "probeLineWrite": probe_line_write,
            "lineSelectAdvance": int(
                to_rec.get("demoLineTextIndex", 0xFF) != from_rec.get("demoLineTextIndex", 0xFF)
            ),
            "lineDstAdvance": int(line_dst(to_rec) != line_dst(from_rec)),
            "lineCounterAdvance": int(
                to_rec.get("lineCounter", 0xFF) != from_rec.get("lineCounter", 0xFF)
            ),
            "curVAdvance": int(
                to_rec.get("curVScroll", 0xFF) != from_rec.get("curVScroll", 0xFF)
            ),
            "segment": segment_for_transition(from_rec, to_rec, bool(wrote_line)),
            "stateKey": transition_key(from_rec, to_rec),
        })
    return rows


def write_transition_csv(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow([
            "system", "fromFrame", "toFrame", "segment", "curVScroll",
            "demoLineTextIndex", "lineCounter", "lineDst", "switchReq",
            "bestShiftY", "residual", "titleShiftY", "titleResidual",
            "lineWrite", "probeLineWrite", "lineSelectAdvance",
            "lineDstAdvance", "lineCounterAdvance", "curVAdvance",
        ])
        for row in rows:
            writer.writerow([
                row["system"],
                row["fromFrame"],
                row["toFrame"],
                row["segment"],
                f'{row["curVScroll"]:02X}',
                f'{row["demoLineTextIndex"]:02X}',
                f'{row["lineCounter"]:02X}',
                f'{row["lineDst"]:04X}',
                f'{row["switchReq"]:02X}',
                row["bestShiftY"],
                f'{row["residual"]:.5f}',
                row["titleShiftY"],
                f'{row["titleResidual"]:.5f}',
                row["lineWrite"],
                row["probeLineWrite"],
                row["lineSelectAdvance"],
                row["lineDstAdvance"],
                row["lineCounterAdvance"],
                row["curVAdvance"],
            ])


def classify_compare(nes_row: dict[str, object], gen_row: dict[str, object]) -> str:
    shift_mismatch = (
        nes_row["bestShiftY"] != gen_row["bestShiftY"]
        or nes_row["titleShiftY"] != gen_row["titleShiftY"]
    )
    timing_mismatch = (
        nes_row["lineWrite"] != gen_row["lineWrite"]
        or nes_row["lineSelectAdvance"] != gen_row["lineSelectAdvance"]
        or nes_row["lineDstAdvance"] != gen_row["lineDstAdvance"]
    )
    if not shift_mismatch and not timing_mismatch:
        return "ok"
    if shift_mismatch and not timing_mismatch:
        return "display_timing"
    if timing_mismatch and not shift_mismatch:
        return "content_timing"
    return "both"


def build_compare(
    nes_rows: list[dict[str, object]],
    gen_rows: list[dict[str, object]],
) -> list[dict[str, object]]:
    nes_by_key = {row["stateKey"]: row for row in nes_rows}
    rows: list[dict[str, object]] = []
    for gen_row in gen_rows:
        nes_row = nes_by_key.get(gen_row["stateKey"])
        if not nes_row:
            continue
        rows.append({
            "nesFrom": nes_row["fromFrame"],
            "nesTo": nes_row["toFrame"],
            "genFrom": gen_row["fromFrame"],
            "genTo": gen_row["toFrame"],
            "segment": gen_row["segment"],
            "curVScroll": gen_row["curVScroll"],
            "demoLineTextIndex": gen_row["demoLineTextIndex"],
            "lineCounter": gen_row["lineCounter"],
            "lineDst": gen_row["lineDst"],
            "switchReq": gen_row["switchReq"],
            "nesShiftY": nes_row["bestShiftY"],
            "genShiftY": gen_row["bestShiftY"],
            "shiftDelta": int(gen_row["bestShiftY"]) - int(nes_row["bestShiftY"]),
            "nesResidual": nes_row["residual"],
            "genResidual": gen_row["residual"],
            "nesTitleShiftY": nes_row["titleShiftY"],
            "genTitleShiftY": gen_row["titleShiftY"],
            "nesLineWrite": nes_row["lineWrite"],
            "genLineWrite": gen_row["lineWrite"],
            "class": classify_compare(nes_row, gen_row),
        })
    rows.sort(key=lambda row: row["genTo"])
    return rows


def write_compare_csv(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow([
            "nesFrom", "nesTo", "genFrom", "genTo", "segment", "class",
            "curVScroll", "demoLineTextIndex", "lineCounter", "lineDst",
            "switchReq", "nesShiftY", "genShiftY", "shiftDelta",
            "nesResidual", "genResidual", "nesTitleShiftY", "genTitleShiftY",
            "nesLineWrite", "genLineWrite",
        ])
        for row in rows:
            writer.writerow([
                row["nesFrom"],
                row["nesTo"],
                row["genFrom"],
                row["genTo"],
                row["segment"],
                row["class"],
                f'{row["curVScroll"]:02X}',
                f'{row["demoLineTextIndex"]:02X}',
                f'{row["lineCounter"]:02X}',
                f'{row["lineDst"]:04X}',
                f'{row["switchReq"]:02X}',
                row["nesShiftY"],
                row["genShiftY"],
                row["shiftDelta"],
                f'{row["nesResidual"]:.5f}',
                f'{row["genResidual"]:.5f}',
                row["nesTitleShiftY"],
                row["genTitleShiftY"],
                row["nesLineWrite"],
                row["genLineWrite"],
            ])


def main() -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    nes_trace = load_trace(NES_TRACE)
    gen_trace = load_trace(GEN_TRACE)
    gen_rowwrite = load_rowwrite(GEN_ROWWRITE)

    nes_rows = build_transitions("nes", nes_trace, NES_DIR, None)
    gen_rows = build_transitions("gen", gen_trace, GEN_DIR, gen_rowwrite)
    compare_rows = build_compare(nes_rows, gen_rows)

    write_transition_csv(OUT_NES, nes_rows)
    write_transition_csv(OUT_GEN, gen_rows)
    write_compare_csv(OUT_COMPARE, compare_rows)

    class_counts = Counter(row["class"] for row in compare_rows)
    first_bad = next((row for row in compare_rows if row["class"] != "ok"), None)
    first_section = [row for row in compare_rows if str(row["segment"]).startswith("first_section")]
    first_section_bad = [row for row in first_section if row["class"] != "ok"]

    gen_first_section = [row for row in gen_rows if str(row["segment"]).startswith("first_section")]
    jumpy_gen = [
        row for row in gen_first_section
        if abs(int(row["bestShiftY"])) > 1 or abs(int(row["titleShiftY"])) > 1
    ]

    with OUT_MD.open("w", newline="") as fh:
        fh.write("# Intro Continuity Report\n\n")
        fh.write(f"- NES transitions: {len(nes_rows)}\n")
        fh.write(f"- Genesis transitions: {len(gen_rows)}\n")
        fh.write(f"- Matched transitions: {len(compare_rows)}\n")
        fh.write(f"- Compare classes: {dict(class_counts)}\n")
        fh.write(f"- First-section matched transitions: {len(first_section)}\n")
        fh.write(f"- First-section divergences: {len(first_section_bad)}\n")
        fh.write(f"- Genesis-only jump suspects in first section: {len(jumpy_gen)}\n\n")

        if first_bad:
            fh.write("## First Matched Divergence\n\n")
            fh.write(
                f'- NES {first_bad["nesFrom"]}->{first_bad["nesTo"]} vs '
                f'GEN {first_bad["genFrom"]}->{first_bad["genTo"]}: '
                f'{first_bad["class"]}, shift {first_bad["nesShiftY"]}->{first_bad["genShiftY"]}, '
                f'lineWrite {first_bad["nesLineWrite"]}->{first_bad["genLineWrite"]}\n\n'
            )

        if first_section_bad:
            fh.write("## First-Section Divergences\n\n")
            fh.write("| nes | gen | class | segment | curV | line | ctr | lineDst | NES shift | GEN shift | NES write | GEN write |\n")
            fh.write("|---|---|---|---|---|---|---|---|---|---|---|---|\n")
            for row in first_section_bad[:20]:
                fh.write(
                    f'| {row["nesFrom"]}->{row["nesTo"]} | {row["genFrom"]}->{row["genTo"]} | '
                    f'{row["class"]} | {row["segment"]} | {row["curVScroll"]:02X} | '
                    f'{row["demoLineTextIndex"]:02X} | {row["lineCounter"]:02X} | {row["lineDst"]:04X} | '
                    f'{row["nesShiftY"]} | {row["genShiftY"]} | {row["nesLineWrite"]} | {row["genLineWrite"]} |\n'
                )

        if jumpy_gen:
            fh.write("\n## Genesis-Only First-Section Jump Suspects\n\n")
            fh.write("| gen | segment | curV | line | ctr | lineDst | shift | titleShift | residual | lineWrite |\n")
            fh.write("|---|---|---|---|---|---|---|---|---|---|\n")
            for row in jumpy_gen[:20]:
                fh.write(
                    f'| {row["fromFrame"]}->{row["toFrame"]} | {row["segment"]} | '
                    f'{row["curVScroll"]:02X} | {row["demoLineTextIndex"]:02X} | {row["lineCounter"]:02X} | '
                    f'{row["lineDst"]:04X} | {row["bestShiftY"]} | {row["titleShiftY"]} | '
                    f'{row["residual"]:.5f} | {row["lineWrite"]} |\n'
                )


if __name__ == "__main__":
    main()
