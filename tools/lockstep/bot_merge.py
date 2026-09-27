"""Fold a route-bot log into a preset's script (T-013).

    python tools/lockstep/bot_merge.py <preset.json> [<nes.botin>] [--out P]

The NES capture of a preset with "bot" writes <OUT>.botin: one button
string per game tick after the script, then "# <why it stopped>". This
appends those ticks to "script" (run-length encoded), drops "bot", and
writes the preset (in place unless --out). The Genesis then replays the
same buttons, so a normal run_lockstep diff checks the whole route.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def rle(lines: list[str]) -> list[list]:
    out: list[list] = []
    for b in lines:
        if out and out[-1][1] == b:
            out[-1][0] += 1
        else:
            out.append([1, b])
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("preset", type=Path)
    ap.add_argument("botin", type=Path, nargs="?")
    ap.add_argument("--out", type=Path)
    a = ap.parse_args()
    spec = json.loads(a.preset.read_text(encoding="utf-8-sig"))
    botin = a.botin or ROOT / "builds" / "reports" / "lockstep" / spec["name"] / "nes.botin"
    lines = botin.read_text(encoding="utf-8").splitlines()
    why = next((l[2:] for l in lines if l.startswith("# ")), "no end line")
    ticks = [l for l in lines if not l.startswith("#")]
    spec["script"] = spec["script"] + rle(ticks)
    spec.pop("bot", None)
    out = a.out or a.preset
    out.write_text(json.dumps(spec, indent=1) + "\n", encoding="utf-8")
    print(f"{out}: +{len(ticks)} bot ticks ({why}); script ticks "
          f"{sum(n for n, _ in spec['script'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
