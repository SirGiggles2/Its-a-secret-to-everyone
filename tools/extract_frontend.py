#!/usr/bin/env python3
"""
extract_frontend.py - Extract frontend, save-menu, and ending text tables.

This fills one of the remaining Phase 1 gaps by pulling inline Z_02 menu and
ending data into Genesis include files:
  - file-select / register / elimination UI tables
  - save-slot helper address tables
  - ending text / flash / textbox metadata
"""

import os
import re
import sys

INES_HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000
BANK_CPU_BASE = 0x8000

LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):$")
VAR_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:=\s*\$([0-9A-Fa-f]+)$")
OFFSET_EXPR_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)([+-]\d+)?$")

Z02_TARGET_LABELS = {
    "TitlePaletteTransferRecord",
    "StoryPaletteTransferRecord",
    "TriforcePaletteTransferRecord",
    "TriforceGlowingColors",
    "DemoPhase0Subphase1Palettes",
    "ModeEandFSlotCursorYs",
    "ModeE_CharMap",
    "SlotToInitialNameCharTransferHeaders",
    "DeletedSlotBlankNameTransferBuf",
    "ModeEandFCursorSprites",
    "ModeE_CharBoardYOffsetsAndBounds",
    "ModeFTitleTransferBuf",
    "ModeFSaveSlotTemplatePatchRegister",
    "ModeFSaveSlotTemplateTransferBuf",
    "SlotToBlankNameTransferBufEndOffset",
    "SlotToNameOffset",
    "Mode1SlotLineTransferBuf",
    "Mode1DeathCountsTransferBuf",
    "LinkColors",
    "Mode1CursorSpriteTriplet",
    "Mode1CursorSpriteYs",
    "DemoLineAttrs",
    "SaveSlotHeartsAddrsLo",
    "SaveSlotHeartsAddrsHi",
    "ProfileNameAddrsLo",
    "ProfileNameAddrsHi",
    "PlayAreaAttr0TransferBuf",
    "ThanksText",
    "ThanksTextboxCharTransferRecTemplate",
    "ThanksTextboxLineAddrsLo",
    "EndingFlashColors",
    "PeaceTextboxCharTransferRecTemplate",
    "PeaceTextboxCharAddrsLo",
    "PeaceText",
    "CreditsLastScreenList",
    "CreditsLastVscrollList",
    "CreditLineVramAddrsHi",
    "CreditsPagesTextMasks",
    "CreditsAttrs",
}

Z06_TARGET_LABELS = {
    "Mode11PlayAreaAttrsBottomHalfTransferBuf",
}


def strip_comment(line):
    return line.split(";", 1)[0].strip()


def parse_byte_token(token):
    token = token.strip()
    if not token:
        raise ValueError("Empty token")
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


def parse_variables(path):
    symbols = {}
    with open(path, "r", encoding="utf-8") as f:
        for raw_line in f:
            line = strip_comment(raw_line)
            if not line:
                continue
            match = VAR_RE.match(line)
            if match:
                symbols[match.group(1)] = int(match.group(2), 16)
    return symbols


def eval_offset_expr(expr, symbols):
    match = OFFSET_EXPR_RE.match(expr.strip())
    if not match:
        raise ValueError(f"Unsupported byte expression: {expr}")
    name = match.group(1)
    offset_text = match.group(2)
    if name not in symbols:
        raise ValueError(f"Unknown symbol in expression: {expr}")
    value = symbols[name]
    if offset_text:
        value += int(offset_text, 10)
    return value


