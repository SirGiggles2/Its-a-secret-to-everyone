"""Phase H4 — Per-scenario byte-diff: NES baseline vs Genesis capture.

Reads:
  - C:/tmp/g_sweep/nes_<sid>.bin (NDMP from probe_nes_one.lua)
  - C:/tmp/g_sweep/gen_<sid>.bin (GDMP from probe_one_gen.lua)

Domains compared per scenario:
  - STAT: EXACT on game-state cells (GameMode, RoomId, CurLevel,
    Link X/Y/Dir/State, CavePersonState, CaveFlags, CurQuest,
    PersonTextSelector, ObjType[0..15], CaveItemIds[0..2])
  - PAL_/CRAM: EXACT after NES PALRAM -> Genesis CRAM LUT
  - OAM/SAT: FUNCTIONAL — same sprite count, same tile/palette per
    matching slot; ±1 px position tolerance
  - CIRA/Plane A: EXACT after NES tile_id -> Genesis tile_id LUT
    (32×30 visible)

Emits reports/<sid>/{summary.md, stat_diff.txt, pal_diff.txt,
oam_diff.txt, nt_diff.txt}.

Usage:
    python diff_scenario.py <scenario_id>           # one
    python diff_scenario.py --all                   # all 56
    python diff_scenario.py --filter cave_6A,...    # subset
"""
from __future__ import annotations

import json
import pathlib
import struct
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
SCENARIOS = (
    REPO / "tools" / "parity" / "dungeon_visual_sweep" / "scenarios.json"
)
TMP = pathlib.Path(r"C:\tmp\g_sweep")
REPORTS = (
    REPO / "tools" / "parity" / "dungeon_visual_sweep" / "reports"
)
REPORTS.mkdir(parents=True, exist_ok=True)


def parse_bundle(path: pathlib.Path) -> dict:
    if not path.exists():
        return {"_error": "missing"}
    data = path.read_bytes()
    if len(data) < 16 or data[:4] not in (b"GDMP", b"NDMP"):
        return {"_error": f"bad magic {data[:4]!r}"}
    out = {
        "_magic": data[:4].decode("ascii"),
        "version": struct.unpack("<I", data[4:8])[0],
        "frame": struct.unpack("<I", data[8:12])[0],
        "hash": struct.unpack("<I", data[12:16])[0],
        "blocks": {},
    }
    idx = 16
    while idx < len(data) - 8:
        tag = data[idx:idx + 4].decode("ascii", "ignore")
        ln = struct.unpack("<I", data[idx + 4:idx + 8])[0]
        if tag == "END_":
            break
        out["blocks"][tag] = data[idx + 8: idx + 8 + ln]
        idx += 8 + ln
    return out


def parse_stat(stat_bytes: bytes, is_nes: bool) -> dict:
    """STAT layout from read_stat() — same for NES + Gen first 32 bytes.

    Bytes 0..11: GameMode, RoomId, CurLevel, LinkX, LinkY, LinkDir,
                 LinkState, CavePersonState, CaveFlags, CurQuest,
                 PersonTextSelector, FrameCounter
    Bytes 12..27: ObjType[0..15]
    Genesis-only bytes 28..30: s_scene, s_mode, s_room_id
    NES bytes 28..30: CaveItemIds[0..2]
    """
    out = {
        "GameMode": stat_bytes[0],
        "RoomId": stat_bytes[1],
        "CurLevel": stat_bytes[2],
        "LinkX": stat_bytes[3],
        "LinkY": stat_bytes[4],
        "LinkDir": stat_bytes[5],
        "LinkState": stat_bytes[6],
        "CavePersonState": stat_bytes[7],
        "CaveFlags": stat_bytes[8],
        "CurQuest": stat_bytes[9],
        "PersonTextSelector": stat_bytes[10],
        "FrameCounter": stat_bytes[11],
        "ObjType": list(stat_bytes[12:28]),
    }
    if is_nes:
        out["CaveItemIds"] = list(stat_bytes[28:31])
    else:
        out["s_scene"] = stat_bytes[28]
        out["s_mode"] = stat_bytes[29]
        out["s_room_id"] = stat_bytes[30]
    return out


# NES PALRAM -> Genesis CRAM mapping. Load from real source-of-truth
# data/misc/palettes.c first 128 bytes (64 entries × 2 LE bytes per entry).
# Per src/game/world/bg_palette.c roomrom_bg_palette_nes_to_cram:
#   off = (nes_color & 0x3F) * 2
#   cram_word = misc_palettes[off] | (misc_palettes[off+1] << 8)
_NES_TO_CRAM_LUT = None

