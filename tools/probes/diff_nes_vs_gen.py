#!/usr/bin/env python3
"""diff_nes_vs_gen.py — byte-diff NES Z1 cave-entry capture vs Genesis port.

Reads:
  C:/tmp/nes_full.bin  (NESF magic, per-frame: state + OAM + PALRAM + NT + attr + TBUF)
  C:/tmp/gen_auto.bin  (GENA magic, per-frame: state + cf-state + CRAM + SAT + PlaneA + NESRAM)

Aligns frame 0 of each = first frame of cave-entry transition (NES Mode $10
entry / Genesis cave_fade activation, both fire on same logical event = Link
steps on entrance tile).

Per frame, compares:
  - Shared NES RAM cells (GameMode/Submode/FrameCounter/ObjX/Y/Dir/State)
    NES System Bus vs Genesis NES RAM mirror at $00FF8000 + offset
  - PALRAM ($3F00-$3F1F, 32 bytes) NES vs Genesis CRAM (first 32 bytes = PAL0)
    direct compare assumes Genesis CRAM mirrors NES PPU palette layout
    (rough approx — Genesis uses 9-bit BGR, NES uses 6-bit indexed)
  - NES nametable cells vs Genesis Plane A cells (tile id only, palette/prio
    bits stripped). Mapping: NES tile_id -> Genesis VRAM slot via
    bg_sparse_tile_lut (not loaded; this script reports raw values for
    manual cross-ref).
  - OAM: NES OAM byte vs Genesis NES OAM mirror at $00FF8200 (same layout).

Output: tools/probes/captures/cave_diff_report.txt — sorted by frame, then
category. Each line: "fr=N CAT addr NES=$XX GEN=$XX DIFF".
"""

import struct
from pathlib import Path


NES_BIN = Path("C:/tmp/nes_full.bin")
GEN_BIN = Path("C:/tmp/gen_auto.bin")
REPORT  = Path("tools/probes/captures/cave_diff_report.txt")


# -------- NES bin format --------
NES_REC_BYTES = 1 + 4 + 6 + 256 + 32 + 768 + 64 + 37  # = 1168


def parse_nes(path):
    data = path.read_bytes()
    assert data[:4] == b"NESF", f"bad NES magic: {data[:4]!r}"
    count = struct.unpack("<I", data[4:8])[0]
    pos = 8
    records = []
    for i in range(count):
        rec_end = pos + NES_REC_BYTES
        if rec_end > len(data):
            break
        rec = data[pos:rec_end]
        records.append({
            "frame_idx":  rec[0],
            "gm":         rec[1],
            "sm":         rec[2],
            "lx":         rec[3],
            "ly":         rec[4],
            "stairs_y":   rec[5],
            "item_lift":  rec[6],
            "obj_state":  rec[7],
            "obj_dir":    rec[8],
            "fc":         rec[9],
            "ppu_ctrl":   rec[10],
            "oam":        rec[11:11+256],
            "pal":        rec[267:267+32],
            "nt":         rec[299:299+768],
            "attr":       rec[1067:1067+64],
            "tbuf":       rec[1131:1131+37],
        })
        pos = rec_end
    return records


# -------- Genesis bin format --------
GEN_REC_BYTES = 1 + 5 + 5 + 128 + 640 + 8192 + 2048  # = 11019


def parse_gen(path):
    """Wider nesram = 32 KB (0x00FF8000..0x00FFFFFF). New rec size."""
    data = path.read_bytes()
    assert data[:4] == b"GENA", f"bad GEN magic: {data[:4]!r}"
    count = struct.unpack("<I", data[4:8])[0]
    pos = 8
    records = []
    nesram_size = 0x8000
    rec_size = 1 + 5 + 5 + 128 + 640 + 8192 + nesram_size
    for i in range(count):
        rec_end = pos + rec_size
        if rec_end > len(data):
            break
        rec = data[pos:rec_end]
        records.append({
            "frame_idx": rec[0],
            "gm":        rec[1],
            "sm":        rec[2],
            "fc":        rec[3],
            "lx":        rec[4],
            "ly":        rec[5],
            "cf_phase":  rec[6],
            "cf_frame":  rec[7],
            "cf_step":   rec[8],
            "cf_calls":  rec[9],
            "cf_liveY":  rec[10],
            "cram":      rec[11:11+128],
            "sat":       rec[139:139+640],
            "plna":      rec[779:779+8192],
            "nesram":    rec[8971:8971+nesram_size],
        })
        pos = rec_end
    return records


# -------- comparison helpers --------
def diff_state_cells(n, g):
    """Compare shared NES RAM cells (NES System Bus vs Genesis NES RAM mirror)."""
    divs = []
    cmps = [
        ("$0012 GameMode",      n["gm"],        g["gm"]),
        ("$0013 Submode",       n["sm"],        g["sm"]),
        ("$002F FrameCounter",  n["fc"],        g["fc"]),
        ("$0070 ObjX[0]",       n["lx"],        g["lx"]),
        ("$0084 ObjY[0]",       n["ly"],        g["ly"]),
        ("$00AC ObjState[0]",   n["obj_state"], g["nesram"][0x00AC]),
        ("$0098 ObjDir[0]",     n["obj_dir"],   g["nesram"][0x0098]),
    ]
    for name, nv, gv in cmps:
        if nv != gv:
            divs.append(f"STATE {name:24s} NES=${nv:02X} GEN=${gv:02X}")
    return divs


