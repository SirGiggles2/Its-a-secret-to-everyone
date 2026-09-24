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
    a = ap.parse_args()

    spec = json.loads(a.preset.read_text(encoding="utf-8"))
    p = presets.build(spec)
    out = ROOT / "builds" / "reports" / "lockstep" / p["name"]
    out.mkdir(parents=True, exist_ok=True)
    for f in out.glob("*"):
        if f.is_file():
            f.unlink()
    preset_lua = out / "preset.lua"
    preset_lua.write_text(presets.to_lua(p), encoding="utf-8")

    seed = ""
    for plat, rom in (("nes", NES_ROM), ("gen", GEN_ROM)):
        prefix = (out / plat).as_posix()
        r = subprocess.run([sys.executable, str(ROOT / "tools" / "debug" / "run_probe.py"),
                            str(HERE / "capture.lua"), str(out / f"run_{plat}"),
                            "--rom", str(rom), "--timeout", "300",
                            "--subst", f"PRESET={preset_lua.as_posix()}",
                            f"OUT={prefix}", f"MAXF={a.frames}", f"SEED={seed}"])
        print(f"{plat}: runner exit {r.returncode}")
        if plat == "nes":
            ram = (out / "nes.ram").read_bytes()[:0x800] if (out / "nes.ram").exists() else b""
            if len(ram) == 0x800:
                cells = [0x15, *range(0x18, 0x25), 0x26]
                seed = " ".join(f"SEED[0x{a:02X}]=0x{ram[a]:02X}" for a in cells)
    return diff.main(out)


if __name__ == "__main__":
    raise SystemExit(main())
