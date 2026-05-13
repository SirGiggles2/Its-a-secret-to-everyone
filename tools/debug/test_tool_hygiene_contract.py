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


def need_file(path: str, label: str) -> None:
    if not (ROOT / path).is_file():
        raise AssertionError(f"{label}: missing {path}")


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


def test_regression_matrix_uses_timezone_aware_utc() -> None:
    src = read("tools/run_regression_matrix.py")
    reject(src, "datetime.datetime.utcnow()",
           "regression matrix must avoid deprecated naive UTC timestamps")
    need(src, "datetime.UTC",
         "regression matrix timestamps must use timezone-aware UTC")


def test_ph5_t52_probe_uses_current_debug_game_and_symbols() -> None:
    need_file("tools/probes/run_ph5_uw_t52_special_cases.py",
              "T52 probe must have a launcher that passes Lua and ROM together")

    lua = read("tools/probes/ph5_uw_t52_special_cases.lua")
    launcher = read("tools/probes/run_ph5_uw_t52_special_cases.py")

    reject(lua, "RoomRom/out/rom.out",
           "T52 probe must not document retired RoomRom symbol output")
    reject(lua, "s_link_x",
           "T52 probe must not depend on retired s_link_x")
    reject(lua, "s_link_y",
           "T52 probe must not depend on retired s_link_y")
    need(lua, 'os.getenv("CODEX_T52_LINK_X")',
         "T52 probe must receive current players[0].x from launcher")
    need(lua, 'os.getenv("CODEX_T52_LINK_Y")',
         "T52 probe must receive current players[0].y from launcher")
    need(lua, '"P1 A"', "T52 probe must press A+B+C to enter debug gameplay")
    need(lua, '"P1 B"', "T52 probe must press A+B+C to enter debug gameplay")
    need(lua, '"P1 C"', "T52 probe must press A+B+C to enter debug gameplay")
    need(lua, "0xA4", "T52 probe must wait for probe magic before input")
    need(lua, "0x07F0", "T52 probe must wait for title display phase")

    need(launcher, 'ROOT / "builds" / "Debug.md"',
         "T52 launcher must target builds/Debug.md")
    need(launcher, 'ROOT / "build" / "debug_project" / "out" / "Debug.out"',
         "T52 launcher must resolve current Debug.out symbols")
    need(launcher, 'f"--lua={short_path(LUA)}"',
         "T52 launcher must pass the Lua script")
    need(launcher, "short_path(ROM)",
         "T52 launcher must pass the Debug ROM too")
    need(launcher, '"players"',
         "T52 launcher must resolve players[0] instead of retired link globals")
    need(launcher, '"CODEX_T52_LINK_X"',
         "T52 launcher must export players[0].x")
    need(launcher, '"CODEX_T52_LINK_Y"',
         "T52 launcher must export players[0].y")


def test_roomrom_generation_gates_do_not_name_retired_build() -> None:
    for rel in (
        "tools/probes/check_roomrom_data_manifest.py",
        "tools/probes/check_generated_freshness.py",
    ):
        src = read(rel)
        reject(src, "RoomRom/build.bat",
               f"{rel} must not point users at the retired RoomRom build")


def test_uw_walkability_overlay_uses_current_debug_launcher_and_symbols() -> None:
    need_file("RoomRom/tools/launch_uw_walkability_overlay.py",
              "UW overlay must have a launcher that passes Lua and ROM together")

    lua = read("RoomRom/tools/uw_walkability_overlay.lua")
    launcher = read("RoomRom/tools/launch_uw_walkability_overlay.py")

    reject(lua, "rom.out",
           "UW overlay must not depend on retired symbol output")
    reject(lua, "GEN_TILE_WALKABLE_ADDR = 0x",
           "UW overlay must not hard-code stale walkability address")
    reject(lua, "GEN_LINK_X_ADDR = 0x",
           "UW overlay must not hard-code stale player x address")
    reject(lua, "GEN_LINK_Y_ADDR = 0x",
           "UW overlay must not hard-code stale player y address")
    need(lua, 'os.getenv("CODEX_UW_OVERLAY_TILE_WALKABLE")',
         "UW overlay must receive current walkability symbol")
    need(lua, 'os.getenv("CODEX_UW_OVERLAY_LINK_X")',
         "UW overlay must receive current players[0].x")
    need(lua, 'os.getenv("CODEX_UW_OVERLAY_LINK_Y")',
         "UW overlay must receive current players[0].y")

    need(launcher, 'ROOT / "builds" / "Debug.md"',
         "UW overlay launcher must target builds/Debug.md")
    need(launcher, 'ROOT / "build" / "debug_project" / "out" / "Debug.out"',
         "UW overlay launcher must resolve current Debug.out symbols")
    need(launcher, 'f"--lua={short_path(LUA)}"',
         "UW overlay launcher must pass the Lua script")
    need(launcher, "short_path(ROM)",
         "UW overlay launcher must pass the Debug ROM too")
    need(launcher, '"players"',
         "UW overlay launcher must resolve players[0] instead of retired link globals")


def test_verify_chr_live_launches_lua_and_rom_positionally() -> None:
    src = read("RoomRom/tools/verify_chr_live.py")
    reject(src, "--rom=",
           "CHR live verifier must pass the ROM as a BizHawk positional argument")
    need(src, "short_path",
         "CHR live verifier must use short paths for BizHawk CLI")
    need(src, 'f"--lua={short_path(probe_copy)}"',
         "CHR live verifier must pass the Lua script with --lua")
    need(src, "short_path(rom_path)",
         "CHR live verifier must pass the ROM too")


def test_retired_room_render_probe_fails_closed() -> None:
    src = read("tools/probes/probe_room_render.py")
    reject(src, "Title_ow_debug",
           "retired OW room probe must not emit legacy Title probe ROMs")
    reject(src, "OW_DEBUG_ENTRY",
           "retired OW room probe must not try to compile removed debug entry code")
    reject(src, 'REPO_ROOT / "builds" / "Debug.out"',
           "retired OW room probe must not link against nonexistent builds/Debug.out")
    need(src, "retired", "retired OW room probe must fail closed with a clear reason")
    need(src, "tools/room_checklist.py",
         "retired OW room probe must point to current room capture tooling")
    need(src, "tools/compare_room77_parity.py",
         "retired OW room probe must point to current parity comparator")


if __name__ == "__main__":
    test_uw_walk_contract_checks_debug_build_source_list()
    test_intro_asset_tests_are_directly_runnable()
    test_extraction_probe_stays_inside_repo_reports()
    test_roomrom_debug_tools_target_current_debug_rom()
    test_uw_debug_lua_enters_debug_gameplay_before_sampling()
    test_human_input_recorder_launcher_loads_script_and_game()
    test_human_input_recorder_default_is_timestamped()
    test_regression_matrix_uses_timezone_aware_utc()
    test_ph5_t52_probe_uses_current_debug_game_and_symbols()
    test_roomrom_generation_gates_do_not_name_retired_build()
    test_uw_walkability_overlay_uses_current_debug_launcher_and_symbols()
    test_verify_chr_live_launches_lua_and_rom_positionally()
    test_retired_room_render_probe_fails_closed()
    print("PASS: Tool hygiene contract")
