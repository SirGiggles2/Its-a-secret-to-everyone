"""Run one lockstep scenario on NES and Genesis, then diff.

    python tools/lockstep/run_lockstep.py <preset.json> [--frames N] [--full]
           [--no-cache] [--nes-only] [--frame-dump] [--snap T1,T2] [--bless]
           [--rom PATH] [--report-suffix SUFFIX]

Output: builds/reports/lockstep/<preset name>/{nes,gen}.{ram,txt,png},
diff.txt, diff.json, and each run's launch.json (ROM + script hashes).
NES ROM: roms/Legend of Zelda, The (USA).nes (local reference, never
distributed). Genesis ROM: builds/Debug.md.

T-141 fast loop:
- NES golden cache: the NES capture is a pure function of (NES ROM,
  preset.lua, capture.lua template, run_probe.py, EmuHawk build, MAXF),
  so it is stored under build/lockstep_cache/<sha256>/ and replayed from
  there; nes.cache records the key and hit/miss. --no-cache reruns it.
- Fail-fast: the Genesis capture compares the gate KEY cells
  (tools/lockstep/gate.py) against the NES rows every tick and stops 30
  ticks after the first non-allowed mismatch, with a full video snapshot
  of the tick after it. The runner then captures the NES up to that tick
  with the same snapshot (nes.fNNNNN.*), so both consoles' video domains
  exist for the failing tick. --full disables fail-fast.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

from capture_evidence import completed_ticks

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
NES_ROM = ROOT / "roms" / "Legend of Zelda, The (USA).nes"
GEN_ROM = ROOT / "builds" / "Debug.md"
CACHE = ROOT / "build" / "lockstep_cache"
RUN_PROBE = ROOT / "tools" / "debug" / "run_probe.py"

sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / "tools" / "debug"))
import presets  # noqa: E402
import diff  # noqa: E402
import run_probe  # noqa: E402


def nes_key(preset_text: str, maxf: int) -> str:
    h = hashlib.sha256()
    h.update(NES_ROM.read_bytes())
    h.update(preset_text.encode("utf-8"))
    h.update((HERE / "capture.lua").read_bytes())
    h.update(RUN_PROBE.read_bytes())
    # EmuHawk build: exe, core DLLs, and the config run_probe copies
    # (core sync settings live there).
    emu = run_probe.EMU
    parts = [emu] + sorted((emu.parent / "dll").glob("*")) + [emu.parent / "config.ini"]
    for f in parts:
        if f.is_file():
            st = f.stat()
            h.update(f"{f.name}:{st.st_size}:{int(st.st_mtime)};".encode())
    h.update((emu.parent / "config.ini").read_bytes())
    h.update(f"maxf={maxf}".encode())
    return h.hexdigest()


def capture(plat: str, rom: Path, out: Path, prefix_name: str, preset_lua: Path,
            maxf: int, seed: str, gold: str, timeout: int) -> int:
    prefix = (out / prefix_name).as_posix()
    r = subprocess.run([sys.executable, str(RUN_PROBE),
                        str(HERE / "capture.lua"), str(out / f"run_{prefix_name}"),
                        "--rom", str(rom), "--timeout", str(timeout),
                        "--subst", f"PRESET={preset_lua.as_posix()}",
                        f"OUT={prefix}", f"MAXF={maxf}", f"SEED={seed}", f"GOLD={gold}"])
    print(f"{plat}: runner exit {r.returncode}")
    return r.returncode


def nes_cached(p: dict, out: Path, prefix_name: str, maxf: int, timeout: int,
               use_cache: bool) -> str:
    """NES capture into out/<prefix_name>.*, through the cache. Returns 'hit'/'miss'/'fail'."""
    text = presets.to_lua(p)
    # The NES capture never reads PRESET.gate: allow edits keep the key.
    # write_watch is Genesis-only debug: not part of the NES key either.
    key = nes_key(presets.to_lua({**p, "allow": [], "write_watch": []}), maxf)
    cdir = CACHE / key
    files = [f for f in cdir.glob("nes.*")] if (use_cache and (cdir / "nes.ram").exists()) else []
    if files:
        for f in files:
            shutil.copy2(f, out / (prefix_name + f.name[3:]))
        state = "hit"
    else:
        preset_lua = out / f"preset_{prefix_name}.lua"
        preset_lua.write_text(text, encoding="utf-8")
        rc = capture("nes", NES_ROM, out, prefix_name, preset_lua, maxf, "", "", timeout)
        # Complete = runner exit 0 (no timeout kill), no .err, and the
        # capture's own end line ("frames=N") written after the last row.
        try:
            completed_ticks(out, prefix_name)
            ok = rc == 0
        except (OSError, ValueError):
            ok = False
        state = "miss" if ok else "fail"
        if ok and use_cache:
            tmp = CACHE / (key + ".tmp")
            shutil.rmtree(tmp, ignore_errors=True)
            tmp.mkdir(parents=True)
            for f in out.glob(f"{prefix_name}.*"):
                if f.is_file():
                    shutil.copy2(f, tmp / ("nes" + f.name[len(prefix_name):]))
            shutil.rmtree(cdir, ignore_errors=True)
            tmp.rename(cdir)
    if state == "hit":
        try:
            completed_ticks(out, prefix_name)
        except (OSError, ValueError):
            state = "fail"
    (out / f"{prefix_name}.cache").write_text(f"{state} {key}\n", encoding="utf-8")
    print(f"nes cache {state} {key[:16]}")
    return state


def seed_of(out: Path) -> str:
    ram = (out / "nes.ram").read_bytes()[:0x800] if (out / "nes.ram").exists() else b""
    if len(ram) != 0x800:
        return ""
    # $4A ChaseLongTimer, $60-$62 chase flag/target: NES runs an init frame
    # before its first update; Genesis toggles the chase flag on its first
    # tick (before seeding). Align them too (T-107).
    cells = [0x15, *range(0x18, 0x25), 0x26, 0x4A, 0x60, 0x61, 0x62]
    return " ".join(f"SEED[0x{a:02X}]=0x{ram[a]:02X}" for a in cells)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("preset", type=Path)
    ap.add_argument("--rom", type=Path, default=GEN_ROM,
                    help="Genesis payload (use a frozen copy for concurrent work)")
    ap.add_argument("--report-suffix", default="",
                    help="append a safe suffix to Lua/report names; baseline name stays unchanged")
    ap.add_argument("--frames", type=int, default=100000)
    ap.add_argument("--pc-profile", metavar="FIRST:LAST",
                    help="Genesis 68K PC histogram over VIDEO frames FIRST..LAST "
                         "(writes gen.pcprof; report with pc_profile.py)")
    ap.add_argument("--frame-dump", action="store_true",
                    help="also dump RAM every video frame (<plat>.fram/.frtick, lag work)")
    ap.add_argument("--nes-only", action="store_true",
                    help="capture the NES only (route design; no Genesis run, no diff)")
    ap.add_argument("--snap", metavar="F1,F2,...",
                    help="also dump the video domains at these game ticks (T-136) "
                         "(<plat>.fNNNNN.<oam|nt|pal|vram|cram|vsram>)")
    ap.add_argument("--vframes", metavar="T0,T1[,MAX]",
                    help="dump the video domains + screenshot of every video frame whose "
                         "tick is in [T0,T1] (at most MAX, default 200) as <plat>.vNNNNN.*")
    ap.add_argument("--write-watch", metavar="ADDR,...",
                    help="Genesis: log every write (value, 68K PC, frame) to these 68K bus "
                         "addresses (hex, e.g. FF7FFE) in gen.txt (memory-corruption hunts)")
    ap.add_argument("--write-watch-nes", metavar="ADDR,...",
                    help="NES: log every write (value, 6502 PC, frame, FrameCounter) to these "
                         "System Bus addresses (hex, e.g. 009D) in nes.txt")
    ap.add_argument("--full", action="store_true",
                    help="no fail-fast: the Genesis runs the whole script (milestone evidence, --bless)")
    ap.add_argument("--no-cache", action="store_true", help="rerun the NES capture")
    ap.add_argument("--bless", action="store_true",
                    help="write the full-RAM ratchet baseline from this run (needs --full)")
    a = ap.parse_args()
    if a.report_suffix and not re.fullmatch(r"[A-Za-z0-9_-]+", a.report_suffix):
        ap.error("--report-suffix permits only letters, digits, underscores and hyphens")

    spec = json.loads(a.preset.read_text(encoding="utf-8-sig"))
    p = presets.build(spec)
    p["name"] += a.report_suffix
    if a.pc_profile:
        p["pc_profile"] = [int(x) for x in a.pc_profile.split(":")]
    if a.frame_dump:
        p["frames"] = True
    if a.snap:
        p["snap"] = [int(x) for x in a.snap.split(",")]
    if a.write_watch_nes:
        p["write_watch_nes"] = [int(x, 16) for x in a.write_watch_nes.split(",")]
    if a.write_watch:
        p["write_watch"] = [int(x, 16) for x in a.write_watch.split(",")]
    if a.vframes:
        v = [int(x) for x in a.vframes.split(",")]
        p["vframes"] = v + [200] if len(v) == 2 else v
    out = ROOT / "builds" / "reports" / "lockstep" / p["name"]
    out.mkdir(parents=True, exist_ok=True)
    for f in out.glob("*"):
        if f.is_file():
            f.unlink()
    preset_lua = out / "preset.lua"
    preset_lua.write_text(presets.to_lua(p), encoding="utf-8")

    # Long scripts and --snap dumps outrun a fixed emulator timeout.
    frames = min(a.frames, sum(n for n, _ in p["script"]))
    timeout = (300 + frames // 10 + 20 * len(p.get("snap", []))
               + 2 * (p.get("vframes") or [0, 0, 0])[2])
    if nes_cached(p, out, "nes", a.frames, timeout, not a.no_cache) == "fail":
        err = out / "nes.err"
        why = err.read_text(encoding="utf-8", errors="replace").strip() if err.exists() else "incomplete (timeout?)"
        print(f"ERROR nes: {why}")
        return 1
    if a.nes_only:
        return 0

    gold = "" if a.full else (out / "nes.ram").as_posix()
    rc = capture("gen", a.rom, out, "gen", preset_lua, a.frames, seed_of(out), gold, timeout)
    try:
        completed_ticks(out, "gen")
    except (OSError, ValueError) as e:
        print(f"ERROR gen: {e}")
        return 1
    if rc != 0:
        print(f"ERROR gen: runner failed ({rc}); capture cannot establish acceptance")
        return 1

    ff = diff.failfast(out)
    if ff is not None and ff[1] >= 0:
        # NES video domains at the Genesis snapshot tick, same script.
        snap_t = ff[1]
        q = dict(p)
        q["snap"] = sorted(set(p.get("snap", [])) | {snap_t})
        nes_cached(q, out, "nes_ff", snap_t + 1, timeout, not a.no_cache)
        for f in out.glob("nes_ff.f*"):
            f.replace(out / ("nes" + f.name[len("nes_ff"):]))
    return diff.main(out, spec, a.bless)


if __name__ == "__main__":
    raise SystemExit(main())
