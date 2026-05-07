from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SGDK = ROOT / "sgdk"
TOOLBIN = ROOT / "build" / "toolchain" / "sgdk_bin" / "bin"
LIB = SGDK / "lib"
PROJ = ROOT / "build" / "combined_debug_project"
OUT = PROJ / "out"
ROM_RAW = OUT / "CombinedDebug_raw.md"
ROM_OUT = ROOT / "builds" / "CombinedDebug.md"

GCC = TOOLBIN / "gcc.exe"
OBJCOPY = TOOLBIN / "objcopy.exe"


CFLAGS = [
    "-DSGDK_GCC",
    "-DROOMROM_NO_STANDALONE_MAIN",
    "-m68000",
    "-Wall",
    "-Wno-main",
    "-Wno-unused-parameter",
    "-fno-builtin",
    "-ffunction-sections",
    "-fdata-sections",
    "-fms-extensions",
    "-Os",
    "-fomit-frame-pointer",
    "-ffixed-a4",
]

INCS = [
    ROOT / "src",
    ROOT / "src" / "abi",
    ROOT / "src" / "combined_debug",
    ROOT / "src" / "frontend",
    ROOT / "src" / "frontend" / "intro",
    ROOT / "src" / "sgdk_adapter",
    ROOT / "RoomRom" / "src",
    ROOT / "src" / "state",
    ROOT / "src" / "game",
    ROOT / "src" / "game" / "cave",
    ROOT / "src" / "game" / "world",
    ROOT / "src" / "game" / "core",
    ROOT / "src" / "game" / "enemies",
    ROOT / "src" / "game" / "combat",
    ROOT / "src" / "game" / "room",
    ROOT / "src" / "game" / "hud",
    ROOT / "src" / "game" / "items",
    ROOT / "src" / "oracle" / "room",
    SGDK / "inc",
    SGDK / "res",
]

TITLE_C_SOURCES = [
    ("src/sgdk_adapter/render_adapter.c", "render_adapter.o"),
    ("src/frontend/intro/intro_phase.c", "intro_phase.o"),
    ("src/frontend/intro/intro_title.c", "intro_title.o"),
    ("src/frontend/intro/intro_story.c", "intro_story.o"),
    ("data/intro/intro_font_chr.c", "intro_font_chr.o"),
    ("data/intro/intro_art_chr.c", "intro_art_chr.o"),
    ("data/intro/intro_palette.c", "intro_palette.o"),
    ("data/intro/intro_story_tilemap.c", "intro_story_tilemap.o"),
    ("data/intro/intro_restore_chr.c", "intro_restore_chr.o"),
    ("data/intro/intro_restore_palette.c", "intro_restore_palette.o"),
    ("data/intro/intro_title_bg_chr.c", "intro_title_bg_chr.o"),
    ("data/intro/intro_title_sprite_chr.c", "intro_title_sprite_chr.o"),
    ("data/intro/intro_title_palette.c", "intro_title_palette.o"),
    ("data/intro/intro_title_tilemap.c", "intro_title_tilemap.o"),
    ("data/intro/intro_title_fade.c", "intro_title_fade.o"),
    ("data/intro/intro_title_glow.c", "intro_title_glow.o"),
    ("data/intro/intro_common_bg_chr.c", "intro_common_bg_chr.o"),
    ("data/intro/intro_sprite_chr.c", "intro_sprite_chr.o"),
    ("data/intro/intro_misc_chr.c", "intro_misc_chr.o"),
    ("data/intro/intro_punct_chr.c", "intro_punct_chr.o"),
    ("data/intro/intro_blink_chr.c", "intro_blink_chr.o"),
    ("data/intro/intro_combined_palette.c", "intro_combined_palette.o"),
    ("data/intro/intro_treasures_tilemap.c", "intro_treasures_tilemap.o"),
]

