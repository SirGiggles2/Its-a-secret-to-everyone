# NES → Sega Genesis Converter Reference

A practical guide for porting NES games to the Sega Genesis (Mega Drive) using an automated 6502→M68K transpiler approach. Everything here is grounded in building this actual port of *The Legend of Zelda*.

---

## Table of Contents

1. [Approach Overview](#approach-overview)
2. [CPU Register Mapping](#cpu-register-mapping)
3. [6502 → M68K Instruction Translation](#6502--m68k-instruction-translation)
4. [NES Memory Map → Genesis Memory Map](#nes-memory-map--genesis-memory-map)
5. [PPU → VDP](#ppu--vdp)
6. [APU → YM2612 / PSG](#apu--ym2612--psg)
7. [Controller → Genesis Joypad](#controller--genesis-joypad)
8. [MMC Mapper Emulation](#mmc-mapper-emulation)
9. [Genesis ROM Header](#genesis-rom-header)
10. [VDP Register Init (H32 mode)](#vdp-register-init-h32-mode)
11. [VRAM Layout](#vram-layout)
12. [Genesis Boot Sequence](#genesis-boot-sequence)
13. [Exception Handling & Forensics](#exception-handling--forensics)
14. [Critical Correctness Rules](#critical-correctness-rules)
15. [Build System](#build-system)
16. [Probe / Test Harness](#probe--test-harness)
17. [Common Bugs & How to Diagnose Them](#common-bugs--how-to-diagnose-them)
18. [Transpiler Architecture Checklist](#transpiler-architecture-checklist)

---

## Approach Overview

**Manual reimplementation** (rewriting the game from scratch in M68K) is extremely slow and error-prone — a single game can take hundreds of builds. The smarter approach, proven by the 2010 *Super Mario Bros.* Genesis port and this project, is:

1. **Automatically transpile** the original 6502 disassembly to M68K assembly.
2. **Keep all original data** (tilemaps, palettes, enemy AI tables, audio data) untouched.
3. **Write only the I/O shim** — a layer that intercepts NES hardware register reads/writes and redirects them to Genesis hardware equivalents.

This yields ~75% of the ROM being actual game code, just running on different silicon. Behavioral accuracy is guaranteed by construction.

**Source material needed:**
- A labeled, commented 6502 disassembly (e.g., the aldonunez Zelda disassembly). Raw binary disassembly works but is harder.
- Genesis hardware documentation (sega2f / Charles MacDonald VDP docs).
- A debuggable emulator (BizHawk with Lua scripting is ideal).

---

## CPU Register Mapping

| 6502 | M68K | Notes |
|------|------|-------|
| A (accumulator) | D0 | All loads/stores use `.B` size |
| X index | D2 | |
| Y index | D3 | |
| SP (stack pointer) | A5 | NES stack at $01xx; A5 = `NES_RAM_BASE + $0200`. First PHA decrements to $01FF. |
| PC | natural M68K PC | — |
| Carry | X flag | Use ROXL/ROXR for rotates; ADDX/SUBX for carry chains |
| Zero | Z flag | Direct M68K equivalent |
| Negative | N flag | Direct M68K equivalent |
| Overflow | V flag | Direct M68K equivalent |

**Permanent register allocation (Genesis shell, never scratch):**

| Register | Value | Purpose |
|----------|-------|---------|
| A4 | `$FF0000` | NES RAM base — all NES zero-page/work-RAM accesses use `(offset,A4)` |
| A5 | `$FF0200` | NES stack pointer (grows downward) |
| D7 | `$FF` | NES SP shadow (used by TSX/TXS) |

---

## 6502 → M68K Instruction Translation

### Loads and Stores

| 6502 | M68K |
|------|------|
| `LDA #n` | `move.b #n, D0` |
| `LDA $zp` | `move.b ($00zp,A4), D0` |
| `LDA $addr` | `move.b ($addr).w, D0` |
| `LDA $addr,X` | `move.b ($addr,D2.w), D0` |
| `LDA $addr,Y` | `move.b ($addr,D3.w), D0` |
| `LDA ($zp),Y` | `movea.w ($00zp,A4),A0` / `move.b (0,A0,D3.w), D0` |
| `LDA ($zp,X)` | `movea.w ($00zp,D2.w), A0` / `move.b (A0), D0` |
| `STA $addr` | `move.b D0, ($addr).w` |
| `STX $addr` | `move.b D2, ($addr).w` — **NEVER touches D0** |
| `STY $addr` | `move.b D3, ($addr).w` — **NEVER touches D0** |
| `LDX #n` | `moveq #n, D2` (then `and.w #$FF, D2` if sign matters) |
| `LDY #n` | `moveq #n, D3` |

> **Critical:** STX and STY do **not** modify A on the 6502. If your transpiler's write function routes through D0 (e.g. to call a PPU/APU stub), it must save and restore D0 around the stub call. Failure to do so corrupts the accumulator silently and produces very hard-to-debug logic errors.

### Register Transfers

| 6502 | M68K |
|------|------|
| `TAX` | `move.b D0, D2` |
| `TAY` | `move.b D0, D3` |
| `TXA` | `move.b D2, D0` |
| `TYA` | `move.b D3, D0` |
| `TXS` | `move.b D2, D7` (SP shadow); `movea.l #NES_STACK_BASE, A5`; adjust A5 |
| `TSX` | `move.b D7, D2` |

### Arithmetic

| 6502 | M68K |
|------|------|
| `ADC #n` | Set X from C: `move.b #0,D1; addx.b D1,D1`; then `add.b #n, D0` |
| `SBC #n` | Set X from C; `subx.b ...`; `sub.b #n, D0` |
| `INC $addr` | `addq.b #1, ($addr).w` |
| `DEC $addr` | `subq.b #1, ($addr).w` |
| `INX` | `addq.b #1, D2` |
| `DEX` | `subq.b #1, D2` |
| `INY` | `addq.b #1, D3` |
| `DEY` | `subq.b #1, D3` |

### Logic

| 6502 | M68K |
|------|------|
| `AND #n` | `andi.b #n, D0` |
| `ORA #n` | `ori.b #n, D0` |
| `EOR #n` | `eori.b #n, D0` |
| `ASL A` | `lsl.b #1, D0` |
| `LSR A` | `lsr.b #1, D0` |
| `ROL A` | `roxl.b #1, D0` (uses X flag as carry-in) |
| `ROR A` | `roxr.b #1, D0` |
| `BIT $addr` | `move.b ($addr).w, D1; tst.b D1` (sets N/V from mem bits 7/6, Z from AND) |

### Branches

**Important — carry flag inversion:** After 6502 `CMP`, `CPX`, `CPY`, `SBC`, the M68K C flag is **inverted** relative to 6502. On 6502, CMP sets C=1 when A ≥ operand. On M68K, CMPI sets C=1 when A < operand (borrow). You must swap BCS↔BCC after any compare or SBC.

| 6502 | M68K (normal) | M68K (after CMP/SBC) |
|------|---------------|----------------------|
| `BEQ` | `beq` | `beq` |
| `BNE` | `bne` | `bne` |
| `BCC` | `bcc` | **`bcs`** |
| `BCS` | `bcs` | **`bcc`** |
| `BPL` | `bpl` | `bpl` |
| `BMI` | `bmi` | `bmi` |
| `BVC` | `bvc` | `bvc` |
| `BVS` | `bvs` | `bvs` |

Track this with a `carry_inverted` flag in your transpiler that sets on CMP/CPX/CPY/SBC and clears at every label and after ADC/shifts/SEC/CLC.

### Jumps and Calls

| 6502 | M68K |
|------|------|
| `JMP $addr` | `jmp ($addr).l` |
| `JMP ($addr)` | `movea.w ($addr).w, A0; jmp (A0)` |
| `JSR $addr` | `bsr $addr` |
| `RTS` | `rts` |
| `RTI` | `rts` (**NOT** `rte` — see Critical Rules below) |

### Stack

| 6502 | M68K |
|------|------|
| `PHA` | `move.b D0, -(A5)` |
| `PLA` | `move.b (A5)+, D0` |
| `PHP` | Push CCR manually to NES stack |
| `PLP` | Pop NES stack into CCR |

### Flags

| 6502 | M68K |
|------|------|
| `SEC` | `ori.b #$10, CCR` (set X flag = NES carry) |
| `CLC` | `andi.b #$EF, CCR` |
| `SEI` | **NOP** (see Critical Rules) |
| `CLI` | `andi.w #$F8FF, SR` |
| `NOP` | `nop` |

### TableJump Pattern (6502 JSR trick)

Many NES games use an idiom where `JSR TableJump` is followed immediately by a table of addresses. The called routine reads the return address off the stack to find the table, then indexes into it using the accumulator as a mode byte.

**M68K replacement — `_m68k_tablejump`:**

```asm
_m68k_tablejump:
    movea.l (SP)+, A0       ; pop BSR return addr = pointer to table[0]
    and.w   #$00FF, D0      ; zero-extend mode byte
    lsl.w   #2, D0          ; D0 = index × 4 (32-bit entries)
    movea.l (A0,D0.w), A0   ; load 32-bit handler address
    jmp     (A0)            ; dispatch — no return
```

In the transpiler output, each `JSR TableJump` becomes:
```asm
    bsr     _m68k_tablejump
table_label:
    dc.l    Handler0        ; 32-bit M68K addresses, one per mode
    dc.l    Handler1
    ...
```

The original 6502 tables use 16-bit addresses. Your transpiler must convert each table entry to a 32-bit `dc.l` with the resolved M68K label.

> **Watch out:** NES interrupt vectors at the end of the fixed bank (`$FFFA-$FFFF`) look like table entries but must NOT be dispatched via `_m68k_tablejump`. They are just data (`dc.l IsrNmi`, `dc.l IsrReset`, etc.).

---

## NES Memory Map → Genesis Memory Map

| NES Address | Size | Purpose | Genesis Mapping |
|-------------|------|---------|----------------|
| `$0000-$00FF` | 256 B | Zero page | `$FF0000-$FF00FF` (A4+offset) |
| `$0100-$01FF` | 256 B | Stack | `$FF0100-$FF01FF` (A5 grows down) |
| `$0200-$07FF` | 1.5 KB | Work RAM | `$FF0200-$FF07FF` (A4+offset) |
| `$2000-$2007` | 8 B | PPU registers | `nes_io.asm` BSR stubs |
| `$4000-$4013` | 20 B | APU registers | `nes_io.asm` BSR stubs (or silence) |
| `$4014` | 1 B | OAM DMA | `nes_io.asm` BSR stub → sprite upload |
| `$4016-$4017` | 2 B | Controller I/O | `nes_io.asm` BSR stubs → Genesis joypad |
| `$6000-$7FFF` | 8 KB | SRAM (MMC1) | Genesis SRAM (if needed) or Genesis RAM |
| `$8000-$BFFF` | 16 KB | Switchable PRG bank | Genesis ROM (bank window) |
| `$C000-$FFFF` | 16 KB | Fixed PRG bank | Genesis ROM (fixed segment) |
| `$0000-$1FFF` (CHR) | 8 KB | CHR-RAM (PPU) | Genesis VRAM `$0000-$AFFF` (tiles) |
| `$2000-$3FFF` (PPU) | 8 KB | Nametables/attributes | Genesis VRAM `$C000-$CFFF` (Plane A) |
| `$3F00-$3F1F` (PPU) | 32 B | Palette | Genesis CRAM (64 colors × 2 bytes) |

**NES RAM base:** Allocate 2KB at top of Genesis RAM: `$FF0000`. This is addressable via `(offset,A4)` for all NES RAM accesses.

---

## PPU → VDP

### PPU State Block (RAM at `$FF0800`)

Maintain an 12-byte block in Genesis RAM to shadow NES PPU register state:

| Offset | Symbol | Size | Description |
|--------|--------|------|-------------|
| +0 | `PPU_LATCH` | byte | PPUADDR/PPUSCROLL w-register (0=high byte next, 1=low byte next) |
| +1 | (pad) | byte | — |
| +2 | `PPU_VADDR` | word | Current PPUADDR pointer (accumulated from two writes to $2006) |
| +4 | `PPU_CTRL` | byte | $2000 — NMI enable (bit 7), BG table (bit 4), sprite table (bit 3), vram inc (bit 2) |
| +5 | `PPU_MASK` | byte | $2001 — display enable flags |
| +6 | `PPU_SCRL_X` | byte | X scroll (first $2005 write) |
| +7 | `PPU_SCRL_Y` | byte | Y scroll (second $2005 write) |
| +8 | `PPU_DBUF` | byte | PPUDATA byte buffer (even address → stash here) |
| +9 | `PPU_DHALF` | byte | 0 = even half pending, 1 = odd half pending |

### $2000 PPUCTRL

- Bit 7: NMI enable → gate VBlankISR on this bit before calling IsrNmi
- Bit 4: BG table select (0=$0000, 1=$1000 in CHR) → Genesis tile index offset
- Bit 3: Sprite table select (0=$0000, 1=$1000)
- Bit 2: VRAM address increment (0=+1 horizontal, 1=+32 vertical) → after each PPUDATA write
- Bits 1-0: Nametable base select (usually irrelevant for M68K mapping)

### $2002 PPUSTATUS (read)

- Bit 7: VBlank flag — return `$80` during boot so IsrReset's warmup polling loops exit immediately.
- Reading $2002 clears the **w-register** (PPU_LATCH = 0).

### $2005 PPUSCROLL

Two consecutive writes: first = X scroll, second = Y scroll. Share the w-register with $2006.

### $2006 PPUADDR

Two consecutive writes latch a 14-bit VRAM address (bit 14 always cleared on first write). Store in `PPU_VADDR`. After both writes, emit the VDP VRAM write command:

```asm
; Compose VDP VRAM write command: CD1 CD0 A13..A0 | 0 0 CD5..CD2 A15..A14
; For VRAM write: CD = %0001
; cmd_hi = $4000 | (addr & $3FFF)
; cmd_lo = (addr >> 14) & 3  (always 0 for <16KB VRAM)
```

### $2007 PPUDATA (write)

NES games write CHR tile data and nametable data byte-by-byte to $2007. Because the Genesis VDP takes word writes, buffer every two bytes:

1. Even PPUADDR → store byte in `PPU_DBUF`, set `PPU_DHALF=1`
2. Odd PPUADDR → assemble `word = (PPU_DBUF << 8) | current_byte`, set VDP address, write word to `VDP_DATA`, clear `PPU_DHALF`
3. After each write, advance `PPU_VADDR` by 1 (or 32 if PPUCTRL bit 2 set)

The VDP address command (to `VDP_CTRL`) must be re-sent before each word write since the NES allows arbitrary seeks within the frame.

**VRAM destination by PPUADDR range:**

| PPUADDR range | Content | Genesis VRAM destination |
|---------------|---------|--------------------------|
| `$0000-$1FFF` | CHR-RAM tile data (2bpp) | `$0000-$AFFF` (tiles, after 2bpp→4bpp conversion) |
| `$2000-$23FF` | Nametable 0 | Plane A at `$C000` |
| `$2400-$27FF` | Nametable 1 | Plane A mirror or Plane B at `$E000` |
| `$2800-$2BFF` | Nametable 2 | Plane A at `$C000` (mirrored, or second page) |
| `$2C00-$2FFF` | Nametable 3 | — |
| `$3F00-$3F1F` | Palette | Genesis CRAM |

### CHR-RAM 2bpp → 4bpp Conversion

NES tile format: 16 bytes per 8×8 tile, 2 bitplanes stored separately.
- Bytes 0-7: bitplane 0 (LSB of each pixel in a row)
- Bytes 8-15: bitplane 1 (MSB of each pixel in a row)

Genesis tile format: 32 bytes per 8×8 tile, 4 bits per pixel, packed.

Conversion per row (1 byte from each NES plane → 4 Genesis nibbles of 4 bits each):
```
nes_plane0 = bitplane_low_byte
nes_plane1 = bitplane_high_byte
For each bit i (7..0):
    genesis_pixel[7-i] = ((nes_plane1 >> i) & 1) << 1 | ((nes_plane0 >> i) & 1)
```

### Palette ($3F00-$3F1F) → CRAM

NES palette entries are indices into the NES master palette (54 colors). Map to Genesis RGB444 colors by lookup table. Genesis CRAM format: `0BBB0GGG0RRR0` (bits 11:9=B, 7:5=G, 3:1=R).

Write to CRAM by setting VDP CRAM write command then writing 16-bit color words.

---

## APU → YM2612 / PSG

| NES APU | Genesis Equivalent |
|---------|--------------------|
| Pulse 1 ($4000-$4003) | YM2612 FM channel 1 or PSG tone 0 |
| Pulse 2 ($4004-$4007) | YM2612 FM channel 2 or PSG tone 1 |
| Triangle ($4008-$400B) | YM2612 FM channel 3 (no volume control) or PSG tone 2 |
| Noise ($400C-$400F) | PSG noise channel |
| DMC ($4010-$4013) | PSG or silence (Zelda barely uses it) |
| $4015 APU control | Enable/disable channels |

**For a first pass:** stub all APU writes as silent (just `rts`). Get the video working first. Audio can be layered on after T14 equivalent.

**YM2612 basics:**
- Address port: `$A04000` (chip 1), `$A04002` (chip 2)
- Data port: `$A04001` (chip 1), `$A04003` (chip 2)
- Key-on: register `$28`, `data = (slot_mask << 4) | channel`
- PSG: `$C00011` (write-only, 8-bit, format `1CCCXXXX` then `0XXXXXXX`)

---

## Controller → Genesis Joypad

NES controller protocol: game writes 1 then 0 to $4016 to latch buttons, then reads $4016/$4017 one bit at a time.

Genesis joypad: read `$A10003` (port 1) or `$A10005` (port 2). 6-button protocol needs TH line toggling; 3-button is simpler.

**Button mapping:**

| NES | Genesis |
|-----|---------|
| A | C (or A) |
| B | B |
| Select | Start / Mode |
| Start | Start |
| D-pad | D-pad |

For `LDA $4016`: read the Genesis port, translate buttons to the NES serial format the game expects. Games typically read 8 bits in a loop.

---

## MMC Mapper Emulation

### MMC1 (Zelda, Metroid, Mega Man 2, many others)

MMC1 is configured via 5 consecutive bit-serial writes to `$8000-$FFFF`. Each write shifts one bit into a 5-bit shift register; the 5th write commits the value to one of four internal registers:

| Address | Register | Function |
|---------|----------|---------|
| `$8000-$9FFF` | Control | Mirroring, PRG bank mode, CHR bank mode |
| `$A000-$BFFF` | CHR bank 0 | Select 4KB CHR bank for $0000 |
| `$C000-$DFFF` | CHR bank 1 | Select 4KB CHR bank for $1000 |
| `$E000-$FFFF` | PRG bank | Select 16KB PRG bank |

For the transpiler approach: since all PRG banks are included as sections in the Genesis ROM, the M68K equivalent of bank switching is a `jmp` to the correct absolute ROM address. The `_mmc1_write_XXXX` stubs can be silent (no-ops) if you've preloaded all banks statically.

### NROM (Super Mario Bros., Donkey Kong)

No mapper. Both PRG banks are fixed. Simplest possible case — just translate both banks and include them both.

### MMC3 (Super Mario Bros. 3, Mega Man 3-6)

8 switchable banks (2×2KB CHR + 6×8KB PRG). More complex but follows the same principle: treat all banks as static ROM sections in the Genesis image.

---

## Genesis ROM Header

The ROM header lives at `$000100-$0001FF` (256 bytes). All fields are ASCII or big-endian.

```asm
    org     $000100

    dc.b    "SEGA MEGA DRIVE "          ; $100: system type (16 bytes, space-padded)
    dc.b    "(C)YOURNAME YYYY"          ; $110: copyright (16 bytes)
    dc.b    "GAME TITLE                      "  ; $120: domestic name (48 bytes, space-padded)
    dc.b    "GAME TITLE                      "  ; $150: overseas name (48 bytes, space-padded)
    dc.b    "GM 00000000-00"            ; $180: serial (14 bytes)
    dc.w    0                           ; $18E: checksum (fill with fix_checksum.py)
    dc.b    "J               "          ; $190: I/O support (16 bytes) "J"=3-btn joy
    dc.l    $00000000                   ; $1A0: ROM start address
    dc.l    RomEnd-1                    ; $1A4: ROM end address
    dc.l    $00FF0000                   ; $1A8: RAM start
    dc.l    $00FFFFFF                   ; $1AC: RAM end
    dc.b    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; $1B0: no SRAM (12 bytes)
    rept    12
        dc.b    $20                     ; $1BC: modem field (spaces, 12 bytes)
    endr
    rept    40
        dc.b    $20                     ; $1C8: memo field (spaces, 40 bytes)
    endr
    dc.b    "JUE             "          ; $1F0: regions (16 bytes)
```

**Checksum:** Calculated as the sum of all 16-bit words in the ROM from `$000200` onward. A Python script can patch it after assembly.

---

## VDP Register Init (H32 mode)

Write these in order during boot (display OFF). Each write is a 16-bit write to `VDP_CTRL = $C00004`.

```asm
move.w  #$8004, (VDP_CTRL).l  ; Reg  0: COLORFIX — bit 2 MUST be 1 or colors are dingy/dark
move.w  #$8134, (VDP_CTRL).l  ; Reg  1: display OFF, VBlank IRQ on, DMA on, Genesis mode (M5)
move.w  #$8230, (VDP_CTRL).l  ; Reg  2: Plane A at $C000  ($C000÷$2000=6, stored as $30)
move.w  #$832C, (VDP_CTRL).l  ; Reg  3: Window  at $B000  (bits[5:1]=22 → $2C)
move.w  #$8407, (VDP_CTRL).l  ; Reg  4: Plane B at $E000  ($E000÷$2000=7)
move.w  #$856C, (VDP_CTRL).l  ; Reg  5: Sprite table at $D800  ($D800÷$200=108 → $6C)
move.w  #$8600, (VDP_CTRL).l  ; Reg  6: sprite table high bit = 0
move.w  #$8700, (VDP_CTRL).l  ; Reg  7: background color = palette 0, color 0
move.w  #$8800, (VDP_CTRL).l  ; Reg  8: (SMS compat, unused in M5)
move.w  #$8900, (VDP_CTRL).l  ; Reg  9: (SMS compat, unused in M5)
move.w  #$8AFF, (VDP_CTRL).l  ; Reg 10: H-int counter = $FF (disabled)
move.w  #$8B00, (VDP_CTRL).l  ; Reg 11: full V-scroll, full H-scroll
move.w  #$8C00, (VDP_CTRL).l  ; Reg 12: H32 mode (bits 7,0 = 0), no interlace/shadow
move.w  #$8D37, (VDP_CTRL).l  ; Reg 13: H-scroll table at $DC00  ($DC00÷$400=55 → $37)
move.w  #$8E00, (VDP_CTRL).l  ; Reg 14: (SMS compat, 0 in M5)
move.w  #$8F02, (VDP_CTRL).l  ; Reg 15: auto-increment = 2 (one word per VRAM access)
move.w  #$9001, (VDP_CTRL).l  ; Reg 16: scroll size 64H × 32V
move.w  #$9100, (VDP_CTRL).l  ; Reg 17: window H position = 0
move.w  #$9200, (VDP_CTRL).l  ; Reg 18: window V position = 0
move.w  #$9300, (VDP_CTRL).l  ; Reg 19: DMA length low = 0
move.w  #$9400, (VDP_CTRL).l  ; Reg 20: DMA length high = 0
move.w  #$9500, (VDP_CTRL).l  ; Reg 21: DMA source low = 0
move.w  #$9600, (VDP_CTRL).l  ; Reg 22: DMA source mid = 0
move.w  #$9700, (VDP_CTRL).l  ; Reg 23: DMA source high/type = 0 (ROM→VRAM)
```

After all VRAM data is loaded, turn display on:
```asm
move.w  #$8174, (VDP_CTRL).l  ; Reg 1: display ON + VBlank IRQ + DMA + M5
```

**COLORFIX WARNING:** Register 0 value `$00` (`$8000`) produces washed-out/dingy colors on real hardware. The reserved bit 2 must ALWAYS be 1. Use `$8004`. This is the single most commonly missed Genesis init bug.

### VDP Command Format

To write to VRAM address `addr`:
```
cmd_hi = $4000 | (addr & $3FFF)
cmd_lo = ((addr >> 14) & 3)
write long: (cmd_hi << 16) | cmd_lo  →  VDP_CTRL
```
For CRAM write: replace `$4000` with `$C000`.

---

## VRAM Layout

Recommended layout (H32 mode, fits in 64KB VDP VRAM):

| Range | Size | Use |
|-------|------|-----|
| `$0000-$AFFF` | 44 KB | Tiles (1408 tiles × 32 bytes; CHR-RAM fills dynamically) |
| `$B000-$B7FF` | 2 KB | Window plane (32×32 cells × 2 bytes) — HUD strip |
| `$C000-$CFFF` | 4 KB | Plane A (64×32 cells × 2 bytes) — main playfield |
| `$D800-$DA7F` | 640 B | Sprite attribute table (80 sprites × 8 bytes) |
| `$DC00-$DF7F` | 896 B | H-scroll table (224 lines × 4 bytes, line-scroll mode) |
| `$E000-$EFFF` | 4 KB | Plane B (64×32 cells × 2 bytes) — room-transition staging |
| `$F000-$FFFF` | 4 KB | Free / reserved |

---

## Genesis Boot Sequence

```asm
EntryPoint:
    ; TMSS handshake (required on hardware revisions with TMSS)
    move.b  ($A10001).l, D0
    andi.b  #$0F, D0
    beq.s   .skip_tmss
    move.l  #$53454741, ($A14000).l    ; 'SEGA' as hex — NOT the string 'SEGA'
.skip_tmss:

    ; Stop Z80 to prevent bus contention
    move.w  #$0100, ($A11100).l
    move.w  #$0100, ($A11200).l
.z80wait:
    btst    #0, ($A11100).l
    bne.s   .z80wait

    ; VDP register init (24 registers, display OFF)
    ; ... (see above)

    ; Clear VRAM (32768 words = 64KB)
    move.l  #$40000000, ($C00004).l    ; VRAM write to $0000
    move.w  #32767, D0
.vramclear:
    move.w  #0, ($C00000).l
    dbra    D0, .vramclear

    ; Clear NES RAM ($FF0000-$FF080F)
    movea.l #$FF0000, A0
    move.w  #$040F, D0                 ; (NES_RAM + PPU_STATE) / 2 - 1
.nesramclear:
    move.w  #0, (A0)+
    dbra    D0, .nesramclear

    ; Init permanent registers
    movea.l #$FF0000, A4               ; NES RAM base
    movea.l #$FF0200, A5               ; NES stack pointer
    moveq   #-1, D7                    ; D7 = $FF (NES SP shadow)

    ; Lower interrupt mask — enable VBlank (IPL=6)
    andi.w  #$F8FF, SR

    ; Hand off to NES game code
    jsr     IsrReset                   ; never returns (→ RunGame → LoopForever)

HaltForever:
    stop    #$2700
    bra.s   HaltForever

VBlankISR:
    btst    #7, ($FF0804).l            ; PPUCTRL bit 7 = NMI enable
    beq.s   .nmi_off
    jsr     IsrNmi
.nmi_off:
    rte
```

---

## Exception Handling & Forensics

The 68000 has separate exception handlers for different fault types. Set these up early — they will save you hours of debugging.

### Vector Table Wiring

```asm
    org     $000000
    dc.l    STACK_TOP           ; vec  0: initial SSP
    dc.l    EntryPoint          ; vec  1: initial PC
    dc.l    ExcBusError         ; vec  2: bus error
    dc.l    ExcAddrError        ; vec  3: address error
    rept    20
        dc.l    DefaultException    ; vec 4–23: all other exceptions
    endr
    ; ... IRQ vectors ...
    dc.l    VBlankISR           ; vec 30: level 6 = VBlank
    ; ...
```

### 68000 Exception Stack Frames

| Exception | SR at | PC at | Extra |
|-----------|-------|-------|-------|
| Bus Error (vec 2) | SP+8 | SP+10 | SP+0..6: fault info (access addr, etc.) |
| Address Error (vec 3) | SP+8 | SP+10 | Same as bus error |
| All others | SP+0 | SP+2 | — |

### Forensics Handlers

Allocate a 64-byte forensics block in RAM (e.g. `$FF0900`):

```
$FF0900: exception type (2=bus, 3=addr, 0=other)
$FF0901: (pad)
$FF0902: stacked SR at time of exception
$FF0904: faulting PC (32-bit)
$FF0908: D0-D7 saved (8 × 4 = 32 bytes)
$FF0928: A0-A6 saved (7 × 4 = 28 bytes, ends $FF0943)
```

```asm
ExcBusError:
    move.b  #2, ($FF0900).l
    move.w  8(SP), ($FF0902).l
    move.l  10(SP), ($FF0904).l
    movem.l D0-D7/A0-A6, ($FF0908).l
.spin:
    bra.s   .spin

ExcAddrError:
    move.b  #3, ($FF0900).l
    move.w  8(SP), ($FF0902).l
    move.l  10(SP), ($FF0904).l
    movem.l D0-D7/A0-A6, ($FF0908).l
.spin:
    bra.s   .spin

DefaultException:
    move.b  #0, ($FF0900).l
    move.w  (SP), ($FF0902).l
    move.l  2(SP), ($FF0904).l
    movem.l D0-D7/A0-A6, ($FF0908).l
.spin:
    bra.s   .spin
```

Read `$FF0904` in your Lua probe script to see exactly which instruction triggered the fault.

---

## Critical Correctness Rules

### 1. STX/STY must not modify D0

The 6502 `STX` and `STY` instructions do NOT modify the A register. If your `_ppu_write_*` / `_apu_write_*` stubs expect the value in D0, and you move D2/D3 into D0 before calling the stub, you must save D0 first:

```asm
    move.l  D0, -(SP)       ; save A (STX/STY never modifies A on 6502)
    move.b  D2, D0          ; D2 (X register) → D0 for I/O dispatch
    bsr     _ppu_write_6    ; write to PPU register
    move.l  (SP)+, D0       ; restore A
```

### 2. RTI → `rts`, NOT `rte`

NES interrupt handlers return with `RTI` (6 cycles, pops P+PC from stack). In your transpiler architecture, `IsrNmi` is called via `jsr IsrNmi` from the Genesis VBlankISR — it is a **subroutine**, not an exception handler. `rte` pops 6 bytes (SR + PC), corrupting the M68K return address. Translate all NES `RTI` as `rts`.

### 3. SEI → NOP, not `ori.w #$0700, SR`

NES `SEI` masks the IRQ line but NOT the NMI line. In Genesis terms, the VBlank interrupt is your NMI. If you translate `SEI` as `ori.w #$0700, SR` (IPL=7), you will permanently mask the VBlank interrupt and the game will hang forever in a warmup loop.

### 4. `even` before every label

M68K instructions must be at even (word-aligned) addresses. Any time `dc.b` data sections with an odd number of bytes precede a label, that label lands on an odd address. Jumping to an odd address causes an address error on instruction fetch. Emit `even` before every label in transpiler output:

```python
emit('    even')
emit(f'{label}:')
```

vasm inserts one padding byte if needed, does nothing if already aligned.

### 5. PPUADDR two-write latch protocol

NES PPUADDR ($2006) requires **two consecutive writes** to set a 14-bit address. The w-register alternates: first write = high byte (bit 14 forced 0), second write = low byte. The w-register is **shared** with PPUSCROLL ($2005). Reading PPUSTATUS ($2002) clears the w-register.

### 6. PPUDATA word assembly

The Genesis VDP requires 16-bit writes. NES games write bytes one at a time. Buffer byte N in `PPU_DBUF`, then on byte N+1 write `(PPU_DBUF << 8) | byte_N+1` as a word to `VDP_DATA`. You must set the VDP VRAM address before each word write.

### 7. TMSS register must receive `$53454741`, not `'SEGA'`

In vasm Motorola syntax, `'SEGA'` is a character constant but may not assemble to the correct 32-bit value on all versions. Write it explicitly: `move.l #$53454741, ($A14000).l`.

### 8. All absolute address accesses need `.l` suffix in vasm

`($FF0804)` without a suffix defaults to `.w` in some contexts, which truncates to a 16-bit signed address. Always use `($FF0804).l` for any absolute long address.

---

## Build System

```
project/
├── build.bat                       ← runs all three steps
├── src/
│   ├── genesis_shell.asm           ← boot, VDP init, vector table, VBlankISR
│   ├── nes_io.asm                  ← PPU/APU/controller I/O emulation
│   └── translated/                 ← transpiler output (generated, not hand-edited)
│       ├── bank0.asm, bank1.asm, ...
├── tools/
│   ├── transpile_6502.py           ← auto-translates disassembly → M68K
│   └── fix_checksum.py             ← patches ROM header checksum word
├── reference/
│   └── disassembly/                ← original labeled 6502 source (read-only)
└── builds/
    ├── game.bin                    ← final ROM
    └── game.lst                    ← listing (address of every symbol)
```

**Build steps:**
1. `python transpile_6502.py --all --no-stubs` → writes `src/translated/*.asm`
2. `vasmm68k_mot.exe -Fbin -m68000 -L game.lst -o game_raw.bin genesis_shell.asm`
3. `python fix_checksum.py game_raw.bin game.bin`

**vasm flags:**
- `-Fbin`: raw binary output (no ELF/COFF headers)
- `-m68000`: target the original 68000 (no 68020 instructions)
- `-maxerrors=5000`: don't bail on the first few warnings

---

## Probe / Test Harness

Use BizHawk's Lua scripting to run automated smoke tests after each build. A probe script:

1. Advances 60 frames (`emu.frameadvance()`)
2. Checks M68K PC at each frame boundary (detects exception hangs vs. expected spin loops)
3. Reads PPU state RAM directly from Genesis RAM
4. Reads VDP VRAM to verify writes landed correctly
5. Writes a report to disk; `client.exit()` when done

**Running from command line:**
```
EmuHawk.exe --lua=probe.lua rom.bin
```

**Key Lua functions:**
```lua
emu.getregister("M68K PC")          -- sample program counter
memory.usememorydomain("M68K BUS")  -- select bus-mapped address space
memory.read_u8(0xFF0800)            -- read byte from absolute address
memory.read_u16_be(0xFF0802)        -- read big-endian word
memory.usememorydomain("VRAM")      -- select VDP VRAM
memory.read_u16_be(0x2000)          -- verify nametable write
event.onmemoryexecute(fn, addr, "name")  -- hook PC reaching a specific address
```

**What to test at each milestone:**

| Milestone | Key check |
|-----------|-----------|
| T1 (shell) | PC never hits exception; VBlank fires (stuck counter increment) |
| T2 (Z07 transpiles) | ROM assembles, correct size |
| T3 (all banks) | Full ROM assembles without errors |
| T4 (Reset runs) | PC reaches game's idle loop |
| T5 (PPU latch) | VRAM[$2000]=$2424 (nametable cleared with $24 tile) |
| T6 (CHR upload) | VRAM[$0000-$01FF] non-zero tile data |
| T7 (nametable) | Tile indices visible in Plane A VRAM viewer |
| T8 (palette) | CRAM has correct colors |
| T9 (sprites) | Sprite table populated |

---

## Common Bugs & How to Diagnose Them

### PC stuck at exception handler (address error)

**Symptom:** PC stays at a fixed address for many frames; BizHawk shows faulting instruction.

**Most likely cause:** A function label lands on an odd address. Check if there's an odd-length `dc.b` block before the function. Fix: add `even` before every label in transpiler output.

**How to diagnose:** Add exception forensics handlers (see above). Read `$FF0904` in BizHawk Lua to get the exact faulting PC. Cross-reference with the listing file (`.lst`) to find which instruction triggered it.

### Colors are wrong / washed out

**Symptom:** Screen shows but all colors appear dark, gray, or incorrect.

**Cause:** VDP register 0 written as `$8000` instead of `$8004`. Bit 2 is reserved and must be 1.

**Fix:** Always use `move.w #$8004, (VDP_CTRL).l` for register 0.

### Game loops forever during boot (never reaches RunGame)

**Symptom:** PC loops in PPUSTATUS polling loop inside IsrReset.

**Cause:** `_ppu_read_2` returns 0. IsrReset polls $2002 bit 7 (VBlank) until it's set. It never gets set.

**Fix:** `_ppu_read_2` must return `move.b #$80, D0` unconditionally during boot.

### Wrong branches after comparisons

**Symptom:** Game logic fails inexplicably (enemies behave wrong, counters don't decrement, etc.).

**Cause:** BCS/BCC after CMP translated literally. M68K C flag is inverted vs 6502 for CMPI.

**Fix:** Track `carry_inverted` state in the transpiler. Swap BCS↔BCC after every CMP/CPX/CPY/SBC.

### VBlank never fires (game hangs after lowering IPL)

**Symptom:** After `andi.w #$F8FF, SR`, game does nothing; stuck in main loop.

**Cause:** `SEI` translated as `ori.w #$0700, SR` (IPL=7), re-masking all interrupts.

**Fix:** Translate `SEI` as a comment or NOP.

### Stack corruption / `rte` crash

**Symptom:** Crash immediately on returning from IsrNmi.

**Cause:** NES `RTI` translated as M68K `rte`. `rte` pops 6 bytes; `rts` only pushed 4.

**Fix:** Always translate 6502 `RTI` as M68K `rts`.

### Nametable writes land at wrong VRAM address

**Symptom:** VRAM viewer shows $0000 when $2424 is expected.

**Cause:** PPUADDR latch not correctly implementing the two-write protocol, or PPUDATA not sending VDP address command before each word write.

**Fix:** Verify the w-register is shared between $2005 and $2006. Verify the VDP write command (`$40000000 | (addr & $3FFF)`) is sent before each `move.w data, (VDP_DATA).l`.

### `_m68k_tablejump` dispatches to garbage address

**Symptom:** Address error with faulting PC inside a data table or `$0000FFF0`-style NES address.

**Cause A:** A NES address was emitted as a raw `dc.l $NNNN` instead of a resolved M68K label in a jump table.

**Cause B:** D0 contains the wrong value at the dispatch site (e.g., D0 was clobbered by an STX/STY write stub).

**Fix A:** Resolve all NES labels in jump tables to their M68K counterparts. Mark unresolvable entries as `dc.l DefaultException` or a dedicated error handler.

**Fix B:** Ensure STX/STY I/O writes save/restore D0.

---

## Transpiler Architecture Checklist

When building a 6502→M68K transpiler for a new NES game:

- [ ] Parse labeled disassembly (aldonunez style) or raw binary + symbol table
- [ ] Pre-pass: build local label → global unique label map
- [ ] Carry inversion tracking: flag set after CMP/CPX/CPY/SBC, cleared at labels + ADC/shifts/SEC/CLC
- [ ] `even` before every label (global, local, stub)
- [ ] NES RAM accesses use `(offset,A4)` not absolute addresses
- [ ] All PPU register writes ($2000-$2007) intercepted → `bsr _ppu_write_N`
- [ ] All APU register writes ($4000-$4015) intercepted → `bsr _apu_write_N`
- [ ] Controller reads ($4016/$4017) intercepted → `bsr _ctrl_read_N`
- [ ] OAM DMA ($4014) intercepted → `bsr _oam_dma`
- [ ] Mapper writes ($8000-$FFFF) intercepted → `bsr _mmc_write_NNNN`
- [ ] `JSR TableJump` → `bsr _m68k_tablejump` + `dc.l` table entries (32-bit)
- [ ] `RTI` → `rts`
- [ ] `SEI` → NOP comment
- [ ] `BCS`/`BCC` inverted after CMP/CPX/CPY/SBC
- [ ] STX/STY writes to I/O: save/restore D0 around stub
- [ ] Import stubs: every `.IMPORT` symbol gets an `even` + label + `rts` stub so file assembles standalone
- [ ] NES interrupt vectors (`$FFFA-$FFFF`) → `dc.l IsrNmi`, `dc.l IsrReset`, etc. (NOT jump table entries)
- [ ] NES addresses in `dc.w` / `dc.l` data: attempt to resolve to labels; fall through to raw value if unknown
- [ ] `org $NNNN` directives: strip (or keep only the outermost `org 0`; M68K binary is flat)

---

*Document compiled from the WHAT IF project — Zelda 1 NES→Genesis port (2026).*
