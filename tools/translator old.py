#!/usr/bin/env python3
"""
NES (6502) to Sega Genesis (68000) Assembly Translator
Phase 1: Core instruction translation
For use with cyneprepou4uk's Legend of Zelda disassembly
"""

import re
import sys
from dataclasses import dataclass, field
from typing import Optional

# ─────────────────────────────────────────────
# 6502 Register model
# A  = accumulator
# X, Y = index registers
# SP = stack pointer
# PC = program counter
# P  = status flags: N V - B D I Z C
#
# 68000 Register mapping:
# A  → D0 (primary data register)
# X  → D1
# Y  → D2
# SP → A7 (native stack pointer)
# Temp → D3, D4, D5
# NES RAM base ptr → A0
# NES flags emulation → D6 (N=bit7, V=bit6, Z=bit1, C=bit0)
# ─────────────────────────────────────────────

NES_RAM_BASE = "$FF0000"   # Where we map NES $0000-$07FF in Genesis RAM
NES_PPU_BASE = "$A00000"   # Placeholder - will need VDP translation layer

@dataclass
class Line:
    original: str
    label: Optional[str] = None
    mnemonic: Optional[str] = None
    operand: Optional[str] = None
    comment: Optional[str] = None
    output_lines: list = field(default_factory=list)

def parse_line(raw: str) -> Line:
    line = Line(original=raw)
    s = raw.strip()

    # Handle cyneprepou4uk disassembly listing lines
    # Format: "- D 0 - - - 0x003F6A 00:BF5A: AD 02 20  LDA $2002"
    # We need to EXTRACT the instruction at the end
    listing_match = re.match(
        r'^(?:[-\w]\s+){3,8}0x[0-9A-Fa-f]+\s+[0-9A-Fa-f]{2}:[0-9A-Fa-f]{4}:\s+(?:[0-9A-Fa-f]{2}\s+)+\s*(.*)',
        s
    )
    if listing_match:
        instruction_part = listing_match.group(1).strip()
        if instruction_part:
            s = instruction_part
        else:
            line.comment = "; [LISTING LINE - data only]"
            return line

    # Strip comment
    if ';' in s:
        idx = s.index(';')
        line.comment = s[idx:]
        s = s[:idx].strip()

    if not s:
        return line

    # Label (ends with ':') - support . and @ prefixes used by ca65
    label_match = re.match(r'^([A-Za-z_.@][A-Za-z0-9_.@]*):\s*(.*)', s)
    if label_match:
        line.label = label_match.group(1)
        s = label_match.group(2).strip()

    if not s:
        return line

    # Mnemonic + operand
    parts = s.split(None, 1)
    line.mnemonic = parts[0].upper()
    line.operand = parts[1].strip() if len(parts) > 1 else ""
    return line

def addr_mode(operand: str):
    """Classify 6502 addressing mode, return (mode, value)"""
    o = operand.strip()
    if not o:
        return ('implied', '')
    if o == 'A':
        return ('accumulator', '')
    if o.startswith('#'):
        return ('immediate', o[1:])
    if re.match(r'^\$[0-9A-Fa-f]{1,2}$', o):
        return ('zeropage', o)
    if re.match(r'^\$[0-9A-Fa-f]{1,2},X$', o):
        return ('zeropage_x', o.split(',')[0])
    if re.match(r'^\$[0-9A-Fa-f]{1,2},Y$', o):
        return ('zeropage_y', o.split(',')[0])
    if re.match(r'^\$[0-9A-Fa-f]{3,4}$', o):
        return ('absolute', o)
    if re.match(r'^\$[0-9A-Fa-f]{3,4},X$', o):
        return ('absolute_x', o.split(',')[0])
    if re.match(r'^\$[0-9A-Fa-f]{3,4},Y$', o):
        return ('absolute_y', o.split(',')[0])
    if re.match(r'^\([^)]+\),Y$', o):
        val = re.match(r'^\(([^)]+)\),Y$', o).group(1)
        return ('indirect_y', val)
    if re.match(r'^\([^)]+,X\)$', o):
        val = re.match(r'^\(([^)]+),X\)$', o).group(1)
        return ('indirect_x', val)
    if re.match(r'^\([^)]+\)$', o):
        val = re.match(r'^\(([^)]+)\)$', o).group(1)
        return ('indirect', val)
    # Named label / symbol
    if re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', o):
        return ('absolute_sym', o)
    if re.match(r'^[A-Za-z_][A-Za-z0-9_]*,X$', o):
        return ('absolute_x_sym', o.split(',')[0])
    if re.match(r'^[A-Za-z_][A-Za-z0-9_]*,Y$', o):
        return ('absolute_y_sym', o.split(',')[0])
    return ('unknown', o)