def diff_oam(n, g):
    """Compare 256 OAM bytes (NES OAM vs Genesis NES OAM mirror at $0200)."""
    nes_oam = n["oam"]
    # Genesis stores NES OAM mirror at NES RAM $0200..$02FF
    gen_oam = g["nesram"][0x0200:0x0300]
    divs = []
    # Report only non-zero divergences in Link slots ($10-$13 = bytes 0x40-0x4F)
    for slot in range(0x10, 0x14):
        for byte_off in range(4):
            i = slot * 4 + byte_off
            if nes_oam[i] != gen_oam[i]:
                divs.append(
                    f"OAM[{slot:02X}].{byte_off} (b{i:02X}) NES=${nes_oam[i]:02X} GEN=${gen_oam[i]:02X}")
    return divs


def diff_palram(n, g):
    """NES PALRAM (32 bytes) vs Genesis CRAM (first 32 bytes = PAL0 of 16 colors).
    Per slot, NES is single byte (6-bit indexed), Genesis is word (9-bit BGR).
    Skip direct compare; just report any cell change between NES and Genesis."""
    divs = []
    for i in range(8):  # PAL0 first 8 NES colors = BG row 0
        nes_byte = n["pal"][i]
        gen_word = (g["cram"][i*2+1] << 8) | g["cram"][i*2]
        # Note: not byte-identical even after correct mapping due to color
        # quantization. Report for visibility only.
        # Skip if both are zero (transparent / unloaded).
        if nes_byte != 0 or gen_word != 0:
            pass  # noisy; suppress
    return divs


def diff_plane_a_arch_region(n, g):
    """Compare NES nametable (col 0-15, rows 0-15) vs Genesis Plane A
    at corresponding cells. Scan WIDE area to find arch position on both."""
    divs = []
    # NES: which cells contain $24 (cave entrance floor)?
    divs.append("== NES nametable $24 tile locations (cave entrance candidates) ==")
    for nes_row in range(0, 22):
        for nes_col in range(0, 32):
            t = n["nt"][nes_row * 32 + nes_col]
            if t == 0x24:
                divs.append(f"  NES NT($24) at row={nes_row} col={nes_col}")
    # Genesis: which Plane A cells have non-default tile (search broad area)?
    divs.append("== Genesis Plane A row by row tile-id maps (rows 7-15, cols 0-15) ==")
    for gen_row in range(7, 16):
        line = f"  gen_row={gen_row:2d}: "
        for col in range(0, 16):
            plna_off = (gen_row * 64 + col) * 2
            w = (g["plna"][plna_off+1] << 8) | g["plna"][plna_off]
            tile = w & 0x07FF
            prio = "P" if (w & 0x8000) else "."
            line += f"{tile:03X}{prio} "
        divs.append(line)
    return divs


def main():
    nes = parse_nes(NES_BIN)
    gen = parse_gen(GEN_BIN)
    print(f"NES records: {len(nes)}, GEN records: {len(gen)}")

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    with REPORT.open("w") as f:
        f.write(f"# cave_diff_report  NES vs Genesis cave-entry byte-diff\n")
        f.write(f"# NES records: {len(nes)}, GEN records: {len(gen)}\n\n")

        # Frame 0 alignment: both should be at cave-entry trigger
        f.write("== Frame 0 alignment check ==\n")
        if nes and gen:
            n0, g0 = nes[0], gen[0]
            f.write(f"NES fr 0: GM=${n0['gm']:02X} Link=(${n0['lx']:02X},${n0['ly']:02X})\n")
            f.write(f"GEN fr 0: GM=${g0['gm']:02X} Link=(${g0['lx']:02X},${g0['ly']:02X})\n")
            f.write(f"  Y delta = NES_Y - GEN_Y = ${n0['ly']:02X} - ${g0['ly']:02X} = {n0['ly'] - g0['ly']}\n")
            f.write("\n")

        # Plane A arch column (col 8) tile ids at trigger
        f.write("== Trigger-frame nametable cells (col 8, rows 0-10) ==\n")
        if nes and gen:
            for line in diff_plane_a_arch_region(nes[0], gen[0]):
                f.write(line + "\n")
        f.write("\n")

        # PlayAreaTiles dump (Genesis nesram[$6530+])
        f.write("== Genesis PlayAreaTiles ($6530+, col-major: col*0x16 + row) ==\n")
        if gen:
            g0 = gen[0]
            for col in range(0, 16):
                line = f"  PAT col {col:2d}: "
                for row in range(0, 11):
                    pat_off = 0x6530 + col * 0x16 + row
                    if pat_off < len(g0["nesram"]):
                        t = g0["nesram"][pat_off]
                        line += f"r{row:02d}={t:02X} "
                f.write(line + "\n")
        f.write("\n")

        # Per-frame state diffs
        f.write("== Per-frame STATE diffs (frame 0 .. min(NES, GEN)) ==\n")
        n_count = min(len(nes), len(gen))
        for i in range(n_count):
            divs = diff_state_cells(nes[i], gen[i])
            if divs:
                f.write(f"-- fr {i:03d} --\n")
                for d in divs:
                    f.write(f"  {d}\n")
        f.write("\n")

        # Per-frame OAM Link-slot diffs
        f.write("== Per-frame OAM Link-slot diffs ($10..$13) ==\n")
        for i in range(min(20, n_count)):
            divs = diff_oam(nes[i], gen[i])
            if divs:
                f.write(f"-- fr {i:03d} --\n")
                for d in divs:
                    f.write(f"  {d}\n")

    print(f"Report: {REPORT}")


if __name__ == "__main__":
    main()
