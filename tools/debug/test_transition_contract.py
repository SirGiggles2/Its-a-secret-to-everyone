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


def test_room_scroll_duration_is_snappy_genesis_native() -> None:
    """Genesis hardware scroll should keep Zelda's room slide but land in
    roughly half a second by default, while retaining the saved classic
    64-frame debug transition style as an option."""
    main_c = read("RoomRom/src/main.c")
    need(main_c, "#define SCROLL_TOTAL_FRAMES_SMOOTH 32u",
         "32-frame smooth room scroll")
    need(main_c, "#define SCROLL_TOTAL_FRAMES_CLASSIC 64u",
         "64-frame classic room scroll")
    need(main_c, "s_scroll_total_frames = transition_scroll_total_frames();",
         "transition captures saved scroll style")


def test_room_scroll_uses_fixed_point_cadence() -> None:
    """Scroll cadence should be accumulated once per frame, not recomputed
    through integer division that can introduce uneven pixel cadence."""
    main_c = read("RoomRom/src/main.c")
    need(main_c, "s_scroll_cur_x_8_8", "fixed-point scroll x accumulator")
    need(main_c, "s_scroll_cur_y_8_8", "fixed-point scroll y accumulator")
    need(main_c, "s_scroll_step_x_8_8", "fixed-point scroll x step")
    need(main_c, "s_scroll_step_y_8_8", "fixed-point scroll y step")
    need(main_c, "scroll_init_fixed_point_steps", "fixed-point scroll setup")
    need(main_c, "scroll_advance_fixed_point", "fixed-point scroll tick")
    need(main_c, "h_scroll == s_scroll_target_x && v_scroll == s_scroll_target_y",
         "target-reached scroll finalizer")
    need(main_c, "s_scroll_total_frames", "saved transition duration byte")
    reject(main_c, " * num) / den", "per-frame divided lerp")


def test_vertical_scroll_uses_single_surface_not_pingpong_planes() -> None:
    """Vertical scroll must not stage a different room on BG_B; Genesis color-0
    transparency lets BG_B leak through BG_A and creates garbage during motion."""
    main_c = read("RoomRom/src/main.c")
    render_h = read("RoomRom/src/ow_room_render_roomrom.h")
    ow_c = read("RoomRom/src/ow_room_render_roomrom.c")
    uw_c = read("RoomRom/src/uw_room_render_roomrom.c")
    need(render_h, "#define ROOMROM_PLANE_ROWS   64u", "64-row vertical staging plane")
    need(main_c, "VDP_setBGBAddress(0xC000u)", "BG_B mirrors BG_A nametable")
    need(main_c, "render_mode_set_v64();", "render ABI 64-row stride cache")
    need(main_c, "set_bg_scroll(s_active_scroll_x, s_active_scroll_y)",
         "vertical finalize mirrors both scroll planes")
    need(main_c, "s_active_row_base = s_transition_row_base",
         "vertical commit reuses staged room rows")
    need(ow_c, "wrapped_plane_row", "OW renderer wraps vertical staging rows")
    need(uw_c, "wrapped_plane_row", "UW renderer wraps vertical staging rows")
    reject(main_c, "s_scroll_stage_plane", "BG_B ping-pong staging state")
    reject(main_c, "old_active_plane", "vertical plane-swap finalizer")
    reject(main_c, "clear_room_playfield_on_plane", "outgoing plane clear workaround")
    reject(main_c, "render_room_into_slot(s_room_id", "vertical commit full repaint")


def test_vertical_scroll_does_not_clear_live_wrapped_rows() -> None:
    """After a vertical commit the live room may sit at a non-zero row base.
    Vertical staging must not clear canonical gutters because those rows can
    now contain live room tiles."""
    main_c = read("RoomRom/src/main.c")
    need(main_c, "clear_room_scroll_gutters_on_plane", "scroll gutter clear helper")
    need(main_c, "clear_room_scroll_gutters_on_plane(0u)", "shared-plane gutter clear")
    need(main_c, "clear_hud_underlay_for_row_base", "row-base-aware HUD backing clear")
    need(main_c, "clear_hud_underlay_for_row_base(s_active_row_base)",
         "vertical commit restores transparent HUD backing at active row base")
    need(main_c, "s_active_slot_x ? ROOMROM_SLOT_TILES : 0u",
         "HUD backing clear follows active horizontal slot")
    reject(main_c, "clear_room_scroll_gutters_on_plane(s_active_plane)",
           "vertical staging live-row clear")