def zp_addr(zp: str) -> str:
    """Convert ZP address to Genesis absolute address"""
    if zp.startswith('$'):
        val = int(zp[1:], 16)
        return f"({NES_RAM_BASE}+${val:04X}).l"
    return f"({NES_RAM_BASE}+{zp}).l"

def abs_addr(addr: str) -> str:
    """Convert NES absolute address to Genesis address"""
    if addr.startswith('$'):
        val = int(addr[1:], 16)
        if val < 0x0800:
            return f"({NES_RAM_BASE}+${val:04X}).l"
        elif val >= 0x2000 and val < 0x4000:
            # PPU registers - needs special handling
            return f"PPU_REG_${val:04X}  ; !! PPU REGISTER - NEEDS VDP TRANSLATION !!"
        elif val >= 0x8000:
            # ROM space
            return f"ROM_${val:04X}"
    return addr

def translate_instruction(line: Line) -> list:
    mn = line.mnemonic
    op = line.operand or ""
    mode, val = addr_mode(op)
    out = []

    # ── Load instructions ──
    if mn == 'LDA':
        if mode == 'immediate':
            out.append(f"    MOVE.B  #{val},D0")
        elif mode in ('zeropage', 'zeropage_x', 'zeropage_y'):
            if mode == 'zeropage':
                out.append(f"    MOVE.B  {zp_addr(val)},D0")
            elif mode == 'zeropage_x':
                out.append(f"    MOVE.L  D1,D3")
                out.append(f"    ADD.L   #{NES_RAM_BASE},D3")
                out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
                out.append(f"    MOVE.B  (D3),D0")
            else:
                out.append(f"    MOVE.L  D2,D3")
                out.append(f"    ADD.L   #{NES_RAM_BASE},D3")
                out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
                out.append(f"    MOVE.B  (D3),D0")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    MOVE.B  {a},D0")
        elif mode in ('absolute_x', 'absolute_x_sym'):
            a = abs_addr(val) if mode == 'absolute_x' else val
            out.append(f"    MOVE.B  {a}(D1.L),D0  ; LDA abs,X")
        elif mode in ('absolute_y', 'absolute_y_sym'):
            a = abs_addr(val) if mode == 'absolute_y' else val
            out.append(f"    MOVE.B  {a}(D2.L),D0  ; LDA abs,Y")
        elif mode == 'indirect_y':
            out.append(f"    MOVEA.W {zp_addr(val)},A1  ; LDA (zp),Y")
            out.append(f"    MOVE.B  ({NES_RAM_BASE},A1,D2.W),D0")
        elif mode == 'indirect_x':
            out.append(f"    MOVE.L  D1,D3           ; LDA (zp,X)")
            out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
            out.append(f"    MOVEA.W ({NES_RAM_BASE},D3.L),A1")
            out.append(f"    MOVE.B  ({NES_RAM_BASE},A1.L),D0")

    elif mn == 'LDX':
        if mode == 'immediate':
            out.append(f"    MOVE.B  #{val},D1")
        elif mode == 'zeropage':
            out.append(f"    MOVE.B  {zp_addr(val)},D1")
        elif mode == 'zeropage_y':
            out.append(f"    MOVE.L  D2,D3")
            out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
            out.append(f"    MOVE.B  ({NES_RAM_BASE},D3.L),D1")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    MOVE.B  {a},D1")
        elif mode in ('absolute_y', 'absolute_y_sym'):
            a = abs_addr(val) if mode == 'absolute_y' else val
            out.append(f"    MOVE.B  {a}(D2.L),D1  ; LDX abs,Y")

    elif mn == 'LDY':
        if mode == 'immediate':
            out.append(f"    MOVE.B  #{val},D2")
        elif mode == 'zeropage':
            out.append(f"    MOVE.B  {zp_addr(val)},D2")
        elif mode == 'zeropage_x':
            out.append(f"    MOVE.L  D1,D3")
            out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
            out.append(f"    MOVE.B  ({NES_RAM_BASE},D3.L),D2")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    MOVE.B  {a},D2")
        elif mode in ('absolute_x', 'absolute_x_sym'):
            a = abs_addr(val) if mode == 'absolute_x' else val
            out.append(f"    MOVE.B  {a}(D1.L),D2  ; LDY abs,X")

    # ── Store instructions ──
    elif mn == 'STA':
        if mode == 'zeropage':
            out.append(f"    MOVE.B  D0,{zp_addr(val)}")
        elif mode == 'zeropage_x':
            out.append(f"    MOVE.L  D1,D3")
            out.append(f"    ADD.L   #{NES_RAM_BASE},D3")
            out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
            out.append(f"    MOVE.B  D0,(D3)")
        elif mode == 'zeropage_y':
            out.append(f"    MOVE.L  D2,D3")
            out.append(f"    ADD.L   #{NES_RAM_BASE},D3")
            out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
            out.append(f"    MOVE.B  D0,(D3)")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    MOVE.B  D0,{a}")
        elif mode in ('absolute_x', 'absolute_x_sym'):
            a = abs_addr(val) if mode == 'absolute_x' else val
            out.append(f"    MOVE.B  D0,{a}(D1.L)  ; STA abs,X")
        elif mode in ('absolute_y', 'absolute_y_sym'):
            a = abs_addr(val) if mode == 'absolute_y' else val
            out.append(f"    MOVE.B  D0,{a}(D2.L)  ; STA abs,Y")
        elif mode == 'indirect_y':
            out.append(f"    MOVEA.W {zp_addr(val)},A1  ; STA (zp),Y")
            out.append(f"    MOVE.B  D0,({NES_RAM_BASE},A1,D2.W)")
        elif mode == 'indirect_x':
            out.append(f"    MOVE.L  D1,D3           ; STA (zp,X)")
            out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
            out.append(f"    MOVEA.W ({NES_RAM_BASE},D3.L),A1")
            out.append(f"    MOVE.B  D0,({NES_RAM_BASE},A1.L)")

    elif mn == 'STX':
        if mode == 'zeropage':
            out.append(f"    MOVE.B  D1,{zp_addr(val)}")
        elif mode == 'zeropage_y':
            out.append(f"    MOVE.L  D2,D3")
            out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
            out.append(f"    MOVE.B  D1,({NES_RAM_BASE},D3.L)")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    MOVE.B  D1,{a}")

    elif mn == 'STY':
        if mode == 'zeropage':
            out.append(f"    MOVE.B  D2,{zp_addr(val)}")
        elif mode == 'zeropage_x':
            out.append(f"    MOVE.L  D1,D3")
            out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
            out.append(f"    MOVE.B  D2,({NES_RAM_BASE},D3.L)")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    MOVE.B  D2,{a}")

    # ── Transfer instructions ──
    elif mn == 'TAX':
        out.append(f"    MOVE.B  D0,D1           ; TAX")
    elif mn == 'TAY':
        out.append(f"    MOVE.B  D0,D2           ; TAY")
    elif mn == 'TXA':
        out.append(f"    MOVE.B  D1,D0           ; TXA")
    elif mn == 'TYA':
        out.append(f"    MOVE.B  D2,D0           ; TYA")
    elif mn == 'TSX':
        out.append(f"    MOVE.L  A7,D1           ; TSX (approx)")
    elif mn == 'TXS':
        out.append(f"    MOVE.L  D1,A7           ; TXS (approx)")

    # ── Arithmetic ──
    elif mn == 'ADC':
        if mode == 'immediate':
            out.append(f"    ADDX.B  #{val},D0       ; ADC imm (uses X flag for carry)")
        elif mode == 'zeropage':
            out.append(f"    ADDX.B  {zp_addr(val)},D0")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    ADDX.B  {a},D0")
        else:
            out.append(f"    ; !! ADC {op} - complex mode, manual review needed")

    elif mn == 'SBC':
        if mode == 'immediate':
            out.append(f"    SUBX.B  #{val},D0       ; SBC imm")
        elif mode == 'zeropage':
            out.append(f"    SUBX.B  {zp_addr(val)},D0")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    SUBX.B  {a},D0")
        else:
            out.append(f"    ; !! SBC {op} - complex mode, manual review needed")

    elif mn == 'INC':
        if mode == 'zeropage':
            out.append(f"    ADDQ.B  #1,{zp_addr(val)}")
        elif mode == 'zeropage_x':
            out.append(f"    MOVE.L  D1,D3")
            out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
            out.append(f"    ADDQ.B  #1,({NES_RAM_BASE},D3.L)")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    ADDQ.B  #1,{a}")

    elif mn == 'DEC':
        if mode == 'zeropage':
            out.append(f"    SUBQ.B  #1,{zp_addr(val)}")
        elif mode == 'zeropage_x':
            out.append(f"    MOVE.L  D1,D3")
            out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
            out.append(f"    SUBQ.B  #1,({NES_RAM_BASE},D3.L)")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    SUBQ.B  #1,{a}")

    elif mn == 'INX':
        out.append(f"    ADDQ.B  #1,D1           ; INX")
    elif mn == 'INY':
        out.append(f"    ADDQ.B  #1,D2           ; INY")
    elif mn == 'DEX':
        out.append(f"    SUBQ.B  #1,D1           ; DEX")
    elif mn == 'DEY':
        out.append(f"    SUBQ.B  #1,D2           ; DEY")

    # ── Logical ──
    elif mn == 'AND':
        if mode == 'immediate':
            out.append(f"    ANDI.B  #{val},D0")
        elif mode == 'zeropage':
            out.append(f"    AND.B   {zp_addr(val)},D0")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    AND.B   {a},D0")
        else:
            out.append(f"    ; !! AND {op} - needs manual review")

    elif mn == 'ORA':
        if mode == 'immediate':
            out.append(f"    ORI.B   #{val},D0")
        elif mode == 'zeropage':
            out.append(f"    OR.B    {zp_addr(val)},D0")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    OR.B    {a},D0")
        else:
            out.append(f"    ; !! ORA {op} - needs manual review")

    elif mn == 'EOR':
        if mode == 'immediate':
            out.append(f"    EORI.B  #{val},D0")
        elif mode == 'zeropage':
            out.append(f"    EOR.B   {zp_addr(val)},D0")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    EOR.B   {a},D0")
        else:
            out.append(f"    ; !! EOR {op} - needs manual review")

    elif mn == 'BIT':
        if mode == 'zeropage':
            out.append(f"    BTST    D0,{zp_addr(val)}  ; BIT zp (approx - sets Z only)")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    BTST    D0,{a}  ; BIT abs")

    # ── Shifts / Rotates ──
    elif mn == 'ASL':
        if mode == 'accumulator' or not op:
            out.append(f"    ASL.B   #1,D0           ; ASL A")
        elif mode == 'zeropage':
            out.append(f"    ASL.B   #1,{zp_addr(val)}")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    ASL.B   #1,{a}")

    elif mn == 'LSR':
        if mode == 'accumulator' or not op:
            out.append(f"    LSR.B   #1,D0           ; LSR A")
        elif mode == 'zeropage':
            out.append(f"    LSR.B   #1,{zp_addr(val)}")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    LSR.B   #1,{a}")

    elif mn == 'ROL':
        if mode == 'accumulator' or not op:
            out.append(f"    ROXL.B  #1,D0           ; ROL A (uses X flag)")
        elif mode == 'zeropage':
            out.append(f"    ROXL.B  #1,{zp_addr(val)}")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    ROXL.B  #1,{a}")

    elif mn == 'ROR':
        if mode == 'accumulator' or not op:
            out.append(f"    ROXR.B  #1,D0           ; ROR A (uses X flag)")
        elif mode == 'zeropage':
            out.append(f"    ROXR.B  #1,{zp_addr(val)}")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    ROXR.B  #1,{a}")

    # ── Compare ──
    elif mn == 'CMP':
        if mode == 'immediate':
            out.append(f"    CMPI.B  #{val},D0")
        elif mode == 'zeropage':
            out.append(f"    CMP.B   {zp_addr(val)},D0")
        elif mode == 'zeropage_x':
            out.append(f"    MOVE.L  D1,D3")
            out.append(f"    ADD.L   #${int(val[1:],16):04X},D3")
            out.append(f"    CMP.B   ({NES_RAM_BASE},D3.L),D0")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    CMP.B   {a},D0")
        elif mode in ('absolute_x', 'absolute_x_sym'):
            a = abs_addr(val) if mode == 'absolute_x' else val
            out.append(f"    CMP.B   {a}(D1.L),D0")
        elif mode in ('absolute_y', 'absolute_y_sym'):
            a = abs_addr(val) if mode == 'absolute_y' else val
            out.append(f"    CMP.B   {a}(D2.L),D0")
        elif mode == 'indirect_y':
            out.append(f"    MOVEA.W {zp_addr(val)},A1")
            out.append(f"    CMP.B   ({NES_RAM_BASE},A1,D2.W),D0")
        else:
            out.append(f"    ; !! CMP {op} - needs manual review")

    elif mn == 'CPX':
        if mode == 'immediate':
            out.append(f"    CMPI.B  #{val},D1")
        elif mode == 'zeropage':
            out.append(f"    CMP.B   {zp_addr(val)},D1")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    CMP.B   {a},D1")

    elif mn == 'CPY':
        if mode == 'immediate':
            out.append(f"    CMPI.B  #{val},D2")
        elif mode == 'zeropage':
            out.append(f"    CMP.B   {zp_addr(val)},D2")
        elif mode in ('absolute', 'absolute_sym'):
            a = abs_addr(val) if mode == 'absolute' else val
            out.append(f"    CMP.B   {a},D2")

    # ── Branches ──
    elif mn == 'BEQ':
        out.append(f"    BEQ     {op}             ; BEQ")
    elif mn == 'BNE':
        out.append(f"    BNE     {op}             ; BNE")
    elif mn == 'BCC':
        out.append(f"    BCC     {op}             ; BCC")
    elif mn == 'BCS':
        out.append(f"    BCS     {op}             ; BCS")
    elif mn == 'BMI':
        out.append(f"    BMI     {op}             ; BMI")
    elif mn == 'BPL':
        out.append(f"    BPL     {op}             ; BPL")
    elif mn == 'BVC':
        out.append(f"    BVC     {op}             ; BVC")
    elif mn == 'BVS':
        out.append(f"    BVS     {op}             ; BVS")

    # ── Jumps / Calls ──
    elif mn == 'JMP':
        if mode == 'indirect':
            out.append(f"    MOVEA.L ({val}),A1      ; JMP indirect")
            out.append(f"    JMP     (A1)")
        else:
            out.append(f"    JMP     {op}")
    elif mn == 'JSR':
        out.append(f"    BSR     {op}             ; JSR -> BSR")
    elif mn == 'RTS':
        out.append(f"    RTS                     ; RTS")
    elif mn == 'RTI':
        out.append(f"    RTE                     ; RTI -> RTE (!! review flags)")

    # ── Stack ──
    elif mn == 'PHA':
        out.append(f"    MOVE.B  D0,-(A7)        ; PHA")
    elif mn == 'PLA':
        out.append(f"    MOVE.B  (A7)+,D0        ; PLA")
    elif mn == 'PHP':
        out.append(f"    MOVE    SR,-(A7)        ; PHP (approx)")
    elif mn == 'PLP':
        out.append(f"    MOVE    (A7)+,SR        ; PLP (approx - !! privilege risk)")

    # ── Flag instructions ──
    elif mn == 'CLC':
        out.append(f"    ANDI    #$FFFE,SR       ; CLC (clear carry)")
    elif mn == 'SEC':
        out.append(f"    ORI     #$0001,SR       ; SEC (set carry)")
    elif mn == 'CLI':
        out.append(f"    ANDI    #$F8FF,SR       ; CLI (enable interrupts)")
    elif mn == 'SEI':
        out.append(f"    ORI     #$0700,SR       ; SEI (disable interrupts)")
    elif mn == 'CLD':
        out.append(f"    ; CLD (clear decimal) - 68000 has no decimal mode, NOP")
    elif mn == 'SED':
        out.append(f"    ; SED (set decimal) - 68000 has no decimal mode, NOP")
    elif mn == 'CLV':
        out.append(f"    ANDI    #$FBFF,SR       ; CLV (clear overflow)")

    # ── NOP ──
    elif mn == 'NOP':
        out.append(f"    NOP")

    # ── Directives (pass through with comment) ──
    elif mn in ('.BYTE', '.WORD', '.DB', '.DW', '.ORG', '.SEGMENT', '.PROC',
                '.ENDPROC', '.INCLUDE', '.DEFINE', '.IF', '.ENDIF', '.ELSE',
                '.IFDEF', '.IFNDEF', '.MACRO', '.ENDMACRO', '.EXPORT',
                '.IMPORT', '.EXPORTZP', '.IMPORTZP', '.ADDR', '.LOBYTE',
                '.HIBYTE', '.RES', '.ALIGN', '.SCOPE', '.ENDSCOPE',
                '.ENUM', '.ENDENUM', '.STRUCT', '.ENDSTRUCT'):
        out.append(f"    ; [DIRECTIVE] {mn} {op}  -- needs manual handling")

    else:
        out.append(f"    ; !! UNKNOWN: {mn} {op}")

    return out

