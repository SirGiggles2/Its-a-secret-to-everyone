"""Phase 9 Task close — HUD / Options / Save / Menus matrix contract.

Static check that Phase 9 substrate is present and wired:

1. Each Phase 9 sub-task has a drain findings doc (9.1-9.7).
2. Options subsystem TUs are linked into Debug.md
   (options_runtime, options_persistence, options_consumer +
   per-probe siblings).
3. Save-serializer subsystem is linked and exposes the four-call API.
4. HUD dispatch + format probe are linked.
5. FS options surface (fs_options.c + fs_options_render.c) is linked.
6. SAVE format constants match NES InitSaveRam sentinel.

Failures here mean the close-gate evidence is broken — a real
substrate file moved or got renamed, or a probe was dropped from
build_debug.py.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, ctx: str) -> None:
    if needle not in text:
        raise AssertionError(f"{ctx}: missing {needle!r}")


def test_phase9_drain_findings_present() -> None:
    fdir = ROOT / "docs" / "audit" / "drain_findings"
    expected = [f"phase9_task_9_{n}.md" for n in range(1, 8)]
    missing = [n for n in expected if not (fdir / n).exists()]
    if missing:
        raise AssertionError(
            "Missing Phase 9 drain findings docs: " + ", ".join(missing)
        )


def test_options_subsystem_linked() -> None:
    build = read("tools/debug/build_debug.py")
    for tu in (
        "src/game/options/options_runtime.c",
        "src/game/options/options_persistence.c",
        "src/game/options/options_consumer.c",
        "src/sgdk_adapter/sram_options_io.c",
        "src/game/options/probes/options_probe.c",
        "src/game/options/probes/options_persistence_probe.c",
        "src/game/options/probes/options_consumer_probe.c",
    ):
        need(build, tu, "options TU registration")


def test_save_serializer_linked() -> None:
    build = read("tools/debug/build_debug.py")
    need(build, "src/state/save_serializer.c",        "save serializer TU")
    need(build, "src/state/probes/save_serializer_probe.c",
                                                       "save serializer probe TU")
    header = read("src/state/save_serializer.h")
    for needle in (
        "SAVE_SLOT_COUNT",
        "SAVE_SLOT_STRIDE",
        "SAVE_MAGIC_LO",
        "SAVE_MAGIC_HI",
        "SAVE_INVENTORY_BYTES",
        "SAVE_INVENTORY_RAM_BASE",
    ):
        need(header, needle, "save serializer constant")
    body = read("src/state/save_serializer.c")
    for sym in (
        "save_slot_compute_checksum",
        "save_slot_serialize",
        "save_slot_validate",
        "save_slot_deserialize",
    ):
        need(body, sym, "save serializer entry")


def test_save_sentinels_match_nes() -> None:
    """SAVE_MAGIC_LO/HI must match NES InitSaveRam sentinel ($5A / $A5)."""
    header = read("src/state/save_serializer.h")
    need(header, "0x5Au", "SAVE_MAGIC_LO matches NES $5A SaveRamBegin")
    need(header, "0xA5u", "SAVE_MAGIC_HI matches NES $A5 SaveRamEnd")


def test_hud_dispatch_linked() -> None:
    build = read("tools/debug/build_debug.py")
    need(build, "src/game/hud/hud_dispatch.c", "hud dispatch TU")
    need(build, "src/game/hud/probes/hud_format_probe.c", "hud probe TU")
    header = read("src/game/hud/hud_dispatch.h")
    for sym in (
        "hud_format_hearts_in_text_buf",
        "hud_copy_triplet_to_text_buf",
        "hud_format_decimal_count_byte",
        "hud_format_decimal_count_byte_in_text_buf",
        "hud_format_status_bar_text",
        "hud_world_change_rupees",
    ):
        need(header, sym, "hud dispatch entry")


def test_fs_options_linked() -> None:
    build = read("tools/debug/build_debug.py")
    need(build, "src/frontend/fs/fs_options.c",        "fs options phase TU")
    need(build, "src/frontend/fs/fs_options_render.c", "fs options render TU")


def test_consumer_call_sites_present() -> None:
    """Verify the 6 wired option consumers reach their drained call sites.

    Coverage matrix per docs/audit/drain_findings/phase9_task_9_4.md.
    """
    # Paths post-Phase-12.2 RoomRom drain: combat moved to src/game/combat/.
    sites = [
        ("RoomRom/src/main.c",                        "options_consumer_apply_inventory_at_start"),
        ("RoomRom/src/main.c",                        "options_consumer_get_room_scroll"),
        ("RoomRom/src/main.c",                        "options_consumer_get_ab_swap"),
        ("src/game/combat/combat_runtime.c",          "options_consumer_get_sword_style"),
        ("src/game/enemies/enemy_special_bridge.c",   "options_consumer_get_like_like_behavior"),
        ("src/game/world/draw_dispatch.c",            "options_consumer_get_no_reduced_flashing"),
    ]
    missing: list[str] = []
    for path, sym in sites:
        if sym not in read(path):
            missing.append(f"{path}::{sym}")
    if missing:
        raise AssertionError(
            "Phase 9.4 consumer call site missing: " + ", ".join(missing)
        )


if __name__ == "__main__":
    test_phase9_drain_findings_present()
    test_options_subsystem_linked()
    test_save_serializer_linked()
    test_save_sentinels_match_nes()
    test_hud_dispatch_linked()
    test_fs_options_linked()
    test_consumer_call_sites_present()
    print(
        "PASS: Phase 9 matrix contract "
        "(7 drain findings + options + save + hud + fs_options + 6 consumer sites)"
    )
