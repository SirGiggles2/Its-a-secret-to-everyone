"""gen_chr_viewer_rom.py — generate a standalone NES test ROM that displays
each Z1 CHR bank as a deterministic tile grid for byte-diff against Genesis.

Output: build/probes/chr_viewer_rom.nes

Design:
  Mapper:  3 (CNROM) — single 32 KB PRG bank, N × 8 KB CHR pages selected
           by writing bank# to any address in $8000-$FFFF.
  PRG:     32 KB. ~80 6502 instructions hand-encoded via op() helper.
           - Reset: PPU init, fill nametable + attribute table, enable
             rendering, enter infinite loop.
           - NMI: read $0010 (bank) -> CNROM bank-select via STA $8000.
                  read $0011 (sub_pal) -> rewrite attribute table.
  CHR:     N × 8 KB pages mirroring Z1's PPU state at each scene:
             page 0  Common BG + Common SPR + Common Misc (baseline)
             page 1  OW gameplay (Common + OW BG + OW SP)
             page 2  UW1 (Common + UW BG + UW SP + UWSP127)
             page 3  UW3 (Common + UW BG + UW SP + UWSP358)
             page 4  UW4 (Common + UW BG + UW SP + UWSP469)
             page 5  UW1 boss (Common + UW BG + Boss1257)
             page 6  UW3 boss (Common + UW BG + Boss3468)
             page 7  UW9 boss (Common + UW BG + Boss9)
             page 8  Title demo (Common + Demo BG + Demo SPR)

Probe drives the ROM by poking $0010 + $0011 in WRAM; NMI handler swaps
CHR bank + sub-pal accordingly. Probe captures CIRAM + PALRAM + OAM + CHR
at known frame.

Hand-coded 6502 with op() helper: each call appends opcode bytes to PRG;
labels resolved at end via second-pass patching for branches/JSRs.
"""
from __future__ import annotations

import pathlib
import struct
import sys


# ---------------------------------------------------------------------------
# Minimal 6502 micro-assembler — opcode encodings for the subset we use.
# Reference: nesdev.org/wiki/CPU_unofficial_opcodes (official only here).
# ---------------------------------------------------------------------------

