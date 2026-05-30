#!/usr/bin/env python3
"""Aggregate NES-vs-Gen byte/pixel diff across ALL 20 caves.

For each cave_id $6A..$7D, runs the per-domain byte-diff (cave_byte_diff.py:
PAL0/BG CRAM byte-exact gate + BG play-cell structure) and the rendered-frame
shape-gate pixel-diff (pixel_diff.py, --rgb-tol 64) at frame 120, then emits
one table. Requires nes_<ID>/ + gen_<ID>/ goldens in C:/tmp/cave_golden.

Verdict columns:
  GATE  = cave_byte_diff exit 0 (BG CRAM byte-exact + every NES play cell has
          a Gen tile). This is the byte-exact gate.
  pix%  = pixel_diff play-area % (shape gate; residual is HUD-row offset +
          NES-vs-genplus color model, NOT byte data -- see commit history).
"""
import subprocess, sys, re, pathlib

ROOT = pathlib.Path(__file__).parent
CAVE_DIR = "C:/tmp/cave_golden"
CAVES = [f"{c:02X}" for c in range(0x6A, 0x7E)]

def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)

def main():
    rows = []
    npass = nfail = nmiss = 0
    for cid in CAVES:
        nes = pathlib.Path(CAVE_DIR) / f"nes_{cid}" / "f120.bin"
        gen = pathlib.Path(CAVE_DIR) / f"gen_{cid}" / "f120.bin"
        if not nes.exists() or not gen.exists():
            rows.append((cid, "MISSING", f"nes={nes.exists()} gen={gen.exists()}", "-"))
            nmiss += 1
            continue
        bd = run([sys.executable, str(ROOT / "cave_byte_diff.py"), CAVE_DIR,
                  "--cave", cid, "--frame", "120"])
        gate = "PASS" if bd.returncode == 0 else "FAIL"
        m = re.search(r"GATE DIVERGENCES.*?:\s*(\d+)", bd.stdout)
        gate_n = m.group(1) if m else "?"
        pd = run([sys.executable, str(ROOT / "pixel_diff.py"), CAVE_DIR,
                  "--cave", cid, "--rgb-tol", "64"])
        pm = re.search(r"\(([\d.]+)%\)", pd.stdout)
        pix = pm.group(1) + "%" if pm else "?"
        rows.append((cid, gate, gate_n, pix))
        if gate == "PASS": npass += 1
        else: nfail += 1

    print("# All-cave NES-vs-Gen diff (frame 120)\n")
    print("| cave | BG-byte gate | gate divs | pixel% (shape) |")
    print("|------|--------------|-----------|----------------|")
    for cid, gate, gn, pix in rows:
        print(f"| ${cid} | {gate} | {gn} | {pix} |")
    print(f"\nBG-byte GATE: PASS {npass}/{len(CAVES)}  FAIL {nfail}  MISSING {nmiss}")
    return 0 if (nfail == 0 and nmiss == 0) else 1

if __name__ == "__main__":
    sys.exit(main())
