#!/usr/bin/env python3
"""Hard gate: no NES-pal-to-Genesis-slot patterns + no slot<3 BG loaders.

Scans RoomRom render + HUD + sprite + combat + projectile sources.
Forbidden patterns post-Phase-4:
  - `(pal & 0x03) << 13`   -- legacy Gen pal-slot encoding in tile word
  - `slot < 3` BG loader   -- legacy 3-slot BG palette load
  - `TILE_ATTR_FULL(PAL3,` -- sprite SAT pal-slot was PAL3, now PAL1
  - `PAL3` Gen-slot writes in HUD (Window plane) -- HUD lives in PAL0

Phase 5 sprite-renderer gates (check_sprite_renderers):
  - Forbidden: (pal & 0x03) << 13 in any sprite renderer
  - Forbidden: TILE_ATTR_FULL(PAL3, ...) in any sprite renderer
  - Required: ROOMROM_ITEM_TILE_BASE_PAL in roomrom_sprites.c (item-bank
    renderer wiring)

Exit code 0 = pass, 1 = fail.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCAN = [
    "src/ow_room_render_roomrom.c",
    "src/uw_room_render_roomrom.c",
    "src/roomrom_hud.c",
    "src/roomrom_sprites.c",
    "src/roomrom_combat.c",
    "src/roomrom_arrow.c",
    "src/roomrom_bomb.c",
    "src/roomrom_boomerang.c",
]

SPRITE_RENDERERS = [
    "src/roomrom_sprites.c",
    "src/roomrom_combat.c",
    "src/roomrom_bomb.c",
    "src/roomrom_boomerang.c",
    "src/roomrom_arrow.c",
]

PAT_PAL_SHIFT = re.compile(r"\(\s*pal\s*&\s*0x0?3\s*\)\s*<<\s*13", re.IGNORECASE)
PAT_SLOT_LT_3 = re.compile(r"\bslot\s*<\s*3\b")
PAT_PAL3      = re.compile(r"TILE_ATTR_FULL\s*\(\s*PAL3\b")
PAT_PAL2_HUD  = re.compile(r"TILE_ATTR_FULL\s*\(\s*PAL2\b")


def fail(msg):
    print(f"verify_slot_map: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def check_sprite_renderers():
    """Phase 5: gate sprite renderers for forbidden patterns + required macro."""
    bad = []
    for rel in SPRITE_RENDERERS:
        path = ROOT / rel
        if not path.exists():
            bad.append((rel, 0, "missing sprite renderer file"))
            continue
        text = path.read_text(encoding="utf-8")
        # Forbidden: legacy (pal & 0x03) << 13 pattern
        if PAT_PAL_SHIFT.search(text):
            bad.append((rel, 0, "forbidden (pal & 0x03) << 13 pattern present"))
        # Forbidden: TILE_ATTR_FULL(PAL3, ...) -- post-cutover sprite slot is PAL1
        # (PAL2 is OK; beam flash deliberately borrows it)
        if PAT_PAL3.search(text):
            bad.append((rel, 0, "forbidden TILE_ATTR_FULL(PAL3 (post-cutover sprite slot is PAL1)"))
    # Item-rendering files must reference ROOMROM_ITEM_TILE_BASE_PAL
    items_renderer = ROOT / "src" / "roomrom_sprites.c"
    if items_renderer.exists():
        if "ROOMROM_ITEM_TILE_BASE_PAL" not in items_renderer.read_text(encoding="utf-8"):
            bad.append((str(items_renderer.relative_to(ROOT)), 0,
                        "missing ROOMROM_ITEM_TILE_BASE_PAL reference "
                        "(Phase 3 item-bank renderer wiring)"))
    if bad:
        for rel, ln, msg in bad:
            print(f"  {rel}:{ln}  {msg}", file=sys.stderr)
        fail(f"{len(bad)} sprite-renderer violations")


def main():
    bad = []
    for rel in SCAN:
        path = ROOT / rel
        if not path.exists():
            bad.append((rel, 0, "missing file"))
            continue
        text = path.read_text(encoding="utf-8")
        for ln, line in enumerate(text.splitlines(), start=1):
            stripped = line.strip()
            # Skip pure comments.
            if stripped.startswith("//") or stripped.startswith("*"):
                continue
            if PAT_PAL_SHIFT.search(line):
                bad.append((rel, ln, f"(pal & 0x03) << 13: {stripped}"))
            if PAT_SLOT_LT_3.search(line):
                bad.append((rel, ln, f"slot < 3 (BG-loader artifact): {stripped}"))
            if PAT_PAL3.search(line):
                bad.append((rel, ln, f"TILE_ATTR_FULL(PAL3, ...): {stripped}"))
            if rel.endswith("roomrom_hud.c") and PAT_PAL2_HUD.search(line):
                bad.append((rel, ln, f"HUD PAL2 SAT write (HUD must use PAL0): {stripped}"))

    if bad:
        for rel, ln, msg in bad:
            print(f"  {rel}:{ln}  {msg}", file=sys.stderr)
        fail(f"{len(bad)} slot-map violations")

    check_sprite_renderers()
    print("verify_slot_map: OK")


if __name__ == "__main__":
    main()
