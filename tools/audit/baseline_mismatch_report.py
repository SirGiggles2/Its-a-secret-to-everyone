"""Pool every lockstep ratchet baseline into one NES-vs-Genesis RAM list.

    python tools/audit/baseline_mismatch_report.py [--md OUT] [--min-tick N]

Each tools/lockstep/baselines/<preset>.json maps an NES RAM cell to the
first game tick it differed from the NES in that preset (an accepted,
non-KEY difference). A cell that differs from tick 0 is a boot-state
difference (Genesis boots straight into a staged save); cells that start
later are behavior differences: each one is a bug candidate or a
documented Genesis-native / better-than-NES difference (ACCEPTED below).

Output: open cells (bug candidates) then accepted cells with the reason:
cell, NES name, number of presets, the earliest (preset, tick) pairs.
Names come from the lockstep differ (tools/lockstep/diff.py).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "tools" / "lockstep" / "baselines"

# Cells whose NES value is NES-hardware bookkeeping with no gameplay
# function on the Genesis, or where the Genesis is better (user rule
# 2026-09-30: better is fine; worse, or different gameplay, is a bug).
# Each entry: cell -> reason. Reported separately, never silently.
ACCEPTED = {
    0x0341: "RollingSpriteIndex: NES OAM rotation for 8-per-line flicker; Genesis draws all sprites, no flicker (better)",
    0x0342: "FirstSpriteIndex: same NES OAM flicker rotation (better)",
    0x0058: "VScrollAddrHi: NES PPU name-table address of the vertical scroll; Genesis scrolls planes",
    0x00E3: "IsSprite0CheckActive: NES sprite-0 status-bar split; Genesis HUD is a window plane",
    0x00E9: "CurRow: NES row-by-row PPU transfer counter during loads; Genesis loads faster (better)",
    0x00ED: "PrevRow: NES PPU row bookkeeping of the scroll transfer",
    0x005C: "SwitchNameTablesReq: NES pause-menu name-table switch; native Genesis menu (T-165, user: function not memory)",
    0x005D: "CurScanRoomId: NES pause-menu map scan; native Genesis menu (T-165)",
    0x005E: "SubmenuScrollProgress: NES pause-menu scroll; native Genesis menu (T-165)",
    0x00E1: "MenuState: NES pause-menu scroll states; native Genesis menu (T-165)",
    0x00FC: "CurVScroll: NES pause-menu vertical scroll; native Genesis menu (T-165)",
    0x0412: "TriforceGlowTimer ($412+0): one-tick sprite-helper scratch at cave entry, cleared by InitMode_EnterRoom the next tick",
    0x052F: "MazeStep: same value ~1 tick earlier (Genesis runs CheckMazes at the screen edge to stage the next room)",
}

# (preset, first tick) pairs explained for every cell that starts there:
# a transient in a mode the Genesis runs natively, ending in the NES state.
ACCEPTED_ONSETS = {
    ("t013_save", 255): "NES UpdateModeDSave mid-checksum pointer scratch in $C0-$CF (lag frame); Genesis writes the NES end state at save end (mode_save.c)",
    ("t013_save", 256): "same save pointer scratch, NES Sub1 in progress",
    ("save_roundtrip", 131): "same save pointer scratch ($C0-$CF) during mode $0D",
    ("save_roundtrip", 132): "same save pointer scratch, NES Sub1 in progress",
}


def cell_names() -> dict[int, str]:
    sys.path.insert(0, str(ROOT / "tools" / "lockstep"))
    import diff  # type: ignore  (the lockstep differ's Variables.inc map)
    return {a: diff.name(a) for a in range(0x800)}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--md", type=Path)
    ap.add_argument("--min-tick", type=int, default=1)
    args = ap.parse_args()
    pool: dict[int, list[tuple[int, str]]] = {}
    for f in sorted(BASE.glob("*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        for k, t in d.get("cells", {}).items():
            if t >= args.min_tick and (d.get("preset", f.stem), t) not in ACCEPTED_ONSETS:
                pool.setdefault(int(k, 16), []).append((t, d.get("preset", f.stem)))
    names = cell_names()
    rows = ["## Open (bug candidates)", "",
            "| Cell | Name | Presets | Earliest (preset@tick) |", "|---|---|---|---|"]
    acc = ["", "## Accepted (Genesis-native or better)", "",
           "| Cell | Name | Presets | Reason |", "|---|---|---|---|"]
    open_n = 0
    for a in sorted(pool, key=lambda a: (-len(pool[a]), a)):
        hits = sorted(pool[a])
        first = ", ".join(f"{p}@{t}" for t, p in hits[:4])
        if a in ACCEPTED:
            acc.append(f"| ${a:04X} | {names.get(a, '')} | {len(hits)} | {ACCEPTED[a]} |")
        else:
            open_n += 1
            rows.append(f"| ${a:04X} | {names.get(a, '')} | {len(hits)} | {first} |")
    text = "\n".join(rows + acc)
    if args.md:
        args.md.write_text(text + "\n", encoding="utf-8")
    print(text)
    print(f"MISMATCH: {len(pool)} cells differ after tick {args.min_tick - 1} "
          f"across {len(list(BASE.glob('*.json')))} baselines: "
          f"{open_n} open, {len(pool) - open_n} accepted")


if __name__ == "__main__":
    main()
