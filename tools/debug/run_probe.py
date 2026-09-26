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
import os
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


# EmuHawk (WinForms) activates its main window even when started hidden, which
# steals keyboard focus from whatever the user is doing. It runs on its own
# Win32 desktop instead: windows there are never shown and cannot take the
# foreground on the user's desktop. CLAUDE_PROBE_VISIBLE=1 restores the old
# on-screen launch.
PROBE_DESKTOP = "claude_probe"


def run_on_hidden_desktop(cmd: list[str], cwd: Path, log_path: Path,
                          timeout: float) -> "int | str":
    from ctypes import wintypes
    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    u32 = ctypes.WinDLL("user32", use_last_error=True)
    u32.CreateDesktopW.restype = wintypes.HANDLE
    GENERIC_ALL = 0x10000000
    if not u32.CreateDesktopW(PROBE_DESKTOP, None, None, 0, GENERIC_ALL, None):
        raise OSError(f"CreateDesktopW failed ({ctypes.get_last_error()})")

    class SA(ctypes.Structure):
        _fields_ = [("nLength", wintypes.DWORD), ("lpSecurityDescriptor", wintypes.LPVOID),
                    ("bInheritHandle", wintypes.BOOL)]

    class SI(ctypes.Structure):
        _fields_ = [("cb", wintypes.DWORD), ("lpReserved", wintypes.LPWSTR),
                    ("lpDesktop", wintypes.LPWSTR), ("lpTitle", wintypes.LPWSTR),
                    ("dwX", wintypes.DWORD), ("dwY", wintypes.DWORD),
                    ("dwXSize", wintypes.DWORD), ("dwYSize", wintypes.DWORD),
                    ("dwXCountChars", wintypes.DWORD), ("dwYCountChars", wintypes.DWORD),
                    ("dwFillAttribute", wintypes.DWORD), ("dwFlags", wintypes.DWORD),
                    ("wShowWindow", wintypes.WORD), ("cbReserved2", wintypes.WORD),
                    ("lpReserved2", wintypes.LPVOID), ("hStdInput", wintypes.HANDLE),
                    ("hStdOutput", wintypes.HANDLE), ("hStdError", wintypes.HANDLE)]

    class PI(ctypes.Structure):
        _fields_ = [("hProcess", wintypes.HANDLE), ("hThread", wintypes.HANDLE),
                    ("dwProcessId", wintypes.DWORD), ("dwThreadId", wintypes.DWORD)]

    k32.CreateFileW.restype = wintypes.HANDLE
    sa = SA(ctypes.sizeof(SA), None, True)
    log = k32.CreateFileW(str(log_path), 0x40000000, 3, ctypes.byref(sa), 2, 0x80, None)
    if log in (None, wintypes.HANDLE(-1).value):
        raise OSError(f"CreateFileW failed ({ctypes.get_last_error()})")
    si = SI()
    si.cb = ctypes.sizeof(SI)
    si.lpDesktop = PROBE_DESKTOP
    si.dwFlags = 0x100 | 0x1          # STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW
    si.wShowWindow = 0
    si.hStdInput = None
    si.hStdOutput = log
    si.hStdError = log
    pi = PI()
    cmdline = ctypes.create_unicode_buffer(subprocess.list2cmdline(cmd))
    if not k32.CreateProcessW(None, cmdline, None, None, True, 0x08000000, None,
                              str(cwd), ctypes.byref(si), ctypes.byref(pi)):
        err = ctypes.get_last_error()
        k32.CloseHandle(log)
        raise OSError(f"CreateProcessW failed ({err})")
    try:
        r = k32.WaitForSingleObject(pi.hProcess, int(timeout * 1000))
        if r == 0x102:                # WAIT_TIMEOUT: kill only our process
            k32.TerminateProcess(pi.hProcess, 1)
            k32.WaitForSingleObject(pi.hProcess, 10000)
            return "timeout"
        code = wintypes.DWORD()
        k32.GetExitCodeProcess(pi.hProcess, ctypes.byref(code))
        return int(code.value)
    finally:
        k32.CloseHandle(pi.hThread)
        k32.CloseHandle(pi.hProcess)
        k32.CloseHandle(log)


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
    ap.add_argument("--subst", nargs="*", default=[],
                    help="KEY=VALUE: replace @KEY@ in the Lua before launch")
    a = ap.parse_args()

    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    text = a.lua.read_text(encoding="utf-8")
    for kv in a.subst:
        key, _, val = kv.partition("=")
        if f"@{key}@" not in text:
            raise SystemExit(f"@{key}@ not in {a.lua.name}")
        text = text.replace(f"@{key}@", val)
    syms = elf_symbols(set(SYM_RE.findall(text)))
    text = SYM_RE.sub(lambda m: f"0x{syms[m.group(1)]:06X}", text)

    # Unique per output folder (e.g. <preset>_run_nes) so parallel runs of
    # different presets never share a stage directory.
    stage = Path(r"C:\tmp\claude_probe") / f"{out.parent.name}_{out.name}"
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
    rom_dir = stage / "rom"
    rom_dir.mkdir()
    rom_copy = rom_dir / ("game" + a.rom.suffix)  # space/comma-free name for EmuHawk argv
    shutil.copy2(a.rom, rom_copy)
    cmd = [short(EMU), "--gdi", f"--config={config}", f"--lua={probe}", str(rom_copy)]
    if os.environ.get("CLAUDE_PROBE_VISIBLE") == "1":
        with (out / "emuhawk.log").open("w", encoding="utf-8") as log:
            p = subprocess.Popen(cmd, cwd=EMU.parent, stdout=log, stderr=subprocess.STDOUT, startupinfo=si)
            try:
                code: int | str = p.wait(timeout=a.timeout)
            except subprocess.TimeoutExpired:
                p.kill()
                p.wait(timeout=10)
                code = "timeout"
    else:
        code = run_on_hidden_desktop(cmd, EMU.parent, out / "emuhawk.log", a.timeout)

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