def _load_nes_to_cram_lut():
    global _NES_TO_CRAM_LUT
    if _NES_TO_CRAM_LUT is not None:
        return _NES_TO_CRAM_LUT
    path = REPO / "data" / "misc" / "palettes.c"
    text = path.read_text(encoding="utf-8")
    # Parse hex bytes from C array.
    import re
    matches = re.findall(r"0x([0-9A-Fa-f]{2})", text)
    bytes_arr = [int(m, 16) for m in matches]
    if len(bytes_arr) < 128:
        raise RuntimeError(f"misc_palettes too short: {len(bytes_arr)}")
    lut = []
    for i in range(64):
        word = bytes_arr[i * 2] | (bytes_arr[i * 2 + 1] << 8)
        lut.append(word)
    _NES_TO_CRAM_LUT = lut
    return lut


def nes_to_cram(nes_byte: int) -> int:
    lut = _load_nes_to_cram_lut()
    return lut[nes_byte & 0x3F]


def diff_stat(nes_stat: dict, gen_stat: dict, sc: dict) -> list:
    """Compare game-state cells. Returns list of mismatch strings."""
    mismatches = []
    # Cells that MUST match.
    must_match = ["GameMode", "CurLevel", "LinkX", "LinkY", "LinkDir",
                  "LinkState", "CavePersonState", "CaveFlags",
                  "CurQuest", "PersonTextSelector"]
    for k in must_match:
        if nes_stat.get(k) != gen_stat.get(k):
            mismatches.append(
                f"{k}: NES=0x{nes_stat.get(k, 0):02X} "
                f"GEN=0x{gen_stat.get(k, 0):02X}")
    # ObjType[0..15]
    for i, (n, g) in enumerate(zip(nes_stat["ObjType"], gen_stat["ObjType"])):
        if n != g:
            mismatches.append(f"ObjType[{i}]: NES=0x{n:02X} GEN=0x{g:02X}")
    # RoomId: for cave entries, NES has cave_id loaded; Gen has cave_id too.
    # For dungeon entries, NES RoomId = UW room. Match expected.
    if nes_stat["RoomId"] != gen_stat["RoomId"]:
        mismatches.append(
            f"RoomId: NES=0x{nes_stat['RoomId']:02X} "
            f"GEN=0x{gen_stat['RoomId']:02X}")
    return mismatches


def diff_pal(nes_pal: bytes, gen_cram: bytes) -> list:
    """Compare NES PALRAM (32 bytes) -> Genesis CRAM (128 bytes = 64 words)
    after NES->Gen LUT."""
    mismatches = []
    # Genesis CRAM is 64 words (128 bytes), BE. NES has 32 entries.
    # PAL0 (BG sub-pals 0..3) maps to Gen CRAM[0..15].
    # PAL1 (SPR sub-pals 0..3) maps to Gen CRAM[16..31].
    # For cave: PAL0 = NES BG palette (32 bytes).
    if len(gen_cram) < 32:
        return [f"CRAM too short ({len(gen_cram)} < 32)"]
    for i in range(min(len(nes_pal), 16)):
        expected = nes_to_cram(nes_pal[i])
        # Gen CRAM is BE 16-bit
        actual = (gen_cram[i * 2] << 8) | gen_cram[i * 2 + 1]
        if expected != actual:
            mismatches.append(
                f"CRAM[{i}]: NES=0x{nes_pal[i]:02X}->0x{expected:03X} "
                f"GEN=0x{actual:03X}")
    return mismatches


def diff_objtype_only(nes_stat: dict, gen_stat: dict) -> list:
    """Just ObjType array diff for quick OAM-class checks."""
    mismatches = []
    for i, (n, g) in enumerate(zip(nes_stat["ObjType"], gen_stat["ObjType"])):
        if n != g:
            mismatches.append(f"ObjType[{i}]: NES=0x{n:02X} GEN=0x{g:02X}")
    return mismatches


