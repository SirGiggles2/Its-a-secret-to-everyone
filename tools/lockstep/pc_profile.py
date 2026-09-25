"""Map a lockstep 68K PC histogram (gen.pcprof) to functions.

    python tools/lockstep/run_lockstep.py <preset> --pc-profile 2290:2400
    python tools/lockstep/pc_profile.py builds/reports/lockstep/<name>/gen.pcprof [--top 40]

Counts are executed INSTRUCTIONS per function (the execute callback fires
once per instruction), not cycles: a ranking of where the 68000 spends its
time, not an exact cycle budget. Symbols come from nm of the ELF that
built builds/Debug.md (build/debug_project/out/Debug.out); profile a ROM
only against the ELF it was linked from.
"""
from __future__ import annotations

import argparse
import bisect
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NM = ROOT / "build" / "toolchain" / "sgdk_bin" / "bin" / "nm.exe"
ELF = ROOT / "build" / "debug_project" / "out" / "Debug.out"


def symbols(elf: Path) -> tuple[list[int], list[str]]:
    out = subprocess.run([str(NM), "-n", str(elf)], capture_output=True, text=True,
                         check=True).stdout
    addrs, names = [], []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[1] in "tTWw":
            addrs.append(int(parts[0], 16) & 0xFFFFFF)
            names.append(parts[2])
    return addrs, names


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pcprof", type=Path)
    ap.add_argument("--top", type=int, default=40)
    ap.add_argument("--elf", type=Path, default=ELF)
    a = ap.parse_args()

    addrs, names = symbols(a.elf)
    header = ""
    per_fn: Counter[str] = Counter()
    hits: dict[int, int] = {}
    total = 0
    for line in a.pcprof.read_text().splitlines():
        if line.startswith("#"):
            header = line
            continue
        pc_s, n_s = line.split()
        pc, n = int(pc_s, 16) & 0xFFFFFF, int(n_s)
        i = bisect.bisect_right(addrs, pc) - 1
        per_fn[names[i] if i >= 0 else f"?{pc:06X}"] += n
        hits[pc] = hits.get(pc, 0) + n
        total += n
    # Calls = executions of the function's first instruction (a loop that
    # branches back to the entry would over-count; rare in gcc output).
    entry = {nm: hits.get(ad, 0) for ad, nm in zip(addrs, names)}
    frames = 1
    if header.startswith("# frames"):
        f0, f1 = header.split()[2].split("..")
        frames = int(f1) - int(f0) + 1
    print(header)
    print(f"instructions {total}  ({total / frames:.0f}/frame)")
    print("   share     instr   calls/f  instr/call  function")
    for name, n in per_fn.most_common(a.top):
        c = entry.get(name, 0)
        per_call = f"{n / c:10.1f}" if c else "         -"
        print(f"{n * 100.0 / total:6.2f}% {n:9d} {c / frames:9.1f} {per_call}  {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
