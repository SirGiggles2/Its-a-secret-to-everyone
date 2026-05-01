"""Hard gate: OW PALRAM static extraction + generated header shape.

Source-first path: PALRAM bytes come from extract_ow_palram_from_rom.py
which reads the LevelInfoOW palette transfer buffer directly out of the
NES ROM PRG. Verifier checks:
  - nes_ow_palram_static.json exists with orig + redux keys, each 32 bytes
  - palram[0] == 0x0F (NES universal backdrop)
  - generated roomrom_ow_palette.{c,h} exposes [2][32] shape

UW palettes still come from g_uw_room_palette[636][32] (existing runtime
capture path, unchanged).

Exit code 0 = pass, 1 = fail.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "out" / "nes_ow_palram_static.json"
HEADER = ROOT / "src" / "roomrom_ow_palette.h"
SOURCE = ROOT / "src" / "roomrom_ow_palette.c"


def fail(msg):
    print(f"verify_bg_palette_manifest: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def check_input():
    if not INPUT.exists():
        fail(f"missing {INPUT}; run extract_ow_palram_from_rom.py first")
    payload = json.loads(INPUT.read_text(encoding="utf-8"))
    for label in ("orig", "redux"):
        if label not in payload:
            fail(f"{INPUT}: missing key {label!r}")
        pr = payload[label]
        if len(pr) != 32:
            fail(f"{label}: PALRAM len {len(pr)} != 32")
        if pr[0] != 0x0F:
            fail(f"{label}: palram[0]=0x{pr[0]:02X} != 0x0F")
        if all(b == 0 for b in pr):
            fail(f"{label}: all-zero PALRAM (extraction invalid)")


def check_generated():
    if not HEADER.exists():
        fail(f"missing {HEADER}")
    text = HEADER.read_text(encoding="utf-8")
    if not re.search(r"g_roomrom_ow_palram\[2\]\[32\]", text):
        fail("header shape != [2][32]")
    if not SOURCE.exists():
        fail(f"missing {SOURCE}")


def main():
    check_input()
    check_generated()
    print("verify_bg_palette_manifest: OK")


if __name__ == "__main__":
    main()
