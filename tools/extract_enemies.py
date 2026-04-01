#!/usr/bin/env python3
"""
extract_enemies.py - Extract enemy/object dispatch and drop tables.

This stage pulls the NES game's object-type metadata out of Z_04/Z_07 and
emits Genesis-friendly include files:
  - enemy_tables.inc: object attributes, HP, and behavior-dispatch IDs
  - drop_tables.inc: monster drop grouping/rates/table data

The behavior tables are emitted as local numeric IDs rather than raw NES
routine pointers so the Genesis engine can switch on compact self-contained
tables without needing unresolved 6502 labels.
"""

import os
import re
import sys

INES_HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000
BANK_CPU_BASE = 0x8000

LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):$")

Z07_TARGET_LABELS = {
    "SpecialBossPaletteObjTypes",
    "ObjectTypeToAttributes",
    "ObjectTypeToHpPairs",
    "UpdateObject_JumpTable",
    "InitObject_JumpTable",
}

Z04_TARGET_LABELS = {
    "NoDropMonsterTypes",
    "DropItemMonsterTypes0",
    "DropItemMonsterTypes1",
    "DropItemMonsterTypes2",
    "DropItemSetBaseOffsets",
    "DropItemRates",
    "DropItemTable",
}

Z05_TARGET_LABELS = {
    "EnteringRoomRelativePositions",
}

INITMODE4_SIGNATURE = bytes([0xA6, 0x13, 0xF0, 0x47, 0xCA])


def strip_comment(line):
    return line.split(";", 1)[0].strip()


def parse_byte_token(token):
    token = token.strip()
    if not token:
        raise ValueError("Empty .BYTE token")
    if token.startswith("$"):
        return int(token[1:], 16)
    return int(token, 10)


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
                if current is not None:
                    block = blocks[current]
                    if block["bytes"] or block["addr_labels"]:
                        current = None
                continue

            match = LABEL_RE.match(line)
            if match:
                label = match.group(1)
                current = label if label in target_labels else None
                if current is not None and current not in blocks:
                    blocks[current] = {"bytes": bytearray(), "addr_labels": []}
                continue

            if current is None:
                continue

            if line.startswith(".BYTE"):
                items = [item.strip() for item in line[5:].split(",") if item.strip()]
                blocks[current]["bytes"].extend(parse_byte_token(item) for item in items)
            elif line.startswith(".ADDR"):
                items = [item.strip() for item in line[5:].split(",") if item.strip()]
                blocks[current]["addr_labels"].extend(items)

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


def cpu_addr_to_bank_offset(cpu_addr):
    if cpu_addr < BANK_CPU_BASE or cpu_addr >= BANK_CPU_BASE + PRG_BANK_SIZE:
        raise ValueError(f"CPU address ${cpu_addr:04X} is outside bank range")
    return cpu_addr - BANK_CPU_BASE


def parse_le_words(data):
    if len(data) & 1:
        raise ValueError("Word table has odd length")
    return [data[i] | (data[i + 1] << 8) for i in range(0, len(data), 2)]


def find_pointer_table_start(bank_data, table_end, minimum_offset):
    start = table_end
    previous = None
    while start - 2 >= minimum_offset:
        word = bank_data[start - 2] | (bank_data[start - 1] << 8)
        if word < BANK_CPU_BASE or word >= BANK_CPU_BASE + PRG_BANK_SIZE:
            break
        offset = cpu_addr_to_bank_offset(word)
        if offset < minimum_offset or offset >= start - 2:
            break
        if previous is not None and word > previous:
            break
        previous = word
        start -= 2
    if start == table_end:
        raise ValueError("Could not locate object list pointer table")
    return start


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


def write_labeled_records(lines, blob, ordered_addrs, labels_by_addr, label_prefix):
    offsets = [cpu_addr_to_bank_offset(addr) for addr in ordered_addrs]
    for index, addr in enumerate(ordered_addrs):
        start = offsets[index] - cpu_addr_to_bank_offset(ordered_addrs[0])
        if index + 1 < len(offsets):
            end = offsets[index + 1] - cpu_addr_to_bank_offset(ordered_addrs[0])
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


