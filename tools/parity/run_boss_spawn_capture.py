#!/usr/bin/env python3
"""Phase 1 orchestrator: drive tools/parity/probe_nes_boss_spawn.lua across
all dungeon levels x quests x maps to establish authoritative NES boss-spawn
ground truth (room id, slot-1 ObjType, LBA bytes, NT/PALRAM).

Usage:
    python tools/parity/run_boss_spawn_capture.py            # all L1..9 x Q1,2 x orig,redux
    python tools/parity/run_boss_spawn_capture.py --level 5  # one level, both quests/maps
    python tools/parity/run_boss_spawn_capture.py --level 1 --quest 1 --map orig
    python tools/parity/run_boss_spawn_capture.py --summary  # re-print summary from existing JSONs

Strictly sequential (one EmuHawk at a time, -Wait). Resumable: skips a run
whose JSON already exists with boot_ok+warp_ok unless --force. Models
RoomRom/tools/run_uw_level.py (the proven BizHawk launch pattern).
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
LAUNCH_PS1 = REPO_ROOT / "tools" / "launch_bizhawk.ps1"
PROBE_LUA = REPO_ROOT / "tools" / "parity" / "probe_nes_boss_spawn.lua"
OUT = REPO_ROOT / "tools" / "parity" / "out"

# ROM candidates (first existing wins). Mirrors run_uw_level.py.
ROMS = {
    "orig": [
        Path(r"C:\tmp\loz_real.nes"),     # user's staged real Z1 ROM
        Path(r"C:\tmp\zelda1.nes"),
        REPO_ROOT / "roms" / "Legend of Zelda, The (USA).nes",
        REPO_ROOT / "Zelda1-Redux" / "Legend of Zelda, The (USA).nes",
    ],
    "redux": [
        Path(r"C:\tmp\zelda_redux.nes"),
        REPO_ROOT / "roms" / "Zelda Redux.nes",
        REPO_ROOT / "Zelda1-Redux" / "Zelda Redux.nes",
    ],
}

# Per-level boss ObjType(s); L9 = Patra + Ganon. (Z_07 InitObject_JumpTable.)
# L5 Digdogger=$39 (Digdogger2->$38 runtime), L6 Gohma=$34 (blue; $33 red).
BOSS_OT = {1: [0x3D], 2: [0x31], 3: [0x3C], 4: [0x43], 5: [0x39, 0x38],
           6: [0x34, 0x33], 7: [0x3D], 8: [0x45], 9: [0x47, 0x3E]}


def find_rom(rom_id):
    for c in ROMS[rom_id]:
        if c.exists():
            return c
    return None


def out_path(level, quest, rom_id):
    return OUT / f"nes_boss_spawn_L{level}_Q{quest}_{rom_id}.json"


def run_probe(level, quest, rom_id, rom_path):
    op = out_path(level, quest, rom_id)
    OUT.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["CODEX_BOSS_LEVEL"] = str(level)
    env["CODEX_BOSS_QUEST"] = str(quest)
    env["CODEX_BOSS_MAP"] = rom_id
    env["CODEX_BOSS_OUT"] = str(op)
    cmd = [
        "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", str(LAUNCH_PS1),
        "-RomPath", str(rom_path),
        "-LuaPath", str(PROBE_LUA),
        "-Wait",
    ]
    print(f"[probe] L{level} Q{quest} {rom_id} -> {op.name}")
    print("$ " + " ".join(cmd))
    rc = subprocess.run(cmd, cwd=str(REPO_ROOT), env=env).returncode
    if rc != 0:
        print(f"  WARN: launch_bizhawk.ps1 exit={rc}")
    return op


def run_ok(op):
    if not op.exists():
        return False
    try:
        d = json.loads(op.read_text(encoding="utf-8"))
        return bool(d.get("boot_ok")) and bool(d.get("warp_ok"))
    except Exception:
        return False


def print_summary(levels, quests, maps):
    print("\n=== BOSS-SPAWN SUMMARY (authoritative live NES) ===")
    print(f"{'L/Q/map':14} {'boss_ot':8} {'room':5} {'slot1':6} {'spawn':6} {'lba_lid':8} {'BossRoomId':10}")
    for level in levels:
        for quest in quests:
            for rom_id in maps:
                op = out_path(level, quest, rom_id)
                if not op.exists():
                    print(f"L{level}Q{quest}/{rom_id:5} (no capture)")
                    continue
                d = json.loads(op.read_text(encoding="utf-8"))
                if d.get("fatal"):
                    print(f"L{level}Q{quest}/{rom_id:5} FATAL {d['fatal']}")
                    continue
                caps = d.get("captures", [])
                wanted = BOSS_OT.get(level, [])
                for cap in caps:
                    slot1 = next((s["t"] for s in cap.get("slots", []) if s["slot"] == 1), 0)
                    tag = f"L{level}Q{quest}/{rom_id}"
                    print(f"{tag:14} ${cap.get('want_ot',0):02X}     ${cap['room']:02X}  "
                          f"${slot1:02X}   {str(cap.get('spawned_boss')):6} "
                          f"${cap.get('lba_lid',0):02X}     ${cap.get('boss_room_id',0):02X}")


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", type=int, default=None)
    ap.add_argument("--quest", type=int, default=None)
    ap.add_argument("--map", choices=["orig", "redux"], default=None)
    ap.add_argument("--force", action="store_true", help="re-run even if JSON exists")
    ap.add_argument("--summary", action="store_true", help="only print summary")
    args = ap.parse_args(argv[1:])

    levels = [args.level] if args.level else list(range(1, 10))
    quests = [args.quest] if args.quest else [1, 2]
    maps = [args.map] if args.map else ["orig", "redux"]

    if args.summary:
        print_summary(levels, quests, maps)
        return 0

    for rom_id in maps:
        if find_rom(rom_id) is None:
            print(f"WARN: no ROM for '{rom_id}', skipping that map. Tried: "
                  + ", ".join(str(c) for c in ROMS[rom_id]))

    for level in levels:
        for quest in quests:
            for rom_id in maps:
                rom_path = find_rom(rom_id)
                if rom_path is None:
                    continue
                op = out_path(level, quest, rom_id)
                if op.exists() and run_ok(op) and not args.force:
                    print(f"[skip] L{level} Q{quest} {rom_id} already captured")
                    continue
                run_probe(level, quest, rom_id, rom_path)
                if not run_ok(op):
                    print(f"  WARN: L{level} Q{quest} {rom_id} capture not ok "
                          f"(boot/warp failed) — inspect {op}")

    print_summary(levels, quests, maps)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
