"""room_checklist.py — per-room parity driver.

Usage:
  python tools/room_checklist.py init        # create empty checklist
  python tools/room_checklist.py next        # process next TODO room
  python tools/room_checklist.py status      # show progress

Flow per `next`:
  1. Read checklist. Find next TODO row.
  2. Compute direction from previous captured room to this one
     (path is adjacency-safe).
  3. Write direction to _next_dir.txt.
  4. Invoke advance_and_capture_gen.lua via EmuHawk.
  5. Invoke advance_and_capture_nes.lua via EmuHawk.
  6. Run compare_one_room.py.
  7. Update checklist: MATCH / MISMATCH / BLOCKED.
  8. Print outcome.
"""
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROOMS = ROOT / "builds" / "reports" / "rooms"
CHECKLIST = ROOMS / "_checklist.md"
NEXT_DIR = ROOMS / "_next_dir.txt"
EMU = Path(r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe")
GEN_ROM = ROOT / "builds" / "whatif.md"
NES_ROM = ROOT / "Legend of Zelda, The (USA).nes"
LUA_GEN = ROOT / "tools" / "advance_and_capture_gen.lua"
LUA_NES = ROOT / "tools" / "advance_and_capture_nes.lua"


def build_path():
    """Adjacency-only serpentine starting from $77."""
    p = [0x77]
    # row 7 left: $77 → $70
    for c in range(6, -1, -1):
        p.append(0x70 + c)
    # col 0 up: $70 → $00
    for r in range(6, -1, -1):
        p.append(r * 16)
    # serpentine rows 0..7 covering remaining rooms
    seen = set(p)
    for row in range(0, 8):
        cols = range(0, 16) if row % 2 == 0 else range(15, -1, -1)
        for col in cols:
            rid = row * 16 + col
            if rid not in seen:
                p.append(rid)
                seen.add(rid)
    return p


def dir_toward(cur, target):
    cur_row, cur_col = cur >> 4, cur & 0x0F
    tgt_row, tgt_col = target >> 4, target & 0x0F
    if tgt_col > cur_col: return "Right"
    if tgt_col < cur_col: return "Left"
    if tgt_row > cur_row: return "Down"
    if tgt_row < cur_row: return "Up"
    return None


def init_checklist():
    ROOMS.mkdir(parents=True, exist_ok=True)
    path = build_path()
    lines = ["# Room Parity Checklist", "",
             "| idx | room | status | tiles | palette | notes |",
             "|----:|------|--------|------:|--------:|-------|"]
    for i, rid in enumerate(path):
        status = "DONE" if rid == 0x77 else "TODO"
        lines.append(f"| {i} | ${rid:02X} | {status} | - | - | |")
    CHECKLIST.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {CHECKLIST} with {len(path)} rooms.")


def parse_checklist():
    if not CHECKLIST.exists():
        return None
    rows = []
    for line in CHECKLIST.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"): continue
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) < 6: continue
        if parts[0] in ("idx", ":---") or parts[0].startswith(":-"): continue
        try:
            idx = int(parts[0])
        except ValueError:
            continue
        rows.append({
            "idx": idx,
            "room_str": parts[1],
            "room": int(parts[1].lstrip("$"), 16),
            "status": parts[2],
            "tiles": parts[3],
            "palette": parts[4],
            "notes": parts[5],
        })
    return rows


def write_checklist(rows):
    lines = ["# Room Parity Checklist", "",
             "| idx | room | status | tiles | palette | notes |",
             "|----:|------|--------|------:|--------:|-------|"]
    for r in rows:
        lines.append(
            f"| {r['idx']} | {r['room_str']} | {r['status']} | {r['tiles']} | {r['palette']} | {r['notes']} |"
        )
    CHECKLIST.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run_emu(rom, lua, timeout=60):
    proc = subprocess.Popen(
        [str(EMU), f"--lua={lua}", str(rom)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    try:
        proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        return False
    return proc.returncode == 0


def compare(rid):
    out = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "compare_one_room.py"), f"{rid:02X}"],
        capture_output=True, text=True, cwd=str(ROOT),
    )
    txt = out.stdout
    tile_mm = pal_mm = -1
    for line in txt.splitlines():
        if "tile mismatches:" in line:
            try: tile_mm = int(line.split(":")[1].split("/")[0].strip())
            except: pass
        if "palette mismatches:" in line:
            try: pal_mm = int(line.split(":")[1].split("/")[0].strip())
            except: pass
    return tile_mm, pal_mm, txt


