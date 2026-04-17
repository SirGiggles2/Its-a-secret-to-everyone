#!/usr/bin/env python
"""
extract_dmc_samples.py — Pull the 7 DMC samples used by Zelda 1 out of the
stock NES ROM and produce assets consumable by the Genesis port.

Outputs:
  data/dmc_samples.bin        — concatenated raw DMC delta-PCM bytes
  data/dmc_samples_pcm.bin    — concatenated 8-bit unsigned linear PCM, ready
                                 to stream directly to YM2612 reg $2A (DAC).
                                 Each delta byte decodes to 8 PCM bytes, so the
                                 PCM blob is ~8x the delta blob.
  src/dmc_samples.inc         — 68K-assembler include: labels, offsets, sizes,
                                 NES $4010/$4012/$4013 values. Emits both
                                 delta and PCM offset tables and incbin labels.
  data/dmc_samples_wav/*.wav  — decoded PCM for ear-checking (optional)

Sample-table source is `src/zelda_translated/z_00.asm`:

    SampleAddrs:   dc.b $00, $4C, $80, $1D, $20, $28, $4C   ; $4012 values
    SampleLengths: dc.b $75, $C0, $40, $0A, $B0, $90, $D0   ; $4013 values
    SampleRates:   dc.b $0F, $0F, $0D, $0F, $0E, $0F, $0E   ; $4010 values

NES DMC encoding (per https://www.nesdev.org/wiki/APU_DMC):
  $4012 byte N  → sample start address = $C000 + N*64
  $4013 byte N  → sample length        = N*16 + 1   bytes
  $4010 low 4   → playback rate (period table below)

Zelda uses MMC1 with a 128 KB PRG. The last 16 KB bank is fixed at
$C000-$FFFF, so any address in that range is at file offset
  0x10  +  7 * 0x4000  +  (addr - 0xC000)
  = 0x1C010 + (addr - 0xC000)

Usage:
  python tools/extract_dmc_samples.py [path-to-rom]

If no path given, looks for "Legend of Zelda, The (USA).nes" in worktree root.
"""

from __future__ import annotations

import os
import struct
import sys
import wave
from pathlib import Path

# --- sample table -----------------------------------------------------------

SAMPLE_NAMES = [
    "SFX_01",   # 1
    "SFX_02",   # 2
    "SFX_03",   # 3
    "SFX_04",   # 4
    "SFX_05",   # 5
    "SFX_06",   # 6
    "SFX_07",   # 7
]
SAMPLE_ADDR_BYTES   = [0x00, 0x4C, 0x80, 0x1D, 0x20, 0x28, 0x4C]  # $4012
SAMPLE_LENGTH_BYTES = [0x75, 0xC0, 0x40, 0x0A, 0xB0, 0x90, 0xD0]  # $4013
SAMPLE_RATE_BYTES   = [0x0F, 0x0F, 0x0D, 0x0F, 0x0E, 0x0F, 0x0E]  # $4010

# NES NTSC DMC period table (CPU cycles per output bit)
DMC_PERIOD_NTSC = [428, 380, 340, 320, 286, 254, 226, 214,
                   190, 160, 142, 128, 106,  84,  72,  54]
CPU_HZ_NTSC = 1789773


def dmc_rate_hz(rate_idx: int) -> float:
    return CPU_HZ_NTSC / DMC_PERIOD_NTSC[rate_idx & 0xF]


# --- ROM IO -----------------------------------------------------------------

def read_ines(rom_path: Path):
    data = rom_path.read_bytes()
    if data[:4] != b"NES\x1A":
        raise SystemExit(f"{rom_path}: not an iNES file")
    prg_banks = data[4]  # 16 KB units
    chr_banks = data[5]  # 8 KB units
    prg_size = prg_banks * 0x4000
    header = 0x10
    # Trainer?
    if data[6] & 0x04:
        header += 0x200
    prg = data[header:header + prg_size]
    print(f"  iNES: PRG={prg_banks}*16KB ({prg_size} B), CHR={chr_banks}*8KB, "
          f"mapper={((data[6]>>4) | (data[7]&0xF0))}")
    if prg_size != 0x20000:
        raise SystemExit(f"expected 128 KB PRG, got {prg_size}")
    return prg  # 128 KB


