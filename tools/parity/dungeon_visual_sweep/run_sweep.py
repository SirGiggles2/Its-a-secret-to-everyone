"""Phase G — Orchestrator. Launches BizHawk once per scenario.

For each scenario in scenarios.json, writes a tiny prelude.lua that
sets SCENARIO_* globals + runs probe_one_gen.lua. Launches BizHawk
synchronously, waits for completion (auto-exit via client.exit()),
moves to next.

Output: C:\\tmp\\g_sweep\\gen_<scenario>.{bin,png}
Log:    C:\\tmp\\g_sweep\\sweep_log.txt
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
    REPO / "tools" / "parity" / "dungeon_visual_sweep" / "probe_one_gen.lua"
)
ROM_SRC = REPO / "builds" / "Debug.md"
BIZHAWK = pathlib.Path(
    r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms"
    r"\BizHawk-2.11-win-x64"
) / "EmuHawk.exe"
TMP = pathlib.Path(r"C:\tmp\g_sweep")
TMP.mkdir(parents=True, exist_ok=True)
ROM_STAGED = pathlib.Path(r"C:\tmp\Debug.md")
PROBE_PRELUDE = pathlib.Path(r"C:\tmp\probe_one_gen_prelude.lua")

LOG_PATH = TMP / "sweep_log.txt"


def stage_rom():
    if not ROM_STAGED.exists() or ROM_STAGED.stat().st_mtime < ROM_SRC.stat().st_mtime:
        ROM_STAGED.write_bytes(ROM_SRC.read_bytes())


def write_prelude(sc: dict):
    lines = [
        f'SCENARIO_ID    = "{sc["id"]}"',
        f'SCENARIO_CAT   = "{sc["category"]}"',
    ]
    # Per-category TARGET selection:
    #   cave_enter / dungeon_enter: navigate OW to the entry room
    #     (ow_room_id from scenarios.json).
    #   dungeon_exit: navigate OW to the dungeon's entry room first
    #     (expected_ow_room_id), then probe enters dungeon, then walks
    #     south through doorway $7D to return to that same OW room.
    if sc["category"] == "dungeon_exit":
        target = sc.get("expected_ow_room_id")
    else:
        target = sc.get("ow_room_id")
    if target is None:
        target = sc.get("entry_room")
    if target is None:
        target = sc.get("uw_room_id")
    if target is None:
        target = 0
    lines.append(f"SCENARIO_TARGET = 0x{target:02X}")
    expect = 2 if sc["category"] == "cave_enter" else 1
    if sc["category"] == "dungeon_exit":
        expect = 0
    lines.append(f"SCENARIO_EXPECT = {expect}")
    lines.append(f"SCENARIO_LEVEL = {sc.get('level', 0)}")
    lines.append(f"SCENARIO_QUEST = {sc.get('quest', 1)}")
    # Bake category into single token expected by probe.
    cat_map = {
        "cave_enter": "cave",
        "dungeon_enter": "dungeon",
        "dungeon_exit": "dungeon_exit",
    }
    lines.append(f'SCENARIO_CAT = "{cat_map.get(sc["category"], sc["category"])}"')
    lines.append(f'dofile("{str(PROBE_SRC).replace(chr(92), chr(92)*2)}")')
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
        f"-ArgumentList '--lua={PROBE_PRELUDE}','{ROM_STAGED}' "
        f"-WorkingDirectory '{BIZHAWK.parent}'",
    ]
    subprocess.run(cmd, capture_output=True)

    # Poll for capture output OR EmuHawk exit.
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
        # Check if capture landed (probe finished + exited self).
        captures = list(TMP.glob(f"gen_{sc_id}*.bin"))
        if captures:
            time.sleep(1)
        time.sleep(2)
    # Timeout — force kill.
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
        log.write("# Phase G one-launch sweep log\n")
        log.write("# scenario\tcategory\ttarget\tstatus\tbin\n")
        for i, sc in enumerate(scs):
            if filter_ids and sc["id"] not in filter_ids:
                continue
            print(f"[{i+1}/{len(scs)}] {sc['id']}  ({sc['category']})")
            # Remove prior captures for this scenario so we know if
            # this run produced new output.
            for old in TMP.glob(f"gen_{sc['id']}*.bin"):
                old.unlink()
            for old in TMP.glob(f"gen_{sc['id']}*.png"):
                old.unlink()
            write_prelude(sc)
            ok = launch_bizhawk_and_wait(sc["id"])
            captures = sorted(TMP.glob(f"gen_{sc['id']}*.bin"))
            status = "TIMEOUT"
            bin_name = ""
            if captures:
                bin_name = captures[0].name
                if "_NOTRIGGER" in bin_name or "_NO_" in bin_name or \
                   "_BOOT_FAIL" in bin_name:
                    status = bin_name.split(sc["id"] + "_", 1)[1].rsplit(".bin", 1)[0]
                else:
                    status = "OK"
            log.write(f"{sc['id']}\t{sc['category']}\t"
                      f"0x{sc.get('ow_room_id', sc.get('uw_room_id', 0)):02X}\t"
                      f"{status}\t{bin_name}\n")
            log.flush()
            print(f"  -> {status}  ({bin_name})")
    print(f"\nDone. Log: {LOG_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
