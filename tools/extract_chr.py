#!/usr/bin/env python3
"""
extract_chr.py - Extract and convert NES Zelda 1 tile data to Genesis format.

Reads the NES ROM and extracts all pattern block data, converting from
NES 2bpp (16 bytes/tile) to Genesis 4bpp (32 bytes/tile).

NES tile format (2bpp, 8x8):
  Bytes 0-7:  Bit plane 0 (one byte per row)
  Bytes 8-15: Bit plane 1 (one byte per row)
  Each pixel = 2 bits (plane1:plane0), values 0-3

Genesis tile format (4bpp, 8x8):
  32 bytes per tile, 4 bytes per row
  Each byte = 2 pixels (high nibble = left, low nibble = right)
  Each pixel = 4 bits, but we only use the low 2 for NES-sourced tiles

Output: vasm-compatible .inc files with dc.w statements.

Primary Phase 1 compatibility outputs:
  - tiles_overworld_bg.inc
  - tiles_underworld_bg.inc
  - tiles_sprites.inc

Legacy grouped outputs are still emitted as convenience bundles:
  - tiles_overworld.inc
  - tiles_underworld.inc
  - tiles_bosses.inc
  - tiles_common.inc
  - tiles_demo.inc
"""

import struct
import sys
import os

# iNES header constants
INES_HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000  # 16 KB

# Pattern block sizes (from Z_03.asm)
PATTERN_BLOCKS = {
    # Bank 3 blocks (level patterns) - order matches INCBIN order in Z_03.asm
    'PatternBlockUWBG':         0x0820,  # Underworld background
    'PatternBlockOWBG':         0x0820,  # Overworld background
    'PatternBlockOWSP':         0x0720,  # Overworld sprites
    'PatternBlockUWSP358':      0x0220,  # Underworld sprites levels 3,5,8
    'PatternBlockUWSP469':      0x0220,  # Underworld sprites levels 4,6,9
    'PatternBlockUWSP':         0x0100,  # Underworld base sprites
    'PatternBlockUWSP127':      0x0220,  # Underworld sprites levels 1,2,7
    'PatternBlockUWSPBoss1257': 0x0400,  # Boss sprites levels 1,2,5,7
    'PatternBlockUWSPBoss3468': 0x0400,  # Boss sprites levels 3,4,6,8
    'PatternBlockUWSPBoss9':    0x0400,  # Boss sprites level 9
}

# Bank 1 blocks (demo/title patterns) - from Z_01.asm
DEMO_BLOCKS = {
    'DemoSpritePatterns':     0x0900,
    'DemoBackgroundPatterns': 0x0820,
}

# Bank 2 blocks (common patterns) - from Z_02.asm
COMMON_BLOCKS = {
    'CommonSpritePatterns':     0x0700,
    'CommonBackgroundPatterns': 0x0700,
    'CommonMiscPatterns':       0x00E0,
}

# Z_02.asm places an explicit 161-byte $FF padding block immediately after
# CommonMiscPatterns and before the following code block. We use that run as
# the bank-2 anchor instead of trying to infer the pattern data from the ISR.
COMMON_POST_PADDING_BYTES = 0x00A1

# Known byte signature at start of BANK_03_ISR (reset vector code)
BANK3_ISR_SIGNATURE = bytes([0x78, 0xD8, 0xA9, 0x00, 0x8D, 0x00, 0x20, 0xA2,
                              0xFF, 0x9A, 0xAD, 0x02, 0x20])