def parse_asm_data_blocks(path, target_labels, symbols):
    blocks = {}
    current = None

    with open(path, "r", encoding="utf-8") as f:
        for raw_line in f:
            line = strip_comment(raw_line)
            if not line:
                if current is not None and blocks[current]:
                    current = None
                continue

            match = LABEL_RE.match(line)
            if match:
                label = match.group(1)
                current = label if label in target_labels else None
                if current is not None and current not in blocks:
                    blocks[current] = bytearray()
                continue

            if current is None:
                continue

            if line.startswith(".BYTE"):
                items = [item.strip() for item in line[5:].split(",") if item.strip()]
                blocks[current].extend(parse_byte_token(item) for item in items)
            elif line.startswith(".LOBYTES"):
                expr = line[len(".LOBYTES") :].strip()
                value = eval_offset_expr(expr, symbols)
                blocks[current].append(value & 0xFF)
            elif line.startswith(".HIBYTES"):
                expr = line[len(".HIBYTES") :].strip()
                value = eval_offset_expr(expr, symbols)
                blocks[current].append((value >> 8) & 0xFF)

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


def parse_le_words(data):
    if len(data) & 1:
        raise ValueError("Word table has odd length")
    return [data[i] | (data[i + 1] << 8) for i in range(0, len(data), 2)]


def cpu_addr_to_bank_offset(cpu_addr):
    if cpu_addr < BANK_CPU_BASE or cpu_addr >= BANK_CPU_BASE + PRG_BANK_SIZE:
        raise ValueError(f"CPU address ${cpu_addr:04X} is outside bank range")
    return cpu_addr - BANK_CPU_BASE


def find_longest_pointer_run(bank_data, scan_end, lookback=0x100, min_count=8):
    best = None
    scan_start = max(0, scan_end - lookback)

    for start in range(scan_start, scan_end):
        pos = start
        addresses = []
        while pos + 1 < scan_end:
            addr = bank_data[pos] | (bank_data[pos + 1] << 8)
            try:
                offset = cpu_addr_to_bank_offset(addr)
            except ValueError:
                break
            if offset >= start:
                break
            addresses.append(addr)
            pos += 2

        if len(addresses) < min_count:
            continue

        candidate = {
            "start": start,
            "end": pos,
            "addresses": addresses,
        }
        if best is None or len(candidate["addresses"]) > len(best["addresses"]):
            best = candidate

    if best is None:
        raise ValueError("Could not locate a valid pointer table run")
    return best


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


def extract_demo_text_data(prg_data, blocks):
    bank2_data = prg_data[2 * PRG_BANK_SIZE : 3 * PRG_BANK_SIZE]
    title_palette = bytes(blocks["TitlePaletteTransferRecord"])
    title_palette_pos = find_unique_pattern(
        bank2_data, title_palette, "TitlePaletteTransferRecord in bank 2"
    )

    pointer_run = find_longest_pointer_run(bank2_data, title_palette_pos)
    addr_table_start = pointer_run["start"]
    addresses = pointer_run["addresses"]
    fields_start = min(cpu_addr_to_bank_offset(addr) for addr in addresses)
    fields_blob = bytes(bank2_data[fields_start:addr_table_start])

    return {
        "addresses": addresses,
        "fields_blob": fields_blob,
    }


def extract_credits_text_data(prg_data, blocks):
    bank2_data = prg_data[2 * PRG_BANK_SIZE : 3 * PRG_BANK_SIZE]
    credits_masks = bytes(blocks["CreditsPagesTextMasks"])
    credits_attrs = bytes(blocks["CreditsAttrs"])

    masks_pos = find_unique_pattern(
        bank2_data, credits_masks, "CreditsPagesTextMasks in bank 2"
    )
    attrs_pos = find_unique_pattern(bank2_data, credits_attrs, "CreditsAttrs in bank 2")

    credits_line_count = 0x17
    addrs_lo_start = masks_pos + len(credits_masks)
    addrs_hi_start = addrs_lo_start + credits_line_count
    text_lines_start = addrs_hi_start + credits_line_count

    addrs_lo = bank2_data[addrs_lo_start:addrs_hi_start]
    addrs_hi = bank2_data[addrs_hi_start:text_lines_start]
    addresses = [
        addrs_lo[index] | (addrs_hi[index] << 8) for index in range(credits_line_count)
    ]
    text_lines_blob = bytes(bank2_data[text_lines_start:attrs_pos])

    return {
        "addresses": addresses,
        "text_lines_blob": text_lines_blob,
    }


