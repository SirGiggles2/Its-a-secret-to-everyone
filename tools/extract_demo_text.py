#!/usr/bin/env python3
"""
Extract DemoTextFields and DemoLineTextAddrs from the NES Zelda 1 ROM.

The NES ROM layout (iNES):
  - 16-byte header
  - 8 PRG banks of $4000 (16KB) each
  - 0 CHR banks (CHR-RAM)

Z_02.asm is PRG bank 2 (swappable bank, mapped at $8000-$BFFF).
Bank 2 file offset = 16 + 2*$4000 = $8010.

We locate the data by pattern-matching the known 48-byte anchor
(DemoStoryFinalSpriteTiles + DemoStoryFinalSpriteAttrs), then read
the DemoTextFields and DemoLineTextAddrs that follow.
"""

import sys
import os

ROM_PATH = os.path.join(os.path.dirname(__file__), "..",
                        "Legend of Zelda, The (USA).nes")

HEADER_SIZE = 16
BANK_SIZE = 0x4000
# Z_02.asm is PRG bank 2 (swappable bank, mapped at $8000-$BFFF)
DATA_BANK = 2
DATA_BANK_OFFSET = HEADER_SIZE + DATA_BANK * BANK_SIZE  # 0x08010
DATA_BANK_CPU_BASE = 0x8000

# Known anchor: DemoStoryFinalSpriteTiles (24 bytes) + DemoStoryFinalSpriteAttrs (24 bytes)
ANCHOR = bytes([
    0xE0, 0xE2, 0xEC, 0xEE, 0xF8, 0xFA, 0xE4, 0xE6,
    0xF0, 0xF2, 0xFC, 0xFE, 0xE8, 0xEA, 0xF4, 0xF6,
    0xDC, 0xDE, 0x00, 0x00, 0x78, 0x78, 0x00, 0x00,
    # attrs
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00,
])


