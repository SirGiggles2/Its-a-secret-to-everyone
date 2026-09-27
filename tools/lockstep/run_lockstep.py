"""Run one lockstep scenario on NES and Genesis, then diff.

    python tools/lockstep/run_lockstep.py <preset.json> [--frames N]

Output: builds/reports/lockstep/<preset name>/{nes,gen}.{ram,txt,png},
diff.txt, diff.json, and each run's launch.json (ROM + script hashes).
NES ROM: roms/Legend of Zelda, The (USA).nes (local reference, never
distributed). Genesis ROM: builds/Debug.md.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
NES_ROM = ROOT / "roms" / "Legend of Zelda, The (USA).nes"
GEN_ROM = ROOT / "builds" / "Debug.md"

sys.path.insert(0, str(HERE))
import presets  # noqa: E402
import diff  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("preset", type=Path)
    ap.add_argument("--frames", type=int, default=100000)
    ap.add_argument("--pc-profile", metavar="FIRST:LAST",
                    help="Genesis 68K PC histogram over VIDEO frames FIRST..LAST "
                         "(writes gen.pcprof; report with pc_profile.py)")
    ap.add_argument("--nes-only", action="store_true",
                    help="capture the NES only (route design; no Genesis run, no diff)")
    ap.add_argument("--snap", metavar="F1,F2,...",
                    help="also dump the video domains at these game ticks (T-136) "
                         "(<plat>.fNNNNN.<oam|nt|pal|vram|cram|vsram>)")
    a = ap.parse_args()

    spec = json.loads(a.preset.read_text(encoding="utf-8"))
    p = presets.build(spec)
    if a.pc_profile:
        p["pc_profile"] = [int(x) for x in a.pc_profile.split(":")]
    if a.snap:
        p["snap"] = [int(x) for x in a.snap.split(",")]
    out = ROOT / "builds" / "reports" / "lockstep" / p["name"]
    out.mkdir(parents=True, exist_ok=True)
    for f in out.glob("*"):
        if f.is_file():
            f.unlink()
    preset_lua = out / "preset.lua"
    preset_lua.write_text(presets.to_lua(p), encoding="utf-8")

    # Long scripts and --snap dumps outrun a fixed emulator timeout.
    frames = min(a.frames, sum(n for n, _ in p["script"]))
    timeout = 300 + frames // 10 + 20 * len(p.get("snap", []))
    seed = ""
    plats = (("nes", NES_ROM),) if a.nes_only else (("nes", NES_ROM), ("gen", GEN_ROM))
    for plat, rom in plats:
        prefix = (out / plat).as_posix()
        r = subprocess.run([sys.executable, str(ROOT / "tools" / "debug" / "run_probe.py"),
                            str(HERE / "capture.lua"), str(out / f"run_{plat}"),
                            "--rom", str(rom), "--timeout", str(timeout),
                            "--subst", f"PRESET={preset_lua.as_posix()}",
                            f"OUT={prefix}", f"MAXF={a.frames}", f"SEED={seed}"])
        print(f"{plat}: runner exit {r.returncode}")
        if plat == "nes":
            ram = (out / "nes.ram").read_bytes()[:0x800] if (out / "nes.ram").exists() else b""
            if len(ram) == 0x800:
                # $4A ChaseLongTimer, $60-$62 chase flag/target: NES runs an
                # init frame before its first update; Genesis toggles the chase
                # flag on its first tick (before seeding). Align them too (T-107).
                cells = [0x15, *range(0x18, 0x25), 0x26, 0x4A, 0x60, 0x61, 0x62]
                seed = " ".join(f"SEED[0x{a:02X}]=0x{ram[a]:02X}" for a in cells)
    if a.nes_only:
        return 0
    return diff.main(out)


if __name__ == "__main__":
    raise SystemExit(main())
