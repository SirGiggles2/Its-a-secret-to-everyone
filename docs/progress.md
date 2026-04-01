# WHAT IF — Development Progress Log

A running record of every significant approach, decision, bug, and fix across all phases of the project. Most recent entries are at the top of each phase section.

---

## Phase 5 — Transpiler Approach (Current)

**Strategy:** Auto-translate the original 6502 Zelda disassembly to M68K. Write only the I/O shim. Keep all original game data untouched.

---

### T5 — PPUADDR Latch / PPUDATA → VDP ✅ COMPLETE

**Status:** 7/7 probe checks PASS (2026-04-01)

#### Fix: `even` before all transpiler labels (address error on odd PC)

**Problem:** After T5 VRAM writes started passing, the CPU was still dying with an address error. Exception forensics revealed: faulting PC = `$00359B` (odd address). `DriveAudio` label was at that odd address because a 15-byte `dc.b` block in the `BANK_07_VEC` segment left the offset counter at an odd value, and `DriveAudio:` was placed right after without alignment.

**Root cause:** M68K instruction fetch from an odd address causes an immediate address error before the instruction executes. Any label following an odd-length `dc.b` block will land on an odd address.

**Fix:** Modified `transpile_6502.py` to emit `    even` before every label definition (global, local, and import stub). Vasm inserts one padding byte if needed, no-ops if already aligned.

**Lesson:** Always emit `even` before labels in M68K transpiler output. This is not just for this game — any NES game's fixed bank ends with odd-length data sections followed by function labels.

---

#### Fix: Exception forensics in `genesis_shell.asm`

**Problem:** The CPU was stuck at an exception handler but the probe (and BizHawk debugger) couldn't tell what exception type or what instruction triggered it.

**Fix:** Replaced the simple `DefaultException: bra.s DefaultException` spin with three separate handlers:
- `ExcBusError` (vec 2): saves type=2, SR from SP+8, faulting PC from SP+10
- `ExcAddrError` (vec 3): saves type=3, SR from SP+8, faulting PC from SP+10
- `DefaultException` (vec 4+): saves type=0, SR from SP+0, faulting PC from SP+2
- All three then save D0-D7/A0-A6 via `movem.l` and spin

Forensics RAM layout at `$FF0900`:
- `+0`: exception type byte
- `+2`: stacked SR
- `+4`: faulting PC (long)
- `+8`: D0-D7/A0-A6 (60 bytes)

The BizHawk probe reads `$FF0904` and reports the faulting instruction address. This turned the "mystery exception" into a 1-minute debug session.

---

#### Fix: STX/STY must not clobber D0 in I/O write path

**Problem:** ClearNameTable was running 65,536 iterations instead of 1,024. The outer loop counter (D2/D3) was being counted against D0 (the accumulator), and after a `STY $2006` write, D0 was being overwritten with D3's value, breaking the subsequent `cmpi.b #$20, D0` comparison.

**Root cause:** The transpiler's `gen_write()` function routed all PPU/APU writes through D0 (`move.b D3, D0; bsr _ppu_write_6`). But on the 6502, `STY` does NOT modify A. After the store, the accumulator still held its pre-store value.

**Fix:** Modified `gen_write()` to save and restore D0 when the source register is not D0:
```python
emit(f'    move.l  D0,-(SP)       ; save A (6502 STX/STY never modifies A)')
emit(f'    move.b  {src},D0       ; {src} → D0 for I/O write')
# ... emit stub call ...
emit(f'    move.l  (SP)+,D0       ; restore A')
```

---

#### Fix: `_m68k_tablejump` — M68K-native JSR-trick dispatch

**Problem:** The original Zelda code uses `JSR TableJump` extensively as a switch-case dispatch pattern. The return address trick doesn't translate directly — M68K `bsr` pushes a 4-byte address, while the 6502 JSR trick relies on reading the return address from the NES stack as a table pointer.

**Fix:** Wrote a native M68K routine `_m68k_tablejump` in `nes_io.asm`:
```asm
_m68k_tablejump:
    movea.l (SP)+, A0        ; pop BSR return addr = pointer to table[0]
    and.w   #$00FF, D0       ; zero-extend mode byte
    lsl.w   #2, D0           ; D0 = index × 4
    movea.l (A0,D0.w), A0    ; load 32-bit handler address
    jmp     (A0)             ; dispatch
```

