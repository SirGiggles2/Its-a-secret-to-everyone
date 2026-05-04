#!/usr/bin/env python3
"""
midi_to_zelda_song.py

Convert a standard MIDI file into NES-Zelda song bytecode (as understood by
src/audio_driver.asm) and patch src/data/music_blob.dat in place.

Bytecode (per-channel stream):
  $00       end-of-phrase (sq1: also ends song; trg: silence; noise: wraps)
  $01-$7F   direct note id  -> NotePeriodTable[note*2] = 16-bit big-endian period
  $80-$EF   control byte    -> low 3 bits = idx into NoteLengthTables[m_len_base + idx]
                               next byte read = note id, played at this length
  $F0       (trg) end-of-passage marker
  $F1-$FF   (trg) start passage, repeat (byte - $F0) times

Self-test: round-trips the original NES-Zelda SongScriptItemTaken0 (sq1 stream)
through decode -> encode and asserts byte-identical output. Run with --self-test.
"""
import argparse
import struct
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
BLOB_PATH = REPO / "src" / "data" / "music_blob.dat"
SONGS_INC = REPO / "src" / "data" / "songs.inc"
NES_BASE = 0x8D60
ITEMTAKEN_HEADER_NES = 0x8E5D       # script ptr from header
ITEMTAKEN_HEADER_OFFSET = 0x67      # offset of 7-byte SongHeaderItemTaken0 in blob
ITEMTAKEN_SCRIPT_OFFSET = ITEMTAKEN_HEADER_NES - NES_BASE  # = 0xFD

NTSC_FRAME_HZ = 60.0988
NES_CPU_HZ = 1789773.0


# ---------------------------------------------------------------------------
# NoteLengthTables (concatenated, 5 x 8 = 40 bytes) - matches songs.inc
# ---------------------------------------------------------------------------
NOTE_LENGTH_TABLES = bytes([
    0x03, 0x0A, 0x01, 0x14, 0x05, 0x28, 0x3C, 0x70,   # Table0
    0x07, 0x1B, 0x35, 0x14, 0x0D, 0x28, 0x3C, 0x50,   # Table1
    0x06, 0x0C, 0x08, 0x18, 0x24, 0x30, 0x48, 0x10,   # Table2
    0x07, 0x0D, 0x09, 0x1B, 0x24, 0x36, 0x48, 0x10,   # Table3
    0x3C, 0x50, 0x0A, 0x05, 0x14, 0x0D, 0x28, 0x0E,   # Table4
])

# NotePeriodTable - 114 bytes, 57 entries of 16-bit big-endian periods.
# Index 0 ($0023) is a control entry: when key_off path checks lo==0, idx 0
# acts like a rest in some channels via special handling, but for melody we
# use entries whose hi:lo period maps to a real frequency.
NOTE_PERIOD_TABLE = bytes([
    0x00, 0x23, 0x00, 0x6A, 0x03, 0x27, 0x00, 0x97, 0x00, 0x00, 0x02, 0xF9,
    0x02, 0xCF, 0x02, 0xA6, 0x02, 0x80, 0x02, 0x5C, 0x02, 0x3A, 0x02, 0x1A,
    0x01, 0xFC, 0x01, 0xDF, 0x01, 0xC4, 0x01, 0xAB, 0x01, 0x93, 0x01, 0x7C,
    0x01, 0x67, 0x01, 0x53, 0x01, 0x40, 0x01, 0x2E, 0x01, 0x1D, 0x01, 0x0D,
    0x00, 0xFE, 0x00, 0xEF, 0x00, 0xE2, 0x00, 0xD5, 0x00, 0xC9, 0x00, 0xBE,
    0x00, 0xB3, 0x00, 0xA9, 0x00, 0xA0, 0x00, 0x8E, 0x00, 0x86, 0x00, 0x77,
    0x00, 0x7E, 0x00, 0x71, 0x00, 0x54, 0x00, 0x64, 0x00, 0x5F, 0x00, 0x59,
    0x00, 0x50, 0x00, 0x47, 0x00, 0x43, 0x00, 0x3F, 0x00, 0x38, 0x00, 0x32,
    0x00, 0x21, 0x05, 0x4D, 0x05, 0x01, 0x04, 0xB9, 0x04, 0x35, 0x03, 0xF8,
    0x03, 0xBF, 0x03, 0x89, 0x03, 0x57,
])


def period_to_freq(period: int) -> float:
    if period == 0:
        return 0.0
    return NES_CPU_HZ / (16.0 * (period + 1))


