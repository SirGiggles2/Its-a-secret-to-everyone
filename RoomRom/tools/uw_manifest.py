#!/usr/bin/env python3
"""
RoomRom underworld manifest extractor.

Per (level, quest), produces RoomRom/data/uw_level{L}_quest{Q}_manifest.json
with visual-baseline constraints used by verify_uw_level.py.

Sources:
  - Border fill tile: hardcoded $F6 in LayOutRoom UW branch
    (reference/aldonunez/Z_05.asm:5621). Same for all UW levels.
  - Wall tiles: WallTileList table at Z_05.asm:4377 (78 bytes).
  - Door tiles: DoorFaceTiles{E,W,S,N} tables at Z_05.asm:4389-4432.
  - Stair tiles: hardcoded subset known from disasm (entry to cellar
    rooms uses tiles $74-$77 plus $F1, per cellar layout in z_05.asm).
  - Palette baseline: best-effort from LevelInfoUW{N}.dat. The first
    byte of every NES sub-palette is the universal $0F backdrop, so
    palette_baseline[0] = 0x0F always; other bytes filled when the
    .dat contains the full palettes transfer buffer.
  - expected_prg_bank: null (BizHawk MMC1 state not reliably probed
    here; left as informational).

The verifier uses:
  - manifest.border_fill_tile  -> outer NT frame tile membership
  - manifest.door_tiles        -> outer NT frame tile membership
  - manifest.wall_tiles        -> outer NT frame tile membership
  - manifest.palette_baseline[0] (== 0x0F) -> palram[0] check
"""

import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DAT_DIR = REPO_ROOT / "reference" / "aldonunez" / "dat"
ASM_FILE = REPO_ROOT / "reference" / "aldonunez" / "Z_05.asm"
ROOMS_DIR = REPO_ROOT / "RoomRom" / "data"
OUT_DIR = ROOMS_DIR

# NES backdrop is universally $0F across the entire palette.
NES_BACKDROP = 0x0F


def parse_byte_table(asm_text: str, label: str) -> list[int]:
    """Read .BYTE rows after a `Label:` until the next non-data line."""
    lines = asm_text.splitlines()
    try:
        i0 = next(i for i, ln in enumerate(lines) if ln.strip().startswith(label + ":"))
    except StopIteration:
        raise RuntimeError(f"label {label}: not found in {ASM_FILE}")
    out: list[int] = []
    for ln in lines[i0 + 1:]:
        s = ln.strip()
        if not s:
            continue
        if s.startswith(";"):
            continue
        if s.startswith(".BYTE") or s.startswith(".byte") or s.startswith("dc.b"):
            payload = s.split(None, 1)[1] if " " in s else ""
            if ";" in payload:
                payload = payload.split(";", 1)[0]
            for tok in payload.split(","):
                tok = tok.strip()
                if not tok:
                    continue
                if tok.startswith("$"):
                    out.append(int(tok[1:], 16))
                else:
                    out.append(int(tok, 0))
        else:
            # End of contiguous data.
            break
    return out


def extract_border_fill_tile(asm_text: str) -> int | None:
    """LayOutRoom UW branch: `LDA #$F6 / STA $0A / JSR FillTileMap`.
    Locate `LDA #$F6` immediately after `LayOutRoom:` label and use its
    operand as the border fill tile."""
    m = re.search(
        r"LayOutRoom:[^\n]*\n(?:[^\n]*\n){0,12}?\s*LDA\s+#\$([0-9A-Fa-f]{2})",
        asm_text,
    )
    if not m:
        return None
    return int(m.group(1), 16)


def find_foe_counts_offset(raw: bytes) -> int | None:
    needle = bytes([0x03, 0x05, 0x06, 0x08])
    idx = raw.find(needle)
    return idx if idx >= 0 else None