def nes_addr_to_prg_offset(addr: int, prg: bytes) -> int:
    # MMC1, last bank fixed at $C000-$FFFF.
    assert 0xC000 <= addr <= 0xFFFF, f"DMC addr {addr:04X} outside last bank"
    return (len(prg) - 0x4000) + (addr - 0xC000)


# --- DMC decoder (delta-PCM → uint8 signed-7) -------------------------------

def decode_dmc(sample_bytes: bytes) -> list[int]:
    """Decode NES DMC delta modulation to a list of 7-bit DAC levels (0..127)."""
    level = 64  # reset value in the Zelda driver is 64 (mid)
    out: list[int] = []
    for byte in sample_bytes:
        for bit in range(8):
            if byte & (1 << bit):
                if level <= 125:
                    level += 2
            else:
                if level >= 2:
                    level -= 2
            out.append(level)
    return out


def write_wav(path: Path, samples: list[int], rate_hz: float) -> None:
    # Convert 0..127 → signed int16 centered at 0, ~1/2 full scale
    frames = bytearray()
    for s in samples:
        v = (s - 64) * 256  # roughly ±16k
        frames += struct.pack("<h", max(-32768, min(32767, v)))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(int(round(rate_hz)))
        w.writeframes(bytes(frames))


# --- main -------------------------------------------------------------------