class Assembler:
    """Single-pass 6502 emitter with label patching. ORG-aware."""

    def __init__(self, org: int = 0xC000):
        self.org = org
        self.code = bytearray()
        self.labels: dict[str, int] = {}
        self.fixups: list[tuple[int, str, str]] = []  # (offset, label, kind)

    def pc(self) -> int:
        return self.org + len(self.code)

    def label(self, name: str) -> None:
        if name in self.labels:
            raise ValueError(f"duplicate label {name}")
        self.labels[name] = self.pc()

    def emit(self, *bytes_) -> None:
        for b in bytes_:
            self.code.append(b & 0xFF)

    # ---- Immediate / accumulator ----
    def lda_imm(self, v):  self.emit(0xA9, v)
    def ldx_imm(self, v):  self.emit(0xA2, v)
    def ldy_imm(self, v):  self.emit(0xA0, v)
    def cmp_imm(self, v):  self.emit(0xC9, v)
    def cpx_imm(self, v):  self.emit(0xE0, v)
    def cpy_imm(self, v):  self.emit(0xC0, v)
    def and_imm(self, v):  self.emit(0x29, v)
    def ora_imm(self, v):  self.emit(0x09, v)
    def adc_imm(self, v):  self.emit(0x69, v)

    # ---- Absolute ----
    def lda_abs(self, a):  self.emit(0xAD, a & 0xFF, (a >> 8) & 0xFF)
    def sta_abs(self, a):  self.emit(0x8D, a & 0xFF, (a >> 8) & 0xFF)
    def ldx_abs(self, a):  self.emit(0xAE, a & 0xFF, (a >> 8) & 0xFF)
    def stx_abs(self, a):  self.emit(0x8E, a & 0xFF, (a >> 8) & 0xFF)
    def ldy_abs(self, a):  self.emit(0xAC, a & 0xFF, (a >> 8) & 0xFF)
    def sty_abs(self, a):  self.emit(0x8C, a & 0xFF, (a >> 8) & 0xFF)
    def bit_abs(self, a):  self.emit(0x2C, a & 0xFF, (a >> 8) & 0xFF)
    def jmp_abs(self, a):  self.emit(0x4C, a & 0xFF, (a >> 8) & 0xFF)
    def jsr_abs(self, a):  self.emit(0x20, a & 0xFF, (a >> 8) & 0xFF)
    def sta_abs_x(self, a): self.emit(0x9D, a & 0xFF, (a >> 8) & 0xFF)
    def lda_abs_x(self, a): self.emit(0xBD, a & 0xFF, (a >> 8) & 0xFF)

    # ---- Zero page ----
    def lda_zp(self, a):  self.emit(0xA5, a)
    def sta_zp(self, a):  self.emit(0x85, a)
    def ldx_zp(self, a):  self.emit(0xA6, a)
    def stx_zp(self, a):  self.emit(0x86, a)
    def inc_zp(self, a):  self.emit(0xE6, a)
    def dec_zp(self, a):  self.emit(0xC6, a)
    def cmp_zp(self, a):  self.emit(0xC5, a)
    def bit_zp(self, a):  self.emit(0x24, a)

    # ---- Branches (relative; needs label patch) ----
    def bne_label(self, name): self._branch(0xD0, name)
    def beq_label(self, name): self._branch(0xF0, name)
    def bpl_label(self, name): self._branch(0x10, name)
    def bmi_label(self, name): self._branch(0x30, name)
    def bcc_label(self, name): self._branch(0x90, name)
    def bcs_label(self, name): self._branch(0xB0, name)

    def _branch(self, opcode, name):
        self.emit(opcode, 0x00)  # placeholder offset
        self.fixups.append((len(self.code) - 1, name, "rel"))

    # ---- Implicit ----
    def sei(self): self.emit(0x78)
    def cld(self): self.emit(0xD8)
    def txs(self): self.emit(0x9A)
    def tax(self): self.emit(0xAA)
    def tay(self): self.emit(0xA8)
    def txa(self): self.emit(0x8A)
    def tya(self): self.emit(0x98)
    def pha(self): self.emit(0x48)
    def pla(self): self.emit(0x68)
    def php(self): self.emit(0x08)
    def plp(self): self.emit(0x28)
    def inx(self): self.emit(0xE8)
    def iny(self): self.emit(0xC8)
    def dex(self): self.emit(0xCA)
    def dey(self): self.emit(0x88)
    def rts(self): self.emit(0x60)
    def rti(self): self.emit(0x40)
    def nop(self): self.emit(0xEA)
    def clc(self): self.emit(0x18)
    def sec(self): self.emit(0x38)

    def resolve(self) -> bytes:
        for offset, name, kind in self.fixups:
            if name not in self.labels:
                raise KeyError(f"unresolved label {name}")
            target = self.labels[name]
            if kind == "rel":
                # Branch offset is from (offset + 1), signed 8-bit
                rel = target - (self.org + offset + 1)
                if not (-128 <= rel <= 127):
                    raise ValueError(f"branch {name} out of range: {rel}")
                self.code[offset] = rel & 0xFF
            else:
                raise ValueError(f"unknown fixup kind {kind}")
        return bytes(self.code)


# ---------------------------------------------------------------------------
# PRG program — Reset, NMI, IRQ handlers
# ---------------------------------------------------------------------------

# RAM locations
RAM_BANK     = 0x10   # probe pokes desired CHR bank here
RAM_SUBPAL   = 0x11   # probe pokes desired sub-pal here
RAM_LAST_BANK   = 0x12  # last applied bank (for change detection)
RAM_LAST_SUBPAL = 0x13  # last applied sub-pal
RAM_FRAME    = 0x14   # frame counter (probe reads for sync)

# Constants
PPUCTRL   = 0x2000
PPUMASK   = 0x2001
PPUSTATUS = 0x2002
PPUADDR   = 0x2006
PPUDATA   = 0x2007

NUM_BANKS = 9


