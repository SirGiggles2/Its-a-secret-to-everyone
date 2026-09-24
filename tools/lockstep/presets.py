"""Lockstep presets ("cheat cards"): one spec -> identical starting state on
NES and Genesis, entered through each console's real load path.

NES side (reference/aldonunez):
  Save file A, slot 0 (Z_01.asm SaveFileAAddressSets, Variables.inc):
    name $6002 (8), items $601A ($28), world flags $6092 ($180),
    single bytes $6512 (IsSaveSlotActive), $6515, $6518, $651B (quest).
  Validity (Z_02.asm UpdateMode0Demo_Sub1 / CalculateFileAChecksum):
    open marker $651E+slot = $5A, close marker $6521+slot = $A5,
    FileAChecksums $6524+2*slot = [hi, lo] of the 16-bit byte sum of
    name + items + world flags + the four single bytes.
  File B skipped when IsSaveFileBCommitted $652A+slot != 0; set $FF for
  all three slots so uninitialized file B never overwrites file A.
  New file contents (Z_02.asm UpdateModeERegister): items zero except
  HeartValues(+$18)=$22, HeartPartial(+$19)=$FF, MaxBombs(+$25)=$08.

Genesis side (src/state/save_serializer.*): slot 0 payload 43 bytes =
  $5A $A5 + 40 Items bytes + XOR of bytes 0..41; cart SRAM logical byte k
  at BizHawk "SRAM" domain index 2k+1 (probe_save_persistence.lua).
  Genesis load restores ONLY the Items block (T-100 extends it), so world
  flags/name/quest are NES-only until then; the differ reports that.

Spec file (JSON): {"name": "...", "file_name": "LINK", "quest": 0,
  "items": {"InvBombs": 4, ...} (names from Variables.inc, offsets inside
  Items $657..$67E), "world_flags": {"0x67F": 1, ...}, "script": [[frames,
  "UDLRABSs"], ...]}  (s = Select/C, S = Start).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VARS = ROOT / "reference" / "aldonunez" / "Variables.inc"

ITEMS_BASE = 0x657
ITEMS_LEN = 0x28
WF_BASE = 0x67F
WF_LEN = 0x180

SLOT0 = {
    "name": 0x6002, "items": 0x601A, "wf": 0x6092,
    "singles": (0x6512, 0x6515, 0x6518, 0x651B),
    "open": 0x651E, "close": 0x6521, "cksum": 0x6524,
}
FILE_B_COMMITTED = 0x652A

NES_CHARS = {**{str(d): d for d in range(10)},
             **{chr(ord("A") + i): 0x0A + i for i in range(26)}, " ": 0x24}


def variables() -> dict[str, int]:
    out = {}
    for line in VARS.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\s*(\w+)\s*:=\s*\$([0-9A-Fa-f]+)", line)
        if m:
            out[m.group(1)] = int(m.group(2), 16)
    return out


def encode_name(name: str) -> list[int]:
    name = name.upper()[:8].ljust(8)
    return [NES_CHARS[c] for c in name]


def new_file_items() -> list[int]:
    items = [0] * ITEMS_LEN
    items[0x18] = 0x22  # HeartValues: 3 containers, 3 full
    items[0x19] = 0xFF  # HeartPartial
    items[0x25] = 0x08  # MaxBombs
    return items


def build(spec: dict) -> dict:
    v = variables()
    items = new_file_items()
    for key, val in spec.get("items", {}).items():
        addr = v[key] if key in v else int(key, 0)
        if not ITEMS_BASE <= addr < ITEMS_BASE + ITEMS_LEN:
            raise SystemExit(f"{key} ${addr:X} outside Items block")
        items[addr - ITEMS_BASE] = int(val) & 0xFF
    wf = [0] * WF_LEN
    for key, val in spec.get("world_flags", {}).items():
        addr = int(key, 0)
        if not WF_BASE <= addr < WF_BASE + WF_LEN:
            raise SystemExit(f"world flag ${addr:X} outside $67F..$7FE")
        wf[addr - WF_BASE] = int(val) & 0xFF
    name = encode_name(spec.get("file_name", "LINK"))
    if name[:5] == encode_name("ZELDA")[:5]:
        raise SystemExit("name ZELDA forces quest 2 on NES; set quest explicitly")
    quest = int(spec.get("quest", 0))
    singles = [1, 0, 0, quest]  # active, $6515, $6518 (death count ptr), quest

    total = sum(name) + sum(items) + sum(wf) + sum(singles)
    nes: dict[int, int] = {}
    for i, b in enumerate(name):
        nes[SLOT0["name"] + i] = b
    for i, b in enumerate(items):
        nes[SLOT0["items"] + i] = b
    for i, b in enumerate(wf):
        nes[SLOT0["wf"] + i] = b
    for a, b in zip(SLOT0["singles"], singles):
        nes[a] = b
    nes[SLOT0["open"]] = 0x5A
    nes[SLOT0["close"]] = 0xA5
    nes[SLOT0["cksum"]] = (total >> 8) & 0xFF
    nes[SLOT0["cksum"] + 1] = total & 0xFF
    for s in range(3):
        nes[FILE_B_COMMITTED + s] = 0xFF

    payload = [0x5A, 0xA5] + items
    x = 0
    for b in payload:
        x ^= b
    gen = payload + [x]

    return {"name": spec["name"], "nes_wram": nes, "gen_slot0": gen,
            "items": items, "script": spec.get("script", [])}


def to_lua(p: dict) -> str:
    nes = ",".join(f"[0x{a:04X}]=0x{b:02X}" for a, b in sorted(p["nes_wram"].items()))
    gen = ",".join(f"0x{b:02X}" for b in p["gen_slot0"])
    script = ",".join(f'{{{n},"{btn}"}}' for n, btn in p["script"])
    items = ",".join(f"0x{b:02X}" for b in p["items"])
    return (f'PRESET={{name="{p["name"]}",nes_wram={{{nes}}},gen_slot0={{{gen}}},'
            f'items={{{items}}},script={{{script}}}}}\n')


if __name__ == "__main__":
    import sys
    spec = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    p = build(spec)
    Path(sys.argv[2]).write_text(to_lua(p), encoding="utf-8")
    print(f"preset {p['name']}: nes {len(p['nes_wram'])} bytes, gen {len(p['gen_slot0'])} bytes")
