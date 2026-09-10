"""pause_oam_sat_diff.py — pairwise compare NES OAM vs Genesis SAT during
active subscreen. Per RULE ZERO: probe NES live + Genesis live + byte-diff
BEFORE writing fixes.

For each visible NES OAM sprite:
  - Compute expected Genesis SAT position: SAT_X = nes_x + 128, SAT_Y = nes_y + 129
  - Compute expected VRAM tile: SPR_TILE_BASE + nes_tile_id
  - Look up actual Genesis SAT entry at that position
  - Report mismatches: nes_tile vs gen_tile, pal, hflip
"""
import struct, pathlib

NES = pathlib.Path("C:/tmp/nes_subscreen")
GEN = pathlib.Path("C:/tmp/gen_subscreen")

SPR_TILE_BASE = 533

def parse_nes_oam(b):
    """Returns list of (slot, y, tile, attr, x) for visible sprites."""
    out = []
    for i in range(64):
        y, t, a, x = b[i*4], b[i*4+1], b[i*4+2], b[i*4+3]
        if y < 0xEF and t != 0xFF:
            out.append((i, y, t, a, x))
    return out

def parse_gen_sat(b):
    """Genesis SAT: 80 entries x 8 bytes each.
    Format per entry (big-endian):
      0-1: Y (10 bits, 0-1023)
      2:   size_link high (size 4 bits in upper nibble: VV HH)
      3:   link (next sprite chain, 7 bits)
      4-5: attr (priority + palette + hflip + vflip + tile_id 11 bits)
      6-7: X (10 bits, 0-1023)
    Returns list of (slot, y, size, link, tile_id, hflip, pal, x).
    """
    out = []
    for i in range(80):
        off = i * 8
        y = (b[off]<<8) | b[off+1]
        sl = b[off+2]
        lk = b[off+3]
        a = (b[off+4]<<8) | b[off+5]
        x = (b[off+6]<<8) | b[off+7]
        size = sl & 0x0F
        tile = a & 0x07FF
        hflip = (a >> 11) & 1
        vflip = (a >> 12) & 1
        pal = (a >> 13) & 3
        prio = (a >> 15) & 1
        if y == 0 and x == 0 and tile == 0:
            continue  # blank slot
        out.append((i, y, size, lk, tile, hflip, vflip, pal, x))
    return out

def main():
    nes_oam = (NES / "oam.bin").read_bytes()
    gen_sat = (GEN / "sat.bin").read_bytes()
    nes = parse_nes_oam(nes_oam)
    gen = parse_gen_sat(gen_sat)

    # Build Genesis index by (X, Y) for lookup
    gen_by_pos = {}
    for entry in gen:
        slot, y, size, lk, tile, hf, vf, pal, x = entry
        gen_by_pos[(x, y)] = entry

    print("=== NES OAM (visible, y < $EF) ===")
    print(f"  {'idx':>3} {'Y':>4} {'tile':>4} {'attr':>4} {'X':>4}  sub_pal hflip")
    for slot, y, t, a, x in nes:
        sp = a & 3
        hf = (a >> 6) & 1
        print(f"  {slot:3d} ${y:02X} ${t:02X}  ${a:02X}  ${x:02X}  pal{sp}    hf={hf}")

    print()
    print("=== Genesis SAT (active slots) ===")
    print(f"  {'idx':>3} {'Y':>5} {'sz':>3} {'lk':>3} {'tile':>5} {'pal':>3} {'hflip':>5} {'X':>5}  delta(X-128, Y-129)")
    for entry in gen:
        slot, y, size, lk, tile, hf, vf, pal, x = entry
        dx = x - 128
        dy = y - 129
        dx_s = f"${dx:02X}" if dx >= 0 else f"({dx})"
        dy_s = f"${dy:02X}" if dy >= 0 else f"({dy})"
        print(f"  {slot:3d} {y:5d} {size:3d} {lk:3d} {tile:5d} {pal:3d} {hf:5d} {x:5d}   nes_x={dx_s} nes_y={dy_s}")

    print()
    print("=== Pairwise NES OAM ↔ Genesis SAT match ===")
    print("For each NES sprite expect Genesis entry at SAT(X=nes_x+128, Y=nes_y+129)")
    print("with tile=SPR_TILE_BASE+nes_tile_id (533 + tile)")
    print()
    mismatches = 0
    for slot, y, t, a, x in nes:
        sp_nes = a & 3
        hf_nes = (a >> 6) & 1
        expect_x = x + 128
        expect_y = y + 129
        expect_tile = SPR_TILE_BASE + t
        # Find Genesis sprite at expected position (allow ±1 px tolerance)
        g = None
        for entry in gen:
            sl, gy, sz, lk, gt, ghf, gvf, gpal, gx = entry
            if abs(gx - expect_x) <= 2 and abs(gy - expect_y) <= 2:
                g = entry
                break
        if g is None:
            print(f"  NES slot {slot} (y=${y:02X} x=${x:02X} tile=${t:02X}) -> NO Genesis sprite at expected ({expect_x},{expect_y})  MISSING")
            mismatches += 1
            continue
        sl, gy, sz, lk, gt, ghf, gvf, gpal, gx = g
        status = []
        if gt != expect_tile:
            status.append(f"TILE_DIFF gen={gt} expect={expect_tile} (nes${t:02X})")
            mismatches += 1
        if ghf != hf_nes:
            status.append(f"HFLIP_DIFF gen={ghf} nes={hf_nes}")
        if abs(gx - expect_x) > 0 or abs(gy - expect_y) > 0:
            status.append(f"POS_OFF gen=({gx},{gy}) expect=({expect_x},{expect_y})")
        if not status:
            print(f"  NES {slot:2d} (y=${y:02X} x=${x:02X} tile=${t:02X}) -> Gen {sl:2d} OK")
        else:
            print(f"  NES {slot:2d} (y=${y:02X} x=${x:02X} tile=${t:02X}) -> Gen {sl:2d} {'  '.join(status)}")

    print()
    print(f"Total mismatches: {mismatches}")

if __name__ == "__main__":
    main()
