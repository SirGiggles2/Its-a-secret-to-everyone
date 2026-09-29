"""Run the T-004 NES Ganon nametable probe in an owned BizHawk process.

Uses the original ROM path: the 2026-09-23 approach.State may require the
same path to load without a modal prompt. Does not touch the user's session.
"""
from __future__ import annotations

import ctypes
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EMU = Path(r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe")
ROM = Path(r"C:\tmp\loz_real.nes")
STAGE = Path(r"C:\tmp\t004_ganon_probe_stage")


def short(path: Path) -> str:
    buf = ctypes.create_unicode_buffer(520)
    if not ctypes.windll.kernel32.GetShortPathNameW(str(path), buf, len(buf)):
        raise OSError(path)
    return buf.value


def main() -> int:
    entry = sys.argv[1] if len(sys.argv) > 1 else "mode4"
    if entry not in ("mode3", "mode4"):
        raise SystemExit("usage: run_nes_ganon_nt.py [mode3|mode4]")
    out = ROOT / f"builds/reports/recovery/t004-ganon-nt-{entry}"
    STAGE.mkdir(parents=True, exist_ok=True)
    out.mkdir(parents=True, exist_ok=True)
    probe = STAGE / "probe.lua"
    shutil.copy2(ROOT / "tools/parity/probe_nes_ganon_nt.lua", probe)
    cfg = json.loads((EMU.parent / "config.ini").read_text(encoding="utf-8-sig"))
    cfg["SoundEnabled"] = False
    cfg["SingleInstanceMode"] = False
    for path_entry in cfg.get("PathEntries", {}).get("Paths", []):
        if path_entry.get("Type") == "Base":
            path_entry["Path"] = str(STAGE / path_entry["System"])
        elif path_entry.get("Type") == "Firmware":
            path_entry["Path"] = str(EMU.parent / "Firmware")
    config = STAGE / "config.ini"
    config.write_text(json.dumps(cfg), encoding="utf-8")
    names = ("t004_ganon_nt.txt", "t004_ganon_nt_level9.bin",
             "t004_ganon_nt_room42_first_play.bin", "t004_ganon_nt_combat.bin",
             "t004_ganon_nt_level9_pal.bin", "t004_ganon_nt_combat_pal.bin",
             "t004_ganon_nt_combat.png")
    for name in names:
        (Path(r"C:\tmp") / name).unlink(missing_ok=True)
    cmd = [short(EMU), "--gdi", f"--config={config}", f"--lua={probe}", short(ROM)]
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    env = os.environ.copy()
    env["T004_ENTRY_MODE"] = entry
    with (out / "emuhawk.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(cmd, cwd=EMU.parent, stdout=log,
                                   stderr=subprocess.STDOUT, startupinfo=startup, env=env)
        try:
            code = process.wait(timeout=180)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)
            code = "timeout"
    captured = []
    for name in names:
        source = Path(r"C:\tmp") / name
        if source.exists():
            shutil.copy2(source, out / source.name)
            captured.append(source.name)
    print(f"exit={code} captured={captured}")
    report = out / "t004_ganon_nt.txt"
    return 0 if code == 0 and len(captured) == len(names) and report.exists() and "ERROR" not in report.read_text() else 1


if __name__ == "__main__":
    raise SystemExit(main())
