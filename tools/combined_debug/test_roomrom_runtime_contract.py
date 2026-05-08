from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label}: missing {needle!r}")


def need_order(text: str, first: str, second: str, label: str) -> None:
    first_at = text.find(first)
    second_at = text.find(second)
    if first_at < 0 or second_at < 0 or first_at > second_at:
        raise AssertionError(f"{label}: expected {first!r} before {second!r}")


def need_count_at_least(text: str, needle: str, minimum: int, label: str) -> None:
    count = text.count(needle)
    if count < minimum:
        raise AssertionError(f"{label}: expected at least {minimum}, got {count}")


def test_roomrom_runtime_exports() -> None:
    header = read("RoomRom/src/roomrom_debug_runtime.h")
    main_c = read("RoomRom/src/main.c")

    need(header, "void roomrom_debug_enter(void);", "enter export")
    need(header, "void roomrom_debug_tick(void);", "tick export")

    need(main_c, '#include "roomrom_debug_runtime.h"', "runtime header include")
    need(main_c, "void roomrom_debug_enter(void)", "enter implementation")
    need(main_c, "void roomrom_debug_tick(void)", "tick implementation")
    need(main_c, "#ifndef ROOMROM_NO_STANDALONE_MAIN", "standalone main guard")
    need(main_c, "roomrom_debug_enter();", "main calls enter")
    need(main_c, "roomrom_debug_tick();", "main calls tick")


def test_roomrom_hud_owns_common_chr_dependencies() -> None:
    hud_c = read("RoomRom/src/roomrom_hud.c")
    hud_h = read("RoomRom/src/roomrom_hud.h")
    main_c = read("RoomRom/src/main.c")

    need(hud_h, "unsigned char is_underworld", "HUD draw scene selector")
    need(main_c, "roomrom_hud_draw(roomrom_uw_room_render_get_map(), room_id, 1u);", "UW HUD scene flag")
    need(main_c, "roomrom_hud_draw(roomrom_ow_room_render_get_map(), room_id, 0u);", "OW HUD scene flag")
    need(hud_c, "s_redux_ow_hud_macro", "redux OW HUD macro")
    need(hud_c, "s_redux_uw_hud_macro", "redux UW HUD macro")
    need(hud_c, "is_underworld ? s_redux_uw_hud_macro : s_redux_ow_hud_macro", "scene-specific redux HUD")
    need(hud_c, "static void upload_common_hud_chr", "common HUD CHR uploader")
    need(hud_c, "upload_common_hud_tile_range(subpal, 0x00u, 0x15u);", "digits and LIFE glyphs")
    need(hud_c, "upload_common_hud_tile_range(subpal, 0x20u, 0x24u);", "counter x and spaces")
    need(hud_c, "upload_common_hud_tile_range(subpal, 0x61u, 0x6Eu);", "item box glyphs")
    need(hud_c, "upload_common_hud_tile_range(subpal, 0xF7u, 0xF9u);", "status count icons")
    need(hud_c, "upload_common_hud_chr(s);", "common HUD CHR reload before custom tiles")
    need(hud_c, "static void upload_redux_automap_chr", "redux automap CHR uploader")
    need(hud_c, "redux_automap_chr_x4", "redux automap source")
    need(hud_c, "upload_redux_automap_chr(s);", "redux automap reload before custom tiles")
    need_count_at_least(
        main_c,
        "roomrom_scene_load(\n                (s_scene == SCENE_UW) ? ROOMROM_SCENE_UW_L1\n                                      : ROOMROM_SCENE_OVERWORLD,\n                current_redux_flag());\n            roomrom_combat_set_redux(current_redux_flag());\n            load_room(s_room_id);",
        2,
        "scene/map CHR reload before HUD redraw",
    )


if __name__ == "__main__":
    test_roomrom_runtime_exports()
    test_roomrom_hud_owns_common_chr_dependencies()
    print("PASS: RoomRom runtime export contract")
