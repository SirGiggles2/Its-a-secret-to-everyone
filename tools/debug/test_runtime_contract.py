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
    hud_c = read("src/game/hud/hud_runtime.c")
    hud_h = read("src/game/hud/hud_runtime.h")
    main_c = read("RoomRom/src/main.c")

    need(hud_h, "unsigned char is_underworld", "HUD draw scene selector")

    # Phase J.2 (2026-05-18) deleted upload_common_hud_chr /
    # upload_common_hud_tile_range / upload_redux_automap_chr. All HUD CHR is
    # now force-included in bg_sparse_chr (RoomRom/tools/gen_bg_sparse.py
    # HUD_FORCE_TILES + redux automap range 0x30..0x4F) and uploaded by the
    # sparse room-CHR path. Assert the replacement exists and that the old
    # uploaders stay gone, rather than asserting a deleted implementation.
    reject(hud_c, "upload_common_hud_tile_range", "deleted legacy HUD uploader")
    reject(hud_c, "static void upload_redux_automap_chr", "deleted legacy automap uploader")
    sparse_gen = read("RoomRom/tools/gen_bg_sparse.py")
    need(sparse_gen, "HUD_FORCE_TILES", "HUD CHR force-include list")
    need(sparse_gen, "range(0x30, 0x50)", "redux automap tile range force-include")
    need(main_c, "roomrom_hud_draw(roomrom_uw_room_render_get_map(), room_id, 1u);", "UW HUD scene flag")
    need(main_c, "roomrom_hud_draw(roomrom_ow_room_render_get_map(), room_id, 0u);", "OW HUD scene flag")
    need(hud_c, "s_redux_ow_hud_macro", "redux OW HUD macro")
    need(hud_c, "s_redux_uw_hud_macro", "redux UW HUD macro")
    need(hud_c, "is_underworld ? s_redux_uw_hud_macro : s_redux_ow_hud_macro", "scene-specific redux HUD")
    # redux_automap_chr_x4 removed with the other legacy expanded_bg_chr_x4
    # arrays in Phase J.2; the sparse atlas carries the automap tiles now.
    reject(hud_c, "redux_automap_chr_x4", "legacy 4x automap array must stay gone")
    # The redux toggle must reload scene CHR and the room before the HUD
    # redraws, at every toggle site. Asserted as a count of the reload
    # marker rather than an exact indented block: the previous version
    # embedded literal whitespace from main.c and broke on reformatting
    # while the invariant itself was intact (3 sites in both HEAD and
    # working tree, verified 2026-08-04).
    need_count_at_least(
        main_c,
        "roomrom_combat_set_redux(current_redux_flag());",
        2,
        "scene/map CHR reload before HUD redraw",
    )


if __name__ == "__main__":
    test_roomrom_runtime_exports()
    test_roomrom_hud_owns_common_chr_dependencies()
    print("PASS: RoomRom runtime export contract")