def build_prg() -> bytes:
    a = Assembler(org=0xC000)

    # ============ RESET vector ============
    a.label("reset")
    a.sei()
    a.cld()
    a.ldx_imm(0xFF); a.txs()
    a.lda_imm(0x00); a.sta_abs(PPUCTRL)
    a.lda_imm(0x00); a.sta_abs(PPUMASK)

    # Wait first VBlank (PPU warmup)
    a.label("vwait1")
    a.bit_abs(PPUSTATUS)
    a.bpl_label("vwait1")

    # Clear $0000-$07FF RAM
    a.lda_imm(0x00)
    a.tax()
    a.label("clear_ram")
    a.sta_abs_x(0x0000)
    a.sta_abs_x(0x0100)
    a.sta_abs_x(0x0200)
    a.sta_abs_x(0x0300)
    a.sta_abs_x(0x0400)
    a.sta_abs_x(0x0500)
    a.sta_abs_x(0x0600)
    a.sta_abs_x(0x0700)
    a.inx()
    a.bne_label("clear_ram")

    # Wait second VBlank
    a.label("vwait2")
    a.bit_abs(PPUSTATUS)
    a.bpl_label("vwait2")

    # Set PALRAM via $3F00. Use Z1 OW orig palette (per ow_palette.c).
    a.lda_imm(0x3F); a.sta_abs(PPUADDR)
    a.lda_imm(0x00); a.sta_abs(PPUADDR)
    pal_addr = 0xC500   # palette table at $C500 (defined below)
    a.ldx_imm(0x00)
    a.label("pal_loop")
    a.lda_abs_x(pal_addr)
    a.sta_abs(PPUDATA)
    a.inx()
    a.cpx_imm(0x20)
    a.bne_label("pal_loop")

    # Set nametable: fill $2000 with deterministic tile grid.
    # Layout: 32 wide × 30 visible rows. Tiles tile_id $00..$FF rendered
    # at cells where cell_index = (row*32 + col); tile_id = ((row & 0x0F)
    # << 4) | (col & 0x0F) for the visible 16×16 tile block at top-left.
    # Rows 0-15, cols 0-15 = tile grid. Rest = $00 (blank).
    a.lda_imm(0x20); a.sta_abs(PPUADDR)
    a.lda_imm(0x00); a.sta_abs(PPUADDR)
    # Emit 960 bytes via outer loop on Y (row), inner X (col).
    # Use a precomputed table at $C600 — write all 960 bytes from there.
    nt_addr_lo = 0xC600
    nt_addr_hi = 0xC600 + 0x100
    nt_addr_2  = 0xC600 + 0x200
    nt_addr_3  = 0xC600 + 0x2C0  # 960 - 768 = 192 bytes in 4th page
    # Use 4 page loops since LDA abs,X only addresses 256 bytes.
    for page, base in enumerate([0xC600, 0xC700, 0xC800, 0xC900]):
        # last page only needs 192 of 256 bytes (960 = 3*256 + 192)
        count = 256 if page < 3 else 192
        a.ldx_imm(0x00)
        a.label(f"nt_page_{page}")
        a.lda_abs_x(base)
        a.sta_abs(PPUDATA)
        a.inx()
        a.cpx_imm(count if count != 256 else 0)  # 0 means INX wrapped past 255
        a.bne_label(f"nt_page_{page}")

    # Set attribute table at $23C0. 64 bytes, each = sub_pal repeated 4×.
    # NMI handler rewrites this when $0011 changes; here we init to sub_pal 0.
    a.lda_imm(0x23); a.sta_abs(PPUADDR)
    a.lda_imm(0xC0); a.sta_abs(PPUADDR)
    a.lda_imm(0x00)        # sub_pal 0 = 0b00000000
    a.ldx_imm(0x00)
    a.label("attr_loop")
    a.sta_abs(PPUDATA)
    a.inx()
    a.cpx_imm(0x40)
    a.bne_label("attr_loop")

    # Reset PPUADDR to $0000 (so scroll = 0,0)
    a.lda_imm(0x00); a.sta_abs(PPUADDR); a.sta_abs(PPUADDR)
    # PPUSCROLL reset
    a.sta_abs(0x2005); a.sta_abs(0x2005)

    # Enable rendering + NMI:
    #   PPUMASK = $1E (BG + sprite show; bg-only left-col disabled)
    #   PPUCTRL = $90 (NMI on, BG pattern table = $1000)
    #              bit 7 = NMI on
    #              bit 4 = BG pattern table addr ($1000 = where Z1 BG lives)
    #              bit 5 = 0 (8x8 sprite mode for test ROM)
    a.lda_imm(0x1E); a.sta_abs(PPUMASK)
    a.lda_imm(0x90); a.sta_abs(PPUCTRL)

    # Infinite loop
    a.label("main_loop")
    a.jmp_abs(0)  # placeholder; fix after labels resolved
    main_loop_offset = len(a.code) - 2
    # We'll patch this manually after label resolution

    # ============ NMI handler at $C100 ============
    # Align to $C100
    while a.pc() < 0xC100:
        a.nop()
    a.label("nmi")
    a.pha()
    a.txa(); a.pha()
    a.tya(); a.pha()

    # Increment frame counter
    a.inc_zp(RAM_FRAME)

    # Check if bank changed: if $10 != $12 then update
    a.lda_zp(RAM_BANK)
    a.cmp_zp(RAM_LAST_BANK)
    a.beq_label("nmi_check_subpal")
    a.sta_zp(RAM_LAST_BANK)
    a.sta_abs(0x8000)        # CNROM bank-select
    a.label("nmi_check_subpal")

    # Check sub-pal change: if $11 != $13 then rebuild attr table
    a.lda_zp(RAM_SUBPAL)
    a.cmp_zp(RAM_LAST_SUBPAL)
    a.beq_label("nmi_done")
    a.sta_zp(RAM_LAST_SUBPAL)
    # Compute attr byte: sub_pal & 3, replicate to 2 bits × 4 quads.
    # byte = (sp<<6) | (sp<<4) | (sp<<2) | sp
    a.and_imm(0x03)
    a.tax()                  # X = sub_pal
    # multiply via shift: we'll use a small table lookup at $C580.
    # X selects byte from attr_byte_table[4].
    a.lda_abs_x(0xC580)      # attr byte table
    a.tax()                  # X = attr byte
    # Write all 64 attr bytes
    a.lda_imm(0x23); a.sta_abs(PPUADDR)
    a.lda_imm(0xC0); a.sta_abs(PPUADDR)
    a.txa()                  # A = attr byte
    a.ldx_imm(0x00)
    a.label("nmi_attr_loop")
    a.sta_abs(PPUDATA)
    a.inx()
    a.cpx_imm(0x40)
    a.bne_label("nmi_attr_loop")
    # Reset PPUADDR for next frame
    a.lda_imm(0x00); a.sta_abs(PPUADDR); a.sta_abs(PPUADDR)
    a.sta_abs(0x2005); a.sta_abs(0x2005)

    a.label("nmi_done")
    a.pla(); a.tay()
    a.pla(); a.tax()
    a.pla()
    a.rti()

    # ============ IRQ handler ============
    a.label("irq")
    a.rti()

    # Resolve labels (patches branches)
    code = a.resolve()

    # Patch main_loop JMP to point at itself
    main_loop_addr = a.labels["main_loop"]
    code_ba = bytearray(code)
    code_ba[main_loop_offset]     = main_loop_addr & 0xFF
    code_ba[main_loop_offset + 1] = (main_loop_addr >> 8) & 0xFF
    code = bytes(code_ba)

    # Pad PRG to 16 KB. For 16 KB CNROM PRG, mapper mirrors at:
    #   CPU $8000-$BFFF and CPU $C000-$FFFF (both views of same 16 KB)
    #   file offset 0 = both CPU $8000 and $C000
    # Code was assembled at org=$C000, so place it at PRG offset 0.
    prg = bytearray(0x4000)
    code_offset = a.org - 0xC000   # 0x0000 for org=$C000
    prg[code_offset:code_offset + len(code)] = code

    # 16 KB PRG layout — addresses are PRG offsets, CPU sees them at $C000+offset.
    # Insert attribute byte lookup table at CPU $C580 = PRG $0580.
    for sp in range(4):
        byte = (sp << 6) | (sp << 4) | (sp << 2) | sp
        prg[0x0580 + sp] = byte

    # Insert palette reference table at CPU $C500 = PRG $0500.
    # Z1 OW orig palette per src/game/world/ow_palette.c:5
    z1_palette = [
        0x0F, 0x30, 0x00, 0x12,
        0x0F, 0x16, 0x27, 0x36,
        0x0F, 0x1A, 0x37, 0x12,
        0x0F, 0x17, 0x37, 0x12,
        0x0F, 0x29, 0x27, 0x17,
        0x0F, 0x02, 0x22, 0x30,
        0x0F, 0x16, 0x27, 0x30,
        0x0F, 0x0C, 0x1C, 0x2C,
    ]
    for i, v in enumerate(z1_palette):
        prg[0x0500 + i] = v

    # Insert nametable table at CPU $C600-$C9BF = PRG $0600-$09BF (960 bytes).
    # Layout: 16-wide × 16-tall tile grid (256 tiles) in top-left, rest = $00.
    for row in range(30):
        for col in range(32):
            cell = row * 32 + col
            if row < 16 and col < 16:
                tile_id = (row * 16) + col
            else:
                tile_id = 0x00
            prg[0x0600 + cell] = tile_id

    # Set vectors at $FFFA-$FFFF = PRG offset $3FFA-$3FFF (end of 16 KB PRG).
    nmi_addr   = a.labels["nmi"]
    reset_addr = a.labels["reset"]
    irq_addr   = a.labels["irq"]
    prg[0x3FFA] = nmi_addr & 0xFF
    prg[0x3FFB] = (nmi_addr >> 8) & 0xFF
    prg[0x3FFC] = reset_addr & 0xFF
    prg[0x3FFD] = (reset_addr >> 8) & 0xFF
    prg[0x3FFE] = irq_addr & 0xFF
    prg[0x3FFF] = (irq_addr >> 8) & 0xFF

    return bytes(prg)


