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


def test_boss_room_item_state_uses_obj_state_slot_19() -> None:
    boss_state = read("src/state/boss_state.h")
    need(boss_state, "BOSS_ROOM_ITEM_STATE         ENEMY_STATE_TIMER(BOSS_ROOM_ITEM_SLOT)",
         "room item active flag maps to ObjState+19")
    reject(boss_state, "BOSS_ROOM_ITEM_STATE         OBJ(0x0098u, BOSS_ROOM_ITEM_SLOT)",
           "room item active flag must not overwrite RoomItemId")
    need(boss_state, "BOSS_ROOM_KILL_COUNT         ROOM_OW_CUR_KILL_TOTAL",
         "room kill count uses room-state canonical owner")
    need(boss_state, "BOSS_CUR_LEVEL               CUR_LEVEL",
         "boss level check uses progress canonical owner")
    need(boss_state, "BOSS_GAMEMODE                MODE_VALUE",
         "boss mode gate uses progress canonical owner")


if __name__ == "__main__":
    test_boss_room_item_state_uses_obj_state_slot_19()
    print("PASS: Boss state contract")