ROOMROM_C_SOURCES = [
    ("src/game/cave/cave_dispatch.c", "cave_dispatch.o"),
    ("src/game/world/world_dispatch.c", "world_dispatch.o"),
    ("src/game/world/object_dispatch.c", "object_dispatch.o"),
    ("src/game/world/sprite_dispatch.c", "sprite_dispatch.o"),
    ("src/game/world/progress_dispatch.c", "progress_dispatch.o"),
    ("src/game/world/trap_dispatch.c", "trap_dispatch.o"),
    ("src/game/core/core_dispatch.c", "core_dispatch.o"),
    ("src/game/enemies/enemy_dispatch.c", "enemy_dispatch.o"),
    ("src/game/combat/collision_dispatch.c", "collision_dispatch.o"),
    ("src/game/room/room_dispatch.c", "room_dispatch.o"),
    ("src/game/hud/hud_dispatch.c", "hud_dispatch.o"),
    ("src/game/items/weapon_dispatch.c", "weapon_dispatch.o"),
    ("src/game/combat/targeting_dispatch.c", "targeting_dispatch.o"),
    ("src/game/combat/combat_dispatch.c", "combat_dispatch.o"),
    ("src/game/cave/uw_person_dispatch.c", "uw_person_dispatch.o"),
    ("src/game/combat/link_collision_dispatch.c", "link_collision_dispatch.o"),
    ("src/game/world/draw_dispatch.c", "draw_dispatch.o"),
    ("src/game/items/item_dispatch.c", "item_dispatch.o"),
    ("RoomRom/src/main.c", "roomrom_main.o"),
    ("RoomRom/src/ow_room_render_roomrom.c", "ow_room_render.o"),
    ("RoomRom/src/roomrom_hud.c", "roomrom_hud.o"),
    ("RoomRom/src/uw_room_render_roomrom.c", "uw_room_render.o"),
    ("RoomRom/src/uw_room_blob.c", "uw_room_blob.o"),
    ("RoomRom/src/uw_collision_data.c", "uw_collision_data.o"),
    ("RoomRom/src/uw_walk_model.c", "uw_walk_model.o"),
    ("RoomRom/src/uw_door_state.c", "uw_door_state.o"),
    ("RoomRom/src/roomrom_sprites.c", "roomrom_sprites.o"),
    ("RoomRom/src/roomrom_combat.c", "roomrom_combat.o"),
    ("RoomRom/src/roomrom_boomerang.c", "roomrom_boomerang.o"),
    ("RoomRom/src/roomrom_arrow.c", "roomrom_arrow.o"),
    ("RoomRom/src/roomrom_bomb.c", "roomrom_bomb.o"),
    ("RoomRom/src/roomrom_bg_palette.c", "roomrom_bg_palette.o"),
    ("RoomRom/src/roomrom_scene_load.c", "roomrom_scene_load.o"),
    # Task 5.4: warp coordinator + OW metadata accessor + level/quest table + Gate D probe
    ("RoomRom/src/ow_room_meta.c", "ow_room_meta.o"),
    ("RoomRom/src/roomrom_world_transition.c", "roomrom_world_transition.o"),
    ("RoomRom/data/levelinfo_start_rooms.c", "levelinfo_start_rooms.o"),
    ("RoomRom/src/probes/metadata_probe.c", "metadata_probe.o"),
    # Task 5.5: door-type expected table for L1Q1 verification
    ("RoomRom/data/uw_l1q1_expected_doors.c", "uw_l1q1_expected_doors.o"),
    # Task 5.6: cellar pair table + accessor module + LevelInfo offsets
    ("data/rooms/dungeons_offsets.c", "dungeons_offsets.o"),
    ("RoomRom/data/uw_l1q1_cellar_pairs.c", "uw_l1q1_cellar_pairs.o"),
    ("RoomRom/src/uw_cellar_meta.c", "uw_cellar_meta.o"),
    # Task 5.7: push-block manifest + accessor + state machine
    ("RoomRom/data/uw_l1q1_pushblocks.c", "uw_l1q1_pushblocks.o"),
    ("RoomRom/src/uw_push_block_meta.c", "uw_push_block_meta.o"),
    ("RoomRom/src/roomrom_pushblock.c", "roomrom_pushblock.o"),
    # Task 5.8: dark-room manifest + accessor + lit-state
    ("RoomRom/data/uw_dark_rooms.c", "uw_dark_rooms.o"),
    ("RoomRom/src/uw_dark_meta.c", "uw_dark_meta.o"),
    # Task 5.9: item-room manifest + accessor + pickup wrapper
    ("RoomRom/data/uw_item_rooms.c", "uw_item_rooms.o"),
    ("RoomRom/src/uw_item_room_meta.c", "uw_item_room_meta.o"),
    ("RoomRom/src/roomrom_ow_palette.c", "roomrom_ow_palette.o"),
    ("src/state/palette_tick.c", "palette_tick.o"),
    ("RoomRom/src/roomrom_palette_tick.c", "roomrom_palette_tick.o"),
    ("RoomRom/src/expanded_bg_chr.c", "expanded_bg_chr.o"),
    ("RoomRom/src/atlas/items_chr_x4.c", "atlas_items_chr_x4.o"),
    ("data/rooms/overworld.c", "overworld.o"),
    ("data/chr/overworld_bg.c", "overworld_bg.o"),
    ("data/rooms/dungeons.c", "dungeons.o"),
    ("data/chr/underworld_bg.c", "underworld_bg.o"),
    ("RoomRom/src/redux_overworld.c", "redux_overworld.o"),
    ("RoomRom/src/redux_overworld_bg.c", "redux_overworld_bg.o"),
    ("RoomRom/src/redux_uw_bg.c", "redux_uw_bg.o"),
    ("RoomRom/src/redux_hud_chr.c", "redux_hud_chr.o"),
    ("data/chr/common.c", "common.o"),
    ("data/chr/sprites.c", "sprites.o"),
    ("data/misc/palettes.c", "palettes.o"),
]


