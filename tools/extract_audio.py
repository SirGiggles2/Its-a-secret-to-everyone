#!/usr/bin/env python3
"""
extract_audio.py - Extract audio data from NES Zelda Z_00.

This pass extracts:
  - song phrase headers
  - raw song-script blobs from the NES ROM
  - tune scripts, note tables, envelopes, and noise params
  - SFX note arrays and sample tables

The Aldonunez disassembly references the song scripts via .INCBIN files, but
those sidecar files are not present in this workspace. We recover the exact
blob boundaries from the header pointers plus the first opcode sequence of
DriveAudio in PRG bank 0, so the extraction still stays deterministic.
"""

import os
import re
import sys

INES_HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000
BANK0_CPU_BASE = 0x8000

DRIVE_AUDIO_SIGNATURE = bytes(
    [
        0xA5,
        0xE0,
        0xF0,
        0x0C,
        0xA9,
        0x00,
        0x8D,
        0x15,
        0x40,
        0xA9,
        0x0F,
        0x8D,
        0x15,
        0x40,
        0xD0,
        0x11,
        0xA9,
        0xFF,
        0x8D,
        0x17,
        0x40,
    ]
)

LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):$")

SONG_LABELS = {
    "SongTable",
    "SongHeaderDemo0",
    "SongHeaderItemTaken0",
    "SongHeaderEndLevel0",
    "SongHeaderOverworld0",
    "SongHeaderUnderworld0",
    "SongHeaderLastLevel0",
    "SongHeaderGanon0",
    "SongHeaderEnding0",
    "SongHeaderZelda",
    "TuneScripts0",
    "TuneScripts1",
    "NoiseVolumes",
    "NoisePeriods",
    "NoiseLengths",
    "NotePeriodTable",
    "NoteLengthTable0",
    "NoteLengthTable1",
    "NoteLengthTable2",
    "NoteLengthTable3",
    "NoteLengthTable4",
    "CustomEnvelopeSong",
    "CustomEnvelopeTune1",
}

Z07_LABELS = {
    "PlayAreaColumnAddrs",
}

SFX_LABELS = {
    "BombSfxNotes",
    "StairsSfxNotes",
    "SwordSfxNotes",
    "ArrowSfxNotes",
    "FlameSfxNotes",
    "SampleAddrs",
    "SampleLengths",
    "SampleRates",
}

SONG_SCRIPT_HEADER_MAP = [
    ("SongScriptItemTaken0", "SongHeaderItemTaken0", 0),
    ("SongScriptOverworld0", "SongHeaderOverworld0", 0),
    ("SongScriptUnderworld0", "SongHeaderUnderworld0", 0),
    ("SongScriptEndLevel0", "SongHeaderEndLevel0", 0),
    ("SongScriptLastLevel0", "SongHeaderLastLevel0", 0),
    ("SongScriptGanon0", "SongHeaderGanon0", 0),
    ("SongScriptEnding0", "SongHeaderEnding0", 0),
    ("SongScriptDemo0", "SongHeaderDemo0", 0),
    ("SongScriptZelda0", "SongHeaderZelda", 0),
]


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

    missing = sorted(label for label in target_labels if label not in blocks)
    if missing:
        raise ValueError(f"Missing expected labels in {path}: {', '.join(missing)}")

    return blocks


def extract_script_addr(header_bytes, phrase_index):
    offset = phrase_index * 8
    if len(header_bytes) < offset + 3:
        raise ValueError("Song header too short to extract script address")
    lo = header_bytes[offset + 1]
    hi = header_bytes[offset + 2]
    return (hi << 8) | lo


def cpu_addr_to_bank0_offset(cpu_addr):
    if cpu_addr < BANK0_CPU_BASE or cpu_addr >= BANK0_CPU_BASE + PRG_BANK_SIZE:
        raise ValueError(f"CPU address ${cpu_addr:04X} is outside PRG bank 0")
    return cpu_addr - BANK0_CPU_BASE


def find_drive_audio_addr(bank0_data, min_cpu_addr):
    min_offset = cpu_addr_to_bank0_offset(min_cpu_addr)
    match_offset = bank0_data.find(DRIVE_AUDIO_SIGNATURE, min_offset)
    if match_offset < 0:
        raise ValueError("Could not locate DriveAudio signature in PRG bank 0")
    return BANK0_CPU_BASE + match_offset


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


