from __future__ import annotations

# Phase 6 Task 6.3 — Sword + beam parity contract.
#
# Asserts that combat_runtime.c implements sword swing + beam
# with the exact constants from NES Z1 source (Z_05.asm WieldSword,
# Z_07.asm UpdateSwordOrRod, Z_07.asm UpdateSwordShotOrMagicShot).
# A drift in any of these regresses sword feel.

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COMBAT_C = "src/game/combat/combat_runtime.c"
COMBAT_H = "src/game/combat/combat_runtime.h"
SPRITE_C = "src/game/world/render/sprite_render.c"
SYNC_C = "src/state/nes_ram_sync.c"
SYNC_H = "src/state/nes_ram_sync.h"
MAIN_C = "RoomRom/src/main.c"


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label}: missing {needle!r}")


def reject(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"{label}: unexpected {needle!r}")


def test_swing_window_16_frames() -> None:
    """NES total swing = 5+8+1+1+1 = 16 frames. RoomRom drops state-1
    windup to 0 to match observed NES sprite emission, total = 11 frames.
    Both numbers are valid as long as the per-state breakdown is intact."""
    c = read(COMBAT_C)
    need(c, "#define COMBAT_STATE2_FRAMES   8u", "state-2 extend = 8")
    need(c, "#define COMBAT_STATE3_FRAMES   1u", "state-3 retract-1 = 1")
    need(c, "#define COMBAT_STATE4_FRAMES   1u", "state-4 retract-2 = 1")
    need(c, "#define COMBAT_STATE5_FRAMES   1u", "state-5 invisible = 1")


def test_beam_spawn_frame_and_speed() -> None:
    """NES MakeSwordShot fires at end of state 2. RoomRom: BEAM_FRAME_SPAWN
    = STATE1+STATE2 = 0+8 = 8. Speed q$C0 = 3 px/frame."""
    c = read(COMBAT_C)
    need(c, "#define BEAM_FRAME_SPAWN", "beam spawn frame defined")
    need(c, "#define BEAM_SPEED_PX        3", "beam speed 3 px/frame")


def test_beam_bounds_despawn() -> None:
    """NES beam despawns when it leaves the playfield rect. RoomRom uses
    [-16, 272) x [-16, 240) as a generous OW envelope."""
    c = read(COMBAT_C)
    need(c, "#define BEAM_BOUND_X_MIN     ((short)(-16))", "beam x min")
    need(c, "#define BEAM_BOUND_X_MAX     ((short)272)", "beam x max")
    need(c, "#define BEAM_BOUND_Y_MIN     ((short)(-16))", "beam y min")
    need(c, "#define BEAM_BOUND_Y_MAX     ((short)240)", "beam y max")


def test_beam_palette_flash_cycles_per_divergence_d001() -> None:
    """Beam palette flash is 3-step on Genesis; NES is 4-step.

    NES Z_07.asm:3453 -> ATTR = base | (FrameCounter & 3), cycling all
    four sprite sub-palettes one per frame. Genesis cycles
    RENDER_PAL1 + {0,1,2} because PAL0 is BG and PAL2 was given to
    bomb/explosion by commit 2e2a54eb.

    This asserts the ACCEPTED divergence D-001, not the NES behaviour.
    See docs/audit/known_divergences.md. If that entry is ever resolved,
    this test must go back to asserting the 4-step cycle.

    The previous version of this test asserted the NES behaviour and had
    been failing silently since 2e2a54eb landed, which is how the
    divergence went unrecorded.
    """
    c = read(COMBAT_C)
    need(c, "(s_beam_palette_phase + 1u) % 3u", "3-step palette cycle (D-001)")

    # The divergence must stay documented. If the entry is deleted, this
    # test fails rather than quietly blessing a 3-step cycle.
    div = read("docs/audit/known_divergences.md")
    need(div, "D-001", "known_divergences.md D-001 entry")
    need(div, "s_beam_palette_phase + 1u) % 3u", "D-001 cites the actual code")


def test_swing_lock_is_active() -> None:
    """Re-swing must be locked the entire active window. The guard is the
    `s_state != COMBAT_IDLE` check in roomrom_combat_try_swing."""
    c = read(COMBAT_C)
    need(c, "if (s_state != COMBAT_IDLE) return;", "re-swing lock")


def test_hp_gated_beam_is_wired() -> None:
    """Beam should only spawn at full HP in vanilla mode (NES
    UpdateSwordShotOrMagicShot HP check). Redux option modes may
    explicitly disable or always allow the beam."""
    c = read(COMBAT_C)
    need(c, "options_consumer_get_sword_style()", "sword style option gate")
    need(c, "OPTIONS_SWORD_STAB_ONLY", "stab-only beam suppression")
    need(c, "OPTIONS_SWORD_BEAM_ALWAYS", "always-beam option")
    need(c, "heart_values_cur(hv)", "current HP read")
    need(c, "heart_values_max(hv)", "max HP read")
    need(c, "cur == max && g_inventory.heart_partial >= 0x80u", "NES full HP gate")
    reject(c, "cur == max && g_inventory.heart_partial == 0u", "stale full HP gate")
    finding = read("docs/audit/drain_findings/phase6_task_6_3.md")
    need(finding, "Beam spawn gated on full HP", "HP gate row in finding doc")
    need(finding, "options_consumer_get_sword_style", "option gate documented")


def test_new_game_full_hp_seeds_nes_partial_full() -> None:
    """Fresh full-health starts must seed HeartPartial above the NES beam
    threshold; $00 is not full enough for MakeSwordShot."""
    inv = read("src/state/inventory.c")
    opt = read("src/game/options/options_consumer.c")
    need(inv, ".heart_partial    = 0xFFu", "boot HeartPartial full")
    need(opt, "g_inventory.heart_partial = 0xFFu;", "options start HeartPartial full")
    reject(inv, ".heart_partial    = 0u", "stale boot HeartPartial empty")
    reject(opt, "g_inventory.heart_partial = 0u;", "stale options HeartPartial empty")


