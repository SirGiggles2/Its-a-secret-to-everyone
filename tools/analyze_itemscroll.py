from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

from PIL import Image
import numpy as np


ROOT = Path(r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY")
REPORT_DIR = ROOT / "builds" / "reports" / "item_scroll"
GEN_DIR = ROOT / "builds" / "reports" / "items_seq_gen"
NES_DIR = ROOT / "builds" / "reports" / "items_seq_nes"


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


def s2_rows(rows: Iterable[TraceRow]) -> List[TraceRow]:
    return [r for r in rows if r.phase == 0x01 and r.subphase == 0x02]


def main() -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    gen_rows = parse_trace(GEN_DIR / "gen_trace.txt")
    nes_rows = parse_trace(NES_DIR / "nes_trace.txt")
    gen_s2 = s2_rows(gen_rows)
    nes_s2 = s2_rows(nes_rows)

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


if __name__ == "__main__":
    main()
