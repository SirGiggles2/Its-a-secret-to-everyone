#!/usr/bin/env python3
"""compare_vram_reference.py — Compare Genesis VRAM/CRAM dump against NES reference.

Reads:
  builds/reports/bizhawk_vram_cram_dump.txt
  reference/aldonunez/dat/CommonBackgroundPatterns.dat
  reference/aldonunez/dat/CommonSpritePatterns.dat

Reports:
  - CRAM palette entries vs expected NES Zelda title screen palette
  - Tile $24 VRAM bytes vs expected 4bpp conversion of reference NES tile
  - Sprite tile 160 VRAM bytes vs expected
"""

import os, sys, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DUMP = os.path.join(ROOT, "builds", "reports", "bizhawk_vram_cram_dump.txt")
DAT_BG = os.path.join(ROOT, "reference", "aldonunez", "dat", "CommonBackgroundPatterns.dat")
DAT_SP = os.path.join(ROOT, "reference", "aldonunez", "dat", "CommonSpritePatterns.dat")

# ─── NES Palette (2C02 NTSC) — 64 colors → (R8,G8,B8) ──────────────────────
NES_PALETTE_RGB = [
    (84,84,84),(0,30,116),(8,16,144),(48,0,136),(68,0,100),(92,0,48),(84,4,0),
    (60,24,0),(32,42,0),(8,58,0),(0,64,0),(0,60,0),(0,50,60),(0,0,0),(0,0,0),(0,0,0),
    (152,150,152),(8,76,196),(48,50,236),(92,30,228),(136,20,176),(160,20,100),
    (152,34,32),(120,60,0),(84,90,0),(40,114,0),(8,124,0),(0,118,40),(0,102,120),
    (0,0,0),(0,0,0),(0,0,0),
    (236,238,236),(76,154,236),(120,124,236),(176,98,236),(228,84,236),(236,88,180),
    (236,106,100),(212,136,32),(160,170,0),(116,196,0),(76,208,32),(56,204,108),
    (56,180,204),(60,60,60),(0,0,0),(0,0,0),
    (236,238,236),(168,204,236),(188,188,236),(212,178,236),(236,174,236),
    (236,174,212),(236,180,176),(228,196,144),(204,210,120),(180,222,120),
    (168,226,144),(152,226,180),(160,214,228),(160,162,160),(0,0,0),(0,0,0),
]

def rgb_to_genesis(r8, g8, b8):
    """Convert 8-bit RGB to Genesis 9-bit color word.
    Genesis format (GPGX): 0000 BBB0 GGG0 RRR0
    Each channel: 8-bit → 3-bit by >> 5
    """
    r3 = r8 >> 5
    g3 = g8 >> 5
    b3 = b8 >> 5
    return (b3 << 9) | (g3 << 5) | (r3 << 1)

def genesis_to_rgb(word):
    """Extract 3-bit channels from Genesis 9-bit word (GPGX format)."""
    r3 = (word >> 1) & 7
    g3 = (word >> 5) & 7
    b3 = (word >> 9) & 7
    return r3, g3, b3

def nes_palette_genesis(idx):
    idx = idx & 0x3F
    if idx >= len(NES_PALETTE_RGB):
        return 0
    r, g, b = NES_PALETTE_RGB[idx]
    return rgb_to_genesis(r, g, b)

# ─── NES 2BPP → Genesis 4BPP conversion (mirrors expand_nibble logic) ────────
def expand_nibble(n4):
    """Scatter 4-bit value to bit-0 of each nibble in a 16-bit word."""
    d2 = 0
    d2 |= ((n4 & 0x08) << 9)   # bit3 → bit12
    d2 |= ((n4 & 0x04) << 6)   # bit2 → bit8
    d2 |= ((n4 & 0x02) << 3)   # bit1 → bit4
    d2 |= ((n4 & 0x01))        # bit0 → bit0
    return d2

def nes_tile_to_genesis(tile16):
    """Convert 16-byte NES 2bpp tile to 32-byte Genesis 4bpp tile."""
    result = []
    for row in range(8):
        p0 = tile16[row]
        p1 = tile16[row + 8]
        # Pixels 0-3: upper nibble of each plane byte
        n0_p0 = (p0 >> 4) & 0x0F
        n0_p1 = (p1 >> 4) & 0x0F
        d0 = expand_nibble(n0_p0)
        d1 = expand_nibble(n0_p1)
        word0 = (d1 << 1) | d0   # combine planes; but mask to 16 bits
        word0 &= 0xFFFF
        # word0 now has plane1 at bit1 and plane0 at bit0 of each nibble
        # But we need to interleave: each nibble = (p1<<1)|p0 → 0-3 range
        # Let me redo: d0 has bits at 12,8,4,0 (one per nibble); d1 same
        # Combined: OR d0 with (d1<<1)
        w0 = d0 | ((d1 << 1) & 0xFFFF)
        # Pixels 4-7: lower nibble
        n1_p0 = p0 & 0x0F
        n1_p1 = p1 & 0x0F
        d2 = expand_nibble(n1_p0)
        d3 = expand_nibble(n1_p1)
        w1 = d2 | ((d3 << 1) & 0xFFFF)
        # Each 16-bit word = 2 bytes (big-endian)
        result += [(w0 >> 8) & 0xFF, w0 & 0xFF]
        result += [(w1 >> 8) & 0xFF, w1 & 0xFF]
    return result

