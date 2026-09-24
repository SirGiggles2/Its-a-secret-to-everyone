#!/usr/bin/env python3
"""Dungeon (UW) BG byte sweep — one level at a time, both platforms.

For a (level, quest): read the room list from
RoomRom/data/uw_level{N}_quest{Q}_rooms.json, then in ONE BizHawk launch per
platform capture every room's golden (the NES probe loads the level once and
re-decodes each room via mode 4; the Gen probe probe-warps to each room).
Finally byte-diff each room (cave_byte_diff.py: BG CRAM palette byte-exact +
BG play-cell presence) and print a per-room PASS/FAIL table.

NES core = NesHawk (config.ini PreferredCores NES=NesHawk — the CHR/PALRAM
capture reads the "VRAM" domain only NesHawk exposes). Gen core = genplus.

Usage:
  python run_dungeon_sweep.py 1 1            # level 1 quest 1
  python run_dungeon_sweep.py 1 1 --only-diff
  python run_dungeon_sweep.py 1 1 --rooms 0x73,0x63
"""
import subprocess, sys, time, json, pathlib, argparse, re, tempfile, shutil

ROOT     = pathlib.Path(__file__).resolve().parents[3]
BIZHAWK  = r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
EMUHAWK  = BIZHAWK + r"\EmuHawk.exe"
NES_ROM  = r"C:\tmp\loz_real.nes"
GEN_ROM  = r"C:\tmp\Debug.md"
GEN_SRC  = ROOT / "builds" / "Debug.md"
OUT_DIR  = r"C:\tmp\cave_golden"
NES_PROBE = r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\parity\cave_golden\probe_nes_dungeon_golden.lua"
GEN_PROBE = r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\parity\cave_golden\probe_gen_dungeon_golden.lua"
DIFF      = ROOT / "tools" / "parity" / "cave_golden" / "cave_byte_diff.py"


def launch(prelude_path, rom, timeout=600):
    # Never inspect/kill unrelated emulator processes or write their profile.
    sys.path.insert(0, str(ROOT / "tools"))
    from dungeon_harness.run_all import short_path
    with tempfile.TemporaryDirectory(prefix="zelda-sweep-") as staging:
        stage = pathlib.Path(staging)
        settings = json.loads((pathlib.Path(BIZHAWK) / "config.ini").read_text(encoding="utf-8-sig"))
        settings.update(SingleInstanceMode=False, SoundEnabled=False,
                        RunInBackground=True, AcceptBackgroundInput=False)
        def disable_autoload(value):
            if isinstance(value, dict):
                for key, child in value.items():
                    if key == "AutoLoad": value[key] = False
                    else: disable_autoload(child)
            elif isinstance(value, list):
                for child in value: disable_autoload(child)
        disable_autoload(settings)
        for entry in settings.get("PathEntries", {}).get("Paths", []):
            if entry["Type"] == "Firmware":
                entry["Path"] = str(pathlib.Path(BIZHAWK) / "Firmware")
            elif entry["Type"] in {"Base", "Save RAM", "Savestates", "Screenshots", "Cheats"}:
                dest = stage / entry["System"] / entry["Type"]
                dest.mkdir(parents=True, exist_ok=True)
                entry["Path"] = str(dest)
        config = stage / "config.ini"
        config.write_text(json.dumps(settings), encoding="utf-8")
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
        command = [short_path(pathlib.Path(EMUHAWK)), "--gdi",
                   "--config=" + short_path(config),
                   "--lua=" + short_path(pathlib.Path(prelude_path)),
                   short_path(pathlib.Path(rom))]
        proc = subprocess.Popen(command, cwd=BIZHAWK, startupinfo=startup)
        try:
            return proc.wait(timeout=timeout) == 0
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            return False


def manifest_rooms(level, quest):
    mf = ROOT / "RoomRom" / "data" / f"uw_level{level}_quest{quest}_rooms.json"
    d = json.loads(mf.read_text())
    rooms = [int(r, 16) for r in d["rooms"]]
    start = int(d["start_room_id"], 16)
    # start room first (it's the proven one), then the rest in id order
    rest = sorted(r for r in rooms if r != start)
    return [start] + rest


def lua_room_list(rooms):
    return "{" + ",".join(f"0x{r:02X}" for r in rooms) + "}"


def write_prelude(path, body):
    with open(path, "w") as f:
        f.write(body)


