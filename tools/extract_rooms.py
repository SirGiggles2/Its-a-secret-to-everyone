#!/usr/bin/env python3
"""
extract_rooms.py - Extract room and level data from NES Zelda 1.

This script keeps the original compact, column-based room format intact.
The Genesis runtime can interpret these tables directly instead of expanding
them into full tilemaps ahead of time.

Data sources:
  - ROM PRG banks for .INCBIN blocks and common bank data
  - Aldonunez disassembly for inline room tables and patch tables

Outputs:
  - Overworld and underworld level block attribute tables
  - Level info blocks
  - Room layout descriptor tables (OW/UW/caves/cellars)
  - Column directories and column heaps (OW/UW)
  - Common data block from bank 6
  - Second quest room/info patch tables
"""

import os
import re
import sys

INES_HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000

LEVEL_BLOCK_SIZE = 0x0300
LEVEL_INFO_SIZE = 0x0100
COMMON_DATA_SIZE = 0x008E

ROOM_LAYOUT_OW_SIZE = 0x0390
ROOM_LAYOUT_UW_SIZE = 0x0300

BANK_ISR_SIGNATURE = bytes(
    [
        0x78,
        0xD8,
        0xA9,
        0x00,
        0x8D,
        0x00,
        0x20,
        0xA2,
        0xFF,
        0x9A,
        0xAD,
        0x02,
        0x20,
    ]
)

LEVEL_BLOCK_LABELS = [
    "LevelBlockOW",
    "LevelBlockUW1Q1",
    "LevelBlockUW2Q1",
    "LevelBlockUW1Q2",
    "LevelBlockUW2Q2",
]

LEVEL_INFO_LABELS = [
    "LevelInfoOW",
    "LevelInfoUW1",
    "LevelInfoUW2",
    "LevelInfoUW3",
    "LevelInfoUW4",
    "LevelInfoUW5",
    "LevelInfoUW6",
    "LevelInfoUW7",
    "LevelInfoUW8",
    "LevelInfoUW9",
]

OW_HEAP_LABELS = [
    "ColumnHeapOW0",
    "ColumnHeapOW1",
    "ColumnHeapOW2",
    "ColumnHeapOW3",
    "ColumnHeapOW4",
    "ColumnHeapOW5",
    "ColumnHeapOW6",
    "ColumnHeapOW7",
    "ColumnHeapOW8",
    "ColumnHeapOW9",
    "ColumnHeapOWA",
    "ColumnHeapOWB",
    "ColumnHeapOWC",
    "ColumnHeapOWD",
    "ColumnHeapOWE",
    "ColumnHeapOWF",
]

UW_HEAP_LABELS = [
    "ColumnHeapUW0",
    "ColumnHeapUW1",
    "ColumnHeapUW2",
    "ColumnHeapUW3",
    "ColumnHeapUW4",
    "ColumnHeapUW5",
    "ColumnHeapUW6",
    "ColumnHeapUW7",
    "ColumnHeapUW8",
    "ColumnHeapUW9",
]

Q2_REPLACEMENT_LABELS = [
    "LevelInfoUWQ2Replacements1",
    "LevelInfoUWQ2Replacements2",
    "LevelInfoUWQ2Replacements3",
    "LevelInfoUWQ2Replacements4",
    "LevelInfoUWQ2Replacements5",
    "LevelInfoUWQ2Replacements6",
    "LevelInfoUWQ2Replacements7",
    "LevelInfoUWQ2Replacements8",
    "LevelInfoUWQ2Replacements9",
]

Z05_TARGET_LABELS = {
    "RoomLayoutsOW",
    "RoomLayoutOWCave0",
    "RoomLayoutOWCave1",
    "RoomLayoutOWCave2",
    "RoomLayoutsUW",
    "RoomLayoutUWCellar0",
    "RoomLayoutUWCellar1",
    "ColumnHeapUWCellar",
    "ColumnDirectoryUW",
    *OW_HEAP_LABELS,
    *UW_HEAP_LABELS,
}

