#!/usr/bin/env python3
"""
extract_misc.py - Extract foundational item, UI, and player constants.

This script focuses on the first high-value slice of "misc" data needed by the
Genesis engine:
  - item metadata tables from Z_01
  - submenu / cave UI placement tables from Z_01 + Z_05
  - player movement helper constants from Z_01 + Z_05
  - palette helpers and Genesis CRAM conversion tables from Z_01 + Z_02 + Z_05

It deliberately keeps scope modest so the extraction pipeline can keep growing
in working increments instead of waiting on every text/UI system at once.
"""

import os
import re
import sys

INES_HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000
BANK_CPU_BASE = 0x8000

LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):$")
Z01_TARGET_LABELS = {
    "PriceListTemplateTransferBuf",
    "LifeOrMoneyItemXs",
    "LifeOrMoneyItemTypes",
    "LinkToSquareOffsetsX",
    "LinkToSquareOffsetsY",
    "ItemIdToSlot",
    "ItemIdToDescriptor",
    "ItemSlotToPaletteOffsetsOrValues",
    "PaletteRow7TransferRecord",
    "GanonColorTriples",
    "StatusBarTransferBufTemplate",
    "LinkColors_CommonCode",
    "OverworldPersonTextSelectors",
    "HintCaveTextSelectors0",
    "HintCaveTextSelectors1",
    "UnderworldPersonTextSelectorsA",
    "UnderworldPersonTextSelectorsB",
    "UnderworldPersonTextSelectorsC",
}

Z05_TARGET_LABELS = {
    "SubmenuItemXs",
    "SubmenuCursorXs",
    "TriforceTransferBufOffsets",
    "TriforceTriforceBufReplacements",
    "TriforceTransferBufTiles",
    "RoomPaletteSelectorToNTAttr",
}

Z02_PALETTE_LABELS = {
    "TitlePaletteTransferRecord",
    "StoryPaletteTransferRecord",
    "TriforcePaletteTransferRecord",
    "TriforceGlowingColors",
    "DemoPhase0Subphase1Palettes",
}


def strip_comment(line):
    return line.split(";", 1)[0].strip()


def parse_byte_token(token):
    token = token.strip()
    if not token:
        raise ValueError("Empty .BYTE token")
    if token.startswith("$"):
        return int(token[1:], 16)
    return int(token, 10)


def clamp(value, low, high):
    return max(low, min(high, value))


def read_ines_prg(path):
    with open(path, "rb") as f:
        header = f.read(INES_HEADER_SIZE)
        if header[:4] != b"NES\x1A":
            raise ValueError(f"Not a valid iNES ROM: {path}")
        prg_banks = header[4]
        prg_data = f.read(prg_banks * PRG_BANK_SIZE)
    return prg_data


def parse_asm_data_blocks(path, target_labels):
    blocks = {}
    current = None

    with open(path, "r", encoding="utf-8") as f:
        for raw_line in f:
            line = strip_comment(raw_line)
            if not line:
                if current is not None and blocks[current]["bytes"]:
                    current = None
                continue

            match = LABEL_RE.match(line)
            if match:
                label = match.group(1)
                current = label if label in target_labels else None
                if current is not None and current not in blocks:
                    blocks[current] = {"bytes": bytearray()}
                continue

            if current is None:
                continue

            if line.startswith(".BYTE"):
                items = [item.strip() for item in line[5:].split(",") if item.strip()]
                blocks[current]["bytes"].extend(parse_byte_token(item) for item in items)

    missing = sorted(label for label in target_labels if label not in blocks)
    if missing:
        raise ValueError(f"Missing expected labels in {path}: {', '.join(missing)}")

    return blocks


def bytes_to_words_inc(words, label, words_per_line=8):
    lines = [f"; {label} - {len(words)} words", f"{label}:"]
    for i in range(0, len(words), words_per_line):
        chunk = words[i : i + words_per_line]
        lines.append("    dc.w " + ",".join(f"${word:04X}" for word in chunk))
    return "\n".join(lines)


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


def parse_le_words(data):
    if len(data) & 1:
        raise ValueError("Word table has odd length")
    return [data[i] | (data[i + 1] << 8) for i in range(0, len(data), 2)]


def cpu_addr_to_bank_offset(cpu_addr):
    if cpu_addr < BANK_CPU_BASE or cpu_addr >= BANK_CPU_BASE + PRG_BANK_SIZE:
        raise ValueError(f"CPU address ${cpu_addr:04X} is outside bank range")
    return cpu_addr - BANK_CPU_BASE