def run_platform(level, quest, rooms, which):
    rl = lua_room_list(rooms)
    if which == "nes":
        prelude = r"C:\tmp\sweep_nes_dun_prelude.lua"
        write_prelude(prelude,
            f"LEVEL={level}\nQUEST={quest}\nUW_ROOM=0x{rooms[0]:02X}\n"
            f"ROOMS={rl}\n"
            f'OUT_DIR="C:\\\\tmp\\\\cave_golden"\n'
            f'dofile("{NES_PROBE.replace(chr(92), chr(92)*2)}")\n')
        return launch(prelude, NES_ROM)
    else:
        prelude = r"C:\tmp\sweep_gen_dun_prelude.lua"
        write_prelude(prelude,
            f"LEVEL={level}\nQUEST={quest}\nUW_ROOM=0x{rooms[0]:02X}\nOW_ROOM=0x37\n"
            f"ROOMS={rl}\n"
            f'OUT_DIR="C:\\\\tmp\\\\cave_golden"\n'
            f'dofile("{GEN_PROBE.replace(chr(92), chr(92)*2)}")\n')
        return launch(prelude, GEN_ROM)


def diff_room(level, quest, room, capture_started=None):
    nes = f"{OUT_DIR}\\nes_L{level}Q{quest}_R{room:02X}"
    gen = f"{OUT_DIR}\\gen_L{level}Q{quest}_R{room:02X}"
    if not pathlib.Path(nes, "f120.bin").exists():
        return ("NO-NES", -1)
    if not pathlib.Path(gen, "f120.bin").exists():
        return ("NO-GEN", -1)
    if capture_started is not None and any(
        pathlib.Path(folder, "f120.bin").stat().st_mtime < capture_started
        for folder in (nes, gen)
    ):
        return ("STALE", -1)
    r = subprocess.run([sys.executable, str(DIFF), "--nes", nes, "--gen", gen],
                       capture_output=True, text=True)
    m = re.search(r"GATE DIVERGENCES.*?:\s*(\d+)", r.stdout)
    n = int(m.group(1)) if m else -1
    verdict = "PASS" if r.returncode == 0 and "GATE PASS" in r.stdout else ("FAIL" if "GATE FAIL" in r.stdout else "?")
    return (verdict, n)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("level", type=int)
    ap.add_argument("quest", type=int)
    ap.add_argument("--only-diff", action="store_true")
    ap.add_argument("--rooms", help="comma list of hex ids to override manifest")
    a = ap.parse_args()

    rooms = ([int(x, 16) for x in a.rooms.split(",")] if a.rooms
             else manifest_rooms(a.level, a.quest))
    if not rooms:
        print("ERROR: no rooms selected")
        return 2
    capture_started = time.time() if not a.only_diff else None
    print(f"L{a.level}Q{a.quest}: {len(rooms)} rooms = "
          + " ".join(f"${r:02X}" for r in rooms), flush=True)

    if not a.only_diff:
        # stage Debug.md fresh
        if GEN_SRC.exists():
            shutil.copy2(GEN_SRC, GEN_ROM)
        else:
            print("ERROR: current Genesis build missing")
            return 2
        print("  capturing NES golden (one launch, level loaded once)…", flush=True)
        ok_n = run_platform(a.level, a.quest, rooms, "nes")
        print(f"  NES launch: {'EXIT' if ok_n else 'TIMEOUT'}", flush=True)
        if not ok_n:
            return 2
        print("  capturing Gen golden (one launch, probe-warp per room)…", flush=True)
        ok_g = run_platform(a.level, a.quest, rooms, "gen")
        print(f"  Gen launch: {'EXIT' if ok_g else 'TIMEOUT'}", flush=True)
        if not ok_g:
            return 2

    print(f"\n{'room':6} {'verdict':8} {'BG-div':7}")
    print("-" * 24)
    npass = 0
    for r in rooms:
        verdict, n = diff_room(a.level, a.quest, r, capture_started)
        if verdict == "PASS":
            npass += 1
        print(f"${r:02X}    {verdict:8} {n if n>=0 else '-':>7}", flush=True)
    print("-" * 24)
    print(f"L{a.level}Q{a.quest} BG byte-exact: {npass}/{len(rooms)} PASS")
    return 0 if npass == len(rooms) else 1


if __name__ == "__main__":
    sys.exit(main())