def translate_file(input_path: str) -> str:
    results = []
    stats = {'translated': 0, 'warnings': 0, 'directives': 0, 'unknown': 0}

    results.append("; ═══════════════════════════════════════════════════════")
    results.append(f"; AUTO-TRANSLATED from NES 6502 → Sega Genesis 68000")
    results.append(f"; Source: {input_path}")
    results.append("; !! This is a FIRST PASS - hardware I/O needs manual work !!")
    results.append("; Register mapping:")
    results.append(";   A (accumulator) → D0")
    results.append(";   X (index)       → D1")
    results.append(";   Y (index)       → D2")
    results.append(";   Temp            → D3, D4, D5")
    results.append(";   NES RAM base    → A0 = $FF0000")
    results.append("; ═══════════════════════════════════════════════════════")
    results.append("")

    try:
        with open(input_path, 'r', errors='replace') as f:
            lines = f.readlines()
    except FileNotFoundError:
        return f"; ERROR: File not found: {input_path}"

    for raw in lines:
        line = parse_line(raw)
        out_parts = []

        # Reconstruct label
        if line.label:
            out_parts.append(f"{line.label}:")

        if line.mnemonic:
            translated = translate_instruction(line)
            if translated:
                for t in translated:
                    if '!! UNKNOWN' in t:
                        stats['unknown'] += 1
                    elif '!! ' in t or 'DIRECTIVE' in t:
                        stats['warnings'] += 1
                    else:
                        stats['translated'] += 1
                out_parts.extend(translated)
            else:
                out_parts.append(f"    ; (empty translation for {line.mnemonic})")
        elif not line.label and not line.mnemonic:
            out_parts.append("")  # blank line

        # Append original as comment
        if line.comment and not line.mnemonic:
            out_parts.append(line.comment)
        elif line.original.strip() and (line.mnemonic or line.label):
            if out_parts:
                out_parts[-1] += f"  ; orig: {line.original.strip()[:60]}"

        results.extend(out_parts)

    results.append("")
    results.append(f"; ── Translation Stats ──")
    results.append(f"; Translated:  {stats['translated']}")
    results.append(f"; Warnings:    {stats['warnings']}")
    results.append(f"; Unknown:     {stats['unknown']}")

    return '\n'.join(results)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 translator.py <input.asm> [output.asm]")
        print("Example: python3 translator.py bank_00.asm bank_00_gen.asm")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else input_file.replace('.asm', '_gen68k.asm')

    print(f"Translating {input_file} → {output_file}...")
    result = translate_file(input_file)

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(result)

    print(f"Done! Output written to {output_file}")