def build_pointer_labels(addresses, prefix):
    labels_by_addr = {}
    table_labels = []
    for addr in addresses:
        if addr not in labels_by_addr:
            labels_by_addr[addr] = f"{prefix}{len(labels_by_addr):02d}"
        table_labels.append(labels_by_addr[addr])
    ordered_addrs = sorted(labels_by_addr)
    return labels_by_addr, table_labels, ordered_addrs


def labels_to_inc_words(label_names, table_label, words_per_line=4):
    lines = [f"; {table_label} - {len(label_names)} entries", f"{table_label}:"]
    for i in range(0, len(label_names), words_per_line):
        chunk = label_names[i : i + words_per_line]
        lines.append("    dc.w " + ",".join(chunk))
    return "\n".join(lines)


def write_labeled_records(lines, blob, ordered_addrs, labels_by_addr):
    first_offset = cpu_addr_to_bank_offset(ordered_addrs[0])
    ordered_offsets = [cpu_addr_to_bank_offset(addr) for addr in ordered_addrs]
    for index, addr in enumerate(ordered_addrs):
        start = ordered_offsets[index] - first_offset
        if index + 1 < len(ordered_offsets):
            end = ordered_offsets[index + 1] - first_offset
        else:
            end = len(blob)
        label = labels_by_addr[addr]
        lines.append(f"; {label} - {end - start} bytes")
        lines.append(f"{label}:")
        data = blob[start:end]
        for i in range(0, len(data), 16):
            chunk = data[i : i + 16]
            lines.append("    dc.b " + ",".join(f"${byte:02X}" for byte in chunk))
        lines.append("")


def max_person_text_selector(z01_blocks):
    selector_values = []
    selector_values.extend(
        byte & 0x3F for byte in z01_blocks["OverworldPersonTextSelectors"]["bytes"]
    )
    for label in [
        "HintCaveTextSelectors0",
        "HintCaveTextSelectors1",
        "UnderworldPersonTextSelectorsA",
        "UnderworldPersonTextSelectorsB",
        "UnderworldPersonTextSelectorsC",
    ]:
        selector_values.extend(z01_blocks[label]["bytes"])
    return max(selector_values)


def extract_person_text(prg_data, z01_blocks):
    bank1_data = prg_data[1 * PRG_BANK_SIZE : 2 * PRG_BANK_SIZE]
    person_addr_table_size = max_person_text_selector(z01_blocks) + 2
    overworld_selector_bytes = bytes(z01_blocks["OverworldPersonTextSelectors"]["bytes"])
    overworld_selector_pos = find_unique_pattern(
        bank1_data,
        overworld_selector_bytes,
        "OverworldPersonTextSelectors in bank 1",
    )

    addr_table = bytes(bank1_data[:person_addr_table_size])
    text_blob = bytes(bank1_data[person_addr_table_size:overworld_selector_pos])
    addresses = parse_le_words(addr_table)

    first_text_offset = cpu_addr_to_bank_offset(addresses[0])
    if first_text_offset != person_addr_table_size:
        raise ValueError(
            "PersonTextAddrs did not point at the expected start of PersonText"
        )

    return {
        "addresses": addresses,
        "text_blob": text_blob,
    }


def extract_init_link_speed_constants(z05_path):
    with open(z05_path, "r", encoding="utf-8") as f:
        text = f.read()

    start = text.find("InitLinkSpeed:")
    end = text.find("Link_ModifyDirOnGridLine:", start)
    if start < 0 or end < 0:
        raise ValueError("Could not locate InitLinkSpeed block")

    block = text[start:end]
    values = []
    for raw_line in block.splitlines():
        line = strip_comment(raw_line)
        if line.startswith("LDA #$"):
            values.append(int(line.split("#$", 1)[1], 16))

    if len(values) < 3:
        raise ValueError("Could not extract Link speed constants from InitLinkSpeed")

    return {
        "LinkQSpeedDefault": values[0],
        "LinkQSpeedMountainStairs": values[1],
    }


def data_to_inc_bytes(data, label, bytes_per_line=16):
    lines = [f"; {label} - {len(data)} bytes", f"{label}:"]
    for i in range(0, len(data), bytes_per_line):
        chunk = data[i : i + bytes_per_line]
        lines.append("    dc.b " + ",".join(f"${byte:02X}" for byte in chunk))
    return "\n".join(lines)


def nes_level_to_genesis(level):
    level = clamp(level, 0.0, 1.0)
    return int(round(level * 7.0)) * 2