def main(argv: list[str]) -> int:
    here = Path(__file__).resolve().parent
    worktree = here.parent
    default_rom = worktree / "Legend of Zelda, The (USA).nes"
    rom_path = Path(argv[1]) if len(argv) > 1 else default_rom
    print(f"ROM: {rom_path}")
    prg = read_ines(rom_path)

    # Blobs live under src/data/ so vasm's `include` directive (run with cwd
    # = src/) can pull them in with a short "data/..." path matching the
    # other audio-include conventions (music_blob.dat, pcm_samples.inc).
    src_dir = worktree / "src"
    data_dir = src_dir / "data"
    wav_dir = worktree / "data" / "dmc_samples_wav"
    data_dir.mkdir(parents=True, exist_ok=True)
    wav_dir.mkdir(parents=True, exist_ok=True)

    bin_path = data_dir / "dmc_samples.bin"
    pcm_path = data_dir / "dmc_samples_pcm.bin"
    inc_path = data_dir / "dmc_samples.inc"

    blob = bytearray()       # raw DMC delta
    pcm_blob = bytearray()   # 8-bit unsigned linear PCM, ready for YM $2A
    offsets: list[int] = []
    lengths: list[int] = []
    pcm_offsets: list[int] = []
    pcm_lengths: list[int] = []
    nes_addrs: list[int] = []

    for i, (name, a12, a13, a10) in enumerate(
            zip(SAMPLE_NAMES, SAMPLE_ADDR_BYTES, SAMPLE_LENGTH_BYTES, SAMPLE_RATE_BYTES)):
        nes_addr = 0xC000 + a12 * 64
        length   = a13 * 16 + 1
        rate_idx = a10 & 0x0F
        rate_hz  = dmc_rate_hz(rate_idx)

        prg_off = nes_addr_to_prg_offset(nes_addr, prg)
        sample  = bytes(prg[prg_off:prg_off + length])
        if len(sample) != length:
            raise SystemExit(f"{name}: short read ({len(sample)}/{length})")

        offsets.append(len(blob))
        lengths.append(length)
        nes_addrs.append(nes_addr)
        blob.extend(sample)

        # Decode delta -> 7-bit DAC levels (0..127), then shift <<1 to 8-bit
        # unsigned (0..254) centered at 128 to match YM2612 reg $2A encoding.
        decoded = decode_dmc(sample)
        pcm_offsets.append(len(pcm_blob))
        pcm_lengths.append(len(decoded))
        pcm_blob.extend(bytes((v << 1) & 0xFF for v in decoded))

        wav_path = wav_dir / f"{i+1:02d}_{name}.wav"
        write_wav(wav_path, decoded, rate_hz)

        print(f"  [{i+1}] {name}: NES ${nes_addr:04X} "
              f"(PRG ${prg_off:05X})  {length} B delta / "
              f"{len(decoded)} B pcm  "
              f"rate_idx=${rate_idx:X} ({rate_hz:7.1f} Hz)")

    # align blobs to even byte for M68K rept loads
    if len(blob) & 1:
        blob.append(0x00)
    if len(pcm_blob) & 1:
        pcm_blob.append(0x80)  # center value = silence for PCM

    bin_path.write_bytes(bytes(blob))
    pcm_path.write_bytes(bytes(pcm_blob))
    print(f"\nWrote {len(blob)} B delta -> {bin_path}")
    print(f"Wrote {len(pcm_blob)} B pcm   -> {pcm_path}")

    # --- emit assembler include --------------------------------------------
    lines = []
    lines.append("; dmc_samples.inc - auto-generated by tools/extract_dmc_samples.py")
    lines.append("; DO NOT EDIT BY HAND. Regenerate from Legend of Zelda, The (USA).nes.")
    lines.append(";")
    lines.append("; 7 DMC samples ripped from the stock NES ROM, available in two forms:")
    lines.append(";")
    lines.append(";   data/dmc_samples.bin     — raw DMC delta-PCM bytes. Kept for a")
    lines.append(";                              possible future true-NES-DMC emulation")
    lines.append(";                              path. The current Phase-C scaffold does")
    lines.append(";                              NOT consume this.")
    lines.append(";   data/dmc_samples_pcm.bin — decoded 8-bit unsigned linear PCM,")
    lines.append(";                              ready to stream byte-by-byte to YM2612")
    lines.append(";                              register $2A (DAC). Each delta byte")
    lines.append(";                              expands to 8 PCM bytes.")
    lines.append(";")
    lines.append("; Each sample's metadata matches the NES $4010/$4012/$4013 values so the")
    lines.append("; APU register stubs in nes_io.asm can look them up by 1-based index.")
    lines.append("")
    lines.append("DMC_SAMPLE_COUNT    equ     " + str(len(SAMPLE_NAMES)))
    lines.append("")
    lines.append("; --- Delta form (raw DMC bytes) ----------------------------------------")
    for i, name in enumerate(SAMPLE_NAMES):
        lines.append(f"DMC_{name}_DELTA_OFF equ     ${offsets[i]:04X}")
        lines.append(f"DMC_{name}_DELTA_LEN equ     ${lengths[i]:04X}")
    lines.append("")
    lines.append("; --- PCM form (decoded, ready for YM reg $2A) --------------------------")
    for i, name in enumerate(SAMPLE_NAMES):
        lines.append(f"DMC_{name}_PCM_OFF   equ     ${pcm_offsets[i]:06X}")
        lines.append(f"DMC_{name}_PCM_LEN   equ     ${pcm_lengths[i]:06X}")
    lines.append("")
    lines.append("; --- Shared metadata ---------------------------------------------------")
    for i, name in enumerate(SAMPLE_NAMES):
        lines.append(f"DMC_{name}_RATE      equ     ${SAMPLE_RATE_BYTES[i]:02X}"
                     f"   ; $4010 raw")
        lines.append(f"DMC_{name}_NESADDR   equ     ${nes_addrs[i]:04X}"
                     f"   ; $4012 -> NES addr")
    lines.append("")
    lines.append("; --- Parallel lookup tables, 1-based --------------------------------")
    lines.append("; Note: DMC_SAMPLE_PCM_OFFS/LENS are long-word because decoded")
    lines.append("; samples are up to ~26 KB each (larger than a 16-bit offset).")
    lines.append("    even")
    lines.append("DMC_SAMPLE_PCM_OFFS:")
    for i, name in enumerate(SAMPLE_NAMES):
        lines.append(f"    dc.l    DMC_{name}_PCM_OFF       ; {i+1}")
    lines.append("")
    lines.append("    even")
    lines.append("DMC_SAMPLE_PCM_LENS:")
    for i, name in enumerate(SAMPLE_NAMES):
        lines.append(f"    dc.l    DMC_{name}_PCM_LEN       ; {i+1}")
    lines.append("")
    lines.append("DMC_SAMPLE_RATES:")
    for i, name in enumerate(SAMPLE_NAMES):
        lines.append(f"    dc.b    DMC_{name}_RATE          ; {i+1}")
    lines.append("    even")
    lines.append("")
    lines.append("; Per-frame burst size at ~60 Hz VBlank.  Computed as")
    lines.append("; round(dmc_rate_hz / 60) so playback speed matches the NES")
    lines.append("; original.  Used by dmc_feed to drain exactly one frame's")
    lines.append("; worth of PCM bytes per music_tick.")
    lines.append("    even")
    lines.append("DMC_SAMPLE_BURST60:")
    for i, name in enumerate(SAMPLE_NAMES):
        burst60 = int(round(dmc_rate_hz(SAMPLE_RATE_BYTES[i]) / 60.0))
        lines.append(f"    dc.w    {burst60}                     ; {i+1} "
                     f"({dmc_rate_hz(SAMPLE_RATE_BYTES[i]):.0f} Hz)")
    lines.append("")
    lines.append("; dbra-count per sample for dmc_trigger's synchronous cycle-paced")
    lines.append("; streamer.  M68K runs at 7.67 MHz NTSC; a sample at rate_hz needs")
    lines.append("; one DAC write every (7670000 / rate_hz) cycles.  Fixed overhead")
    lines.append("; per byte in the streamer inner loop is ~50 cycles; the dbra spin")
    lines.append("; loop contributes 10*N + 4 cycles for dbra count N.  So:")
    lines.append(";     N = round((cycles_per_byte - 54) / 10)")
    lines.append("; Clamp to zero so a too-slow-CPU assumption never goes negative.")
    lines.append("    even")
    lines.append("DMC_SAMPLE_SPIN:")
    M68K_HZ = 7670000
    FIXED_OVERHEAD = 54  # cycles of non-spin work per byte in streamer inner loop
    for i, name in enumerate(SAMPLE_NAMES):
        hz = dmc_rate_hz(SAMPLE_RATE_BYTES[i])
        cyc = M68K_HZ / hz
        spin = max(0, int(round((cyc - FIXED_OVERHEAD) / 10.0)))
        lines.append(f"    dc.w    {spin:<5}                  ; {i+1} "
                     f"({hz:.0f} Hz, {cyc:.0f} cyc/byte)")
    lines.append("")
    lines.append("; --- Blobs ------------------------------------------------------------")
    lines.append("    even")
    lines.append("DMC_SAMPLE_BLOB:")
    lines.append('    incbin  "data/dmc_samples.bin"')
    lines.append("DMC_SAMPLE_BLOB_END:")
    lines.append("")
    lines.append("    even")
    lines.append("DMC_SAMPLE_PCM_BLOB:")
    lines.append('    incbin  "data/dmc_samples_pcm.bin"')
    lines.append("DMC_SAMPLE_PCM_BLOB_END:")
    lines.append("")

    # vasm accepts UTF-8 comments; switch off ASCII enforcement so that em-dashes
    # and arrows in the generated include don't blow up the writer on Windows.
    inc_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote asm include -> {inc_path}")
    print(f"Wrote {len(SAMPLE_NAMES)} WAVs -> {wav_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