Z06_TARGET_LABELS = {
    "LevelBlockAttrsBQ2ReplacementOffsets",
    "LevelBlockAttrsBQ2ReplacementValues",
    "LevelInfoUWQ2ReplacementAddrs",
    "LevelInfoUWQ2ReplacementSizes",
    "ColumnDirectoryOW",
    *Q2_REPLACEMENT_LABELS,
}

INCBIN_SIZES = {
    "RoomLayoutsOW": ROOM_LAYOUT_OW_SIZE,
    "RoomLayoutsUW": ROOM_LAYOUT_UW_SIZE,
}

LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):$")


def read_ines_rom(path):
    with open(path, "rb") as f:
        header = f.read(INES_HEADER_SIZE)

    if header[:4] != b"NES\x1a":
        raise ValueError(f"Not a valid iNES ROM: {path}")

    prg_banks = header[4]

    with open(path, "rb") as f:
        f.seek(INES_HEADER_SIZE)
        prg_data = f.read(prg_banks * PRG_BANK_SIZE)

    return prg_data


def strip_comment(line):
    return line.split(";", 1)[0].strip()


def parse_byte_token(token):
    token = token.strip()
    if not token:
        raise ValueError("Empty .BYTE token")
    if token.startswith("$"):
        return int(token[1:], 16)
    return int(token, 10)


def parse_asm_data_blocks(path, target_labels, incbin_sizes=None):
    if incbin_sizes is None:
        incbin_sizes = {}

    blocks = {}
    current = None

    with open(path, "r", encoding="utf-8") as f:
        for raw_line in f:
            line = strip_comment(raw_line)
            if not line:
                if current is not None:
                    block = blocks[current]
                    if (
                        block["bytes"]
                        or block["addr_labels"]
                        or block["incbin_size"] is not None
                    ):
                        current = None
                continue

            label_match = LABEL_RE.match(line)
            if label_match:
                label = label_match.group(1)
                current = label if label in target_labels else None
                if current is not None and current not in blocks:
                    blocks[current] = {
                        "bytes": bytearray(),
                        "addr_labels": [],
                        "incbin_size": None,
                    }
                continue

            if current is None:
                continue

            if line.startswith(".BYTE"):
                items = [item.strip() for item in line[5:].split(",") if item.strip()]
                blocks[current]["bytes"].extend(parse_byte_token(item) for item in items)
            elif line.startswith(".ADDR"):
                items = [item.strip() for item in line[5:].split(",") if item.strip()]
                blocks[current]["addr_labels"].extend(items)
            elif line.startswith(".INCBIN"):
                if current not in incbin_sizes:
                    raise ValueError(f"Missing size for .INCBIN label {current}")
                blocks[current]["incbin_size"] = incbin_sizes[current]

    missing = sorted(label for label in target_labels if label not in blocks)
    if missing:
        raise ValueError(f"Missing expected labels in {path}: {', '.join(missing)}")

    return blocks


def find_unique_pattern(data, pattern, description):
    pos = data.find(pattern)
    if pos < 0:
        raise ValueError(f"Could not find {description}")
    second = data.find(pattern, pos + 1)
    if second >= 0:
        raise ValueError(
            f"{description} was not unique (found at {pos:#x} and {second:#x})"
        )
    return pos