def freq_to_midi(freq: float) -> float:
    if freq <= 0:
        return -1
    import math
    return 69 + 12 * math.log2(freq / 440.0)


def build_note_table():
    """Return list of (nes_note_byte, period, freq, midi). nes_note_byte is even, 2..0x70."""
    out = []
    for idx in range(57):
        hi = NOTE_PERIOD_TABLE[idx * 2]
        lo = NOTE_PERIOD_TABLE[idx * 2 + 1]
        period = (hi << 8) | lo
        freq = period_to_freq(period)
        midi = freq_to_midi(freq)
        out.append((idx * 2, period, freq, midi))
    return out


def map_midi_to_nes(midi_note: int, table) -> int:
    """Find closest NES note byte for a given MIDI note number, snapping to
    semitone. Skips degenerate entries (idx 0 has lo=$23 special, idx 4 has
    period=0 = invalid)."""
    best = None
    best_err = 9e9
    for nes_byte, period, freq, midi in table:
        if period == 0 or freq < 50 or freq > 8000:
            continue
        err = abs(midi - midi_note)
        if err < best_err:
            best_err = err
            best = nes_byte
    return best


# ---------------------------------------------------------------------------
# Bytecode encode / decode
# ---------------------------------------------------------------------------

def decode_sq_stream(blob: bytes, start: int, m_len_base: int):
    """Decode an Sq1/Sq0-style stream. Returns list of dicts:
        {'note': int, 'frames': int}
    Stops at first $00 byte (sq1 song-end). For sq0, $00 is not actually
    end-of-stream (it's a direct note 0), so caller must specify max_steps."""
    out = []
    cur_len = None
    i = start
    while i < len(blob):
        b = blob[i]; i += 1
        if b == 0x00:
            out.append({'note': 0, 'frames': cur_len, 'terminator': True})
            break
        if b & 0x80:
            # control byte
            idx = b & 0x07
            cur_len = NOTE_LENGTH_TABLES[m_len_base + idx]
            # next byte is note
            note = blob[i]; i += 1
            out.append({'note': note, 'frames': cur_len, 'control': b})
        else:
            # direct note at last set length
            out.append({'note': b, 'frames': cur_len})
    return out, i


def encode_sq_stream(events, m_len_base: int, terminate=True) -> bytes:
    """Encode events [{'note':int, 'frames':int}, ...] into bytecode.
    Selects a control byte whenever the desired frame count differs from
    previous. Frames must already match an entry in NoteLengthTables[m_len_base..+8]."""
    out = bytearray()
    cur_len = None
    for ev in events:
        frames = ev['frames']
        # find the index that produces these frames
        idx = None
        for i in range(8):
            if NOTE_LENGTH_TABLES[m_len_base + i] == frames:
                idx = i
                break
        if idx is None:
            raise ValueError(f"frames={frames} not in NoteLengthTables[{m_len_base}..+8] = "
                             f"{list(NOTE_LENGTH_TABLES[m_len_base:m_len_base+8])}")
        if frames != cur_len:
            out.append(0x80 | idx)
            cur_len = frames
        out.append(ev['note'])
    if terminate:
        out.append(0x00)
    return bytes(out)


def quantize_frames(target_frames: float, m_len_base: int) -> int:
    """Pick the closest available length-table entry for target_frames."""
    options = NOTE_LENGTH_TABLES[m_len_base:m_len_base + 8]
    best = min(options, key=lambda v: abs(v - target_frames))
    return best


# ---------------------------------------------------------------------------
# MIDI parsing
# ---------------------------------------------------------------------------

def parse_midi(path: Path):
    data = path.read_bytes()
    def vlq(d, i):
        v = 0
        while True:
            b = d[i]; i += 1; v = (v << 7) | (b & 0x7f)
            if not (b & 0x80): break
        return v, i
    i = 0
    assert data[i:i+4] == b'MThd'
    size = struct.unpack('>I', data[i+4:i+8])[0]; i += 8
    fmt, trks, div = struct.unpack('>HHH', data[i:i+6]); i += size
    tempo = 500000
    chan_notes = {}     # ch -> [(start_tick, dur_ticks, note)]
    opens = {}
    while i < len(data):
        chunk = data[i:i+4]; size = struct.unpack('>I', data[i+4:i+8])[0]; i += 8
        if chunk != b'MTrk':
            i += size; continue
        end = i + size; status = 0; tick = 0
        while i < end:
            dt, i = vlq(data, i); tick += dt
            b = data[i]
            if b & 0x80: status = b; i += 1
            ev = status
            if ev == 0xff:
                meta = data[i]; i += 1; ln, i = vlq(data, i); payload = data[i:i+ln]; i += ln
                if meta == 0x51 and ln == 3:
                    tempo = int.from_bytes(payload, 'big')
            elif 0xc0 <= ev <= 0xdf:
                i += 1
            elif 0xe0 <= ev <= 0xef:
                i += 2
            elif 0x80 <= ev <= 0xbf:
                p1 = data[i]; p2 = data[i+1]; i += 2
                ch = ev & 0x0f
                if 0x90 <= ev <= 0x9f and p2 > 0:
                    opens[(ch, p1)] = tick
                elif (0x80 <= ev <= 0x8f) or (0x90 <= ev <= 0x9f and p2 == 0):
                    if (ch, p1) in opens:
                        start = opens.pop((ch, p1))
                        chan_notes.setdefault(ch, []).append((start, tick - start, p1))
            else:
                i += 1
    return {'ppqn': div, 'tempo_us': tempo, 'channels': chan_notes}


