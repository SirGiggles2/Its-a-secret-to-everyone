"""Lag scan of lockstep frame dumps: video frames per game tick, NES vs Genesis.

    python tools/lockstep/lag_scan.py [preset ...] [--md OUT]

Needs runs made with `run_lockstep.py <preset> --full --frame-dump`
(builds/reports/lockstep/<preset>/{nes,gen}.{fram,frtick}: 2 KB NES RAM and
the game tick of every video frame). Ticks are aligned across the two
consoles (the lockstep script runs per tick), so the number of video frames
each console spends on tick T is a direct speed comparison: Genesis frames
> NES frames on a tick = the Genesis was slower there.

User rule (2026-09-26/30): no slowdown; the Genesis may be faster, never
slower. Reported:
  * play stalls: ticks in GameMode 5 where the Genesis spent more frames
    than the NES (a gameplay lag frame) -- always a bug;
  * episodes: runs of consecutive non-play ticks (loads, scrolls, menus);
    a bug when the Genesis spent more frames on the whole run than the NES.
The harness attach frames (tick 0/1) are ignored.
Verdict line: LAG: PASS / FAIL.
"""
from __future__ import annotations

import argparse
import struct
from collections import defaultdict
from pathlib import Path

from capture_evidence import completed_ticks

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / "builds" / "reports" / "lockstep"


def per_tick(d: Path, plat: str) -> tuple[dict[int, int], dict[int, int]]:
    """tick -> video frames spent on it, tick -> GameMode at its last frame."""
    ram = (d / f"{plat}.fram").read_bytes()
    ticks = (d / f"{plat}.frtick").read_bytes()
    count = completed_ticks(d, plat)
    if not ram or len(ram) % 2048 or len(ticks) != 2 * (len(ram) // 2048):
        raise ValueError(f"{plat}: empty, truncated or mismatched video records")
    frames: dict[int, int] = defaultdict(int)
    mode: dict[int, int] = {}
    previous = -1
    for i in range(len(ticks) // 2):
        t = struct.unpack(">H", ticks[2 * i:2 * i + 2])[0]
        if not previous <= t < count:
            raise ValueError(f"{plat}: invalid video tick {t}")
        previous = t
        frames[t] += 1
        mode[t] = ram[i * 2048 + 0x12]
    # Faster transitions may jump FrameCounter; the capture explicitly
    # records those synthetic RAM ticks in .pad. All others need video.
    pad_file = d / f"{plat}.pad"
    pad = {int(t) for t in pad_file.read_text(encoding="utf-8").split()} if pad_file.exists() else set()
    if set(range(count)) - frames.keys() - pad:
        raise ValueError(f"{plat}: video trace does not cover completed ticks")
    return frames, mode


def budget_worst(d: Path) -> tuple[int, int]:
    """Latest VDP line ($01FF, written at the next tick's start) at which a
    Genesis play tick finished inside its own frame ($01FE = 0)."""
    ram = (d / "gen.fram").read_bytes()
    ticks = (d / "gen.frtick").read_bytes()
    worst, worst_t = 0, -1
    for i in range(1, len(ram) // 2048):
        r = ram[i * 2048:(i + 1) * 2048]
        p = ram[(i - 1) * 2048:i * 2048]
        t = struct.unpack(">H", ticks[2 * i:2 * i + 2])[0]
        # The tick that just ended was a play tick; values below $80 are
        # line numbers after the VBlank wrap (an overrun, caught as a stall).
        if p[0x12] == 5 and r[0x01FE] == 0 and 0x80 <= r[0x01FF] < 0xE0:
            if r[0x01FF] > worst:
                worst, worst_t = r[0x01FF], t - 1
    return worst, worst_t


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("presets", nargs="*")
    ap.add_argument("--md", type=Path)
    ap.add_argument("--budget", type=lambda v: int(v, 0), metavar="LINE",
                    help="T-172 margin gate: fail when a Genesis play tick that "
                         "fit its frame ended at or after this VDP line "
                         "($01FF; VBlank starts at $E0)")
    a = ap.parse_args()
    dirs = ([REPORTS / p for p in a.presets] if a.presets else
            sorted(d for d in REPORTS.iterdir() if (d / "gen.frtick").exists()))
    rows = ["| Preset | Kind | Ticks | NES frames | Genesis frames | Where |",
            "|---|---|---|---|---|---|"]
    fail = checked = 0
    for d in dirs:
        try:
            nf, nm = per_tick(d, "nes")
            gf, gm = per_tick(d, "gen")
            if completed_ticks(d, "nes") != completed_ticks(d, "gen"):
                raise ValueError("NES/Genesis completion counts differ")
        except (OSError, ValueError) as e:
            fail += 1
            rows.append(f"| {d.name} | ERROR | - | - | - | {e} |")
            continue
        common = sorted(t for t in set(nf) & set(gf) if t >= 2)
        if not common:
            fail += 1
            rows.append(f"| {d.name} | ERROR | 0 | - | - | no comparable ticks |")
            continue
        checked += 1
        if a.budget is not None:
            worst, worst_t = budget_worst(d)
            if worst >= a.budget:
                fail += 1
                rows.append(f"| {d.name} | budget | 1 | - | line ${worst:02X} **OVER ${a.budget:02X}** | tick {worst_t} |")
            else:
                rows.append(f"| {d.name} | budget | - | - | worst line ${worst:02X} | tick {worst_t} |")
        # Play stalls: both consoles in mode 5 on the tick.
        stalls = [t for t in common
                  if nm.get(t) == 5 and gm.get(t) == 5 and gf[t] > nf[t]]
        if stalls:
            fail += 1
            rows.append(f"| {d.name} | play stall | {len(stalls)} | "
                        f"{sum(nf[t] for t in stalls)} | {sum(gf[t] for t in stalls)} **WORSE** | "
                        f"ticks {', '.join(str(t) for t in stalls[:8])} |")
        # Non-play episodes.
        ep: list[int] = []
        for t in common + [None]:
            if t is not None and nm.get(t) != 5:
                ep.append(t)
                continue
            if ep:
                n_sum = sum(nf[x] for x in ep)
                g_sum = sum(gf[x] for x in ep)
                if g_sum > n_sum:
                    fail += 1
                    rows.append(f"| {d.name} | episode modes "
                                f"{'/'.join(sorted({'%02X' % nm[x] for x in ep}))} | {len(ep)} | "
                                f"{n_sum} | {g_sum} **WORSE** | ticks {ep[0]}-{ep[-1]} |")
                ep = []
    if not checked:
        fail += 1
        rows.append("| - | ERROR | 0 | - | - | no completed cases checked |")
    text = "\n".join(rows)
    if a.md:
        a.md.write_text(text + "\n", encoding="utf-8")
    print(text)
    print(f"LAG: {'FAIL' if fail else 'PASS'} ({checked} completed cases, {fail} errors/slower-than-NES rows)")
    return 1 if fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
