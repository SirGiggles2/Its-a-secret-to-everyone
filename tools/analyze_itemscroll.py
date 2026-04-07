from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

from PIL import Image
import numpy as np


ROOT = Path(r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY")
REPORT_DIR = ROOT / "builds" / "reports" / "item_scroll"
GEN_DIR = ROOT / "builds" / "reports" / "items_fix2_gen"
NES_DIR = ROOT / "builds" / "reports" / "items_baseline_nes"


@dataclass
class TraceRow:
    frame: int
    game_mode: int
    phase: int
    subphase: int
    frame_ctr: int
    cur_v: int
    cur_h: int
    ppu_ctrl: int
    switch_req: int
    tile_buf_sel: int
    line_counter: int
    vram_hi: int
    vram_lo: int
    text_index: int
    obj_y_tick: int
    vsram0: int
    ppu_scrl_x: int
    ppu_scrl_y: int
    hint_q_count: int
    hint_pend_split: int
    intro_scroll_mode: int
    staged_mode: int
    staged_hint_ctr: int
    staged_base: int
    staged_event: int
    active_hint_ctr: int
    staged_segment: int
    active_segment: int
    active_base: int
    active_event: int
    sprite_visible: int
    attr_index: int
    item_row: int

    @property
    def key(self) -> Tuple[int, int, int, int, int, int]:
        return (
            self.phase,
            self.subphase,
            self.cur_v,
            self.line_counter,
            self.vram_hi,
            self.vram_lo,
        )


def parse_trace(path: Path) -> List[TraceRow]:
    lines = path.read_text().splitlines()
    header = lines[1][2:].split(",")
    rows: List[TraceRow] = []
    for raw in csv.DictReader(lines[2:], fieldnames=header):
        rows.append(
            TraceRow(
                frame=int(raw["frame"]),
                game_mode=int(raw["gameMode"], 16),
                phase=int(raw["phase"], 16),
                subphase=int(raw["subphase"], 16),
                frame_ctr=int(raw["frameCtr"], 16),
                cur_v=int(raw["curVScroll"], 16),
                cur_h=int(raw["curHScroll"], 16),
                ppu_ctrl=int(raw["ppuCtrl"], 16),
                switch_req=int(raw["switchReq"], 16),
                tile_buf_sel=int(raw["tileBufSel"], 16),
                line_counter=int(raw["lineCounter"], 16),
                vram_hi=int(raw["vramHi"], 16),
                vram_lo=int(raw["vramLo"], 16),
                text_index=int(raw["textIndex"], 16),
                obj_y_tick=int(raw["objYTick"], 16),
                vsram0=int(raw["vsram0"], 16),
                ppu_scrl_x=int(raw["ppuScrlX"], 16),
                ppu_scrl_y=int(raw["ppuScrlY"], 16),
                hint_q_count=int(raw["hintQCount"], 16),
                hint_pend_split=int(raw["hintPendSplit"], 16),
                intro_scroll_mode=int(raw["introScrollMode"], 16),
                staged_mode=int(raw["stagedMode"], 16),
                staged_hint_ctr=int(raw["stagedHintCtr"], 16),
                staged_base=int(raw["stagedBase"], 16),
                staged_event=int(raw["stagedEvent"], 16),
                active_hint_ctr=int(raw["activeHintCtr"], 16),
                staged_segment=int(raw["stagedSegment"], 16),
                active_segment=int(raw["activeSegment"], 16),
                active_base=int(raw["activeBase"], 16),
                active_event=int(raw["activeEvent"], 16),
                sprite_visible=int(raw["spriteVisible"]),
                attr_index=int(raw.get("attrIndex", "FF"), 16),
                item_row=int(raw.get("itemRow", "FF"), 16),
            )
        )
    return rows


def load_gray(path: Path) -> np.ndarray:
    img = Image.open(path).convert("L")
    return np.array(img, dtype=np.int16)


def changed_rows(a: np.ndarray, b: np.ndarray, threshold: int = 12) -> Tuple[int, int, int]:
    diff = np.abs(a - b)
    mask = diff > threshold
    rows = np.nonzero(mask.any(axis=1))[0]
    if len(rows) == 0:
        return -1, -1, 0
    return int(rows[0]), int(rows[-1]), int(len(rows))


def mismatch_ratio(a: np.ndarray, b: np.ndarray, threshold: int = 20) -> float:
    diff = np.abs(a - b)
    return float((diff > threshold).mean())


def best_shift(a: np.ndarray, b: np.ndarray, max_shift: int = 4) -> Tuple[int, float]:
    best_y = 0
    best = float("inf")
    for dy in range(-max_shift, max_shift + 1):
        if dy >= 0:
            aa = a[dy:, :]
            bb = b[: a.shape[0] - dy, :]
        else:
            aa = a[: a.shape[0] + dy, :]
            bb = b[-dy:, :]
        if aa.size == 0 or bb.size == 0:
            continue
        score = float(np.mean(np.abs(aa - bb)))
        if score < best:
            best = score
            best_y = dy
    return best_y, best


def frame_path(directory: Path, label: str, frame: int) -> Path:
    return directory / f"{label}_f{frame:05d}.png"


def item_rows(rows: Iterable[TraceRow]) -> List[TraceRow]:
    return [r for r in rows if r.phase == 0x01 and r.subphase == 0x02 and r.text_index >= 0x05]


def region_slice(img: np.ndarray, rect: Tuple[int, int, int, int]) -> np.ndarray:
    x0, y0, x1, y1 = rect
    return img[y0:y1, x0:x1]


def ink_bbox(img: np.ndarray, rect: Tuple[int, int, int, int], threshold: int = 24) -> Optional[Tuple[int, int, int, int]]:
    x0, y0, x1, y1 = rect
    region = region_slice(img, rect)
    ys, xs = np.nonzero(region > threshold)
    if len(xs) == 0:
        return None
    return (x0 + int(xs.min()), y0 + int(ys.min()), x0 + int(xs.max()), y0 + int(ys.max()))


def region_mismatch(a: np.ndarray, b: np.ndarray, rect: Tuple[int, int, int, int], threshold: int = 20) -> float:
    aa = region_slice(a, rect)
    bb = region_slice(b, rect)
    diff = np.abs(aa - bb)
    return float((diff > threshold).mean())


def bbox_anchor_delta(nes_bbox: Optional[Tuple[int, int, int, int]], gen_bbox: Optional[Tuple[int, int, int, int]]) -> Tuple[int, int]:
    if nes_bbox is None or gen_bbox is None:
        return (999, 999)
    return (gen_bbox[0] - nes_bbox[0], gen_bbox[1] - nes_bbox[1])


def bbox_fields(prefix: str, bbox: Optional[Tuple[int, int, int, int]]) -> Dict[str, int]:
    if bbox is None:
        return {
            f"{prefix}X0": -1,
            f"{prefix}Y0": -1,
            f"{prefix}X1": -1,
            f"{prefix}Y1": -1,
        }
    return {
        f"{prefix}X0": bbox[0],
        f"{prefix}Y0": bbox[1],
        f"{prefix}X1": bbox[2],
        f"{prefix}Y1": bbox[3],
    }


def main() -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    gen_rows = parse_trace(GEN_DIR / "gen_trace.txt")
    nes_rows = parse_trace(NES_DIR / "nes_trace.txt")
    gen_s2 = item_rows(gen_rows)
    nes_s2 = item_rows(nes_rows)

    gen_by_key: Dict[Tuple[int, int, int, int, int, int], TraceRow] = {}
    nes_by_key: Dict[Tuple[int, int, int, int, int, int], TraceRow] = {}
    for r in gen_s2:
        gen_by_key.setdefault(r.key, r)
    for r in nes_s2:
        nes_by_key.setdefault(r.key, r)

    shared_keys = sorted(set(gen_by_key) & set(nes_by_key), key=lambda k: (k[2], k[3], k[5]))

    pair_rows = []
    for key in shared_keys:
        gr = gen_by_key[key]
        nr = nes_by_key[key]
        gimg = load_gray(frame_path(GEN_DIR, "gen", gr.frame))
        nimg = load_gray(frame_path(NES_DIR, "nes", nr.frame))
        ratio = mismatch_ratio(gimg, nimg)
        first, last, count = changed_rows(nimg, gimg)
        pair_rows.append(
            {
                "nesFrame": nr.frame,
                "genFrame": gr.frame,
                "phase": nr.phase,
                "subphase": nr.subphase,
                "curV": nr.cur_v,
                "lineCounter": nr.line_counter,
                "textIndex": nr.text_index,
                "vramHi": nr.vram_hi,
                "vramLo": nr.vram_lo,
                "nesSprites": nr.sprite_visible,
                "genSprites": gr.sprite_visible,
                "maskRaw": ratio,
                "firstChangedRow": first,
                "lastChangedRow": last,
                "changedRowCount": count,
                "nesVsram0": nr.vsram0,
                "genVsram0": gr.vsram0,
                "genHintQ": gr.hint_q_count,
                "genHintPend": gr.hint_pend_split,
                "genMode": gr.intro_scroll_mode,
                "genActiveSeg": gr.active_segment,
                "genActiveBase": gr.active_base,
                "genActiveEvent": gr.active_event,
                "nesAttrIndex": nr.attr_index,
                "genAttrIndex": gr.attr_index,
                "nesItemRow": nr.item_row,
                "genItemRow": gr.item_row,
            }
        )

    pair_csv = REPORT_DIR / "item_pairs.csv"
    with pair_csv.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(pair_rows[0].keys()))
        writer.writeheader()
        writer.writerows(pair_rows)

    def build_transitions(rows: List[TraceRow], label: str, img_dir: Path) -> Dict[Tuple[Tuple[int, int, int, int, int, int], Tuple[int, int, int, int, int, int]], dict]:
        out = {}
        for a, b in zip(rows, rows[1:]):
            aimg = load_gray(frame_path(img_dir, label, a.frame))
            bimg = load_gray(frame_path(img_dir, label, b.frame))
            first, last, count = changed_rows(aimg, bimg)
            shift_y, residual = best_shift(aimg, bimg)
            out[(a.key, b.key)] = {
                "fromFrame": a.frame,
                "toFrame": b.frame,
                "curV": a.cur_v,
                "nextCurV": b.cur_v,
                "lineCounter": a.line_counter,
                "nextLineCounter": b.line_counter,
                "textIndex": a.text_index,
                "nextTextIndex": b.text_index,
                "attrIndex": a.attr_index,
                "nextAttrIndex": b.attr_index,
                "itemRow": a.item_row,
                "nextItemRow": b.item_row,
                "tileBufSel": a.tile_buf_sel,
                "nextTileBufSel": b.tile_buf_sel,
                "bestShiftY": shift_y,
                "residual": residual,
                "firstChangedRow": first,
                "lastChangedRow": last,
                "changedRowCount": count,
            }
        return out

    gen_trans = build_transitions(gen_s2, "gen", GEN_DIR)
    nes_trans = build_transitions(nes_s2, "nes", NES_DIR)
    shared_trans = sorted(set(gen_trans) & set(nes_trans), key=lambda item: (item[0][2], item[1][2], item[0][3]))

    continuity_rows = []
    for key in shared_trans:
        gt = gen_trans[key]
        nt = nes_trans[key]
        classification = "ok"
        if gt["bestShiftY"] != nt["bestShiftY"] or abs(gt["changedRowCount"] - nt["changedRowCount"]) > 4:
            classification = "motion_mismatch"
        continuity_rows.append(
            {
                "curV": gt["curV"],
                "nextCurV": gt["nextCurV"],
                "lineCounter": gt["lineCounter"],
                "nextLineCounter": gt["nextLineCounter"],
                "textIndex": gt["textIndex"],
                "nextTextIndex": gt["nextTextIndex"],
                "attrIndex": gt["attrIndex"],
                "nextAttrIndex": gt["nextAttrIndex"],
                "itemRow": gt["itemRow"],
                "nextItemRow": gt["nextItemRow"],
                "nesFrom": nt["fromFrame"],
                "nesTo": nt["toFrame"],
                "genFrom": gt["fromFrame"],
                "genTo": gt["toFrame"],
                "nesShiftY": nt["bestShiftY"],
                "genShiftY": gt["bestShiftY"],
                "nesRows": nt["changedRowCount"],
                "genRows": gt["changedRowCount"],
                "nesFirstRow": nt["firstChangedRow"],
                "genFirstRow": gt["firstChangedRow"],
                "nesLastRow": nt["lastChangedRow"],
                "genLastRow": gt["lastChangedRow"],
                "nesResidual": round(nt["residual"], 3),
                "genResidual": round(gt["residual"], 3),
                "classification": classification,
            }
        )

    cont_csv = REPORT_DIR / "item_continuity.csv"
    with cont_csv.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(continuity_rows[0].keys()))
        writer.writeheader()
        writer.writerows(continuity_rows)

    regions = {
        "titleHeart": (0, 0, 256, 64),
        "rupeeText": (24, 80, 232, 144),
        "triforceBlock": (56, 88, 200, 176),
        "triforceCaption": (64, 144, 208, 208),
    }
    layout_targets = {
        "title_heart": 2303,
        "rupee_text": 2601,
        "late_triforce": 2704,
    }

    def closest_pair(target_gen_frame: int) -> dict:
        return min(pair_rows, key=lambda row: (abs(row["genFrame"] - target_gen_frame), abs(row["nesFrame"] - (target_gen_frame - 60))))

    layout_rows = []
    for anchor, target_gen_frame in layout_targets.items():
        pair = closest_pair(target_gen_frame)
        gimg = load_gray(frame_path(GEN_DIR, "gen", pair["genFrame"]))
        nimg = load_gray(frame_path(NES_DIR, "nes", pair["nesFrame"]))
        for region_name, rect in regions.items():
            nes_bbox = ink_bbox(nimg, rect)
            gen_bbox = ink_bbox(gimg, rect)
            dx, dy = bbox_anchor_delta(nes_bbox, gen_bbox)
            row = {
                "anchor": anchor,
                "region": region_name,
                "nesFrame": pair["nesFrame"],
                "genFrame": pair["genFrame"],
                "curV": pair["curV"],
                "lineCounter": pair["lineCounter"],
                "textIndex": pair["textIndex"],
                "nesAttrIndex": pair["nesAttrIndex"],
                "genAttrIndex": pair["genAttrIndex"],
                "nesItemRow": pair["nesItemRow"],
                "genItemRow": pair["genItemRow"],
                "nesSprites": pair["nesSprites"],
                "genSprites": pair["genSprites"],
                "genMode": pair["genMode"],
                "genActiveSeg": pair["genActiveSeg"],
                "genActiveBase": pair["genActiveBase"],
                "genActiveEvent": pair["genActiveEvent"],
                "maskRaw": round(region_mismatch(nimg, gimg, rect), 5),
                "anchorDx": dx,
                "anchorDy": dy,
            }
            row.update(bbox_fields("nes", nes_bbox))
            row.update(bbox_fields("gen", gen_bbox))
            layout_rows.append(row)

    layout_csv = REPORT_DIR / "item_layout.csv"
    with layout_csv.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(layout_rows[0].keys()))
        writer.writeheader()
        writer.writerows(layout_rows)

    worst_pairs = sorted(pair_rows, key=lambda r: r["maskRaw"], reverse=True)[:12]
    motion_bad = [r for r in continuity_rows if r["classification"] != "ok"]

    summary = REPORT_DIR / "item_summary.md"
    with summary.open("w", encoding="utf-8") as f:
        f.write("# Item Scroll Summary\n\n")
        f.write(f"- Shared paired frames in phase 1/subphase 2: {len(pair_rows)}\n")
        f.write(f"- Shared paired transitions in phase 1/subphase 2: {len(continuity_rows)}\n")
        f.write(f"- Motion mismatches: {len(motion_bad)}\n")
        if pair_rows:
            avg_mask = sum(r["maskRaw"] for r in pair_rows) / len(pair_rows)
            f.write(f"- Average paired mismatch (`maskRaw`): {avg_mask:.4f}\n")
        f.write("\n## Worst Paired Frames\n\n")
        f.write("| nes | gen | curV | line | text | maskRaw | rows |\n")
        f.write("|---|---|---:|---:|---:|---:|---:|\n")
        for row in worst_pairs:
            f.write(
                f"| {row['nesFrame']} | {row['genFrame']} | {row['curV']:02X} | {row['lineCounter']:02X} | {row['textIndex']:02X} | {row['maskRaw']:.4f} | {row['changedRowCount']} |\n"
            )
        f.write("\n## First Motion Mismatches\n\n")
        f.write("| curV | next | nes | gen | nesShift | genShift | nesRows | genRows |\n")
        f.write("|---:|---:|---|---|---:|---:|---:|---:|\n")
        for row in motion_bad[:16]:
            f.write(
                f"| {row['curV']:02X} | {row['nextCurV']:02X} | {row['nesFrom']}->{row['nesTo']} | {row['genFrom']}->{row['genTo']} | {row['nesShiftY']} | {row['genShiftY']} | {row['nesRows']} | {row['genRows']} |\n"
            )

    layout_md = REPORT_DIR / "item_layout.md"
    with layout_md.open("w", encoding="utf-8") as f:
        f.write("# Item Layout Summary\n\n")
        for anchor in layout_targets:
            anchor_rows = [row for row in layout_rows if row["anchor"] == anchor]
            if not anchor_rows:
                continue
            pair = anchor_rows[0]
            f.write(f"## {anchor}\n\n")
            f.write(
                f"- paired frames: NES {pair['nesFrame']} vs GEN {pair['genFrame']}\n"
                f"- state: curV={pair['curV']:02X} line={pair['lineCounter']:02X} text={pair['textIndex']:02X} "
                f"attr={pair['nesAttrIndex']:02X}/{pair['genAttrIndex']:02X} itemRow={pair['nesItemRow']:02X}/{pair['genItemRow']:02X}\n"
                f"- Genesis active state: seg={pair['genActiveSeg']:02X} base={pair['genActiveBase']:04X} event={pair['genActiveEvent']:04X} mode={pair['genMode']:02X}\n"
                f"- sprites: nes={pair['nesSprites']} gen={pair['genSprites']}\n\n"
            )
            f.write("| region | maskRaw | dx | dy | nes bbox | gen bbox |\n")
            f.write("|---|---:|---:|---:|---|---|\n")
            for row in anchor_rows:
                f.write(
                    f"| {row['region']} | {row['maskRaw']:.5f} | {row['anchorDx']} | {row['anchorDy']} | "
                    f"({row['nesX0']},{row['nesY0']})-({row['nesX1']},{row['nesY1']}) | "
                    f"({row['genX0']},{row['genY0']})-({row['genX1']},{row['genY1']}) |\n"
                )
            f.write("\n")


if __name__ == "__main__":
    main()
