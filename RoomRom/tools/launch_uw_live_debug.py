#!/usr/bin/env python3
"""Launch RoomRom in BizHawk with the live UW walk debugger overlay."""

from __future__ import annotations

import ctypes
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LUA = ROOT / "RoomRom" / "tools" / "uw_live_walk_debug.lua"
ROM = ROOT / "builds" / "Debug.md"
ELF = ROOT / "build" / "debug_project" / "out" / "Debug.out"
NM = ROOT / "build" / "toolchain" / "sgdk_bin" / "bin" / "nm.exe"
OUT = ROOT / "build" / "reports" / "uw_live_walk_debug" / "latest.json"

SYMBOL_ENV = {
    "s_uw_tile_walkable": "CODEX_UW_LIVE_TILE_WALKABLE",
    "s_door_types": "CODEX_UW_LIVE_DOOR_TYPES",
    "s_cur_opened": "CODEX_UW_LIVE_CUR_OPENED",
    "s_room_id": "CODEX_UW_LIVE_ROOM_ID",
    "s_scene": "CODEX_UW_LIVE_SCENE",
    "s_link_dir": "CODEX_UW_LIVE_LINK_DIR",
    "s_link_keys": "CODEX_UW_LIVE_LINK_KEYS",
    "s_link_grid_offset": "CODEX_UW_LIVE_GRID_OFFSET",
    "s_link_pos_frac": "CODEX_UW_LIVE_POS_FRAC",
    "s_doorway_dir": "CODEX_UW_LIVE_DOORWAY_DIR",
    "s_scroll_state": "CODEX_UW_LIVE_SCROLL_STATE",
    "s_scroll_frame": "CODEX_UW_LIVE_SCROLL_FRAME",
}

PLAYER_OFFSETS = {
    "CODEX_UW_LIVE_LINK_X": 0,
    "CODEX_UW_LIVE_LINK_Y": 2,
    "CODEX_UW_LIVE_LINK_FACE": 7,
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
    for c in candidates:
        if c.is_file():
            return c
    raise FileNotFoundError("EmuHawk.exe not found; set CODEX_BIZHAWK_ROOT")


def resolve_symbols() -> dict[str, int]:
    result = subprocess.run(
        [str(NM), "-n", str(ELF)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    wanted = set(SYMBOL_ENV) | {"players"}
    out: dict[str, int] = {}
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[2] in wanted:
            out[parts[2]] = ram_offset(int(parts[0], 16))
    missing = sorted(wanted - out.keys())
    if missing:
        raise RuntimeError(f"missing symbols: {missing}")
    return out


def stop_bizhawk() -> None:
    subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command",
         "Get-Process EmuHawk -ErrorAction SilentlyContinue | Stop-Process -Force"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main() -> int:
    if not LUA.is_file():
        raise FileNotFoundError(LUA)
    if not ROM.is_file() or not ELF.is_file():
        raise FileNotFoundError("missing Debug build output; run Debug.bat")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["CODEX_UW_LIVE_OUT_JSON"] = str(OUT)
    symbols = resolve_symbols()
    for symbol, env_name in SYMBOL_ENV.items():
        env[env_name] = str(ram_offset(symbols[symbol]))
    for env_name, offset in PLAYER_OFFSETS.items():
        env[env_name] = str(ram_offset(symbols["players"] + offset))

    emu = find_bizhawk()
    stop_bizhawk()
    args = [f"--lua={short_path(LUA)}", short_path(ROM)]
    proc = subprocess.Popen(
        [short_path(emu), *args],
        cwd=short_path(emu.parent),
        env=env,
    )
    print(f"launched EmuHawk pid={proc.pid}")
    print(f"snapshot={OUT}")
    print("Stop Link at the bad spot, screenshot the overlay, then tell Codex to read latest.json.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
