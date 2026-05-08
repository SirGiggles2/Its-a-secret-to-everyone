#!/usr/bin/env python3
"""Boot RoomRom in BizHawk and prove live UW room $73 collision.

The proof compares Genesis 68K RAM `s_uw_tile_walkable` against the restored
Apr 30 captured-blob collision model for L1Q1 room $73, including current
door-state overrides.
"""

from __future__ import annotations

import ctypes
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ROM = ROOT / "RoomRom" / "out" / "Debug.md"
ELF = ROOT / "RoomRom" / "out" / "rom.out"
NM = ROOT / "build" / "toolchain" / "sgdk_bin" / "bin" / "nm.exe"
NES_JSON = ROOT / "RoomRom" / "out" / "nes_uw_level1_quest1_orig.json"
EMU = (ROOT.parent / "VDP rebirth tools and asms" /
       "BizHawk-2.11-win-x64" / "EmuHawk.exe")
OUT_DIR = ROOT / "build" / "probes" / "ph5"
LUA = OUT_DIR / "probe_uw_collision_boot.lua"
REPORT = OUT_DIR / "uw_collision_boot_proof.json"
SCREENSHOT = OUT_DIR / "uw_collision_boot_proof.png"

ROOM_ID = 0x73
WALL_TILE_IDS = {
    0xB8, 0xBC,
    0xC0, 0xC4, 0xC8, 0xCC,
    0xD0, 0xD4, 0xD8, 0xDC, 0xDE,
    0xE0,
    0xF5, 0xF6,
}

DOOR_E = 0
DOOR_W = 1
DOOR_S = 2
DOOR_N = 3
DOOR_OPEN = 0
DOOR_KEY = 5

DOOR_TYPES_R73 = {
    DOOR_E: DOOR_OPEN,
    DOOR_W: DOOR_OPEN,
    DOOR_S: DOOR_OPEN,
    DOOR_N: DOOR_KEY,
}

WALK_MT = {
    DOOR_E: ((14, 5), (15, 5)),
    DOOR_W: ((1, 5), (0, 5)),
    DOOR_S: ((8, 9), (8, 10)),
    DOOR_N: ((8, 1), (8, 0)),
}

OPEN_PATCHES = {
    DOOR_E: ((28, 10), (29, 10), (28, 11), (29, 11)),
    DOOR_W: ((2, 10), (3, 10), (2, 11), (3, 11)),
    DOOR_S: ((15, 18), (16, 18), (15, 19), (16, 19)),
    DOOR_N: ((15, 2), (16, 2), (15, 3), (16, 3)),
}


def short_path(path: Path) -> str:
    buf = ctypes.create_unicode_buffer(260)
    rc = ctypes.windll.kernel32.GetShortPathNameW(str(path), buf, len(buf))
    if rc == 0:
        return str(path)
    return buf.value


def symbol_offsets() -> dict[str, int]:
    output = subprocess.check_output([str(NM), "-n", str(ELF)],
                                     text=True, encoding="utf-8",
                                     errors="replace")
    want = {"s_uw_tile_walkable", "s_link_x", "s_link_y", "s_room_id"}
    found: dict[str, int] = {}
    for line in output.splitlines():
        m = re.match(r"([0-9a-fA-F]+)\s+\S\s+(\S+)$", line.strip())
        if not m:
            continue
        addr = int(m.group(1), 16)
        name = m.group(2)
        if name in want:
            found[name] = addr & 0xFFFF
    missing = want - found.keys()
    if missing:
        raise RuntimeError(f"missing symbols: {sorted(missing)}")
    return found


def expected_mask() -> list[list[int]]:
    payload = json.loads(NES_JSON.read_text(encoding="utf-8"))
    room = next(r for r in payload["results"] if r["room_id"] == ROOM_ID)
    nt = room["nt"]
    mask = [[0 for _row in range(22)] for _col in range(32)]

    for mt_col in range(16):
        for mt_row in range(11):
            walk = 0 if nt[mt_row * 2 + 8][mt_col * 2] in WALL_TILE_IDS else 1
            for dc in (0, 1):
                for dr in (0, 1):
                    mask[mt_col * 2 + dc][mt_row * 2 + dr] = walk

    for door_dir, door_type in DOOR_TYPES_R73.items():
        open_value = 1 if door_type == DOOR_OPEN else 0
        for mt_col, mt_row in WALK_MT[door_dir]:
            for dc in (0, 1):
                for dr in (0, 1):
                    mask[mt_col * 2 + dc][mt_row * 2 + dr] = open_value
        for col, row in OPEN_PATCHES[door_dir]:
            mask[col][row] = open_value

    return mask