def main():
    with open(ROM_PATH, "rb") as f:
        rom = f.read()

    # Read bank 2
    bank_data = rom[DATA_BANK_OFFSET:DATA_BANK_OFFSET + BANK_SIZE]

    # Find the anchor pattern
    anchor_pos = bank_data.find(ANCHOR)
    if anchor_pos < 0:
        print("ERROR: Anchor pattern not found in bank 2!")
        sys.exit(1)

    print(f"Anchor found at bank offset ${anchor_pos:04X}")
    print(f"  CPU address: ${DATA_BANK_CPU_BASE + anchor_pos:04X}")
    print(f"  File offset: ${DATA_BANK_OFFSET + anchor_pos:05X}")

    # DemoTextFields starts right after the 48-byte anchor
    text_start = anchor_pos + len(ANCHOR)
    text_cpu = DATA_BANK_CPU_BASE + text_start
    print(f"\nDemoTextFields starts at bank offset ${text_start:04X}")
    print(f"  CPU address: ${text_cpu:04X}")

    # Find InitDemoSubphaseClearArtifacts by looking for the pattern
    # $20 xx xx $EE xx xx $60 in the bank data after text_start
    # JSR target should be in ROM ($8000-$FFFF), INC target in RAM ($0000-$07FF)
    end_pos = None
    for i in range(text_start, len(bank_data) - 7):
        if (bank_data[i] == 0x20 and
            bank_data[i+3] == 0xEE and
            bank_data[i+6] == 0x60):
            jsr_target = bank_data[i+1] | (bank_data[i+2] << 8)
            inc_target = bank_data[i+4] | (bank_data[i+5] << 8)
            if jsr_target >= 0x8000 and inc_target < 0x0800:
                end_pos = i
                print(f"\nInitDemoSubphaseClearArtifacts found at bank offset ${i:04X}")
                print(f"  CPU address: ${DATA_BANK_CPU_BASE + i:04X}")
                print(f"  JSR target (TurnOffVideoAndClearArtifacts): ${jsr_target:04X}")
                print(f"  INC target (DemoSubphase): ${inc_target:04X}")
                break

    if end_pos is None:
        print("ERROR: Could not find InitDemoSubphaseClearArtifacts!")
        sys.exit(1)

    # Everything from text_start to end_pos is DemoTextFields + DemoLineTextAddrs
    combined = bank_data[text_start:end_pos]
    total_len = len(combined)
    print(f"\nTotal data between anchor and InitDemoSubphaseClearArtifacts: {total_len} bytes")

    # Split DemoTextFields from DemoLineTextAddrs.
    # DemoLineTextAddrs entries are 16-bit LE addresses pointing into DemoTextFields.
    # Scan backwards from end to find where DemoLineTextAddrs starts.
    addr_start = total_len

    for i in range(total_len - 2, -1, -2):
        lo = combined[i]
        hi = combined[i + 1]
        addr = lo | (hi << 8)
        if addr >= text_cpu and addr < (text_cpu + total_len):
            addr_start = i
        else:
            break

    text_field_data = combined[:addr_start]
    line_addr_data = combined[addr_start:]

    print(f"\nDemoTextFields: {len(text_field_data)} bytes (bank ${text_start:04X}-${text_start+len(text_field_data)-1:04X})")
    print(f"  CPU: ${text_cpu:04X}-${text_cpu+len(text_field_data)-1:04X}")
    line_cpu = text_cpu + addr_start
    print(f"DemoLineTextAddrs: {len(line_addr_data)} bytes (bank ${text_start+addr_start:04X}-${text_start+addr_start+len(line_addr_data)-1:04X})")
    print(f"  CPU: ${line_cpu:04X}-${line_cpu+len(line_addr_data)-1:04X}")

    # Verify: count $FF terminators in DemoTextFields
    ff_count = text_field_data.count(0xFF)
    print(f"\n$FF terminators in DemoTextFields: {ff_count}")

    # Verify: decode DemoLineTextAddrs
    num_ptrs = len(line_addr_data) // 2
    print(f"DemoLineTextAddrs entries ({num_ptrs} pointers):")
    for i in range(0, len(line_addr_data), 2):
        lo = line_addr_data[i]
        hi = line_addr_data[i + 1]
        addr = lo | (hi << 8)
        offset_into_text = addr - text_cpu
        print(f"  [{i//2:2d}] ${addr:04X}  (DemoTextFields+${offset_into_text:03X})")

    # Verify pointer count matches $FF terminator count
    if num_ptrs == ff_count:
        print(f"\n  OK: pointer count ({num_ptrs}) matches $FF terminator count ({ff_count})")
    else:
        print(f"\n  WARNING: pointer count ({num_ptrs}) != $FF terminator count ({ff_count})")

    # Output vasm dc.b lines
    print("\n" + "="*60)
    print("=== DemoTextFields (vasm dc.b) ===")
    print("="*60)
    for i in range(0, len(text_field_data), 16):
        chunk = text_field_data[i:i+16]
        hex_vals = ", ".join(f"${b:02X}" for b in chunk)
        print(f"    dc.b    {hex_vals}")

    print()
    print("="*60)
    print("=== DemoLineTextAddrs raw bytes (vasm dc.b, NES LE format) ===")
    print("="*60)
    for i in range(0, len(line_addr_data), 16):
        chunk = line_addr_data[i:i+16]
        hex_vals = ", ".join(f"${b:02X}" for b in chunk)
        print(f"    dc.b    {hex_vals}")

    # Also output with annotations
    print()
    print("="*60)
    print("=== DemoLineTextAddrs annotated ===")
    print("="*60)
    for i in range(0, len(line_addr_data), 2):
        lo = line_addr_data[i]
        hi = line_addr_data[i + 1]
        addr = lo | (hi << 8)
        print(f"    dc.b    ${lo:02X}, ${hi:02X}   ; -> ${addr:04X}")

    # Hex dump of the raw data for verification
    print()
    print("="*60)
    print("=== Raw hex dump of DemoTextFields ===")
    print("="*60)
    for i in range(0, len(text_field_data), 32):
        chunk = text_field_data[i:i+32]
        hex_str = " ".join(f"{b:02X}" for b in chunk)
        ascii_str = ""
        for b in chunk:
            if 0x20 <= b < 0x7F:
                ascii_str += chr(b)
            else:
                ascii_str += "."
        print(f"  {text_cpu+i:04X}: {hex_str:<96s}  {ascii_str}")

if __name__ == "__main__":
    main()
