from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def assert_contains(text: str, needle: str, context: str) -> None:
    if needle not in text:
        raise AssertionError(f"{context}: missing {needle!r}")


def assert_not_contains(text: str, needle: str, context: str) -> None:
    if needle in text:
        raise AssertionError(f"{context}: unexpected {needle!r}")


def test_debug_a4_probe_contract() -> None:
    script = read("Debug.bat")
    builder = read("tools/debug/build_debug.py")
    build_text = script + "\n" + builder
    main_c = read("src/debug/a4_probe_main.c")
    asm_s = read("src/debug/a4_probe_asm.s")
    render_adapter = read("src/sgdk_adapter/render_adapter.c")
    lua = read("tools/debug/probe_a4_survival.lua")
    entry_lua = read("tools/debug/probe_debug_entry.lua")

    assert_contains(build_text, "-ffixed-a4", "A4 ABI")
    assert_contains(build_text, "-DROOMROM_NO_STANDALONE_MAIN", "RoomRom main guard")
    assert_not_contains(build_text, "-DROOMROM_BUILD", "must use Title A4 ABI")
    assert_not_contains(build_text, "nes_ram_init.c", "must not link RoomRom fake RAM")
    assert_contains(build_text, "src/debug/a4_probe_main.c", "probe C compile")
    assert_contains(build_text, "src/debug/a4_probe_asm.s", "probe asm compile")
    assert_contains(build_text, "Debug.md", "ROM output")
    assert_contains(build_text, "sega.s", "SGDK boot object")
    assert_contains(build_text, "rom_head.c", "SGDK header object")
    assert_contains(build_text, "RoomRom/src/main.c", "RoomRom runtime link")
    assert_contains(build_text, "roomrom_main.o", "RoomRom runtime object")
    assert_not_contains(build_text, "RoomRom/src/render_adapter_sgdk.c", "single render ABI implementation")
    assert_contains(build_text, "src/frontend/intro/intro_phase.c", "real title phase machine")
    assert_contains(build_text, "src/frontend/intro/intro_title.c", "real title renderer")
    assert_contains(build_text, "src/frontend/intro/intro_story.c", "real story renderer")
    assert_contains(build_text, "src/sgdk_adapter/render_adapter.c", "title render adapter")
    assert_contains(build_text, "data/intro/intro_title_bg_chr.c", "title assets")
    assert_contains(build_text, "data/intro/intro_story_tilemap.c", "story assets")
    assert_not_contains(
        render_adapter,
        "const unsigned short *p = (const unsigned short *)src",
        "CHR upload must not word-read arbitrary byte assets",
    )
    assert_contains(render_adapter, "const unsigned char *bytes", "byte-safe CHR upload source")
    assert_contains(render_adapter, "hi = bytes[i]", "byte-safe CHR upload high byte")
    assert_contains(render_adapter, "lo = bytes[i + 1u]", "byte-safe CHR upload low byte")
    assert_contains(render_adapter, "s_plane_row_stride_bytes", "dynamic plane row stride")
    assert_contains(render_adapter, "s_plane_row_stride_bytes = 64u", "title row stride")
    assert_contains(render_adapter, "s_plane_row_stride_bytes = 128u", "RoomRom row stride")
    assert_contains(render_adapter, "row * s_plane_row_stride_bytes", "tilemap writes use active stride")
    assert_not_contains(render_adapter, "(void)idx;", "palette loader must honor CRAM slot")
    assert_contains(render_adapter, "render_cram_open_write((unsigned short)(idx * 16u))", "palette slot offset")
    assert_contains(render_adapter, "static void render_set_autoinc_word(void)", "central VDP auto-increment guard")
    assert_contains(render_adapter, "render_set_autoinc_word();", "raw VDP streams force word increment")

    assert_contains(main_c, "#include <genesis.h>", "SGDK main")
    assert_contains(main_c, '#include "platform_abi.h"', "A4 RAM macro")
    assert_contains(main_c, "debug_main_after_a4", "C entry after A4 load")
    assert_contains(main_c, "intro_phase_init();", "real title init")
    assert_contains(main_c, "intro_phase_step();", "real title frame step")
    assert_contains(main_c, "debug_get_a4()", "A4 probe readback")
    assert_contains(main_c, "SYS_doVBlankProcess();", "vblank survival probe")
    assert_contains(main_c, "roomrom_debug_enter();", "RoomRom entry chord")
    assert_contains(main_c, "roomrom_debug_tick();", "RoomRom frame tick")
    assert_contains(main_c, "CHORD_DEBUG (BUTTON_A | BUTTON_B | BUTTON_C)", "A+B+C gate")
    assert_contains(main_c, "RAM(0x0012)", "A4-backed RAM write")
    assert_contains(main_c, "0x00FF8000UL", "Debug A4 NES RAM page")
    assert_contains(main_c, "0x00FF7000UL", "Lua-visible probe marker")
    assert_contains(main_c, "roomrom_debug_get_scene()", "RoomRom scene state probe")
    assert_contains(main_c, "roomrom_debug_get_room_id()", "RoomRom room state probe")
    assert_not_contains(main_c, "int main(bool hardReset)", "A4 must load before C main body")

    assert_contains(asm_s, ".globl main", "SGDK main wrapper")
    assert_contains(asm_s, "main:", "SGDK main label")
    assert_contains(asm_s, "debug_set_a4", "A4 setter symbol")
    assert_contains(asm_s, "debug_get_a4", "A4 getter symbol")
    assert_contains(asm_s, "lea 0x00FF8000,%a4", "A4 load")
    assert_not_contains(asm_s, "lea 0x00FF0000,%a4", "A4 must not overlap SGDK globals")
    assert_contains(asm_s, "move.l %a4,%d0", "A4 read")

    assert_contains(lua, "68K RAM", "BizHawk Genesis memory domain")
    assert_contains(lua, "0x7000", "probe marker offset")
    assert_contains(entry_lua, "0x8000", "A4 RAM page offset")
    assert_contains(lua, "a4_survival", "probe report")
    assert_contains(entry_lua, "P1 A", "entry probe A button")
    assert_contains(entry_lua, "P1 B", "entry probe B button")
    assert_contains(entry_lua, "P1 C", "entry probe C button")
    assert_contains(entry_lua, "debug_entry", "entry probe report")
    assert_contains(entry_lua, "0x07F0", "entry probe title phase check")
    assert_contains(entry_lua, "PHASE_TITLE_DISPLAY", "entry probe waits for real title")
    assert_contains(entry_lua, "survived CHR upload", "entry probe must keep running after RoomRom entry")
    assert_contains(entry_lua, "room_id", "entry probe reports RoomRom room")
    assert_contains(entry_lua, "0x73", "entry probe checks UW debug room")


if __name__ == "__main__":
    test_debug_a4_probe_contract()
    print("PASS: Debug A4 probe contract")