def find_bank6_level_data(prg_data, z06_blocks):
    bank6_offset = 6 * PRG_BANK_SIZE
    bank6_data = prg_data[bank6_offset : bank6_offset + PRG_BANK_SIZE]

    isr_pos = bank6_data.find(BANK_ISR_SIGNATURE)
    if isr_pos < 0:
        raise ValueError("Could not find BANK_06_ISR signature")
    print(
        f"  Found BANK_06_ISR at bank 6 offset ${isr_pos:04X} "
        f"(ROM ${bank6_offset + isr_pos:05X})"
    )

    ff_run_start = None
    level_block_start = None
    for i in range(len(bank6_data) - 64):
        if all(byte == 0xFF for byte in bank6_data[i : i + 64]):
            end = i
            while end < len(bank6_data) and bank6_data[end] == 0xFF:
                end += 1
            ff_run_start = i
            level_block_start = end
            break

    if level_block_start is None:
        raise ValueError("Could not find padding before level block data")

    print(
        f"  Found bank 6 padding at ${ff_run_start:04X}-${level_block_start - 1:04X}; "
        f"level data starts at ${level_block_start:04X}"
    )

    level_blocks = {}
    offset = level_block_start
    for label in LEVEL_BLOCK_LABELS:
        rom_offset = bank6_offset + offset
        level_blocks[label] = prg_data[rom_offset : rom_offset + LEVEL_BLOCK_SIZE]
        print(f"    {label}: ROM ${rom_offset:05X}, {LEVEL_BLOCK_SIZE} bytes")
        offset += LEVEL_BLOCK_SIZE

    level_infos = {}
    for label in LEVEL_INFO_LABELS:
        rom_offset = bank6_offset + offset
        level_infos[label] = prg_data[rom_offset : rom_offset + LEVEL_INFO_SIZE]
        print(f"    {label}: ROM ${rom_offset:05X}, {LEVEL_INFO_SIZE} bytes")
        offset += LEVEL_INFO_SIZE

    common_data_rom_offset = bank6_offset + offset
    common_data = prg_data[
        common_data_rom_offset : common_data_rom_offset + COMMON_DATA_SIZE
    ]
    print(
        f"    CommonDataBlock_Bank6: ROM ${common_data_rom_offset:05X}, "
        f"{COMMON_DATA_SIZE} bytes"
    )

    column_directory_ow = bytes(z06_blocks["ColumnDirectoryOW"]["bytes"])
    column_dir_pos = find_unique_pattern(
        bank6_data, column_directory_ow, "ColumnDirectoryOW in bank 6"
    )
    print(
        f"    ColumnDirectoryOW found at bank 6 offset ${column_dir_pos:04X} "
        f"(ROM ${bank6_offset + column_dir_pos:05X})"
    )

    q2_patch_pos = find_unique_pattern(
        bank6_data,
        bytes(z06_blocks["LevelBlockAttrsBQ2ReplacementOffsets"]["bytes"]),
        "Q2 room replacement offset table in bank 6",
    )
    print(
        f"    Q2 patch tables begin at bank 6 offset ${q2_patch_pos:04X} "
        f"(ROM ${bank6_offset + q2_patch_pos:05X})"
    )

    return {
        "level_blocks": level_blocks,
        "level_infos": level_infos,
        "common_data": common_data,
    }