def parse_transfer_buf_end(data, start):
    """Parse NES PPU transfer buffer records to find the true $FF terminator.

    Record format:
      byte 0: PPU addr hi (>= $80 = terminator, buffer ends here)
      byte 1: PPU addr lo
      byte 2: control (bits 5:0 = count [0=64], bit 6 = inc mode, bit 7 = repeat)
      If repeat (bit 7): 1 data byte (repeated count times)
      If sequential: count data bytes
    """
    pos = start
    while pos < len(data):
        first = data[pos]
        if first >= 0x80:
            return pos  # terminator byte
        # Skip header (3 bytes)
        if pos + 2 >= len(data):
            raise ValueError(f"Transfer buf truncated at offset {pos}")
        control = data[pos + 2]
        count = control & 0x3F
        if count == 0:
            count = 64
        pos += 3  # past header
        if control & 0x80:
            pos += 1  # repeat mode: 1 data byte
        else:
            pos += count  # sequential: count data bytes
    raise ValueError(f"Transfer buf: no terminator found starting at {start}")


def extract_frontend_transfer_blobs(prg_data, z06_blocks):
    bank6_data = prg_data[6 * PRG_BANK_SIZE : 7 * PRG_BANK_SIZE]
    mode11_bottom = bytes(z06_blocks["Mode11PlayAreaAttrsBottomHalfTransferBuf"])
    marker_pos = find_unique_pattern(
        bank6_data,
        mode11_bottom,
        "Mode11PlayAreaAttrsBottomHalfTransferBuf in bank 6",
    )

    story_start = marker_pos + len(mode11_bottom)
    story_term = parse_transfer_buf_end(bank6_data, story_start)
    story_blob = bytes(bank6_data[story_start : story_term + 1])

    game_title_start = story_term + 1
    game_title_term = parse_transfer_buf_end(bank6_data, game_title_start)
    game_title_blob = bytes(bank6_data[game_title_start : game_title_term + 1])

    return {
        "story_tile_attr_transfer_buf": story_blob,
        "game_title_transfer_buf": game_title_blob,
    }


def data_to_inc_bytes(data, label, bytes_per_line=16):
    lines = [f"; {label} - {len(data)} bytes", f"{label}:"]
    for i in range(0, len(data), bytes_per_line):
        chunk = data[i : i + bytes_per_line]
        lines.append("    dc.b " + ",".join(f"${byte:02X}" for byte in chunk))
    return "\n".join(lines)


def write_text_file(path, lines):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"  Wrote {path}")


def write_frontend_ui(data_dir, blocks):
    ordered = [
        "ModeFTitleTransferBuf",
        "ModeFSaveSlotTemplatePatchRegister",
        "ModeFSaveSlotTemplateTransferBuf",
        "Mode1SlotLineTransferBuf",
        "Mode1DeathCountsTransferBuf",
        "LinkColors",
        "Mode1CursorSpriteTriplet",
        "Mode1CursorSpriteYs",
        "ModeEandFSlotCursorYs",
        "ModeEandFCursorSprites",
        "ModeE_CharMap",
        "ModeE_CharBoardYOffsetsAndBounds",
        "SlotToInitialNameCharTransferHeaders",
        "DeletedSlotBlankNameTransferBuf",
        "SlotToBlankNameTransferBufEndOffset",
        "SlotToNameOffset",
    ]
    lines = [
        "; Frontend and menu UI tables extracted from NES Zelda Z_02",
        "; Auto-generated by extract_frontend.py - DO NOT EDIT",
        "",
    ]
    for label in ordered:
        lines.append(data_to_inc_bytes(bytes(blocks[label]), label))
        lines.append("")
    write_text_file(os.path.join(data_dir, "frontend_ui.inc"), lines[:-1])


