#!/usr/bin/env python3
"""Run NES and Genesis UW room $73 walk-reason probes and diff them."""

from __future__ import annotations

import argparse
import ctypes
import json
import os
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LUA = ROOT / "RoomRom" / "tools" / "uw_walk_reason_probe.lua"
ROM_GEN = ROOT / "RoomRom" / "out" / "RoomRom.md"
ELF_GEN = ROOT / "RoomRom" / "out" / "rom.out"
NM = ROOT / "build" / "toolchain" / "sgdk_bin" / "bin" / "nm.exe"
OUT_DIR = ROOT / "build" / "reports" / "uw_walk_reason" / "r73"

SYMBOLS = (
    "s_uw_tile_walkable",
    "s_uw_walkable",
    "s_room_id",
    "s_link_x",
    "s_link_y",
)


def short_path(path: Path) -> str:
    raw = str(path.resolve())
    if os.name != "nt":
        return raw
    buf = ctypes.create_unicode_buffer(32768)
    n = ctypes.windll.kernel32.GetShortPathNameW(raw, buf, len(buf))
    return buf.value if n else raw


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


def find_nes_rom() -> Path:
    env = os.environ.get("ZELDA_NES_ROM")
    candidates: list[Path] = []
    if env:
        candidates.append(Path(env))
    candidates.extend([
        Path(r"C:\tmp\zelda1.nes"),
        ROOT / "Legend of Zelda, The (USA).nes",
        ROOT / "Zelda1-Redux" / "Legend of Zelda, The (USA).nes",
        Path(r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\zelda.nes"),
        Path(r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"),
    ])
    for c in candidates:
        if c.is_file():
            return c
    raise FileNotFoundError("NES ROM not found; set ZELDA_NES_ROM")


def resolve_gen_symbols() -> dict[str, int]:
    if not ELF_GEN.is_file():
        raise FileNotFoundError(f"missing {ELF_GEN}; run RoomRom/build.bat")
    result = subprocess.run(
        [str(NM), "-n", str(ELF_GEN)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    found: dict[str, int] = {}
    want = set(SYMBOLS)
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[2] in want:
            found[parts[2]] = int(parts[0], 16) & 0xFFFF
    missing = want - found.keys()
    if missing:
        raise RuntimeError(f"missing Genesis symbols: {sorted(missing)}")
    return found


def stop_bizhawk() -> None:
    subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command",
         "Get-Process EmuHawk -ErrorAction SilentlyContinue | Stop-Process -Force"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def run_probe(system: str, rom: Path, out_json: Path, timeout: int) -> dict:
    emu = find_bizhawk()
    out_json.parent.mkdir(parents=True, exist_ok=True)
    if out_json.exists():
        out_json.unlink()

    env = os.environ.copy()
    env["CODEX_UW_REASON_OUT_JSON"] = str(out_json)
    env["CODEX_UW_REASON_ROOM"] = str(0x73)
    if system == "genesis":
        symbols = resolve_gen_symbols()
        env["CODEX_GEN_TILE_WALKABLE"] = str(symbols["s_uw_tile_walkable"])
        env["CODEX_GEN_WALKABLE"] = str(symbols["s_uw_walkable"])
        env["CODEX_GEN_ROOM_ID"] = str(symbols["s_room_id"])
        env["CODEX_GEN_LINK_X"] = str(symbols["s_link_x"])
        env["CODEX_GEN_LINK_Y"] = str(symbols["s_link_y"])

    stop_bizhawk()
    args = [short_path(emu), f"--lua={short_path(LUA)}", short_path(rom)]
    proc = subprocess.run(
        args,
        cwd=short_path(emu.parent),
        env=env,
        timeout=timeout,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"{system} BizHawk exit={proc.returncode}")
    if not out_json.is_file():
        raise RuntimeError(f"{system} probe did not write {out_json}")
    payload = json.loads(out_json.read_text(encoding="utf-8"))
    if not payload.get("pass"):
        raise RuntimeError(f"{system} probe failed prep={payload.get('prep')}")
    return payload


def ok_code(code: int) -> bool:
    return code > 0


def bbox_add(box: list[int] | None, x: int, y: int) -> list[int]:
    if box is None:
        return [x, y, x, y]
    box[0] = min(box[0], x)
    box[1] = min(box[1], y)
    box[2] = max(box[2], x)
    box[3] = max(box[3], y)
    return box


def tile_walk_map(payload: dict) -> list[bool]:
    return [bool(cell["walk"]) for cell in payload["tile_cells"]]


def summarize_tile_diff(nes: dict, gen: dict) -> dict:
    nes_map = tile_walk_map(nes)
    gen_map = tile_walk_map(gen)
    first = []
    pair_hist: Counter[str] = Counter()
    box = None
    count = 0
    for idx, (n, g) in enumerate(zip(nes_map, gen_map)):
        if n == g:
            continue
        col = idx // 22
        row = idx % 22
        count += 1
        pair_hist[f"{int(n)}->{int(g)}"] += 1
        box = bbox_add(box, col, row)
        if len(first) < 48:
            first.append({
                "col": col,
                "row": row,
                "nes_walk": n,
                "gen_walk": g,
                "nes": nes["tile_cells"][idx],
                "gen": gen["tile_cells"][idx],
            })
    return {
        "diff_count": count,
        "bbox": box,
        "pair_histogram": dict(pair_hist),
        "first": first,
    }


def summarize_move_diff(nes: dict, gen: dict) -> dict:
    out = {}
    for direction, nes_move in nes["move"].items():
        gen_move = gen["move"][direction]
        n_codes = nes_move["codes"]
        g_codes = gen_move["codes"]
        count = 0
        pair_hist: Counter[str] = Counter()
        source_hist: Counter[str] = Counter()
        boxes: dict[str, list[int]] = {}
        first = []
        for idx, (nc, gc) in enumerate(zip(n_codes, g_codes)):
            if ok_code(nc) == ok_code(gc):
                continue
            x = idx % 256
            y = idx // 256
            count += 1
            pair = f"{nc}->{gc}"
            pair_hist[pair] += 1
            source_hist[f"{'walk' if ok_code(nc) else 'block'}->{'walk' if ok_code(gc) else 'block'}"] += 1
            boxes[pair] = bbox_add(boxes.get(pair), x, y)
            if len(first) < 64:
                first.append({
                    "local_x": x,
                    "local_y": y,
                    "nes_code": nc,
                    "gen_code": gc,
                    "nes_walk": ok_code(nc),
                    "gen_walk": ok_code(gc),
                })
        out[direction] = {
            "diff_count": count,
            "walk_block_histogram": dict(source_hist),
            "reason_pair_histogram": dict(pair_hist),
            "reason_pair_bboxes": boxes,
            "first": first,
        }
    return out


def infer_root(tile_summary: dict, move_summary: dict) -> list[str]:
    notes = []
    if tile_summary["diff_count"]:
        notes.append(
            "Tile collision data differs before movement is considered: "
            "NES reads PlayAreaTiles/ObjectFirstUnwalkableTile, while Genesis "
            "currently reads RoomRom s_uw_tile_walkable/s_uw_walkable."
        )
    else:
        notes.append("Tile collision data matches; remaining drift is movement sampling/doorway logic.")

    total_move = sum(v["diff_count"] for v in move_summary.values())
    if total_move:
        notes.append(
            "Movement walkability also differs. Reason-pair histograms show whether "
            "the drift is primary tile, NES vertical second-column, doorway, or OOB."
        )
    return notes


def write_pngs(nes: dict, gen: dict, out_dir: Path) -> list[str]:
    try:
        from PIL import Image
    except Exception:
        return []

    written: list[str] = []
    out_dir.mkdir(parents=True, exist_ok=True)

    def save_bool_diff(name: str, width: int, height: int,
                       nvals: list[bool], gvals: list[bool], scale: int = 3) -> None:
        img = Image.new("RGBA", (width, height), (0, 0, 0, 255))
        pix = img.load()
        for i, (n, g) in enumerate(zip(nvals, gvals)):
            x = i % width
            y = i // width
            if n == g:
                pix[x, y] = (0, 160, 60, 180) if n else (30, 30, 30, 220)
            elif n and not g:
                pix[x, y] = (255, 0, 0, 255)
            else:
                pix[x, y] = (0, 100, 255, 255)
        img = img.resize((width * scale, height * scale), Image.Resampling.NEAREST)
        path = out_dir / name
        img.save(path)
        written.append(str(path))

    save_bool_diff("tile_diff.png", 32, 22, tile_walk_map(nes), tile_walk_map(gen), 8)
    for direction in nes["move"]:
        nvals = [ok_code(c) for c in nes["move"][direction]["codes"]]
        gvals = [ok_code(c) for c in gen["move"][direction]["codes"]]
        save_bool_diff(f"move_{direction}_diff.png", 256, 176, nvals, gvals, 2)
    return written


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--timeout", type=int, default=120)
    args = ap.parse_args(argv[1:])

    if not LUA.is_file():
        raise FileNotFoundError(LUA)
    if not ROM_GEN.is_file():
        raise FileNotFoundError(f"missing {ROM_GEN}; run RoomRom/build.bat")

    nes_rom = find_nes_rom()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    nes_json = OUT_DIR / "nes_r73_walk_reason.json"
    gen_json = OUT_DIR / "gen_r73_walk_reason.json"
    diff_json = OUT_DIR / "diff_r73_walk_reason.json"

    print(f"[nes] {nes_rom}")
    nes = run_probe("nes", nes_rom, nes_json, args.timeout)
    print(f"[genesis] {ROM_GEN}")
    gen = run_probe("genesis", ROM_GEN, gen_json, args.timeout)

    tile_summary = summarize_tile_diff(nes, gen)
    move_summary = summarize_move_diff(nes, gen)
    pngs = write_pngs(nes, gen, OUT_DIR)
    diff = {
        "pass": tile_summary["diff_count"] == 0
        and all(v["diff_count"] == 0 for v in move_summary.values()),
        "nes_json": str(nes_json),
        "gen_json": str(gen_json),
        "tile": tile_summary,
        "move": move_summary,
        "root_cause_notes": infer_root(tile_summary, move_summary),
        "source_legend": {
            "nes": nes["source"],
            "genesis": gen["source"],
            "movement_nes": "reference/aldonunez/Z_07.asm:GetCollidingTileMoving/GetCollidableTile; reference/aldonunez/Z_05.asm:DoorwayRequiredCoord/Bounds",
            "movement_genesis": "RoomRom/src/main.c:link_walkable_at UW branch; RoomRom/src/uw_walk_model.c doorway helpers",
        },
        "pngs": pngs,
    }
    diff_json.write_text(json.dumps(diff, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({
        "pass": diff["pass"],
        "tile_diff_count": tile_summary["diff_count"],
        "move_diff_count": {k: v["diff_count"] for k, v in move_summary.items()},
        "diff_json": str(diff_json),
        "pngs": pngs,
        "root_cause_notes": diff["root_cause_notes"],
    }, indent=2))
    return 0 if diff["pass"] else 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