The transpiler replaces each `JSR TableJump` with `bsr _m68k_tablejump` followed by a `dc.l` table of 32-bit M68K addresses.

---

#### Fix: `LoopForever` address probe constant drift

**Problem:** Each time code is added before `z_07.asm` (shell code, nes_io.asm, etc.), `LoopForever` shifts. The BizHawk probe hardcodes the address and reported false failures when the ROM changed.

**Fix:** After each build, grep `whatif.lst` for `LoopForever` and update the probe constant. Automated this by making the probe output its constants in the report header, making drift immediately visible.

---

#### VBlankISR gates on PPUCTRL bit 7 (NMI enable)

**Problem:** IsrNmi was firing during IsrReset's warmup period when PPUCTRL=0. This caused garbage behavior before the game finished initialization.

**Fix:** Added a guard in VBlankISR:
```asm
btst    #7, ($FF0804).l    ; PPUCTRL bit 7 = NMI enable
beq.s   .nmi_off
jsr     IsrNmi
.nmi_off:
rte
```

---

#### `_ppu_read_2` must return `$80` (VBlank bit set)

**Problem:** IsrReset contains two loops that poll PPUSTATUS ($2002) bit 7 waiting for VBlank. If the stub returns 0, these loops never exit.

**Fix:** `_ppu_read_2` returns `move.b #$80, D0` unconditionally during boot. Also clears `PPU_LATCH` (the PPUADDR w-register), per NES hardware spec.

---

### T4 — Zelda Reset Vector Runs ✅ COMPLETE

