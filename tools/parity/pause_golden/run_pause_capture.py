#!/usr/bin/env python3
"""run_pause_capture.py — launch BizHawk to capture the pause-subscreen
golden for one platform, mirroring the cave-golden sweep runners.

Writes a TRIVIAL prelude .lua (sets globals + dofile()s the REVIEWED probe
— RULE V2: the probe is the reviewed unit) to C:\\tmp, launches EmuHawk on
the right ROM (NesHawk for NES via config pin; genplus for Genesis), waits
for the probe's client.exit().

Usage:
  python run_pause_capture.py nes ow         # NES overworld golden
  python run_pause_capture.py nes uw         # NES dungeon golden
  python run_pause_capture.py gen boot       # Genesis as-booted
  python run_pause_capture.py gen <tag>      # Genesis, custom subdir tag
"""
import subprocess, sys, time, shutil, pathlib

REPO    = pathlib.Path(__file__).resolve().parents[3]
BIZHAWK = r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
EMUHAWK = BIZHAWK + r"\EmuHawk.exe"
NES_ROM = r"C:\tmp\loz_real.nes"
GEN_ROM = r"C:\tmp\Debug.md"
PRELUDE = r"C:\tmp\pause_prelude.lua"
NES_PROBE = REPO / "tools" / "parity" / "pause_golden" / "pause_capture_nes.lua"
GEN_PROBE = REPO / "tools" / "parity" / "pause_golden" / "pause_capture_gen.lua"


def emuhawk_running():
    out = subprocess.run(["tasklist"], capture_output=True, text=True).stdout.lower()
    return "emuhawk" in out


def launch_and_wait(rom, timeout=180):
    subprocess.run([
        "powershell", "-Command",
        f"Start-Process -FilePath '{EMUHAWK}' "
        f"-ArgumentList '--lua={PRELUDE}','{rom}' "
        f"-WorkingDirectory '{BIZHAWK}'"
    ])
    time.sleep(4)
    waited = 0
    while emuhawk_running() and waited < timeout:
        time.sleep(3); waited += 3
    if emuhawk_running():
        subprocess.run(["taskkill", "/F", "/IM", "EmuHawk.exe"], capture_output=True)
        return False
    return True


def write_prelude(lines, probe):
    probe_esc = str(probe).replace("\\", "\\\\")
    with open(PRELUDE, "w") as f:
        for ln in lines:
            f.write(ln + "\n")
        f.write(f'dofile("{probe_esc}")\n')


def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(2)
    plat, arg = sys.argv[1], sys.argv[2]
    if plat == "nes":
        write_prelude([f'CONTEXT="{arg}"', 'OUT_DIR="C:\\\\tmp\\\\pause_golden"'], NES_PROBE)
        ok = launch_and_wait(NES_ROM)
        out = pathlib.Path(f"C:/tmp/pause_golden/nes_{arg}")
    elif plat == "gen":
        # always stage the freshest ROM
        shutil.copy(REPO / "builds" / "Debug.md", GEN_ROM)
        write_prelude([f'TAG="{arg}"', 'OUT_DIR="C:\\\\tmp\\\\pause_golden"'], GEN_PROBE)
        ok = launch_and_wait(GEN_ROM)
        out = pathlib.Path(f"C:/tmp/pause_golden/{arg}")
    else:
        print("platform must be nes|gen"); sys.exit(2)
    active = out / "active.bin"
    print(f"{plat} {arg}: {'EXIT' if ok else 'TIMEOUT'} "
          f"active.bin={'YES' if active.exists() else 'NO'} -> {out}", flush=True)


if __name__ == "__main__":
    main()