# ---------------------------------------------------------------------------
# CHR page builder — pack reference Z1 .dat files into 8 KB PPU layout.
# ---------------------------------------------------------------------------

def read_dat(name: str) -> bytes:
    p = pathlib.Path("reference/aldonunez/dat") / name
    return p.read_bytes()


def build_chr_page(spr_blocks: list[tuple[bytes, int]],
                   bg_blocks: list[tuple[bytes, int]]) -> bytes:
    """8 KB page. Each block = (data_bytes, ppu_addr_offset_into_8kb).
    spr_blocks land at $0000-$0FFF region; bg_blocks at $1000-$1FFF.
    """
    page = bytearray(8192)
    for data, off in spr_blocks + bg_blocks:
        end = off + len(data)
        if end > 8192:
            raise ValueError(f"block at ${off:04X} + {len(data)} > 8 KB")
        page[off:end] = data
    return bytes(page)


def build_chr() -> list[bytes]:
    common_bg   = read_dat("CommonBackgroundPatterns.dat")
    common_spr  = read_dat("CommonSpritePatterns.dat")
    common_misc = read_dat("CommonMiscPatterns.dat")
    ow_bg       = read_dat("PatternBlockOWBG.dat")
    ow_sp       = read_dat("PatternBlockOWSP.dat")
    uw_bg       = read_dat("PatternBlockUWBG.dat")
    uw_sp       = read_dat("PatternBlockUWSP.dat")
    uw_sp127    = read_dat("PatternBlockUWSP127.dat")
    uw_sp358    = read_dat("PatternBlockUWSP358.dat")
    uw_sp469    = read_dat("PatternBlockUWSP469.dat")
    boss1257    = read_dat("PatternBlockUWSPBoss1257.dat")
    boss3468    = read_dat("PatternBlockUWSPBoss3468.dat")
    boss9       = read_dat("PatternBlockUWSPBoss9.dat")
    demo_bg     = read_dat("DemoBackgroundPatterns.dat")
    demo_sp     = read_dat("DemoSpritePatterns.dat")

    # Z1 PPU layout offsets (per Z_02.asm:69 + Z_03.asm:62):
    #   $0000  Common SPR  (112 tiles = $700 B)
    #   $08E0  Scene SPR   (PatternBlockXXSP at $08E0-$0FFF region)
    #   $09E0  UW-specific SPR (PatternBlockUWSP127/358/469)
    #   $0C00  Boss SPR    (PatternBlockUWSPBoss*)
    #   $1000  Common BG   (112 tiles = $700 B)
    #   $1700  Scene BG    (PatternBlockXXBG)
    #   $1F20  Common Misc (14 tiles)
    OFF_COMMON_SPR = 0x0000
    OFF_SCENE_SPR  = 0x08E0
    OFF_UW_LEVEL_SPR = 0x09E0
    OFF_BOSS_SPR   = 0x0C00
    OFF_COMMON_BG  = 0x1000
    OFF_SCENE_BG   = 0x1700
    OFF_COMMON_MISC = 0x1F20

    pages = []
    # Page 0: Common-only (BG + SPR + Misc) — baseline
    pages.append(build_chr_page(
        spr_blocks=[(common_spr, OFF_COMMON_SPR)],
        bg_blocks=[(common_bg, OFF_COMMON_BG), (common_misc, OFF_COMMON_MISC)],
    ))
    # Page 1: OW (Common + OW BG + OW SP)
    pages.append(build_chr_page(
        spr_blocks=[(common_spr, OFF_COMMON_SPR), (ow_sp, OFF_SCENE_SPR)],
        bg_blocks=[(common_bg, OFF_COMMON_BG), (ow_bg, OFF_SCENE_BG), (common_misc, OFF_COMMON_MISC)],
    ))
    # Page 2: UW1/2/7 (Common + UW BG + UW SP base + UWSP127)
    pages.append(build_chr_page(
        spr_blocks=[(common_spr, OFF_COMMON_SPR), (uw_sp, OFF_SCENE_SPR), (uw_sp127, OFF_UW_LEVEL_SPR)],
        bg_blocks=[(common_bg, OFF_COMMON_BG), (uw_bg, OFF_SCENE_BG), (common_misc, OFF_COMMON_MISC)],
    ))
    # Page 3: UW3/5/8
    pages.append(build_chr_page(
        spr_blocks=[(common_spr, OFF_COMMON_SPR), (uw_sp, OFF_SCENE_SPR), (uw_sp358, OFF_UW_LEVEL_SPR)],
        bg_blocks=[(common_bg, OFF_COMMON_BG), (uw_bg, OFF_SCENE_BG), (common_misc, OFF_COMMON_MISC)],
    ))
    # Page 4: UW4/6/9
    pages.append(build_chr_page(
        spr_blocks=[(common_spr, OFF_COMMON_SPR), (uw_sp, OFF_SCENE_SPR), (uw_sp469, OFF_UW_LEVEL_SPR)],
        bg_blocks=[(common_bg, OFF_COMMON_BG), (uw_bg, OFF_SCENE_BG), (common_misc, OFF_COMMON_MISC)],
    ))
    # Page 5: UW1257 boss
    pages.append(build_chr_page(
        spr_blocks=[(common_spr, OFF_COMMON_SPR), (uw_sp, OFF_SCENE_SPR), (boss1257, OFF_BOSS_SPR)],
        bg_blocks=[(common_bg, OFF_COMMON_BG), (uw_bg, OFF_SCENE_BG), (common_misc, OFF_COMMON_MISC)],
    ))
    # Page 6: UW3468 boss
    pages.append(build_chr_page(
        spr_blocks=[(common_spr, OFF_COMMON_SPR), (uw_sp, OFF_SCENE_SPR), (boss3468, OFF_BOSS_SPR)],
        bg_blocks=[(common_bg, OFF_COMMON_BG), (uw_bg, OFF_SCENE_BG), (common_misc, OFF_COMMON_MISC)],
    ))
    # Page 7: UW9 boss (Ganon)
    pages.append(build_chr_page(
        spr_blocks=[(common_spr, OFF_COMMON_SPR), (uw_sp, OFF_SCENE_SPR), (boss9, OFF_BOSS_SPR)],
        bg_blocks=[(common_bg, OFF_COMMON_BG), (uw_bg, OFF_SCENE_BG), (common_misc, OFF_COMMON_MISC)],
    ))
    # Page 8: Title demo
    pages.append(build_chr_page(
        spr_blocks=[(common_spr, OFF_COMMON_SPR), (demo_sp, OFF_SCENE_SPR)],
        bg_blocks=[(common_bg, OFF_COMMON_BG), (demo_bg, OFF_SCENE_BG), (common_misc, OFF_COMMON_MISC)],
    ))
    return pages


# ---------------------------------------------------------------------------
# iNES file emit
# ---------------------------------------------------------------------------

def emit_ines(prg: bytes, chr_pages: list[bytes]) -> bytes:
    header = bytearray(16)
    header[0:4] = b"NES\x1a"
    header[4]   = len(prg) // 16384         # PRG banks (16 KB each)
    header[5]   = len(chr_pages)            # CHR banks (8 KB each)
    header[6]   = 0x30                      # mapper 3 (CNROM) low nibble
    header[7]   = 0x00                      # mapper high nibble; NES 1.0
    return bytes(header) + prg + b"".join(chr_pages)


def main():
    prg = build_prg()
    chr_pages = build_chr()
    rom = emit_ines(prg, chr_pages)
    out = pathlib.Path("build/probes/chr_viewer_rom.nes")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(rom)
    print(f"wrote {out}")
    print(f"  PRG: {len(prg)} B ({len(prg)//1024} KB)")
    print(f"  CHR: {len(chr_pages)} pages × 8 KB = {len(chr_pages)*8} KB")
    print(f"  ROM total: {len(rom)} B")


if __name__ == "__main__":
    sys.exit(main())
