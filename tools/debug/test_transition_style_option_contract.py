from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label}: missing {needle!r}")


def test_options_schema_has_room_scroll_style() -> None:
    state_h = read("src/game/options/options_state.h")
    need(state_h, "#define OPTIONS_VERSION_V2", "schema version bump")
    need(state_h, "OPTIONS_VERSION_CURRENT OPTIONS_VERSION_V2",
         "current options version")
    need(state_h, "OPTION_ID_ROOM_SCROLL", "room scroll option id")
    need(state_h, "OPTIONS_SCROLL_SMOOTH", "smooth scroll enum")
    need(state_h, "OPTIONS_SCROLL_CLASSIC", "classic scroll enum")
    need(state_h, "unsigned char room_scroll;", "persisted room scroll field")


def test_options_runtime_defaults_and_validates_room_scroll() -> None:
    runtime_c = read("src/game/options/options_runtime.c")
    need(runtime_c, "s->room_scroll = OPTIONS_SCROLL_SMOOTH;",
         "smooth default")
    need(runtime_c, "case OPTION_ID_ROOM_SCROLL:",
         "runtime get/set room scroll case")
    need(runtime_c, "OPTIONS_SCROLL_COUNT",
         "runtime room scroll range validation")
    need(runtime_c, "tmp[11] >= OPTIONS_SCROLL_COUNT",
         "serialized room scroll validation")


def test_file_select_options_exposes_room_scroll_row() -> None:
    options_h = read("src/frontend/fs/fs_options.h")
    options_c = read("src/frontend/fs/fs_options.c")
    render_c = read("src/frontend/fs/fs_options_render.c")
    need(options_h, "#define FS_OPTIONS_ROW_COUNT   16u",
         "option row count includes room scroll and save")
    need(options_h, "#define FS_OPTIONS_SAVE_ROW    15u",
         "save row shifted after room scroll")
    need(options_c, "case OPTION_ID_ROOM_SCROLL:",
         "file-select enum cycle includes room scroll")
    need(render_c, '"ROOM SCROLL"', "room scroll row label")
    need(render_c, "scroll_value_str", "room scroll value formatter")
    need(render_c, "OPTIONS_SCROLL_CLASSIC", "classic value visible")


def test_roomrom_main_uses_saved_transition_style() -> None:
    main_c = read("RoomRom/src/main.c")
    need(main_c, "#define SCROLL_TOTAL_FRAMES_SMOOTH 32u",
         "smooth transition frame count")
    need(main_c, "#define SCROLL_TOTAL_FRAMES_CLASSIC 64u",
         "classic transition frame count")
    need(main_c, "options_consumer_get_room_scroll",
         "main queries saved option")
    need(main_c, "s_scroll_total_frames",
         "transition captures selected frame count")


def test_debug_probes_preserve_saved_options() -> None:
    main_c = read("RoomRom/src/main.c")
    persistence_probe_c = read("src/game/options/probes/options_persistence_probe.c")
    need(main_c, "saved_options[OPTIONS_STATE_SIZE]",
         "debug entry snapshots live options before self-tests")
    need(main_c, "options_runtime_apply(saved_options, OPTIONS_STATE_SIZE)",
         "debug entry restores live options after self-tests")
    need(persistence_probe_c, "sram_options_io_read(saved_options",
         "persistence probe snapshots SRAM option block")
    need(persistence_probe_c, "sram_options_io_write(saved_options",
         "persistence probe restores SRAM option block")


if __name__ == "__main__":
    test_options_schema_has_room_scroll_style()
    test_options_runtime_defaults_and_validates_room_scroll()
    test_file_select_options_exposes_room_scroll_row()
    test_roomrom_main_uses_saved_transition_style()
    test_debug_probes_preserve_saved_options()
    print("PASS: Transition style option contract")