def run(args: list[str | Path], *, cwd: Path = ROOT) -> None:
    subprocess.run([str(arg) for arg in args], cwd=cwd, check=True)


def gcc_prefix() -> list[str | Path]:
    return [GCC, "-B", f"{TOOLBIN}\\"]


def include_args() -> list[str]:
    args: list[str] = []
    for inc in INCS:
        args.append(f"-I{inc}")
    return args


def compile_c(src: str, obj_name: str) -> Path:
    src_path = ROOT / src
    obj_path = OUT / obj_name
    print(f"[3] Compiling {src}...")
    run(gcc_prefix() + CFLAGS + include_args() + ["-c", src_path, "-o", obj_path], cwd=PROJ)
    return obj_path


def compile_asm(src: Path, obj_name: str, label: str) -> Path:
    obj_path = OUT / obj_name
    print(f"[3] Compiling {label}...")
    run(
        gcc_prefix()
        + ["-x", "assembler-with-cpp", "-Wa,--register-prefix-optional,--bitwise-or"]
        + CFLAGS
        + include_args()
        + ["-c", src, "-o", obj_path],
        cwd=PROJ,
    )
    return obj_path


def main() -> int:
    if not GCC.exists():
        print(f"ERROR: gcc not found at {GCC}")
        return 1

    PROJ.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    ROM_OUT.parent.mkdir(parents=True, exist_ok=True)

    print("[CombinedDebug] check_sgdk_pin.py")
    run([sys.executable, ROOT / "tools" / "check_sgdk_pin.py"])

    print("[1] Compiling sgdk/src/boot/rom_head.c...")
    run(gcc_prefix() + CFLAGS + include_args() + ["-c", SGDK / "src" / "boot" / "rom_head.c", "-o", OUT / "rom_head.o"], cwd=PROJ)

    print("[1] objcopy rom_head.o -> rom_head.bin...")
    run([OBJCOPY, "-O", "binary", OUT / "rom_head.o", OUT / "rom_head.bin"], cwd=PROJ)

    print("[2] Compiling sgdk/src/boot/sega.s...")
    run(
        gcc_prefix()
        + ["-x", "assembler-with-cpp", "-Wa,--register-prefix-optional,--bitwise-or"]
        + CFLAGS
        + include_args()
        + ["-c", SGDK / "src" / "boot" / "sega.s", "-o", OUT / "sega.o"],
        cwd=PROJ,
    )

    objects = [
        compile_asm(ROOT / "src" / "combined_debug" / "a4_probe_asm.s", "a4_probe_asm.o", "src/combined_debug/a4_probe_asm.s"),
        compile_c("src/combined_debug/a4_probe_main.c", "a4_probe_main.o"),
    ]

    for src, obj in TITLE_C_SOURCES:
        objects.append(compile_c(src, obj))

    for src, obj in ROOMROM_C_SOURCES:
        objects.append(compile_c(src, obj))

    print("[4] Linking...")
    run(
        gcc_prefix()
        + [
            "-m68000",
            "-n",
            "-T",
            SGDK / "md.ld",
            "-nostdlib",
            OUT / "sega.o",
        ]
        + objects
        + [
            LIB / "libmd.a",
            LIB / "libgcc.a",
            "-o",
            OUT / "CombinedDebug.out",
            "-Wl,--gc-sections",
        ],
        cwd=PROJ,
    )

    print("[5] objcopy ELF -> flat binary...")
    run([OBJCOPY, "-O", "binary", OUT / "CombinedDebug.out", ROM_RAW], cwd=PROJ)

    print("[5] fix_checksum...")
    run([sys.executable, ROOT / "tools" / "fix_checksum.py", ROM_RAW, ROM_OUT])
    if ROM_RAW.exists():
        ROM_RAW.unlink()

    print()
    print(f"CombinedDebug built: {ROM_OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