def extract_object_lists(prg_data, z05_blocks):
    bank5_data = prg_data[5 * PRG_BANK_SIZE : 6 * PRG_BANK_SIZE]
    entering_positions = bytes(z05_blocks["EnteringRoomRelativePositions"]["bytes"])
    marker_pos = find_unique_pattern(
        bank5_data, entering_positions, "EnteringRoomRelativePositions in bank 5"
    )
    obj_lists_start = marker_pos + len(entering_positions)

    init_mode4_pos = find_unique_pattern(
        bank5_data[ obj_lists_start : ],
        INITMODE4_SIGNATURE,
        "InitMode4 signature in bank 5",
    ) + obj_lists_start

    obj_list_addrs_start = find_pointer_table_start(
        bank5_data, init_mode4_pos, obj_lists_start
    )

    return {
        "obj_lists": bytes(bank5_data[obj_lists_start:obj_list_addrs_start]),
        "obj_list_addrs": parse_le_words(bank5_data[obj_list_addrs_start:init_mode4_pos]),
    }


def ordered_unique(items):
    result = []
    seen = set()
    for item in items:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result


def unpack_hp_pairs(hp_pairs, object_count):
    unpacked = []
    for obj_type in range(object_count):
        pair_value = hp_pairs[obj_type // 2]
        if obj_type & 1:
            unpacked.append((pair_value & 0x0F) << 4)
        else:
            unpacked.append(pair_value & 0xF0)
    return bytes(unpacked)


def data_to_inc_bytes(data, label, bytes_per_line=16):
    lines = [f"; {label} - {len(data)} bytes", f"{label}:"]
    for i in range(0, len(data), bytes_per_line):
        chunk = data[i : i + bytes_per_line]
        lines.append("    dc.b " + ",".join(f"${byte:02X}" for byte in chunk))
    return "\n".join(lines)


def enum_table_to_inc(enum_prefix, ids_label, handler_labels, table_entries, bytes_per_line=8):
    lines = [f"; {ids_label}"]
    for index, handler in enumerate(handler_labels):
        lines.append(f"{enum_prefix}{handler} equ {index}")
    lines.append("")
    lines.append(f"{ids_label}:")
    for i in range(0, len(table_entries), bytes_per_line):
        chunk = table_entries[i : i + bytes_per_line]
        lines.append(
            "    dc.b " + ",".join(f"{enum_prefix}{handler}" for handler in chunk)
        )
    return "\n".join(lines)


def write_text_file(path, lines):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"  Wrote {path}")


def write_enemy_tables(data_dir, z07_blocks):
    attrs = bytes(z07_blocks["ObjectTypeToAttributes"]["bytes"])
    hp_pairs = bytes(z07_blocks["ObjectTypeToHpPairs"]["bytes"])
    update_handlers = z07_blocks["UpdateObject_JumpTable"]["addr_labels"]
    init_handlers = z07_blocks["InitObject_JumpTable"]["addr_labels"]
    boss_palette_types = bytes(z07_blocks["SpecialBossPaletteObjTypes"]["bytes"])

    init_object_count = len(init_handlers)
    update_object_count = len(update_handlers)
    hp_object_count = len(hp_pairs) * 2

    if len(attrs) != init_object_count:
        raise ValueError("Attribute table length does not match init table length")

    unpacked_hp = unpack_hp_pairs(hp_pairs, hp_object_count)
    unique_init = ordered_unique(init_handlers)
    unique_update = ordered_unique(update_handlers)

    lines = [
        "; Enemy/object metadata extracted from NES Zelda",
        "; Auto-generated by extract_enemies.py - DO NOT EDIT",
        "; These tables intentionally have different ranges in the NES code:",
        "; - HP pairs cover the subset of object types that use packed HP values",
        "; - Attr/init tables cover normal initialized object types",
        "; - Update table extends through item/tile-object updater entries",
        "",
        f"ObjectTypeCount_Hp equ {hp_object_count}",
        f"ObjectTypeCount_Init equ {init_object_count}",
        f"ObjectTypeCount_Update equ {update_object_count}",
        "",
        data_to_inc_bytes(attrs, "ObjectTypeToAttributes"),
        "",
        data_to_inc_bytes(hp_pairs, "ObjectTypeToHpPairs"),
        "",
        data_to_inc_bytes(unpacked_hp, "ObjectTypeToHP"),
        "",
        data_to_inc_bytes(boss_palette_types, "SpecialBossPaletteObjTypes"),
        "",
        enum_table_to_inc(
            "EnemyInitHandler_",
            "ObjectTypeToInitHandlerId",
            unique_init,
            init_handlers,
        ),
        "",
        enum_table_to_inc(
            "EnemyUpdateHandler_",
            "ObjectTypeToUpdateHandlerId",
            unique_update,
            update_handlers,
        ),
    ]

    write_text_file(os.path.join(data_dir, "enemy_tables.inc"), lines)


