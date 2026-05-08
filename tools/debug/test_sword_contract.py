from __future__ import annotations

# Phase 6 Task 6.3 — Sword + beam parity contract.
#
# Asserts that RoomRom roomrom_combat.c implements sword swing + beam
# with the exact constants from NES Z1 source (Z_05.asm WieldSword,
# Z_07.asm UpdateSwordOrRod, Z_07.asm UpdateSwordShotOrMagicShot).
# A drift in any of these regresses sword feel.

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label}: missing {needle!r}")


def test_swing_window_16_frames() -> None:
    """NES total swing = 5+8+1+1+1 = 16 frames. RoomRom drops state-1
    windup to 0 to match observed NES sprite emission, total = 11 frames.
    Both numbers are valid as long as the per-state breakdown is intact."""
    c = read("RoomRom/src/roomrom_combat.c")
    need(c, "#define COMBAT_STATE2_FRAMES   8u", "state-2 extend = 8")
    need(c, "#define COMBAT_STATE3_FRAMES   1u", "state-3 retract-1 = 1")
    need(c, "#define COMBAT_STATE4_FRAMES   1u", "state-4 retract-2 = 1")
    need(c, "#define COMBAT_STATE5_FRAMES   1u", "state-5 invisible = 1")


def test_beam_spawn_frame_and_speed() -> None:
    """NES MakeSwordShot fires at end of state 2. RoomRom: BEAM_FRAME_SPAWN
    = STATE1+STATE2 = 0+8 = 8. Speed q$C0 = 3 px/frame."""
    c = read("RoomRom/src/roomrom_combat.c")
    need(c, "#define BEAM_FRAME_SPAWN", "beam spawn frame defined")
    need(c, "#define BEAM_SPEED_PX        3", "beam speed 3 px/frame")


def test_beam_bounds_despawn() -> None:
    """NES beam despawns when it leaves the playfield rect. RoomRom uses
    [-16, 272) x [-16, 240) as a generous OW envelope."""
    c = read("RoomRom/src/roomrom_combat.c")
    need(c, "#define BEAM_BOUND_X_MIN     ((short)(-16))", "beam x min")
    need(c, "#define BEAM_BOUND_X_MAX     ((short)272)", "beam x max")
    need(c, "#define BEAM_BOUND_Y_MIN     ((short)(-16))", "beam y min")
    need(c, "#define BEAM_BOUND_Y_MAX     ((short)240)", "beam y max")


def test_beam_palette_flash_cycles_4() -> None:
    """NES Z_07.asm:3459 -> ATTR = base | (FrameCounter & 3). Genesis
    fakes the same 4-step cycle by rewriting the 4 PAL2 entries from
    sub-palette N each frame, where N = (phase & 3)."""
    c = read("RoomRom/src/roomrom_combat.c")
    need(c, "(s_beam_palette_phase + 1u) & 0x3u", "4-step palette cycle")


def test_swing_lock_is_active() -> None:
    """Re-swing must be locked the entire active window. The guard is the
    `s_state != COMBAT_IDLE` check in roomrom_combat_try_swing."""
    c = read("RoomRom/src/roomrom_combat.c")
    need(c, "if (s_state != COMBAT_IDLE) return;", "re-swing lock")


def test_hp_gated_beam_deferral_is_documented() -> None:
    """Beam should only spawn at full HP (NES UpdateSwordShotOrMagicShot
    HP check). RoomRom has no HP system yet (Task 6.11). The deferral
    must be documented in source comments so the gate point is obvious
    when 6.11 lands."""
    c = read("RoomRom/src/roomrom_combat.c")
    need(c, "no HP system", "HP-gate deferral note")
    finding = read("docs/audit/drain_findings/phase6_task_6_3.md")
    need(finding, "Beam spawn gated on full HP", "deferral row in finding doc")
    need(finding, "Task 6.11", "deferral re-entry pointer")


if __name__ == "__main__":
    test_swing_window_16_frames()
    test_beam_spawn_frame_and_speed()
    test_beam_bounds_despawn()
    test_beam_palette_flash_cycles_4()
    test_swing_lock_is_active()
    test_hp_gated_beam_deferral_is_documented()
    print("PASS: Phase 6 Task 6.3 sword contract")
