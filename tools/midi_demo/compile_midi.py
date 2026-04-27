#!/usr/bin/env python3
"""compile_midi.py - Compile a Standard MIDI File into a compact event blob
for the midi_demo ROM.

Output binary layout (big-endian):

    magic        u32   = b'MIDI'
    num_events   u32
    loop_offset  u32   (byte offset relative to start of events[] where the
                        song should resume after end-of-song)
    events[N]    each = u16 delta_frames | u8 op | u8 ch | u8 bf_hi | u8 fnum_lo

Ops:
    0x00 = note-off
    0x01 = note-on
    0xFF = end-of-song (loops to loop_offset)

Channel allocation: first 6 distinct MIDI channels (excluding 9 = drums)
encountered are mapped 1:1 onto FM channels 0..5.  Notes on unmapped
channels are dropped.

YM2612 frequency table (block, fnum) precomputed for MIDI notes 0..127.

Usage: compile_midi.py input.mid output.bin
"""

import struct
import sys
from pathlib import Path

YM_CLOCK = 7670453
NES_FRAME_HZ = 60  # NTSC
DRUM_CHANNEL = 9  # GM drums

# ----------------------------------------------------------------------
# Build YM block/fnum table for MIDI notes 0..127
# ----------------------------------------------------------------------

def midi_to_ym(note: int) -> tuple[int, int]:
    """Return (block 0..7, fnum 0..2047) for a MIDI note number."""
    if note < 12:
        note = 12  # clamp - YM block 0 lower than this is unusable
    if note > 119:
        note = 119  # clamp - keep block <= 7
    hz = 440.0 * (2.0 ** ((note - 69) / 12.0))
    # F = (Hz * 144 * 2^20) / (clock * 2^block); pick block so 1024 <= F < 2048
    for block in range(8):
        f = (hz * 144 * (1 << 20)) / (YM_CLOCK * (1 << block))
        if 1024.0 <= f < 2048.0:
            return block, int(round(f))
    # fallback
    block = 4
    f = (hz * 144 * (1 << 20)) / (YM_CLOCK * (1 << block))
    return block, max(0, min(2047, int(round(f))))


# ----------------------------------------------------------------------
# SMF parser (variable length quantity + chunked event stream)
# ----------------------------------------------------------------------

def read_vlq(data: bytes, i: int) -> tuple[int, int]:
    val = 0
    while True:
        b = data[i]
        i += 1
        val = (val << 7) | (b & 0x7F)
        if not (b & 0x80):
            return val, i


def parse_track(data: bytes) -> list[tuple[int, str, tuple]]:
    """Return list of (abs_tick, kind, payload)."""
    out = []
    tick = 0
    i = 0
    running = None
    while i < len(data):
        delta, i = read_vlq(data, i)
        tick += delta
        b = data[i]
        if b < 0x80:
            # running status
            status = running
        else:
            status = b
            i += 1
            running = status if status < 0xF0 else None

        if status == 0xFF:
            mtype = data[i]; i += 1
            mlen, i = read_vlq(data, i)
            payload = data[i:i+mlen]; i += mlen
            if mtype == 0x51 and mlen == 3:
                tempo = (payload[0] << 16) | (payload[1] << 8) | payload[2]
                out.append((tick, 'tempo', (tempo,)))
            elif mtype == 0x2F:
                out.append((tick, 'eot', ()))
                break
            # ignore other meta
        elif status in (0xF0, 0xF7):
            mlen, i = read_vlq(data, i)
            i += mlen  # ignore sysex
        else:
            hi = status & 0xF0
            ch = status & 0x0F
            if hi in (0x80, 0x90):
                note = data[i]; vel = data[i+1]; i += 2
                if hi == 0x90 and vel > 0:
                    out.append((tick, 'on', (ch, note, vel)))
                else:
                    out.append((tick, 'off', (ch, note)))
            elif hi in (0xA0, 0xB0, 0xE0):
                i += 2
            elif hi in (0xC0, 0xD0):
                i += 1
    return out


def parse_smf(path: Path) -> tuple[int, list[list[tuple[int, str, tuple]]]]:
    raw = path.read_bytes()
    assert raw[:4] == b'MThd'
    fmt, ntrk, div = struct.unpack('>HHH', raw[8:14])
    tracks = []
    i = 14
    while i < len(raw):
        cid = raw[i:i+4]; sz = struct.unpack('>I', raw[i+4:i+8])[0]
        if cid == b'MTrk':
            tracks.append(parse_track(raw[i+8:i+8+sz]))
        i += 8 + sz
    return div, tracks


# ----------------------------------------------------------------------
# Compile to event blob
# ----------------------------------------------------------------------