def lua_bool_grid(mask: list[list[int]]) -> str:
    rows = []
    for col in range(32):
        rows.append("{" + ",".join(str(mask[col][row]) for row in range(22)) + "}")
    return "{\n" + ",\n".join(rows) + "\n}"


def write_lua(symbols: dict[str, int], mask: list[list[int]]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    report = str(REPORT).replace("\\", "\\\\")
    screenshot = str(SCREENSHOT).replace("\\", "\\\\")
    LUA.write_text(f"""local OUT = "{report}"
local SCREENSHOT = "{screenshot}"
local TILE_ADDR = 0x{symbols['s_uw_tile_walkable']:04X}
local LINK_X_ADDR = 0x{symbols['s_link_x']:04X}
local LINK_Y_ADDR = 0x{symbols['s_link_y']:04X}
local ROOM_ADDR = 0x{symbols['s_room_id']:04X}
local EXPECTED = {lua_bool_grid(mask)}

local function read_u8(addr)
  return memory.read_u8(addr, "68K RAM") or 0
end

local function read_s16(addr)
  return memory.read_s16_be(addr, "68K RAM") or 0
end

for _ = 1, 180 do
  emu.frameadvance()
end

local diff = {{}}
local walk = 0
local block = 0
for col = 0, 31 do
  for row = 0, 21 do
    local actual = read_u8(TILE_ADDR + col * 22 + row)
    local expected = EXPECTED[col + 1][row + 1]
    if actual ~= 0 then walk = walk + 1 else block = block + 1 end
    if ((actual ~= 0) and 1 or 0) ~= expected then
      diff[#diff + 1] = string.format(
        '{{"col":%d,"row":%d,"expected":%d,"actual":%d}}',
        col, row, expected, actual)
    end
  end
end

for row = 0, 21 do
  for col = 0, 31 do
    local actual = read_u8(TILE_ADDR + col * 22 + row)
    local fill = actual ~= 0 and 0x7000D050 or 0x70E02028
    gui.drawBox(8 + col * 8, 56 + row * 8,
                8 + col * 8 + 7, 56 + row * 8 + 7,
                0x50000000, fill)
  end
end
gui.drawBox(0, 0, 255, 18, 0xC0000000, 0xC0000000)
gui.text(4, 3, "UW collision proof: diff=" .. tostring(#diff) ..
    " room=$" .. string.format("%02X", read_u8(ROOM_ADDR)),
    0xFFFFFFFF, 0xC0000000)
emu.frameadvance()
client.screenshot(SCREENSHOT)

local f = assert(io.open(OUT, "w"))
f:write('{{\\n')
f:write('  "pass": ', (#diff == 0) and 'true' or 'false', ',\\n')
f:write('  "room": ', read_u8(ROOM_ADDR), ',\\n')
f:write('  "link_x": ', read_s16(LINK_X_ADDR), ',\\n')
f:write('  "link_y": ', read_s16(LINK_Y_ADDR), ',\\n')
f:write('  "tile_addr": ', TILE_ADDR, ',\\n')
f:write('  "walkable_count": ', walk, ',\\n')
f:write('  "blocked_count": ', block, ',\\n')
f:write('  "diff_count": ', #diff, ',\\n')
f:write('  "diff": [', table.concat(diff, ","), ']\\n')
f:write('}}\\n')
f:close()
client.exit()
""", encoding="utf-8")


def run_bizhawk() -> int:
    if not EMU.exists():
        raise FileNotFoundError(EMU)
    if not ROM.exists():
        raise FileNotFoundError(ROM)
    if not ELF.exists():
        raise FileNotFoundError(ELF)

    subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "Get-Process EmuHawk -ErrorAction SilentlyContinue | Stop-Process -Force"],
        check=False,
    )

    proc = subprocess.run(
        [short_path(EMU), f"--lua={short_path(LUA)}", short_path(ROM)],
        cwd=short_path(EMU.parent),
        check=False,
    )
    return proc.returncode


def main() -> int:
    symbols = symbol_offsets()
    mask = expected_mask()
    write_lua(symbols, mask)
    rc = run_bizhawk()
    if rc != 0:
        print(f"BizHawk exited with code {rc}", file=sys.stderr)
        return rc
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    print(json.dumps(report, indent=2))
    print(f"screenshot={SCREENSHOT}")
    return 0 if report.get("pass") else 2


if __name__ == "__main__":
    raise SystemExit(main())