- `org $C000` removed from transpiler output (bank files are not standalone; they're included into the flat binary by genesis_shell.asm)
- RTI → `rts` fix: IsrNmi is called by `jsr` from VBlankISR, not via exception mechanism. `rte` pops 6 bytes and corrupts the stack.
- SEI → NOP: `ori.w #$0700,SR` would mask Genesis VBlank (level 6). SEI on NES only masks IRQ not NMI; VBlank is our NMI.
- ca65 addressing prefixes (`a:`, `z:`, `f:`) stripped from operands
- Local `@label` references resolved to globally unique `_L_bankname_scope_local` labels
- Anonymous `:` labels resolved to `_anon_bankname_N` labels
- NES RAM accesses rewritten from absolute `$00xx` to `(offset,A4)` form
- BCS/BCC carry inversion tracking implemented (after 222 CMP instructions all fired on opposite condition)

---

### T1-T3 — Shell, Transpiler Bootstrap ✅ COMPLETE

- Genesis shell built: TMSS handshake, Z80 stop, VDP init (H32), VRAM clear, CRAM test color, display on
- **COLORFIX** discovered and documented: VDP Reg 0 must be `$8004` not `$8000` — bit 2 reserved must be 1 or colors are dingy/dark on hardware
- ROM header format finalized: "SEGA MEGA DRIVE" system ID, TMSS write as `$53454741` (not `'SEGA'` char constant)
- STACK_TOP set to `$00FFFFFE` (even, aligned — odd SSP would cause immediate address error on boot)
- All `(addr)` references changed to `(addr).l` — vasm `.w` default truncates Genesis RAM addresses
- `rept`/`endr` used for repeated vector entries (ca65 `.repeat` not valid in vasm Motorola syntax)
- Transpiler built: parses aldonunez `.asm` format, handles `.DEFINE`, `.SEGMENT`, `.IMPORT`, `.EXPORT`, inline data (`.BYTE`/`.WORD`/`.ADDR`/`.FARADDR`), local labels, anonymous labels, and all ~60 6502 instructions
- All 8 Zelda banks transpile successfully to M68K

---

## Phase 4 — Manual Reimplementation (Hand-Coded M68K, Build P4.1–P4.12+)

**Strategy:** Write Zelda-faithful M68K directly. Extract all data (tiles, palettes, rooms, enemy tables) from the NES ROM via Python tools, compile into Genesis include files.

**Why abandoned:** After 12+ builds, data extraction bugs (wrong offsets, wrong attribute order) kept corrupting the overworld layout. Each fix revealed another layer of NES ROM format complexity. The root issue: accurately modeling Zelda's behavior in hand-coded M68K requires understanding every nuance of every subsystem, which is effectively re-reverse-engineering the game.

### Key P4 work (salvaged into Phase 5 reference):

- Overworld level block structure reverse-engineered: `LEVEL_BLOCK_SIZE=752` (0x02F0), not 768 as initially assumed. Attribute order in ROM: A, B, D, C, E, F (not alphabetical).
- `RoomAttrsOW_D` was extracting from wrong offset — 128-byte error caused all attribute reads to be wrong.
- Cave entry behavior identified as dependent on room attribute byte D, not attribute byte C as assumed.
- VDP plane scroll mechanism worked out: H-scroll table at $DC00, line-scroll mode for per-scanline scroll (needed for Zelda's status bar split).

---

## Phase 3 — Manual Reimplementation (Hand-Coded M68K, Build P3.1–P3.86+)

**Strategy:** Build Zelda from scratch in Genesis M68K ASM, extracting data from the NES ROM.

**What was achieved:** By P3.46, the Genesis ROM booted into a recognizable Zelda 1 overworld room $77 with:
- Real extracted Zelda tileset (overworld and background tiles)
- Correct gameplay CRAM colors
- Room $77 decoded from extracted overworld room data
- Plane A filled from room buffer
- Placeholder Link sprite with correct bank ordering
- D-pad movement and room-edge transitions in all four directions

**Why replaced:** Phase 3 was a manual recreation, not the real game. Room transitions worked but enemy AI, game modes, HUD, inventory, sound, and every other system would each require the same effort as the room rendering system. The transpiler approach routes around all of this.

### Key Phase 3 lessons (still relevant):

- Genesis H32 mode: VDP Reg 12 = `$00` (RS0 bit 0 = 0, RS1 bit 7 = 0). 256 pixels wide, 32 tiles per row.
- Plane A tilemap at VRAM `$C000`: each cell is a 16-bit word `PVHNN NNNNNNNN` (P=priority, V=vflip, H=hflip, N=tile index).
- Sprite attribute table: 8 bytes per sprite. Word 0 = Y, word 1 = size+link, word 2 = flags+tile, word 3 = X.
- DMA for sprite upload: source in 68K ROM/RAM, destination VRAM sprite table. Set DMA type in Reg 23.
- VDP auto-increment (Reg 15 = 2) advances VRAM pointer by 2 after each word write — critical for bulk VRAM fills.
- CHR bank seam: Zelda uses two CHR banks. The tile ordering at the seam matters for correct sprite rendering. Bank 0 tiles are the "common" bank (Link, enemies, items); bank 1 is the background bank.
- CRAM layout: 4 palettes × 16 colors × 2 bytes. Palettes 0-1 for backgrounds, 2-3 for sprites.

---

## Pre-Phase 3 — Initial Exploration

- Established that Zelda 1 uses the MMC1 mapper (5-bit serial register, 4 internal registers: Control, CHR0, CHR1, PRG).
- Mapped all 8 PRG banks to their content (audio, init, graphics, rooms, enemies, items, level loading, fixed bank).
- Identified `aldonunez` GitHub disassembly as the best-labeled source for the fixed bank (Z_07) and all other banks.
- Confirmed Genesis NTSC timing: 60Hz VBlank, same as NES. No frame-rate conversion needed.
- Confirmed Genesis has enough RAM (64KB work RAM + 64KB VRAM + 512 bytes CRAM) to represent all NES state.
- Identified the 2010 *Super Mario Bros.* Genesis port as the proof-of-concept for the transpiler approach.

---

## Open Issues / Known Gaps

| Issue | Status |
|-------|--------|
| NES addresses in jump tables emitted as raw `dc.l $NNNN` | Accepted for now — only fire when that code path is reached |
| `$B517` and other NES addresses in `CalculateNextRoom_JumpTable` | Will fault if CalculateNextRoom runs with door type 1 or 8 |
| APU stubs are all silent (no sound) | Planned for T14 |
| MMC1 bank switch stubs are no-ops (all banks preloaded) | Acceptable for static ROM layout |
| CHR-RAM 2bpp→4bpp conversion not yet wired | T6 milestone |
| OAM DMA stub (`_oam_dma`) does nothing | T9 milestone |
| Controller stubs return 0 (no input) | T10 milestone |

---

*Last updated: 2026-04-01 after T5 milestone complete.*
