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

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / "builds" / "reports" / "lockstep"


def per_tick(d: Path, plat: str) -> tuple[dict[int, int], dict[int, int]]:
    """tick -> video frames spent on it, tick -> GameMode at its last frame."""
    ram = (d / f"{plat}.fram").read_bytes()
    ticks = (d / f"{plat}.frtick").read_bytes()
    frames: dict[int, int] = defaultdict(int)
    mode: dict[int, int] = {}
    for i in range(min(len(ram) // 2048, len(ticks) // 2)):
        t = struct.unpack(">H", ticks[2 * i:2 * i + 2])[0]
        frames[t] += 1
        mode[t] = ram[i * 2048 + 0x12]
    return frames, mode


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("presets", nargs="*")
    ap.add_argument("--md", type=Path)
    a = ap.parse_args()
    dirs = ([REPORTS / p for p in a.presets] if a.presets else
            sorted(d for d in REPORTS.iterdir() if (d / "gen.frtick").exists()))
    rows = ["| Preset | Kind | Ticks | NES frames | Genesis frames | Where |",
            "|---|---|---|---|---|---|"]
    fail = 0
    for d in dirs:
        if not all((d / f).exists() for f in ("nes.fram", "nes.frtick", "gen.fram", "gen.frtick")):
            continue
        nf, nm = per_tick(d, "nes")
        gf, gm = per_tick(d, "gen")
        common = sorted(t for t in set(nf) & set(gf) if t >= 2)
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
    text = "\n".join(rows)
    if a.md:
        a.md.write_text(text + "\n", encoding="utf-8")
    print(text)
    print(f"LAG: {'FAIL' if fail else 'PASS'} ({fail} slower-than-NES rows)")
    return 1 if fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