def write_drop_tables(data_dir, z04_blocks):
    lines = [
        "; Monster drop tables extracted from NES Zelda",
        "; Auto-generated by extract_enemies.py - DO NOT EDIT",
        "",
        data_to_inc_bytes(bytes(z04_blocks["NoDropMonsterTypes"]["bytes"]), "NoDropMonsterTypes"),
        "",
        data_to_inc_bytes(
            bytes(z04_blocks["DropItemMonsterTypes0"]["bytes"]),
            "DropItemMonsterTypes0",
        ),
        "",
        data_to_inc_bytes(
            bytes(z04_blocks["DropItemMonsterTypes1"]["bytes"]),
            "DropItemMonsterTypes1",
        ),
        "",
        data_to_inc_bytes(
            bytes(z04_blocks["DropItemMonsterTypes2"]["bytes"]),
            "DropItemMonsterTypes2",
        ),
        "",
        data_to_inc_bytes(
            bytes(z04_blocks["DropItemSetBaseOffsets"]["bytes"]),
            "DropItemSetBaseOffsets",
        ),
        "",
        data_to_inc_bytes(bytes(z04_blocks["DropItemRates"]["bytes"]), "DropItemRates"),
        "",
        data_to_inc_bytes(bytes(z04_blocks["DropItemTable"]["bytes"]), "DropItemTable"),
    ]

    write_text_file(os.path.join(data_dir, "drop_tables.inc"), lines)


def write_object_lists_file(data_dir, object_list_data):
    labels_by_addr, table_labels, ordered_addrs = build_pointer_labels(
        object_list_data["obj_list_addrs"], "ObjList"
    )

    lines = [
        "; Room object list templates extracted from NES Zelda bank 5",
        "; Auto-generated by extract_enemies.py - DO NOT EDIT",
        "",
        labels_to_inc_words(table_labels, "ObjListAddrs"),
        "",
    ]

    write_labeled_records(
        lines,
        object_list_data["obj_lists"],
        ordered_addrs,
        labels_by_addr,
        "ObjList",
    )

    write_text_file(os.path.join(data_dir, "object_lists.inc"), lines[:-1])


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)

    z04_path = os.path.join(project_root, "reference", "aldonunez", "Z_04.asm")
    z05_path = os.path.join(project_root, "reference", "aldonunez", "Z_05.asm")
    z07_path = os.path.join(project_root, "reference", "aldonunez", "Z_07.asm")
    rom_path = os.path.join(project_root, "Legend of Zelda, The (USA).nes")
    data_dir = os.path.join(project_root, "src", "data")

    for required_path in [z04_path, z05_path, z07_path, rom_path]:
        if not os.path.exists(required_path):
            print(f"ERROR: required file not found: {required_path}")
            sys.exit(1)

    os.makedirs(data_dir, exist_ok=True)

    print(f"Parsing reference data: {z04_path}")
    z04_blocks = parse_asm_data_blocks(z04_path, Z04_TARGET_LABELS)

    print(f"Parsing reference data: {z05_path}")
    z05_blocks = parse_asm_data_blocks(z05_path, Z05_TARGET_LABELS)

    print(f"Parsing reference data: {z07_path}")
    z07_blocks = parse_asm_data_blocks(z07_path, Z07_TARGET_LABELS)
    prg_data = read_ines_prg(rom_path)
    object_list_data = extract_object_lists(prg_data, z05_blocks)

    print("\nWriting enemy/object data files...")
    write_enemy_tables(data_dir, z07_blocks)
    write_drop_tables(data_dir, z04_blocks)
    write_object_lists_file(data_dir, object_list_data)

    total_bytes = 0
    total_bytes += len(z07_blocks["ObjectTypeToAttributes"]["bytes"])
    total_bytes += len(z07_blocks["ObjectTypeToHpPairs"]["bytes"])
    total_bytes += len(z07_blocks["SpecialBossPaletteObjTypes"]["bytes"])
    total_bytes += len(z07_blocks["UpdateObject_JumpTable"]["addr_labels"])
    total_bytes += len(z07_blocks["InitObject_JumpTable"]["addr_labels"])
    total_bytes += sum(len(z04_blocks[label]["bytes"]) for label in Z04_TARGET_LABELS)
    total_bytes += len(object_list_data["obj_lists"])
    total_bytes += len(object_list_data["obj_list_addrs"]) * 2

    print("\n=== Enemy extraction complete ===")
    print(f"  Total extracted enemy/drop table bytes: {total_bytes}")
    print(f"  Output directory: {data_dir}")


if __name__ == "__main__":
    main()