def nes_color_index_to_genesis(color_index):
    color_index &= 0x3F
    nes_rgb_palette = [
        (124, 124, 124), (0, 0, 252), (0, 0, 188), (68, 40, 188),
        (148, 0, 132), (168, 0, 32), (168, 16, 0), (136, 20, 0),
        (80, 48, 0), (0, 120, 0), (0, 104, 0), (0, 88, 0),
        (0, 64, 88), (0, 0, 0), (0, 0, 0), (0, 0, 0),
        (188, 188, 188), (0, 120, 248), (0, 88, 248), (104, 68, 252),
        (216, 0, 204), (228, 0, 88), (248, 56, 0), (228, 92, 16),
        (172, 124, 0), (0, 184, 0), (0, 168, 0), (0, 168, 68),
        (0, 136, 136), (0, 0, 0), (0, 0, 0), (0, 0, 0),
        (248, 248, 248), (60, 188, 252), (104, 136, 252), (152, 120, 248),
        (248, 120, 248), (248, 88, 152), (248, 120, 88), (252, 160, 68),
        (248, 184, 0), (184, 248, 24), (88, 216, 84), (88, 248, 152),
        (0, 232, 216), (120, 120, 120), (0, 0, 0), (0, 0, 0),
        (252, 252, 252), (164, 228, 252), (184, 184, 248), (216, 184, 248),
        (248, 184, 248), (248, 164, 192), (240, 208, 176), (252, 224, 168),
        (248, 216, 120), (216, 248, 120), (184, 248, 184), (184, 248, 216),
        (0, 252, 252), (248, 216, 248), (0, 0, 0), (0, 0, 0),
    ]

    red, green, blue = nes_rgb_palette[color_index]

    red_level = nes_level_to_genesis((red / 255.0) ** 0.9)
    green_level = nes_level_to_genesis((green / 255.0) ** 0.9)
    blue_level = nes_level_to_genesis((blue / 255.0) ** 0.9)
    return (blue_level << 8) | (green_level << 4) | red_level


def palette_record_to_nes_colors(record_bytes):
    if len(record_bytes) < 4 or record_bytes[-1] != 0xFF:
        raise ValueError("Palette transfer record was not terminated with $FF")
    color_count = record_bytes[2]
    color_start = 3
    color_end = color_start + color_count
    if color_end != len(record_bytes) - 1:
        raise ValueError("Palette transfer record length did not match payload")
    return list(record_bytes[color_start:color_end])


def nes_colors_to_genesis_words(color_bytes):
    return [nes_color_index_to_genesis(color) for color in color_bytes]


def tuned_link_colors_genesis():
    # The extracted NES source bytes for gameplay Link are correct, but the
    # generic lookup-table conversion leaves the opening-screen sprite looking
    # noticeably off compared to the NES reference capture.
    # The placeholder Link art uses the third sprite color for the larger
    # shaded regions and the second sprite color for the smaller highlights,
    # so keep the green base and tune/swap the two warm colors to match the
    # live NES opening-screen capture more closely.
    return [0x0C8, 0x28E, 0x04A]


def write_text_file(path, lines):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"  Wrote {path}")


def write_item_tables(data_dir, z01_blocks):
    lines = [
        "; Item metadata tables extracted from NES Zelda",
        "; Auto-generated by extract_misc.py - DO NOT EDIT",
        "",
        data_to_inc_bytes(bytes(z01_blocks["ItemIdToSlot"]["bytes"]), "ItemIdToSlot"),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["ItemIdToDescriptor"]["bytes"]),
            "ItemIdToDescriptor",
        ),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["ItemSlotToPaletteOffsetsOrValues"]["bytes"]),
            "ItemSlotToPaletteOffsetsOrValues",
        ),
    ]

    write_text_file(os.path.join(data_dir, "item_tables.inc"), lines)


def write_ui_layout(data_dir, z01_blocks, z05_blocks):
    lines = [
        "; UI and submenu placement tables extracted from NES Zelda",
        "; Auto-generated by extract_misc.py - DO NOT EDIT",
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["PriceListTemplateTransferBuf"]["bytes"]),
            "PriceListTemplateTransferBuf",
        ),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["LifeOrMoneyItemXs"]["bytes"]),
            "LifeOrMoneyItemXs",
        ),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["LifeOrMoneyItemTypes"]["bytes"]),
            "LifeOrMoneyItemTypes",
        ),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["StatusBarTransferBufTemplate"]["bytes"]),
            "StatusBarTransferBufTemplate",
        ),
        "",
        data_to_inc_bytes(bytes(z05_blocks["SubmenuItemXs"]["bytes"]), "SubmenuItemXs"),
        "",
        data_to_inc_bytes(
            bytes(z05_blocks["SubmenuCursorXs"]["bytes"]),
            "SubmenuCursorXs",
        ),
        "",
        data_to_inc_bytes(
            bytes(z05_blocks["TriforceTransferBufOffsets"]["bytes"]),
            "TriforceTransferBufOffsets",
        ),
        "",
        data_to_inc_bytes(
            bytes(z05_blocks["TriforceTriforceBufReplacements"]["bytes"]),
            "TriforceTriforceBufReplacements",
        ),
        "",
        data_to_inc_bytes(
            bytes(z05_blocks["TriforceTransferBufTiles"]["bytes"]),
            "TriforceTransferBufTiles",
        ),
    ]

    write_text_file(os.path.join(data_dir, "ui_layout.inc"), lines)


