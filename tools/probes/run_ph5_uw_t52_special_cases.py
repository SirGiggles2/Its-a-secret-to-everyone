#!/usr/bin/env python3
"""Launch the Phase 5 T52 UW collision probe against builds/Debug.md."""

from __future__ import annotations

import argparse
import ctypes
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LUA = ROOT / "tools" / "probes" / "ph5_uw_t52_special_cases.lua"
ROM = ROOT / "builds" / "Debug.md"
ELF = ROOT / "build" / "debug_project" / "out" / "Debug.out"
NM = ROOT / "build" / "toolchain" / "sgdk_bin" / "bin" / "nm.exe"
OUT_CASES = ROOT / "build" / "probes" / "ph5" / "t52" / "special_cases.json"
OUT_WSTOP = ROOT / "build" / "probes" / "ph5" / "t52" / "wall_stop.json"

SYMBOL_ENV = {
    "s_room_id": "CODEX_T52_ROOM_ID",
    "s_scene": "CODEX_T52_SCENE",
    "s_uw_level": "CODEX_T52_UW_LEVEL",
    "s_link_dir": "CODEX_T52_LINK_DIR",
    "s_uw_walkable": "CODEX_T52_WALKABLE",
}

PLAYER_OFFSETS = {
    "CODEX_T52_LINK_X": 0,
    "CODEX_T52_LINK_Y": 2,
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
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--keep-bizhawk", action="store_true")
    args = parser.parse_args()

    if not LUA.is_file():
        raise FileNotFoundError(LUA)
    if not ROM.is_file():
        raise FileNotFoundError(f"missing {ROM}; run Debug.bat")

    OUT_CASES.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["CODEX_T52_OUT_CASES"] = str(OUT_CASES)
    env["CODEX_T52_OUT_WSTOP"] = str(OUT_WSTOP)

    symbols = resolve_symbols()
    for symbol, env_name in SYMBOL_ENV.items():
        env[env_name] = str(ram_offset(symbols[symbol]))
    for env_name, offset in PLAYER_OFFSETS.items():
        env[env_name] = str(ram_offset(symbols["players"] + offset))

    if not args.keep_bizhawk:
        stop_bizhawk()
    emu = find_bizhawk()
    proc = subprocess.run(
        [short_path(emu), f"--lua={short_path(LUA)}", short_path(ROM)],
        cwd=short_path(emu.parent),
        env=env,
        timeout=args.timeout,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"BizHawk exited with {proc.returncode}")
    if not OUT_CASES.is_file():
        raise RuntimeError(f"probe did not write {OUT_CASES}")
    if not OUT_WSTOP.is_file():
        raise RuntimeError(f"probe did not write {OUT_WSTOP}")
    print(f"wrote {OUT_CASES}")
    print(f"wrote {OUT_WSTOP}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
