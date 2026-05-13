#!/usr/bin/env python3
"""Launch Debug.md in BizHawk with the passive human-input recorder.

This launcher intentionally does not drive input. It only boots the current
Debug ROM with record_human_input.lua so player input can be captured exactly.
"""

from __future__ import annotations

import argparse
import ctypes
import os
import subprocess
import time
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LUA = ROOT / "tools" / "debug" / "record_human_input.lua"
ROM = ROOT / "builds" / "Debug.md"


def default_out() -> Path:
    stamp = datetime.now().strftime("input_%Y%m%d_%H%M%S.jsonl")
    return ROOT / "builds" / "reports" / "human_input_recording" / stamp


def short_path(path: Path) -> str:
    raw = str(path.resolve())
    if os.name != "nt":
        return raw
    buf = ctypes.create_unicode_buffer(32768)
    n = ctypes.windll.kernel32.GetShortPathNameW(raw, buf, len(buf))
    return buf.value if n else raw


def find_bizhawk() -> Path:
    env = os.environ.get("CODEX_BIZHAWK_ROOT")
    candidates: list[Path] = []
    if env:
        candidates.append(Path(env) / "EmuHawk.exe")
    candidates.extend([
        Path(r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"),
        Path(r"C:\BizHawk\EmuHawk.exe"),
        Path.home() / "BizHawk" / "EmuHawk.exe",
    ])
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError("EmuHawk.exe not found; set CODEX_BIZHAWK_ROOT")


def focus_process_window(pid: int) -> bool:
    if os.name != "nt":
        return False

    user32 = ctypes.windll.user32
    handles: list[int] = []

    enum_windows_proc = ctypes.WINFUNCTYPE(
        ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p
    )

    @enum_windows_proc
    def enum_window(hwnd, _lparam):
        found_pid = ctypes.c_ulong()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(found_pid))
        if found_pid.value == pid and user32.IsWindowVisible(hwnd):
            handles.append(int(hwnd))
            return False
        return True

    for _ in range(40):
        handles.clear()
        user32.EnumWindows(enum_window, 0)
        if handles:
            hwnd = handles[0]
            user32.ShowWindowAsync(hwnd, 9)
            user32.SetForegroundWindow(hwnd)
            return True
        time.sleep(0.1)
    return False


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args(argv)
    out_path = args.out or default_out()

    if not LUA.is_file():
        raise FileNotFoundError(LUA)
    if not ROM.is_file():
        raise FileNotFoundError(f"missing {ROM}; run Debug.bat")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["HUMAN_INPUT_RECORD_OUT"] = str(out_path.resolve())

    emu = find_bizhawk()
    proc = subprocess.Popen(
        [short_path(emu), f"--lua={short_path(LUA)}", short_path(ROM)],
        cwd=short_path(emu.parent),
        env=env,
    )
    focus_process_window(proc.pid)
    print(f"launched EmuHawk pid={proc.pid}")
    print(f"recording={out_path.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
