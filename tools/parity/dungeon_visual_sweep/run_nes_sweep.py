"""Phase H3 — NES baseline sweep orchestrator.

For each scenario in scenarios.json, launches BizHawk with NES Z1 ROM
and probe_nes_one.lua. Captures NDMP bundle per scenario into
C:/tmp/g_sweep/nes_<sid>.bin.

Mirrors run_sweep.py structure but targets NES ROM.
"""
from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import time

REPO = pathlib.Path(__file__).resolve().parents[3]
SCENARIOS = (
    REPO / "tools" / "parity" / "dungeon_visual_sweep" / "scenarios.json"
)
PROBE_SRC = (
    REPO / "tools" / "parity" / "dungeon_visual_sweep" / "probe_nes_one.lua"
)
NES_ROM_SRC = pathlib.Path(
    r"C:\Users\Jake Diggity\Documents\GitHub\Legend of Zelda, The (USA).nes"
)
BIZHAWK = pathlib.Path(
    r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms"
    r"\BizHawk-2.11-win-x64"
) / "EmuHawk.exe"
TMP = pathlib.Path(r"C:\tmp\g_sweep")
TMP.mkdir(parents=True, exist_ok=True)
NES_ROM_STAGED = pathlib.Path(r"C:\tmp\Z1.nes")
PROBE_PRELUDE = pathlib.Path(r"C:\tmp\probe_nes_one_prelude.lua")

LOG_PATH = TMP / "nes_sweep_log.txt"


def stage_rom():
    if (not NES_ROM_STAGED.exists() or
            NES_ROM_STAGED.stat().st_mtime < NES_ROM_SRC.stat().st_mtime):
        NES_ROM_STAGED.write_bytes(NES_ROM_SRC.read_bytes())


def write_prelude(sc: dict):
    cat_map = {
        "cave_enter": "cave",
        "dungeon_enter": "dungeon",
        "dungeon_exit": "dungeon_exit",
    }
    cat = cat_map.get(sc["category"], sc["category"])

    # Per-category target meaning:
    #   cave: target = ow_room_id (for SRAM populate step)
    #   dungeon: target = uw_start_room_id
    #   dungeon_exit: target = expected_ow_room_id (landing OW)
    if cat == "cave":
        target = sc.get("ow_room_id", 0)
    elif cat == "dungeon":
        target = sc.get("uw_start_room_id", 0)
    elif cat == "dungeon_exit":
        target = sc.get("expected_ow_room_id", 0)
    else:
        target = 0

    expect = 2 if cat == "cave" else (1 if cat == "dungeon" else 0)
    cave_id = sc.get("cave_id", 0)

    lines = [
        f'SCENARIO_ID    = "{sc["id"]}"',
        f'SCENARIO_CAT   = "{cat}"',
        f"SCENARIO_TARGET = 0x{target:02X}",
        f"SCENARIO_EXPECT = {expect}",
        f"SCENARIO_LEVEL = {sc.get('level', 0)}",
        f"SCENARIO_QUEST = {sc.get('quest', 1)}",
        f"SCENARIO_CAVE_ID = 0x{cave_id:02X}",
        f'dofile("{str(PROBE_SRC).replace(chr(92), chr(92)*2)}")',
    ]
    PROBE_PRELUDE.write_text("\n".join(lines) + "\n", encoding="utf-8")


def kill_emuhawk():
    subprocess.run(
        ["powershell", "-Command",
         "Stop-Process -Name EmuHawk -Force -ErrorAction SilentlyContinue"],
        capture_output=True,
    )


def launch_bizhawk_and_wait(sc_id: str, timeout: float = 120.0):
    cmd = [
        "powershell", "-Command",
        f"Start-Process -FilePath '{BIZHAWK}' "
        f"-ArgumentList '--lua={PROBE_PRELUDE}','{NES_ROM_STAGED}' "
        f"-WorkingDirectory '{BIZHAWK.parent}'",
    ]
    subprocess.run(cmd, capture_output=True)

    start = time.time()
    while time.time() - start < timeout:
        ps = subprocess.run(
            ["powershell", "-Command",
             "(Get-Process EmuHawk -ErrorAction SilentlyContinue).Count"],
            capture_output=True, text=True,
        )
        try:
            running = int(ps.stdout.strip() or 0)
        except ValueError:
            running = 0
        if running == 0:
            return True
        captures = list(TMP.glob(f"nes_{sc_id}*.bin"))
        if captures:
            time.sleep(1)
        time.sleep(2)
    kill_emuhawk()
    return False


def main(argv):
    scs = json.loads(SCENARIOS.read_text(encoding="utf-8"))["scenarios"]
    filter_ids = set()
    if len(argv) > 1:
        filter_ids = set(argv[1].split(","))
    stage_rom()
    kill_emuhawk()

    with LOG_PATH.open("w", encoding="utf-8") as log:
        log.write("# Phase H3 NES baseline sweep log\n")
        log.write("# scenario\tcategory\ttarget\tstatus\tbin\n")
        for i, sc in enumerate(scs):
            if filter_ids and sc["id"] not in filter_ids:
                continue
            print(f"[{i+1}/{len(scs)}] {sc['id']}  ({sc['category']})")
            for old in TMP.glob(f"nes_{sc['id']}*.bin"):
                old.unlink()
            for old in TMP.glob(f"nes_{sc['id']}*.png"):
                old.unlink()
            write_prelude(sc)
            ok = launch_bizhawk_and_wait(sc["id"])
            captures = sorted(TMP.glob(f"nes_{sc['id']}*.bin"))
            status = "TIMEOUT"
            bin_name = ""
            if captures:
                bin_name = captures[0].name
                if "_UNKNOWN" in bin_name:
                    status = "UNKNOWN_CAT"
                else:
                    status = "OK"
            log.write(f"{sc['id']}\t{sc['category']}\t"
                      f"0x{sc.get('ow_room_id', sc.get('uw_start_room_id', 0)):02X}\t"
                      f"{status}\t{bin_name}\n")
            log.flush()
            print(f"  -> {status}  ({bin_name})")
    print(f"\nDone. Log: {LOG_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