def midi_channel_to_events(midi, ch, m_len_base):
    """Convert MIDI channel to bytecode events list using START-time deltas
    (NES sequencer plays note_i for length frames, then triggers note_i+1)."""
    notes = sorted(midi['channels'][ch])
    if not notes:
        return []
    ppqn = midi['ppqn']
    # us_per_tick = tempo_us / ppqn
    us_per_tick = midi['tempo_us'] / ppqn
    table = build_note_table()
    events = []
    starts = [n[0] for n in notes] + [notes[-1][0] + notes[-1][1]]
    for i, (start, _dur, midi_note) in enumerate(notes):
        delta_ticks = starts[i + 1] - starts[i]
        delta_us = delta_ticks * us_per_tick
        delta_frames = delta_us * 1e-6 * NTSC_FRAME_HZ
        frames = quantize_frames(delta_frames, m_len_base)
        nes_byte = map_midi_to_nes(midi_note, table)
        events.append({'note': nes_byte, 'frames': frames})
    return events


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

def self_test():
    blob = BLOB_PATH.read_bytes()
    print(f"music_blob.dat size = {len(blob)}")
    # ItemTaken header at offset 0x67: $10 $5D $8E $0D $07 $00 $80
    hdr = blob[ITEMTAKEN_HEADER_OFFSET:ITEMTAKEN_HEADER_OFFSET + 7]
    print(f"ItemTaken header @ 0x{ITEMTAKEN_HEADER_OFFSET:04X}: {hdr.hex()}")
    assert hdr == bytes.fromhex('105D8E0D070080'), f"unexpected header: {hdr.hex()}"
    m_len_base = hdr[0]   # $10
    sq1_stream = blob[ITEMTAKEN_SCRIPT_OFFSET:ITEMTAKEN_SCRIPT_OFFSET + 7]
    print(f"sq1 stream         : {sq1_stream.hex()}")
    expected = bytes.fromhex('811E202285240081'[:14])  # 7 bytes
    assert sq1_stream == bytes.fromhex('811e2022852400'), f"sq1 mismatch: {sq1_stream.hex()}"

    # Decode
    events, _ = decode_sq_stream(blob, ITEMTAKEN_SCRIPT_OFFSET, m_len_base)
    print("decoded events:")
    for e in events:
        print(f"  note=${e['note']:02X} frames={e['frames']} terminator={e.get('terminator', False)}")

    # Encode (drop the synthesized terminator event from the events list,
    # since encode_sq_stream re-adds it via terminate=True)
    melody = [e for e in events if not e.get('terminator')]
    re_encoded = encode_sq_stream(melody, m_len_base, terminate=True)
    print(f"re-encoded         : {re_encoded.hex()}")
    print(f"original           : {sq1_stream.hex()}")
    assert re_encoded == sq1_stream, "ROUND-TRIP FAILED"
    print("OK: round-trip byte-identical")

    # Show MIDI->NES mapping for our target notes
    table = build_note_table()
    print("\nMIDI -> NES note byte mapping (LA get-item notes):")
    for m in [65, 66, 67, 68, 69, 70, 72, 73, 74, 75, 76, 77, 81, 82, 83, 84, 85, 86]:
        nb = map_midi_to_nes(m, table)
        for entry in table:
            if entry[0] == nb:
                _, period, freq, midi = entry
                print(f"  MIDI {m:3d} -> NES ${nb:02X} (period ${period:04X}, {freq:.1f} Hz, ~MIDI {midi:.2f})")
                break


# ---------------------------------------------------------------------------
# Main: convert + dump info
# ---------------------------------------------------------------------------