def find_bank5_room_data(prg_data, z05_blocks):
    bank5_offset = 5 * PRG_BANK_SIZE
    bank5_data = prg_data[bank5_offset : bank5_offset + PRG_BANK_SIZE]

    cave0 = bytes(z05_blocks["RoomLayoutOWCave0"]["bytes"])
    cellar0 = bytes(z05_blocks["RoomLayoutUWCellar0"]["bytes"])

    cave0_pos = find_unique_pattern(bank5_data, cave0, "RoomLayoutOWCave0 in bank 5")
    cellar0_pos = find_unique_pattern(
        bank5_data, cellar0, "RoomLayoutUWCellar0 in bank 5"
    )

    room_layouts_ow_start = cave0_pos - ROOM_LAYOUT_OW_SIZE
    if room_layouts_ow_start < 0:
        raise ValueError("Invalid RoomLayoutsOW start in bank 5")

    uw_heap_total = sum(len(z05_blocks[label]["bytes"]) for label in UW_HEAP_LABELS)
    room_layouts_uw_start = cellar0_pos - uw_heap_total - ROOM_LAYOUT_UW_SIZE
    if room_layouts_uw_start < 0:
        raise ValueError("Invalid RoomLayoutsUW start in bank 5")

    print(
        f"  RoomLayoutsOW: bank 5 offset ${room_layouts_ow_start:04X} "
        f"(ROM ${bank5_offset + room_layouts_ow_start:05X})"
    )
    print(
        f"  RoomLayoutsUW: bank 5 offset ${room_layouts_uw_start:04X} "
        f"(ROM ${bank5_offset + room_layouts_uw_start:05X})"
    )

    # Extract the 912 bytes of actual layout data (57 layouts)
    room_layouts_ow = bank5_data[
        room_layouts_ow_start : room_layouts_ow_start + ROOM_LAYOUT_OW_SIZE
    ]
    room_layouts_uw = bank5_data[
        room_layouts_uw_start : room_layouts_uw_start + ROOM_LAYOUT_UW_SIZE
    ]

    ow_cave_layouts = {}
    offset = cave0_pos
    for label in ["RoomLayoutOWCave0", "RoomLayoutOWCave1", "RoomLayoutOWCave2"]:
        size = len(z05_blocks[label]["bytes"])
        data = bank5_data[offset : offset + size]
        expected = bytes(z05_blocks[label]["bytes"])
        if data != expected:
            raise ValueError(f"ROM mismatch for {label}")
        ow_cave_layouts[label] = data
        offset += size

    ow_heaps = {}
    ow_heap_offsets = []
    ow_heap_blob = bytearray()
    for label in OW_HEAP_LABELS:
        size = len(z05_blocks[label]["bytes"])
        data = bank5_data[offset : offset + size]
        expected = bytes(z05_blocks[label]["bytes"])
        if data != expected:
            raise ValueError(f"ROM mismatch for {label}")
        ow_heaps[label] = data
        ow_heap_offsets.append(len(ow_heap_blob))
        ow_heap_blob.extend(data)
        offset += size

    uw_heaps = {}
    offset = room_layouts_uw_start + ROOM_LAYOUT_UW_SIZE
    for label in UW_HEAP_LABELS:
        size = len(z05_blocks[label]["bytes"])
        data = bank5_data[offset : offset + size]
        expected = bytes(z05_blocks[label]["bytes"])
        if data != expected:
            raise ValueError(f"ROM mismatch for {label}")
        uw_heaps[label] = data
        offset += size

    if offset != cellar0_pos:
        raise ValueError(
            f"UW heap extraction drifted before cellar layouts: "
            f"expected ${cellar0_pos:04X}, got ${offset:04X}"
        )

    uw_cellar_layouts = {}
    for label in ["RoomLayoutUWCellar0", "RoomLayoutUWCellar1"]:
        size = len(z05_blocks[label]["bytes"])
        data = bank5_data[offset : offset + size]
        expected = bytes(z05_blocks[label]["bytes"])
        if data != expected:
            raise ValueError(f"ROM mismatch for {label}")
        uw_cellar_layouts[label] = data
        offset += size

    cellar_heap_size = len(z05_blocks["ColumnHeapUWCellar"]["bytes"])
    cellar_heap = bank5_data[offset : offset + cellar_heap_size]
    if cellar_heap != bytes(z05_blocks["ColumnHeapUWCellar"]["bytes"]):
        raise ValueError("ROM mismatch for ColumnHeapUWCellar")

    return {
        "room_layouts_ow": room_layouts_ow,
        "room_layouts_uw": room_layouts_uw,
        "ow_cave_layouts": ow_cave_layouts,
        "ow_heaps": ow_heaps,
        "ow_heap_blob": bytes(ow_heap_blob),
        "ow_heap_offsets": ow_heap_offsets,
        "uw_heaps": uw_heaps,
        "uw_cellar_layouts": uw_cellar_layouts,
        "uw_cellar_heap": cellar_heap,
    }


def data_to_inc_bytes(data, label, bytes_per_line=16):
    lines = [f"; {label} - {len(data)} bytes", f"{label}:"]
    for i in range(0, len(data), bytes_per_line):
        chunk = data[i : i + bytes_per_line]
        lines.append("    dc.b " + ",".join(f"${byte:02X}" for byte in chunk))
    return "\n".join(lines)


def labels_to_inc_words(label_names, table_label, words_per_line=4):
    lines = [f"{table_label}:"]
    for i in range(0, len(label_names), words_per_line):
        chunk = label_names[i : i + words_per_line]
        lines.append("    dc.w " + ",".join(chunk))
    return "\n".join(lines)


