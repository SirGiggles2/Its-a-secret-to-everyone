#!/usr/bin/env python3
"""NES cave golden sweep — capture all 20 caves from the real NES Z1 ROM.

Mirror of run_cave_sweep_gen.py for the NES side. For each cave_id $6A..$7D:
write a trivial prelude that sets CAVE_ID/QUEST/OW_ROOM/OUT_DIR then
dofile()s the REVIEWED probe_nes_cave_golden.lua, launch BizHawk (NesHawk
core -- config.ini PreferredCores NES=NesHawk; the CHR/PALRAM capture reads
the "VRAM" domain that only NesHawk exposes) on loz_real.nes, wait for the
probe's client.exit(). The probe boots from battery SRAM (core-agnostic),
fakes HandleWarpOW to load the cave, asserts ObjType+1==CAVE_ID, and writes
nes_<ID>/{f*.bin,shot.png}.

cave_id -> OW_ROOM identical to the Gen sweep (Phase A warp oracle).
"""
import subprocess, sys, time, pathlib

CAVE_OW = {
    0x6A: 0x77, 0x6B: 0x06, 0x6C: 0x0A, 0x6D: 0x09, 0x6E: 0x1D,
    0x6F: 0x1C, 0x70: 0x10, 0x71: 0x01, 0x72: 0x0E, 0x73: 0x75,
    0x74: 0x02, 0x75: 0x1A, 0x76: 0x70, 0x77: 0x25, 0x78: 0x0C,
    0x79: 0x12, 0x7A: 0x34, 0x7B: 0x13, 0x7C: 0x0F, 0x7D: 0x2B,
}

BIZHAWK = r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
EMUHAWK = BIZHAWK + r"\EmuHawk.exe"
ROM     = r"C:\tmp\loz_real.nes"
PROBE   = r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\parity\cave_golden\probe_nes_cave_golden.lua"
PRELUDE = r"C:\tmp\sweep_nes_prelude.lua"

def emuhawk_running():
    out = subprocess.run(["tasklist"], capture_output=True, text=True).stdout.lower()
    return "emuhawk" in out

def run_one(cave, ow):
    with open(PRELUDE, "w") as f:
        f.write(f"CAVE_ID=0x{cave:02X}\nQUEST=1\nOW_ROOM=0x{ow:02X}\n"
                f'OUT_DIR="C:\\\\tmp\\\\cave_golden"\n'
                f'dofile("{PROBE.replace(chr(92), chr(92)*2)}")\n')
    subprocess.run([
        "powershell", "-Command",
        f"Start-Process -FilePath '{EMUHAWK}' "
        f"-ArgumentList '--lua={PRELUDE}','{ROM}' "
        f"-WorkingDirectory '{BIZHAWK}'"
    ])
    time.sleep(4)
    waited = 0
    while emuhawk_running() and waited < 180:
        time.sleep(3); waited += 3
    if emuhawk_running():
        subprocess.run(["taskkill", "/F", "/IM", "EmuHawk.exe"], capture_output=True)
        return False
    return True

def main():
    only = sys.argv[1:]
    caves = [int(x, 16) for x in only] if only else sorted(CAVE_OW)
    for cave in caves:
        ow = CAVE_OW[cave]
        ok = run_one(cave, ow)
        f120 = pathlib.Path(f"C:/tmp/cave_golden/nes_{cave:02X}/f120.bin")
        print(f"cave ${cave:02X} (ow ${ow:02X}): "
              f"{'EXIT' if ok else 'TIMEOUT'} golden={'YES' if f120.exists() else 'NO'}",
              flush=True)

if __name__ == "__main__":
    main()
