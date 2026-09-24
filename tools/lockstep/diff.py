"""Lockstep RAM differ: NES capture vs Genesis capture, aligned at sync.

Both captures start at their first GameMode $05 frame and replay the same
per-frame input, dumping the 2 KB NES work RAM each frame (capture.lua).

Report:
  - frame-0 state diff (what the two load paths produced), by variable
  - first frame each non-masked cell diverges, grouped by variable
Masks (documented platform differences, reported as counts only):
  $0000-$000F  6502 scratch temps
  $0100-$01FF  6502 stack page
  $0200-$02FF  OAM shadow (sprites compared separately, not raw)
  $0300-$033F  PPU transfer buffers
  $0066-$006F, $05F0-$061F  audio driver state (NES APU vs Genesis driver)
  $07E0-$07FF  Genesis debug/probe scratch (fs_handoff marker $07F2 etc.)
Names come from reference/aldonunez/*.inc; an address inside an array
prints as Name+offset (nearest lower symbol).
"""
from __future__ import annotations

import bisect
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INC = ROOT / "reference" / "aldonunez"
MASKS = [(0x0000, 0x000F), (0x0100, 0x01FF), (0x0200, 0x02FF), (0x0300, 0x033F),
         (0x0066, 0x006F), (0x05F0, 0x061F), (0x07E0, 0x07FF)]


def load_names() -> tuple[list[int], list[str]]:
    table: dict[int, str] = {}
    for inc in sorted(INC.glob("*.inc")):
        for line in inc.read_text(encoding="utf-8").splitlines():
            m = re.match(r"\s*(\w+)\s*:=\s*\$([0-9A-Fa-f]+)", line)
            if m:
                a = int(m.group(2), 16)
                if a < 0x800:
                    table.setdefault(a, m.group(1))
    addrs = sorted(table)
    return addrs, [table[a] for a in addrs]


ADDRS, NAMES = load_names()


def name(a: int) -> str:
    i = bisect.bisect_right(ADDRS, a) - 1
    if i < 0:
        return f"${a:04X}"
    base = ADDRS[i]
    return NAMES[i] if base == a else f"{NAMES[i]}+{a - base}"


def masked(a: int) -> bool:
    return any(lo <= a <= hi for lo, hi in MASKS)


def load(prefix: Path) -> list[bytes]:
    err = prefix.with_suffix(".err")
    if err.exists():
        raise SystemExit(f"ERROR {prefix.name}: {err.read_text().strip()}")
    ram = prefix.with_suffix(".ram")
    if not ram.exists():
        raise SystemExit(f"ERROR {prefix.name}: no .ram (capture did not run)")
    data = ram.read_bytes()
    if not data or len(data) % 0x800:
        raise SystemExit(f"ERROR {prefix.name}: bad .ram size {len(data)}")
    return [data[i:i + 0x800] for i in range(0, len(data), 0x800)]


def main(out_dir: Path) -> int:
    nes = load(out_dir / "nes")
    gen = load(out_dir / "gen")
    n = min(len(nes), len(gen))
    if n == 0:
        raise SystemExit("ERROR: zero frames")

    lines: list[str] = []
    f0 = [(a, nes[0][a], gen[0][a]) for a in range(0x800)
          if nes[0][a] != gen[0][a] and not masked(a)]
    lines.append(f"frames compared: {n}  (nes {len(nes)}, gen {len(gen)})")
    lines.append(f"\n== sync frame 0: {len(f0)} unmasked cells differ ==")
    for a, x, y in f0:
        lines.append(f"  ${a:04X} {name(a):32s} NES {x:02X}  GEN {y:02X}")

    first: dict[int, int] = {}
    for f in range(n):
        for a in range(0x800):
            if a in first or masked(a):
                continue
            if nes[f][a] != gen[f][a]:
                first[a] = f
    later = sorted((f, a) for a, f in first.items() if f > 0)
    lines.append(f"\n== cells equal at frame 0 that diverge later: {len(later)} ==")
    for f, a in later:
        lines.append(f"  f={f:4d} ${a:04X} {name(a):32s} NES {nes[f][a]:02X}  GEN {gen[f][a]:02X}")

    masked_diff = sum(1 for a in range(0x800) if masked(a) and nes[0][a] != gen[0][a])
    lines.append(f"\nmasked cells differing at frame 0: {masked_diff} (not evaluated)")
    verdict = "MATCH" if not first else "DIVERGE"
    lines.append(f"\nVERDICT: {verdict} ({len(first)} unmasked cells ever differ)")
    report = "\n".join(lines)
    (out_dir / "diff.txt").write_text(report + "\n", encoding="utf-8")
    (out_dir / "diff.json").write_text(json.dumps({
        "frames": n, "verdict": verdict,
        "frame0": [{"addr": f"${a:04X}", "name": name(a), "nes": x, "gen": y} for a, x, y in f0],
        "later": [{"frame": f, "addr": f"${a:04X}", "name": name(a)} for f, a in later],
    }, indent=1), encoding="utf-8")
    print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(Path(sys.argv[1])))