def write_frontend_palettes(data_dir, blocks):
    ordered = [
        "TitlePaletteTransferRecord",
        "StoryPaletteTransferRecord",
        "TriforcePaletteTransferRecord",
        "TriforceGlowingColors",
        "DemoPhase0Subphase1Palettes",
    ]
    lines = [
        "; Frontend palette and demo color tables extracted from NES Zelda Z_02",
        "; Auto-generated by extract_frontend.py - DO NOT EDIT",
        "",
    ]
    for label in ordered:
        lines.append(data_to_inc_bytes(bytes(blocks[label]), label))
        lines.append("")
    write_text_file(os.path.join(data_dir, "frontend_palettes.inc"), lines[:-1])


def write_save_tables(data_dir, blocks):
    ordered = [
        "SaveSlotHeartsAddrsLo",
        "SaveSlotHeartsAddrsHi",
        "ProfileNameAddrsLo",
        "ProfileNameAddrsHi",
    ]
    lines = [
        "; Save/profile helper tables extracted from NES Zelda Z_02",
        "; Auto-generated by extract_frontend.py - DO NOT EDIT",
        "",
    ]
    for label in ordered:
        lines.append(data_to_inc_bytes(bytes(blocks[label]), label))
        lines.append("")
    write_text_file(os.path.join(data_dir, "save_tables.inc"), lines[:-1])


def write_demo_text_file(data_dir, blocks, demo_text_data):
    labels_by_addr, table_labels, ordered_addrs = build_pointer_labels(
        demo_text_data["addresses"], "DemoTextField"
    )

    lines = [
        "; Demo/story text field blobs extracted from NES Zelda bank 2",
        "; Auto-generated by extract_frontend.py - DO NOT EDIT",
        "",
        data_to_inc_bytes(bytes(blocks["DemoLineAttrs"]), "DemoLineAttrs"),
        "",
        labels_to_inc_words(table_labels, "DemoLineTextAddrs"),
        "",
    ]

    write_labeled_records(lines, demo_text_data["fields_blob"], ordered_addrs, labels_by_addr)
    write_text_file(os.path.join(data_dir, "demo_text.inc"), lines[:-1])


def write_credits_text_file(data_dir, credits_text_data):
    labels_by_addr, table_labels, ordered_addrs = build_pointer_labels(
        credits_text_data["addresses"], "CreditsTextLine"
    )

    lines = [
        "; Credits text line blobs extracted from NES Zelda bank 2",
        "; Auto-generated by extract_frontend.py - DO NOT EDIT",
        "",
        labels_to_inc_words(table_labels, "CreditsTextAddrs"),
        "",
    ]

    write_labeled_records(
        lines,
        credits_text_data["text_lines_blob"],
        ordered_addrs,
        labels_by_addr,
    )
    write_text_file(os.path.join(data_dir, "credits_text.inc"), lines[:-1])


def write_frontend_transfers_file(data_dir, transfer_blobs):
    lines = [
        "; Frontend transfer buffers extracted from NES Zelda bank 6",
        "; Auto-generated by extract_frontend.py - DO NOT EDIT",
        "",
        data_to_inc_bytes(
            transfer_blobs["story_tile_attr_transfer_buf"],
            "StoryTileAttrTransferBuf",
        ),
        "",
        data_to_inc_bytes(
            transfer_blobs["game_title_transfer_buf"],
            "GameTitleTransferBuf",
        ),
    ]
    write_text_file(os.path.join(data_dir, "frontend_transfers.inc"), lines)


def write_raw_dat_files(ref_dat_dir, transfer_blobs):
    """Write raw binary .dat files so the transpiler's .INCBIN can find them."""
    os.makedirs(ref_dat_dir, exist_ok=True)
    for filename, key in [
        ("StoryTileAttrTransferBuf.dat", "story_tile_attr_transfer_buf"),
        ("GameTitleTransferBuf.dat", "game_title_transfer_buf"),
    ]:
        path = os.path.join(ref_dat_dir, filename)
        with open(path, "wb") as f:
            f.write(transfer_blobs[key])
        print(f"  Wrote {path} ({len(transfer_blobs[key])} bytes)")


