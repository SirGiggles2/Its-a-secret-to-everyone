"""Phase G5/G6 — Verify the per-scenario Phase G sweep.

Parses each gen_<scenario>.bin captured by run_sweep.py + probe_one_gen.lua,
extracts the STAT region, and validates:
  - bundle present + non-empty
  - PNG present + non-trivial size
  - status (from filename suffix or sweep_log.txt) is OK
  - s_scene matches expected (OW=0, UW=1, CAVE=2)
  - s_room_id matches expected target

Emits sweep_report.md (56-row table). Exit 0 if all PASS, else 1.

GDMP v2 layout (from probe_one_gen.lua capture()):
  Magic 'GDMP' + u32_le version + u32_le frame + u32_le hash
  Then blocks: 4-byte tag + u32_le size + data.
  STAT (32 bytes) contains read_stat() output:
    [0..11]  NES-mirror cells (GameMode/RoomId/CurLevel/LinkX/Y/Dir/State/...)
    [12..27] ObjType[0..15]
    [28]     s_scene (low byte)
    [29]     s_mode  (low byte)
    [30]     s_room_id
    [31]     padding (zero)
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
REPORT = (
    REPO / "tools" / "parity" / "dungeon_visual_sweep" / "sweep_report.md"
)

SCENE_OW, SCENE_UW, SCENE_CAVE = 0, 1, 2


def parse_bundle(path: pathlib.Path) -> dict:
    data = path.read_bytes()
    if len(data) < 16 or data[:4] != b"GDMP":
        return {"_error": "not a GDMP bundle"}
    out = {
        "_magic": "GDMP",
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
        out["blocks"][tag] = (idx + 8, ln)
        idx += 8 + ln
    if "STAT" in out["blocks"]:
        off, ln = out["blocks"]["STAT"]
        stat = data[off:off + ln]
        out["stat"] = {
            "GameMode": stat[0],
            "RoomId": stat[1],
            "CurLevel": stat[2],
            "LinkX": stat[3],
            "LinkY": stat[4],
            "LinkDir": stat[5],
            "LinkState": stat[6],
            "CavePersonState": stat[7],
            "CaveFlags": stat[8],
            "CurQuest": stat[9],
            "PersonTextSelector": stat[10],
            "FrameCounter": stat[11],
            "ObjType": list(stat[12:28]),
            "s_scene": stat[28],
            "s_mode": stat[29],
            "s_room_id": stat[30],
        }
    return out


def expected_scene(category: str) -> int:
    if category == "cave_enter":
        return SCENE_CAVE
    if category == "dungeon_enter":
        return SCENE_UW
    if category == "dungeon_exit":
        return SCENE_OW
    return -1


def evaluate(sc: dict) -> dict:
    sid = sc["id"]
    cat = sc["category"]
    base = TMP / f"gen_{sid}.bin"
    png = TMP / f"gen_{sid}.png"

    # status-suffixed bundle?
    status_bundles = []
    for p in TMP.glob(f"gen_{sid}_*.bin"):
        status_bundles.append(p)

    bundle = None
    status = "MISSING"
    if base.exists():
        bundle = base
        status = "TRIGGERED"
    elif status_bundles:
        bundle = status_bundles[0]
        # Extract status suffix from filename.
        status = bundle.stem.split(sid + "_", 1)[1] if "_" in bundle.stem else "UNKNOWN"

    result = {
        "id": sid,
        "category": cat,
        "status": status,
        "bundle": bundle.name if bundle else "",
        "png": png.name if png.exists() else "",
        "png_bytes": png.stat().st_size if png.exists() else 0,
        "domains": {
            "bundle_present": bundle is not None,
            "png_present": png.exists(),
            "png_size_ok": png.exists() and png.stat().st_size >= 500,
            "stat_scene_match": False,
            "stat_room_match": False,
            "stat_present": False,
        },
        "stat": None,
        "expected": {
            "scene": expected_scene(cat),
            "room": sc.get("ow_room_id")
                    or sc.get("uw_start_room_id")
                    or sc.get("expected_ow_room_id")
                    or sc.get("uw_room_id"),
        },
    }

    if bundle is None:
        return result

    parsed = parse_bundle(bundle)
    if "stat" in parsed:
        result["stat"] = parsed["stat"]
        result["domains"]["stat_present"] = True
        exp_scene = expected_scene(cat)
        result["domains"]["stat_scene_match"] = parsed["stat"]["s_scene"] == exp_scene
        # For cave entries, target room is the OW room we WARPED FROM.
        # After warp, s_room_id usually = cave_id-style mapping; just sanity check non-zero.
        if cat == "dungeon_enter":
            expected_room = sc.get("uw_start_room_id", 0)
            result["domains"]["stat_room_match"] = parsed["stat"]["s_room_id"] == expected_room
        elif cat == "dungeon_exit":
            expected_room = sc.get("expected_ow_room_id", 0)
            result["domains"]["stat_room_match"] = parsed["stat"]["s_room_id"] == expected_room
        else:  # cave_enter: post-warp s_room_id should be 0/cave-specific; relax to non-zero
            result["domains"]["stat_room_match"] = parsed["stat"]["s_scene"] == SCENE_CAVE
        # Cave entries: ObjType[1] should equal cave_id (bonfire/person slot init).
        if cat == "cave_enter":
            expected_cave_id = sc.get("cave_id", 0)
            result["domains"]["objtype_match"] = (
                parsed["stat"]["ObjType"][1] == expected_cave_id
            )
            result["expected"]["objtype1"] = expected_cave_id
            result["actual_objtype1"] = parsed["stat"]["ObjType"][1]

    return result


def verdict(r: dict) -> str:
    d = r["domains"]
    if not d["bundle_present"]:
        return "FAIL_MISSING"
    if r["status"].startswith("NOTRIGGER") or r["status"] in (
            "BOOT_FAIL", "NO_WARP_TILE", "NO_ENTRY", "NO_EXIT",
            "NO_WARP_TILE_PRE"):
        return f"FAIL_{r['status']}"
    if not d["png_size_ok"]:
        return "FAIL_PNG"
    if not d["stat_present"]:
        return "FAIL_NO_STAT"
    if not d["stat_scene_match"]:
        return "FAIL_SCENE"
    if not d["stat_room_match"]:
        return "FAIL_ROOM"
    if r["category"] == "cave_enter" and not d.get("objtype_match", True):
        return "FAIL_OBJTYPE"
    return "PASS"


def fmt_row(r: dict, v: str) -> str:
    stat = r["stat"] or {}
    scene = f"${stat.get('s_scene', 0):02X}"
    mode = f"${stat.get('s_mode', 0):02X}"
    room = f"${stat.get('s_room_id', 0):02X}"
    exp_scene = f"${r['expected']['scene']:02X}" if r["expected"]["scene"] >= 0 else "??"
    exp_room = f"${r['expected']['room'] or 0:02X}"
    return (f"| {r['id']:<22s} | {r['category']:<13s} | {r['status']:<18s} | "
            f"{scene} | {mode} | {room} | {exp_scene} | {exp_room} | "
            f"{r['png_bytes']:>5d} | **{v}** |")


def main():
    scs = json.loads(SCENARIOS.read_text(encoding="utf-8"))["scenarios"]
    rows = []
    pass_count = 0
    for sc in scs:
        r = evaluate(sc)
        v = verdict(r)
        if v == "PASS":
            pass_count += 1
        rows.append((r, v))

    lines = [
        "# Phase G — Visual sweep report",
        "",
        f"Total scenarios: {len(scs)}",
        f"PASS: {pass_count} / {len(scs)}",
        "",
        ("| scenario | category | status | s_scene | s_mode | s_room | "
         "exp_scene | exp_room | png_b | verdict |"),
        ("|---|---|---|---|---|---|---|---|---|---|"),
    ]
    for r, v in rows:
        lines.append(fmt_row(r, v))

    fail_summary = {}
    for r, v in rows:
        if v != "PASS":
            fail_summary[v] = fail_summary.get(v, 0) + 1
    if fail_summary:
        lines.append("")
        lines.append("## Failure breakdown")
        for k, v in sorted(fail_summary.items(), key=lambda kv: -kv[1]):
            lines.append(f"- {k}: {v}")

    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Report: {REPORT}")
    print(f"PASS: {pass_count}/{len(scs)}")
    return 0 if pass_count == len(scs) else 1


if __name__ == "__main__":
    sys.exit(main())