# Zelda 1's bank-3 pattern data is not packed flush against BANK_03_ISR.
# The actual verified seam for the USA PRG-ROM is bank-3 offset $011B:
#   PatternBlockUWBG      $011B-$093A
#   PatternBlockOWBG      $093B-$115A
#   PatternBlockOWSP      $115B-$187A
#   PatternBlockUWSP358   $187B-$1A9A
#   PatternBlockUWSP469   $1A9B-$1CBA
#   PatternBlockUWSP      $1CBB-$1DBA
#   PatternBlockUWSP127   $1DBB-$1FDA
#   PatternBlockUWSPBoss1257 $1FDB-$23DA
#   PatternBlockUWSPBoss3468 $23DB-$27DA
#   PatternBlockUWSPBoss9    $27DB-$2BDA
#
# This seam was proven by matching the live NES CHR-RAM dump for the real
# room-$77 start screen against PRG-ROM bytes. The old ISR-backtracking
# heuristic landed $138F bytes too late and produced "close but wrong" OW art.
BANK3_PATTERN_DATA_START = 0x011B


def read_ines_rom(path):
    """Read an iNES ROM and return PRG-ROM data with header info."""
    with open(path, 'rb') as f:
        header = f.read(INES_HEADER_SIZE)

    if header[:4] != b'NES\x1a':
        raise ValueError(f"Not a valid iNES ROM: {path}")

    prg_banks = header[4]
    chr_banks = header[5]
    flags6 = header[6]
    mapper = (flags6 >> 4) | (header[7] & 0xF0)

    print(f"  iNES header:")
    print(f"    PRG-ROM: {prg_banks} x 16KB = {prg_banks * 16}KB")
    print(f"    CHR-ROM: {chr_banks} x 8KB = {chr_banks * 8}KB")
    print(f"    Mapper:  {mapper} ({'MMC1' if mapper == 1 else 'unknown'})")

    with open(path, 'rb') as f:
        f.seek(INES_HEADER_SIZE)
        prg_data = f.read(prg_banks * PRG_BANK_SIZE)

    return prg_data, prg_banks


def find_bank3_pattern_data(prg_data):
    """Find the start of pattern block data in bank 3."""
    bank3_offset = 3 * PRG_BANK_SIZE
    bank3_data = prg_data[bank3_offset:bank3_offset + PRG_BANK_SIZE]

    # BANK_03_ISR is still useful as a sanity-check, but the pattern block data
    # is not adjacent to it in the retail ROM.
    isr_pos = bank3_data.find(BANK3_ISR_SIGNATURE)
    if isr_pos < 0:
        raise ValueError("Could not find BANK_03_ISR signature in bank 3")

    print(f"  Found BANK_03_ISR at bank 3 offset ${isr_pos:04X} (ROM ${bank3_offset + isr_pos:05X})")
    total_data_size = sum(PATTERN_BLOCKS.values())
    data_start = BANK3_PATTERN_DATA_START
    data_end = data_start + total_data_size
    if data_end > isr_pos:
        raise ValueError(
            f"Verified bank-3 pattern seam ${data_start:04X}-${data_end - 1:04X} overlaps ISR at ${isr_pos:04X}"
        )

    print(f"  Total bank 3 pattern data: ${total_data_size:04X} ({total_data_size} bytes)")
    print(f"  Using verified bank 3 pattern-data seam at offset ${data_start:04X}")

    blocks = {}
    offset = data_start
    for name in [
        'PatternBlockUWBG',
        'PatternBlockOWBG',
        'PatternBlockOWSP',
        'PatternBlockUWSP358',
        'PatternBlockUWSP469',
        'PatternBlockUWSP',
        'PatternBlockUWSP127',
        'PatternBlockUWSPBoss1257',
        'PatternBlockUWSPBoss3468',
        'PatternBlockUWSPBoss9',
    ]:
        size = PATTERN_BLOCKS[name]
        rom_offset = bank3_offset + offset
        blocks[name] = prg_data[rom_offset:rom_offset + size]
        print(f"    {name}: ROM ${rom_offset:05X}, {size} bytes, {size // 16} tiles")
        offset += size

    return blocks