def status():
    rows = parse_checklist()
    if not rows: print("No checklist. Run `init`."); return
    done = sum(1 for r in rows if r["status"] == "MATCH" or r["status"] == "DONE")
    todo = sum(1 for r in rows if r["status"] == "TODO")
    blocked = sum(1 for r in rows if r["status"] in ("MISMATCH", "BLOCKED"))
    print(f"done={done}  todo={todo}  blocked={blocked}  total={len(rows)}")
    for r in rows:
        if r["status"] not in ("MATCH", "DONE", "TODO"):
            print(f"  {r['room_str']}: {r['status']} tiles={r['tiles']} pal={r['palette']} -- {r['notes']}")


def next_room():
    rows = parse_checklist()
    if not rows: print("No checklist. Run `init`."); return 2
    # previous done room = the latest row with MATCH or DONE
    prev = None
    for r in rows:
        if r["status"] in ("MATCH", "DONE"):
            prev = r
        elif r["status"] == "TODO":
            target = r
            break
    else:
        print("No TODO rooms remain."); return 0
    if prev is None:
        print("ERROR: no previously-captured room. Checklist needs a DONE anchor."); return 3

    cur = prev["room"]
    tgt = target["room"]
    d = dir_toward(cur, tgt)
    if d is None:
        print(f"ERROR: $({cur:02X}) and $({tgt:02X}) are not adjacent."); return 4

    print(f"Room ${tgt:02X} (from ${cur:02X}, direction {d})")
    NEXT_DIR.write_text(d + "\n", encoding="utf-8")
    # Tell each Lua to load the PREVIOUS room's per-room snapshot state.
    (ROOMS / "_gen_load_room.txt").write_text(f"{cur:02X}\n", encoding="utf-8")
    (ROOMS / "_nes_load_room.txt").write_text(f"{cur:02X}\n", encoding="utf-8")

    # Invoke Gen then NES.
    for label, rom, lua in (("gen", GEN_ROM, LUA_GEN), ("nes", NES_ROM, LUA_NES)):
        print(f"  running {label}...")
        t0 = time.time()
        ok = run_emu(rom, lua, timeout=90)
        dt = time.time() - t0
        if not ok:
            print(f"  {label} run timed out or failed after {dt:.1f}s")
            target["status"] = "BLOCKED"
            target["notes"] = f"{label} emulator run failed"
            write_checklist(rows)
            return 5
        print(f"  {label} done ({dt:.1f}s)")

    tile_mm, pal_mm, txt = compare(tgt)
    target["tiles"] = str(tile_mm)
    target["palette"] = str(pal_mm)
    if tile_mm == 0 and pal_mm == 0:
        target["status"] = "MATCH"
        target["notes"] = ""
        write_checklist(rows)
        print(f"  [MATCH]")
        return 0
    else:
        target["status"] = "MISMATCH"
        target["notes"] = f"tile={tile_mm} pal={pal_mm}"
        write_checklist(rows)
        print(f"  [MISMATCH] -- tiles={tile_mm} palette={pal_mm}")
        print(txt)
        print(f"User action needed for room ${tgt:02X}")
        return 1


def recapture_gen():
    """After a ROM fix: re-walk to the last MISMATCH room from the
    previous room's state and re-capture + re-compare (Gen only)."""
    rows = parse_checklist()
    if not rows: print("No checklist."); return 2
    prev = None
    target = None
    for r in rows:
        if r["status"] in ("MATCH", "DONE"):
            prev = r
        elif r["status"] == "MISMATCH":
            target = r; break
    if not target or not prev:
        print("No MISMATCH row to recapture."); return 3
    cur = prev["room"]; tgt = target["room"]
    d = dir_toward(cur, tgt)
    NEXT_DIR.write_text(d + "\n", encoding="utf-8")
    (ROOMS / "_gen_load_room.txt").write_text(f"{cur:02X}\n", encoding="utf-8")
    print(f"Recapture Gen room ${tgt:02X} (from ${cur:02X}, {d})")
    t0 = time.time()
    ok = run_emu(GEN_ROM, LUA_GEN, timeout=90)
    print(f"gen done ({time.time()-t0:.1f}s)")
    if not ok:
        print("Gen emu run timed out"); return 4
    tile_mm, pal_mm, txt = compare(tgt)
    target["tiles"] = str(tile_mm)
    target["palette"] = str(pal_mm)
    if tile_mm == 0 and pal_mm == 0:
        target["status"] = "MATCH"; target["notes"] = ""
        print("[MATCH]")
    else:
        target["notes"] = f"retry tile={tile_mm} pal={pal_mm}"
        print(f"still MISMATCH -- tiles={tile_mm} palette={pal_mm}")
        print(txt)
    write_checklist(rows)
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__); return 2
    cmd = sys.argv[1]
    if cmd == "init": init_checklist(); return 0
    if cmd == "status": status(); return 0
    if cmd == "next": return next_room()
    if cmd == "recapture-gen": return recapture_gen()
    print(__doc__); return 2


if __name__ == "__main__":
    raise SystemExit(main())