def values_to_inc_words(values, table_label, words_per_line=8):
    lines = [f"{table_label}:"]
    for i in range(0, len(values), words_per_line):
        chunk = values[i : i + words_per_line]
        lines.append("    dc.w " + ",".join(f"${value:04X}" for value in chunk))
    return "\n".join(lines)


def write_text_file(path, lines):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"  Wrote {path}")


def write_room_attr_files(data_dir, level_blocks):
    ow_block = level_blocks["LevelBlockOW"]
    lines = [
        "; Overworld room attributes (6 tables x 128 rooms)",
        "; Auto-generated by extract_rooms.py - DO NOT EDIT",
        "; Each table is 128 bytes, indexed by room ID (row*16 + col)",
        "",
        "; Byte A: outer palette, exit X, door bits (S/N)",
        data_to_inc_bytes(ow_block[0x000:0x080], "RoomAttrsOW_A"),
        "",
        "; Byte B: inner palette, cave index, door bits (E/W)",
        data_to_inc_bytes(ow_block[0x080:0x100], "RoomAttrsOW_B"),
        "",
        "; Byte C: monster list ID (low 6 bits)",
        data_to_inc_bytes(ow_block[0x100:0x180], "RoomAttrsOW_C"),
        "",
        "; Byte D: unique room ID low 6 bits, push-block flag, specials",
        data_to_inc_bytes(ow_block[0x180:0x200], "RoomAttrsOW_D"),
        "",
        "; Byte E: sound effect / item metadata",
        data_to_inc_bytes(ow_block[0x200:0x280], "RoomAttrsOW_E"),
        "",
        "; Byte F: secret trigger, underground exit row, edge spawning",
        data_to_inc_bytes(ow_block[0x280:0x300], "RoomAttrsOW_F"),
    ]
    write_text_file(os.path.join(data_dir, "rooms_overworld.inc"), lines)

    for suffix, q1_key, q2_key in [
        ("1", "LevelBlockUW1Q1", "LevelBlockUW1Q2"),
        ("2", "LevelBlockUW2Q1", "LevelBlockUW2Q2"),
    ]:
        q1_block = level_blocks[q1_key]
        q2_block = level_blocks[q2_key]
        range_label = "1-6" if suffix == "1" else "7-9"
        lines = [
            f"; Underworld room attributes set {suffix}",
            "; Auto-generated by extract_rooms.py - DO NOT EDIT",
            "",
            f"; Quest 1 (levels {range_label})",
            data_to_inc_bytes(q1_block[0x000:0x080], f"RoomAttrsUW{suffix}Q1_A"),
            "",
            data_to_inc_bytes(q1_block[0x080:0x100], f"RoomAttrsUW{suffix}Q1_B"),
            "",
            data_to_inc_bytes(q1_block[0x100:0x180], f"RoomAttrsUW{suffix}Q1_C"),
            "",
            data_to_inc_bytes(q1_block[0x180:0x200], f"RoomAttrsUW{suffix}Q1_D"),
            "",
            data_to_inc_bytes(q1_block[0x200:0x280], f"RoomAttrsUW{suffix}Q1_E"),
            "",
            data_to_inc_bytes(q1_block[0x280:0x300], f"RoomAttrsUW{suffix}Q1_F"),
            "",
            f"; Quest 2 (levels {range_label})",
            data_to_inc_bytes(q2_block[0x000:0x080], f"RoomAttrsUW{suffix}Q2_A"),
            "",
            data_to_inc_bytes(q2_block[0x080:0x100], f"RoomAttrsUW{suffix}Q2_B"),
            "",
            data_to_inc_bytes(q2_block[0x100:0x180], f"RoomAttrsUW{suffix}Q2_C"),
            "",
            data_to_inc_bytes(q2_block[0x180:0x200], f"RoomAttrsUW{suffix}Q2_D"),
            "",
            data_to_inc_bytes(q2_block[0x200:0x280], f"RoomAttrsUW{suffix}Q2_E"),
            "",
            data_to_inc_bytes(q2_block[0x280:0x300], f"RoomAttrsUW{suffix}Q2_F"),
        ]
        write_text_file(os.path.join(data_dir, f"rooms_underworld{suffix}.inc"), lines)


