#!/usr/bin/env python3
"""
Sequential per-level RoomRom underworld capture driver.

Usage:
    python RoomRom/tools/run_uw_level.py <level 1..9>

For the given level, generates missing reachability + manifest JSONs,
then for each (quest in 1,2) x (rom in orig, redux) launches BizHawk
under tools/launch_bizhawk.ps1 with the unified probe and verifies
the per-run dump. Halts on first failure with a clear rerun hint.

If the level is > 1, an aggregate golden check is performed first
to ensure L1 hashes have not drifted.

NO --jobs option. Strictly sequential, one BizHawk launch at a time.

Resume: skip per-run dumps whose JSON already passes verification.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
TOOLS = REPO_ROOT / "RoomRom" / "tools"
DATA = REPO_ROOT / "RoomRom" / "data"
OUT = REPO_ROOT / "RoomRom" / "out"
LAUNCH_PS1 = REPO_ROOT / "tools" / "launch_bizhawk.ps1"
PROBE_LUA = REPO_ROOT / "RoomRom" / "probe_nes_uw_dump.lua"

ROMS = {
    "orig": [
        Path(r"C:\tmp\zelda1.nes"),
        REPO_ROOT / "Zelda1-Redux" / "Legend of Zelda, The (USA).nes",
    ],
    "redux": [
        Path(r"C:\tmp\zelda_redux.nes"),
        REPO_ROOT / "Zelda Redux.nes",
        REPO_ROOT / "Zelda1-Redux" / "Zelda Redux.nes",
    ],
}


def find_rom(rom_id: str) -> Path:
    for c in ROMS[rom_id]:
        if c.exists():
            return c
    raise SystemExit(
        f"FATAL: no ROM found for '{rom_id}'. Tried: "
        + ", ".join(str(c) for c in ROMS[rom_id])
    )


def py_run(args: list[str]) -> int:
    """Run a tool with python; returns exit code."""
    cmd = [sys.executable, *args]
    print("$ " + " ".join(cmd))
    return subprocess.run(cmd, cwd=str(REPO_ROOT)).returncode


def ensure_reachability(level: int, quest: int) -> bool:
    p = DATA / f"uw_level{level}_quest{quest}_rooms.json"
    if p.exists():
        return True
    print(f"[reach] generating {p.name}")
    extra = ["--gate"]  # always gate when generating
    rc = py_run([str(TOOLS / "uw_reachability.py"), str(level), str(quest), *extra])
    return rc == 0 and p.exists()


def ensure_manifest(level: int, quest: int) -> bool:
    p = DATA / f"uw_level{level}_quest{quest}_manifest.json"
    if p.exists():
        return True
    print(f"[manifest] generating {p.name}")
    rc = py_run([str(TOOLS / "uw_manifest.py"), str(level), str(quest)])
    return rc == 0 and p.exists()


def run_probe(level: int, quest: int, rom_id: str, rom_path: Path) -> Path:
    out_path = OUT / f"nes_uw_level{level}_quest{quest}_{rom_id}.json"
    OUT.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["CODEX_UW_LEVEL"] = str(level)
    env["CODEX_UW_QUEST"] = str(quest)
    env["CODEX_UW_ROOMS_JSON"] = str(DATA / f"uw_level{level}_quest{quest}_rooms.json")
    env["CODEX_UW_MANIFEST_JSON"] = str(DATA / f"uw_level{level}_quest{quest}_manifest.json")
    env["CODEX_UW_OUT_JSON"] = str(out_path)
    env["CODEX_UW_MAP_ID"] = rom_id
    env["CODEX_UW_MAP_NAME"] = "Zelda1" if rom_id == "orig" else "Zelda1-Redux"

    cmd = [
        "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", str(LAUNCH_PS1),
        "-RomPath", str(rom_path),
        "-LuaPath", str(PROBE_LUA),
        "-Wait",
    ]
    print(f"[probe] L{level} Q{quest} {rom_id} -> {out_path.name}")
    print("$ " + " ".join(cmd))
    rc = subprocess.run(cmd, cwd=str(REPO_ROOT), env=env).returncode
    if rc != 0:
        print(f"  WARN: launch_bizhawk.ps1 exit={rc}")
    return out_path


def verify_run(level: int, quest: int, rom_id: str) -> bool:
    rc = py_run([
        str(TOOLS / "verify_uw_level.py"),
        str(level), str(quest), rom_id,
    ])
    return rc == 0


def golden_check_or_skip(level: int) -> None:
    if level <= 1:
        return
    golden = DATA / "uw_level1_golden.json"
    if not golden.exists():
        print(f"WARN: no L1 golden at {golden}; cannot verify L1 stability before L{level}.")
        return
    rc = py_run([
        str(TOOLS / "verify_uw_aggregate.py"),
        "--check-golden",
    ])
    if rc != 0:
        print("FATAL: L1 golden hash check failed. Halting before any new captures.")
        sys.exit(rc)


def write_l1_golden_if_needed(level: int) -> None:
    if level != 1:
        return
    golden = DATA / "uw_level1_golden.json"
    if golden.exists():
        return
    # Build golden from the four L1 dumps.
    import hashlib
    entries = []
    for q in (1, 2):
        for rom in ("orig", "redux"):
            p = OUT / f"nes_uw_level1_quest{q}_{rom}.json"
            if not p.exists():
                continue
            data = json.loads(p.read_text(encoding="utf-8"))
            for r in data.get("results", []):
                if "nt" not in r:
                    continue  # skip timeouts
                nt_bytes = bytes(b for row in r["nt"] for b in row)
                attr_bytes = bytes(r["attr"])
                pal_bytes = bytes(r["palram"])
                entries.append({
                    "quest": q, "rom": rom,
                    "room_id": f"0x{r['room_id']:02X}",
                    "nt_sha256": hashlib.sha256(nt_bytes).hexdigest(),
                    "attr_sha256": hashlib.sha256(attr_bytes).hexdigest(),
                    "palram_sha256": hashlib.sha256(pal_bytes).hexdigest(),
                })
    golden.write_text(
        json.dumps({"version": 1, "entries": entries}, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote L1 golden: {golden}  ({len(entries)} entries)")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("level", type=int, help="dungeon level 1..9")
    args = ap.parse_args(argv[1:])
    level = args.level
    if level < 1 or level > 9:
        sys.exit("level must be 1..9")

    golden_check_or_skip(level)

    for quest in (1, 2):
        if not ensure_reachability(level, quest):
            sys.exit(f"FATAL: reachability for L{level}Q{quest} failed.")
        if not ensure_manifest(level, quest):
            sys.exit(f"FATAL: manifest for L{level}Q{quest} failed.")
        for rom_id in ("orig", "redux"):
            out_path = OUT / f"nes_uw_level{level}_quest{quest}_{rom_id}.json"
            if out_path.exists() and verify_run(level, quest, rom_id):
                print(f"[skip] L{level} Q{quest} {rom_id} already verified")
                continue
            rom_path = find_rom(rom_id)
            run_probe(level, quest, rom_id, rom_path)
            if not verify_run(level, quest, rom_id):
                sys.exit(
                    f"\nHalting at L={level} Q={quest} R={rom_id}.\n"
                    f"Inspect {out_path}.\n"
                    f"Re-run: python RoomRom/tools/run_uw_level.py {level}\n"
                )

    write_l1_golden_if_needed(level)
    print(f"\nL{level}: all four (Q,R) dumps verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