def write_text_tables(data_dir, blocks):
    ordered = [
        "PlayAreaAttr0TransferBuf",
        "ThanksText",
        "ThanksTextboxCharTransferRecTemplate",
        "ThanksTextboxLineAddrsLo",
        "EndingFlashColors",
        "PeaceTextboxCharTransferRecTemplate",
        "PeaceTextboxCharAddrsLo",
        "PeaceText",
        "CreditsLastScreenList",
        "CreditsLastVscrollList",
        "CreditLineVramAddrsHi",
        "CreditsPagesTextMasks",
        "CreditsAttrs",
    ]
    lines = [
        "; Ending and credits text-support tables extracted from NES Zelda Z_02",
        "; Auto-generated by extract_frontend.py - DO NOT EDIT",
        "",
    ]
    for label in ordered:
        lines.append(data_to_inc_bytes(bytes(blocks[label]), label))
        lines.append("")
    write_text_file(os.path.join(data_dir, "text.inc"), lines[:-1])


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)

    z02_path = os.path.join(project_root, "reference", "aldonunez", "Z_02.asm")
    z06_path = os.path.join(project_root, "reference", "aldonunez", "Z_06.asm")
    vars_path = os.path.join(project_root, "reference", "aldonunez", "Variables.inc")
    rom_path = os.path.join(project_root, "Legend of Zelda, The (USA).nes")
    data_dir = os.path.join(project_root, "src", "data")

    for required_path in [z02_path, z06_path, vars_path, rom_path]:
        if not os.path.exists(required_path):
            print(f"ERROR: required file not found: {required_path}")
            sys.exit(1)

    os.makedirs(data_dir, exist_ok=True)

    print(f"Parsing variables: {vars_path}")
    symbols = parse_variables(vars_path)

    print(f"Parsing reference data: {z02_path}")
    blocks = parse_asm_data_blocks(z02_path, Z02_TARGET_LABELS, symbols)
    z06_blocks = parse_asm_data_blocks(z06_path, Z06_TARGET_LABELS, {})
    prg_data = read_ines_prg(rom_path)
    demo_text_data = extract_demo_text_data(prg_data, blocks)
    credits_text_data = extract_credits_text_data(prg_data, blocks)
    frontend_transfer_blobs = extract_frontend_transfer_blobs(prg_data, z06_blocks)

    print("\nWriting frontend data files...")
    write_frontend_ui(data_dir, blocks)
    write_frontend_palettes(data_dir, blocks)
    write_save_tables(data_dir, blocks)
    write_text_tables(data_dir, blocks)
    write_demo_text_file(data_dir, blocks, demo_text_data)
    write_credits_text_file(data_dir, credits_text_data)
    write_frontend_transfers_file(data_dir, frontend_transfer_blobs)
    ref_dat_dir = os.path.join(project_root, "reference", "aldonunez", "dat")
    write_raw_dat_files(ref_dat_dir, frontend_transfer_blobs)

    total_bytes = sum(len(block) for block in blocks.values())
    total_bytes += len(demo_text_data["fields_blob"])
    total_bytes += len(demo_text_data["addresses"]) * 2
    total_bytes += len(credits_text_data["text_lines_blob"])
    total_bytes += len(credits_text_data["addresses"]) * 2
    total_bytes += len(frontend_transfer_blobs["story_tile_attr_transfer_buf"])
    total_bytes += len(frontend_transfer_blobs["game_title_transfer_buf"])
    print("\n=== Frontend extraction complete ===")
    print(f"  Total extracted frontend/text table bytes: {total_bytes}")
    print(f"  Output directory: {data_dir}")


if __name__ == "__main__":
    main()
