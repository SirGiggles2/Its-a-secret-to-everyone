from __future__ import annotations

# Phase 6 Task 6.2 — NES-faithful movement constants contract.
#
# Asserts that RoomRom main.c implements Link movement with the exact
# constants pulled from the NES Z1 source (Z_05.asm InitLinkSpeed,
# Z_07.asm MoveObject). If a future refactor drifts these values, this
# test fails before the regression hits the ROM.

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label}: missing {needle!r}")


def test_link_qspeed_matches_nes() -> None:
    """NES Z_05.asm:7092 InitLinkSpeed -> ObjQSpeedFrac = $60 default."""
    main_c = read("RoomRom/src/main.c")
    need(main_c, "#define LINK_QSPEED      0x60u", "LINK_QSPEED $60 default")


def test_link_grid_matches_nes() -> None:
    """NES Z_07.asm:2720-2728 MoveObject -> +/-8 grid limit for Link slot 0."""
    main_c = read("RoomRom/src/main.c")
    need(main_c, "#define LINK_GRID_SIZE   8", "LINK_GRID_SIZE 8")


def test_qspeed_4x_apply_per_frame() -> None:
    """NES Z_07.asm:2733-2735 -> QSpeed applied 4x per frame (high nibble = whole px,
    low nibble accumulates fractional). RoomRom calls link_nes_move_object 4 times
    via the move loop in roomrom_debug_tick."""
    main_c = read("RoomRom/src/main.c")
    need(main_c, "link_nes_add_qspeed", "add qspeed accumulator")
    need(main_c, "link_nes_sub_qspeed", "sub qspeed accumulator")
    need(main_c, "link_nes_move_object", "move object dispatcher")


def test_typed_player_state_is_used() -> None:
    """Phase 6 Task 6.1: movement reads/writes go through players[0], not
    s_link_x/s_link_y/s_link_face globals."""
    main_c = read("RoomRom/src/main.c")
    need(main_c, '#include "player_state.h"', "player_state include")
    if "s_link_x " in main_c or "s_link_x;" in main_c or "s_link_x =" in main_c:
        raise AssertionError("legacy s_link_x global must be migrated to players[0].x")
    if "s_link_y " in main_c or "s_link_y;" in main_c or "s_link_y =" in main_c:
        raise AssertionError("legacy s_link_y global must be migrated to players[0].y")
    if "s_link_face " in main_c or "s_link_face;" in main_c or "s_link_face =" in main_c:
        raise AssertionError("legacy s_link_face global must be migrated to players[0].face")


if __name__ == "__main__":
    test_link_qspeed_matches_nes()
    test_link_grid_matches_nes()
    test_qspeed_4x_apply_per_frame()
    test_typed_player_state_is_used()
    print("PASS: Phase 6 Task 6.2 movement contract")