def palette_baseline_for(level: int) -> list[int | None]:
    """Best-effort 32-byte palette baseline from LevelInfoUW{N}.dat.
    The .dat may not contain the full palette area for higher levels;
    in that case bytes beyond what's available are reported as null,
    but byte 0 is always the universal backdrop $0F."""
    p = DAT_DIR / f"LevelInfoUW{level}.dat"
    raw = p.read_bytes()
    fc = find_foe_counts_offset(raw)
    if fc is None:
        return [NES_BACKDROP] + [None] * 31
    # PalettesTransferBuf is at FoeCounts - 0x20 (32 bytes before foe counts
    # for the full transfer buffer). If fc < 0x20 the .dat is truncated.
    pal_start = fc - 0x20
    out: list[int | None] = []
    for i in range(32):
        off = pal_start + i
        if 0 <= off < len(raw):
            out.append(raw[off])
        else:
            out.append(None)
    # Force byte 0 = backdrop regardless of .dat content; the engine
    # always writes $0F at $3F00 for UW.
    out[0] = NES_BACKDROP
    return out


def extract(level: int, quest: int) -> dict:
    asm_text = ASM_FILE.read_text(encoding="utf-8", errors="replace")

    border_fill = extract_border_fill_tile(asm_text)
    if border_fill is None:
        sys.stderr.write(
            "FAIL: could not locate border_fill_tile in LayOutRoom\n"
        )
        sys.exit(2)

    wall_tile_list = parse_byte_table(asm_text, "WallTileList")
    door_e = parse_byte_table(asm_text, "DoorFaceTilesE")
    door_w = parse_byte_table(asm_text, "DoorFaceTilesW")
    door_s = parse_byte_table(asm_text, "DoorFaceTilesS")
    door_n = parse_byte_table(asm_text, "DoorFaceTilesN")

    # Wall tile set: distinct non-zero, non-$24 (blank/background marker).
    wall_set = sorted({t for t in wall_tile_list if t not in (0x00, 0x24)})
    # Door tile set: union all four face tile arrays, excluding $00/$24.
    door_set = sorted({
        t for t in (door_e + door_w + door_s + door_n)
        if t not in (0x00, 0x24)
    })

    # Stair tiles are special cellar-entry tiles; conservatively use the
    # known UW cellar entry block (per cellar layout patches). $F1, $F4
    # appear in the UW stair patterns.
    stair_set = [0xF1, 0xF4]

    # Reachability (start/boss/triforce) comes from the per-(L,Q) rooms
    # JSON if available, else null. The probe driver runs reachability
    # before manifest, so this should always exist.
    rooms_json = ROOMS_DIR / f"uw_level{level}_quest{quest}_rooms.json"
    if rooms_json.exists():
        rooms_data = json.loads(rooms_json.read_text(encoding="utf-8"))
        start_room = rooms_data.get("start_room_id")
        boss_room = rooms_data.get("boss_room_id")
        triforce_room = rooms_data.get("triforce_room_id")
    else:
        start_room = boss_room = triforce_room = None

    pal = palette_baseline_for(level)

    return {
        "level": level,
        "quest": quest,
        "border_fill_tile": border_fill,
        "wall_tiles": wall_set,
        "door_tiles": door_set,
        "stair_tiles": stair_set,
        "palette_baseline": pal,
        "start_room": start_room,
        "boss_room": boss_room,
        "triforce_room": triforce_room,
        "expected_prg_bank": None,
    }


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        sys.stderr.write("usage: uw_manifest.py <level 1..9> <quest 1..2>\n")
        return 1
    level = int(argv[1])
    quest = int(argv[2])
    if level < 1 or level > 9 or quest < 1 or quest > 2:
        sys.stderr.write("level must be 1..9, quest must be 1..2\n")
        return 1

    result = extract(level, quest)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / f"uw_level{level}_quest{quest}_manifest.json"
    out_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(
        f"wrote {out_path} (border=0x{result['border_fill_tile']:02X}, "
        f"walls={len(result['wall_tiles'])}, doors={len(result['door_tiles'])})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