def write_palette_tables(data_dir, z01_blocks, z05_blocks):
    lines = [
        "; Gameplay palette and attribute helper tables extracted from NES Zelda",
        "; Auto-generated by extract_misc.py - DO NOT EDIT",
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["PaletteRow7TransferRecord"]["bytes"]),
            "PaletteRow7TransferRecord",
        ),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["GanonColorTriples"]["bytes"]),
            "GanonColorTriples",
        ),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["LinkColors_CommonCode"]["bytes"]),
            "LinkColors_CommonCode",
        ),
        "",
        data_to_inc_bytes(
            bytes(z05_blocks["RoomPaletteSelectorToNTAttr"]["bytes"]),
            "RoomPaletteSelectorToNTAttr",
        ),
    ]

    write_text_file(os.path.join(data_dir, "palette_tables.inc"), lines)


def write_palettes_inc(data_dir, z01_blocks, z02_blocks):
    title_colors = palette_record_to_nes_colors(
        bytes(z02_blocks["TitlePaletteTransferRecord"]["bytes"])
    )
    story_colors = palette_record_to_nes_colors(
        bytes(z02_blocks["StoryPaletteTransferRecord"]["bytes"])
    )
    triforce_colors = palette_record_to_nes_colors(
        bytes(z02_blocks["TriforcePaletteTransferRecord"]["bytes"])
    )
    row7_colors = palette_record_to_nes_colors(
        bytes(z01_blocks["PaletteRow7TransferRecord"]["bytes"])
    )
    demo_colors = bytes(z02_blocks["DemoPhase0Subphase1Palettes"]["bytes"])
    triforce_glow_colors = bytes(z02_blocks["TriforceGlowingColors"]["bytes"])
    link_colors = bytes(z01_blocks["LinkColors_CommonCode"]["bytes"])
    ganon_colors = bytes(z01_blocks["GanonColorTriples"]["bytes"])

    lookup_words = [nes_color_index_to_genesis(index) for index in range(0x40)]

    lines = [
        "; Unified Phase 1 palette output extracted from NES Zelda",
        "; Auto-generated by extract_misc.py - DO NOT EDIT",
        "; Genesis CRAM words are stored in 0BGR format.",
        "",
        bytes_to_words_inc(lookup_words, "NesColorToGenesisCRAM"),
        "",
        bytes_to_words_inc(
            nes_colors_to_genesis_words(title_colors),
            "TitlePaletteGenesis",
        ),
        "",
        bytes_to_words_inc(
            nes_colors_to_genesis_words(story_colors),
            "StoryPaletteGenesis",
        ),
        "",
        bytes_to_words_inc(
            nes_colors_to_genesis_words(triforce_colors),
            "TriforcePaletteGenesis",
        ),
        "",
        bytes_to_words_inc(
            nes_colors_to_genesis_words(row7_colors),
            "PaletteRow7Genesis",
        ),
        "",
        bytes_to_words_inc(
            nes_colors_to_genesis_words(triforce_glow_colors),
            "TriforceGlowingColorsGenesis",
        ),
        "",
        bytes_to_words_inc(
            tuned_link_colors_genesis(),
            "LinkColorsGenesis",
        ),
        "",
        bytes_to_words_inc(
            nes_colors_to_genesis_words(ganon_colors),
            "GanonColorTriplesGenesis",
        ),
        "",
        bytes_to_words_inc(
            nes_colors_to_genesis_words(demo_colors),
            "DemoPhase0Subphase1PalettesGenesis",
        ),
    ]

    write_text_file(os.path.join(data_dir, "palettes.inc"), lines)


