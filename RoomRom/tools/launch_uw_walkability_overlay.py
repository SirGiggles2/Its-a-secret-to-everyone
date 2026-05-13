#!/usr/bin/env python3
"""Launch the passive UW walkability overlay against builds/Debug.md."""

from __future__ import annotations

import ctypes
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LUA = ROOT / "RoomRom" / "tools" / "uw_walkability_overlay.lua"
ROM = ROOT / "builds" / "Debug.md"
ELF = ROOT / "build" / "debug_project" / "out" / "Debug.out"
NM = ROOT / "build" / "toolchain" / "sgdk_bin" / "bin" / "nm.exe"

SYMBOL_ENV = {
    "s_uw_tile_walkable": "CODEX_UW_OVERLAY_TILE_WALKABLE",
}

PLAYER_OFFSETS = {
    "CODEX_UW_OVERLAY_LINK_X": 0,
    "CODEX_UW_OVERLAY_LINK_Y": 2,
}


def short_path(path: Path) -> str:
    raw = str(path.resolve())
    if os.name != "nt":
        return raw
    buf = ctypes.create_unicode_buffer(32768)
    n = ctypes.windll.kernel32.GetShortPathNameW(raw, buf, len(buf))
    return buf.value if n else raw


def ram_offset(addr: int) -> int:
    return addr & 0xFFFF


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


def resolve_symbols() -> dict[str, int]:
    if not ELF.is_file():
        raise FileNotFoundError(f"missing {ELF}; run Debug.bat")
    result = subprocess.run(
        [str(NM), "-n", str(ELF)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    wanted = set(SYMBOL_ENV) | {"players"}
    found: dict[str, int] = {}
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[2] in wanted:
            found[parts[2]] = ram_offset(int(parts[0], 16))
    missing = sorted(wanted - found.keys())
    if missing:
        raise RuntimeError(f"missing Debug symbols: {missing}")
    return found


def stop_bizhawk() -> None:
    subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-Command",
            "Get-Process EmuHawk -ErrorAction SilentlyContinue | Stop-Process -Force",
        ],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main() -> int:
    if not LUA.is_file():
        raise FileNotFoundError(LUA)
    if not ROM.is_file():
        raise FileNotFoundError(f"missing {ROM}; run Debug.bat")

    symbols = resolve_symbols()
    env = os.environ.copy()
    for symbol, env_name in SYMBOL_ENV.items():
        env[env_name] = str(ram_offset(symbols[symbol]))
    for env_name, offset in PLAYER_OFFSETS.items():
        env[env_name] = str(ram_offset(symbols["players"] + offset))

    emu = find_bizhawk()
    stop_bizhawk()
    proc = subprocess.Popen(
        [short_path(emu), f"--lua={short_path(LUA)}", short_path(ROM)],
        cwd=short_path(emu.parent),
        env=env,
    )
    print(f"launched EmuHawk pid={proc.pid}")
    print("The overlay is passive; enter debug gameplay with A+B+C at title.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
