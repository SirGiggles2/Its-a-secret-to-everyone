from __future__ import annotations

# Save persistence contract.
#
# save_serializer.c builds slot images in the NES RAM mirror via
# SAVE_BYTE(off) = nes_ram[NES_SRAM_BASE + off]. In Debug.md nes_ram is
# A4-pinned to $FF8000, so that lands at $FFE000. sram_adapter.c moves
# bytes through a DIFFERENT mirror at $FF6000, below the A4 window.
#
# The two halves were written against different regions and never joined,
# which is why save_slot_serialize() had zero callers: a save updated
# work RAM and nothing pushed it to the cart, so it died at power-off.
# src/state/save_game.c owns that copy. These assertions keep it owned.

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

SAVE_GAME_C = "src/state/save_game.c"
SAVE_GAME_H = "src/state/save_game.h"
SERIALIZER_H = "src/state/save_serializer.h"
SRAM_ABI_H = "src/abi/sram_abi.h"
BUILD_PY = "tools/debug/build_debug.py"


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8", errors="replace")


def need(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label}: missing {needle!r}")


def test_save_bridge_is_linked_into_debug_md() -> None:
    """A save path that is not in the build cannot persist anything."""
    need(read(BUILD_PY), "src/state/save_game.c",
         "save_game.c linked into Debug.md")


def test_bridge_uses_both_mirrors() -> None:
    """The bridge must touch the serializer mirror AND the cart adapter.

    If it only used one, it would be the same dead-end the serializer was.
    """
    c = read(SAVE_GAME_C)
    need(c, "SAVE_BYTE(", "reads/writes the serializer mirror")
    need(c, "sram_save_store(", "commits to cart SRAM")
    need(c, "sram_save_load(", "reads back from cart SRAM")


def test_slot_geometry_is_statically_asserted() -> None:
    """The serializer and the adapter must agree on slot stride.

    They are declared in different headers by different subsystems, so a
    change to one silently corrupts slot addressing unless this is
    enforced at compile time.
    """
    c = read(SAVE_GAME_C)
    need(c, "_Static_assert(SAVE_SLOT_STRIDE == SRAM_SAVE_SLOT_BYTES",
         "slot stride agreement asserted at compile time")


def test_slot_stride_constants_actually_match() -> None:
    """Belt and braces: the two constants agree in the headers today."""
    need(read(SERIALIZER_H), "SAVE_SLOT_STRIDE       682u",
         "serializer slot stride")
    need(read(SRAM_ABI_H), "SRAM_SAVE_SLOT_BYTES  682u",
         "cart SRAM slot stride")


def test_load_refuses_invalid_slot() -> None:
    """A blank or corrupt cart must not overwrite a live game.

    save_game_read_slot must gate on save_slot_deserialize, which itself
    validates magic + checksum before touching live inventory RAM.
    """
    c = read(SAVE_GAME_C)
    need(c, "return save_slot_deserialize(slot_idx);",
         "load applies only after validation")


def test_slot_validity_probe_does_not_mutate_live_ram() -> None:
    """File Select must be able to ask 'is this slot occupied?' without
    loading it, otherwise browsing slots would clobber the running game."""
    h = read(SAVE_GAME_H)
    need(h, "save_game_slot_is_valid", "non-mutating slot validity query")
    c = read(SAVE_GAME_C)
    body = c[c.find("unsigned char save_game_slot_is_valid"):]
    if "save_slot_deserialize" in body:
        raise AssertionError(
            "save_game_slot_is_valid must not deserialize into live RAM")


if __name__ == "__main__":
    test_save_bridge_is_linked_into_debug_md()
    test_bridge_uses_both_mirrors()
    test_slot_geometry_is_statically_asserted()
    test_slot_stride_constants_actually_match()
    test_load_refuses_invalid_slot()
    test_slot_validity_probe_does_not_mutate_live_ram()
    print("save contract OK")