def write_person_text_file(data_dir, z01_blocks, person_text_data):
    labels_by_addr, table_labels, ordered_addrs = build_pointer_labels(
        person_text_data["addresses"], "PersonText"
    )

    lines = [
        "; Person/cave text tables extracted from NES Zelda bank 1",
        "; Auto-generated by extract_misc.py - DO NOT EDIT",
        "",
        "; Overworld selector bytes keep the original high-bit cave flags",
        data_to_inc_bytes(
            bytes(z01_blocks["OverworldPersonTextSelectors"]["bytes"]),
            "OverworldPersonTextSelectors",
        ),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["HintCaveTextSelectors0"]["bytes"]),
            "HintCaveTextSelectors0",
        ),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["HintCaveTextSelectors1"]["bytes"]),
            "HintCaveTextSelectors1",
        ),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["UnderworldPersonTextSelectorsA"]["bytes"]),
            "UnderworldPersonTextSelectorsA",
        ),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["UnderworldPersonTextSelectorsB"]["bytes"]),
            "UnderworldPersonTextSelectorsB",
        ),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["UnderworldPersonTextSelectorsC"]["bytes"]),
            "UnderworldPersonTextSelectorsC",
        ),
        "",
        labels_to_inc_words(table_labels, "PersonTextAddrs"),
        "",
    ]

    write_labeled_records(lines, person_text_data["text_blob"], ordered_addrs, labels_by_addr)
    write_text_file(os.path.join(data_dir, "person_text.inc"), lines[:-1])


def write_player_constants(data_dir, z01_blocks, link_speed_constants):
    lines = [
        "; Player constants extracted from NES Zelda",
        "; Auto-generated by extract_misc.py - DO NOT EDIT",
        "",
        f"LinkQSpeedDefault equ ${link_speed_constants['LinkQSpeedDefault']:02X}",
        f"LinkQSpeedMountainStairs equ ${link_speed_constants['LinkQSpeedMountainStairs']:02X}",
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["LinkToSquareOffsetsX"]["bytes"]),
            "LinkToSquareOffsetsX",
        ),
        "",
        data_to_inc_bytes(
            bytes(z01_blocks["LinkToSquareOffsetsY"]["bytes"]),
            "LinkToSquareOffsetsY",
        ),
    ]

    write_text_file(os.path.join(data_dir, "player_constants.inc"), lines)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)

    z01_path = os.path.join(project_root, "reference", "aldonunez", "Z_01.asm")
    z02_path = os.path.join(project_root, "reference", "aldonunez", "Z_02.asm")
    z05_path = os.path.join(project_root, "reference", "aldonunez", "Z_05.asm")
    rom_path = os.path.join(project_root, "Legend of Zelda, The (USA).nes")
    data_dir = os.path.join(project_root, "src", "data")

    for required_path in [z01_path, z02_path, z05_path, rom_path]:
        if not os.path.exists(required_path):
            print(f"ERROR: required file not found: {required_path}")
            sys.exit(1)

    os.makedirs(data_dir, exist_ok=True)

    print(f"Parsing reference data: {z01_path}")
    z01_blocks = parse_asm_data_blocks(z01_path, Z01_TARGET_LABELS)

    print(f"Parsing reference data: {z02_path}")
    z02_blocks = parse_asm_data_blocks(z02_path, Z02_PALETTE_LABELS)

    print(f"Parsing reference data: {z05_path}")
    z05_blocks = parse_asm_data_blocks(z05_path, Z05_TARGET_LABELS)
    link_speed_constants = extract_init_link_speed_constants(z05_path)
    prg_data = read_ines_prg(rom_path)
    person_text_data = extract_person_text(prg_data, z01_blocks)

    print("\nWriting misc data files...")
    write_item_tables(data_dir, z01_blocks)
    write_ui_layout(data_dir, z01_blocks, z05_blocks)
    write_palette_tables(data_dir, z01_blocks, z05_blocks)
    write_palettes_inc(data_dir, z01_blocks, z02_blocks)
    write_player_constants(data_dir, z01_blocks, link_speed_constants)
    write_person_text_file(data_dir, z01_blocks, person_text_data)

    total_bytes = 0
    total_bytes += sum(len(block["bytes"]) for block in z01_blocks.values())
    total_bytes += sum(len(block["bytes"]) for block in z02_blocks.values())
    total_bytes += sum(len(block["bytes"]) for block in z05_blocks.values())
    total_bytes += len(person_text_data["text_blob"])
    total_bytes += len(person_text_data["addresses"]) * 2

    print("\n=== Misc extraction complete ===")
    print(f"  Total extracted misc table bytes: {total_bytes}")
    print(f"  Output directory: {data_dir}")


if __name__ == "__main__":
    main()