def write_level_info_file(data_dir, level_infos):
    lines = [
        "; Level info blocks (256 bytes each)",
        "; Auto-generated by extract_rooms.py - DO NOT EDIT",
        "",
    ]
    for label in LEVEL_INFO_LABELS:
        lines.append(data_to_inc_bytes(level_infos[label], label))
        lines.append("")

    write_text_file(os.path.join(data_dir, "level_info.inc"), lines[:-1])


def write_room_layouts_file(data_dir, bank5_data):
    lines = [
        "; Room layout descriptor tables",
        "; Auto-generated by extract_rooms.py - DO NOT EDIT",
        "; Overworld unique rooms use 16 column descriptors each",
        "; Underworld unique rooms use 12 column descriptors each",
        "",
        data_to_inc_bytes(bank5_data["room_layouts_ow"], "RoomLayoutsOW"),
        "",
    ]

    for label in ["RoomLayoutOWCave0", "RoomLayoutOWCave1", "RoomLayoutOWCave2"]:
        lines.append(data_to_inc_bytes(bank5_data["ow_cave_layouts"][label], label))
        lines.append("")

    lines.append(data_to_inc_bytes(bank5_data["room_layouts_uw"], "RoomLayoutsUW"))
    lines.append("")

    for label in ["RoomLayoutUWCellar0", "RoomLayoutUWCellar1"]:
        lines.append(data_to_inc_bytes(bank5_data["uw_cellar_layouts"][label], label))
        lines.append("")

    write_text_file(os.path.join(data_dir, "room_layouts.inc"), lines[:-1])


def write_room_columns_file(data_dir, bank5_data, z05_blocks):
    uw_directory_labels = z05_blocks["ColumnDirectoryUW"]["addr_labels"]
    ow_directory_exprs = [
        f"ColumnHeapOWBlob+${offset:04X}" for offset in bank5_data["ow_heap_offsets"]
    ]

    lines = [
        "; Column directories and compressed column heaps",
        "; Auto-generated by extract_rooms.py - DO NOT EDIT",
        "",
        "; Overworld directory preserved as offsets into one continuous heap blob",
        values_to_inc_words(bank5_data["ow_heap_offsets"], "ColumnDirectoryOWOffsets"),
        "",
        labels_to_inc_words(ow_directory_exprs, "ColumnDirectoryOW"),
        "",
    ]

    lines.append(data_to_inc_bytes(bank5_data["ow_heap_blob"], "ColumnHeapOWBlob"))
    lines.append("")

    lines.append(labels_to_inc_words(uw_directory_labels, "ColumnDirectoryUW"))
    lines.append("")

    for label in UW_HEAP_LABELS:
        lines.append(data_to_inc_bytes(bank5_data["uw_heaps"][label], label))
        lines.append("")

    lines.append(data_to_inc_bytes(bank5_data["uw_cellar_heap"], "ColumnHeapUWCellar"))

    write_text_file(os.path.join(data_dir, "room_columns.inc"), lines)


def write_room_common_file(data_dir, common_data):
    lines = [
        "; Common room data copied by bank 6 loader",
        "; Auto-generated by extract_rooms.py - DO NOT EDIT",
        "",
        data_to_inc_bytes(common_data, "CommonDataBlock_Bank6"),
    ]
    write_text_file(os.path.join(data_dir, "room_common.inc"), lines)


