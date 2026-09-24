"""T-001: re-run an existing accepted probe against the current Debug.md.

Copies <src_dir>/<lua> into t001-merged/<name>/, rewrites only the output
directory string (so the original evidence stays untouched), launches an
isolated hidden BizHawk (private config, owned process, timeout) exactly
like the original run_*.py runners, and records ROM/script hashes.

    python run.py <name> <src_dir_relative_to_recovery> <lua_file> [timeout_s]
"""
import ctypes, hashlib, json, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY")
REC = ROOT / "builds/reports/recovery"
EMU = Path(r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe")


def short(path):
    buf = ctypes.create_unicode_buffer(520)
    if not ctypes.windll.kernel32.GetShortPathNameW(str(path), buf, 520):
        raise OSError(path)
    return buf.value


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


name, src, lua = sys.argv[1], sys.argv[2], sys.argv[3]
timeout = int(sys.argv[4]) if len(sys.argv) > 4 else 120
out = REC / "t001-merged" / name
out.mkdir(parents=True, exist_ok=True)
old_prefix = f"C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/recovery/{src}/"
new_prefix = out.as_posix() + "/"
src_path = (ROOT / src / lua) if src.startswith("tools/") else (REC / src / lua)
text = src_path.read_text(encoding="utf-8")
if src.startswith("tools/"):
    pass  # repo probe: writes its own fixed report path; copied verbatim
elif old_prefix not in text:
    raise SystemExit(f"output prefix not found in {lua}")
else:
    text = text.replace(old_prefix, new_prefix)
probe = out / lua
probe.write_text(text, encoding="utf-8")

stage = Path(r"C:\tmp\claude_t001") / name
stage.mkdir(parents=True, exist_ok=True)
cfg = json.loads((EMU.parent / "config.ini").read_text(encoding="utf-8-sig"))
cfg["SoundEnabled"] = False
cfg["SingleInstanceMode"] = False
for entry in cfg.get("PathEntries", {}).get("Paths", []):
    if entry.get("Type") == "Base":
        entry["Path"] = str(stage / entry["System"])
    elif entry.get("Type") == "Firmware":
        entry["Path"] = str(EMU.parent / "Firmware")
config = stage / "config.ini"
config.write_text(json.dumps(cfg), encoding="utf-8")
staged_lua = stage / lua
shutil.copy2(probe, staged_lua)

si = subprocess.STARTUPINFO()
si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
si.wShowWindow = 0
rom = ROOT / "builds/Debug.md"
cmd = [short(EMU), "--gdi", f"--config={config}", f"--lua={staged_lua}", short(rom)]
code = None
with (out / "emuhawk.log").open("w", encoding="utf-8") as log:
    p = subprocess.Popen(cmd, cwd=EMU.parent, stdout=log, stderr=subprocess.STDOUT, startupinfo=si)
    try:
        code = p.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        p.kill()
        p.wait(timeout=10)
        code = "timeout"
(out / "launch.json").write_text(json.dumps({
    "rom_sha256": sha(rom),
    "script_sha256": sha(probe),
    "source_script": f"{src}/{lua}",
    "exit_code": code,
}, indent=2), encoding="utf-8")
print(f"{name}: exit={code}")
for f in sorted(out.iterdir()):
    print("  ", f.name, f.stat().st_size)
