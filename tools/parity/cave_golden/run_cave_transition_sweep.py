#!/usr/bin/env python3
"""run_cave_transition_sweep.py — sweep the cave-entry TRANSITION byte-diff
across caves to check the load-hold / emerge / floor fix generalizes beyond
cave $6A (where CAVE_LOAD_HOLD_FRAMES=18 + floor $D5 were tuned).

For each cave_id it: writes a per-cave prelude that sets globals + dofile()s the
(C:\\tmp-staged, space-free) transition probe, launches NES (loz_real.nes,
NesHawk) then Gen (Debug.md), waits for each to exit, then runs
cave_transition_diff.py and records the gated-field result (ObjY/ObjDir/
ObjGridOffset — the cave-entry MOTION; ObjX is the documented probe
entrance-column residual, reported but not failed here).

Prereqs (caller must have staged these to C:\\tmp, as the $6A run does):
  C:\\tmp\\Debug.md, C:\\tmp\\loz_real.nes,
  C:\\tmp\\probe_nes_cave_transition.lua, C:\\tmp\\probe_gen_cave_transition.lua

Usage:
  python tools/parity/cave_golden/run_cave_transition_sweep.py [cave ...]
    no args -> all 20 caves; or pass hex ids e.g. 0x6B 0x6C
Exit 0 iff every swept cave's MOTION fields (ObjY/ObjDir/ObjGridOffset) are CLEAN.
"""
from __future__ import annotations
import subprocess, sys, time, re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
DIFF = REPO / "tools" / "parity" / "cave_golden" / "cave_transition_diff.py"
TMP = Path(r"C:\tmp")
OUT_ROOT = TMP / "cave_golden"
BIZHAWK = r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
EMUHAWK = BIZHAWK + r"\EmuHawk.exe"
NES_ROM = r"C:\tmp\loz_real.nes"
GEN_ROM = r"C:\tmp\Debug.md"

# cave_id -> hosting OW room (Phase A warp oracle; from run_cave_sweep_nes.py).
CAVE_OW = {
    0x6A: 0x77, 0x6B: 0x06, 0x6C: 0x0A, 0x6D: 0x09, 0x6E: 0x1D,
    0x6F: 0x1C, 0x70: 0x10, 0x71: 0x01, 0x72: 0x0E, 0x73: 0x75,
    0x74: 0x02, 0x75: 0x1A, 0x76: 0x70, 0x77: 0x25, 0x78: 0x0C,
    0x79: 0x12, 0x7A: 0x34, 0x7B: 0x13, 0x7C: 0x0F, 0x7D: 0x2B,
}

# Gated MOTION fields (the cave-entry animation/positioning parity). ObjX is the
# documented probe entrance-column + nes_ram-mirror residual — reported, not gated.
MOTION_FIELDS = ("ObjY", "ObjDir", "ObjGridOffset")


def emuhawk_up() -> bool:
    out = subprocess.run(["tasklist"], capture_output=True, text=True).stdout.lower()
    return "emuhawk" in out


def run_probe(probe_tmp: str, rom: str, cave: int, ow: int, side: str) -> None:
    # Plain-text cfg the probe reads via io.open+match (dofile is broken in this
    # NLua build; io.open works). "<cave_hex> <ow_hex>". Launch probe DIRECTLY.
    (TMP / "_cave_cfg.txt").write_text(f"{cave:02X} {ow:02X}\n", encoding="utf-8")
    subprocess.run(["powershell", "-Command",
        f"Start-Process -FilePath '{EMUHAWK}' "
        f"-ArgumentList '--lua=C:\\tmp\\{probe_tmp}','{rom}' -WorkingDirectory '{BIZHAWK}'"])
    time.sleep(4)
    waited = 0
    while emuhawk_up() and waited < 180:
        time.sleep(3); waited += 3
    if emuhawk_up():
        subprocess.run(["taskkill", "/F", "/IM", "EmuHawk.exe"], capture_output=True)
        time.sleep(2)


def diff_motion(nes_dir: Path, gen_dir: Path) -> tuple[str, str]:
    r = subprocess.run([sys.executable, str(DIFF), str(nes_dir), str(gen_dir)],
                       capture_output=True, text=True)
    txt = r.stdout
    bad = []
    for f in MOTION_FIELDS:
        m = re.search(rf"\[{re.escape(f)}\]\s+(\d+) divergent", txt)
        if m and int(m.group(1)) > 0:
            bad.append(f"{f}={m.group(1)}")
        elif f"[{f}] CLEAN" not in txt and not m:
            bad.append(f"{f}=?")
    objx = re.search(r"\[ObjX\]\s+(\d+) divergent", txt)
    objx_n = objx.group(1) if objx else "?"
    return ("CLEAN" if not bad else "DIRTY:" + ",".join(bad)), f"ObjX={objx_n}"


def main() -> int:
    caves = [int(a, 16) for a in sys.argv[1:]] or list(CAVE_OW)
    rows = []
    for cave in caves:
        ow = CAVE_OW[cave]
        nes_dir = OUT_ROOT / f"nes_{cave:02X}_trans"
        gen_dir = OUT_ROOT / f"gen_{cave:02X}_trans"
        for d in (nes_dir, gen_dir):
            if d.exists():
                for p in d.glob("*"):
                    p.unlink()
        run_probe("probe_nes_cave_transition.lua", NES_ROM, cave, ow, "nes")
        run_probe("probe_gen_cave_transition.lua", GEN_ROM, cave, ow, "gen")
        nb = len(list(nes_dir.glob("f*.bin"))); gb = len(list(gen_dir.glob("f*.bin")))
        gstat = (gen_dir / "status.txt")
        gpass = gstat.read_text().split()[0] if gstat.exists() else "NOCAP"
        if nb == 0 or gb == 0 or gpass != "PASS":
            rows.append((cave, f"CAPTURE-FAIL (nes={nb} gen={gb} gstatus={gpass})", ""))
            continue
        verdict, objx = diff_motion(nes_dir, gen_dir)
        rows.append((cave, verdict, objx))
        print(f"  cave ${cave:02X} (ow ${ow:02X}): {verdict}  {objx}")

    print("\n== cave-entry transition sweep — MOTION (ObjY/ObjDir/ObjGridOffset) ==")
    clean = 0
    for cave, verdict, objx in rows:
        print(f"  ${cave:02X}: {verdict:40s} {objx}")
        if verdict == "CLEAN":
            clean += 1
    print(f"\n{clean}/{len(rows)} caves MOTION-CLEAN")
    return 0 if clean == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