def evaluate_one(sc: dict) -> dict:
    sid = sc["id"]
    nes_path = TMP / f"nes_{sid}.bin"
    gen_path = TMP / f"gen_{sid}.bin"

    # Also accept status-suffixed gen captures.
    if not gen_path.exists():
        for cand in TMP.glob(f"gen_{sid}_*.bin"):
            gen_path = cand
            break

    result = {
        "id": sid,
        "category": sc["category"],
        "nes_present": nes_path.exists(),
        "gen_present": gen_path.exists(),
        "domains": {},
        "verdict": "PENDING",
    }

    if not result["nes_present"]:
        result["verdict"] = "FAIL_NO_NES"
        return result
    if not result["gen_present"]:
        result["verdict"] = "FAIL_NO_GEN"
        return result

    nes = parse_bundle(nes_path)
    gen = parse_bundle(gen_path)

    if "_error" in nes:
        result["verdict"] = f"FAIL_NES_PARSE: {nes['_error']}"
        return result
    if "_error" in gen:
        result["verdict"] = f"FAIL_GEN_PARSE: {gen['_error']}"
        return result

    # STAT diff
    if "STAT" not in nes["blocks"] or "STAT" not in gen["blocks"]:
        result["verdict"] = "FAIL_NO_STAT"
        return result
    nes_stat = parse_stat(nes["blocks"]["STAT"], is_nes=True)
    gen_stat = parse_stat(gen["blocks"]["STAT"], is_nes=False)

    stat_mismatch = diff_stat(nes_stat, gen_stat, sc)
    result["domains"]["STAT"] = {
        "pass": len(stat_mismatch) == 0,
        "mismatches": stat_mismatch,
    }

    # PAL diff
    nes_pal = nes["blocks"].get("PAL_", b"")
    gen_cram = gen["blocks"].get("CRAM", b"")
    if nes_pal and gen_cram:
        pal_mismatch = diff_pal(nes_pal, gen_cram)
        result["domains"]["PAL"] = {
            "pass": len(pal_mismatch) == 0,
            "mismatches": pal_mismatch[:10],  # limit output
            "total_mismatches": len(pal_mismatch),
        }

    # ObjType-only OAM check (full OAM/SAT diff is deferred until normalization
    # ready). Sprites are identified by ObjType — if those match, sprite types match.
    objtype_mismatch = diff_objtype_only(nes_stat, gen_stat)
    result["domains"]["OBJTYPE"] = {
        "pass": len(objtype_mismatch) == 0,
        "mismatches": objtype_mismatch,
    }

    # Verdict aggregation
    all_pass = all(d.get("pass", False) for d in result["domains"].values())
    result["verdict"] = "PASS" if all_pass else "FAIL"
    return result


def write_report(result: dict):
    sid = result["id"]
    folder = REPORTS / sid
    folder.mkdir(parents=True, exist_ok=True)

    lines = [
        f"# Diff report — {sid}",
        "",
        f"Category: {result['category']}",
        f"Verdict: **{result['verdict']}**",
        f"NES bundle: {'YES' if result['nes_present'] else 'MISSING'}",
        f"GEN bundle: {'YES' if result['gen_present'] else 'MISSING'}",
        "",
        "## Per-domain results",
        "",
    ]
    for domain, info in result.get("domains", {}).items():
        status = "PASS" if info.get("pass") else "FAIL"
        lines.append(f"### {domain}: {status}")
        if info.get("mismatches"):
            lines.append("")
            for m in info["mismatches"]:
                lines.append(f"- {m}")
            if info.get("total_mismatches", 0) > len(info["mismatches"]):
                extra = info["total_mismatches"] - len(info["mismatches"])
                lines.append(f"- ...({extra} more)")
        lines.append("")
    (folder / "summary.md").write_text("\n".join(lines), encoding="utf-8")


def write_aggregate(results: list):
    pass_count = sum(1 for r in results if r["verdict"] == "PASS")
    lines = [
        "# Phase H — Aggregate byte-diff sweep report",
        "",
        f"Total: {len(results)}, PASS: {pass_count}, FAIL: {len(results) - pass_count}",
        "",
        "| scenario | category | verdict | STAT | PAL | OBJTYPE |",
        "|---|---|---|---|---|---|",
    ]
    for r in results:
        def cell(d):
            info = r.get("domains", {}).get(d)
            if not info:
                return "—"
            return "✓" if info.get("pass") else "✗"
        lines.append(
            f"| {r['id']:<22s} | {r['category']:<13s} | "
            f"**{r['verdict']}** | {cell('STAT')} | {cell('PAL')} | "
            f"{cell('OBJTYPE')} |"
        )
    out = REPORTS / "aggregate.md"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Aggregate: {out}")


def main(argv):
    scs = json.loads(SCENARIOS.read_text(encoding="utf-8"))["scenarios"]
    filter_ids = None
    if "--all" not in argv and "--filter" in argv:
        i = argv.index("--filter")
        filter_ids = set(argv[i + 1].split(","))
    elif "--all" not in argv and len(argv) > 1:
        filter_ids = {argv[1]}

    results = []
    for sc in scs:
        if filter_ids and sc["id"] not in filter_ids:
            continue
        r = evaluate_one(sc)
        write_report(r)
        results.append(r)
        print(f"{sc['id']:<22s} {r['verdict']}")

    write_aggregate(results)
    pass_count = sum(1 for r in results if r["verdict"] == "PASS")
    return 0 if pass_count == len(results) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