def extract_song_scripts(prg_data, song_blocks):
    bank0_data = prg_data[:PRG_BANK_SIZE]

    script_starts = []
    for script_label, header_label, phrase_index in SONG_SCRIPT_HEADER_MAP:
        start_addr = extract_script_addr(song_blocks[header_label], phrase_index)
        script_starts.append((script_label, start_addr))

    drive_audio_addr = find_drive_audio_addr(bank0_data, script_starts[-1][1])

    scripts = {}
    for index, (script_label, start_addr) in enumerate(script_starts):
        if index + 1 < len(script_starts):
            end_addr = script_starts[index + 1][1]
        else:
            end_addr = drive_audio_addr

        start_offset = cpu_addr_to_bank0_offset(start_addr)
        end_offset = cpu_addr_to_bank0_offset(end_addr)
        if end_offset <= start_offset:
            raise ValueError(
                f"Invalid ROM bounds for {script_label}: "
                f"${start_addr:04X}-${end_addr:04X}"
            )

        scripts[script_label] = {
            "start_addr": start_addr,
            "end_addr": end_addr,
            "bytes": bytes(bank0_data[start_offset:end_offset]),
        }

    return scripts, drive_audio_addr


SONG_TABLE_SIGNATURE = bytes(
    [
        0x7D, 0xB5, 0x6E, 0x67, 0x7D, 0xAD, 0x64, 0x64,
        0x75, 0x7D, 0x85, 0x95, 0x7D, 0x8D, 0x95, 0x9D,
        0xA5, 0xBD, 0xC5, 0xCD, 0xD5, 0xDD, 0xD5, 0xE5,
        0xED, 0x24, 0x2C, 0x34, 0x3C, 0x44, 0x34, 0x4C,
        0x54, 0x5C, 0x44, 0xF5,
    ]
)


def extract_music_blob(prg_data, song_script_blocks):
    """Return (blob_bytes, nes_base_addr) for the contiguous music data.

    The blob is SongTable + all 9 song headers + unknown 3-byte gap +
    9 concatenated song scripts, pulled verbatim from PRG bank 0.  The
    native M68K music player converts any NES CPU pointer found inside a
    song header to a blob offset via (nes_addr - nes_base_addr).
    """
    bank0_data = prg_data[:PRG_BANK_SIZE]
    pos = find_unique_pattern(
        bank0_data, SONG_TABLE_SIGNATURE, "SongTable in PRG bank 0"
    )
    nes_base = BANK0_CPU_BASE + pos
    end_addr = max(info["end_addr"] for info in song_script_blocks.values())
    blob_size = end_addr - nes_base
    if blob_size <= 0:
        raise ValueError("Music blob end address precedes SongTable")
    blob_bytes = bytes(bank0_data[pos : pos + blob_size])
    return blob_bytes, nes_base


def write_music_blob_file(data_dir, blob, nes_base):
    dat_path = os.path.join(data_dir, "music_blob.dat")
    with open(dat_path, "wb") as f:
        f.write(blob)
    print(f"  Wrote {dat_path} ({len(blob)} bytes, NES base ${nes_base:04X})")

    inc_lines = [
        "; Music blob constants - auto-generated by extract_audio.py",
        "; DO NOT EDIT.  Regenerated on every audio extraction.",
        "",
        f"MUSIC_BLOB_NES_BASE equ ${nes_base:04X}",
        f"MUSIC_BLOB_SIZE     equ {len(blob)}",
        "",
    ]
    inc_path = os.path.join(data_dir, "music_blob.inc")
    with open(inc_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(inc_lines))
    print(f"  Wrote {inc_path}")


def extract_pcm_samples(prg_data, z07_blocks):
    bank7_data = prg_data[7 * PRG_BANK_SIZE : 8 * PRG_BANK_SIZE]
    play_area_column_addrs = bytes(z07_blocks["PlayAreaColumnAddrs"])
    play_area_pos = find_unique_pattern(
        bank7_data, play_area_column_addrs, "PlayAreaColumnAddrs in PRG bank 7"
    )
    return bytes(bank7_data[:play_area_pos])


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


def write_songs_file(data_dir, song_blocks):
    ordered_labels = [
        "SongTable",
        "SongHeaderDemo0",
        "SongHeaderItemTaken0",
        "SongHeaderEndLevel0",
        "SongHeaderOverworld0",
        "SongHeaderUnderworld0",
        "SongHeaderLastLevel0",
        "SongHeaderGanon0",
        "SongHeaderEnding0",
        "SongHeaderZelda",
        "TuneScripts0",
        "TuneScripts1",
        "NoiseVolumes",
        "NoisePeriods",
        "NoiseLengths",
        "NotePeriodTable",
        "NoteLengthTable0",
        "NoteLengthTable1",
        "NoteLengthTable2",
        "NoteLengthTable3",
        "NoteLengthTable4",
        "CustomEnvelopeSong",
        "CustomEnvelopeTune1",
    ]

    lines = [
        "; Audio song/tune tables extracted from NES Zelda Z_00",
        "; Auto-generated by extract_audio.py - DO NOT EDIT",
        "",
    ]

    for label in ordered_labels:
        lines.append(data_to_inc_bytes(bytes(song_blocks[label]), label))
        lines.append("")

    write_text_file(os.path.join(data_dir, "songs.inc"), lines[:-1])


