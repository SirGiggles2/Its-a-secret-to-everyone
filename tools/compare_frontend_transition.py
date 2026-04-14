#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / "builds" / "reports"
GEN_JSON = REPORTS / "frontend_transition_gen_capture.json"
NES_JSON = REPORTS / "frontend_transition_nes_capture.json"
OUT_TXT = REPORTS / "frontend_transition_report.txt"
OUT_JSON = REPORTS / "frontend_transition_report.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def compare_streams(gen: dict, nes: dict) -> tuple[int, dict | None]:
    gt = gen.get("transfer_stream_events", [])
    nt = nes.get("transfer_stream_events", [])
    max_n = min(len(gt), len(nt))
    for i in range(max_n):
        g = gt[i]
        n = nt[i]
        for field in ("mode", "submode", "tile_buf_selector", "source_kind", "raw_stream_bytes"):
            if g.get(field) != n.get(field):
                return abs(len(gt) - len(nt)) + 1, {
                    "event_index": i,
                    "field": field,
                    "gen_value": g.get(field),
                    "nes_value": n.get(field),
                }
    if len(gt) != len(nt):
        return abs(len(gt) - len(nt)), {
            "event_index": max_n,
            "field": "event_count",
            "gen_value": len(gt),
            "nes_value": len(nt),
        }
    return 0, None


def has_mode1_dyn(events: list[dict]) -> bool:
    for e in events:
        if int(e.get("mode", -1)) == 1 and str(e.get("source_kind", "")) == "dyn":
            raw = [int(x) & 0xFF for x in e.get("raw_stream_bytes", [])]
            if raw and raw[0] != 0xFF:
                return True
    return False


def main() -> int:
    gen = load(GEN_JSON)
    nes = load(NES_JSON)
    mm_count, first_div = compare_streams(gen, nes)
    gen_mode1_dyn = has_mode1_dyn(gen.get("transfer_stream_events", []))
    nes_mode1_dyn = has_mode1_dyn(nes.get("transfer_stream_events", []))
    hard_pass = (
        bool(gen.get("transfer_stream_capture_valid"))
        and bool(nes.get("transfer_stream_capture_valid"))
        and mm_count == 0
        and gen_mode1_dyn == nes_mode1_dyn
    )

    lines = []
    lines.append("FRONTEND TRANSITION REPORT")
    lines.append("=" * 72)
    lines.append(f"gen_target_reached: {gen.get('target_reached')}")
    lines.append(f"nes_target_reached: {nes.get('target_reached')}")
    lines.append(f"gen_transfer_events: {len(gen.get('transfer_stream_events', []))}")
    lines.append(f"nes_transfer_events: {len(nes.get('transfer_stream_events', []))}")
    lines.append(f"transfer_stream_mismatch_count: {mm_count}")
    lines.append(f"gen_mode1_dyn_present: {gen_mode1_dyn}")
    lines.append(f"nes_mode1_dyn_present: {nes_mode1_dyn}")
    if first_div:
        lines.append(f"first_divergence: {json.dumps(first_div)}")
    lines.append("")
    lines.append("FRONTEND_TRANSITION: ALL PASS" if hard_pass else "FRONTEND_TRANSITION: FAIL")
    OUT_TXT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    OUT_JSON.write_text(
        json.dumps(
            {
                "hard_pass": hard_pass,
                "transfer_stream_mismatch_count": mm_count,
                "first_divergence": first_div,
                "gen_mode1_dyn_present": gen_mode1_dyn,
                "nes_mode1_dyn_present": nes_mode1_dyn,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(OUT_TXT.read_text(encoding="utf-8"), end="")
    return 0 if hard_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
