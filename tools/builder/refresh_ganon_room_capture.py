"""Replace the stale L9Q1 $42 forced-mode-4 capture with live mode-3 data.

Development regeneration only. The input is produced by
`python tools/parity/run_nes_ganon_nt.py mode3` against the locally supplied
NES ROM. No ROM or raw capture is checked into the builder package.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/builder"))
import gen_uw_room_tiles as rooms  # noqa: E402

CAPTURE = ROOT / "builds/reports/recovery/t004-ganon-nt-mode3"
SOURCE = ROOT / "RoomRom/out/nes_uw_level9_quest1_orig.json"


def main() -> int:
    ciram = (CAPTURE / "t004_ganon_nt_combat.bin").read_bytes()
    pal = (CAPTURE / "t004_ganon_nt_combat_pal.bin").read_bytes()
    report = (CAPTURE / "t004_ganon_nt.txt").read_text(encoding="utf-8")
    if len(ciram) != 2048 or len(pal) != 32:
        raise SystemExit("incomplete live NES CIRAM/PALRAM capture")
    if "combat mode=05 sub=00 level=09 room=42 phase=02 D42=28" not in report:
        raise SystemExit("capture did not reach Ganon combat with installed D42=$28")
    nt = [list(ciram[r * 32:(r + 1) * 32]) for r in range(30)]
    attr = list(ciram[0x3C0:0x400])
    expected = rooms.compose("UW2", 1, 0x42)
    actual = [b for row in nt[8:30] for b in row]
    if actual != expected:
        raise SystemExit("live NES Ganon NT does not match ROM-table generator")

    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    rows = [r for r in source["results"] if r.get("room_id") == 0x42]
    if len(rows) != 1:
        raise SystemExit("expected exactly one L9Q1 Ganon capture")
    row = rows[0]
    row.update(nt=nt, attr=attr, palram=list(pal),
               capture_source="T-004 live NES mode-3 room layout, Ganon phase 2")
    SOURCE.write_text(json.dumps(source, indent=2) + "\n", encoding="utf-8")

    # The aggregate source contains 638 captured entries. The 11 synthetic
    # boss entries are reconstructed from that captured base, then re-emitted.
    # inject_boss_rooms.py inventories the current blob, so emit the captured
    # base first to avoid mistaking old synthetic entries for source captures.
    for script in (ROOT / "RoomRom/tools/verify_uw_aggregate.py",
                   ROOT / "RoomRom/tools/gen_uw_blob.py",
                   ROOT / "tools/builder/inject_boss_rooms.py",
                   ROOT / "RoomRom/tools/gen_uw_blob.py"):
        subprocess.run([sys.executable, str(script)], cwd=ROOT, check=True)
    emitted = (ROOT / "RoomRom/src/uw_room_blob.c").read_text(encoding="utf-8")
    if "g_uw_room_nt[649][704]" not in emitted:
        raise SystemExit("regeneration lost synthetic boss-room entries")
    print("L9Q1 $42: 704/704 live NT bytes match generator; 649-room blob refreshed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