def write_room_patches_file(data_dir, z06_blocks):
    lines = [
        "; Second quest room/data patch tables",
        "; Auto-generated by extract_rooms.py - DO NOT EDIT",
        "",
        data_to_inc_bytes(
            bytes(z06_blocks["LevelBlockAttrsBQ2ReplacementOffsets"]["bytes"]),
            "LevelBlockAttrsBQ2ReplacementOffsets",
        ),
        "",
        data_to_inc_bytes(
            bytes(z06_blocks["LevelBlockAttrsBQ2ReplacementValues"]["bytes"]),
            "LevelBlockAttrsBQ2ReplacementValues",
        ),
        "",
        labels_to_inc_words(Q2_REPLACEMENT_LABELS, "LevelInfoUWQ2ReplacementAddrs"),
        "",
        data_to_inc_bytes(
            bytes(z06_blocks["LevelInfoUWQ2ReplacementSizes"]["bytes"]),
            "LevelInfoUWQ2ReplacementSizes",
        ),
        "",
    ]

    for label in Q2_REPLACEMENT_LABELS:
        lines.append(data_to_inc_bytes(bytes(z06_blocks[label]["bytes"]), label))
        lines.append("")

    write_text_file(os.path.join(data_dir, "room_patches.inc"), lines[:-1])


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)

    rom_path = os.path.join(project_root, "Legend of Zelda, The (USA).nes")
    z05_path = os.path.join(project_root, "reference", "aldonunez", "Z_05.asm")
    z06_path = os.path.join(project_root, "reference", "aldonunez", "Z_06.asm")
    data_dir = os.path.join(project_root, "src", "data")

    for required_path in [rom_path, z05_path, z06_path]:
        if not os.path.exists(required_path):
            print(f"ERROR: required file not found: {required_path}")
            sys.exit(1)

    os.makedirs(data_dir, exist_ok=True)

    print(f"Reading NES ROM: {rom_path}")
    prg_data = read_ines_rom(rom_path)

    print(f"Parsing reference data: {z05_path}")
    z05_blocks = parse_asm_data_blocks(z05_path, Z05_TARGET_LABELS, INCBIN_SIZES)

    print(f"Parsing reference data: {z06_path}")
    z06_blocks = parse_asm_data_blocks(z06_path, Z06_TARGET_LABELS)

    print("\nExtracting bank 6 level/common data...")
    bank6_data = find_bank6_level_data(prg_data, z06_blocks)

    print("\nExtracting bank 5 layout/column data...")
    bank5_data = find_bank5_room_data(prg_data, z05_blocks)

    print("\nWriting room data files...")
    write_room_attr_files(data_dir, bank6_data["level_blocks"])
    write_level_info_file(data_dir, bank6_data["level_infos"])
    write_room_layouts_file(data_dir, bank5_data)
    write_room_columns_file(data_dir, bank5_data, z05_blocks)
    write_room_common_file(data_dir, bank6_data["common_data"])
    write_room_patches_file(data_dir, z06_blocks)

    total_bytes = 0
    total_bytes += sum(len(data) for data in bank6_data["level_blocks"].values())
    total_bytes += sum(len(data) for data in bank6_data["level_infos"].values())
    total_bytes += len(bank6_data["common_data"])
    total_bytes += len(bank5_data["room_layouts_ow"])
    total_bytes += len(bank5_data["room_layouts_uw"])
    total_bytes += sum(len(data) for data in bank5_data["ow_cave_layouts"].values())
    total_bytes += sum(len(data) for data in bank5_data["ow_heaps"].values())
    total_bytes += sum(len(data) for data in bank5_data["uw_heaps"].values())
    total_bytes += sum(len(data) for data in bank5_data["uw_cellar_layouts"].values())
    total_bytes += len(bank5_data["uw_cellar_heap"])
    total_bytes += len(z06_blocks["LevelBlockAttrsBQ2ReplacementOffsets"]["bytes"])
    total_bytes += len(z06_blocks["LevelBlockAttrsBQ2ReplacementValues"]["bytes"])
    total_bytes += len(z06_blocks["LevelInfoUWQ2ReplacementSizes"]["bytes"])
    total_bytes += sum(len(z06_blocks[label]["bytes"]) for label in Q2_REPLACEMENT_LABELS)

    print("\n=== Room extraction complete ===")
    print(f"  Total extracted room data: {total_bytes} bytes")
    print(f"  Output directory: {data_dir}")


if __name__ == "__main__":
    main()
