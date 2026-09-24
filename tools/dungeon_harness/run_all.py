"""Run selected BizHawk dungeon scenarios; entry smoke is never completion.

Examples:
  python tools/dungeon_harness/run_all.py --level 1 --quest 1 --entry-only --emuhawk PATH
  python tools/dungeon_harness/run_all.py --level 1 --quest 1 --dry-run
Completion requires a pinned current-ROM state and a completion-capable probe.
Exit: 0 selected scope passed / dry files valid; 1 scenario FAIL; 2 ERROR.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "tools/dungeon_harness"
MANIFEST = HARNESS / "manifest.json"
REPORTS_DIR = ROOT / "builds/reports/dungeon_harness"


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def select_rows(rows: list[dict], level: int | None, quest: int | None) -> list[dict]:
    return [r for r in rows if (level is None or r["level"] == level)
            and (quest is None or r["quest"] == quest)]


def checked_path(base: Path, relative: str) -> Path:
    path = (base / relative).resolve()
    if not path.is_relative_to(base.resolve()):
        raise ValueError(f"path outside scenario directory: {relative}")
    if not path.is_file():
        raise ValueError(f"missing file: {path}")
    return path


def prepare_row(row: dict, entry_only: bool, rom_hash: str) -> tuple[Path, Path | None]:
    if entry_only:
        if not row.get("entry_probe"):
            raise ValueError("entry probe not implemented for this row")
        return checked_path(HARNESS / "probes", row["entry_probe"]), None
    # Check required state before checking probe capability so missing inputs
    # are explicit even for legacy load-only rows.
    state = checked_path(HARNESS / "save_states", row["save_state"])
    if not row.get("save_state_sha256") or sha256_file(state) != row["save_state_sha256"]:
        raise ValueError("save-state hash missing or mismatched")
    if row.get("state_rom_sha256") != rom_hash:
        raise ValueError("save state is not pinned to this ROM")
    if row.get("probe_scope") != "completion":
        raise ValueError("legacy load-only probe cannot verify completion")
    return checked_path(HARNESS / "probes", row["probe"]), state


def short_path(path: Path) -> str:
    value = str(path.resolve())
    if os.name == "nt":
        buf = ctypes.create_unicode_buffer(32768)
        n = ctypes.windll.kernel32.GetShortPathNameW(value, buf, len(buf))
        if 0 < n < len(buf):
            value = buf.value
    if any(c.isspace() for c in value):
        raise ValueError(f"BizHawk argument needs a space-free/8.3 path: {path}")
    return value


def lua_string(value: str) -> str:
    # All supplied paths are UTF-8; escape backslash/control characters for Lua.
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace(
        "\r", "\\r").replace("\n", "\\n") + '"'


def validate_report(report: dict, context: dict) -> str:
    for field in ("run_id", "rom_sha256", "level", "quest", "scope"):
        if report.get(field) != context[field]:
            raise ValueError(f"report identity/scope mismatch: {field}")
    verdict = report.get("verdict")
    if verdict not in {"PASS", "ENTRY_ONLY", "FAIL", "ERROR"}:
        raise ValueError(f"invalid verdict: {verdict}")
    if verdict in {"FAIL", "ERROR"}:
        return verdict
    if context["scope"] == "entry":
        if verdict != "ENTRY_ONLY":
            raise ValueError("entry scenario must report ENTRY_ONLY")
        entry = report.get("entry", {})
        if not (entry.get("room") == context["expected_room"]
                and entry.get("level") == context["level"]
                and entry.get("quest") == context["quest"]
                and entry.get("frame_delta", 0) > 0):
            raise ValueError("entry assertions missing or failed")
    else:
        if verdict != "PASS" or not all(report.get("events", {}).get(k) is True
                for k in ("entered", "boss_killed", "reward_collected")):
            raise ValueError("completion events missing; entry-only is not completion")
    return verdict


def launch_row(row: dict, probe: Path, state: Path | None, args: argparse.Namespace,
               rom_hash: str, run_dir: Path) -> dict:
    scope = "entry" if args.entry_only else "completion"
    context = {
        "run_id": run_dir.name, "rom_sha256": rom_hash,
        "level": row["level"], "quest": row["quest"], "scope": scope,
        "expected_room": int(row["entry_room"], 16) if row.get("entry_room") else -1,
        "out_path": str(run_dir / "probe.json"),
        "screenshot_path": str(run_dir / "entry.png"),
        "state_path": str(run_dir / "entry.State"),
        "input_state": str(state) if state else "",
    }
    (run_dir / "context.json").write_text(json.dumps(context, indent=2), encoding="utf-8")
    values = ",\n".join(f"  {k} = {lua_string(v) if isinstance(v, str) else v}"
                        for k, v in context.items())
    wrapper = ("HARNESS = {\n" + values + "\n}\n"
               + f"dofile({lua_string(str(HARNESS / 'report.lua'))})\n"
               + "local ok, err = pcall(function()\n"
               + f"  dofile({lua_string(str(probe))})\n"
               + "end)\n"
               + "if not ok then HARNESS.finish('ERROR', {error=tostring(err)}) end\n")
    # Space-free wrapper/config paths; preserve probe diagnostics in run_dir.
    stage = Path(tempfile.mkdtemp(prefix="zelda-probe-"))
    wrapper_path = stage / "run.lua"
    wrapper_path.write_text(wrapper, encoding="utf-8")
    config = stage / "config.ini"
    # Retain this installation's working graphics/core settings, but isolate
    # mutable paths and disable automatic recent-file loading and sound output.
    installed_config = args.emuhawk.parent / "config.ini"
    settings = json.loads(installed_config.read_text(encoding="utf-8-sig"))
    settings["SoundEnabled"] = False
    settings["SingleInstanceMode"] = False
    def disable_autoload(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if key == "AutoLoad":
                    value[key] = False
                else:
                    disable_autoload(child)
        elif isinstance(value, list):
            for child in value:
                disable_autoload(child)
    disable_autoload(settings)
    for entry in settings.get("PathEntries", {}).get("Paths", []):
        if entry["Type"] == "Base":
            entry["Path"] = str(stage / entry["System"])
            Path(entry["Path"]).mkdir(parents=True, exist_ok=True)
        elif entry["Type"] == "Firmware":
            entry["Path"] = str(args.emuhawk.parent / "Firmware")
        elif entry["Type"] in {"Save RAM", "Savestates", "Screenshots", "Cheats"}:
            entry["Path"] = str(stage / entry["System"] / entry["Type"])
            Path(entry["Path"]).mkdir(parents=True, exist_ok=True)
    config.write_text(json.dumps(settings), encoding="utf-8")
    exe = short_path(args.emuhawk)
    config_arg = str(Path(short_path(stage)) / "config.ini")
    command = [exe, "--gdi", "--config=" + config_arg, "--lua=" + short_path(wrapper_path),
               short_path(args.rom)]
    startup = None
    if os.name == "nt":
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
    with (run_dir / "emuhawk.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=args.emuhawk.parent,
                                   stdout=log, stderr=subprocess.STDOUT,
                                   startupinfo=startup)
        try:
            code = process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            process.kill()  # only this test's process
            process.wait(timeout=10)
            raise ValueError(f"BizHawk timeout after {args.timeout}s; see {run_dir}")
    (run_dir / "launch.json").write_text(json.dumps({
        "exit_code": code, "emuhawk": str(args.emuhawk),
        "emuhawk_sha256": sha256_file(args.emuhawk),
        "staging": str(stage),
    }, indent=2), encoding="utf-8")
    if code:
        raise ValueError(f"BizHawk exited {code}; see {run_dir}")
    report_path = run_dir / "probe.json"
    if not report_path.is_file():
        raise ValueError("BizHawk exited without this run's report")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    verdict = validate_report(report, context)
    if sha256_file(args.rom) != rom_hash:
        raise ValueError("ROM changed during the probe")
    if verdict == "ENTRY_ONLY":
        captured = run_dir / "entry.State"
        if not captured.is_file():
            raise ValueError("entry state was not captured")
        report["state_sha256"] = sha256_file(captured)
    report["verdict"] = verdict
    report["scope_note"] = ("Debug chord and probe warp; no normal traversal, boss kill or reward tested."
                            if args.entry_only else "Completion probe from pinned starting state.")
    return report


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--quest", type=int, choices=(1, 2))
    ap.add_argument("--level", type=int, choices=range(1, 10))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--entry-only", action="store_true")
    ap.add_argument("--rom", type=Path, default=ROOT / "builds/Debug.md")
    ap.add_argument("--emuhawk", type=Path,
                    default=Path(os.environ["BIZHAWK_EXE"]) if os.environ.get("BIZHAWK_EXE") else None)
    ap.add_argument("--timeout", type=int, default=120)
    args = ap.parse_args(argv)
    try:
        if args.timeout <= 0:
            raise ValueError("--timeout must be positive")
        args.rom = args.rom.resolve(strict=True)
        if not args.dry_run:
            if args.emuhawk is None:
                raise ValueError("provide --emuhawk or BIZHAWK_EXE")
            args.emuhawk = args.emuhawk.resolve(strict=True)
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        rows = select_rows(manifest["rows"], args.level, args.quest)
        if not rows:
            raise ValueError("no selected rows")
        rom_hash = sha256_file(args.rom)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    exit_code = 0
    for row in rows:
        run_dir = REPORTS_DIR / f"L{row['level']}Q{row['quest']}-{uuid.uuid4().hex[:12]}"
        run_dir.mkdir(parents=True)
        try:
            probe, state = prepare_row(row, args.entry_only, rom_hash)
            if args.dry_run:
                report = {"verdict": "DRY_OK", "scope": "files-only",
                          "rom_sha256": rom_hash}
            else:
                report = launch_row(row, probe, state, args, rom_hash, run_dir)
        except (OSError, ValueError, KeyError, TypeError) as exc:
            report = {"verdict": "ERROR", "error": str(exc), "rom_sha256": rom_hash}
        verdict = report["verdict"]
        exit_code = max(exit_code, 2 if verdict == "ERROR" else 1 if verdict == "FAIL" else 0)
        (run_dir / "result.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"L{row['level']}Q{row['quest']} {verdict}: {run_dir / 'result.json'}")
        if report.get("error"):
            print("  " + report["error"])
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
