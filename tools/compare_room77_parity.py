#!/usr/bin/env python3
"""Room-target strict BG parity comparator with deterministic triage routing.

Inputs:
  builds/reports/roomXX_gen_capture.json
  builds/reports/roomXX_nes_capture.json
  src/nes_io.asm (NES->Genesis palette LUT)

Outputs:
  builds/reports/roomXX_parity_report.txt
  builds/reports/roomXX_parity_report.json
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / "builds" / "reports"
NES_IO_ASM = ROOT / "src" / "nes_io.asm"

ROWS = 22
COLS = 32

ROUTE_LAYOUT_SOURCE = "ROUTE_LAYOUT_SOURCE"
ROUTE_LAYOUT_DECODE = "ROUTE_LAYOUT_DECODE"
ROUTE_TRANSFER_PATH = "ROUTE_TRANSFER_PATH"
ROUTE_TRANSFER_CAPTURE_INVALID = "ROUTE_TRANSFER_CAPTURE_INVALID"
ROUTE_TRANSFER_PRODUCER = "ROUTE_TRANSFER_PRODUCER"
ROUTE_TRANSFER_INTERPRETER = "ROUTE_TRANSFER_INTERPRETER"
ROUTE_TRANSFER_INTERPRETER_EDGE = "ROUTE_TRANSFER_INTERPRETER_EDGE"
ROUTE_EDGE_OWNERSHIP_EXTERNAL = "ROUTE_EDGE_OWNERSHIP_EXTERNAL"
ROUTE_EDGE_SEED_MISSING = "ROUTE_EDGE_SEED_MISSING"
ROUTE_EDGE_RUNTIME_DIVERGENCE = "ROUTE_EDGE_RUNTIME_DIVERGENCE"
ROUTE_EDGE_WINDOW_CONTRACT = "ROUTE_EDGE_WINDOW_CONTRACT"
ROUTE_CAPTURE_ALIGNMENT = "ROUTE_CAPTURE_ALIGNMENT"
ROUTE_TRANSITION_SETTLE = "ROUTE_TRANSITION_SETTLE"
ROUTE_NONE = "ROUTE_NONE"


def parse_room_id(text: str) -> int:
    s = str(text).strip()
    if s.lower().startswith("0x"):
        return int(s, 16) & 0xFF
    if s.startswith("$"):
        return int(s[1:], 16) & 0xFF
    return int(s, 16) & 0xFF if re.fullmatch(r"[0-9a-fA-F]{1,2}", s) else int(s) & 0xFF


def report_paths(room_id: int) -> tuple[Path, Path, Path, Path]:
    tag = f"room{room_id:02X}"
    return (
        REPORTS / f"{tag}_gen_capture.json",
        REPORTS / f"{tag}_nes_capture.json",
        REPORTS / f"{tag}_parity_report.txt",
        REPORTS / f"{tag}_parity_report.json",
    )


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"missing required input: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def parse_nes_to_gen_lut(path: Path) -> list[int]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.strip().startswith("nes_palette_to_genesis:"):
            start = i + 1
            break
    if start is None:
        raise ValueError("nes_palette_to_genesis label not found in src/nes_io.asm")

    values: list[int] = []
    for line in lines[start:]:
        s = line.strip()
        if not s:
            continue
        if s.endswith(":") and not s.startswith("dc.w"):
            break
        if "dc.w" not in s:
            continue
        code = s.split(";", 1)[0]
        for word in re.findall(r"\$([0-9A-Fa-f]{1,4})", code):
            values.append(int(word, 16))
            if len(values) == 64:
                return values

    if len(values) < 64:
        raise ValueError(f"nes_palette_to_genesis parse incomplete: got {len(values)} entries")
    return values[:64]


def expect_matrix(name: str, value: Any, rows: int, cols: int) -> list[list[int]]:
    if not isinstance(value, list) or len(value) != rows:
        raise ValueError(f"{name} must be {rows}x{cols}")
    out: list[list[int]] = []
    for r, row in enumerate(value):
        if not isinstance(row, list) or len(row) != cols:
            raise ValueError(f"{name}[{r}] must have {cols} columns")
        out.append([int(x) for x in row])
    return out


def maybe_matrix(value: Any, rows: int, cols: int) -> bool:
    if not isinstance(value, list) or len(value) != rows:
        return False
    for row in value:
        if not isinstance(row, list) or len(row) != cols:
            return False
    return True


def matrix_nonzero_count(value: Any) -> int:
    if not isinstance(value, list):
        return 0
    total = 0
    for row in value:
        if not isinstance(row, list):
            continue
        for x in row:
            try:
                if int(x) != 0:
                    total += 1
            except Exception:
                pass
    return total


def first_n(items: list[dict[str, int]], limit: int = 20) -> list[dict[str, int]]:
    return items[:limit]


def first_bad_tile_summary(
    stage1: list[dict[str, int]],
    playmap: list[dict[str, int]],
    transfer_stream_mismatch_count: int,
    ntcache: list[dict[str, int]],
    plane: list[dict[str, int]],
) -> dict[str, Any]:
    if stage1:
        m = stage1[0]
        return {
            "stage": "SOURCE_DECODE",
            "row": int(m.get("row", -1)),
            "col": int(m.get("col", -1)),
            "nes_value": int(m.get("nes_tile", -1)),
            "gen_value": int(m.get("source_tile", m.get("gen_tile", -1))),
        }
    if playmap:
        m = playmap[0]
        return {
            "stage": "PLAYMAP",
            "row": int(m.get("row", -1)),
            "col": int(m.get("col", -1)),
            "nes_value": int(m.get("nes_tile", -1)),
            "gen_value": int(m.get("source_tile", -1)),
        }
    if transfer_stream_mismatch_count > 0:
        return {
            "stage": "TRANSFER_PRODUCER",
            "row": -1,
            "col": -1,
            "nes_value": -1,
            "gen_value": -1,
        }
    if ntcache:
        m = ntcache[0]
        return {
            "stage": "TRANSFER_INTERPRETER",
            "row": int(m.get("row", -1)),
            "col": int(m.get("col", -1)),
            "nes_value": int(m.get("nes_tile", -1)),
            "gen_value": int(m.get("source_tile", -1)),
        }
    if plane:
        m = plane[0]
        return {
            "stage": "COMMIT",
            "row": int(m.get("row", -1)),
            "col": int(m.get("col", -1)),
            "nes_value": int(m.get("expected_idx", -1)),
            "gen_value": int(m.get("actual_idx", -1)),
        }
    return {"stage": "NONE", "row": -1, "col": -1, "nes_value": -1, "gen_value": -1}


def optional_screenshot_diff(gen_png: Path, nes_png: Path) -> dict[str, Any]:
    result: dict[str, Any] = {
        "available": False,
        "reason": "",
        "nonzero_pixels": None,
        "total_pixels": None,
        "ratio": None,
    }
    if not gen_png.exists() or not nes_png.exists():
        result["reason"] = "missing screenshot artifact(s)"
        return result

    try:
        from PIL import Image, ImageChops  # type: ignore
    except Exception:
        result["reason"] = "Pillow not installed"
        return result

    g = Image.open(gen_png).convert("RGB")
    n = Image.open(nes_png).convert("RGB")
    width = min(g.width, n.width, 256)
    height = min(g.height, n.height, 224)
    top = 48
    if height <= top:
        result["reason"] = "image height too small for BG crop"
        return result
    box = (0, top, width, height)
    gc = g.crop(box)
    nc = n.crop(box)
    diff = ImageChops.difference(gc, nc).convert("L")
    hist = diff.histogram()
    total = gc.width * gc.height
    nonzero = total - (hist[0] if hist else 0)
    ratio = (nonzero / total) if total else 0.0
    result.update(
        {
            "available": True,
            "reason": "",
            "nonzero_pixels": nonzero,
            "total_pixels": total,
            "ratio": ratio,
        }
    )
    return result


def expected_idx(raw_tile: int, bg_half: int) -> int:
    return (raw_tile & 0xFF) + (0x100 if bg_half else 0)


def compare_nes_to_plane(
    nes_tiles: list[list[int]],
    nes_pals: list[list[int]],
    plane_words: list[list[int]],
    nes_bg_half: int,
) -> tuple[list[dict[str, int]], list[dict[str, int]]]:
    tile_mismatches: list[dict[str, int]] = []
    pal_mismatches: list[dict[str, int]] = []
    for row in range(ROWS):
        for col in range(COLS):
            nes_tile = nes_tiles[row][col] & 0xFF
            want_idx = expected_idx(nes_tile, nes_bg_half) & 0x07FF
            want_pal = nes_pals[row][col] & 0x03

            word = plane_words[row][col] & 0xFFFF
            got_idx = word & 0x07FF
            got_pal = (word >> 13) & 0x03

            if got_idx != want_idx:
                tile_mismatches.append(
                    {
                        "row": row,
                        "col": col,
                        "expected_idx": want_idx,
                        "actual_idx": got_idx,
                        "nes_tile": nes_tile,
                    }
                )
            if got_pal != want_pal:
                pal_mismatches.append(
                    {
                        "row": row,
                        "col": col,
                        "expected_pal": want_pal,
                        "actual_pal": got_pal,
                        "gen_word": word,
                    }
                )
    return tile_mismatches, pal_mismatches


def compare_source_to_plane(
    source_tiles: list[list[int]],
    plane_words: list[list[int]],
    gen_bg_half: int,
) -> list[dict[str, int]]:
    mismatches: list[dict[str, int]] = []
    for row in range(ROWS):
        for col in range(COLS):
            src_tile = source_tiles[row][col] & 0xFF
            want_idx = expected_idx(src_tile, gen_bg_half) & 0x07FF
            got_idx = plane_words[row][col] & 0x07FF
            if got_idx != want_idx:
                mismatches.append(
                    {
                        "row": row,
                        "col": col,
                        "source_tile": src_tile,
                        "expected_idx": want_idx,
                        "actual_idx": got_idx,
                    }
                )
    return mismatches


def compare_nes_to_source(
    nes_tiles: list[list[int]],
    source_tiles: list[list[int]],
) -> list[dict[str, int]]:
    mismatches: list[dict[str, int]] = []
    for row in range(ROWS):
        for col in range(COLS):
            nes_tile = nes_tiles[row][col] & 0xFF
            src_tile = source_tiles[row][col] & 0xFF
            if src_tile != nes_tile:
                mismatches.append(
                    {
                        "row": row,
                        "col": col,
                        "nes_tile": nes_tile,
                        "source_tile": src_tile,
                    }
                )
    return mismatches


def compare_bg_palette(
    nes_palram: list[int],
    gen_cram: list[int],
    lut: list[int],
) -> list[dict[str, int]]:
    mismatches: list[dict[str, int]] = []
    for pal in range(4):
        for slot in range(4):
            nes_idx = pal * 4 + slot
            nes_color = nes_palram[nes_idx] & 0x3F
            expected = lut[nes_color] & 0x0FFF
            gen_cram_idx = pal * 16 + slot
            actual = gen_cram[gen_cram_idx] & 0x0FFF
            if actual != expected:
                mismatches.append(
                    {
                        "palette": pal,
                        "slot": slot,
                        "nes_color": nes_color,
                        "gen_cram_index": gen_cram_idx,
                        "expected_word": expected,
                        "actual_word": actual,
                    }
                )
    return mismatches


def find_alignment_offset(
    nes_tiles: list[list[int]],
    nes_pals: list[list[int]],
    plane_words: list[list[int]],
    nes_bg_half: int,
) -> dict[str, int | bool]:
    best = {"row_delta": 0, "col_delta": 0, "tile_mismatches": ROWS * COLS, "pal_mismatches": ROWS * COLS}
    for dr in range(-2, 3):
        for dc in range(-2, 3):
            tile_bad = 0
            pal_bad = 0
            for row in range(ROWS):
                for col in range(COLS):
                    rr = row + dr
                    cc = col + dc
                    if rr < 0 or rr >= ROWS or cc < 0 or cc >= COLS:
                        tile_bad += 1
                        pal_bad += 1
                        continue
                    want_idx = expected_idx(nes_tiles[rr][cc], nes_bg_half) & 0x07FF
                    want_pal = nes_pals[rr][cc] & 0x03
                    word = plane_words[row][col] & 0xFFFF
                    got_idx = word & 0x07FF
                    got_pal = (word >> 13) & 0x03
                    if got_idx != want_idx:
                        tile_bad += 1
                    if got_pal != want_pal:
                        pal_bad += 1
            if tile_bad + pal_bad < int(best["tile_mismatches"]) + int(best["pal_mismatches"]):
                best = {
                    "row_delta": dr,
                    "col_delta": dc,
                    "tile_mismatches": tile_bad,
                    "pal_mismatches": pal_bad,
                }
    best["perfect_nonzero_offset"] = (
        int(best["tile_mismatches"]) == 0
        and int(best["pal_mismatches"]) == 0
        and (int(best["row_delta"]) != 0 or int(best["col_delta"]) != 0)
    )
    return best


def compare_traces(gen: dict[str, Any], nes: dict[str, Any]) -> dict[str, Any]:
    gen_traces = {t.get("name", f"gen_{i}"): t for i, t in enumerate(gen.get("trace_snapshots", []))}
    nes_traces = {t.get("name", f"nes_{i}"): t for i, t in enumerate(nes.get("trace_snapshots", []))}
    common = sorted(set(gen_traces) & set(nes_traces))
    preferred = "layoutroomow_exit_snapshot"
    if preferred in common:
        compared = [preferred]
    else:
        compared = common

    ptr_mismatches = 0
    source_byte_mismatches = 0
    first_divergence: dict[str, Any] | None = None

    authoritative_diag: dict[str, Any] = {}

    for name in compared:
        gt = gen_traces[name]
        nt = nes_traces[name]
        # In P34 direct-pointer mode, authoritative source evidence is layout_bytes/column_bytes,
        # not NES-RAM ptr_inputs ($02/$03-style transport).
        if name == preferred:
            authoritative_diag = {
                "gen_room_attr_raw": int(gt.get("room_attr_raw", -1)),
                "gen_room_attr_masked": int(gt.get("room_attr_masked", -1)),
                "gen_layout_ptr_effective": int(gt.get("layout_ptr_effective", -1)),
                "nes_room_attr_raw": int(nt.get("room_attr_raw", -1)),
                "nes_room_attr_masked": int(nt.get("room_attr_masked", -1)),
                "nes_layout_ptr_effective": int(nt.get("layout_ptr_effective", -1)),
            }
            for field, kind in (("layout_bytes", "layout_byte"), ("column_bytes", "column_byte")):
                gb = [int(x) & 0xFF for x in gt.get(field, [])]
                nb = [int(x) & 0xFF for x in nt.get(field, [])]
                m = min(len(gb), len(nb))
                for i in range(m):
                    if gb[i] != nb[i]:
                        source_byte_mismatches += 1
                        if first_divergence is None:
                            first_divergence = {
                                "snapshot": name,
                                "kind": kind,
                                "field": field,
                                "index": i,
                                "gen_value": gb[i],
                                "nes_value": nb[i],
                            }
            # keep ptr mismatch as diagnostic only on authoritative snapshot
            gp = [int(x) & 0xFF for x in gt.get("ptr_inputs", [])]
            np = [int(x) & 0xFF for x in nt.get("ptr_inputs", [])]
            n = min(len(gp), len(np))
            for i in range(n):
                if gp[i] != np[i]:
                    ptr_mismatches += 1
            continue

        gp = [int(x) & 0xFF for x in gt.get("ptr_inputs", [])]
        np = [int(x) & 0xFF for x in nt.get("ptr_inputs", [])]
        n = min(len(gp), len(np))
        for i in range(n):
            if gp[i] != np[i]:
                ptr_mismatches += 1
                if first_divergence is None:
                    first_divergence = {
                        "snapshot": name,
                        "kind": "ptr_input",
                        "index": i,
                        "gen_value": gp[i],
                        "nes_value": np[i],
                    }

        gs = {s.get("label", f"g{i}"): s for i, s in enumerate(gt.get("source_samples", []))}
        ns = {s.get("label", f"n{i}"): s for i, s in enumerate(nt.get("source_samples", []))}
        for label in sorted(set(gs) & set(ns)):
            gbytes = [int(x) & 0xFF for x in gs[label].get("bytes", [])]
            nbytes = [int(x) & 0xFF for x in ns[label].get("bytes", [])]
            m = min(len(gbytes), len(nbytes))
            for i in range(m):
                if gbytes[i] != nbytes[i]:
                    source_byte_mismatches += 1
                    if first_divergence is None:
                        first_divergence = {
                            "snapshot": name,
                            "kind": "source_byte",
                            "label": label,
                            "index": i,
                            "gen_value": gbytes[i],
                            "nes_value": nbytes[i],
                        }

    return {
        "common_snapshots": common,
        "compared_snapshots": compared,
        "authoritative_snapshot": preferred if preferred in compared else "",
        "authoritative_diag": authoritative_diag,
        "ptr_mismatches": ptr_mismatches,
        "source_byte_mismatches": source_byte_mismatches,
        "first_divergence": first_divergence or {},
    }


def compare_decode_write_trace(gen: dict[str, Any], nes: dict[str, Any]) -> dict[str, Any]:
    gt = gen.get("decode_write_trace", [])
    nt = nes.get("decode_write_trace", [])
    if not isinstance(gt, list):
        gt = []
    if not isinstance(nt, list):
        nt = []

    fields = [
        "col",
        "row",
        "descriptor_raw",
        "repeat_flag",
        "square_index",
        "primary_tile",
        "ptr04_before",
        "ptr04_after",
        "ptr00_before",
        "ptr00_after",
    ]
    max_n = min(len(gt), len(nt))
    mismatch_count = 0
    first_div: dict[str, Any] = {}

    for i in range(max_n):
        g = gt[i] if isinstance(gt[i], dict) else {}
        n = nt[i] if isinstance(nt[i], dict) else {}
        entry_bad = False

        for f in fields:
            gv = int(g.get(f, -1))
            nv = int(n.get(f, -1))
            if gv != nv:
                entry_bad = True
                if not first_div:
                    first_div = {
                        "entry_index": i,
                        "field": f,
                        "gen_value": gv,
                        "nes_value": nv,
                    }
                break

        if not entry_bad:
            gseq = [int(x) & 0xFF for x in g.get("tile_write_seq", [])]
            nseq = [int(x) & 0xFF for x in n.get("tile_write_seq", [])]
            if gseq != nseq:
                entry_bad = True
                if not first_div:
                    first_div = {
                        "entry_index": i,
                        "field": "tile_write_seq",
                        "gen_value": gseq,
                        "nes_value": nseq,
                    }

        if entry_bad:
            mismatch_count += 1

    if len(gt) != len(nt):
        mismatch_count += abs(len(gt) - len(nt))
        if not first_div:
            first_div = {
                "entry_index": max_n,
                "field": "trace_length",
                "gen_value": len(gt),
                "nes_value": len(nt),
            }

    return {
        "gen_len": len(gt),
        "nes_len": len(nt),
        "mismatch_count": mismatch_count,
        "first_divergence": first_div,
    }


def _classify_rt_divergence(first_div: dict[str, Any]) -> str:
    field = str(first_div.get("field", ""))
    if field == "square_index":
        return "COLUMN_SCAN"
    if field == "addr":
        return "REPEAT_ADVANCE"
    if field == "value":
        return "WRITE_ORDER"
    return "UNKNOWN"


def compare_decode_write_trace_rt(gen: dict[str, Any], nes: dict[str, Any]) -> dict[str, Any]:
    gt = gen.get("decode_write_trace_rt", [])
    nt = nes.get("decode_write_trace_rt", [])
    if not isinstance(gt, list):
        gt = []
    if not isinstance(nt, list):
        nt = []

    max_n = min(len(gt), len(nt))
    mismatch_count = 0
    first_div: dict[str, Any] = {}

    def _ival(d: dict[str, Any], key: str, default: int = -1) -> int:
        return int(d.get(key, default))

    for i in range(max_n):
        g = gt[i] if isinstance(gt[i], dict) else {}
        n = nt[i] if isinstance(nt[i], dict) else {}

        # diff priority: addr -> value -> context
        ordered_fields = [
            "addr",
            "value",
            "square_index",
            "repeat_state",
            "ptr00_01",
            "ptr04_05",
            "room_attr_raw",
            "room_attr_masked",
            "mode",
            "submode",
        ]
        entry_bad = False
        for f in ordered_fields:
            gv = _ival(g, f)
            nv = _ival(n, f)
            if gv != nv:
                entry_bad = True
                if not first_div:
                    first_div = {
                        "seq": i + 1,
                        "field": f,
                        "gen_value": gv,
                        "nes_value": nv,
                    }
                break

        if entry_bad:
            mismatch_count += 1

    if len(gt) != len(nt):
        mismatch_count += abs(len(gt) - len(nt))
        if not first_div:
            first_div = {
                "seq": max_n + 1,
                "field": "trace_length",
                "gen_value": len(gt),
                "nes_value": len(nt),
            }

    return {
        "gen_len": len(gt),
        "nes_len": len(nt),
        "mismatch_count": mismatch_count,
        "first_divergence": first_div,
        "divergence_class": _classify_rt_divergence(first_div) if first_div else "UNKNOWN",
        "gen_valid": bool(gen.get("decode_write_trace_rt_valid", False)),
        "nes_valid": bool(nes.get("decode_write_trace_rt_valid", False)),
    }


def compare_transfer_streams(gen: dict[str, Any], nes: dict[str, Any]) -> dict[str, Any]:
    gt = gen.get("transfer_stream_events", gen.get("room_row_transfer_records", []))
    nt = nes.get("transfer_stream_events", nes.get("room_row_transfer_records", []))
    if not isinstance(gt, list):
        gt = []
    if not isinstance(nt, list):
        nt = []
    gen_valid = bool(gen.get("transfer_stream_capture_valid", len(gt) > 0))
    nes_valid = bool(nes.get("transfer_stream_capture_valid", len(nt) > 0))

    def _ival(d: dict[str, Any], key: str, default: int = -1) -> int:
        return int(d.get(key, default))

    max_n = min(len(gt), len(nt))
    mismatch_count = 0
    first_div: dict[str, Any] = {}

    for i in range(max_n):
        g = gt[i] if isinstance(gt[i], dict) else {}
        n = nt[i] if isinstance(nt[i], dict) else {}
        ordered_fields = [
            "dispatch_role",
            "tile_buf_selector",
            "source_kind",
        ]
        entry_bad = False
        for f in ordered_fields:
            if f in {"dispatch_role", "source_kind"}:
                gv = str(g.get(f, ""))
                nv = str(n.get(f, ""))
            else:
                gv = _ival(g, f)
                nv = _ival(n, f)
            if gv != nv:
                entry_bad = True
                if not first_div:
                    first_div = {
                        "event_index": i,
                        "field": f,
                        "gen_value": gv,
                        "nes_value": nv,
                    }
                break

        if not entry_bad:
            gbytes = [int(x) & 0xFF for x in g.get("raw_stream_bytes", g.get("bytes", []))]
            nbytes = [int(x) & 0xFF for x in n.get("raw_stream_bytes", n.get("bytes", []))]
            if gbytes != nbytes:
                entry_bad = True
                if not first_div:
                    first_div = {
                        "event_index": i,
                        "field": "raw_stream_bytes",
                        "gen_value": gbytes,
                        "nes_value": nbytes,
                    }

        if entry_bad:
            mismatch_count += 1

    if len(gt) != len(nt):
        mismatch_count += abs(len(gt) - len(nt))
        if not first_div:
            first_div = {
                "event_index": max_n,
                "field": "event_count",
                "gen_value": len(gt),
                "nes_value": len(nt),
            }

    return {
        "gen_len": len(gt),
        "nes_len": len(nt),
        "mismatch_count": mismatch_count,
        "first_divergence": first_div,
        "producer_match": gen_valid and nes_valid and mismatch_count == 0 and len(gt) == len(nt) and len(gt) > 0,
        "gen_valid": gen_valid,
        "nes_valid": nes_valid,
    }


def split_stage2_mismatches(items: list[dict[str, int]]) -> tuple[list[dict[str, int]], list[dict[str, int]]]:
    edge: list[dict[str, int]] = []
    interior: list[dict[str, int]] = []
    for item in items:
        col = int(item.get("col", -1))
        if col in (0, COLS - 1):
            edge.append(item)
        else:
            interior.append(item)
    return interior, edge


def transfer_edge_column_summary(events: list[dict[str, Any]]) -> dict[str, Any]:
    touched: set[int] = set()
    for event in events:
        if int(event.get("mode", -1)) not in (3, 4, 5):
            continue
        for rec in event.get("decoded_records", []):
            vram = int(rec.get("vram_addr", -1)) & 0x3FFF
            count = int(rec.get("count", 0))
            if count <= 0:
                continue
            vertical = int(rec.get("vertical_increment", 0)) != 0
            if 0x2000 <= vram < 0x23C0:
                base = 0x2000
            elif 0x2800 <= vram < 0x2BC0:
                base = 0x2800
            else:
                continue
            start = vram - base
            col = start & 0x1F
            if vertical:
                touched.add(col)
                continue
            for i in range(count):
                touched.add((col + i) & 0x1F)
    cols = sorted(touched)
    return {
        "edge_columns_touched": [c for c in cols if c in (0, COLS - 1)],
        "all_columns_touched": cols,
        "transfer_touches_edge_columns": any(c in (0, COLS - 1) for c in cols),
    }


def compare_edge_owner_traces(gen: dict[str, Any], nes: dict[str, Any]) -> dict[str, Any]:
    gt = gen.get("edge_owner_trace", [])
    nt = nes.get("edge_owner_trace", [])
    if not isinstance(gt, list):
        gt = []
    if not isinstance(nt, list):
        nt = []

    gen_valid = bool(gen.get("edge_owner_trace_valid", False))
    nes_valid = bool(nes.get("edge_owner_trace_valid", False))
    gen_classes = [str(x) for x in gen.get("edge_owner_writer_classes", []) if str(x)]
    nes_classes = [str(x) for x in nes.get("edge_owner_writer_classes", []) if str(x)]
    if not gen_classes:
        gen_classes = sorted({str(e.get("writer_class", "")) for e in gt if str(e.get("writer_class", ""))})
    if not nes_classes:
        nes_classes = sorted({str(e.get("writer_class", "")) for e in nt if str(e.get("writer_class", ""))})

    mismatch_count = 0
    first_div: dict[str, Any] = {}
    max_n = min(len(gt), len(nt))
    for i in range(max_n):
        g = gt[i] if isinstance(gt[i], dict) else {}
        n = nt[i] if isinstance(nt[i], dict) else {}
        for field in ("addr", "value", "writer_class"):
            gv = g.get(field, -1 if field != "writer_class" else "")
            nv = n.get(field, -1 if field != "writer_class" else "")
            if gv != nv:
                mismatch_count += 1
                if not first_div:
                    first_div = {
                        "entry_index": i,
                        "field": field,
                        "gen_value": gv,
                        "nes_value": nv,
                    }
                break

    if len(gt) != len(nt):
        mismatch_count += abs(len(gt) - len(nt))
        if not first_div:
            first_div = {
                "entry_index": max_n,
                "field": "event_count",
                "gen_value": len(gt),
                "nes_value": len(nt),
            }

    return {
        "gen_valid": gen_valid,
        "nes_valid": nes_valid,
        "gen_count": len(gt),
        "nes_count": len(nt),
        "mismatch_count": mismatch_count,
        "writer_classes_gen": gen_classes,
        "writer_classes_nes": nes_classes,
        "first_divergence": first_div,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--room-id", default="0x77")
    parser.add_argument(
        "--fixture-mode",
        choices=("auto", "steady_room", "transition_room"),
        default="auto",
    )
    args = parser.parse_args()

    room_id = parse_room_id(args.room_id)
    fixture_mode = args.fixture_mode
    if fixture_mode == "auto":
        fixture_mode = "transition_room" if room_id == 0x76 else "steady_room"
    gen_json, nes_json, out_txt, out_json = report_paths(room_id)

    gen = load_json(gen_json)
    nes = load_json(nes_json)
    lut = parse_nes_to_gen_lut(NES_IO_ASM)
    gen_target_reached = bool(gen.get("target_reached"))
    nes_target_reached = bool(nes.get("target_reached"))
    gen_room_id = int(gen.get("room_id", -1))
    nes_room_id = int(nes.get("room_id", -1))
    gen_final_mode = int(gen.get("final_mode", -1))
    nes_final_mode = int(nes.get("final_mode", -1))
    gen_final_submode = int(gen.get("final_submode", -1))
    nes_final_submode = int(nes.get("final_submode", -1))

    transition_settle_ok = True
    if fixture_mode == "transition_room":
        transition_settle_ok = (
            gen_target_reached
            and nes_target_reached
            and gen_room_id == room_id
            and nes_room_id == room_id
            and gen_final_mode == nes_final_mode
            and gen_final_submode == nes_final_submode
        )

    plane_words = expect_matrix("gen.plane_words", gen.get("plane_words"), ROWS, COLS)
    gen_ntcache_rows = expect_matrix("gen.nt_cache_rows", gen.get("nt_cache_rows"), ROWS, COLS)
    gen_sub8 = gen.get("mode3_sub8_workbuf_rows")
    nes_sub8 = nes.get("mode3_sub8_workbuf_rows")
    use_sub8 = (
        maybe_matrix(gen_sub8, ROWS, COLS)
        and maybe_matrix(nes_sub8, ROWS, COLS)
        and matrix_nonzero_count(gen_sub8) >= 32
        and matrix_nonzero_count(nes_sub8) >= 32
    )

    if use_sub8:
        gen_stage1_raw = gen_sub8
        nes_stage1_raw = nes_sub8
        gen_stage1_name = "gen.mode3_sub8_workbuf_rows"
        nes_stage1_name = "nes.mode3_sub8_workbuf_rows"
    else:
        gen_stage1_raw = gen.get("layoutroomow_exit_workbuf_rows")
        nes_stage1_raw = nes.get("layoutroomow_exit_workbuf_rows")
        gen_stage1_name = "gen.layoutroomow_exit_workbuf_rows"
        nes_stage1_name = "nes.layoutroomow_exit_workbuf_rows"
        if not maybe_matrix(gen_stage1_raw, ROWS, COLS):
            gen_stage1_raw = gen.get("workbuf_rows")
            gen_stage1_name = "gen.workbuf_rows"
        if not maybe_matrix(nes_stage1_raw, ROWS, COLS):
            nes_stage1_raw = nes.get("workbuf_rows")
            nes_stage1_name = "nes.workbuf_rows"

    gen_workbuf_rows = expect_matrix(gen_stage1_name, gen_stage1_raw, ROWS, COLS)
    nes_workbuf_rows = expect_matrix(nes_stage1_name, nes_stage1_raw, ROWS, COLS)
    gen_playmap_rows = expect_matrix("gen.playmap_rows", gen.get("playmap_rows"), ROWS, COLS)
    nes_playmap_rows = expect_matrix("nes.playmap_rows", nes.get("playmap_rows"), ROWS, COLS)
    nes_tiles = expect_matrix("nes.tile_rows", nes.get("tile_rows"), ROWS, COLS)
    nes_pals = expect_matrix("nes.palette_rows", nes.get("palette_rows"), ROWS, COLS)

    gen_cram = [int(x) for x in gen.get("cram_words", [])]
    nes_palram = [int(x) for x in nes.get("palram_bytes", [])]
    if len(gen_cram) < 64:
        raise ValueError("gen.cram_words must have at least 64 entries")
    if len(nes_palram) < 16:
        raise ValueError("nes.palram_bytes must have at least 16 entries")

    nes_bg_half = int(nes.get("bg_pattern_table_half", 1)) & 1
    gen_bg_half = int(gen.get("bg_pattern_table_half", 1)) & 1

    nes_plane_tile, nes_plane_pal = compare_nes_to_plane(nes_tiles, nes_pals, plane_words, nes_bg_half)
    ntcache_plane_tile = compare_source_to_plane(gen_ntcache_rows, plane_words, gen_bg_half)
    nes_ntcache_tile = compare_nes_to_source(nes_tiles, gen_ntcache_rows)
    nes_workbuf_tile = compare_nes_to_source(nes_tiles, gen_workbuf_rows)
    workbuf_ntcache_tile = compare_nes_to_source(gen_workbuf_rows, gen_ntcache_rows)
    nes_workbuf_capture_tile = compare_nes_to_source(nes_workbuf_rows, gen_workbuf_rows)
    nes_playmap_tile = compare_nes_to_source(nes_playmap_rows, gen_playmap_rows)
    nes_tile_to_playmap = compare_nes_to_source(nes_tiles, nes_playmap_rows)
    playmap_to_ntcache_tile = compare_nes_to_source(gen_playmap_rows, gen_ntcache_rows)
    bg_palette = compare_bg_palette(nes_palram, gen_cram, lut)

    alignment = find_alignment_offset(nes_tiles, nes_pals, plane_words, nes_bg_half)
    trace_summary = compare_traces(gen, nes)
    decode_trace = compare_decode_write_trace(gen, nes)
    decode_trace_rt = compare_decode_write_trace_rt(gen, nes)
    transfer_records = compare_transfer_streams(gen, nes)
    stage2_interior_tile, stage2_edge_tile = split_stage2_mismatches(nes_ntcache_tile)
    edge_summary = transfer_edge_column_summary(gen.get("transfer_stream_events", []))
    edge_owner = compare_edge_owner_traces(gen, nes)
    first_bad_tile = first_bad_tile_summary(
        nes_workbuf_capture_tile,
        nes_playmap_tile,
        int(transfer_records["mismatch_count"]),
        nes_ntcache_tile,
        nes_plane_tile,
    )

    screenshot_diag = optional_screenshot_diff(
        Path(gen.get("screenshot_path", "")),
        Path(nes.get("screenshot_path", "")),
    )

    hard_pass = (
        len(nes_plane_tile) == 0
        and len(nes_plane_pal) == 0
        and len(bg_palette) == 0
        and transition_settle_ok
    )

    if hard_pass:
        route_code = ROUTE_NONE
        route_detail = f"PARITY_GREEN: Room-${room_id:02X} BG tile/palette byte parity is green."
    elif fixture_mode == "transition_room" and not transition_settle_ok:
        route_code = ROUTE_TRANSITION_SETTLE
        route_detail = (
            "Transition fixture fail: Genesis does not settle to the same final transition state as NES. "
            f"GEN target_reached={gen_target_reached} room=${gen_room_id & 0xFF:02X} "
            f"mode/sub=${gen_final_mode & 0xFF:02X}/${gen_final_submode & 0xFF:02X}; "
            f"NES target_reached={nes_target_reached} room=${nes_room_id & 0xFF:02X} "
            f"mode/sub=${nes_final_mode & 0xFF:02X}/${nes_final_submode & 0xFF:02X}. "
            "Patch transition state/update path before tile-parity routing."
        )
    elif bool(alignment.get("perfect_nonzero_offset")):
        route_code = ROUTE_CAPTURE_ALIGNMENT
        route_detail = (
            f"Capture/comparator alignment issue: applying row_delta={alignment['row_delta']} "
            f"col_delta={alignment['col_delta']} eliminates byte mismatches."
        )
    elif (
        decode_trace_rt["gen_valid"]
        and decode_trace_rt["nes_valid"]
        and int(decode_trace_rt["mismatch_count"]) > 0
    ):
        route_code = ROUTE_LAYOUT_DECODE
        route_detail = (
            "Stage1 fail (runtime trace): NES->GEN workbuf write stream diverges. "
            f"class={decode_trace_rt.get('divergence_class', 'UNKNOWN')}."
        )
        if decode_trace_rt["first_divergence"]:
            d = decode_trace_rt["first_divergence"]
            route_detail += (
                f" First runtime divergence: seq={int(d.get('seq', -1))} "
                f"field={d.get('field', '')}."
            )
    elif len(nes_workbuf_capture_tile) > 0:
        route_code = ROUTE_LAYOUT_DECODE
        route_detail = "Stage1 fail: NES work buffer diverges from Genesis work buffer. Patch LayoutRoomOrCaveOW decode/write path."
        if decode_trace["first_divergence"]:
            d = decode_trace["first_divergence"]
            route_detail += (
                f" First decode-trace divergence: entry={int(d.get('entry_index', -1))} "
                f"field={d.get('field', '')}."
            )
    elif not transfer_records["gen_valid"] or not transfer_records["nes_valid"]:
        route_code = ROUTE_TRANSFER_CAPTURE_INVALID
        route_detail = (
            "Transfer capture invalid: expected non-zero consumed transfer events on both sides. "
            "Fix hook/core/capture plumbing before assigning producer or interpreter ownership."
        )
    elif not transfer_records["producer_match"]:
        route_code = ROUTE_TRANSFER_PRODUCER
        route_detail = (
            "Transfer producer mismatch: consumed transfer streams diverge before the shared interpreter. "
            "Patch producer/dispatch path."
        )
        if transfer_records["first_divergence"]:
            d = transfer_records["first_divergence"]
            route_detail += (
                f" First transfer divergence: event={int(d.get('event_index', -1))} "
                f"field={d.get('field', '')}."
            )
    elif len(stage2_interior_tile) > 0:
        route_code = ROUTE_TRANSFER_INTERPRETER
        route_detail = (
            "Stage2 interior fail with matching consumed transfer streams. "
            "Patch shared transfer interpreter / NT-cache population path."
        )
    elif len(stage2_edge_tile) > 0:
        edge_valid = bool(edge_owner["gen_valid"]) and bool(edge_owner["nes_valid"])
        if edge_valid and int(edge_owner["gen_count"]) == 0 and int(edge_owner["nes_count"]) == 0:
            route_code = ROUTE_EDGE_WINDOW_CONTRACT
            route_detail = (
                "Edge traces valid on both sides, but neither side writes room edge set during room-load window. "
                "Treat remaining edge mismatch as capture/window contract issue until proven otherwise."
            )
        elif edge_valid and int(edge_owner["nes_count"]) > 0 and int(edge_owner["gen_count"]) == 0:
            route_code = ROUTE_EDGE_SEED_MISSING
            route_detail = (
                "NES writes room edge set during room-load window, but Genesis does not. "
                "Patch missing external edge seed path, not room transfer interpreter."
            )
        elif edge_valid:
            route_code = ROUTE_EDGE_RUNTIME_DIVERGENCE
            route_detail = (
                "Edge traces present on both sides and diverge in count/order/value. "
                "Patch exact shared runtime edge writer or direct seed path."
            )
            if edge_owner["first_divergence"]:
                d = edge_owner["first_divergence"]
                route_detail += (
                    f" First edge divergence: entry={int(d.get('entry_index', -1))} "
                    f"field={d.get('field', '')}."
                )
        elif not bool(edge_summary["transfer_touches_edge_columns"]):
            route_code = ROUTE_EDGE_OWNERSHIP_EXTERNAL
            route_detail = (
                "Only edge-column Stage2 mismatches remain, and consumed room transfers do not touch "
                "edge columns 0/31. Treat edge ownership as external to room transfer interpreter."
            )
        else:
            route_code = ROUTE_TRANSFER_INTERPRETER_EDGE
            route_detail = (
                "Only edge-column Stage2 mismatches remain, and consumed room transfers do touch "
                "edge columns 0/31. Patch shared interpreter edge-column application."
            )
    elif trace_summary["source_byte_mismatches"] > 0:
        route_code = ROUTE_LAYOUT_SOURCE
        route_detail = (
            "Layout/column source bytes diverge in snapshot diagnostics, but only after stage1/transfer ownership "
            "checks. Treat this as secondary evidence unless stage1 regresses."
        )
    elif len(ntcache_plane_tile) > 0:
        route_code = ROUTE_TRANSFER_PATH
        route_detail = "Stage3 fail: Genesis NT cache diverges from Plane A. Patch renderer/composition path."
    else:
        route_code = ROUTE_LAYOUT_DECODE
        route_detail = (
            "Fallback decode route: PlaneA differs without source/transfer mismatch signal. "
            "Re-check decode assumptions with trace snapshots."
        )

    txt_lines: list[str] = []
    txt_lines.append(f"ROOM ${room_id:02X} PARITY REPORT")
    txt_lines.append("=" * 72)
    txt_lines.append(f"fixture_mode: {fixture_mode}")
    txt_lines.append(f"gen target_reached: {gen.get('target_reached')} room_id: ${int(gen.get('room_id', 0)):02X}")
    txt_lines.append(f"nes target_reached: {nes.get('target_reached')} room_id: ${int(nes.get('room_id', 0)):02X}")
    txt_lines.append(f"gen final_mode/submode: ${gen_final_mode & 0xFF:02X}/${gen_final_submode & 0xFF:02X}")
    txt_lines.append(f"nes final_mode/submode: ${nes_final_mode & 0xFF:02X}/${nes_final_submode & 0xFF:02X}")
    txt_lines.append(f"transition_settle_ok: {transition_settle_ok}")
    txt_lines.append("")
    txt_lines.append(f"nes_to_gen_plane_tile_mismatches: {len(nes_plane_tile)}")
    txt_lines.append(f"nes_to_gen_plane_palette_mismatches: {len(nes_plane_pal)}")
    txt_lines.append(f"stage1_nes_workbuf_to_gen_workbuf_tile_mismatches: {len(nes_workbuf_capture_tile)}")
    txt_lines.append(f"stage2_nes_visible_to_gen_ntcache_tile_mismatches: {len(nes_ntcache_tile)}")
    txt_lines.append(f"stage2_interior_tile_mismatches: {len(stage2_interior_tile)}")
    txt_lines.append(f"stage2_edge_tile_mismatches: {len(stage2_edge_tile)}")
    txt_lines.append(f"stage3_gen_ntcache_to_plane_tile_mismatches: {len(ntcache_plane_tile)}")
    txt_lines.append(f"nes_visible_to_gen_workbuf_tile_mismatches: {len(nes_workbuf_tile)}")
    txt_lines.append(f"nes_workbuf_to_gen_workbuf_tile_mismatches: {len(nes_workbuf_capture_tile)}")
    txt_lines.append(f"nes_to_gen_ntcache_tile_mismatches: {len(nes_ntcache_tile)}")
    txt_lines.append(f"nes_to_gen_playmap_tile_mismatches: {len(nes_playmap_tile)}")
    txt_lines.append(f"nes_tile_to_nes_playmap_mismatches: {len(nes_tile_to_playmap)}")
    txt_lines.append(f"gen_playmap_to_ntcache_tile_mismatches: {len(playmap_to_ntcache_tile)}")
    txt_lines.append(f"bg_palette_mismatches: {len(bg_palette)}")
    txt_lines.append("")
    txt_lines.append(f"trace_ptr_mismatches: {int(trace_summary['ptr_mismatches'])}")
    txt_lines.append(f"trace_source_byte_mismatches: {int(trace_summary['source_byte_mismatches'])}")
    txt_lines.append(f"stage1_decode_trace_gen_len: {int(decode_trace['gen_len'])}")
    txt_lines.append(f"stage1_decode_trace_nes_len: {int(decode_trace['nes_len'])}")
    txt_lines.append(f"stage1_trace_mismatch_count: {int(decode_trace['mismatch_count'])}")
    txt_lines.append(f"stage1_rt_trace_gen_len: {int(decode_trace_rt['gen_len'])}")
    txt_lines.append(f"stage1_rt_trace_nes_len: {int(decode_trace_rt['nes_len'])}")
    txt_lines.append(f"stage1_rt_trace_mismatch_count: {int(decode_trace_rt['mismatch_count'])}")
    txt_lines.append(f"stage1_rt_trace_gen_valid: {bool(decode_trace_rt['gen_valid'])}")
    txt_lines.append(f"stage1_rt_trace_nes_valid: {bool(decode_trace_rt['nes_valid'])}")
    txt_lines.append(f"stage1_rt_divergence_class: {decode_trace_rt.get('divergence_class', 'UNKNOWN')}")
    txt_lines.append(f"transfer_event_gen_len: {int(transfer_records['gen_len'])}")
    txt_lines.append(f"transfer_event_nes_len: {int(transfer_records['nes_len'])}")
    txt_lines.append(f"transfer_capture_gen_valid: {bool(transfer_records['gen_valid'])}")
    txt_lines.append(f"transfer_capture_nes_valid: {bool(transfer_records['nes_valid'])}")
    txt_lines.append(f"transfer_stream_mismatch_count: {int(transfer_records['mismatch_count'])}")
    txt_lines.append(f"transfer_producer_match: {bool(transfer_records['producer_match'])}")
    txt_lines.append(f"transfer_touches_edge_columns: {bool(edge_summary['transfer_touches_edge_columns'])}")
    txt_lines.append(f"edge_columns_touched: {edge_summary['edge_columns_touched']}")
    txt_lines.append(f"first_bad_tile: {json.dumps(first_bad_tile)}")
    txt_lines.append(f"edge_owner_gen_count: {int(edge_owner['gen_count'])}")
    txt_lines.append(f"edge_owner_nes_count: {int(edge_owner['nes_count'])}")
    txt_lines.append(f"edge_owner_mismatch_count: {int(edge_owner['mismatch_count'])}")
    txt_lines.append(f"edge_owner_writer_classes_gen: {edge_owner['writer_classes_gen']}")
    txt_lines.append(f"edge_owner_writer_classes_nes: {edge_owner['writer_classes_nes']}")
    txt_lines.append(f"stage1_matrix_gen: {gen_stage1_name}")
    txt_lines.append(f"stage1_matrix_nes: {nes_stage1_name}")
    txt_lines.append(f"trace_common_snapshots: {', '.join(trace_summary['common_snapshots']) if trace_summary['common_snapshots'] else '(none)'}")
    txt_lines.append(f"trace_compared_snapshots: {', '.join(trace_summary['compared_snapshots']) if trace_summary['compared_snapshots'] else '(none)'}")
    if trace_summary["authoritative_snapshot"]:
        txt_lines.append(f"trace_authoritative_snapshot: {trace_summary['authoritative_snapshot']}")
    if trace_summary.get("authoritative_diag"):
        ad = trace_summary["authoritative_diag"]
        txt_lines.append(
            "trace_authoritative_diag: "
            f"gen(raw=${int(ad.get('gen_room_attr_raw', -1)) & 0xFF:02X}, "
            f"mask=${int(ad.get('gen_room_attr_masked', -1)) & 0xFF:02X}, "
            f"layout_ptr=${int(ad.get('gen_layout_ptr_effective', -1)) & 0xFFFFFFFF:08X}) "
            f"nes(raw=${int(ad.get('nes_room_attr_raw', -1)) & 0xFF:02X}, "
            f"mask=${int(ad.get('nes_room_attr_masked', -1)) & 0xFF:02X}, "
            f"layout_ptr=${int(ad.get('nes_layout_ptr_effective', -1)) & 0xFFFFFFFF:08X})"
        )
    if trace_summary["first_divergence"]:
        txt_lines.append(f"trace_first_divergence: {json.dumps(trace_summary['first_divergence'])}")
    if decode_trace["first_divergence"]:
        txt_lines.append(f"stage1_first_trace_divergence: {json.dumps(decode_trace['first_divergence'])}")
    if decode_trace_rt["first_divergence"]:
        txt_lines.append(f"stage1_rt_first_trace_divergence: {json.dumps(decode_trace_rt['first_divergence'])}")
    if transfer_records["first_divergence"]:
        txt_lines.append(f"transfer_first_divergence: {json.dumps(transfer_records['first_divergence'])}")
    if edge_owner["first_divergence"]:
        txt_lines.append(f"edge_owner_first_divergence: {json.dumps(edge_owner['first_divergence'])}")
    txt_lines.append("")

    if nes_plane_tile:
        txt_lines.append("First NES->Plane tile mismatches:")
        for m in first_n(nes_plane_tile):
            txt_lines.append(
                f"  row{m['row']:02d} col{m['col']:02d} expected_idx=${m['expected_idx']:03X} "
                f"actual_idx=${m['actual_idx']:03X} nes_tile=${m['nes_tile']:02X}"
            )
        txt_lines.append("")

    if nes_plane_pal:
        txt_lines.append("First NES->Plane palette mismatches:")
        for m in first_n(nes_plane_pal):
            txt_lines.append(
                f"  row{m['row']:02d} col{m['col']:02d} expected_pal={m['expected_pal']} "
                f"actual_pal={m['actual_pal']} gen_word=${m['gen_word']:04X}"
            )
        txt_lines.append("")

    if ntcache_plane_tile:
        txt_lines.append("First NT cache->Plane tile mismatches:")
        for m in first_n(ntcache_plane_tile):
            txt_lines.append(
                f"  row{m['row']:02d} col{m['col']:02d} source_tile=${m['source_tile']:02X} "
                f"expected_idx=${m['expected_idx']:03X} actual_idx=${m['actual_idx']:03X}"
            )
        txt_lines.append("")

    if nes_workbuf_capture_tile:
        txt_lines.append("First NES workbuf->GEN workbuf tile mismatches:")
        for m in first_n(nes_workbuf_capture_tile):
            txt_lines.append(
                f"  row{m['row']:02d} col{m['col']:02d} nes_workbuf_tile=${m['nes_tile']:02X} "
                f"gen_workbuf_tile=${m['source_tile']:02X}"
            )
        txt_lines.append("")

    if nes_workbuf_tile:
        txt_lines.append("First NES visible->GEN workbuf tile mismatches:")
        for m in first_n(nes_workbuf_tile):
            txt_lines.append(
                f"  row{m['row']:02d} col{m['col']:02d} nes_tile=${m['nes_tile']:02X} "
                f"gen_workbuf_tile=${m['source_tile']:02X}"
            )
        txt_lines.append("")

    if workbuf_ntcache_tile:
        txt_lines.append("First workbuf->NT cache tile mismatches:")
        for m in first_n(workbuf_ntcache_tile):
            txt_lines.append(
                f"  row{m['row']:02d} col{m['col']:02d} workbuf_tile=${m['nes_tile']:02X} "
                f"nt_cache_tile=${m['source_tile']:02X}"
            )
        txt_lines.append("")

    if nes_playmap_tile:
        txt_lines.append("First NES->playmap tile mismatches:")
        for m in first_n(nes_playmap_tile):
            txt_lines.append(
                f"  row{m['row']:02d} col{m['col']:02d} nes_tile=${m['nes_tile']:02X} "
                f"playmap_tile=${m['source_tile']:02X}"
            )
        txt_lines.append("")

    if bg_palette:
        txt_lines.append("First BG palette mismatches:")
        for m in first_n(bg_palette):
            txt_lines.append(
                f"  pal{m['palette']} slot{m['slot']} nes=${m['nes_color']:02X} "
                f"expected=${m['expected_word']:04X} actual=${m['actual_word']:04X} "
                f"(CRAM[{m['gen_cram_index']}])"
            )
        txt_lines.append("")

    txt_lines.append(
        f"alignment_best_offset: row_delta={alignment['row_delta']} col_delta={alignment['col_delta']} "
        f"tile_mismatches={alignment['tile_mismatches']} pal_mismatches={alignment['pal_mismatches']}"
    )
    if screenshot_diag["available"]:
        txt_lines.append(
            "screenshot_diff_diag: "
            f"{screenshot_diag['nonzero_pixels']}/{screenshot_diag['total_pixels']} "
            f"({(screenshot_diag['ratio'] or 0.0) * 100.0:.2f}%) non-zero BG-crop pixels"
        )
    else:
        txt_lines.append(f"screenshot_diff_diag: skipped ({screenshot_diag['reason']})")
    txt_lines.append("")
    txt_lines.append(f"route_code: {route_code}")
    txt_lines.append(f"route_detail: {route_detail}")
    txt_lines.append("")
    txt_lines.append(f"ROOM{room_id:02X}_PARITY: ALL PASS" if hard_pass else f"ROOM{room_id:02X}_PARITY: FAIL")

    out_txt.write_text("\n".join(txt_lines) + "\n", encoding="utf-8")

    payload = {
        "hard_pass": hard_pass,
        "route_code": route_code,
        "route_detail": route_detail,
        "fixture_mode": fixture_mode,
        "transition_settle_ok": transition_settle_ok,
        "first_bad_tile": first_bad_tile,
        "counts": {
            "nes_to_gen_plane_tile_mismatches": len(nes_plane_tile),
            "nes_to_gen_plane_palette_mismatches": len(nes_plane_pal),
            "stage1_nes_workbuf_to_gen_workbuf_tile_mismatches": len(nes_workbuf_capture_tile),
            "stage2_nes_visible_to_gen_ntcache_tile_mismatches": len(nes_ntcache_tile),
            "stage2_interior_tile_mismatches": len(stage2_interior_tile),
            "stage2_edge_tile_mismatches": len(stage2_edge_tile),
            "stage3_gen_ntcache_to_plane_tile_mismatches": len(ntcache_plane_tile),
            "nes_visible_to_gen_workbuf_tile_mismatches": len(nes_workbuf_tile),
            "nes_workbuf_to_gen_workbuf_tile_mismatches": len(nes_workbuf_capture_tile),
            "nes_to_gen_ntcache_tile_mismatches": len(nes_ntcache_tile),
            "nes_to_gen_playmap_tile_mismatches": len(nes_playmap_tile),
            "nes_tile_to_nes_playmap_mismatches": len(nes_tile_to_playmap),
            "gen_playmap_to_ntcache_tile_mismatches": len(playmap_to_ntcache_tile),
            "bg_palette_mismatches": len(bg_palette),
            "trace_ptr_mismatches": int(trace_summary["ptr_mismatches"]),
            "trace_source_byte_mismatches": int(trace_summary["source_byte_mismatches"]),
            "stage1_trace_mismatch_count": int(decode_trace["mismatch_count"]),
            "stage1_rt_trace_mismatch_count": int(decode_trace_rt["mismatch_count"]),
            "transfer_stream_mismatch_count": int(transfer_records["mismatch_count"]),
            "transfer_touches_edge_columns": bool(edge_summary["transfer_touches_edge_columns"]),
            "edge_owner_gen_count": int(edge_owner["gen_count"]),
            "edge_owner_nes_count": int(edge_owner["nes_count"]),
            "edge_owner_mismatch_count": int(edge_owner["mismatch_count"]),
        },
        "samples": {
            "nes_to_gen_plane_tile_mismatches": first_n(nes_plane_tile),
            "nes_to_gen_plane_palette_mismatches": first_n(nes_plane_pal),
            "stage1_nes_workbuf_to_gen_workbuf_tile_mismatches": first_n(nes_workbuf_capture_tile),
            "stage2_nes_visible_to_gen_ntcache_tile_mismatches": first_n(nes_ntcache_tile),
            "stage2_interior_tile_mismatches": first_n(stage2_interior_tile),
            "stage2_edge_tile_mismatches": first_n(stage2_edge_tile),
            "stage3_gen_ntcache_to_plane_tile_mismatches": first_n(ntcache_plane_tile),
            "nes_visible_to_gen_workbuf_tile_mismatches": first_n(nes_workbuf_tile),
            "nes_workbuf_to_gen_workbuf_tile_mismatches": first_n(nes_workbuf_capture_tile),
            "nes_to_gen_ntcache_tile_mismatches": first_n(nes_ntcache_tile),
            "nes_to_gen_playmap_tile_mismatches": first_n(nes_playmap_tile),
            "gen_playmap_to_ntcache_tile_mismatches": first_n(playmap_to_ntcache_tile),
            "bg_palette_mismatches": first_n(bg_palette),
        },
        "alignment": alignment,
        "trace_summary": trace_summary,
        "decode_write_trace_summary": decode_trace,
        "decode_write_trace_rt_summary": decode_trace_rt,
        "transfer_stream_summary": transfer_records,
        "edge_transfer_summary": edge_summary,
        "edge_owner_summary": edge_owner,
        "stage1_matrices": {
            "gen": gen_stage1_name,
            "nes": nes_stage1_name,
        },
        "screenshot_diff_diag": screenshot_diag,
        "inputs": {
            "gen_json": str(gen_json),
            "nes_json": str(nes_json),
            "nes_io_asm": str(NES_IO_ASM),
        },
    }
    out_json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    print(out_txt.read_text(encoding="utf-8"), end="")
    return 0 if hard_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
