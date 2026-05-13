from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label}: missing {needle!r}")


def reject(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"{label}: unexpected {needle!r}")


def test_uw_walk_contract_checks_debug_build_source_list() -> None:
    test_src = read("RoomRom/tools/test_uw_walk_model.py")
    need(test_src, 'ROOT / "tools" / "debug" / "build_debug.py"',
         "UW walk model contract must inspect Debug build source list")
    reject(test_src, 'ROOT / "RoomRom" / "build.bat"',
           "UW walk model contract must not inspect retired standalone build")


def test_intro_asset_tests_are_directly_runnable() -> None:
    test_src = read("tools/tests/test_extract_intro_assets.py")
    need(test_src, "sys.path.insert(0, str(REPO))",
         "direct execution must add repo root before importing tools package")


def test_extraction_probe_stays_inside_repo_reports() -> None:
    probe_src = read("tools/test_extraction_directly.py")
    reject(probe_src, "WHAT IF", "probe must not hard-code retired external tree")
    need(probe_src, "builds/reports/extraction_direct",
         "probe output should stay under ignored build reports")
    need(probe_src, "REFERENCE_ROM",
         "probe should allow explicit reference ROM override")


def test_roomrom_debug_tools_target_current_debug_rom() -> None:
    for rel in (
        "RoomRom/tools/launch_uw_live_debug.py",
        "RoomRom/tools/probe_uw_collision_boot.py",
        "RoomRom/tools/probe_uw_west_exit.py",
        "RoomRom/tools/run_uw_walk_reason_probe.py",
    ):
        src = read(rel)
        reject(src, 'ROOT / "RoomRom" / "out" / "Debug.md"',
               f"{rel} must target builds/Debug.md")
        reject(src, 'ROOT / "RoomRom" / "out" / "rom.out"',
               f"{rel} must use build/debug_project/out/Debug.out")
        reject(src, "RoomRom/build.bat",
               f"{rel} must instruct users to run Debug.bat")
        reject(src, "WHAT IF",
               f"{rel} must not search the retired external tree")


def test_uw_debug_lua_enters_debug_gameplay_before_sampling() -> None:
    for rel in (
        "RoomRom/tools/probe_uw_west_exit.py",
        "RoomRom/tools/probe_uw_collision_boot.py",
        "RoomRom/tools/uw_walk_reason_probe.lua",
        "RoomRom/tools/uw_live_walk_debug.lua",
    ):
        src = read(rel)
        need(src, '"P1 A"', f"{rel} must press the A+B+C debug chord")
        need(src, '"P1 B"', f"{rel} must press the A+B+C debug chord")
        need(src, '"P1 C"', f"{rel} must press the A+B+C debug chord")
        need(src, "0xA4", f"{rel} must wait for the A4 probe magic first")
        need(src, "0x07F0", f"{rel} must wait for PHASE_TITLE_DISPLAY first")


def test_human_input_recorder_launcher_loads_script_and_game() -> None:
    src = read("tools/debug/launch_human_input_recorder.py")
    need(src, "record_human_input.lua", "recorder launcher must use the passive recorder")
    need(src, 'ROOT / "builds" / "Debug.md"', "recorder launcher must target Debug.md")
    need(src, "datetime.now", "recorder launcher must not overwrite prior recordings")
    need(src, "input_%Y%m%d_%H%M%S.jsonl", "recorder launcher must use timestamped default output")
    need(src, "f\"--lua={short_path(LUA)}\"", "recorder launcher must pass the Lua script")
    need(src, "short_path(ROM)", "recorder launcher must pass the ROM too")
    need(src, "SetForegroundWindow", "recorder launcher must focus BizHawk for human input")
    need(src, "ShowWindowAsync", "recorder launcher must restore BizHawk for human input")
    need(src, "focus_process_window(proc.pid)", "recorder launcher must focus after launch")
    reject(src, "joypad.set", "recorder launcher must not drive inputs")


def test_human_input_recorder_default_is_timestamped() -> None:
    src = read("tools/debug/record_human_input.lua")
    need(src, "os.date", "direct Lua recorder default must be timestamped")
    need(src, "input_%Y%m%d_%H%M%S.jsonl", "direct Lua recorder must not overwrite input.jsonl")


if __name__ == "__main__":
    test_uw_walk_contract_checks_debug_build_source_list()
    test_intro_asset_tests_are_directly_runnable()
    test_extraction_probe_stays_inside_repo_reports()
    test_roomrom_debug_tools_target_current_debug_rom()
    test_uw_debug_lua_enters_debug_gameplay_before_sampling()
    test_human_input_recorder_launcher_loads_script_and_game()
    test_human_input_recorder_default_is_timestamped()
    print("PASS: Tool hygiene contract")