def find_demo_pattern_data(prg_data):
    """Find demo/title pattern data in bank 1."""
    # Demo patterns are at the end of bank 1's data section
    # We need to search for them by finding the INCBIN data
    # For now, search for known patterns near the end of bank 1
    bank1_offset = 1 * PRG_BANK_SIZE
    bank1_data = prg_data[bank1_offset:bank1_offset + PRG_BANK_SIZE]

    # Search for the ISR signature in bank 1 (same reset code appears in each bank's ISR)
    isr_pos = bank1_data.find(BANK3_ISR_SIGNATURE)
    if isr_pos < 0:
        print("  WARNING: Could not find ISR signature in bank 1, using end-of-bank heuristic")
        # Pattern data is typically before the ISR vectors at end of bank
        # Bank vectors are at $FFFA-$FFFF relative to bank start = last 6 bytes
        isr_pos = PRG_BANK_SIZE - 84  # Approximate ISR start (78 bytes code + 6 bytes vectors)

    total_size = sum(DEMO_BLOCKS.values())
    data_start = isr_pos - total_size

    blocks = {}
    offset = data_start
    for name, size in DEMO_BLOCKS.items():
        rom_offset = bank1_offset + offset
        blocks[name] = prg_data[rom_offset:rom_offset + size]
        print(f"    {name}: ROM ${rom_offset:05X}, {size} bytes, {size // 16} tiles")
        offset += size

    return blocks


def find_common_pattern_data(prg_data):
    """Find common pattern data in bank 2."""
    bank2_offset = 2 * PRG_BANK_SIZE
    bank2_data = prg_data[bank2_offset:bank2_offset + PRG_BANK_SIZE]
    total_size = sum(COMMON_BLOCKS.values())
    padding_run = b'\xFF' * COMMON_POST_PADDING_BYTES
    data_start = None
    search_pos = 0
    while True:
        run_pos = bank2_data.find(padding_run, search_pos)
        if run_pos < 0:
            break
        candidate_start = run_pos - total_size
        candidate_end = run_pos + COMMON_POST_PADDING_BYTES
        if candidate_start >= 0 and candidate_end < len(bank2_data) and bank2_data[candidate_end] != 0xFF:
            data_start = candidate_start
            print(f"  Found bank 2 common-pattern padding at offset ${run_pos:04X}; data starts at ${candidate_start:04X}")
            break
        search_pos = run_pos + 1

    if data_start is None:
        raise ValueError("Could not locate bank 2 common pattern data from the post-data FF padding run")

    blocks = {}
    offset = data_start
    for name, size in COMMON_BLOCKS.items():
        rom_offset = bank2_offset + offset
        blocks[name] = prg_data[rom_offset:rom_offset + size]
        print(f"    {name}: ROM ${rom_offset:05X}, {size} bytes, {size // 16} tiles")
        offset += size

    return blocks


