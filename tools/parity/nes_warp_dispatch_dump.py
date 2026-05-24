"""
Phase A NES probe — read LevelBlockOW.dat (byte-extracted from NES Zelda 1
PRG ROM, 768 bytes = 6 attrs * 128 rooms) and emit the per-OW-room warp
dispatch table per Z_05.asm:HandleWarpOW (line 7313-7368).

NES dispatch (Z_05.asm:7338-7368):
    attr_b_fc = LevelBlockAttrsB[room_id] & $FC

    attr_b_fc < $40           -> Mode $02 (load level), level = attr_b_fc >> 2
    attr_b_fc == $50          -> Mode $0C (shortcut cave, Mode C)
    attr_b_fc != $50, >= $40  -> Mode $0B (regular cave, Mode B)

Cave-id derivation is per-mode (handled in InitCave / Z_06.asm), not in
HandleWarpOW. We emit the raw attr_b_fc + mode + level here; cave-id
mapping is added in the Gen-side counterpart after we cross-reference.

Outputs:
  build/probes/phaseA/nes_attr_b_dump.txt   - human-readable per-room table
  tools/parity/warp_routes_expected.json    - machine-readable oracle
"""

from __future__ import annotations

import json
import pathlib

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
DAT_PATH = REPO_ROOT / "reference" / "aldonunez" / "dat" / "LevelBlockOW.dat"
TXT_OUT = REPO_ROOT / "build" / "probes" / "phaseA" / "nes_attr_b_dump.txt"
JSON_OUT = REPO_ROOT / "tools" / "parity" / "warp_routes_expected.json"

# LevelBlockOW.dat layout: 6 attribute tables * 128 bytes each.
ATTR_A_OFFSET = 0
ATTR_B_OFFSET = 128
ATTR_C_OFFSET = 256
ATTR_D_OFFSET = 384
ATTR_E_OFFSET = 512
ATTR_F_OFFSET = 640
TABLE_LEN = 128


def classify(attr_b_fc: int) -> dict:
    """Return dispatch metadata for a single attr_b_fc value.

    Cave-id derivation: 19 caves total (IDs $6A..$7C). Z_01.asm:53-56
    `OverworldPersonTextSelectors[20]` indexes by cave_idx 0..19 (entry 0
    unused-by-NES-convention). NES sets cave_id via room-loaded ObjType+1
    in Mode $0B/$0C entry; the OW-side derivation comes from attr_b_fc:

        cave_idx = (attr_b_fc - $40) >> 2     # 0..19 for $40..$8C
        cave_id  = $6A + cave_idx             # $6A..$7D

    Cave_id $7D corresponds to attr_b_fc $8C which appears in 6 OW rooms;
    NES gameplay rarely fires it (no entrance tile in those rooms), so
    the 19-vs-20 inventory discrepancy resolves: 20 derivable cave_ids,
    19 actually reachable in NES gameplay. Phase E live-NES sweep
    validates which are real.
    """
    if attr_b_fc == 0x00:
        return {
            "category": "no_warp",
            "mode": None,
            "level": None,
            "cave_id": None,
        }
    if attr_b_fc < 0x40:
        # Dungeon entry. NES: level = attr_b_fc >> 2 (Z_05.asm:7362-7366).
        return {
            "category": "dungeon",
            "mode": 0x02,
            "level": attr_b_fc >> 2,
            "cave_id": None,
        }
    cave_id = 0x6A + ((attr_b_fc - 0x40) >> 2)
    if attr_b_fc == 0x50:
        # Shortcut cave (Mode C). Z_05.asm:7350-7353 INY path.
        return {
            "category": "cave_shortcut",
            "mode": 0x0C,
            "level": None,
            "cave_id": cave_id,
        }
    # Regular cave (Mode B). Z_05.asm:7344-7349.
    return {
        "category": "cave_regular",
        "mode": 0x0B,
        "level": None,
        "cave_id": cave_id,
    }


def main() -> int:
    raw = DAT_PATH.read_bytes()
    if len(raw) != 768:
        raise SystemExit(
            f"LevelBlockOW.dat unexpected length {len(raw)} (expected 768)"
        )

    lba_b = raw[ATTR_B_OFFSET : ATTR_B_OFFSET + TABLE_LEN]

    rows = []
    counts = {
        "no_warp": 0,
        "dungeon": 0,
        "cave_regular": 0,
        "cave_shortcut": 0,
    }
    for room_id in range(TABLE_LEN):
        raw_attr_b = lba_b[room_id]
        attr_b_fc = raw_attr_b & 0xFC
        meta = classify(attr_b_fc)
        rows.append(
            {
                "room_id": room_id,
                "raw_attr_b": raw_attr_b,
                "attr_b_fc": attr_b_fc,
                **meta,
            }
        )
        counts[meta["category"]] += 1

    TXT_OUT.parent.mkdir(parents=True, exist_ok=True)
    with TXT_OUT.open("w", encoding="utf-8") as f:
        f.write(
            "# NES Zelda 1 OW LevelBlockAttrsB dispatch dump\n"
            "# Source: reference/aldonunez/dat/LevelBlockOW.dat bytes [128..255]\n"
            "# NES authority: Z_05.asm:HandleWarpOW (line 7313-7368)\n"
            "# Dispatch:\n"
            "#   attr_b_fc == $00         -> no warp\n"
            "#   attr_b_fc <  $40         -> dungeon, level = attr_b_fc >> 2 (Mode $02)\n"
            "#   attr_b_fc == $50         -> shortcut cave (Mode $0C)\n"
            "#   attr_b_fc != $50, >=$40  -> regular cave (Mode $0B)\n"
            "#\n"
            f"# Summary:  no_warp={counts['no_warp']:3d}  "
            f"dungeon={counts['dungeon']:3d}  "
            f"cave_reg={counts['cave_regular']:3d}  "
            f"cave_shortcut={counts['cave_shortcut']:3d}\n"
            "#\n"
            "# room_id   raw_attr_b   attr_b_fc   category         mode    level   cave_id\n"
        )
        for r in rows:
            mode_str = f"${r['mode']:02X}" if r["mode"] is not None else "---"
            level_str = f"L{r['level']}" if r["level"] is not None else " -"
            cave_str = (
                f"${r['cave_id']:02X}" if r["cave_id"] is not None else "---"
            )
            f.write(
                f"   $%02X       $%02X         $%02X       %-14s  %4s   %3s   %s\n"
                % (
                    r["room_id"],
                    r["raw_attr_b"],
                    r["attr_b_fc"],
                    r["category"],
                    mode_str,
                    level_str,
                    cave_str,
                )
            )

    JSON_OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "source": "reference/aldonunez/dat/LevelBlockOW.dat",
        "nes_authority": "Z_05.asm:HandleWarpOW lines 7313-7368",
        "table_offset_in_dat": ATTR_B_OFFSET,
        "table_len": TABLE_LEN,
        "summary": counts,
        "rows": rows,
    }
    with JSON_OUT.open("w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")

    print(f"wrote {TXT_OUT.relative_to(REPO_ROOT)}")
    print(f"wrote {JSON_OUT.relative_to(REPO_ROOT)}")
    print(
        "summary: "
        f"no_warp={counts['no_warp']} "
        f"dungeon={counts['dungeon']} "
        f"cave_regular={counts['cave_regular']} "
        f"cave_shortcut={counts['cave_shortcut']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
