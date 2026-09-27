"""Lockstep RAM differ: NES capture vs Genesis capture, aligned per game tick.

    python tools/lockstep/diff.py <out_dir> [--preset P.json] [--bless]

Both captures start at their first live GameMode $05 tick and replay the
same per-tick input, dumping the 2 KB NES work RAM each tick (capture.lua).

Verdict = tools/lockstep/gate.py (T-141), one line:
  GATE: PASS|FAIL  key=<ticks compared> fails=<n>  ratchet new=<n> earlier=<n>
        improved=<n> baseline=<n>  allow=<hits>  [gen stopped early at tick T]
KEY cells gate every tick; all other unmasked cells are held to the
per-preset full-RAM baseline (tools/lockstep/baselines/<preset>.json).
--bless writes the current full-RAM divergence set as the new baseline
(only from a run that compared every script tick).

The report also keeps the raw sections (tick-0 differences, first tick
each unmasked cell diverges) as evidence. Masks (documented platform
differences, never compared) live in gate.MASKS:
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

import argparse
import bisect
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gate  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
INC = ROOT / "reference" / "aldonunez"
MASKS = gate.MASKS
masked = gate.masked


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


def load_pad(out_dir: Path) -> set[int]:
    pad: set[int] = set()
    for plat in ("nes", "gen"):
        p = out_dir / f"{plat}.pad"
        if p.exists():
            pad.update(int(x) for x in p.read_text(encoding="utf-8").split())
    return pad


def failfast(out_dir: Path) -> tuple[int, int] | None:
    """(first mismatch tick, snapshot tick or -1) from gen.txt 'failfast t=.. snap=..'."""
    p = out_dir / "gen.txt"
    if not p.exists():
        return None
    m = re.search(r"^failfast t=(\d+) snap=(-?\d+)",
                  p.read_text(encoding="utf-8", errors="replace"), re.M)
    return (int(m.group(1)), int(m.group(2))) if m else None


def stopped_early(out_dir: Path) -> int | None:
    ff = failfast(out_dir)
    return ff[0] if ff else None


def main(out_dir: Path, spec: dict | None = None, bless: bool = False) -> int:
    spec = spec or {}
    nes_b = load(out_dir / "nes")
    gen_b = load(out_dir / "gen")
    n = min(len(nes_b), len(gen_b))
    if n == 0:
        raise SystemExit("ERROR: zero frames")
    nes = gate.rows(b"".join(nes_b[:n]))
    gen = gate.rows(b"".join(gen_b[:n]))
    pad = load_pad(out_dir)
    allow = spec.get("allow", [])
    pname = spec.get("name") or out_dir.name
    early = stopped_early(out_dir)

    lines: list[str] = []
    lines.append(f"ticks compared: {n}  (nes {len(nes_b)}, gen {len(gen_b)})  padded rows skipped: {len(pad)}")

    # --- gate: KEY cells ---
    fails, hits = gate.key_failures(nes, gen, allow, pad, limit=40)
    lines.append(f"\n== KEY mismatches (first {len(fails)}) ==")
    for t, a, x, y in fails:
        lines.append(f"  t={t:5d} ${a:04X} {name(a):32s} NES {x:02X}  GEN {y:02X}")
    for why, c in sorted(hits.items()):
        lines.append(f"  allowed: {c} tick-cells under {why}")

    # --- gate: full-RAM ratchet ---
    cells = gate.ratchet_cells(nes, gen, pad)
    base = gate.load_baseline(pname)
    new, earlier, improved = gate.ratchet_verdict(cells, base, n)
    lines.append(f"\n== full-RAM ratchet vs baseline "
                 f"({'none' if base is None else len(base)} cells): "
                 f"new {len(new)}, earlier {len(earlier)}, improved {len(improved)} ==")
    for t, a in new:
        lines.append(f"  NEW     t={t:5d} ${a:04X} {name(a):32s} NES {nes[t][a]:02X}  GEN {gen[t][a]:02X}")
    for t, a, bt in earlier:
        lines.append(f"  EARLIER t={t:5d} (baseline {bt}) ${a:04X} {name(a):32s} NES {nes[t][a]:02X}  GEN {gen[t][a]:02X}")
    for a in improved:
        lines.append(f"  IMPROVED ${a:04X} {name(a)} (baseline t={base[a]})")

    # --- raw evidence (unchanged sections) ---
    f0 = [(a, int(nes[0][a]), int(gen[0][a])) for a in range(0x800)
          if nes[0][a] != gen[0][a] and not masked(a)]
    lines.append(f"\n== tick 0: {len(f0)} unmasked cells differ ==")
    for a, x, y in f0:
        lines.append(f"  ${a:04X} {name(a):32s} NES {x:02X}  GEN {y:02X}")
    first: dict[int, int] = {}
    diff_mask = (nes != gen)
    for a in range(0x800):
        if masked(a):
            continue
        col = diff_mask[:, a]
        if col.any():
            first[a] = int(col.argmax())
    later = sorted((f, a) for a, f in first.items() if f > 0)
    lines.append(f"\n== cells equal at tick 0 that diverge later: {len(later)} ==")
    for f, a in later:
        lines.append(f"  t={f:5d} ${a:04X} {name(a):32s} NES {nes[f][a]:02X}  GEN {gen[f][a]:02X}")
    masked_diff = sum(1 for a in range(0x800) if masked(a) and nes[0][a] != gen[0][a])
    lines.append(f"\nmasked cells differing at tick 0: {masked_diff} (not evaluated)")

    no_base = base is None
    ok = not fails and not new and not earlier and not no_base
    early_s = f"  [gen stopped early at tick {early}]" if early is not None else ""
    verdict = (f"GATE: {'PASS' if ok else 'FAIL'}  key={n} fails={len(fails)}  "
               f"ratchet new={len(new)} earlier={len(earlier)} improved={len(improved)} "
               f"baseline={'NONE' if no_base else len(base)}  "
               f"allow={sum(hits.values())}{early_s}")
    lines.append("\n" + verdict)
    lines.append(f"VERDICT: {'MATCH' if ok else 'DIVERGE'} ({len(first)} unmasked cells ever differ)")

    if bless:
        script_ticks = sum(int(k) for k, _ in spec.get("script", [])) or n
        if early is not None or n < min(len(nes_b), script_ticks):
            lines.append("bless REFUSED: run did not compare every tick (use --full)")
        else:
            p = gate.save_baseline(pname, cells, n)
            lines.append(f"blessed {len(cells)} cells -> {p.relative_to(ROOT)}")

    report = "\n".join(lines)
    (out_dir / "diff.txt").write_text(report + "\n", encoding="utf-8")
    (out_dir / "diff.json").write_text(json.dumps({
        "ticks": n, "gate": "PASS" if ok else "FAIL", "verdict": "MATCH" if ok else "DIVERGE",
        "key_fails": [{"tick": t, "addr": f"${a:04X}", "name": name(a), "nes": x, "gen": y}
                      for t, a, x, y in fails],
        "ratchet_new": [{"tick": t, "addr": f"${a:04X}", "name": name(a)} for t, a in new],
        "ratchet_earlier": [{"tick": t, "addr": f"${a:04X}", "baseline": bt} for t, a, bt in earlier],
        "improved": [f"${a:04X}" for a in improved],
        "allow_hits": hits, "stopped_early": early,
        "frame0": [{"addr": f"${a:04X}", "name": name(a), "nes": x, "gen": y} for a, x, y in f0],
        "later": [{"frame": f, "addr": f"${a:04X}", "name": name(a)} for f, a in later],
    }, indent=1), encoding="utf-8")
    print(report)
    return 0 if ok else 1


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("out_dir", type=Path)
    ap.add_argument("--preset", type=Path)
    ap.add_argument("--bless", action="store_true")
    a = ap.parse_args()
    sp = json.loads(a.preset.read_text(encoding="utf-8-sig")) if a.preset else None
    raise SystemExit(main(a.out_dir, sp, a.bless))
