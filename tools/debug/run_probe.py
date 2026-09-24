"""Run one BizHawk Lua probe against builds/Debug.md in an isolated,
hidden, owned EmuHawk process.

    python tools/debug/run_probe.py <probe.lua> <out_dir> [--timeout S]
           [--rom PATH] [--collect C:\\tmp\\report.txt ...]

- Private config + save paths under C:\\tmp\\claude_probe\\<out_dir name>
  (fresh SRAM every run; never touches the user's emulator/profile).
- Only the launched process is ever killed (timeout).
- @SYM:<name>@ tokens in the Lua are replaced with the symbol's address
  from build/debug_project/out/Debug.out (nm), so probes never hardcode
  linker-placed RAM. Unknown symbol = error, not a guess.
- --collect copies fixed-path reports the probe writes into out_dir.
- Writes out_dir/launch.json: ROM/script SHA256, symbols used, exit code.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EMU = Path(r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms"
           r"\BizHawk-2.11-win-x64\EmuHawk.exe")
NM = ROOT / "build" / "toolchain" / "sgdk_bin" / "bin" / "nm.exe"
ELF = ROOT / "build" / "debug_project" / "out" / "Debug.out"
SYM_RE = re.compile(r"@SYM:([A-Za-z_][A-Za-z0-9_]*)@")


def short(path: Path) -> str:
    buf = ctypes.create_unicode_buffer(520)
    if not ctypes.windll.kernel32.GetShortPathNameW(str(path), buf, 520):
        raise OSError(f"no short path for {path}")
    return buf.value


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def elf_symbols(names: set[str]) -> dict[str, int]:
    if not names:
        return {}
    out = subprocess.run([str(NM), str(ELF)], capture_output=True, text=True, check=True).stdout
    found: dict[str, int] = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[2] in names:
            found[parts[2]] = int(parts[0], 16) & 0xFFFFFF
    missing = names - found.keys()
    if missing:
        raise SystemExit(f"symbols not in {ELF.name}: {sorted(missing)}")
    return found


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("lua", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--rom", type=Path, default=ROOT / "builds" / "Debug.md")
    ap.add_argument("--collect", nargs="*", default=[])
    a = ap.parse_args()

    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    text = a.lua.read_text(encoding="utf-8")
    syms = elf_symbols(set(SYM_RE.findall(text)))
    text = SYM_RE.sub(lambda m: f"0x{syms[m.group(1)]:06X}", text)

    stage = Path(r"C:\tmp\claude_probe") / out.name
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir(parents=True)
    probe = stage / a.lua.name
    probe.write_text(text, encoding="utf-8")
    shutil.copy2(probe, out / a.lua.name)
    for c in a.collect:
        Path(c).unlink(missing_ok=True)

    cfg = json.loads((EMU.parent / "config.ini").read_text(encoding="utf-8-sig"))
    cfg["SoundEnabled"] = False
    cfg["SingleInstanceMode"] = False
    for entry in cfg.get("PathEntries", {}).get("Paths", []):
        if entry.get("Type") == "Base":
            entry["Path"] = str(stage / entry["System"])
        elif entry.get("Type") == "Firmware":
            entry["Path"] = str(EMU.parent / "Firmware")
    config = stage / "config.ini"
    config.write_text(json.dumps(cfg), encoding="utf-8")

    si = subprocess.STARTUPINFO()
    si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    si.wShowWindow = 0
    cmd = [short(EMU), "--gdi", f"--config={config}", f"--lua={probe}", short(a.rom.resolve())]
    with (out / "emuhawk.log").open("w", encoding="utf-8") as log:
        p = subprocess.Popen(cmd, cwd=EMU.parent, stdout=log, stderr=subprocess.STDOUT, startupinfo=si)
        try:
            code: int | str = p.wait(timeout=a.timeout)
        except subprocess.TimeoutExpired:
            p.kill()
            p.wait(timeout=10)
            code = "timeout"

    collected = []
    for c in a.collect:
        src = Path(c)
        if src.exists():
            shutil.copy2(src, out / src.name)
            collected.append(src.name)
    (out / "launch.json").write_text(json.dumps({
        "rom": str(a.rom),
        "rom_sha256": sha(a.rom),
        "script": str(a.lua),
        "script_sha256": sha(out / a.lua.name),
        "symbols": {k: f"0x{v:06X}" for k, v in syms.items()},
        "exit_code": code,
        "collected": collected,
    }, indent=2), encoding="utf-8")
    print(f"exit={code} collected={collected} symbols={ {k: hex(v) for k, v in syms.items()} }")
    return 0 if code == 0 and len(collected) == len(a.collect) else 1


if __name__ == "__main__":
    raise SystemExit(main())
