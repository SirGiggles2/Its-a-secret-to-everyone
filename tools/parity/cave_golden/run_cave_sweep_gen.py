#!/usr/bin/env python3
"""Gen cave visual sweep — capture all 20 caves in sequence.

For each cave_id $6A..$7D: write a TRIVIAL prelude .lua (sets CAVE_ID /
OW_ROOM / OUT_DIR globals, then dofile()s the REVIEWED
probe_gen_cave_golden.lua), launch BizHawk (genplus-gx) on Debug.md,
wait for the probe's client.exit(), move on. The probe writes
gen_<ID>/{f*.bin,shot.png}.

The prelude carries ZERO memory access — it only sets globals + dofiles
the already-reviewed probe (RULE V2: the probe is the reviewed unit).

cave_id -> OW_ROOM derived from tools/parity/warp_routes_expected.json
(Phase A oracle, first OW room that maps to each cave_id).
"""
import subprocess, sys, time, os, pathlib

CAVE_OW = {
    0x6A: 0x77, 0x6B: 0x06, 0x6C: 0x0A, 0x6D: 0x09, 0x6E: 0x1D,
    0x6F: 0x1C, 0x70: 0x10, 0x71: 0x01, 0x72: 0x0E, 0x73: 0x75,
    0x74: 0x02, 0x75: 0x1A, 0x76: 0x70, 0x77: 0x25, 0x78: 0x0C,
    0x79: 0x12, 0x7A: 0x34, 0x7B: 0x13, 0x7C: 0x0F, 0x7D: 0x2B,
}

BIZHAWK = r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
EMUHAWK = BIZHAWK + r"\EmuHawk.exe"
ROM     = r"C:\tmp\Debug.md"
PROBE   = r"C:\tmp\probe_gen_cave_golden.lua"
PRELUDE = r"C:\tmp\sweep_prelude.lua"

def emuhawk_running():
    out = subprocess.run(["tasklist"], capture_output=True, text=True).stdout.lower()
    return "emuhawk" in out

def run_one(cave, ow):
    with open(PRELUDE, "w") as f:
        f.write(f"CAVE_ID=0x{cave:02X}\nOW_ROOM=0x{ow:02X}\n"
                f'OUT_DIR="C:\\\\tmp\\\\cave_golden"\n'
                f'dofile("{PROBE.replace(chr(92), chr(92)*2)}")\n')
    subprocess.run([
        "powershell", "-Command",
        f"Start-Process -FilePath '{EMUHAWK}' "
        f"-ArgumentList '--lua={PRELUDE}','{ROM}' "
        f"-WorkingDirectory '{BIZHAWK}'"
    ])
    time.sleep(4)
    # wait for the probe to client.exit()
    waited = 0
    while emuhawk_running() and waited < 180:
        time.sleep(3); waited += 3
    if emuhawk_running():
        subprocess.run(["taskkill", "/F", "/IM", "EmuHawk.exe"],
                       capture_output=True)
        return False
    return True

def main():
    only = sys.argv[1:]  # optional list of hex cave ids
    caves = [int(x, 16) for x in only] if only else sorted(CAVE_OW)
    for cave in caves:
        ow = CAVE_OW[cave]
        shot = pathlib.Path(f"C:/tmp/cave_golden/gen_{cave:02X}/shot.png")
        ok = run_one(cave, ow)
        exists = shot.exists()
        print(f"cave ${cave:02X} (ow ${ow:02X}): "
              f"{'EXIT' if ok else 'TIMEOUT'} shot={'YES' if exists else 'NO'}",
              flush=True)

if __name__ == "__main__":
    main()