def compile_song(midi_path: Path) -> bytes:
    div, tracks = parse_smf(midi_path)

    # Merge all tracks, sort by abs_tick (stable for same-tick events)
    merged: list[tuple[int, str, tuple]] = []
    for t in tracks:
        merged.extend(t)
    merged.sort(key=lambda e: (e[0], 0 if e[1] == 'tempo' else 1))

    # Walk events, converting ticks -> frames.
    events_out: list[tuple[int, int, int, int, int]] = []
    # (abs_frame_q, op, ch, bf_hi, fnum_lo)

    NUM_FM = 6
    # Two voice pools:
    #   ch 0..2 = HARP (lead, notes >= LEAD_THRESHOLD)
    #   ch 3..5 = BELL (backup, notes < LEAD_THRESHOLD)
    # Each FM voice holds the (midi_ch, note) that owns it plus a serial
    # for oldest-first stealing within the pool.
    LEAD_THRESHOLD = 67  # MIDI G4 — anything at/above plays on harp
    voice_owner: list[tuple[int, int] | None] = [None] * NUM_FM
    voice_age:   list[int]                    = [0]    * NUM_FM
    serial = 0

    def pool_for(note: int) -> tuple[int, int]:
        if note >= LEAD_THRESHOLD:
            return (0, 3)            # harp pool: ch 0,1,2
        return (3, 6)                # bell pool: ch 3,4,5

    def voice_alloc(midi_ch: int, note: int) -> int:
        nonlocal serial
        serial += 1
        lo, hi = pool_for(note)
        for i in range(lo, hi):
            if voice_owner[i] is None:
                voice_owner[i] = (midi_ch, note)
                voice_age[i] = serial
                return i
        i = min(range(lo, hi), key=lambda k: voice_age[k])
        voice_owner[i] = (midi_ch, note)
        voice_age[i] = serial
        return i

    def voice_release(midi_ch: int, note: int) -> int | None:
        for i in range(NUM_FM):
            if voice_owner[i] == (midi_ch, note):
                voice_owner[i] = None
                return i
        return None

    tempo_us_per_quarter = 500000  # default 120 BPM
    cur_tick = 0
    cur_frame = 0.0

    def tick_to_frame(target_tick: int) -> float:
        nonlocal cur_tick, cur_frame
        dtick = target_tick - cur_tick
        secs = dtick * tempo_us_per_quarter / (div * 1_000_000.0)
        cur_frame += secs * NES_FRAME_HZ
        cur_tick = target_tick
        return cur_frame

    for tick, kind, payload in merged:
        f = tick_to_frame(tick)
        if kind == 'tempo':
            tempo_us_per_quarter = payload[0]
            continue
        if kind == 'eot':
            continue
        if kind == 'on':
            ch, note, vel = payload
            if ch == DRUM_CHANNEL:
                continue
            # If the same (ch,note) is already sounding, release it first
            # so a key-off / key-on pair retriggers the envelope cleanly.
            existing = voice_release(ch, note)
            if existing is not None:
                # Pitch shift used for the previous note depends on which
                # pool it was on; recompute via the pool ranges.
                shifted = note + (24 if existing >= 3 else 0)
                block, fnum = midi_to_ym(shifted)
                bf_hi = ((block & 7) << 3) | ((fnum >> 8) & 7)
                fnum_lo = fnum & 0xFF
                events_out.append((int(round(f)), 0x00, existing, bf_hi, fnum_lo))
            fm = voice_alloc(ch, note)
            played = note + (24 if fm >= 3 else 0)  # backup transposed +1 oct
            block, fnum = midi_to_ym(played)
            bf_hi = ((block & 7) << 3) | ((fnum >> 8) & 7)
            fnum_lo = fnum & 0xFF
            events_out.append((int(round(f)), 0x00, fm, bf_hi, fnum_lo))
            events_out.append((int(round(f)), 0x01, fm, bf_hi, fnum_lo))
        elif kind == 'off':
            ch, note = payload
            fm = voice_release(ch, note)
            if fm is None:
                continue
            played = note + (24 if fm >= 3 else 0)
            block, fnum = midi_to_ym(played)
            bf_hi = ((block & 7) << 3) | ((fnum >> 8) & 7)
            fnum_lo = fnum & 0xFF
            events_out.append((int(round(f)), 0x00, fm, bf_hi, fnum_lo))

    if not events_out:
        raise SystemExit('No usable events extracted from MIDI')

    # Convert absolute frames -> deltas, clamping to u16.
    blob = bytearray()
    prev_frame = 0
    for abs_f, op, ch, bf_hi, fnum_lo in events_out:
        d = abs_f - prev_frame
        prev_frame = abs_f
        while d > 0xFFFF:
            blob += struct.pack('>HBBBB', 0xFFFF, 0x00, 0xFF, 0, 0)  # filler no-op
            d -= 0xFFFF
        blob += struct.pack('>HBBBB', d, op, ch, bf_hi, fnum_lo)

    # Append end-of-song event with delta = 0 (loops immediately).
    blob += struct.pack('>HBBBB', 0, 0xFF, 0, 0, 0)

    num_events = len(blob) // 6
    # Build header.  loop_offset = 0 (loop entire song from start).
    header = struct.pack('>4sII', b'MIDI', num_events, 0)
    return header + bytes(blob)


def main() -> int:
    if len(sys.argv) != 3:
        print('Usage: compile_midi.py input.mid output.bin', file=sys.stderr)
        return 2
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    blob = compile_song(src)
    dst.write_bytes(blob)
    print(f'compile_midi: wrote {len(blob)} bytes -> {dst}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