def nes_tile_to_genesis(nes_tile_data):
    """Convert a single NES 2bpp tile (16 bytes) to Genesis 4bpp tile (32 bytes).

    NES 2bpp format:
      Bytes 0-7:  bit plane 0 (MSB = leftmost pixel)
      Bytes 8-15: bit plane 1

    Genesis 4bpp format:
      4 bytes per row, 8 rows = 32 bytes
      Each byte = 2 pixels: high nibble = left pixel, low nibble = right pixel
    """
    genesis_tile = bytearray(32)

    for row in range(8):
        plane0 = nes_tile_data[row]
        plane1 = nes_tile_data[row + 8]

        # Convert 8 pixels for this row
        for px in range(8):
            bit_pos = 7 - px  # MSB = leftmost pixel
            bit0 = (plane0 >> bit_pos) & 1
            bit1 = (plane1 >> bit_pos) & 1
            pixel_val = (bit1 << 1) | bit0  # 2-bit color value (0-3)

            # Pack into Genesis format: 2 pixels per byte, high nibble first
            byte_idx = row * 4 + (px // 2)
            if px % 2 == 0:
                genesis_tile[byte_idx] |= (pixel_val << 4)
            else:
                genesis_tile[byte_idx] |= pixel_val

    return bytes(genesis_tile)


def convert_pattern_block(nes_data):
    """Convert an entire pattern block from NES 2bpp to Genesis 4bpp."""
    num_tiles = len(nes_data) // 16
    genesis_data = bytearray()
    for i in range(num_tiles):
        nes_tile = nes_data[i * 16:(i + 1) * 16]
        genesis_data.extend(nes_tile_to_genesis(nes_tile))
    return bytes(genesis_data)


def genesis_data_to_inc(genesis_data, label):
    """Convert Genesis tile data to a vasm-compatible .inc file with dc.w statements."""
    lines = [f"; {label} - {len(genesis_data)} bytes, {len(genesis_data) // 32} tiles"]
    lines.append(f"{label}:")

    for tile_idx in range(len(genesis_data) // 32):
        tile_start = tile_idx * 32
        lines.append(f"; tile {tile_idx}")
        for row in range(8):
            row_start = tile_start + row * 4
            word1 = (genesis_data[row_start] << 8) | genesis_data[row_start + 1]
            word2 = (genesis_data[row_start + 2] << 8) | genesis_data[row_start + 3]
            lines.append(f"    dc.w ${word1:04X},${word2:04X}")

    return '\n'.join(lines)


def write_inc_file(path, blocks_data, header_comment):
    """Write a .inc file containing multiple converted pattern blocks."""
    lines = [
        f"; {header_comment}",
        f"; Auto-generated by extract_chr.py - DO NOT EDIT",
        f"; NES 2bpp tiles converted to Genesis 4bpp format",
        "",
    ]

    for label, genesis_data in blocks_data:
        lines.append(genesis_data_to_inc(genesis_data, label))
        lines.append("")

    with open(path, 'w') as f:
        f.write('\n'.join(lines))

    total_bytes = sum(len(d) for _, d in blocks_data)
    total_tiles = total_bytes // 32
    print(f"  Wrote {path} ({total_bytes} bytes, {total_tiles} tiles)")


def main():
    # Find the project root
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)

    rom_path = os.path.join(project_root, "Legend of Zelda, The (USA).nes")
    data_dir = os.path.join(project_root, "src", "data")

    if not os.path.exists(rom_path):
        print(f"ERROR: NES ROM not found: {rom_path}")
        sys.exit(1)

    os.makedirs(data_dir, exist_ok=True)

    print(f"Reading NES ROM: {rom_path}")
    prg_data, prg_banks = read_ines_rom(rom_path)

    # === Extract bank 3 pattern blocks (level-specific tiles) ===
    print("\nExtracting bank 3 pattern blocks (level tiles)...")
    bank3_blocks = find_bank3_pattern_data(prg_data)

    # Convert and write overworld tiles
    ow_blocks = [
        ("TilesOverworldBG", convert_pattern_block(bank3_blocks['PatternBlockOWBG'])),
        ("TilesOverworldSP", convert_pattern_block(bank3_blocks['PatternBlockOWSP'])),
    ]
    write_inc_file(
        os.path.join(data_dir, "tiles_overworld.inc"),
        ow_blocks,
        "Overworld tile data (background + sprites)"
    )
    write_inc_file(
        os.path.join(data_dir, "tiles_overworld_bg.inc"),
        [("TilesOverworldBG", ow_blocks[0][1])],
        "Overworld background tile data"
    )

    # Convert and write underworld tiles
    uw_blocks = [
        ("TilesUnderworldBG", convert_pattern_block(bank3_blocks['PatternBlockUWBG'])),
        ("TilesUnderworldSP", convert_pattern_block(bank3_blocks['PatternBlockUWSP'])),
        ("TilesUnderworldSP127", convert_pattern_block(bank3_blocks['PatternBlockUWSP127'])),
        ("TilesUnderworldSP358", convert_pattern_block(bank3_blocks['PatternBlockUWSP358'])),
        ("TilesUnderworldSP469", convert_pattern_block(bank3_blocks['PatternBlockUWSP469'])),
    ]
    write_inc_file(
        os.path.join(data_dir, "tiles_underworld.inc"),
        uw_blocks,
        "Underworld tile data (background + sprite variants)"
    )
    write_inc_file(
        os.path.join(data_dir, "tiles_underworld_bg.inc"),
        [("TilesUnderworldBG", uw_blocks[0][1])],
        "Underworld background tile data"
    )

    # Convert and write boss tiles
    boss_blocks = [
        ("TilesBoss1257", convert_pattern_block(bank3_blocks['PatternBlockUWSPBoss1257'])),
        ("TilesBoss3468", convert_pattern_block(bank3_blocks['PatternBlockUWSPBoss3468'])),
        ("TilesBoss9", convert_pattern_block(bank3_blocks['PatternBlockUWSPBoss9'])),
    ]
    write_inc_file(
        os.path.join(data_dir, "tiles_bosses.inc"),
        boss_blocks,
        "Boss sprite tile data"
    )

    # === Extract bank 2 pattern blocks (common tiles) ===
    print("\nExtracting bank 2 pattern blocks (common tiles)...")
    common_blocks = find_common_pattern_data(prg_data)

    common_converted = [
        ("TilesCommonSprites", convert_pattern_block(common_blocks['CommonSpritePatterns'])),
        ("TilesCommonBG", convert_pattern_block(common_blocks['CommonBackgroundPatterns'])),
        ("TilesCommonMisc", convert_pattern_block(common_blocks['CommonMiscPatterns'])),
    ]
    write_inc_file(
        os.path.join(data_dir, "tiles_common.inc"),
        common_converted,
        "Common tile data (always loaded)"
    )

    # === Extract bank 1 pattern blocks (demo/title tiles) ===
    print("\nExtracting bank 1 pattern blocks (demo/title tiles)...")
    demo_blocks = find_demo_pattern_data(prg_data)

    demo_converted = [
        ("TilesDemoSprites", convert_pattern_block(demo_blocks['DemoSpritePatterns'])),
        ("TilesDemoBG", convert_pattern_block(demo_blocks['DemoBackgroundPatterns'])),
    ]
    write_inc_file(
        os.path.join(data_dir, "tiles_demo.inc"),
        demo_converted,
        "Demo/title screen tile data"
    )

    sprite_bundle = [
        ("TilesCommonSprites", common_converted[0][1]),
        ("TilesCommonBG", common_converted[1][1]),
        ("TilesCommonMisc", common_converted[2][1]),
        ("TilesOverworldSP", ow_blocks[1][1]),
        ("TilesUnderworldSP", uw_blocks[1][1]),
        ("TilesUnderworldSP127", uw_blocks[2][1]),
        ("TilesUnderworldSP358", uw_blocks[3][1]),
        ("TilesUnderworldSP469", uw_blocks[4][1]),
        ("TilesBoss1257", boss_blocks[0][1]),
        ("TilesBoss3468", boss_blocks[1][1]),
        ("TilesBoss9", boss_blocks[2][1]),
        ("TilesDemoSprites", demo_converted[0][1]),
        ("TilesDemoBG", demo_converted[1][1]),
    ]
    write_inc_file(
        os.path.join(data_dir, "tiles_sprites.inc"),
        sprite_bundle,
        "Sprite, UI, common, and title tile data"
    )

    # === Summary ===
    all_nes_bytes = sum(len(b) for b in bank3_blocks.values())
    all_nes_bytes += sum(len(b) for b in common_blocks.values())
    all_nes_bytes += sum(len(b) for b in demo_blocks.values())
    total_tiles = all_nes_bytes // 16

    print(f"\n=== Extraction complete ===")
    print(f"  Total NES tile data: {all_nes_bytes} bytes ({total_tiles} tiles)")
    print(f"  Total Genesis tile data: {total_tiles * 32} bytes (2x NES size due to 4bpp)")
    print(f"  Output directory: {data_dir}")


if __name__ == '__main__':
    main()
