#!/usr/bin/env python3
"""
cycle_profile_report.py — summarize a CSV produced by cycle_probe.lua.

Usage:
  python tools/cycle_profile_report.py builds/reports/cycle_profile_73.csv

Important measurement caveats:
  - BizHawk's Genesis Plus GX core does not implement TotalExecutedCycles().
  - Per-bucket cycles are ESTIMATES: static_insts × 8 × calls.
    (M68K mean ~8 cyc/inst; highly approximate for memory-heavy code.)
  - tick_cyc is DERIVED: emu_frames_in_tick × 127,841 cyc (60 Hz NTSC
    frame budget). Resolution is ±1 emu frame = ±127K cyc per tick.
  - Static instr count is the function body only — does NOT include
    called sub-functions (exclusive, not inclusive).
  - Logical FPS is real (measured from FrameCounter advance vs emu frames).
"""

import csv
import sys
from collections import defaultdict
from pathlib import Path

CLOCK_HZ = 7_670_454
TARGET_FPS = 60
CYCLES_PER_EMU_FRAME = CLOCK_HZ // TARGET_FPS

TREE = [
    ("VBlankISR", 0),
    ("_oam_dma_flush",       1),
    ("_ags_prearm",          1),
    ("IsrNmi",               1),
    ("TransferCurTileBuf",   2),
    ("DriveAudio",           2),
    ("UpdateMode",           2),
    ("UpdatePlayer",         3),
    ("UpdateObject",         3),
    ("UpdateMoblin",         4),
    ("UpdateArrowOrBoomerang", 4),
    ("Walker_Move",          5),
    ("MoveObject",           6),
    ("AddQSpeedToPositionFraction", 7),
    ("SubQSpeedFromPositionFraction", 7),
    ("Walker_CheckTileCollision", 5),
    ("GetCollidableTile",    6),
    ("TryNextDir",           5),
    ("AnimateAndDrawObjectWalking", 3),
    ("CheckMonsterCollisions", 3),
    ("music_tick",           1),
    ("_ags_flush",           1),
]


def load_csv(path):
    tick_cycs = {}
    tick_emu_frames = {}
    per_bucket = defaultdict(
        lambda: {"calls": 0, "total": 0, "est_per_call": 0,
                 "ticks_present": 0})

    with open(path, newline="", encoding="utf-8") as fh:
        # Skip leading comment lines (produced by cycle_probe.lua header).
        header_lines = []
        pos = 0
        while True:
            pos = fh.tell()
            line = fh.readline()
            if not line:
                break
            if line.startswith("#"):
                header_lines.append(line.rstrip())
                continue
            fh.seek(pos)
            break
        for line in header_lines:
            print(line)
        rd = csv.DictReader(fh)
        for row in rd:
            tick = int(row["tick"])
            name = row["bucket"]
            calls = int(row["calls"])
            total = int(row["total_cyc"])
            per_call = int(row["max_cyc"])  # repurposed: est per call
            tc    = int(row["tick_cyc"])

            if name == "_tick":
                tick_cycs[tick] = tc
                tick_emu_frames[tick] = calls  # we packed emu_frames into calls
                continue

            per_bucket[name]["calls"] += calls
            per_bucket[name]["total"] += total
            per_bucket[name]["est_per_call"] = per_call
            per_bucket[name]["ticks_present"] += 1

    return tick_cycs, tick_emu_frames, per_bucket


def fmt_cyc(n):
    return f"{n:>7,}".replace(",", "_")


def fmt_pct(x):
    return f"{x:>5.1f}%"


def main():
    if len(sys.argv) < 2:
        print("usage: cycle_profile_report.py <csv>", file=sys.stderr)
        sys.exit(1)
    path = Path(sys.argv[1])
    if not path.exists():
        print(f"error: {path} not found", file=sys.stderr)
        sys.exit(1)

    tick_cycs, tick_emu_frames, per_bucket = load_csv(path)
    n_ticks = len(tick_cycs)
    if n_ticks == 0:
        print("no ticks in CSV")
        sys.exit(1)

    total_cyc = sum(tick_cycs.values())
    total_emu_frames = sum(tick_emu_frames.values())
    mean_tick = total_cyc // n_ticks
    max_tick = max(tick_cycs.values())

    # Logical fps from actual (emu_frames / ticks) ratio — not from mean_tick
    # because that can be biased if ticks happen in non-integer emu frames.
    emu_per_tick = total_emu_frames / n_ticks if n_ticks > 0 else 0
    logical_fps = TARGET_FPS / emu_per_tick if emu_per_tick > 0 else 0

    print(f"=== cycle profile: {path.name} ===")
    print(f"ticks captured:         {n_ticks}")
    print(f"emu frames observed:    {total_emu_frames}")
    print(f"emu frames per tick:    {emu_per_tick:.3f}")
    print(f"logical fps:            {logical_fps:.2f}")
    print(f"mean cyc/tick (proxy):  {mean_tick:,}")
    print(f"max  cyc/tick (proxy):  {max_tick:,}  (±127K resolution)")
    print(f"60fps budget:           {CYCLES_PER_EMU_FRAME:,} cyc/frame")
    print(f"budget overrun:         {(mean_tick - CYCLES_PER_EMU_FRAME):,} "
          f"cyc/tick ({(mean_tick / CYCLES_PER_EMU_FRAME - 1) * 100:.1f}%)")
    print()
    print("Per-bucket (estimates: calls × static_insts × 8 cyc/inst)")
    print("Static instr count is EXCLUSIVE (body only, not callees).")
    print()

    width = 36
    print(f"{'Bucket':<{width}} {'calls/tick':>10}  {'est/call':>9}  "
          f"{'est mean/tick':>13}  {'%tick':>6}")
    print("-" * (width + 52))

    shown = set()

    def emit(label, data):
        mean = data["total"] // n_ticks
        pct = (mean / mean_tick * 100) if mean_tick > 0 else 0
        calls_per = data["calls"] / n_ticks
        print(f"{label:<{width}} {calls_per:>10.2f}  "
              f"{fmt_cyc(data['est_per_call']):>9}  "
              f"{fmt_cyc(mean):>13}  {fmt_pct(pct):>6}")

    for name, depth in TREE:
        if name not in per_bucket:
            continue
        emit(("  " * depth) + name, per_bucket[name])
        shown.add(name)

    for name, data in per_bucket.items():
        if name not in shown:
            emit(name, data)

    # Sum of instrumented estimates vs measured tick total.
    instrumented = sum(d["total"] // n_ticks for d in per_bucket.values())
    print()
    print(f"Sum of bucket estimates:  {fmt_cyc(instrumented):>13}  "
          f"{fmt_pct(instrumented / mean_tick * 100)}")
    print(f"Un-instrumented gap:      "
          f"{fmt_cyc(mean_tick - instrumented):>13}  "
          f"{fmt_pct((mean_tick - instrumented) / mean_tick * 100)}")
    print()
    print("NB: bucket estimates are EXCLUSIVE (function body only). For "
          "e.g. UpdateObject, the estimate excludes MoveObject's cost — "
          "which is its own bucket. For un-hooked callees (e.g. walker_* "
          "helpers), their cost appears in the 'Un-instrumented gap'.")


if __name__ == "__main__":
    main()