def write_song_scripts_file(data_dir, script_blocks, drive_audio_addr):
    ordered_labels = [label for label, _, _ in SONG_SCRIPT_HEADER_MAP]

    lines = [
        "; Raw song-script blobs extracted from NES Zelda PRG bank 0",
        "; Auto-generated by extract_audio.py - DO NOT EDIT",
        f"; Final script ends at DriveAudio (${drive_audio_addr:04X})",
        "",
    ]

    for label in ordered_labels:
        info = script_blocks[label]
        lines.append(
            "; "
            f"{label} - {len(info['bytes'])} bytes "
            f"(${info['start_addr']:04X}-${info['end_addr'] - 1:04X})"
        )
        lines.append(f"{label}:")
        data = info["bytes"]
        for i in range(0, len(data), 16):
            chunk = data[i : i + 16]
            lines.append("    dc.b " + ",".join(f"${byte:02X}" for byte in chunk))
        lines.append("")

    write_text_file(os.path.join(data_dir, "song_scripts.inc"), lines[:-1])


def write_pcm_samples_file(data_dir, pcm_samples):
    lines = [
        "; Raw PCM sample blob extracted from NES Zelda PRG bank 7",
        "; Auto-generated by extract_audio.py - DO NOT EDIT",
        "",
        data_to_inc_bytes(pcm_samples, "PcmSamples"),
    ]
    write_text_file(os.path.join(data_dir, "pcm_samples.inc"), lines)


def write_sfx_file(data_dir, sfx_blocks):
    ordered_labels = [
        "BombSfxNotes",
        "StairsSfxNotes",
        "SwordSfxNotes",
        "ArrowSfxNotes",
        "FlameSfxNotes",
        "SampleAddrs",
        "SampleLengths",
        "SampleRates",
    ]

    lines = [
        "; Audio SFX/sample tables extracted from NES Zelda Z_00",
        "; Auto-generated by extract_audio.py - DO NOT EDIT",
        "",
    ]

    for label in ordered_labels:
        lines.append(data_to_inc_bytes(bytes(sfx_blocks[label]), label))
        lines.append("")

    write_text_file(os.path.join(data_dir, "sfx.inc"), lines[:-1])


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)

    z00_path = os.path.join(project_root, "reference", "aldonunez", "Z_00.asm")
    z07_path = os.path.join(project_root, "reference", "aldonunez", "Z_07.asm")
    rom_path = os.path.join(project_root, "Legend of Zelda, The (USA).nes")
    data_dir = os.path.join(project_root, "src", "data")

    for required_path in [z00_path, z07_path, rom_path]:
        if not os.path.exists(required_path):
            print(f"ERROR: required file not found: {required_path}")
            sys.exit(1)

    os.makedirs(data_dir, exist_ok=True)

    print(f"Parsing reference data: {z00_path}")
    song_blocks = parse_asm_data_blocks(z00_path, SONG_LABELS)
    sfx_blocks = parse_asm_data_blocks(z00_path, SFX_LABELS)
    z07_blocks = parse_asm_data_blocks(z07_path, Z07_LABELS)
    prg_data = read_ines_prg(rom_path)
    song_script_blocks, drive_audio_addr = extract_song_scripts(prg_data, song_blocks)
    pcm_samples = extract_pcm_samples(prg_data, z07_blocks)

    music_blob, music_blob_nes_base = extract_music_blob(
        prg_data, song_script_blocks
    )

    print("\nWriting audio data files...")
    write_songs_file(data_dir, song_blocks)
    write_song_scripts_file(data_dir, song_script_blocks, drive_audio_addr)
    write_sfx_file(data_dir, sfx_blocks)
    write_pcm_samples_file(data_dir, pcm_samples)
    write_music_blob_file(data_dir, music_blob, music_blob_nes_base)

    # Write raw .dat sidecars next to the reference disassembly so the
    # transpiler's .INCBIN handler can find them on subsequent builds.
    ref_dat_dir = os.path.join(project_root, "reference", "aldonunez", "dat")
    os.makedirs(ref_dat_dir, exist_ok=True)
    for label, info in song_script_blocks.items():
        dat_path = os.path.join(ref_dat_dir, f"{label}.dat")
        with open(dat_path, "wb") as f:
            f.write(info["bytes"])
        print(f"  Wrote {dat_path} ({len(info['bytes'])} bytes)")

    total_bytes = 0
    total_bytes += sum(len(block) for block in song_blocks.values())
    total_bytes += sum(len(block["bytes"]) for block in song_script_blocks.values())
    total_bytes += sum(len(block) for block in sfx_blocks.values())
    total_bytes += len(pcm_samples)

    print("\n=== Audio extraction complete ===")
    print(f"  Total extracted audio table bytes: {total_bytes}")
    print(f"  Output directory: {data_dir}")


if __name__ == "__main__":
    main()