def test_shared_bg_b_is_not_used_for_hud_shadow() -> None:
    """BG_B mirrors BG_A in the shared-plane layout. HUD shadow writes to BG_B
    would clear or overwrite wrapped room rows after vertical scrolls."""
    hud_c = read("RoomRom/src/roomrom_hud.c")
    reject(hud_c, "VDP_clearTileMapRect(BG_B", "BG_B HUD clear")
    reject(hud_c, "VDP_setTileMapXY(BG_B", "BG_B HUD tile write")


def test_window_hud_has_fixed_opaque_backdrop() -> None:
    """Window tile color 0 is transparent on Genesis. A fixed low-priority
    black sprite underlay plus high-priority Window HUD tiles keeps the HUD
    black while the shared room surface scrolls underneath."""
    hud_c = read("RoomRom/src/roomrom_hud.c")
    sprites_c = read("RoomRom/src/roomrom_sprites.c")
    need(hud_c, "TILE_ATTR_FULL(PAL0, 1, 0, 0,", "high-priority Window HUD tiles")
    need(sprites_c, "ROOMROM_HUD_BACKDROP_FIRST_SLOT", "HUD backdrop SAT slot range")
    need(sprites_c, "ROOMROM_HUD_BACKDROP_SPRITE_COUNT 48u", "HUD backdrop sprite cover")
    need(sprites_c, "ROOMROM_HUD_BACKDROP_TILE", "dedicated black backdrop tile")
    need(sprites_c, "roomrom_sprites_set_hud_backdrop", "HUD backdrop SAT writer")
    need(sprites_c, "VDP_updateSprites(ROOMROM_SPRITE_CACHE_COUNT",
         "one-time HUD backdrop SAT upload")
    need(sprites_c, "ROOMROM_HUD_BACKDROP_FIRST_SLOT", "magic-shot chain keeps HUD backdrop")


def test_vertical_scroll_suppresses_door_priority_under_hud() -> None:
    """UW door art uses high-priority BG tiles so Link can pass behind door
    arches in normal gameplay. During vertical scroll Link is hidden and
    high-priority door tiles must be demoted, otherwise they draw above the
    fixed black HUD underlay."""
    main_c = read("RoomRom/src/main.c")
    uw_c = read("RoomRom/src/uw_room_render_roomrom.c")
    uw_h = read("RoomRom/src/uw_room_render_roomrom.h")
    need(uw_h, "roomrom_uw_room_render_set_live_door_priority",
         "door-priority scroll helper declaration")
    need(uw_c, "VDP_READ_VRAM_ADDR", "live nametable priority patch reads current words")
    need(uw_c, "s_door_priority_cache_count",
         "door-priority patch uses render-time door coordinate cache")
    need(uw_c, "roomrom_uw_room_render_set_live_door_priority",
         "door-priority scroll helper")
    need(main_c, "s_active_row_base, 0u);",
         "active room door priority demoted for vertical scroll")
    need(main_c, "s_transition_row_base, 0u);",
         "incoming room door priority demoted for vertical scroll")
    need(main_c, "s_active_row_base, 1u);",
         "door priority restored after vertical commit")


if __name__ == "__main__":
    test_room_scroll_duration_is_snappy_genesis_native()
    test_room_scroll_uses_fixed_point_cadence()
    test_vertical_scroll_uses_single_surface_not_pingpong_planes()
    test_vertical_scroll_does_not_clear_live_wrapped_rows()
    test_shared_bg_b_is_not_used_for_hud_shadow()
    test_window_hud_has_fixed_opaque_backdrop()
    test_vertical_scroll_suppresses_door_priority_under_hud()
    print("PASS: Room transition contract")