# ─── Parse CRAM from dump ─────────────────────────────────────────────────────
def parse_cram(text):
    cram = {}
    for m in re.finditer(r'CRAM\[(\d+)\]\[(\d+)\] = \$([0-9A-Fa-f]+)', text):
        pal, slot, hexval = int(m.group(1)), int(m.group(2)), int(m.group(3), 16)
        cram[(pal, slot)] = hexval
    return cram

# ─── Parse VRAM tile bytes from dump ─────────────────────────────────────────
def parse_tile(text, label):
    """Extract bytes from a tile dump section identified by label."""
    # Look for lines like: [+000] XX XX XX XX ...
    pattern = re.compile(r'\[.*?\]\s+((?:[0-9A-Fa-f]{2} ?)+)')
    in_section = False
    bytes_out = []
    for line in text.splitlines():
        if label in line:
            in_section = True
        elif in_section:
            m = pattern.search(line)
            if m:
                chunk = [int(x, 16) for x in m.group(1).split()]
                bytes_out.extend(chunk)
            elif bytes_out:  # hit non-data line after data → stop
                break
    return bytes_out[:32]

# ─── Main ─────────────────────────────────────────────────────────────────────
def main():
    if not os.path.exists(DUMP):
        print(f"ERROR: dump file not found: {DUMP}")
        print("Run bizhawk_vram_cram_dump_probe.lua first.")
        sys.exit(1)

    dump_text = open(DUMP).read()

    print("=" * 68)
    print("VRAM / CRAM Reference Comparison")
    print("=" * 68)

    # ── 1. CRAM Analysis ─────────────────────────────────────────────────────
    print("\n─── CRAM Palette Analysis ──────────────────────────────────────────")
    cram = parse_cram(dump_text)

    if not cram:
        print("  ERROR: no CRAM entries found in dump — check domain name in probe")
    else:
        # Zelda title screen NES palette (approximate expected values):
        # BG pal 0: $0F(black), $00(grey?), $10(grey), $30(white)
        # BG pal 1: $0F, $16, $27, $30  (border / misc)
        # BG pal 2: $0F, $1A, $28, $30  (title accent)
        # Sprite pal 0: $0F, $07, $17, $27  (Link)
        # Sprite pal 2: $0F, $16, $27, $37  (Zelda logo gold/red)
        # (approximate — exact depends on game frame)

        for pal in range(4):
            row = []
            for slot in range(16):
                v = cram.get((pal, slot), None)
                if v is not None:
                    r, g, b = genesis_to_rgb(v)
                    row.append(f"${v:04X}(r{r}g{g}b{b})")
                else:
                    row.append("----")
            print(f"  Palette {pal}: {' '.join(row[:4])} | {' '.join(row[4:8])} ...")

        # Check if palette 0 looks like dark background or bright sprite
        p0s0 = cram.get((0, 0))
        if p0s0 is not None:
            r, g, b = genesis_to_rgb(p0s0)
            brightness = r + g + b
            if brightness > 6:
                print(f"\n  *** PALETTE 0 SLOT 0 IS BRIGHT (R={r}G={g}B={b}) — likely SPRITE OVERWRITE ***")
                print("  Expected: dark/black (R=0 G=0 B=0 or very low)")
            else:
                print(f"\n  Palette 0 slot 0 looks dark (R={r}G={g}B={b}) — BG palette intact")

    # ── 2. Tile $24 pixel data ────────────────────────────────────────────────
    print("\n─── Tile $24 VRAM vs Reference ─────────────────────────────────────")

    if not os.path.exists(DAT_BG):
        print(f"  ERROR: reference file not found: {DAT_BG}")
    else:
        dat = open(DAT_BG, 'rb').read()
        tile24_nes = list(dat[0x24 * 16 : 0x24 * 16 + 16])
        tile24_expected = nes_tile_to_genesis(tile24_nes)

        vram_tile24 = parse_tile(dump_text, "tile24")

        if not vram_tile24:
            print("  ERROR: could not parse tile24 from dump")
        elif not tile24_expected:
            print("  ERROR: could not convert reference tile")
        else:
            print(f"  NES source (16 bytes): {' '.join(f'{b:02X}' for b in tile24_nes)}")
            print(f"  Expected (4bpp):       {' '.join(f'{b:02X}' for b in tile24_expected)}")
            print(f"  VRAM actual  (32b):    {' '.join(f'{b:02X}' for b in vram_tile24)}")
            mismatches = [(i, tile24_expected[i], vram_tile24[i])
                          for i in range(min(len(tile24_expected), len(vram_tile24)))
                          if tile24_expected[i] != vram_tile24[i]]
            if not mismatches:
                print("  ✓ Tile $24 pixel data MATCHES reference")
            else:
                print(f"  ✗ Tile $24 has {len(mismatches)} MISMATCHES:")
                for i, exp, got in mismatches[:8]:
                    print(f"    byte[{i:02d}]: expected ${ exp:02X}, got ${got:02X}")

    # ── 3. Sprite tile 160 ────────────────────────────────────────────────────
    print("\n─── Sprite Tile 160 VRAM vs Reference ─────────────────────────────")

    if os.path.exists(DAT_SP):
        dat_sp = open(DAT_SP, 'rb').read()
        # Sprite tile 160 in Genesis VRAM = VRAM offset 160*32.
        # What NES tile does this correspond to?
        # Genesis tile 160 = NES CHR address 160*16 = $0A00 = NES sprite CHR bank.
        # The sprite CHR bank starts at NES $1000 (MMC1 bank 1), so NES sprite tile index = 160 - 0x80 = 0x50?
        # Or: if Genesis tile N = NES CHR addr N*16/2 = N*8... hmm
        # Actually: Genesis tile N VRAM = NES CHR addr N * 16 * 2? No.
        # .chr_convert_upload sets VRAM addr = CHR_BUF_VADDR * 2 (where VADDR is the NES CHR base addr)
        # So Genesis VRAM tile index N = NES CHR byte address N*16 → CHR_BUF_VADDR = N*16, VRAM = N*32 ✓
        # NES tile 160 is in the sprite CHR bank (NES $1000-$1FFF if bank1, or $0000-$0FFF if bank0)
        # For CommonSpritePatterns.dat: tile indices start at ?
        # The dat file has tiles for sprite CHR bank. Tile offset in file: if the sprites start at NES tile $80 (128),
        # then tile 160 = index 32 in the sprite dat.
        # 1792 bytes / 16 = 112 tiles → sprite tiles 0-111 (NES CHR $0000-$06FF of sprite bank)
        # Genesis sprite tiles start at VRAM $2000 (NES CHR $1000 → VRAM $2000), tile index 256
        # But T26 showed tiles 160-214 which are Genesis tile 160-214 = VRAM $1400-$1AC0
        # NES CHR addr for VRAM $1400 = $1400/2 = $0A00 → within first 4KB CHR bank ($0000-$0FFF)
        # So sprite tiles 160-214 are in CHR bank 0 ($0000-$0FFF), at NES tile indices 160? No, NES tile 160 = CHR addr $A00
        # CommonSpritePatterns.dat seems to have sprites from NES tile $00 upward (sprite bank tile 0=)
        # Let's just try: tile 160 in dat = offset 160*16 (if the sprite dat starts at tile 0)
        sprite_nes_idx = 160  # tentative — may need adjustment
        if sprite_nes_idx * 16 + 16 <= len(dat_sp):
            t160_nes = list(dat_sp[sprite_nes_idx * 16 : sprite_nes_idx * 16 + 16])
            t160_expected = nes_tile_to_genesis(t160_nes)
            vram_t160 = parse_tile(dump_text, "tile160")
            print(f"  NES source  (16b): {' '.join(f'{b:02X}' for b in t160_nes)}")
            print(f"  Expected (4bpp):   {' '.join(f'{b:02X}' for b in t160_expected)}")
            print(f"  VRAM actual (32b): {' '.join(f'{b:02X}' for b in vram_t160)}")
            mismatches = [(i, t160_expected[i], vram_t160[i])
                          for i in range(min(len(t160_expected), len(vram_t160)))
                          if t160_expected[i] != vram_t160[i]]
            if not mismatches:
                print("  ✓ Tile 160 pixel data MATCHES reference")
            else:
                print(f"  ✗ Tile 160 has {len(mismatches)} mismatches")
        else:
            print(f"  tile 160 beyond dat size ({len(dat_sp)} bytes), skipping")

    # ── Summary ───────────────────────────────────────────────────────────────
    print("\n─── Diagnosis Summary ──────────────────────────────────────────────")
    if cram:
        p0s0 = cram.get((0, 0), 0)
        r, g, b = genesis_to_rgb(p0s0)
        if r + g + b > 6:
            print("  ROOT CAUSE CANDIDATE: CRAM palette 0 overwritten by sprite palette")
            print("  FIX: nes_io.asm .t19_palette — map sprite palettes ($3F10-$3F1F)")
            print("       to different CRAM slots (don't overwrite BG palettes 0-3)")
        else:
            print("  CRAM palette 0 appears correct (dark)")
            print("  Investigate tile pixel data or other rendering path")
    print("=" * 68)

if __name__ == "__main__":
    main()
