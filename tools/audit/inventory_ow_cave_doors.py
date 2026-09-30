"""Inventory Q1/Q2 cave selectors and OW tile objects from ROM-derived blobs.

Reads the committed extracted LevelBlock/column heap. Tile-object presence is
not proof of an entrance; live probes own behavior and reachability.
"""
from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = json.loads((ROOT / "data/rooms/MANIFEST.json").read_text())
HEAP_OFFSETS = MANIFEST["ow_heap_offsets"]
LAYOUT_OFF = next(e["byte_offset"] for e in MANIFEST["overworld"]
                  if isinstance(e, dict) and e.get("name") == "RoomLayoutsOW")
HEAP_OFF = next(e["byte_offset"] for e in MANIFEST["overworld"]
                if isinstance(e, dict) and e.get("name") == "ColumnHeapOWBlob")


def c_bytes(path: Path, symbol: str) -> bytes:
    source = path.read_text(encoding="utf-8")
    body = source[source.index("{", source.index(symbol)) + 1:]
    body = body[:body.index("}")]
    return bytes(int(v, 16) for v in re.findall(r"0x([0-9A-Fa-f]{2})", body))


def asm_table(name: str, count: int) -> bytes:
    asm = (ROOT / "reference/aldonunez/Z_05.asm").read_text(encoding="utf-8")
    body = asm.split(f"\n{name}:", 1)[1].split("\n\n", 1)[0]
    values = bytes(int(v, 16) for v in re.findall(r"\$([0-9A-Fa-f]{2})", body))
    assert len(values) >= count, (name, len(values), count)
    return values[:count]


def column(blob: bytes, layout_id: int, col: int) -> list[int]:
    desc = blob[LAYOUT_OFF + layout_id * 16 + col]
    heap_idx, col_in_heap = desc >> 4, desc & 15
    base = HEAP_OFF + HEAP_OFFSETS[heap_idx]
    pos = 0
    while True:
        if blob[base + pos] & 0x80:
            if col_in_heap == 0:
                break
            col_in_heap -= 1
        pos += 1
    base += pos
    result = []
    repeat = 0
    while len(result) < 11:
        value = blob[base]
        result.append(value & 0x3F)
        if value & 0x40:
            repeat ^= 0x40
            if repeat:
                continue
        base += 1
    return result


def main() -> None:
    ow = c_bytes(ROOT / "data/rooms/overworld.c", "rooms_overworld")
    uw = c_bytes(ROOT / "data/rooms/dungeons.c", "rooms_dungeons")
    # NES raw square indexes $38-$3F read into the adjacent table.
    primary = asm_table("PrimarySquaresOW", 56) + asm_table("SecondarySquaresOW", 8)
    manifest_entries = {e["name"]: e for e in MANIFEST["dungeons"]
                        if isinstance(e, dict) and "name" in e}
    offs = manifest_entries["LevelBlockAttrsBQ2ReplacementOffsets"]["byte_offset"]
    vals = manifest_entries["LevelBlockAttrsBQ2ReplacementValues"]["byte_offset"]
    q2 = bytearray(ow[:768])
    for room, value in zip(uw[offs:offs + 8], uw[vals:vals + 8]):
        q2[128 + room] = value
    for room, value in ((11, 0x7B), (60, 0x7B), (116, 0x5A)):
        q2[384 + room] = value
    for room in (60, 116):
        q2[room] = 0x72
    q2[640 + 60], q2[640 + 116] = 1, 0

    counts = Counter()
    for quest, attrs in ((1, ow), (2, q2)):
        for room in range(128):
            selector = attrs[128 + room] & 0xFC
            if selector < 0x40 or selector > 0x8C:
                continue
            layout_id = attrs[384 + room] & 0x7F
            objects: set[int] = set()
            for col in range(16):
                for sq in column(ow, layout_id, col):
                    tile = primary[sq]
                    if 0xE5 <= tile <= 0xEA:
                        objects.add(tile)
            obj = ",".join(f"{x:02X}" for x in sorted(objects)) or "--"
            print(f"Q{quest} {room:02X} cave={0x6A + ((selector - 0x40) >> 2):02X} "
                  f"selector={selector:02X} layout={layout_id:02X} "
                  f"attrF={attrs[640 + room]:02X} objects={obj}")
            counts[(quest, obj)] += 1
    print("summary")
    for (quest, obj), n in sorted(counts.items()):
        print(f"Q{quest} objects={obj} rooms={n}")


if __name__ == "__main__":
    main()