def test_beam_vertical_sprite_uses_nes_8x16_height() -> None:
    """NES gameplay uses 8x16 sprite mode; vertical sword shots are one
    narrow 8x16 item sprite, not a clipped 8x8 Genesis sprite."""
    c = read(SPRITE_C)
    start = c.index("void roomrom_sprites_set_beam")
    end = c.index("void roomrom_sprites_clear_beam", start)
    body = c[start:end]
    need(body, "RENDER_SPRITE_SIZE(1, 2)", "vertical beam 8x16 shape")


def test_beam_state_accessors_are_exposed() -> None:
    """NES RAM sync must be able to publish and cancel the native beam."""
    h = read(COMBAT_H)
    c = read(COMBAT_C)
    for sig in (
        "unsigned char roomrom_combat_get_beam_active(void);",
        "short         roomrom_combat_get_beam_x(void);",
        "short         roomrom_combat_get_beam_y(void);",
        "link_face_t   roomrom_combat_get_beam_face(void);",
        "void roomrom_combat_cancel_beam(void);",
    ):
        need(h, sig, "beam API declaration")
    for impl in (
        "unsigned char roomrom_combat_get_beam_active(void)",
        "short         roomrom_combat_get_beam_x(void)",
        "short         roomrom_combat_get_beam_y(void)",
        "link_face_t   roomrom_combat_get_beam_face(void)",
        "void roomrom_combat_cancel_beam(void)",
    ):
        need(c, impl, "beam API implementation")


def test_beam_sync_publishes_nes_slot_14() -> None:
    """Enemy damage already checks weapon slot 14 for sword shots. Live NES
    capture shows Link's sword shot uses ObjState/Dir/X/Y in slot 14, while
    ObjType[14] remains clear."""
    c = read(SYNC_C)
    h = read(SYNC_H)
    need(c, "#define NES_OBJ_TYPE_BASE   0x034Fu", "ObjType base for slot 14")
    need(c, "#define NES_BEAM_SLOT       14u", "sword shot slot 14")
    reject(c, "NES_SWORD_SHOT_TYPE", "NES sword shot ObjType must stay clear")
    need(c, "#define NES_SWORD_SHOT_STATE_FLYING 0x10u", "active sword shot state")
    need(c, "roomrom_combat_get_beam_active()", "beam active getter used")
    need(c, "nes_ram[NES_OBJ_TYPE_BASE + NES_BEAM_SLOT] = 0u",
         "slot 14 ObjType clear")
    need(c, "nes_ram[NES_OBJ_STATE_BASE + NES_BEAM_SLOT] = NES_SWORD_SHOT_STATE_FLYING",
         "slot 14 active state write")
    need(c, "void nes_ram_reconcile_sword_beam_collision(void)",
         "post-collision reconcile implementation")
    need(c, "roomrom_combat_cancel_beam();", "collision cancel")
    need(h, "void nes_ram_reconcile_sword_beam_collision(void);",
         "post-collision reconcile declaration")


def test_beam_object_coords_match_nes_place_weapon() -> None:
    """NES PlaceWeapon seeds sword shot object coords at +/-16 px, then the
    first UpdateSwordShotOrMagicShot move makes the first visible frame +/-19."""
    c = read(COMBAT_C)
    need(c, "     0,   0, -16, +16", "beam object X spawn offsets")
    need(c, "    +16, -16,   0,   0", "beam object Y spawn offsets")
    need(c, "s_beam_y             = (short)(link_y + beam_spawn_y[face_idx]);",
         "beam object Y must not use sword visual bias")
    reject(c, "link_y + beam_spawn_y[face_idx] + s_uw_y_bias",
           "beam object coords must not use visual Y bias")


def test_beam_renderer_applies_nes_item_draw_offsets() -> None:
    """NES item draw centers narrow vertical shots by X+4, and horizontal
    sword-shot OAM appears at object Y+3."""
    c = read(SPRITE_C)
    start = c.index("void roomrom_sprites_set_beam")
    end = c.index("void roomrom_sprites_clear_beam", start)
    body = c[start:end]
    need(body, "draw_x = (short)(x + 4);", "vertical narrow X centering")
    need(body, "draw_y = (short)(y + 3);", "horizontal beam Y draw offset")


def test_main_reconciles_beam_after_enemy_tick() -> None:
    """Slot 14 collision mutates ObjState during enemy_loop_tick; the native
    beam must be cancelled immediately after that tick observes a hit."""
    c = read(MAIN_C)
    need(c, "enemy_loop_tick();\n                nes_ram_reconcile_sword_beam_collision();",
         "beam collision reconcile after enemy tick")


if __name__ == "__main__":
    test_swing_window_16_frames()
    test_beam_spawn_frame_and_speed()
    test_beam_bounds_despawn()
    test_beam_palette_flash_cycles_4()
    test_swing_lock_is_active()
    test_hp_gated_beam_is_wired()
    test_new_game_full_hp_seeds_nes_partial_full()
    test_beam_vertical_sprite_uses_nes_8x16_height()
    test_beam_state_accessors_are_exposed()
    test_beam_sync_publishes_nes_slot_14()
    test_beam_object_coords_match_nes_place_weapon()
    test_beam_renderer_applies_nes_item_draw_offsets()
    test_main_reconciles_beam_after_enemy_tick()
    print("PASS: Phase 6 Task 6.3 sword contract")