def show_conversion(midi_path, m_len_base):
    midi = parse_midi(midi_path)
    print(f"MIDI: ppqn={midi['ppqn']} tempo_us={midi['tempo_us']} channels={sorted(midi['channels'])}")
    for ch in [0, 2]:
        if ch not in midi['channels']:
            continue
        evs = midi_channel_to_events(midi, ch, m_len_base)
        print(f"\nch{ch} -> events ({len(evs)}):")
        for e in evs:
            print(f"  ${e['note']:02X} frames={e['frames']}")
        encoded = encode_sq_stream(evs, m_len_base, terminate=(ch == 0))
        print(f"ch{ch} bytecode: {encoded.hex()} ({len(encoded)} bytes)")


def build_la_sq1_7byte():
    """Build a 7-byte LA Get-Item sq1 replacement that fits the original slot
    exactly (no header changes, no MusicBlob size change, no shifting of
    downstream song data). Takes 4 notes from MIDI ch0: notes 81, 82, 83, 86
    (the iconic ascending-fanfare-then-stab shape, in LA voicing).

    Encoding:
        $82                control: m_len_base=$10 + idx 2 -> Table2[2] = 8 frames
        $48 $46 $4A        3 short notes (MIDI 81, 82, 83 -> NES note bytes)
        $86                control: idx 6 -> Table2[6] = 72 frames
        $50                long stab note (MIDI 86)
        $00                end-of-phrase
    Total: 7 bytes (matches original)."""
    m_len_base = 0x10
    table = build_note_table()
    notes = [81, 82, 83, 86]
    nes_bytes = [map_midi_to_nes(n, table) for n in notes]
    # 3 short + 1 long
    events = [
        {'note': nes_bytes[0], 'frames': NOTE_LENGTH_TABLES[m_len_base + 2]},  # 8 fr
        {'note': nes_bytes[1], 'frames': NOTE_LENGTH_TABLES[m_len_base + 2]},
        {'note': nes_bytes[2], 'frames': NOTE_LENGTH_TABLES[m_len_base + 2]},
        {'note': nes_bytes[3], 'frames': NOTE_LENGTH_TABLES[m_len_base + 6]},  # 72 fr
    ]
    return encode_sq_stream(events, m_len_base, terminate=True)


def patch_blob(midi_path: Path, dry_run=False):
    """In-place 7-byte replacement of SongScriptItemTaken0 in music_blob.dat.
    Header stays identical; only the script bytes at offset 0xFD change.
    No size change -> no need to update MUSIC_BLOB_SIZE or shift song scripts.
    midi_path is unused (LA reduction is hand-curated to fit), kept for CLI
    parity."""
    new_sq1 = build_la_sq1_7byte()
    assert len(new_sq1) == 7, f"new sq1 must be 7 bytes, got {len(new_sq1)}"
    blob = bytearray(BLOB_PATH.read_bytes())
    original = blob[ITEMTAKEN_SCRIPT_OFFSET:ITEMTAKEN_SCRIPT_OFFSET + 7]

    blob[ITEMTAKEN_SCRIPT_OFFSET:ITEMTAKEN_SCRIPT_OFFSET + 7] = new_sq1

    print(f"music_blob.dat size     : {len(blob)} (unchanged)")
    print(f"Original sq1 (offset 0xFD): {original.hex()}")
    print(f"New sq1     (offset 0xFD): {new_sq1.hex()}")
    print(f"  Plays MIDI notes [81,82,83,86] = LA Get-Item ascending fanfare + stab")

    if dry_run:
        print('[dry-run] no files written')
        return

    bak = BLOB_PATH.with_suffix('.dat.bak')
    if not bak.exists():
        bak.write_bytes(bytes(BLOB_PATH.read_bytes()))
        print(f"Backed up original to   : {bak}")

    BLOB_PATH.write_bytes(bytes(blob))
    print(f"Wrote                   : {BLOB_PATH}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--self-test', action='store_true')
    ap.add_argument('--show', metavar='MIDI', help='show conversion of MIDI file')
    ap.add_argument('--patch', metavar='MIDI', help='patch music_blob.dat with new ItemTaken from MIDI')
    ap.add_argument('--dry-run', action='store_true', help='used with --patch: print without writing')
    args = ap.parse_args()
    if args.self_test:
        self_test()
    elif args.show:
        show_conversion(Path(args.show), m_len_base=0x10)
    elif args.patch:
        patch_blob(Path(args.patch), dry_run=args.dry_run)
    else:
        ap.print_help()


if __name__ == '__main__':
    main()
