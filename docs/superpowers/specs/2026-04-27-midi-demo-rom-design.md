# MIDI Demo ROM — Great Fairy's Fountain

**Date:** 2026-04-27
**Status:** Approved (user pre-approved autonomous execution)

## Goal

Standalone Genesis ROM. Shows Link sprite on screen. Plays
`Zelda - Ocarina of Time - Great Fairy's fountain.mid` looping forever
through the existing YM2612 hardware layer.

## Non-goals

- No NES APU emulation (MIDI ≠ APU register stream)
- No game logic, no input handling, no scrolling
- Not part of the main Z1 port build

## Architecture

```
Zelda... .mid                  (SMF file 1, 2 tracks, div=1024)
       |
       v
tools/midi_demo/compile_midi.py
       |  parses SMF, flattens to (frame_delta, op, ch, note, vel) stream
       |  channel allocation: round-robin first 6 active MIDI channels -> FM 0..5
       |  drum channel (10) dropped (no GM percussion mapping)
       |  MIDI note -> YM (block, fnum) lookup table
       v
tools/midi_demo/midi_data.bin  (binary event blob + note table)
       |
       v assembled via incbin
midi_player.asm
       |  per-vblank tick: decrement frame counter; when 0, dispatch events
       |  each event = note-on or note-off; writes block/fnum + key on/off
       |  uses ym_write1 / ym_write2 helpers from existing audio_driver.asm
       |    (HINT lockout not needed here; no DMC streamer in this ROM)
       v
YM2612 ch 0-5 (Voice $00 bell pad on all six)
```

Boot:

```
boot.asm  -> EntryPoint -> TMSS, Z80 stop, VDP init -> jsr main
main.c    -> palette upload, Link CHR upload, SAT entry,
             ym_init_simple, midi_init, display ON, vblank loop
```

## Channel allocation

- 6 FM voices, all loaded with EHZ Voice $00 (bell pad — fits Great Fairy
  celesta/harp arrangement)
- PSG ignored for v1 (MIDI is mostly tonal; PSG noise has no role)
- If MIDI uses more than 6 channels, lowest-numbered MIDI channels win
- New note on a busy voice steals it (no separate voice scheduler — MIDI
  channel mapping is 1:1 to FM channel)

## Event blob format

Big-endian throughout. Header:

```
u32 magic        = 'MIDI'
u32 num_events
u32 loop_offset  (byte offset into events[] where the song should jump on end)
```

Events (variable length):

```
u16 delta_frames   (frames since previous event, 60 fps)
u8  op             ($00 = note-off, $01 = note-on, $FF = end-of-song)
u8  ch             (0..5 = FM channel)
u8  block_fnum_hi  (high byte of YM $A4 reg: block<<3 | fnum_hi)
u8  fnum_lo        (YM $A0 reg)
```

End-of-song event resets the read pointer to `loop_offset` and continues.

Note-off events still carry block/fnum (ignored for off, kept for symmetric
event size — simpler reader).

## Files

```
tools/midi_demo/
    compile_midi.py     # SMF -> midi_data.bin
    boot.asm            # Genesis vectors + header + VDP init
    main.c              # palette + CHR + SAT + music dispatch loop
    link_sprite.c       # 4 hand-authored Genesis 4bpp tiles (16x16 Link front)
    link_palette.c      # 16-color palette 0
    midi_player.asm     # event-blob driven YM2612 writer
    midi_demo.ld        # link script (rom 0x000000-0x07FFFF, ram 0xFFC000+)
    build.bat           # full pipeline
docs/superpowers/specs/2026-04-27-midi-demo-rom-design.md
```

Source MIDI stays at repo root: `Zelda - Ocarina of Time - Great Fairy's fountain.mid`

Output ROM: `tools/midi_demo/out/midi_demo.md`

## Testing

1. `tools/midi_demo/build.bat` → produces `out/midi_demo.md`
2. Launch in BizHawk via the bizhawkScript skill with a probe Lua that:
   - takes a screenshot at frame 120 (2 s — Link visible, music started)
   - takes a screenshot at frame 600 (10 s — verify still playing)
   - dumps YM2612 register writes via the SymbolicEmu sound trace
3. Verify Link sprite renders correctly + audio probe shows non-silent
   YM register activity on ch 0-5

## Risks / open questions

- MIDI tempo handling: must honor SetTempo events across the whole stream.
  Compiler converts ticks -> frames using current tempo at each point.
- 60 fps quantization: short notes (< 16 ms) may collapse to 0-frame deltas.
  Compiler keeps adjacent same-frame events back-to-back (delta = 0).
- Voice $00 bell decay is slow — overlapping notes may pile up. Acceptable
  for atmospheric Great Fairy theme. Note-off forces RR via $28 key-off.
