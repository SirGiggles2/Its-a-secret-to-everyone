#!/usr/bin/env python3
"""Render NES vs RoomRom UW walkability overlays.

Outputs:
  - tile_nes.png / tile_roomrom.png / tile_diff.png
  - move_{left,right,up,down}_{nes,roomrom,diff}.png
  - summary.json

The tile overlays show raw 8x8 playfield tile walkability. The movement
overlays show whether Link's top-left object coordinate can move one step in
each direction, using the NES collision sampling rules and RoomRom's current
collision sampling rules.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
NES_JSON = ROOT / "RoomRom" / "out" / "nes_uw_level1_quest1_orig.json"
DUNGEONS_C = ROOT / "data" / "rooms" / "dungeons.c"
MANIFEST_JSON = ROOT / "data" / "rooms" / "MANIFEST.json"
OUT_DIR = ROOT / "build" / "reports" / "uw_walkability"

sys.path.insert(0, str(ROOT / "tools" / "builder"))
from extract_uw_collision import build_room_grid, load_manifest, parse_dungeons_c

PLAY_COLS = 32
PLAY_ROWS = 22
TILE = 8
ROOM_W = PLAY_COLS * TILE
ROOM_H = PLAY_ROWS * TILE
NES_PLAYFIELD_Y = 0x40
ROOMROM_PLAYFIELD_Y = 0x38
ROOMROM_VISUAL_X_BIAS = 0
ROOMROM_VISUAL_Y_BIAS = -8

DIRS = ("left", "right", "up", "down")
WALL_TILE_IDS = {
    0xB8, 0xBC,
    0xC0, 0xC4, 0xC8, 0xCC,
    0xD0, 0xD4, 0xD8, 0xDC, 0xDE,
    0xE0,
    0xF5, 0xF6,
}

DOOR_E = 0
DOOR_W = 1
DOOR_S = 2
DOOR_N = 3

DOOR_OPEN = 0
DOOR_WALL = 1
DOOR_FALSE = 2
DOOR_FALSE2 = 3
DOOR_BOMBABLE = 4
DOOR_KEY = 5
DOOR_KEY2 = 6
DOOR_SHUTTER = 7

LINK_DIR = {
    "down": 1,
    "up": 2,
    "left": 3,
    "right": 4,
}


@dataclass(frozen=True)
class DoorState:
    east: int
    west: int
    south: int
    north: int

    def type_for(self, door_dir: int) -> int:
        return (self.east, self.west, self.south, self.north)[door_dir]


def parse_hex_int(value: str) -> int:
    return int(value, 0)


def load_nes_room(room_id: int) -> list[list[int]]:
    payload = json.loads(NES_JSON.read_text(encoding="utf-8"))
    room = next(r for r in payload["results"] if r["room_id"] == room_id)
    return room["nt"]


def load_dungeon_bytes() -> list[int]:
    text = DUNGEONS_C.read_text(encoding="utf-8")
    return [int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{2})", text)]


def level_block_base(level: int, quest: int) -> int:
    base = 0 if level <= 6 else 768
    if quest == 2:
        base += 1536
    return base


def door_state(level: int, quest: int, room_id: int) -> DoorState:
    data = load_dungeon_bytes()
    base = level_block_base(level, quest)
    attrs_a = data[base + room_id]
    attrs_b = data[base + 128 + room_id]
    return DoorState(
        east=(attrs_b >> 2) & 7,
        west=(attrs_b >> 5) & 7,
        south=(attrs_a >> 2) & 7,
        north=(attrs_a >> 5) & 7,
    )


def tile_mask_from_nt(nt: list[list[int]]) -> list[list[bool]]:
    return [[nt[row + 8][col] < 0x78
             for col in range(PLAY_COLS)]
            for row in range(PLAY_ROWS)]


def roomrom_blob_tile_mask(nt: list[list[int]]) -> list[list[bool]]:
    # RoomRom captured blob rooms now mirror NES PlayAreaTiles directly:
    # every rendered 8px tile is walkable only when tile < 0x78.
    return tile_mask_from_nt(nt)


def unique_room_id(data: list[int], tables: dict, level: int,
                   quest: int, room_id: int) -> int:
    block_name = f"LevelBlockUW{1 if level <= 6 else 2}Q{quest}"
    off, _ = tables[block_name]
    return data[off + 0x180 + room_id] & 0x3F


def collision_tile_mask(level: int, quest: int, room_id: int) -> list[list[bool]]:
    _ = (level, quest)
    return tile_mask_from_nt(load_nes_room(room_id))


def base_room_image(nt: list[list[int]]) -> Image.Image:
    img = Image.new("RGBA", (ROOM_W, ROOM_H), (24, 24, 24, 255))
    draw = ImageDraw.Draw(img)
    for row in range(PLAY_ROWS):
        for col in range(PLAY_COLS):
            t = nt[row + 8][col]
            shade = 52 + (t % 8) * 13
            if t < 0x78:
                fill = (shade, shade + 18, shade, 255)
            else:
                fill = (shade + 10, shade, shade, 255)
            x0 = col * TILE
            y0 = row * TILE
            draw.rectangle((x0, y0, x0 + TILE - 1, y0 + TILE - 1), fill=fill)
    for x in range(0, ROOM_W + 1, TILE):
        draw.line((x, 0, x, ROOM_H), fill=(0, 0, 0, 60))
    for y in range(0, ROOM_H + 1, TILE):
        draw.line((0, y, ROOM_W, y), fill=(0, 0, 0, 60))
    return img


def label(img: Image.Image, text: str) -> Image.Image:
    out = Image.new("RGBA", (img.width, img.height + 18), (0, 0, 0, 255))
    out.alpha_composite(img, (0, 18))
    draw = ImageDraw.Draw(out)
    draw.text((4, 3), text, fill=(255, 255, 255, 255))
    return out


def save_scaled(img: Image.Image, path: Path, scale: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale),
                         Image.Resampling.NEAREST)
    img.save(path)


def render_tile_overlay(nt: list[list[int]], mask: list[list[bool]],
                        title: str) -> Image.Image:
    img = base_room_image(nt)
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for row in range(PLAY_ROWS):
        for col in range(PLAY_COLS):
            x0 = col * TILE
            y0 = row * TILE
            fill = (0, 210, 80, 105) if mask[row][col] else (230, 30, 40, 120)
            draw.rectangle((x0, y0, x0 + TILE - 1, y0 + TILE - 1), fill=fill)
    return label(Image.alpha_composite(img, overlay), title)


def render_tile_diff(nt: list[list[int]], nes: list[list[bool]],
                     rr: list[list[bool]], title: str) -> Image.Image:
    img = base_room_image(nt)
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for row in range(PLAY_ROWS):
        for col in range(PLAY_COLS):
            if nes[row][col] == rr[row][col]:
                fill = (0, 190, 80, 100) if nes[row][col] else (40, 40, 40, 130)
            elif nes[row][col] and not rr[row][col]:
                fill = (255, 0, 0, 190)
            else:
                fill = (0, 100, 255, 190)
            x0 = col * TILE
            y0 = row * TILE
            draw.rectangle((x0, y0, x0 + TILE - 1, y0 + TILE - 1), fill=fill)
    return label(Image.alpha_composite(img, overlay),
                 title + "  red=NES walk/RoomRom block  blue=RoomRom walk/NES block")


def door_passable(t: int, keys: int) -> bool:
    if t == DOOR_OPEN:
        return True
    if t in (DOOR_KEY, DOOR_KEY2):
        return keys > 0
    return False


def doorway_at(x: int, y: int, x_bias: int = 0,
               y_bias: int = 0) -> int | None:
    if y == 0x8D + y_bias:
        if 0x00 + x_bias <= x < 0x21 + x_bias:
            return DOOR_W
        if 0xCF + x_bias <= x < 0xF1 + x_bias:
            return DOOR_E
    if x == 0x78 + x_bias:
        if 0x3D + y_bias <= y < 0x5E + y_bias:
            return DOOR_N
        if 0xBD + y_bias <= y < 0xDE + y_bias:
            return DOOR_S
    return None


def doorway_axis_matches(door_dir: int, direction: str) -> bool:
    if door_dir in (DOOR_E, DOOR_W):
        return direction in ("left", "right")
    return direction in ("up", "down")


def doorway_toward(door_dir: int) -> str:
    return ("right", "left", "down", "up")[door_dir]


def doorway_pass(direction: str, x: int, y: int, doors: DoorState,
                 keys: int, x_bias: int = 0,
                 y_bias: int = 0) -> bool | None:
    door_dir = doorway_at(x, y, x_bias, y_bias)
    if door_dir is None:
        return None
    if not doorway_axis_matches(door_dir, direction):
        return False
    if direction == doorway_toward(door_dir):
        return door_passable(doors.type_for(door_dir), keys)
    return True


def sample_nes(direction: str, x: int, y: int) -> tuple[int, int] | None:
    base_y = y + 0x0B
    if direction == "right":
        hot_x = x if x >= 0xF0 else x + 0x10
        hot_y = base_y
    elif direction == "left":
        hot_x = x if x < 0x10 else x - 0x08
        hot_y = base_y
    elif direction == "down":
        hot_x = x
        hot_y = base_y if base_y >= 0xDD else base_y + 0x08
    elif direction == "up":
        hot_x = x
        hot_y = base_y - 0x08
    else:
        return None
    return hot_x, hot_y


def sample_roomrom(direction: str, x: int, y: int) -> tuple[int, int] | None:
    base_y = y + 0x0B
    if direction == "right":
        hot_x = x if x >= 0xF0 else x + 0x10
        hot_y = base_y
    elif direction == "left":
        hot_x = x if x < 0x10 else x - 0x08
        hot_y = base_y
    elif direction == "down":
        hot_x = x
        hot_y = base_y if base_y >= 0xD5 else base_y + 0x08
    elif direction == "up":
        hot_x = x
        hot_y = base_y - 0x08
    else:
        return None
    return hot_x, hot_y


def move_allowed(mask: list[list[bool]], direction: str, x: int, y: int,
                 doors: DoorState, keys: int, model: str) -> bool:
    x_bias = ROOMROM_VISUAL_X_BIAS if model == "roomrom" else 0
    y_bias = ROOMROM_VISUAL_Y_BIAS if model == "roomrom" else 0
    door = doorway_pass(direction, x, y, doors, keys, x_bias, y_bias)
    if door is not None:
        return door

    sample = sample_nes(direction, x, y) if model == "nes" else sample_roomrom(direction, x, y)
    if sample is None:
        return False
    hot_x, hot_y = sample
    top_y = ROOMROM_PLAYFIELD_Y if model == "roomrom" else NES_PLAYFIELD_Y
    if hot_y < top_y:
        return False
    tile_x = hot_x - x_bias
    col = -1 if tile_x < 0 else tile_x // 8
    row = (hot_y - top_y) // 8
    if col < 0 or col > 31 or row < 0 or row > 21:
        return True
    if not mask[row][col]:
        return False
    if direction in ("up", "down") and col < 31:
        return mask[row][col + 1]
    return True


def movement_map(mask: list[list[bool]], direction: str, doors: DoorState,
                 keys: int, model: str) -> list[list[bool]]:
    # Link top-left coordinate map over the visible 256x176 playfield.
    out: list[list[bool]] = []
    playfield_y = ROOMROM_PLAYFIELD_Y if model == "roomrom" else NES_PLAYFIELD_Y
    for sy in range(ROOM_H):
        y = playfield_y + sy
        row: list[bool] = []
        for x in range(ROOM_W):
            row.append(move_allowed(mask, direction, x, y, doors, keys, model))
        out.append(row)
    return out


def render_move_overlay(nt: list[list[int]], allowed: list[list[bool]],
                        title: str) -> Image.Image:
    img = base_room_image(nt)
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    pix = overlay.load()
    for y, row in enumerate(allowed):
        for x, ok in enumerate(row):
            pix[x, y] = (0, 210, 80, 95) if ok else (230, 30, 40, 105)
    return label(Image.alpha_composite(img, overlay), title)


def render_move_diff(nt: list[list[int]], nes: list[list[bool]],
                     rr: list[list[bool]], title: str) -> Image.Image:
    img = base_room_image(nt)
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    pix = overlay.load()
    for y in range(ROOM_H):
        for x in range(ROOM_W):
            if nes[y][x] == rr[y][x]:
                pix[x, y] = (0, 190, 80, 80) if nes[y][x] else (20, 20, 20, 115)
            elif nes[y][x] and not rr[y][x]:
                pix[x, y] = (255, 0, 0, 190)
            else:
                pix[x, y] = (0, 100, 255, 190)
    return label(Image.alpha_composite(img, overlay),
                 title + "  red=NES walk/RoomRom block  blue=RoomRom walk/NES block")


def count_diff(a: list[list[bool]], b: list[list[bool]]) -> int:
    return sum(1 for row_a, row_b in zip(a, b)
               for va, vb in zip(row_a, row_b) if va != vb)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--room", default="0x73", help="UW room id, e.g. 0x73")
    parser.add_argument("--level", type=int, default=1)
    parser.add_argument("--quest", type=int, default=1)
    parser.add_argument("--keys", type=int, default=3,
                        help="Key count used for key-door doorway overlay")
    parser.add_argument("--scale", type=int, default=3)
    parser.add_argument("--out-dir", type=Path, default=OUT_DIR)
    args = parser.parse_args()

    room_id = parse_hex_int(args.room)
    out = args.out_dir / f"l{args.level}q{args.quest}_r{room_id:02x}"
    nt = load_nes_room(room_id)
    # NES Link collision samples PlayAreaTiles. RoomRom captured blob rooms use
    # the same exact 8px tile threshold: tile < 0x78.
    nes_tile = collision_tile_mask(args.level, args.quest, room_id)
    roomrom_tile = roomrom_blob_tile_mask(nt)
    doors = door_state(args.level, args.quest, room_id)

    save_scaled(render_tile_overlay(nt, nes_tile, "NES tile walkability"),
                out / "tile_nes.png", args.scale)
    save_scaled(render_tile_overlay(nt, roomrom_tile, "RoomRom tile walkability"),
                out / "tile_roomrom.png", args.scale)
    save_scaled(render_tile_diff(nt, nes_tile, roomrom_tile, "Tile walkability diff"),
                out / "tile_diff.png", args.scale)

    summary: dict[str, object] = {
        "room": room_id,
        "level": args.level,
        "quest": args.quest,
        "doors": {
            "east": doors.east,
            "west": doors.west,
            "south": doors.south,
            "north": doors.north,
        },
        "tile_diff_count": count_diff(nes_tile, roomrom_tile),
        "movement_diff_count": {},
        "outputs": {},
    }

    outputs: dict[str, str] = {}
    movement_counts: dict[str, int] = {}
    for direction in DIRS:
        nes_move = movement_map(nes_tile, direction, doors, args.keys, "nes")
        rr_move = movement_map(roomrom_tile, direction, doors, args.keys, "roomrom")
        movement_counts[direction] = count_diff(nes_move, rr_move)
        for model, data in (("nes", nes_move), ("roomrom", rr_move)):
            path = out / f"move_{direction}_{model}.png"
            save_scaled(render_move_overlay(nt, data, f"{model.upper()} move {direction}"),
                        path, args.scale)
            outputs[path.stem] = str(path)
        diff_path = out / f"move_{direction}_diff.png"
        save_scaled(render_move_diff(nt, nes_move, rr_move, f"Move {direction} diff"),
                    diff_path, args.scale)
        outputs[diff_path.stem] = str(diff_path)

    outputs["tile_nes"] = str(out / "tile_nes.png")
    outputs["tile_roomrom"] = str(out / "tile_roomrom.png")
    outputs["tile_diff"] = str(out / "tile_diff.png")
    summary["movement_diff_count"] = movement_counts
    summary["outputs"] = outputs
    out.mkdir(parents=True, exist_ok=True)
    (out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n",
                                      encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 0 if summary["tile_diff_count"] == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
