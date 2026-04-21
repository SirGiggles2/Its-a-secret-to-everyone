#!/usr/bin/env python3
"""
transpile_6502.py — 6502 (ca65) to M68K (vasmm68k_mot) ASM transpiler.

Reads reference/aldonunez/Z_XX.asm and writes src/zelda_translated/z_XX.asm.

Register mapping:
    6502 A  → D0    accumulator
    6502 X  → D2    X index
    6502 Y  → D3    Y index
    6502 SP → A5    NES stack pointer (NES_RAM+$0100 area)
    A4      = NES_RAM base ($FF0000) — must be initialized by shell

T2 milestone: Z_07.asm transpiles and assembles with vasm zero errors.
"""

import re
import sys
import os
import argparse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF_DIR = os.path.join(ROOT, "reference", "aldonunez")
OUT_DIR = os.path.join(ROOT, "src", "zelda_translated")

NES_RAM_BASE  = 0xFF0000
NES_SRAM_BASE = 0xFF6000

# ---------------------------------------------------------------------------
# Symbol table loader (ca65 := syntax)
# ---------------------------------------------------------------------------

def load_inc(path):
    """Parse ca65 .inc file of the form: Name := $XXXX"""
    symtab = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.match(r'^\s*(\w+)\s*:?=\s*(\$[0-9A-Fa-f]+|\d+)', line)
            if m:
                name = m.group(1)
                val  = m.group(2)
                symtab[name] = int(val[1:], 16) if val.startswith('$') else int(val)
    return symtab

def build_symtab():
    symtab = {}
    for fname in ("Variables.inc", "CommonVars.inc", "ObjVars.inc",
                  "BeginEndVars.inc", "CaveVars.inc"):
        p = os.path.join(REF_DIR, fname)
        if os.path.exists(p):
            symtab.update(load_inc(p))
    return symtab

# ---------------------------------------------------------------------------
# NES address classification
# ---------------------------------------------------------------------------

def nes_classify(addr):
    if addr < 0x0800:    return 'ram'
    if addr < 0x2000:    return 'mirror'
    if addr < 0x2008:    return 'ppu'
    if addr < 0x4000:    return 'mirror'
    if addr < 0x4020:    return 'apu_io'
    if addr < 0x6000:    return 'cart'
    if addr < 0x8000:    return 'sram'
    return 'prg'         # ROM or MMC1 registers

def resolve_sym(token, symtab):
    """Return integer address if token is a known symbol, hex literal, or sym+/-offset."""
    token = token.strip()
    if token.startswith('$'):
        return int(token[1:], 16)
    if re.match(r'^\d+$', token):
        return int(token)
    # Handle symbol+offset or symbol-offset
    m = re.match(r'^(\w+)\s*([+\-])\s*(\$[\dA-Fa-f]+|\d+)$', token)
    if m:
        base_name = m.group(1)
        op = m.group(2)
        offset_str = m.group(3)
        offset = int(offset_str[1:], 16) if offset_str.startswith('$') else int(offset_str)
        base = symtab.get(base_name)
        if base is not None:
            return base + offset if op == '+' else base - offset
    return symtab.get(token, None)

# ---------------------------------------------------------------------------
# M68K effective address generation
# ---------------------------------------------------------------------------

def ea_read_byte(addr_or_sym, index=None, symtab=None, is_indirect_y=False,
                 is_indexed_x=False):
    """
    Return (lines_before, ea_string) for a NES byte read.
    lines_before: list of M68K lines to emit before the main instruction.
    ea_string: the effective address string for the move instruction.
    index: 'X' or 'Y' or None
    """
    # Resolve symbol to address if possible
    addr = None
    sym  = addr_or_sym
    if isinstance(addr_or_sym, int):
        addr = addr_or_sym
    else:
        addr = resolve_sym(addr_or_sym, symtab or {})

    if addr is None:
        # Unknown symbol — it's a code/data label in this bank (ROM data) or an import.
        # Use the raw expression; vasm handles label arithmetic like Label+1.
        expr = addr_or_sym.replace(' ', '')  # strip whitespace only
        if index == 'X':
            return ([f"    lea     ({expr}).l,A0"],
                    "(A0,D2.W)")
        elif index == 'Y':
            return ([f"    lea     ({expr}).l,A0"],
                    "(A0,D3.W)")
        else:
            return ([], f"({expr}).l")

    cls = nes_classify(addr)

    if cls == 'ram' or cls == 'mirror':
        real_addr = addr & 0x07FF  # mirror wraps
        if index == 'X':
            if real_addr <= 127:
                return ([], f"(${real_addr:02X},A4,D2.W)")
            else:
                return ([f"    lea     (${real_addr:04X},A4),A0"],
                        "(A0,D2.W)")
        elif index == 'Y':
            if real_addr <= 127:
                return ([], f"(${real_addr:02X},A4,D3.W)")
            else:
                return ([f"    lea     (${real_addr:04X},A4),A0"],
                        "(A0,D3.W)")
        else:
            return ([], f"(${real_addr:04X},A4)")

    elif cls == 'ppu':
        reg = addr & 7
        if index:
            # Unusual — PPU indexed access
            return ([f"    ; PPU read reg {reg} (indexed — stub)"],
                    "#0")
        return ([f"    bsr     _ppu_read_{reg}  ; PPU ${addr:04X} read → D0"],
                "_ppu_result")

    elif cls == 'apu_io':
        if addr == 0x4016:
            return ([f"    bsr     _ctrl_read_1    ; $4016 controller 1 → D0"],
                    "_ctrl_result")
        elif addr == 0x4017:
            return ([f"    bsr     _ctrl_read_2    ; $4017 controller 2 → D0"],
                    "_ctrl_result")
        elif addr == 0x4015:
            return ([f"    ; APU status read stub"], "#0")
        else:
            return ([f"    ; APU read ${addr:04X} stub"], "#0")

    elif cls == 'sram':
        offset = addr - 0x6000
        if index == 'X':
            return ([f"    lea     (NES_SRAM+${offset:04X}).l,A0"],
                    "(A0,D2.W)")
        elif index == 'Y':
            return ([f"    lea     (NES_SRAM+${offset:04X}).l,A0"],
                    "(A0,D3.W)")
        else:
            return ([], f"(NES_SRAM+${offset:04X}).l")

    elif cls == 'prg':
        # ROM or MMC1 register — should not normally be read as data
        return ([f"    ; PRG read ${addr:04X} — unexpected"], "#0")

    else:
        return ([f"    ; Unknown NES addr ${addr:04X} read"], "#0")


def ea_write_byte(addr_or_sym, index=None, symtab=None):
    """
    Return (lines_before, ea_string_or_None, special_write_lines).
    If ea_string is not None: emit  MOVE.B D0, ea_string
    If ea_string is None: emit special_write_lines instead (replaces the store).
    lines_before are emitted before the store.
    """
    addr = None
    if isinstance(addr_or_sym, int):
        addr = addr_or_sym
    else:
        addr = resolve_sym(addr_or_sym, symtab or {})

    if addr is None:
        # Unknown symbol — ROM data label; use raw expression for vasm arithmetic
        expr = addr_or_sym.replace(' ', '')
        if index == 'X':
            return ([f"    lea     ({expr}).l,A0"],
                    "(A0,D2.W)", [])
        elif index == 'Y':
            return ([f"    lea     ({expr}).l,A0"],
                    "(A0,D3.W)", [])
        else:
            return ([], f"({expr}).l", [])

    cls = nes_classify(addr)

    if cls == 'ram' or cls == 'mirror':
        real_addr = addr & 0x07FF
        if index == 'X':
            if real_addr <= 127:
                return ([], f"(${real_addr:02X},A4,D2.W)", [])
            else:
                return ([f"    lea     (${real_addr:04X},A4),A0"],
                        "(A0,D2.W)", [])
        elif index == 'Y':
            if real_addr <= 127:
                return ([], f"(${real_addr:02X},A4,D3.W)", [])
            else:
                return ([f"    lea     (${real_addr:04X},A4),A0"],
                        "(A0,D3.W)", [])
        else:
            return ([], f"(${real_addr:04X},A4)", [])

    elif cls == 'ppu':
        reg = addr & 7
        if index:
            return ([], None,
                    [f"    ; PPU write reg {reg} indexed stub",
                     f"    bsr     _ppu_write_{reg}"])
        return ([], None,
                [f"    bsr     _ppu_write_{reg}  ; PPU ${addr:04X} write, D0=val"])

    elif cls == 'apu_io':
        if addr == 0x4014:
            return ([], None,
                    ["    bsr     _oam_dma         ; $4014 OAM DMA, D0=page"])
        elif addr == 0x4016:
            return ([], None,
                    ["    bsr     _ctrl_strobe     ; $4016 controller strobe"])
        else:
            return ([], None,
                    [f"    bsr     _apu_write_{addr:04x}  ; APU/IO write"])

    elif cls == 'sram':
        offset = addr - 0x6000
        if index == 'X':
            return ([f"    lea     (NES_SRAM+${offset:04X}).l,A0"],
                    "(A0,D2.W)", [])
        elif index == 'Y':
            return ([f"    lea     (NES_SRAM+${offset:04X}).l,A0"],
                    "(A0,D3.W)", [])
        else:
            return ([], f"(NES_SRAM+${offset:04X}).l", [])

    elif cls == 'prg':
        # MMC1 register write (bank switch or config)
        # STA $8000/$A000/$C000/$E000 → MMC1 write
        return ([], None,
                [f"    bsr     _mmc1_write_{addr:04x}  ; MMC1 reg write, D0=val"])

    else:
        return ([], None,
                [f"    ; Unknown NES write ${addr:04X} stub"])

# ---------------------------------------------------------------------------
# Operand parser
# ---------------------------------------------------------------------------

# Address token: symbol, symbol+N, symbol-N, $hex, or decimal
_ADDR_TOK = r'(?:\w+(?:\s*[+\-]\s*(?:\$[\dA-Fa-f]+|\d+))?|\$[\dA-Fa-f]+|\d+)'

ADDR_MODE_RE = re.compile(
    r'^\s*(?:'
    r'\((' + _ADDR_TOK + r'),\s*X\)'    # group 1: ($nn,X)
    r'|\((' + _ADDR_TOK + r')\),\s*Y'   # group 2: ($nn),Y
    r'|\((' + _ADDR_TOK + r')\)'        # group 3: ($nnnn) indirect
    r'|[#](\$[\dA-Fa-f]+|\d+)'          # group 4: #n immediate
    r'|(' + _ADDR_TOK + r'),\s*X'       # group 5: nn,X
    r'|(' + _ADDR_TOK + r'),\s*Y'       # group 6: nn,Y
    r'|(A)(?=\s|$)'                      # group 7: A accumulator
    r'|(:\++|:-+)'                        # group 8: anon ref (multi-level: :++, :--)
    r'|([\w.@]+(?:\s*[+\-]\s*(?:\$[\dA-Fa-f]+|\d+))?|\$[\dA-Fa-f]+)'  # group 9
    r')?\s*(?:;.*)?$'
)

def parse_operand(operand_str, symtab):
    """Returns (mode, value) where mode is one of:
       'IND_X', 'IND_Y', 'IND_ABS', 'IMM', 'ABS_X', 'ABS_Y',
       'ACC', 'ANON', 'ABS', 'IMPL'
    value: string token or integer.
    """
    s = operand_str.strip()
    if not s or s.startswith(';'):
        return ('IMPL', None)

    # Remove inline comment
    s = re.sub(r'\s*;.*$', '', s).strip()

    # Strip ca65 addressing-mode prefixes: a: (absolute force), z: (zero page force)
    s = re.sub(r'\b[azAZ]:', '', s)

    # Handle ca65 low/high byte operators: #<expr and #>expr
    lo_m = re.match(r'^#<(.+)$', s)
    hi_m = re.match(r'^#>(.+)$', s)
    if lo_m or hi_m:
        inner = (lo_m or hi_m).group(1).strip()
        # Strip outer parens if present: #<(expr)
        inner = re.sub(r'^\((.+)\)$', r'\1', inner)
        addr = resolve_sym(inner, symtab or {})
        if addr is None:
            # Try evaluating expression: "Symbol + $NN" or "Symbol + NN"
            em = re.match(r'(\w+)\s*\+\s*(\$[\dA-Fa-f]+|\d+)', inner)
            if em:
                base = symtab.get(em.group(1))
                off_s = em.group(2)
                off = int(off_s[1:], 16) if off_s.startswith('$') else int(off_s)
                if base is not None:
                    addr = base + off
        if addr is not None:
            val = (addr & 0xFF) if lo_m else ((addr >> 8) & 0xFF)
            return ('IMM', val)
        # Can't resolve — fall through as raw immediate 0 stub
        return ('IMM', 0)

    m = ADDR_MODE_RE.match(s)
    if not m:
        return ('ABS', s)

    if m.group(1):  return ('IND_X',   m.group(1))
    if m.group(2):  return ('IND_Y',   m.group(2))
    if m.group(3):  return ('IND_ABS', m.group(3))
    if m.group(4):
        v = m.group(4)
        return ('IMM', int(v[1:], 16) if v.startswith('$') else int(v))
    if m.group(5):  return ('ABS_X',   m.group(5))
    if m.group(6):  return ('ABS_Y',   m.group(6))
    if m.group(7):  return ('ACC',     'A')
    if m.group(8):  return ('ANON',    m.group(8))
    if m.group(9):  return ('ABS',     m.group(9))

    return ('IMPL', None)

# ---------------------------------------------------------------------------
# Anonymous label pre-pass
# ---------------------------------------------------------------------------

def prepass_anon(lines):
    """
    Returns (anon_defs, anon_refs) where:
    anon_defs[line_idx] = N  (this line defines anonymous label N)
    anon_refs[line_idx] = N  (this line's :+/:- resolves to label N)
    """
    anon_defs = {}   # line_idx → label_number
    anon_positions = []  # list of (line_idx, label_number) in order

    counter = [0]

    def next_n():
        n = counter[0]
        counter[0] += 1
        return n

    # First pass: find all `:` label definitions
    for i, line in enumerate(lines):
        stripped = line.strip()
        # Anonymous label: line is just ':' (possibly with comment)
        if re.match(r'^:\s*(;.*)?$', stripped):
            n = next_n()
            anon_defs[i] = n
            anon_positions.append((i, n))

    # Second pass: find all :+... and :-... references and resolve them
    anon_refs = {}
    for i, line in enumerate(lines):
        # Find the anon ref token in the line, e.g. :++, :-, :++++
        ref_m = re.search(r'(:\++|:-+)', line)
        if not ref_m:
            continue
        token = ref_m.group(1)   # e.g. ':+', ':++', ':-', ':--'
        depth = len(token) - 1   # number of + or - chars = how many to skip
        direction = token[1]     # '+' or '-'

        if direction == '+':
            # Find the depth-th anon def AFTER line i
            found = [n for pos, n in anon_positions if pos > i]
            idx = depth - 1
            target = found[idx] if idx < len(found) else counter[0]
            anon_refs[i] = ('+', target)
        else:
            # Find the depth-th anon def BEFORE line i (reversed)
            found = [n for pos, n in reversed(anon_positions) if pos < i]
            idx = depth - 1
            target = found[idx] if idx < len(found) else 0
            anon_refs[i] = ('-', target)

    return anon_defs, anon_refs


def prepass_local_labels(src_lines, bank_tag):
    """
    Build a mapping for ca65 @LocalLabel references to globally unique names.

    In ca65, @Label is scoped to the nearest preceding non-anonymous global label.
    We convert each @Label: definition to a unique global name so vasm's local
    scope rules don't interfere (avoids the scope-break caused by anonymous labels
    being translated to global labels).

    Returns:
      local_defs:  dict (ca65_scope, local_name) -> unique_label_string
      scope_at:    dict line_idx -> ca65_scope_name (nearest named global label)
    """
    # Pass 1: compute ca65 scope for every line
    scope_at = {}
    cur_scope = '_TOP_'
    for i, raw in enumerate(src_lines):
        stripped = raw.strip()
        # Anonymous label line — doesn't change scope
        if re.match(r'^:\s*(;.*)?$', stripped):
            scope_at[i] = cur_scope
            continue
        # Named global label (not @ local)
        m = re.match(r'^([A-Za-z_]\w*)\s*:', raw)
        if m:
            cur_scope = m.group(1)
        scope_at[i] = cur_scope

    # Pass 2: find @Label: definitions and assign unique global names
    local_defs = {}   # (scope, local_name) -> unique_label
    dup_count  = {}   # (scope, local_name) -> number of times seen (for safety)
    for i, raw in enumerate(src_lines):
        m = re.match(r'^\s*(@\w+)\s*:(.*)', raw)
        if m:
            local_name = m.group(1)[1:]   # strip @
            scope = scope_at.get(i, '_TOP_')
            key = (scope, local_name)
            n = dup_count.get(key, 0)
            dup_count[key] = n + 1
            suffix = f'_{n}' if n > 0 else ''
            unique = f'_L_{bank_tag}_{scope}_{local_name}{suffix}'
            local_defs[key] = unique

    return local_defs, scope_at


# ---------------------------------------------------------------------------
# Line-by-line translator
# ---------------------------------------------------------------------------

BRANCH_MAP = {
    'BEQ': 'beq', 'BNE': 'bne',
    'BCC': 'bcc', 'BCS': 'bcs',
    'BPL': 'bpl', 'BMI': 'bmi',
    'BVC': 'bvc', 'BVS': 'bvs',
}

def translate_lines(src_lines, symtab, bank_tag, no_stubs=False, no_import_stubs=False,
                    other_exports=None, dup_exports=None,
                    all_nes_addrs=None, bank_nes_addrs=None, bank_num=None):
    """Translate list of ca65 lines to M68K lines."""
    anon_defs, anon_refs = prepass_anon(src_lines)
    local_defs, scope_at = prepass_local_labels(src_lines, bank_tag)

    out = []
    imports   = []   # symbols declared .IMPORT
    exports   = []   # symbols declared .EXPORT
    defined   = set()   # labels defined in this file (global)

    # Carry state for BCS/BCC inversion.
    # On 6502, CMP/CPX/CPY/SBC set C with the OPPOSITE polarity to M68K.
    #   6502 CMP: C=1 if A >= operand (no borrow)
    #   M68K CMPI: C=1 if D0 < operand (borrow)
    # So BCS (branch if 6502 C=1 = A >= n) must become M68K BCC (C=0 = D0 >= n).
    # We track whether C is "inverted" relative to M68K expectations.
    carry_state = {'inverted': False}

    # Track whether the next .ADDR block is a _m68k_tablejump table (dc.l)
    # vs a data pointer table (dc.b little-endian).
    in_jump_table = [False]

    def emit(s):
        out.append(s)

    def resolve_local(line_idx, local_name):
        """Resolve an @LocalName reference at line_idx to its unique global label."""
        scope = scope_at.get(line_idx, '_TOP_')
        key = (scope, local_name)
        return local_defs.get(key, f'_L_{bank_tag}_UNRESOLVED_{local_name}')

    for i, raw_line in enumerate(src_lines):
        line = raw_line.rstrip('\n').rstrip('\r')

        # ---------------------------------------------------------------
        # Anon label definition
        # ---------------------------------------------------------------
        if i in anon_defs:
            n = anon_defs[i]
            emit(f'_anon_{bank_tag}_{n}:')
            continue

        stripped = line.strip()

        # ---------------------------------------------------------------
        # Blank or pure comment
        # ---------------------------------------------------------------
        if not stripped or stripped.startswith(';'):
            emit(line)
            continue

        # ---------------------------------------------------------------
        # Directives
        # ---------------------------------------------------------------
        if stripped.startswith('.'):
            uline = stripped.upper()

            if uline.startswith('.INCLUDE'):
                emit(f'; [skipped] {stripped}')
                continue

            if uline.startswith('.SEGMENT'):
                emit(f'; === {stripped} ===')
                continue

            if uline.startswith('.IMPORT'):
                # May have multiple on one line: .IMPORT A, B, C
                syms = re.findall(r'\b([A-Za-z_]\w*)\b', stripped[7:])
                for s in syms:
                    if s not in imports:
                        imports.append(s)
                emit(f'; {stripped}')
                continue

            if uline.startswith('.EXPORT'):
                syms = re.findall(r'\b([A-Za-z_]\w*)\b', stripped[7:])
                for s in syms:
                    if s not in exports:
                        exports.append(s)
                emit(f'; {stripped}')
                continue

            if uline.startswith('.INCBIN'):
                m = re.search(r'"([^"]+)"', stripped)
                path = os.path.join(REF_DIR, m.group(1).replace('/', os.sep)) if m else None
                if path and os.path.exists(path):
                    data = open(path, 'rb').read()
                    emit(f'; .INCBIN {m.group(1)} ({len(data)} bytes)')
                    # Emit data in 16-byte rows
                    for off in range(0, len(data), 16):
                        chunk = data[off:off+16]
                        hex_str = ', '.join(f'${b:02X}' for b in chunk)
                        emit(f'    dc.b    {hex_str}')
                else:
                    fname = m.group(1) if m else '?'
                    emit(f'; .INCBIN "{fname}" not found — stub 128 zero bytes')
                    emit(f'    rept    128')
                    emit(f'        dc.b    0')
                    emit(f'    endr')
                continue

            if uline.startswith('.BYTE'):
                data_str = stripped[5:].strip()
                data_str = re.sub(r'\s*;.*$', '', data_str)
                emit(f'    dc.b    {data_str}')
                continue

            if uline.startswith('.WORD'):
                data_str = stripped[5:].strip()
                data_str = re.sub(r'\s*;.*$', '', data_str)
                emit(f'    dc.w    {data_str}')
                continue

            if uline.startswith('.DBYT'):
                # .DBYT = big-endian 16-bit word (hi byte first); dc.w is identical on M68K
                data_str = stripped[5:].strip()
                data_str = re.sub(r'\s*;.*$', '', data_str)
                emit(f'    dc.w    {data_str}')
                continue

            # .LOBYTES / .HIBYTES: store low/high bytes of 16-bit NES pointers.
            # For ROM labels (>= $8000), emit the literal NES CPU-address byte so
            # indirect-Y reads at runtime reconstruct a usable 6502 address that
            # maps into the bank window via `add.l #NES_RAM,...`. Falling back to
            # (Symbol)&$FF / (Symbol>>8)&$FF would store the low/high byte of the
            # Genesis ROM offset, which yields garbage when treated as a 6502
            # pointer (root cause of T38 AssignObjSpawnPositions failure).
            def _resolve_nes_byte(entry, hi_byte):
                nes_addr = None
                if entry.startswith('$'):
                    try:
                        nes_addr = int(entry[1:], 16) & 0xFFFF
                    except ValueError:
                        nes_addr = None
                elif re.match(r'^\d+$', entry):
                    nes_addr = int(entry) & 0xFFFF
                if nes_addr is None:
                    if bank_nes_addrs and entry in bank_nes_addrs:
                        nes_addr = bank_nes_addrs[entry]
                    elif all_nes_addrs and entry in all_nes_addrs:
                        nes_addr = all_nes_addrs[entry]
                if nes_addr is not None and nes_addr >= 0x8000:
                    b = (nes_addr >> 8) & 0xFF if hi_byte else nes_addr & 0xFF
                    tag = '>' if hi_byte else '<'
                    return f'    dc.b    ${b:02X}   ; {tag}{entry} (NES=${nes_addr:04X})'
                # Fallback: RAM equate / unresolved — keep expression form.
                expr = f'({entry}>>8)&$FF' if hi_byte else f'({entry})&$FF'
                return f'    dc.b    {expr}'

            if uline.startswith('.LOBYTES'):
                data_str = stripped[8:].strip()
                data_str = re.sub(r'\s*;.*$', '', data_str)
                entries = [x.strip() for x in data_str.split(',') if x.strip()]
                if not entries:
                    raise ValueError(f"{bank_tag}: empty .LOBYTES directive on line {i+1}")
                for entry in entries:
                    emit(_resolve_nes_byte(entry, hi_byte=False))
                continue

            if uline.startswith('.HIBYTES'):
                data_str = stripped[8:].strip()
                data_str = re.sub(r'\s*;.*$', '', data_str)
                entries = [x.strip() for x in data_str.split(',') if x.strip()]
                if not entries:
                    raise ValueError(f"{bank_tag}: empty .HIBYTES directive on line {i+1}")
                for entry in entries:
                    emit(_resolve_nes_byte(entry, hi_byte=True))
                continue

            if uline.startswith('.ADDR'):
                data_str = stripped[5:].strip()
                data_str = re.sub(r'\s*;.*$', '', data_str)
                entries = [x.strip() for x in data_str.split(',') if x.strip()]
                if not entries:
                    raise ValueError(f"{bank_tag}: empty .ADDR directive on line {i+1}")
                if in_jump_table[0]:
                    # Jump table entry: _m68k_tablejump reads dc.l (32-bit M68K addresses)
                    for entry in entries:
                        emit(f'    dc.l    {entry}   ; jump table entry (32-bit for _m68k_tablejump)')
                else:
                    # Data pointer table: keep NES 16-bit little-endian bytes.
                    # For ROM labels, emit literal NES CPU address bytes.
                    # For RAM equates / unknown symbols, keep expression form.
                    for entry in entries:
                        nes_addr = None
                        if entry.startswith('$'):
                            try:
                                nes_addr = int(entry[1:], 16) & 0xFFFF
                            except ValueError:
                                nes_addr = None
                        elif re.match(r'^\d+$', entry):
                            nes_addr = int(entry) & 0xFFFF
                        if nes_addr is None:
                            if bank_nes_addrs and entry in bank_nes_addrs:
                                nes_addr = bank_nes_addrs[entry]
                            elif all_nes_addrs and entry in all_nes_addrs:
                                nes_addr = all_nes_addrs[entry]
                        if nes_addr is not None and nes_addr >= 0x8000:
                            lo = nes_addr & 0xFF
                            hi = (nes_addr >> 8) & 0xFF
                            emit(
                                f'    dc.b    ${lo:02X}, ${hi:02X}'
                                f'   ; NES .ADDR (bank window, NES=${nes_addr:04X} = {entry})'
                            )
                        else:
                            emit(
                                f'    dc.b    ({entry})&$FF, ({entry}>>8)&$FF'
                                f'   ; NES .ADDR (little-endian)'
                            )
                continue

            # Unknown directive — comment it out
            emit(f'; [unknown directive] {stripped}')
            continue

        # ---------------------------------------------------------------
        # Label definition (global or local)
        # ---------------------------------------------------------------
        label_m = re.match(r'^(@?\w+)\s*:\s*(.*)', line)
        if label_m:
            lbl = label_m.group(1)
            rest = label_m.group(2).strip()

            if lbl.startswith('@'):
                # Local label → globally unique label via pre-pass mapping
                unique = resolve_local(i, lbl[1:])
                emit(f'    even')
                emit(f'{unique}:')
            else:
                # Global label
                defined.add(lbl)
                emit(f'    even')
                if dup_exports and lbl in dup_exports:
                    # Symbol exported from multiple banks — IFND-guard so only the
                    # first-included bank's definition is used; others become dead code.
                    emit(f'    IFND {lbl}')
                    emit(f'{lbl}:')
                    emit(f'    ENDC')
                else:
                    emit(f'{lbl}:')

            # Any label definition is a potential branch target — carry state unknown.
            carry_state['inverted'] = False

            # If there's code after the label on the same line, process it
            if rest and not rest.startswith(';'):
                in_jump_table[0] = False
                translated = translate_one_instruction(rest, i, symtab,
                                                        anon_defs, anon_refs,
                                                        bank_tag,
                                                        resolve_local_fn=resolve_local,
                                                        carry_state=carry_state)
                for tl in translated:
                    emit(tl)
                    if '_m68k_tablejump' in tl:
                        in_jump_table[0] = True
            continue

        # ---------------------------------------------------------------
        # Instruction line — clear jump table context, then check if
        # this instruction sets up a new jump table
        # ---------------------------------------------------------------
        in_jump_table[0] = False
        translated = translate_one_instruction(stripped, i, symtab,
                                                anon_defs, anon_refs,
                                                bank_tag,
                                                resolve_local_fn=resolve_local,
                                                carry_state=carry_state)
        for tl in translated:
            emit(tl)
            if '_m68k_tablejump' in tl:
                in_jump_table[0] = True

    # ---------------------------------------------------------------
    # Emit stubs for all .IMPORT symbols not defined locally.
    # In --all mode (no_import_stubs=True), stubs are wrapped in
    # IFND/ENDC so that an earlier-included bank's real definition
    # takes priority and the stub is silently skipped.
    # ---------------------------------------------------------------
    # In --all mode, suppress stubs for symbols that are exported by OTHER banks —
    # those banks are included in the build and will define the symbol.
    # Only emit stubs for symbols not exported by any other bank.
    _other = other_exports or set()
    stubs_needed = [s for s in imports if s not in defined and s not in _other]
    if stubs_needed:
        emit('')
        emit(';==============================================================================')
        emit('; Import stubs (symbols not provided by any other included bank)')
        emit(';==============================================================================')
        for sym in stubs_needed:
            emit(f'    even')
            emit(f'{sym}:')
            emit(f'    rts')
            emit('')

    # Stubs for NES I/O helpers — only emitted when NOT using --no-stubs.
    # With --no-stubs, nes_io.asm (included before this file) provides real
    # implementations.  The --no-stubs path is the T5+ production build.
    if not no_stubs:
        emit('')
        emit('; --- NES I/O stubs (T2 placeholders — real implementations in nes_io.asm) ---')
        io_stubs = [
            '_ppu_read_0','_ppu_read_1','_ppu_read_2','_ppu_read_3',
            '_ppu_read_4','_ppu_read_5','_ppu_read_6','_ppu_read_7',
            '_ppu_write_0','_ppu_write_1','_ppu_write_2','_ppu_write_3',
            '_ppu_write_4','_ppu_write_5','_ppu_write_6','_ppu_write_7',
            '_ctrl_read_1','_ctrl_read_2','_ctrl_strobe',
            '_oam_dma',
            '_mmc1_write_8000','_mmc1_write_a000',
            '_mmc1_write_c000','_mmc1_write_e000',
            '_apu_write_4000','_apu_write_4001','_apu_write_4002','_apu_write_4003',
            '_apu_write_4004','_apu_write_4005','_apu_write_4006','_apu_write_4007',
            '_apu_write_4008','_apu_write_400a','_apu_write_400b',
            '_apu_write_400c','_apu_write_400e','_apu_write_400f',
            '_apu_write_4010','_apu_write_4011','_apu_write_4012','_apu_write_4013',
            '_apu_write_4015','_apu_write_4016','_apu_write_4017',
        ]
        for sym in io_stubs:
            emit(f'{sym}:')
            if sym == '_ppu_read_2':
                # PPU $2002 PPUSTATUS: bit 7 = VBlank flag.
                # Return $80 always so IsrReset's two warmup loops exit immediately.
                # Real implementation (T5+) will track a software VBlank flag.
                emit('    move.b  #$80,D0  ; T4 stub: VBlank flag always set')
            emit(f'    rts')
            emit('')

    return out


def translate_one_instruction(stripped, line_idx, symtab,
                               anon_defs, anon_refs, bank_tag,
                               resolve_local_fn=None, carry_state=None):
    """Translate one 6502 instruction line to a list of M68K lines.

    carry_state: mutable dict {'inverted': bool} tracking whether the M68K C flag
    is inverted relative to 6502 convention (True after CMP/CPX/CPY/SBC).
    """
    if carry_state is None:
        carry_state = {'inverted': False}
    out = []

    def e(s):
        out.append(s)

    # Split mnemonic and operand
    m = re.match(r'^([A-Z]{2,3})\s*(.*)', stripped)
    if not m:
        e(f'; [untranslated] {stripped}')
        return out

    mnem = m.group(1).upper()
    op_str = m.group(2).strip()
    mode, val = parse_operand(op_str, symtab)

    # Handle anonymous label references in op_str
    def anon_label(direction):
        if line_idx in anon_refs:
            d, n = anon_refs[line_idx]
            return f'_anon_{bank_tag}_{n}'
        return f'_anon_{bank_tag}_UNRESOLVED'

    # Helper: generate read of NES byte into D0 (or D1/D2/D3 if specified)
    def gen_read(dst, addr_tok, idx=None):
        """Emit M68K to load NES byte at addr_tok[,idx] into dst register."""
        before, ea = ea_read_byte(addr_tok, idx, symtab)[:2]
        for bl in before:
            e(bl)
        if ea.startswith('_ppu_result') or ea.startswith('_ctrl_result'):
            # The bsr already put the result in D0; move to dst if needed
            if dst != 'D0':
                e(f'    move.b  D0,{dst}')
        elif ea.startswith('#0'):
            e(f'    moveq   #0,{dst}   ; stub read')
        else:
            e(f'    move.b  {ea},{dst}')

    def gen_write(src, addr_tok, idx=None):
        """Emit M68K to store src register to NES byte at addr_tok[,idx]."""
        before, ea, special = ea_write_byte(addr_tok, idx, symtab)
        for bl in before:
            e(bl)
        if ea is not None:
            e(f'    move.b  {src},{ea}')
        else:
            # PPU/APU special writes call a helper that expects the value in D0.
            # STX uses D2, STY uses D3 — move into D0 first.
            # IMPORTANT: in 6502, STX/STY do NOT modify A.  We must preserve D0
            # around the helper call so subsequent code still sees the correct A.
            if src != 'D0' and special:
                e(f'    move.l  D0,-(SP)       ; save A (6502 STX/STY never modifies A)')
                e(f'    move.b  {src},D0  ; {src} → D0 for I/O write')
                for sl in special:
                    e(sl)
                e(f'    move.l  (SP)+,D0       ; restore A')
            else:
                for sl in special:
                    e(sl)

    # ----------------------------------------------------------------
    # Instruction dispatch
    # ----------------------------------------------------------------

    if mnem == 'LDA':
        if mode == 'IMM':
            e(f'    moveq   #{val},D0') if -128 <= val <= 127 else e(f'    move.b  #${val:02X},D0')
        elif mode == 'ABS':
            gen_read('D0', val)
        elif mode == 'ABS_X':
            gen_read('D0', val, 'X')
        elif mode == 'ABS_Y':
            gen_read('D0', val, 'Y')
        elif mode == 'IND_Y':
            # ($nn),Y: load 16-bit LE ptr from NES RAM $nn, add Y, read byte
            addr = resolve_sym(val, symtab) or 0
            e(f'    move.b  (${addr:02X},A4),D1   ; ptr lo')
            e(f'    move.b  (${addr+1:02X},A4),D4  ; ptr hi')
            e(f'    andi.w  #$00FF,D1         ; zero-extend lo byte')
            e(f'    lsl.w   #8,D4')
            e(f'    or.w    D1,D4             ; D4 = NES ptr addr')
            e(f'    ext.l   D4')
            e(f'    add.l   #NES_RAM,D4       ; → Genesis addr')
            e(f'    movea.l D4,A0')
            e(f'    move.b  (A0,D3.W),D0     ; LDA ($nn),Y')
        elif mode == 'IND_X':
            # ($nn,X): ptr at NES RAM $nn+X
            addr = resolve_sym(val, symtab) or 0
            e(f'    move.b  D2,D1             ; X')
            e(f'    add.b   #${addr:02X},D1')
            e(f'    and.w   #$FF,D1')
            e(f'    move.b  (D1.W,A4),D4     ; ptr lo')
            e(f'    addq.w  #1,D1')
            e(f'    move.b  (D1.W,A4),D5     ; ptr hi')
            e(f'    andi.w  #$00FF,D4         ; zero-extend lo byte')
            e(f'    lsl.w   #8,D5')
            e(f'    or.w    D4,D5')
            e(f'    ext.l   D5')
            e(f'    add.l   #NES_RAM,D5')
            e(f'    movea.l D5,A0')
            e(f'    move.b  (A0),D0          ; LDA ($nn,X)')
        else:
            e(f'; [LDA unhandled mode={mode}] {stripped}')

    elif mnem == 'STA':
        if mode == 'ABS':
            gen_write('D0', val)
        elif mode == 'ABS_X':
            gen_write('D0', val, 'X')
        elif mode == 'ABS_Y':
            gen_write('D0', val, 'Y')
        elif mode == 'IND_Y':
            addr = resolve_sym(val, symtab) or 0
            e(f'    move.b  (${addr:02X},A4),D1   ; ptr lo')
            e(f'    move.b  (${addr+1:02X},A4),D4  ; ptr hi')
            e(f'    andi.w  #$00FF,D1         ; zero-extend lo byte')
            e(f'    lsl.w   #8,D4')
            e(f'    or.w    D1,D4')
            e(f'    ext.l   D4')
            e(f'    add.l   #NES_RAM,D4')
            e(f'    movea.l D4,A0')
            e(f'    move.b  D0,(A0,D3.W)     ; STA ($nn),Y')
        elif mode == 'IND_X':
            addr = resolve_sym(val, symtab) or 0
            e(f'    move.b  D2,D1')
            e(f'    add.b   #${addr:02X},D1')
            e(f'    and.w   #$FF,D1')
            e(f'    move.b  (D1.W,A4),D4')
            e(f'    addq.w  #1,D1')
            e(f'    move.b  (D1.W,A4),D5')
            e(f'    andi.w  #$00FF,D4         ; zero-extend lo byte')
            e(f'    lsl.w   #8,D5')
            e(f'    or.w    D4,D5')
            e(f'    ext.l   D5')
            e(f'    add.l   #NES_RAM,D5')
            e(f'    movea.l D5,A0')
            e(f'    move.b  D0,(A0)          ; STA ($nn,X)')
        else:
            e(f'; [STA unhandled mode={mode}] {stripped}')

    elif mnem == 'LDX':
        if mode == 'IMM':
            e(f'    moveq   #{val},D2') if -128 <= val <= 127 else e(f'    move.b  #${val:02X},D2')
        elif mode in ('ABS', 'ABS_Y'):
            idx = 'Y' if mode == 'ABS_Y' else None
            e('    moveq   #0,D2')      # clear D2.w high byte (D2.W used as index)
            gen_read('D2', val, idx)
        else:
            e(f'; [LDX unhandled mode={mode}] {stripped}')

    elif mnem == 'LDY':
        if mode == 'IMM':
            e(f'    moveq   #{val},D3') if -128 <= val <= 127 else e(f'    move.b  #${val:02X},D3')
        elif mode in ('ABS', 'ABS_X'):
            idx = 'X' if mode == 'ABS_X' else None
            e('    moveq   #0,D3')      # clear D3.w high byte (D3.W used as index)
            gen_read('D3', val, idx)
        else:
            e(f'; [LDY unhandled mode={mode}] {stripped}')

    elif mnem == 'STX':
        if mode == 'ABS':
            gen_write('D2', val)
        elif mode == 'ABS_Y':
            gen_write('D2', val, 'Y')
        else:
            e(f'; [STX unhandled mode={mode}] {stripped}')

    elif mnem == 'STY':
        if mode == 'ABS':
            gen_write('D3', val)
        elif mode == 'ABS_X':
            gen_write('D3', val, 'X')
        else:
            e(f'; [STY unhandled mode={mode}] {stripped}')

    elif mnem == 'TAX':
        e('    moveq   #0,D2')     # clear D2.w high byte before TAX
        e('    move.b  D0,D2')
    elif mnem == 'TAY':
        e('    moveq   #0,D3')     # clear D3.w high byte before TAY
        e('    move.b  D0,D3')
    elif mnem == 'TXA':
        e('    move.b  D2,D0')
    elif mnem == 'TYA':
        e('    move.b  D3,D0')
    elif mnem == 'TXS':
        e('    move.b  D2,D7   ; TXS: fake SP update (D7=NES SP shadow)')
    elif mnem == 'TSX':
        e('    moveq   #0,D2')     # clear D2.w high byte before TSX
        e('    move.b  D7,D2   ; TSX: fake SP to X')

    elif mnem == 'INX':
        e('    addq.b  #1,D2')
    elif mnem == 'INY':
        e('    addq.b  #1,D3')
    elif mnem == 'DEX':
        e('    subq.b  #1,D2')
    elif mnem == 'DEY':
        e('    subq.b  #1,D3')

    elif mnem == 'INC':
        if mode == 'ABS':
            addr = resolve_sym(val, symtab)
            if addr is not None:
                cls = nes_classify(addr)
                if cls in ('ram', 'mirror'):
                    real = addr & 0x07FF
                    e(f'    addq.b  #1,(${real:04X},A4)')
                else:
                    e(f'; INC non-RAM ${addr:04X} stub')
            else:
                e(f'    addq.b  #1,(NES_RAM+{val}).l')
        elif mode == 'ABS_X':
            addr = resolve_sym(val, symtab)
            if addr is not None:
                real = (addr & 0x07FF)
                if real <= 127:
                    e(f'    addq.b  #1,(${real:02X},A4,D2.W)')
                else:
                    e(f'    lea     (${real:04X},A4),A0')
                    e(f'    addq.b  #1,(A0,D2.W)')
            else:
                e(f'    lea     (NES_RAM+{val}).l,A0')
                e(f'    addq.b  #1,(A0,D2.W)')
        else:
            e(f'; [INC unhandled mode={mode}] {stripped}')

    elif mnem == 'DEC':
        if mode == 'ABS':
            addr = resolve_sym(val, symtab)
            if addr is not None:
                cls = nes_classify(addr)
                if cls in ('ram', 'mirror'):
                    real = addr & 0x07FF
                    e(f'    subq.b  #1,(${real:04X},A4)')
                else:
                    e(f'; DEC non-RAM ${addr:04X} stub')
            else:
                e(f'    subq.b  #1,(NES_RAM+{val}).l')
        elif mode == 'ABS_X':
            addr = resolve_sym(val, symtab)
            if addr is not None:
                real = addr & 0x07FF
                if real <= 127:
                    e(f'    subq.b  #1,(${real:02X},A4,D2.W)')
                else:
                    e(f'    lea     (${real:04X},A4),A0')
                    e(f'    subq.b  #1,(A0,D2.W)')
            else:
                e(f'    lea     (NES_RAM+{val}).l,A0')
                e(f'    subq.b  #1,(A0,D2.W)')
        else:
            e(f'; [DEC unhandled mode={mode}] {stripped}')

    elif mnem == 'ADC':
        if mode == 'IMM':
            e(f'    move.b  #${val:02X},D1')
            e(f'    addx.b  D1,D0   ; ADC #${val:02X} (X flag = 6502 C)')
        elif mode == 'ABS':
            gen_read('D1', val)
            e(f'    addx.b  D1,D0   ; ADC {val}')
        elif mode == 'ABS_X':
            gen_read('D1', val, 'X')
            e(f'    addx.b  D1,D0   ; ADC {val},X')
        elif mode == 'ABS_Y':
            gen_read('D1', val, 'Y')
            e(f'    addx.b  D1,D0   ; ADC {val},Y')
        elif mode == 'IND_Y':
            # Read into D1 first
            addr = resolve_sym(val, symtab) or 0
            e(f'    move.b  (${addr:02X},A4),D1')
            e(f'    move.b  (${addr+1:02X},A4),D4')
            e(f'    andi.w  #$00FF,D1         ; zero-extend lo byte')
            e(f'    lsl.w   #8,D4')
            e(f'    or.w    D1,D4')
            e(f'    ext.l   D4')
            e(f'    add.l   #NES_RAM,D4')
            e(f'    movea.l D4,A0')
            e(f'    move.b  (A0,D3.W),D1')
            e(f'    addx.b  D1,D0   ; ADC ($nn),Y')
        else:
            e(f'; [ADC unhandled mode={mode}] {stripped}')
        # ADC carry polarity matches M68K (C=1 if overflow)
        carry_state['inverted'] = False

    elif mnem == 'SBC':
        # 6502 SBC borrow polarity is INVERTED vs M68K SUBX:
        #   6502: C=1 means "no borrow in" (plain A - M);  C=0 means borrow in.
        #   M68K: X=1 means "borrow in" (extra -1);        X=0 means no borrow in.
        # We wrap every SUBX with `eori #$10,CCR` pre/post to flip X so the
        # SUBX sees correct borrow-in polarity and restore X to carry the
        # 6502 C bit for subsequent arithmetic. The M68K C flag after SUBX
        # remains M68K-polarity (inverted vs 6502), tracked via carry_state.
        if mode == 'IMM':
            e(f'    move.b  #${val:02X},D1')
            e(f'    eori    #$10,CCR  ; flip X: 6502 SBC polarity')
            e(f'    subx.b  D1,D0   ; SBC #${val:02X}')
            e(f'    eori    #$10,CCR  ; restore X = 6502 C')
        elif mode == 'ABS':
            gen_read('D1', val)
            e(f'    eori    #$10,CCR  ; flip X: 6502 SBC polarity')
            e(f'    subx.b  D1,D0   ; SBC {val}')
            e(f'    eori    #$10,CCR  ; restore X = 6502 C')
        elif mode == 'ABS_X':
            gen_read('D1', val, 'X')
            e(f'    eori    #$10,CCR  ; flip X: 6502 SBC polarity')
            e(f'    subx.b  D1,D0   ; SBC {val},X')
            e(f'    eori    #$10,CCR  ; restore X = 6502 C')
        elif mode == 'ABS_Y':
            gen_read('D1', val, 'Y')
            e(f'    eori    #$10,CCR  ; flip X: 6502 SBC polarity')
            e(f'    subx.b  D1,D0   ; SBC {val},Y')
            e(f'    eori    #$10,CCR  ; restore X = 6502 C')
        else:
            e(f'; [SBC unhandled mode={mode}] {stripped}')
        # M68K SUBX C flag is INVERTED vs 6502 SBC carry (same as CMP issue)
        carry_state['inverted'] = True

    elif mnem in ('AND', 'ORA', 'EOR'):
        op_m68k = {'AND': 'and', 'ORA': 'or', 'EOR': 'eor'}[mnem]
        if mode == 'IMM':
            e(f'    {op_m68k}i.b #${val:02X},D0')
        elif mode == 'ABS':
            gen_read('D1', val)
            e(f'    {op_m68k}.b  D1,D0')
        elif mode == 'ABS_X':
            gen_read('D1', val, 'X')
            e(f'    {op_m68k}.b  D1,D0')
        elif mode == 'ABS_Y':
            gen_read('D1', val, 'Y')
            e(f'    {op_m68k}.b  D1,D0')
        elif mode == 'IND_Y':
            addr = resolve_sym(val, symtab) or 0
            e(f'    move.b  (${addr:02X},A4),D1')
            e(f'    move.b  (${addr+1:02X},A4),D4')
            e(f'    andi.w  #$00FF,D1         ; zero-extend lo byte')
            e(f'    lsl.w   #8,D4')
            e(f'    or.w    D1,D4')
            e(f'    ext.l   D4')
            e(f'    add.l   #NES_RAM,D4')
            e(f'    movea.l D4,A0')
            e(f'    move.b  (A0,D3.W),D1')
            e(f'    {op_m68k}.b  D1,D0')
        else:
            e(f'; [{mnem} unhandled mode={mode}] {stripped}')

    elif mnem == 'CMP':
        if mode == 'IMM':
            e(f'    cmpi.b  #${val:02X},D0')
        elif mode == 'ABS':
            gen_read('D1', val)
            e(f'    cmp.b   D1,D0')
        elif mode == 'ABS_X':
            gen_read('D1', val, 'X')
            e(f'    cmp.b   D1,D0')
        elif mode == 'ABS_Y':
            gen_read('D1', val, 'Y')
            e(f'    cmp.b   D1,D0')
        elif mode == 'IND_Y':
            addr = resolve_sym(val, symtab) or 0
            e(f'    move.b  (${addr:02X},A4),D1')
            e(f'    move.b  (${addr+1:02X},A4),D4')
            e(f'    andi.w  #$00FF,D1         ; zero-extend lo byte')
            e(f'    lsl.w   #8,D4')
            e(f'    or.w    D1,D4')
            e(f'    ext.l   D4')
            e(f'    add.l   #NES_RAM,D4')
            e(f'    movea.l D4,A0')
            e(f'    move.b  (A0,D3.W),D1')
            e(f'    cmp.b   D1,D0')
        else:
            e(f'; [CMP unhandled mode={mode}] {stripped}')
        # M68K CMP/CMPI C flag is INVERTED vs 6502 CMP:
        #   6502 C=1 if A >= operand (no borrow); M68K C=1 if D0 < operand (borrow)
        carry_state['inverted'] = True

    elif mnem == 'CPX':
        if mode == 'IMM':
            e(f'    cmpi.b  #${val:02X},D2')
        elif mode == 'ABS':
            gen_read('D1', val)
            e(f'    cmp.b   D1,D2')
        else:
            e(f'; [CPX unhandled mode={mode}] {stripped}')
        carry_state['inverted'] = True

    elif mnem == 'CPY':
        if mode == 'IMM':
            e(f'    cmpi.b  #${val:02X},D3')
        elif mode == 'ABS':
            gen_read('D1', val)
            e(f'    cmp.b   D1,D3')
        else:
            e(f'; [CPY unhandled mode={mode}] {stripped}')
        carry_state['inverted'] = True

    elif mnem == 'BIT':
        # BIT: Z set if (A AND mem)=0; N=bit7 of mem; V=bit6 of mem
        if mode == 'ABS':
            gen_read('D1', val)
            e(f'    and.b   D0,D1   ; BIT: set Z/N/V from D1 AND A')
        else:
            e(f'; [BIT unhandled mode={mode}] {stripped}')

    elif mnem in BRANCH_MAP:
        m68k_branch = BRANCH_MAP[mnem]
        # BCS/BCC: 6502 carry polarity is INVERTED vs M68K after CMP/CPX/CPY/SBC.
        # When carry_state['inverted'] is True, swap BCS↔BCC so the branch
        # fires on the correct condition.
        if carry_state['inverted']:
            if m68k_branch == 'bcs':
                m68k_branch = 'bcc'
            elif m68k_branch == 'bcc':
                m68k_branch = 'bcs'
        if mode == 'ABS':
            target = val
            if isinstance(target, str) and target.startswith('@'):
                target = resolve_local_fn(line_idx, target[1:]) if resolve_local_fn else target[1:]
            e(f'    {m68k_branch}  {target}')
        elif mode == 'ANON':
            lbl = anon_label(val)
            e(f'    {m68k_branch}  {lbl}')
        else:
            e(f'; [branch unhandled mode={mode}] {stripped}')
        # T38 FIX: 6502 branches don't modify the carry flag. The previous
        # `carry_state['inverted'] = False` was incorrect — a sequence like
        # `CMP ObjX,X / BEQ x / BCS y` was emitting a literal `bcs` for the
        # second branch because BEQ reset the inversion state. Since 6502
        # BEQ/BNE/BPL/BMI/BVC/BVS don't touch carry, the inversion must
        # persist. BCC/BCS themselves also don't write carry — they consume
        # Z/N/V/C but leave them intact on fall-through. Leave carry_state
        # alone here; only CMP/CPX/CPY/SBC/ADC and arithmetic reset it.

    elif mnem == 'JMP':
        if mode == 'ABS':
            target = val
            if isinstance(target, str) and target.startswith('@'):
                target = resolve_local_fn(line_idx, target[1:]) if resolve_local_fn else target[1:]
            e(f'    jmp     {target}')
        elif mode == 'IND_ABS':
            addr = resolve_sym(val, symtab)
            if addr is not None:
                cls = nes_classify(addr)
                if cls in ('ram', 'mirror'):
                    real = addr & 0x07FF
                    e(f'    move.w  (${real:04X},A4),D1  ; JMP ($nnnn) ptr lo')
                    e(f'    ext.l   D1')
                    e(f'    add.l   #NES_RAM,D1')
                    e(f'    movea.l D1,A0')
                    e(f'    jmp     (A0)              ; JMP (${addr:04X})')
                else:
                    e(f'    ; JMP (${addr:04X}) indirect — non-RAM ptr stub')
                    e(f'    jmp     _indirect_stub')
            else:
                e(f'    ; JMP ({val}) indirect — unknown addr stub')
                e(f'    jmp     _indirect_stub')
        elif mode == 'ANON':
            lbl = anon_label(val)
            e(f'    jmp     {lbl}')
        else:
            e(f'; [JMP unhandled mode={mode}] {stripped}')

    elif mnem == 'JSR':
        target = val
        if isinstance(target, str) and target.startswith('@'):
            target = resolve_local_fn(line_idx, target[1:]) if resolve_local_fn else target[1:]
        if target == 'TableJump':
            e(f'    bsr     _m68k_tablejump  ; M68K-native table dispatch (replaces JSR TableJump)')
        else:
            e(f'    bsr     {target}')

    elif mnem == 'RTS':
        # If C is in M68K-inverted state (from CMP/CPX/CPY/SBC earlier in the
        # function without a normalizing op since), flip it back to 6502-style
        # before returning.  Callers assume 6502-polarity C after a JSR that
        # ends in CMP; without this fix, e.g., 6502 "CMP #$16 / RTS ; BCS"
        # becomes M68K "cmpi.b #$16,D0 / rts / bcs" which reads the M68K flag
        # with opposite meaning.  Root cause of T36 cave 21-frame row-copy
        # compression (CopyNextRowToTransferBuf).
        if carry_state.get('inverted'):
            e('    eori    #$01,CCR  ; normalize C to 6502 polarity before RTS')
        e('    rts')

    elif mnem == 'RTI':
        # On NES, RTI returns from NMI/IRQ (pops P,PCL,PCH).
        # On Genesis, IsrNmi is called via BSR/JSR from VBlankISR (not via exception).
        # VBlankISR owns the RTE. IsrNmi must end with RTS.
        if carry_state.get('inverted'):
            e('    eori    #$01,CCR  ; normalize C to 6502 polarity before RTS')
        e('    rts   ; RTI → RTS (IsrNmi is a subroutine; VBlankISR handles the RTE)')

    elif mnem == 'PHA':
        e('    move.b  D0,-(A5)  ; PHA')

    elif mnem == 'PLA':
        e('    move.b  (A5)+,D0  ; PLA')

    elif mnem == 'PHP':
        e('    move.w  SR,D1')
        e('    move.b  D1,-(A5)  ; PHP: push CCR')

    elif mnem == 'PLP':
        e('    move.b  (A5)+,D1  ; PLP: pop to CCR')
        e('    move.w  D1,CCR')

    elif mnem == 'CLC':
        e('    andi    #$EE,CCR  ; CLC: clear C+X')
        carry_state['inverted'] = False  # carry explicitly cleared: M68K C=0

    elif mnem == 'SEC':
        e('    ori     #$11,CCR  ; SEC: set C+X')
        carry_state['inverted'] = False  # carry explicitly set: M68K C=1

    elif mnem == 'CLD':
        e('    ; CLD: decimal mode ignored (68000 has no decimal mode)')

    elif mnem == 'SED':
        e('    ; SED: decimal mode ignored')

    elif mnem == 'SEI':
        e('    ; SEI: NES IRQ disable — NOP on Genesis (VBlank=NMI fires regardless of IRQ mask)')

    elif mnem == 'CLI':
        # NES CLI re-enables the IRQ line but NMI always fires.
        # On Genesis: lower IPL to 5 so level-6 VBlank fires, but no IRQ source
        # is wired above level 6 anyway.  IPL=5 → levels 6 and 7 unmasked.
        e('    andi.w  #$F8FF,SR  ; CLI: IPL=0 — allow all interrupts incl. VBlank(6)')

    elif mnem in ('ASL', 'LSR', 'ROL', 'ROR'):
        op_m68k = {'ASL':'lsl', 'LSR':'lsr', 'ROL':'roxl', 'ROR':'roxr'}[mnem]
        if mode == 'ACC' or mode == 'IMPL':
            e(f'    {op_m68k}.b  #1,D0   ; {mnem} A')
        elif mode == 'ABS':
            addr = resolve_sym(val, symtab)
            if addr is not None and nes_classify(addr) in ('ram','mirror'):
                real = addr & 0x07FF
                e(f'    move.b  (${real:04X},A4),D1')
                e(f'    {op_m68k}.b  #1,D1   ; {mnem} {val}')
                e(f'    move.b  D1,(${real:04X},A4)')
            else:
                e(f'; [{mnem} ABS non-RAM stub] {val}')
        elif mode == 'ABS_X':
            addr = resolve_sym(val, symtab)
            if addr is not None:
                real = addr & 0x07FF
                if real <= 127:
                    e(f'    move.b  (${real:02X},A4,D2.W),D1')
                    e(f'    {op_m68k}.b  #1,D1   ; {mnem} {val},X')
                    e(f'    move.b  D1,(${real:02X},A4,D2.W)')
                else:
                    e(f'    lea     (${real:04X},A4),A0')
                    e(f'    move.b  (A0,D2.W),D1')
                    e(f'    {op_m68k}.b  #1,D1   ; {mnem} {val},X')
                    e(f'    move.b  D1,(A0,D2.W)')
            else:
                e(f'; [{mnem} ABS_X unresolved] {stripped}')
        else:
            e(f'; [{mnem} unhandled mode={mode}] {stripped}')
        # Shift/rotate carry has normal M68K polarity (C = shifted-out bit)
        carry_state['inverted'] = False

    elif mnem == 'NOP':
        e('    nop')

    else:
        e(f'; [UNHANDLED] {stripped}')

    # Add indirect jmp stub if not already present (emitted once)
    # (handled at file level — not per instruction)

    return out

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Cross-bank export collection (used in --all mode for stub suppression)
# ---------------------------------------------------------------------------

def collect_exports_from_source(bank_num):
    """Pre-scan a bank source file for .EXPORT declarations AND global label definitions.
    Returns set of symbol names that this bank defines publicly.
    We collect both .EXPORT symbols AND all non-anonymous labels so that utility
    functions defined in multiple banks (like Exit) can be deduplicated.
    """
    src_name = f"Z_{bank_num:02d}.asm"
    src_path = os.path.join(REF_DIR, src_name)
    exports = set()
    if not os.path.exists(src_path):
        return exports
    with open(src_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            s = line.strip()
            # .EXPORT declaration
            if s.upper().startswith('.EXPORT'):
                rest = s[7:].strip()
                for sym in re.split(r'[\s,]+', rest):
                    sym = sym.strip()
                    if sym and re.match(r'^\w+$', sym):
                        exports.add(sym)
            # Global label definition (non-anonymous: not starting with @)
            m = re.match(r'^([A-Za-z_]\w*)\s*:', s)
            if m:
                sym = m.group(1)
                if not sym.startswith('@'):
                    exports.add(sym)
    return exports


KNOWN_6502_MNEMS = {
    'ADC', 'AND', 'ASL', 'BCC', 'BCS', 'BEQ', 'BIT', 'BMI', 'BNE', 'BPL',
    'BRK', 'BVC', 'BVS',
    'CLC', 'CLD', 'CLI', 'CLV', 'CMP', 'CPX', 'CPY',
    'DEC', 'DEX', 'DEY', 'EOR', 'INC', 'INX', 'INY',
    'JMP', 'JSR', 'LDA', 'LDX', 'LDY', 'LSR', 'NOP', 'ORA',
    'PHA', 'PHP', 'PLA', 'PLP', 'ROL', 'ROR', 'RTI', 'RTS',
    'SBC', 'SEC', 'SED', 'SEI', 'STA', 'STX', 'STY',
    'TAX', 'TAY', 'TSX', 'TXA', 'TXS', 'TYA',
}

BRANCH_MNEMS = {'BCC', 'BCS', 'BEQ', 'BMI', 'BNE', 'BPL', 'BVC', 'BVS'}
ZP_MNEMS = {
    'ADC', 'AND', 'ASL', 'BIT', 'CMP', 'CPX', 'CPY', 'DEC', 'EOR',
    'INC', 'LDA', 'LDX', 'LDY', 'LSR', 'ORA', 'ROL', 'ROR', 'SBC',
    'STA', 'STX', 'STY',
}
ZPX_MNEMS = {
    'ADC', 'AND', 'ASL', 'CMP', 'DEC', 'EOR', 'INC', 'LDA', 'LDY',
    'LSR', 'ORA', 'ROL', 'ROR', 'SBC', 'STA', 'STY',
}
ZPY_MNEMS = {'LDX', 'STX'}


def _strip_asm_comment(line):
    return re.sub(r'\s*;.*$', '', line).strip()


def _split_csv_items(csv_text):
    items = []
    cur = []
    in_quote = False
    quote_ch = ''
    i = 0
    while i < len(csv_text):
        ch = csv_text[i]
        if in_quote:
            cur.append(ch)
            if ch == quote_ch:
                in_quote = False
            i += 1
            continue
        if ch in ('"', "'"):
            in_quote = True
            quote_ch = ch
            cur.append(ch)
            i += 1
            continue
        if ch == ',':
            item = ''.join(cur).strip()
            if item:
                items.append(item)
            cur = []
            i += 1
            continue
        cur.append(ch)
        i += 1
    tail = ''.join(cur).strip()
    if tail:
        items.append(tail)
    return items


def _parse_numeric_token(tok):
    tok = tok.strip()
    if not tok:
        return None
    sign = 1
    if tok.startswith('+'):
        tok = tok[1:].strip()
    elif tok.startswith('-'):
        sign = -1
        tok = tok[1:].strip()
    if not tok:
        return None
    if tok.startswith('$'):
        try:
            return sign * int(tok[1:], 16)
        except ValueError:
            return None
    if tok.startswith('%'):
        try:
            return sign * int(tok[1:], 2)
        except ValueError:
            return None
    if re.fullmatch(r'\d+', tok):
        return sign * int(tok, 10)
    return None


def _resolve_prepass_value(tok, symtab, label_map, local_map, cur_scope):
    tok = tok.strip()
    if not tok:
        return None
    tok = re.sub(r'^[aAzZ]:', '', tok)
    tok = tok.strip()
    if tok.startswith('<') or tok.startswith('>'):
        tok = tok[1:].strip()

    n = _parse_numeric_token(tok)
    if n is not None:
        return n

    if tok.startswith('@'):
        name = tok[1:]
        return local_map.get((cur_scope, name))

    if tok in label_map:
        return label_map[tok]
    if tok in symtab:
        return symtab[tok]

    m = re.match(r'^([@A-Za-z_]\w*)\s*([+\-])\s*(\$[0-9A-Fa-f]+|%[01]+|\d+)$', tok)
    if m:
        base_name = m.group(1)
        op = m.group(2)
        off = _parse_numeric_token(m.group(3))
        if off is None:
            return None
        if base_name.startswith('@'):
            base = local_map.get((cur_scope, base_name[1:]))
        else:
            base = label_map.get(base_name, symtab.get(base_name))
        if base is None:
            return None
        return base + off if op == '+' else base - off
    return None


def _infer_6502_instr_size(mnem, operand, symtab, label_map, local_map, cur_scope, src_name, line_no):
    if mnem not in KNOWN_6502_MNEMS:
        raise ValueError(f"{src_name}:{line_no}: unknown instruction '{mnem}'")

    op = _strip_asm_comment(operand)
    op = re.sub(r'^[aAzZ]:', '', op).strip()
    merged = dict(symtab)
    merged.update(label_map)
    mode, val = parse_operand(op, merged)

    if mode == 'IMPL':
        return 1
    if mnem in BRANCH_MNEMS:
        return 2
    if mode == 'ANON':
        if mnem in BRANCH_MNEMS:
            return 2
        if mnem in ('JMP', 'JSR'):
            return 3
        raise ValueError(f"{src_name}:{line_no}: anonymous label ref not valid for {mnem}")
    if mode == 'ACC':
        return 1
    if mode == 'IMM':
        return 2
    if mode == 'IND_X':
        return 2
    if mode == 'IND_Y':
        return 2
    if mode == 'IND_ABS':
        return 3

    if mode in ('ABS', 'ABS_X', 'ABS_Y'):
        if isinstance(val, str):
            base_val = _resolve_prepass_value(val, symtab, label_map, local_map, cur_scope)
        else:
            base_val = val
        is_zp = base_val is not None and 0 <= base_val <= 0xFF

        if mode == 'ABS':
            if is_zp and mnem in ZP_MNEMS:
                return 2
            return 3
        if mode == 'ABS_X':
            if is_zp and mnem in ZPX_MNEMS:
                return 2
            return 3
        if mode == 'ABS_Y':
            if is_zp and mnem in ZPY_MNEMS:
                return 2
            return 3

    raise ValueError(f"{src_name}:{line_no}: unsupported mode '{mode}' for '{mnem} {operand}'")


def _byte_directive_size(data_expr, src_name, line_no):
    items = _split_csv_items(data_expr)
    if not items:
        raise ValueError(f"{src_name}:{line_no}: malformed .BYTE (no items)")
    size = 0
    for item in items:
        it = item.strip()
        if not it:
            raise ValueError(f"{src_name}:{line_no}: malformed .BYTE entry")
        if (it.startswith('"') and it.endswith('"')) or (it.startswith("'") and it.endswith("'")):
            size += len(it[1:-1])
        else:
            size += 1
    return size


def _count_word_entries(data_expr, src_name, line_no, kind):
    items = _split_csv_items(data_expr)
    if not items:
        raise ValueError(f"{src_name}:{line_no}: malformed {kind} (no items)")
    return len(items)


def _bank_start_pc(bank_num):
    return 0xC000 if bank_num == 7 else 0x8000


def build_nes_address_map(bank_num):
    """Strict NES-address prepass for one bank source file."""
    src_name = f"Z_{bank_num:02d}.asm"
    src_path = os.path.join(REF_DIR, src_name)
    if not os.path.exists(src_path):
        raise FileNotFoundError(f"source not found for bank {bank_num}: {src_path}")

    symtab = build_symtab()
    pc = _bank_start_pc(bank_num)
    bank_end = pc + 0x4000
    label_map = {}
    local_map = {}
    cur_scope = '_TOP_'

    def _resolve_rel_path(base_path, rel_text):
        rel = rel_text.replace('/', os.sep)
        p = os.path.join(os.path.dirname(base_path), rel)
        if os.path.exists(p):
            return p
        p2 = os.path.join(REF_DIR, rel)
        return p2

    def _walk_file(path, pc_in, scope_in):
        scope = scope_in
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()

        src_file = os.path.basename(path)
        pc_local = pc_in
        for idx, raw in enumerate(lines, start=1):
            stripped = raw.strip()
            if not stripped or stripped.startswith(';'):
                continue
            if re.match(r'^:\s*(;.*)?$', stripped):
                continue

            lm = re.match(r'^\s*(@?\w+):(.*)$', raw)
            if lm:
                label = lm.group(1)
                rest = lm.group(2).strip()
                if label.startswith('@'):
                    local_name = label[1:]
                    local_map[(scope, local_name)] = pc_local
                    label_map[f'{scope}::{label}'] = pc_local
                else:
                    scope = label
                    label_map[label] = pc_local
                stripped = rest
                if not stripped or stripped.startswith(';'):
                    continue

            asm = _strip_asm_comment(stripped)
            if not asm:
                continue
            if re.match(r'^[A-Za-z_]\w*\s*:?=\s*', asm):
                # .inc constant/equate assignment (e.g. Var := $10)
                continue

            if asm.startswith('.'):
                upper = asm.upper()
                if upper.startswith('.INCLUDE'):
                    m = re.search(r'"([^"]+)"', asm)
                    if not m:
                        raise ValueError(f"{src_file}:{idx}: malformed .INCLUDE")
                    inc_path = _resolve_rel_path(path, m.group(1))
                    if not os.path.exists(inc_path):
                        raise FileNotFoundError(f"{src_file}:{idx}: .INCLUDE missing file: {inc_path}")
                    pc_local, scope = _walk_file(inc_path, pc_local, scope)
                    continue
                if upper.startswith('.SEGMENT') or upper.startswith('.IMPORT') or upper.startswith('.EXPORT'):
                    continue
                if upper.startswith('.INCBIN'):
                    m = re.search(r'"([^"]+)"', asm)
                    if not m:
                        raise ValueError(f"{src_file}:{idx}: malformed .INCBIN")
                    inc_path = _resolve_rel_path(path, m.group(1))
                    if not os.path.exists(inc_path):
                        raise FileNotFoundError(f"{src_file}:{idx}: .INCBIN missing file: {inc_path}")
                    pc_local += os.path.getsize(inc_path)
                elif upper.startswith('.BYTE'):
                    pc_local += _byte_directive_size(asm[5:].strip(), src_file, idx)
                elif upper.startswith('.WORD'):
                    pc_local += 2 * _count_word_entries(asm[5:].strip(), src_file, idx, '.WORD')
                elif upper.startswith('.ADDR'):
                    pc_local += 2 * _count_word_entries(asm[5:].strip(), src_file, idx, '.ADDR')
                elif upper.startswith('.DBYT'):
                    pc_local += 2 * _count_word_entries(asm[5:].strip(), src_file, idx, '.DBYT')
                elif upper.startswith('.LOBYTES'):
                    pc_local += _count_word_entries(asm[8:].strip(), src_file, idx, '.LOBYTES')
                elif upper.startswith('.HIBYTES'):
                    pc_local += _count_word_entries(asm[8:].strip(), src_file, idx, '.HIBYTES')
                elif upper.startswith('.RES'):
                    args = _split_csv_items(asm[4:].strip())
                    if not args:
                        raise ValueError(f"{src_file}:{idx}: malformed .RES")
                    count = _parse_numeric_token(args[0])
                    if count is None:
                        raise ValueError(f"{src_file}:{idx}: .RES count must be numeric, got '{args[0]}'")
                    if count < 0:
                        raise ValueError(f"{src_file}:{idx}: .RES count must be >= 0, got {count}")
                    pc_local += count
                else:
                    raise ValueError(f"{src_file}:{idx}: unsupported directive '{asm.split()[0]}'")
            else:
                mm = re.match(r'^([A-Z]{2,3})\s*(.*)$', asm)
                if not mm:
                    raise ValueError(f"{src_file}:{idx}: cannot parse instruction '{asm}'")
                mnem = mm.group(1).upper()
                operand = mm.group(2) or ''
                pc_local += _infer_6502_instr_size(
                    mnem,
                    operand,
                    symtab,
                    label_map,
                    local_map,
                    scope,
                    src_file,
                    idx,
                )

            if pc_local > bank_end:
                raise ValueError(
                    f"{src_file}:{idx}: NES address overflow (pc=${pc_local:04X} beyond bank end ${bank_end:04X})"
                )
        return pc_local, scope

    pc, cur_scope = _walk_file(src_path, pc, cur_scope)

    return label_map


def _validate_nes_address_maps(nes_addr_maps):
    required = [
        (5, 'RoomLayoutsOW', 0x9818),
        (6, 'LevelBlockOW', 0x8400),
        (3, 'PatternBlockOWBG', 0x893B),
    ]
    for bank, label, expected_addr in required:
        amap = nes_addr_maps.get(bank, {})
        if label not in amap:
            raise ValueError(f"NES prepass validation failed: missing label {label} in bank {bank}")
        addr = amap[label]
        lo = _bank_start_pc(bank)
        hi = lo + 0x4000
        if not (lo <= addr < hi):
            raise ValueError(
                f"NES prepass validation failed: {label} resolved to ${addr:04X} outside bank-{bank} range ${lo:04X}-${hi-1:04X}"
            )
        if addr != expected_addr:
            raise ValueError(
                f"NES prepass validation failed: {label}=${addr:04X}, expected ${expected_addr:04X}"
            )

    # Optional spot-check against extracted NES banks + known dat blobs (if present).
    spot_checks = [
        (1, 'DemoSpritePatterns', os.path.join('dat', 'DemoSpritePatterns.dat')),
        (2, 'CommonSpritePatterns', os.path.join('dat', 'CommonSpritePatterns.dat')),
        (6, 'StoryTileAttrTransferBuf', os.path.join('dat', 'StoryTileAttrTransferBuf.dat')),
    ]
    for bank, label, rel_dat in spot_checks:
        bank_blob = os.path.join(REF_DIR, 'dat', f'nes_bank_{bank:02d}.bin')
        dat_path = os.path.join(REF_DIR, rel_dat)
        if not os.path.exists(bank_blob) or not os.path.exists(dat_path):
            continue
        amap = nes_addr_maps.get(bank, {})
        if label not in amap:
            continue
        addr = amap[label]
        off = addr - _bank_start_pc(bank)
        if off < 0:
            print(f"  WARNING: NES prepass spot-check skipped ({label}: negative offset)")
            continue
        with open(bank_blob, 'rb') as f:
            bank_data = f.read()
        with open(dat_path, 'rb') as f:
            dat_data = f.read()
        if off + min(8, len(dat_data)) > len(bank_data):
            print(f"  WARNING: NES prepass spot-check skipped ({label}: points beyond bank image)")
            continue
        chk_len = min(8, len(dat_data))
        if chk_len > 0 and bank_data[off:off + chk_len] != dat_data[:chk_len]:
            print(f"  WARNING: NES prepass spot-check mismatch for {label} vs {rel_dat}")


def _audit_bank_window_coverage():
    """Hard-fail if ROM pointer consumers lack a bank-window guard before first table read."""
    checks = [
        (
            os.path.join(OUT_DIR, 'z_03.asm'),
            'FetchPatternBlockAddrUW',
            ['PatternBlockSrcAddrsUW'],
        ),
        (
            os.path.join(OUT_DIR, 'z_03.asm'),
            'FetchPatternBlockInfoOW',
            ['PatternBlockSrcAddrsOW'],
        ),
        (
            os.path.join(OUT_DIR, 'z_03.asm'),
            'FetchPatternBlockAddrUWSpecial',
            ['LevelPatternBlockSrcAddrs'],
        ),
        (
            os.path.join(OUT_DIR, 'z_03.asm'),
            'FetchPatternBlockUWBoss',
            ['BossPatternBlockSrcAddrs'],
        ),
        (
            os.path.join(OUT_DIR, 'z_05.asm'),
            'LayoutRoomOW',
            ['RoomLayoutsOWAddr'],
        ),
        (
            os.path.join(OUT_DIR, 'z_05.asm'),
            'PatchColumnDirectoryForCellar',
            ['ColumnHeapOWAddr'],
        ),
        (
            os.path.join(OUT_DIR, 'z_05.asm'),
            'LayoutCaveAndAvanceSubmode',
            ['SubroomLayoutAddrsUW'],
        ),
        (
            os.path.join(OUT_DIR, 'z_05.asm'),
            'LayoutUWFloor',
            ['ColumnDirectoryUW'],
        ),
        (
            os.path.join(OUT_DIR, 'z_06.asm'),
            'UpdateMode2Load_Full',
            ['LevelInfoUWQ2ReplacementAddrs'],
        ),
    ]

    def get_func_block(lines, func_name):
        start = None
        for i, line in enumerate(lines):
            if line.strip() == f'{func_name}:':
                start = i
                break
        if start is None:
            return None  # function migrated to C — skip audit
        end = len(lines)
        for i in range(start + 1, len(lines)):
            s = lines[i].strip()
            if re.match(r'^[A-Za-z_]\w*:$', s):
                end = i
                break
        return lines[start:end]

    for path, func, markers in checks:
        if not os.path.exists(path):
            raise FileNotFoundError(f"coverage audit: generated file not found: {path}")
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            lines = f.read().splitlines()
        block = get_func_block(lines, func)
        if block is None:
            continue  # function migrated to C — skip
        # If block is a C-shim stub (jmp c_*), skip audit
        block_code = [l.strip() for l in block if l.strip() and not l.strip().startswith(';') and not l.strip().endswith(':') and l.strip() != 'even']
        if len(block_code) <= 1 and any('jmp' in l and 'c_' in l for l in block_code):
            continue  # C-shim stub — skip audit
        ensure_idx = next(
            (
                i
                for i, l in enumerate(block)
                if ('_ensure_bank_window' in l) or ('_copy_bank_to_window' in l)
            ),
            -1,
        )
        if ensure_idx < 0:
            raise ValueError(f"coverage audit: {func} missing bank-window guard call")
        first_use = -1
        for i, l in enumerate(block):
            if any(m in l for m in markers):
                first_use = i
                break
        if first_use >= 0 and ensure_idx > first_use:
            raise ValueError(
                f"coverage audit: {func} calls _ensure_bank_window after first table use ({markers[0]})"
            )


def _audit_isrvector_dead_code():
    """Hard-fail if IsrVector gains runtime consumers."""
    bank_files = [os.path.join(OUT_DIR, f'z_{b:02d}.asm') for b in range(8)]
    refs = []
    for p in bank_files:
        if not os.path.exists(p):
            continue
        with open(p, 'r', encoding='utf-8', errors='replace') as f:
            for i, line in enumerate(f, start=1):
                if re.search(r'\bIsrVector\b', line):
                    refs.append((p, i, line.rstrip('\n')))
    if not refs:
        raise ValueError("dead-vector audit: IsrVector definition missing")
    if len(refs) != 1:
        details = '\n'.join([f"{p}:{ln}: {txt}" for p, ln, txt in refs])
        raise ValueError(f"dead-vector audit: expected definition-only IsrVector, found extra use-sites:\n{details}")
    p, _, txt = refs[0]
    if not txt.strip().startswith('IsrVector:'):
        raise ValueError(f"dead-vector audit: IsrVector reference is not a definition ({p})")

    # Bank-7 exemption guard: IsrVector is the only allowed z_07 ROM .ADDR
    # table that still emits NES bank-window bytes.
    z07 = os.path.join(OUT_DIR, 'z_07.asm')
    if os.path.exists(z07):
        with open(z07, 'r', encoding='utf-8', errors='replace') as f:
            lines = f.read().splitlines()
        last_label = None
        owners = set()
        for line in lines:
            s = line.strip()
            m = re.match(r'^([A-Za-z_]\w*):$', s)
            if m:
                last_label = m.group(1)
            if 'NES .ADDR (bank window' in line:
                owners.add(last_label or '<unknown>')
        extras = sorted([x for x in owners if x != 'IsrVector'])
        if extras:
            raise ValueError(
                "dead-vector audit: unexpected z_07 ROM .ADDR table owner(s): "
                + ', '.join(extras)
            )


# File header and constants
# ---------------------------------------------------------------------------

HEADER_TEMPLATE = """\
;==============================================================================
; {outname} — auto-generated by transpile_6502.py
; Source: reference/aldonunez/{srcname}
; DO NOT EDIT — regenerate with: python tools/transpile_6502.py
;
; Register convention:
;   D0 = 6502 A  (accumulator)
;   D1 = scratch
;   D2 = 6502 X  (X index register)
;   D3 = 6502 Y  (Y index register)
;   D4,D5 = scratch (used by indirect addressing sequences)
;   D6 = scratch
;   D7 = 6502 SP shadow (NES stack pointer, $0100 area)
;   A4 = NES RAM base ($FF0000) — init by genesis_shell.asm
;   A5 = NES stack pointer ($FF0200 initially, grows downward)
;==============================================================================

{fixed_equs}
;==============================================================================
; NES RAM variable offsets (used as (offset,A4) — A4=NES_RAM)
; Source: Variables.inc + CommonVars.inc
;==============================================================================
{var_equs}
;==============================================================================
; Begin translated {srcname} code
;==============================================================================
{org_line}
"""

FIXED_EQUS = """\
NES_RAM         equ $FF0000
NES_SRAM        equ $FF6000
NES_STACK_BASE  equ $FF0100
"""

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def transpile_bank(bank_num, standalone=False, no_stubs=False, no_import_stubs=False,
                   other_exports=None, dup_exports=None,
                   all_nes_addrs=None, bank_nes_addrs=None):
    """Transpile one bank file (0-7). Returns True on success.

    standalone=True: emit 'org $C000' for isolated T2/T3 assembly testing.
    standalone=False (default): no org — code placed by genesis_shell.asm.
    no_stubs=True: skip NES I/O stubs and _indirect_stub — nes_io.asm provides them.
    no_import_stubs=True: skip equate header for non-z07 banks in --all mode
        (z_07.asm provides all equates; others would cause vasm duplicate-symbol errors).
    other_exports: set of symbol names exported by OTHER banks in --all mode.
        Stubs for these symbols are suppressed — the other banks define them.
    dup_exports: set of symbols exported from MULTIPLE banks.
        Label definitions for these are IFND-guarded so only the first-included
        bank's definition is kept; duplicates become dead code.
    """
    src_name = f"Z_{bank_num:02d}.asm"
    out_name = f"z_{bank_num:02d}.asm"
    src_path = os.path.join(REF_DIR, src_name)
    out_path = os.path.join(OUT_DIR, out_name)
    bank_tag = f"z{bank_num:02d}"

    if not os.path.exists(src_path):
        print(f"ERROR: source not found: {src_path}")
        return False

    print(f"  Transpiling {src_name} -> {out_name}  ...", end='', flush=True)

    symtab = build_symtab()

    with open(src_path, encoding="utf-8", errors="replace") as f:
        src_lines = f.read().splitlines()

    # Flatten .INCLUDE directives so included data (e.g. dat/PersonTextAddrs.inc)
    # is emitted. The PC-walker _walk_file already follows .INCLUDE; without
    # flattening here, the translator emits "; [skipped]" and the referenced
    # bytes (pointer tables, text, etc.) vanish from the output, leaving labels
    # positioned on the WRONG bytes.  Root cause of T36 cave textbox "000000".
    def _flatten_includes(lines, base_path, depth=0):
        if depth > 8:
            raise RuntimeError(f".INCLUDE recursion too deep in {base_path}")
        out = []
        for ln in lines:
            s = ln.strip()
            U = s.upper()
            if U.startswith('.INCLUDE'):
                m = re.search(r'"([^"]+)"', s)
                if not m:
                    raise ValueError(f"{base_path}: malformed .INCLUDE: {s}")
                rel = m.group(1).replace('/', os.sep)
                # Only inline data includes (dat/*.inc).  Equate-only includes
                # like Variables.inc, CommonVars.inc are already processed via
                # build_symtab() and must not be re-emitted here.
                if not rel.lower().startswith('dat' + os.sep) and \
                   not rel.lower().startswith('dat/'):
                    out.append(f'; [skipped-equ] {s}')
                    continue
                p = os.path.join(os.path.dirname(base_path), rel)
                if not os.path.exists(p):
                    p = os.path.join(REF_DIR, rel)
                if not os.path.exists(p):
                    raise FileNotFoundError(f"{base_path}: .INCLUDE missing: {rel}")
                with open(p, encoding="utf-8", errors="replace") as f:
                    inc_lines = f.read().splitlines()
                out.append(f'; [inlined] {s}')
                out.extend(_flatten_includes(inc_lines, p, depth + 1))
                out.append(f'; [end inline] {rel}')
            else:
                out.append(ln)
        return out
    src_lines = _flatten_includes(src_lines, src_path)

    # Build var equ block for header.
    # In --all mode (no_import_stubs=True), only z_07 emits equates;
    # all other banks omit them to avoid vasm "symbol already defined" errors.
    if no_import_stubs and bank_num != 7:
        fixed_equs = '; (fixed equates omitted — provided by z_07.asm in --all build)'
        var_equs   = '; (var equates omitted — provided by z_07.asm in --all build)'
    else:
        fixed_equs = FIXED_EQUS
        var_lines = []
        for name, addr in sorted(symtab.items(), key=lambda kv: kv[1]):
            if addr <= 0x07FF:
                var_lines.append(f'{name:40s}equ ${addr:04X}  ; NES RAM offset')
            elif 0x2000 <= addr <= 0x401F:
                var_lines.append(f'{name:40s}equ ${addr:04X}  ; NES I/O')
            elif 0x6000 <= addr <= 0x7FFF:
                var_lines.append(f'{name:40s}equ ${addr:04X}  ; NES SRAM')
        var_equs = '\n'.join(var_lines)

    if standalone:
        org_line = f'    org     $C000   ; standalone origin (T2/T3 testing only)'
    else:
        org_line = ''

    header = HEADER_TEMPLATE.format(
        outname=out_name,
        srcname=src_name,
        fixed_equs=fixed_equs,
        var_equs=var_equs,
        org_line=org_line,
    )

    body_lines = translate_lines(src_lines, symtab, bank_tag, no_stubs=no_stubs,
                                 no_import_stubs=no_import_stubs,
                                 other_exports=other_exports,
                                 dup_exports=dup_exports,
                                 all_nes_addrs=all_nes_addrs,
                                 bank_nes_addrs=bank_nes_addrs,
                                 bank_num=bank_num)

    # Add indirect jump stub (only when not using --no-stubs;
    # nes_io.asm provides it in the production T5+ build).
    if not no_stubs:
        body_lines.append('')
        body_lines.append('_indirect_stub:')
        body_lines.append('    rts   ; JMP (abs) stub — resolve in T9+')

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(header)
        f.write('\n'.join(body_lines))
        f.write('\n')

    # Apply bank-specific post-process patches
    if bank_num == 0:
        _patch_z00(out_path)
    if bank_num == 1:
        _patch_z01(out_path)
    if bank_num == 2:
        _patch_z02(out_path)
    if bank_num == 3:
        _patch_z03(out_path)
    if bank_num == 4:
        _patch_z04(out_path)
    if bank_num == 5:
        _patch_z05(out_path)
    if bank_num == 6:
        _patch_z06(out_path)
    if bank_num == 7:
        _patch_z07(out_path)
    _promote_nonlocal_bsr_to_jsr(out_path)

    print(f" {len(body_lines)} lines")
    return True


def _promote_nonlocal_bsr_to_jsr(path):
    """Promote translated-bank control flow to stable long forms."""
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    stem = os.path.splitext(os.path.basename(path))[0]

    jsr_count = 0

    def repl(match):
        nonlocal jsr_count
        target = match.group(3)
        if target.startswith(('_L_', '_anon_', '.')):
            return match.group(0)
        jsr_count += 1
        comment = match.group(4) or ''
        return f"{match.group(1)}jsr{match.group(2)}{target}{comment}"

    text = re.sub(r'^(\s*)bsr(\s+)([A-Za-z_][A-Za-z0-9_]*)(\s*;.*)?$',
                  repl, text, flags=re.MULTILINE)

    opposite = {
        'beq': 'bne',
        'bne': 'beq',
        'bcc': 'bcs',
        'bcs': 'bcc',
        'bpl': 'bmi',
        'bmi': 'bpl',
        'bvc': 'bvs',
        'bvs': 'bvc',
        'bhi': 'bls',
        'bls': 'bhi',
        'bge': 'blt',
        'blt': 'bge',
        'bgt': 'ble',
        'ble': 'bgt',
    }
    jump_count = 0
    branch_count = 0
    hardened_lines = []
    for line in text.splitlines():
        m = re.match(r'^(\s*)(b(?:ra|eq|ne|cc|cs|pl|mi|vc|vs|hi|ls|ge|gt|lt|le))(\s+)([A-Za-z_][A-Za-z0-9_]*)(\s*;.*)?$', line)
        if not m:
            hardened_lines.append(line)
            continue

        indent, op, ws, target, comment = m.groups()
        if target.startswith(('_L_', '_anon_', '.')):
            hardened_lines.append(line)
            continue

        comment = comment or ''
        if op == 'bra':
            hardened_lines.append(f"{indent}jmp{ws}{target}{comment}")
            jump_count += 1
            continue

        skip = f"__far_{stem}_{branch_count:04d}"
        hardened_lines.append(f"{indent}{opposite[op]}.s  {skip}")
        hardened_lines.append(f"{indent}jmp{ws}{target}{comment}")
        hardened_lines.append(f"{skip}:")
        branch_count += 1

    text = '\n'.join(hardened_lines) + '\n'

    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)

    if jsr_count or jump_count or branch_count:
        print(
            f"  _patch_common: promote {jsr_count} BSR->JSR, "
            f"{jump_count} BRA->JMP, {branch_count} Bcc->far JMP"
        )


def _replace_addr_table_block(text, label, new_entries, expected_count=None):
    """Replace consecutive '; NES .ADDR ...' dc.b lines under label with dc.l entries."""
    lines = text.splitlines()
    label_idx = None
    for i, line in enumerate(lines):
        if line.strip() == f'{label}:':
            label_idx = i
            break
    if label_idx is None:
        return text, False, f"label {label} not found"

    start = label_idx + 1
    end = start
    while end < len(lines) and 'NES .ADDR' in lines[end]:
        end += 1
    count = end - start
    if count <= 0:
        return text, False, f"label {label} has no NES .ADDR entries"
    if expected_count is not None and count != expected_count:
        return text, False, f"label {label} expected {expected_count} entries, found {count}"

    repl = [f'    dc.l    {entry}' for entry in new_entries]
    lines[start:end] = repl
    return '\n'.join(lines), True, None


def _replace_in_function_block(text, func_name, old, new, count=1):
    """Replace snippet inside a single function block (label->next global label)."""
    lines = text.splitlines()
    start = None
    end = len(lines)
    for i, line in enumerate(lines):
        if line.strip() == f'{func_name}:':
            start = i
            break
    if start is None:
        return text, False, f"function {func_name} not found"
    for i in range(start + 1, len(lines)):
        s = lines[i].strip()
        if s.endswith(':') and not s.startswith('_') and not s.startswith('.') and not s.startswith(';'):
            end = i
            break
    block = '\n'.join(lines[start:end])
    new_block, hits = block.replace(old, new, count), block.count(old)
    if hits <= 0:
        return text, False, f"{func_name}: snippet not found"
    lines[start:end] = new_block.splitlines()
    return '\n'.join(lines), True, None


def _replace_global_block(text, start_label, end_label, new_block):
    """Replace a top-level label block with new text."""
    lines = text.splitlines()
    start = None
    end = None
    for i, line in enumerate(lines):
        if line.strip() == f'{start_label}:':
            start = i
            break
    if start is None:
        return text, False, f"label {start_label} not found"

    for i in range(start + 1, len(lines)):
        if lines[i].strip() == f'{end_label}:':
            end = i
            break
    if end is None:
        return text, False, f"end label {end_label} not found"

    lines[start:end] = new_block.rstrip('\n').splitlines()
    return '\n'.join(lines), True, None


def _insert_ensure_bank_window_call(text, func_name):
    """Insert 'bsr _ensure_bank_window' immediately after a function label if missing."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.strip() == f'{func_name}:':
            if i + 1 < len(lines) and '_ensure_bank_window' in lines[i + 1]:
                return text, True, None
            lines.insert(i + 1, '    bsr     _ensure_bank_window')
            return '\n'.join(lines), True, None
    return text, False, f"function {func_name} not found"


def _insert_fixed_bank_window_call(text, func_name, bank_num):
    """Insert fixed bank-window load at function entry if missing."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.strip() == f'{func_name}:':
            lookahead = '\n'.join(lines[i + 1:i + 5])
            if '_copy_bank_to_window' in lookahead or '_ensure_bank_window' in lookahead:
                return text, True, None
            lines.insert(i + 1, f'    moveq   #{bank_num},D0')
            lines.insert(i + 2, f'    jsr     _copy_bank_to_window   ; PATCH P33b: force window bank {bank_num}')
            return '\n'.join(lines), True, None
    return text, False, f"function {func_name} not found"


def _patch_z00(path):
    """Post-process patches for z_00.asm.

    Previously this NOPed DriveAudio because the song-script .INCBIN sidecars
    were missing. extract_audio.py now emits those sidecars to
    reference/aldonunez/dat/, so the transpiler can inline the real data and
    DriveAudio runs natively on top of audio_driver.asm's YM2612/PSG bridge.

    (Original NOP kept below as a stale comment; superseded by audio bridge.)
    The audio driver dereferences NES ROM pointers via ZP indirect addressing.
    These resolve to zeroed NES RAM instead of ROM data, causing the driver
    to loop for 250+ frames parsing invalid music data.  NOP until bank
    mapping is implemented.
    """
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()

    old = ('DriveAudio:\n'
           '    ; If the game is paused, then silence all channels\n'
           '    ; by first disabling them, then enabling them.\n'
           '    ;\n'
           '    ; Then go drive tune channel 0 only.')
    new = ('DriveAudio:\n'
           '    ; PATCHED: NOP — audio data requires NES bank mapping not yet implemented.\n'
           '    rts\n'
           '    ; If the game is paused, then silence all channels\n'
           '    ; by first disabling them, then enabling them.\n'
           '    ;\n'
           '    ; Then go drive tune channel 0 only.')
    # NOTE: re-enabled. Song-script .dat sidecars + YM2612/PSG bridge are in
    # place, but DriveAudio still dereferences 16-bit NES CPU pointers from
    # song headers (e.g. $8E70) via 6502 zero-page indirection. Those addresses
    # are not valid in the M68K port, so the music engine crashes on the first
    # indirect read. Keeping the NOP until the pointer-translation layer is
    # written (pass the M68K label address through header rewriting or a
    # small pointer-fixup table).
    if old in text:
        text = text.replace(old, new, 1)
        print("  _patch_z00: DriveAudio -> rts (NOP)")
    else:
        print("  WARNING: _patch_z00 -- DriveAudio not found")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def _patch_z01(path):
    """Post-process patches for z_01.asm — TransferDemoPatterns / TransferPatternBlock_Bank1.

    Same approach as _patch_z02: fix 32-bit ROM addresses and replace the
    per-byte _ppu_write_7 loop with _transfer_chr_block_fast.
    """
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    text = ''.join(lines)

    # ---- Patch 0: Convert DemoPatternBlockAddrs from dc.b (2-byte NES) to dc.l (32-bit) ----
    text, ok, err = _replace_addr_table_block(
        text,
        'DemoPatternBlockAddrs',
        [
            'DemoSpritePatterns        ; 32-bit Genesis ROM address',
            'DemoBackgroundPatterns     ; 32-bit Genesis ROM address',
        ],
        expected_count=2,
    )
    if ok:
        print("  _patch_z01 P0: DemoPatternBlockAddrs dc.b -> dc.l (structural)")
    else:
        print(f"  WARNING: _patch_z01 P0 -- {err}")

    # ---- Patch 1: Fix TransferDemoPatterns to use 32-bit ROM addresses ----
    # Replace the first DemoPatternBlockAddrs read (before addq.b #1,D2)
    old1a = ('    lea     (DemoPatternBlockAddrs).l,A0\n'
             '    move.b  (A0,D2.W),D0\n'
             '    move.b  D0,($0000,A4)\n'
             '    lea     (DemoPatternBlockSizes).l,A0')
    new1a = ('    lea     (DemoPatternBlockAddrs).l,A0\n'
             '    move.w  D2,D5\n'
             '    add.w   D5,D5              ; D5 = 4*block_idx (dc.l = 4 bytes)\n'
             '    move.l  (A0,D5.W),D5      ; D5 = 32-bit Genesis ROM source addr\n'
             '    move.l  D5,($04,A4)       ; store to [$04:$07]\n'
             '    lea     (DemoPatternBlockSizes).l,A0')
    if old1a in text:
        text = text.replace(old1a, new1a, 1)
        print("  _patch_z01 P1a: DemoPatternBlockAddrs -> 32-bit ROM addr")
    else:
        print("  WARNING: _patch_z01 P1a -- old text not found")

    # Replace the second DemoPatternBlockAddrs read (after addq.b #1,D2)
    old1b = ('    lea     (DemoPatternBlockAddrs).l,A0\n'
             '    move.b  (A0,D2.W),D0\n'
             '    move.b  D0,($0001,A4)\n'
             '    lea     (DemoPatternBlockSizes).l,A0')
    new1b = ('    ; (32-bit Genesis ROM addr already in [$04:$07])\n'
             '    lea     (DemoPatternBlockSizes).l,A0')
    if old1b in text:
        text = text.replace(old1b, new1b, 1)
        print("  _patch_z01 P1b: removed second DemoPatternBlockAddrs read")
    else:
        print("  WARNING: _patch_z01 P1b -- old text not found")

    # ---- Patch 2: Replace TransferPatternBlock_Bank1 with fast bulk transfer ----
    lines = text.split('\n')
    start = None
    end = None
    for i, line in enumerate(lines):
        if line.strip() == 'TransferPatternBlock_Bank1:':
            start = i
        if start is not None and i > start + 2 and 'addq.b  #1,($051D,A4)' in line:
            for j in range(i+1, min(i+3, len(lines))):
                if 'rts' in lines[j]:
                    end = j
                    break
            break

    if start is not None and end is not None:
        replacement = [
            'TransferPatternBlock_Bank1:',
            '    ; PATCHED: fast bulk CHR transfer (bypasses per-byte _ppu_write_7)',
            '    bsr     _ppu_write_6          ; complete PPU addr latch pair (sets PPU_VADDR)',
            '    movea.l ($04,A4),A0           ; ROM source address',
            '    move.w  (PPU_VADDR).l,D1      ; NES CHR destination address',
            '    moveq   #0,D2',
            '    move.b  ($0002,A4),D2         ; size hi byte',
            '    lsl.w   #8,D2',
            '    move.b  ($0003,A4),D2         ; size lo byte (D2.w = total bytes)',
            '    ext.l   D2                    ; D2.l = byte count',
            '    bsr     _transfer_chr_block_fast',
            '    addq.b  #1,($051D,A4)         ; increment block index',
            '    rts',
        ]
        lines[start:end+1] = replacement
        text = '\n'.join(lines)
        print("  _patch_z01 P2: TransferPatternBlock_Bank1 -> _transfer_chr_block_fast")
    else:
        print("  WARNING: _patch_z01 P2 -- TransferPatternBlock_Bank1 not found")

    # ---- Patch 3: NOP CopyCommonCodeToRam ----
    # All code is in flat ROM on Genesis; byte-by-byte copy from NES ROM
    # addresses resolves to zeroed NES RAM, wasting 15 frames.
    old_copy = ('CopyCommonCodeToRam:\n'
                '    moveq   #0,D0\n'
                '    move.b  D0,($0000,A4)')
    new_copy = ('CopyCommonCodeToRam:\n'
                '    ; PATCHED: NOP — all code is in flat ROM on Genesis.\n'
                '    rts\n'
                '    moveq   #0,D0\n'
                '    move.b  D0,($0000,A4)')
    if old_copy in text:
        text = text.replace(old_copy, new_copy, 1)
        print("  _patch_z01 P3: CopyCommonCodeToRam -> rts (NOP)")
    else:
        print("  WARNING: _patch_z01 P3 -- CopyCommonCodeToRam not found")

    # ---- Patch 4 (P31): Remove FileBChecksums code label ----
    # FileBChecksums was a NES RAM variable but the transpiler placed it as a
    # code label in z_01.asm (ROM on Genesis).  Writes to ROM silently fail on
    # real hardware, breaking the save checksum chain.  The equ is now defined
    # in nes_io.asm pointing to writable work RAM ($FF1200).
    old_fbc = 'FileBChecksums:\n'
    new_fbc = '; FileBChecksums: REMOVED by P31 — relocated to writable RAM ($FF1200 in nes_io.asm)\n'
    if old_fbc in text:
        text = text.replace(old_fbc, new_fbc, 1)
        print("  _patch_z01 P4 (P31): FileBChecksums label removed (relocated to RAM)")
    else:
        print("  WARNING: _patch_z01 P4 (P31) -- FileBChecksums label not found")

    # ---- Patch 5 (P36c): Fix CPX/BCC borrow sense in FormatHeartsInTextBuf ----
    # 6502 CPX branches on BCC when X < M. 68K CMP sets carry on borrow, so
    # the translated branch must be BCS for that case.
    old_hearts = ('    move.b  ($0000,A4),D1\n'
                  '    cmp.b   D1,D2\n'
                  '    beq  _L_z01_FormatHeartsInTextBuf_CheckPartial\n'
                  '    bcc  _L_z01_FormatHeartsInTextBuf_EmitEmptyHeart\n')
    new_hearts = ('    move.b  ($0000,A4),D1\n'
                  '    cmp.b   D1,D2\n'
                  '    beq  _L_z01_FormatHeartsInTextBuf_CheckPartial\n'
                  '    bcs  _L_z01_FormatHeartsInTextBuf_EmitEmptyHeart   ; PATCH P36c: 68K borrow sense for CPX/BCC\n')
    if old_hearts in text:
        text = text.replace(old_hearts, new_hearts, 1)
        print("  _patch_z01 P5: FormatHeartsInTextBuf CPX/BCC -> BCS")
    else:
        print("  WARNING: _patch_z01 P5 -- FormatHeartsInTextBuf anchor not found")

    # P6a/P6b removed: superseded by transpiler-side SBC X-flag polarity fix
    # (subx.b now wrapped with `eori #$10,CCR` pair). SUBX off-by-one no longer
    # occurs, so the FormatHeartsInTextBuf compensation is unnecessary.

    # ---- Patch P7: Insert RTS after GetObjectMiddle ----
    # NES GetObjectMiddle falls through into ObjTypeToDamagePoints data
    # whose first byte $60 is the 6502 RTS opcode — implicit return.
    # On M68K $60 is BRA.s, so execution runs data as code → crash on
    # first monster collision (seen at T35 scroll t=333).
    old_gom = ('    move.b  D0,($0003,A4)\n'
               '    even\n'
               'ObjTypeToDamagePoints:\n')
    new_gom = ('    move.b  D0,($0003,A4)\n'
               '    rts                  ; PATCH P7: NES implicit RTS via '
               'ObjTypeToDamagePoints[0]=$60\n'
               '    even\n'
               'ObjTypeToDamagePoints:\n')
    if old_gom in text:
        text = text.replace(old_gom, new_gom, 1)
        print("  _patch_z01 P7: GetObjectMiddle fallthrough -> explicit rts")
    else:
        print("  WARNING: _patch_z01 P7 -- GetObjectMiddle anchor not found")

    # P33d: UpdatePersonState_Textbox reads PersonTextAddrs (bank 1) and then
    # dereferences the returned NES ptr ($8xxx) through the bank window to
    # fetch text characters.  If a cave/room routine previously pinned bank 5
    # into the window, the char read returns garbage/zeros, producing the
    # "000000..." cave textbox symptom.  Pin bank 1 on every entry.
    text, ok_tbx, err_tbx = _insert_fixed_bank_window_call(
        text, 'UpdatePersonState_Textbox', 1)
    if ok_tbx:
        print("  _patch_z01 P33d: UpdatePersonState_Textbox -> pin bank 1")
    else:
        print(f"  WARNING: _patch_z01 P33d -- {err_tbx}")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def _patch_z02(path):
    """Post-process patches for z_02.asm — TransferCommonPatterns / TransferPatternBlock_Bank2.

    The transpiler emits dc.l (32-bit Genesis ptr) for .ADDR entries and
    generates 16-bit NES-pointer + NES_RAM ($FF0000) address logic for
    LDA ($00),Y accesses.  That formula only works for NES RAM addresses;
    pattern data (CommonSpritePatterns etc.) lives in Genesis ROM at $000000+.

    Fix:
    1. TransferCommonPatterns: replace the two one-byte reads from
       CommonPatternBlockAddrs with a single move.l that loads the full
       32-bit Genesis ROM address into [$04:$07] (avoids the [$02:$03] size
       overlap that would corrupt bytes 2-3 of the address).
    2. TransferPatternBlock_Bank2 loop body: replace the 7-line 16-bit NES
       pointer reconstruction + NES_RAM offset with movea.l ($04,A4),A0.
    3. TransferPatternBlock_Bank2 increment: replace the 9-line 16-bit
       carry-increment with addq.l #1,($04,A4).
    """
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()

    # ---- Patch 0: Convert CommonPatternBlockAddrs from dc.b (2-byte NES) to dc.l (32-bit) ----
    text, ok, err = _replace_addr_table_block(
        text,
        'CommonPatternBlockAddrs',
        [
            'CommonSpritePatterns       ; 32-bit Genesis ROM address',
            'CommonBackgroundPatterns    ; 32-bit Genesis ROM address',
            'CommonMiscPatterns          ; 32-bit Genesis ROM address',
        ],
        expected_count=3,
    )
    if ok:
        print("  _patch_z02 P0: CommonPatternBlockAddrs dc.b -> dc.l (structural)")
    else:
        print(f"  WARNING: _patch_z02 P0 -- {err}")

    # ---- Patch 1a: first CommonPatternBlockAddrs read (before addq.b #1,D2) ----
    old1a = ('    lea     (CommonPatternBlockAddrs).l,A0\n'
             '    move.b  (A0,D2.W),D0\n'
             '    move.b  D0,($0000,A4)\n'
             '    lea     (CommonPatternBlockSizes).l,A0')
    new1a = ('    lea     (CommonPatternBlockAddrs).l,A0\n'
             '    move.w  D2,D5\n'
             '    add.w   D5,D5              ; D5 = 4*block_idx (dc.l = 4 bytes)\n'
             '    move.l  (A0,D5.W),D5      ; D5 = 32-bit Genesis ROM source addr\n'
             '    move.l  D5,($04,A4)       ; store to [$04:$07] (avoids size overlap)\n'
             '    lea     (CommonPatternBlockSizes).l,A0')
    text = text.replace(old1a, new1a, 1)

    # ---- Patch 1b: second CommonPatternBlockAddrs read (after addq.b #1,D2) ----
    old1b = ('    lea     (CommonPatternBlockAddrs).l,A0\n'
             '    move.b  (A0,D2.W),D0\n'
             '    move.b  D0,($0001,A4)\n'
             '    lea     (CommonPatternBlockSizes).l,A0')
    new1b = ('    ; (32-bit Genesis ROM addr already in [$04:$07])\n'
             '    lea     (CommonPatternBlockSizes).l,A0')
    text = text.replace(old1b, new1b, 1)

    # ---- Patch 2: TransferPatternBlock_Bank2 — replace 16-bit NES ptr calc ----
    old2 = ('    move.b  ($00,A4),D1   ; ptr lo\n'
            '    move.b  ($01,A4),D4  ; ptr hi\n'
            '    andi.w  #$00FF,D1         ; zero-extend lo byte\n'
            '    lsl.w   #8,D4\n'
            '    or.w    D1,D4             ; D4 = NES ptr addr\n'
            '    ext.l   D4\n'
            '    add.l   #NES_RAM,D4       ; → Genesis addr\n'
            '    movea.l D4,A0\n'
            '    move.b  (A0,D3.W),D0     ; LDA ($nn),Y')
    new2 = ('    movea.l ($04,A4),A0      ; 32-bit Genesis ROM source addr from [$04:$07]\n'
            '    move.b  (A0,D3.W),D0     ; LDA ($nn),Y')
    text = text.replace(old2, new2, 1)

    # ---- Patch 3: replace 16-bit little-endian increment with 32-bit addq ----
    old3 = ('    ; Increment the 16-bit source address at [00:01].\n'
            '    ;\n'
            '    move.b  ($0000,A4),D0\n'
            '    andi    #$EE,CCR  ; CLC: clear C+X\n'
            '    move.b  #$01,D1\n'
            '    addx.b  D1,D0   ; ADC #$01 (X flag = 6502 C)\n'
            '    move.b  D0,($0000,A4)\n'
            '    move.b  ($0001,A4),D0\n'
            '    move.b  #$00,D1\n'
            '    addx.b  D1,D0   ; ADC #$00 (X flag = 6502 C)\n'
            '    move.b  D0,($0001,A4)')
    new3 = ('    ; Increment 32-bit Genesis ROM source address at [$04:$07].\n'
            '    addq.l  #1,($04,A4)')
    text = text.replace(old3, new3, 1)

    # ---- Patch 4: Replace TransferPatternBlock_Bank2 with fast bulk transfer ----
    # Find the function from label to rts (line-based for encoding safety)
    lines = text.split('\n')
    start = None
    end = None
    for i, line in enumerate(lines):
        if line.strip() == 'TransferPatternBlock_Bank2:':
            start = i
        if start is not None and i > start + 2 and 'addq.b  #1,($051D,A4)' in line:
            # rts is next non-blank line
            for j in range(i+1, min(i+3, len(lines))):
                if 'rts' in lines[j]:
                    end = j
                    break
            break

    if start is not None and end is not None:
        replacement = [
            'TransferPatternBlock_Bank2:',
            '    ; PATCHED: fast bulk CHR transfer (bypasses per-byte _ppu_write_7)',
            '    bsr     _ppu_write_6          ; complete PPU addr latch pair (sets PPU_VADDR)',
            '    movea.l ($04,A4),A0           ; ROM source address',
            '    move.w  (PPU_VADDR).l,D1      ; NES CHR destination address',
            '    moveq   #0,D2',
            '    move.b  ($0002,A4),D2         ; size hi byte',
            '    lsl.w   #8,D2',
            '    move.b  ($0003,A4),D2         ; size lo byte (D2.w = total bytes)',
            '    ext.l   D2                    ; D2.l = byte count',
            '    bsr     _transfer_chr_block_fast',
            '    addq.b  #1,($051D,A4)         ; increment block index',
            '    rts',
        ]
        lines[start:end+1] = replacement
        text = '\n'.join(lines)
        print("  _patch_z02 P4: TransferPatternBlock_Bank2 -> _transfer_chr_block_fast")
    else:
        print("  WARNING: _patch_z02 P4 -- TransferPatternBlock_Bank2 not found")

    # ---- Patch 5: Waterfall sprite palette override (NES pal 0 → Genesis pal 3) ----
    # NES writes attr=$00 (sprite palette 0) for wave and crest sprites.
    # Genesis only has 4 palette rows; NES sprite pal 0 maps to Genesis pal 2
    # via OAM DMA, but pal 2 is occupied by BG palette 2.  Force palette 3
    # which carries the same $30/$3B waterfall colors from NES sprite pal 3.
    # NOTE: When CHR_EXPANSION_ENABLED=1 this patch becomes harmful; retire in
    # Stage 12 when the flag is flipped permanently.
    wave_pat = "    moveq   #0,D0\n    lea     ($0202,A4),A0\n    move.b  D0,(A0,D3.W)\n    addq.b  #1,D3"
    wave_fix = "    moveq   #3,D0\n    lea     ($0202,A4),A0\n    move.b  D0,(A0,D3.W)\n    addq.b  #1,D3"
    count = text.count(wave_pat)
    if count >= 2:
        text = text.replace(wave_pat, wave_fix)
        print(f"  _patch_z02 P5: waterfall sprite palette 0->3 ({count} loops patched)")
    else:
        old_attr = "    moveq   #0,D0\n    lea     ($0202,A4),A0\n    move.b  D0,(A0,D3.W)"
        new_attr = "    ; Genesis only has 4 shared palette rows, so force the title waterfall\n    ; sprites onto the mint/white title row instead of NES sprite palette 0.\n    moveq   #3,D0\n    lea     ($0202,A4),A0\n    move.b  D0,(A0,D3.W)"
        c2 = text.count(old_attr)
        if c2 >= 2:
            text = text.replace(old_attr, new_attr)
            print(f"  _patch_z02 P5: waterfall sprite palette 0->3 ({c2} loops patched, broad match)")
        else:
            print(f"  WARNING: _patch_z02 P5 -- waterfall attr pattern not found (count={count},{c2})")

    # ---- Patch 6: Fix fade palette pointer arithmetic ----
    # The NES original computes DemoPhase0Subphase1Palettes + (cycle * 32)
    # using ADC #<label / ADC #>label. The transpiler emits the cycle*32 math
    # but drops the base-address addition, so the code reads from NES RAM
    # zero-page instead of the ROM palette table. Replace with direct M68K lea.
    old_fade = (
        '    ; Calculate the address to the palette to transfer.\n'
        '    ; Addr = DemoPhase0Subphase1Palettes + (DemoPhase0Subphase1Palettes * $20)\n'
        '    moveq   #0,D0\n'
        '    move.b  D0,($0001,A4)\n'
        '    move.b  ($0437,A4),D0\n'
        '    lsl.b  #1,D0   ; ASL A\n'
        '    lsl.b  #1,D0   ; ASL A\n'
        '    lsl.b  #1,D0   ; ASL A\n'
        '    lsl.b  #1,D0   ; ASL A\n'
        '    move.b  ($0001,A4),D1\n'
        '    roxl.b  #1,D1   ; ROL $01\n'
        '    move.b  D1,($0001,A4)\n'
        '    lsl.b  #1,D0   ; ASL A\n'
        '    move.b  ($0001,A4),D1\n'
        '    roxl.b  #1,D1   ; ROL $01\n'
        '    move.b  D1,($0001,A4)\n'
        '    move.b  #$00,D1\n'
        '    addx.b  D1,D0   ; ADC #$00 (X flag = 6502 C)\n'
        '    move.b  D0,($0000,A4)\n'
        '    move.b  ($0001,A4),D0\n'
        '    move.b  #$00,D1\n'
        '    addx.b  D1,D0   ; ADC #$00 (X flag = 6502 C)\n'
        '    move.b  D0,($0001,A4)\n'
        '    moveq   #63,D0\n'
        '    move.b  D0,($0302,A4)\n'
        '    moveq   #0,D0\n'
        '    move.b  D0,($0303,A4)\n'
        '    moveq   #32,D0\n'
        '    move.b  D0,($0304,A4)\n'
        '    moveq   #31,D3\n'
        '    move.b  #$FF,D0\n'
        '    lea     ($0306,A4),A0\n'
        '    move.b  D0,(A0,D3.W)\n'
        '    even\n'
        '_L_z02_AnimateDemoPhase0Subphase1_CopyPalette:\n'
        '    move.b  ($00,A4),D1   ; ptr lo\n'
        '    move.b  ($01,A4),D4  ; ptr hi\n'
        '    andi.w  #$00FF,D1         ; zero-extend lo byte\n'
        '    lsl.w   #8,D4\n'
        '    or.w    D1,D4             ; D4 = NES ptr addr\n'
        '    ext.l   D4\n'
        '    add.l   #NES_RAM,D4       ; \u2192 Genesis addr\n'
        '    movea.l D4,A0\n'
        '    move.b  (A0,D3.W),D0     ; LDA ($nn),Y\n'
        '    lea     ($0305,A4),A0\n'
        '    move.b  D0,(A0,D3.W)\n'
        '    subq.b  #1,D3\n'
        '    bpl  _L_z02_AnimateDemoPhase0Subphase1_CopyPalette'
    )
    new_fade = (
        '    ; PATCHED (P6): Replace broken NES indirect-pointer math with direct\n'
        '    ; M68K addressing. The original ADC #<label / ADC #>label that adds\n'
        '    ; DemoPhase0Subphase1Palettes base address was lost in transpilation.\n'
        '    moveq   #0,D0\n'
        '    move.b  ($0437,A4),D0        ; cycle index (0-13)\n'
        '    lsl.w   #5,D0                ; * 32 = byte offset into palette table\n'
        '    lea     (DemoPhase0Subphase1Palettes).l,A0\n'
        '    adda.w  D0,A0                ; A0 -> palette for this cycle\n'
        '    ; Set up DynTileBuf header: $3F, $00, $20\n'
        '    move.b  #$3F,($0302,A4)\n'
        '    move.b  #$00,($0303,A4)\n'
        '    moveq   #32,D0\n'
        '    move.b  D0,($0304,A4)\n'
        '    ; End marker at DynTileBuf+4+31\n'
        '    moveq   #31,D3\n'
        '    move.b  #$FF,D0\n'
        '    lea     ($0306,A4),A1\n'
        '    move.b  D0,(A1,D3.W)\n'
        '    even\n'
        '_L_z02_AnimateDemoPhase0Subphase1_CopyPalette:\n'
        '    move.b  (A0,D3.W),D0        ; read from ROM palette table\n'
        '    lea     ($0305,A4),A1\n'
        '    move.b  D0,(A1,D3.W)\n'
        '    subq.b  #1,D3\n'
        '    bpl  _L_z02_AnimateDemoPhase0Subphase1_CopyPalette'
    )
    if old_fade in text:
        text = text.replace(old_fade, new_fade, 1)
        print("  _patch_z02 P6: fade palette pointer -> direct M68K lea")
    else:
        print("  WARNING: _patch_z02 P6 -- fade palette pattern not found")

    # ---- Patch 7: Replace DemoTextFields stub with extracted NES ROM data ----
    old_text_stub = (
        'DemoTextFields:\n'
        '; .INCBIN "dat/DemoTextFields.dat" not found \u2014 stub 128 zero bytes\n'
        '    rept    128\n'
        '        dc.b    0\n'
        '    endr\n'
        '\n'
        '    even\n'
        'DemoLineTextAddrs:\n'
        '; [skipped] .INCLUDE "dat/DemoLineTextAddrs.inc"'
    )
    new_text_data = (
        'DemoTextFields:\n'
        '; Extracted from NES ROM bank 2, CPU $929A-$94AC (531 bytes)\n'
        '    dc.b    $00, $E4, $E5, $E4, $E5, $E4, $E5, $E6, $24, $0A, $15, $15, $24, $18, $0F, $24\n'
        '    dc.b    $1D, $1B, $0E, $0A, $1C, $1E, $1B, $0E, $1C, $24, $E6, $E4, $E5, $E4, $E5, $E4\n'
        '    dc.b    $E5, $FF, $07, $11, $0E, $0A, $1B, $1D, $24, $24, $24, $24, $24, $0C, $18, $17\n'
        '    dc.b    $1D, $0A, $12, $17, $0E, $1B, $FF, $14, $11, $0E, $0A, $1B, $1D, $FF, $07, $0F\n'
        '    dc.b    $0A, $12, $1B, $22, $24, $24, $24, $24, $24, $24, $24, $24, $0C, $15, $18, $0C\n'
        '    dc.b    $14, $FF, $07, $1B, $1E, $19, $22, $24, $24, $24, $24, $24, $24, $24, $05, $24\n'
        '    dc.b    $1B, $1E, $19, $12, $0E, $1C, $FF, $07, $1C, $20, $18, $1B, $0D, $24, $24, $24\n'
        '    dc.b    $24, $24, $24, $24, $24, $20, $11, $12, $1D, $0E, $FF, $14, $1C, $20, $18, $1B\n'
        '    dc.b    $0D, $FF, $06, $16, $0A, $10, $12, $0C, $0A, $15, $24, $24, $24, $24, $24, $24\n'
        '    dc.b    $16, $0A, $10, $12, $0C, $0A, $15, $FF, $07, $1C, $20, $18, $1B, $0D, $24, $24\n'
        '    dc.b    $24, $24, $24, $24, $24, $24, $1C, $11, $12, $0E, $15, $0D, $FF, $05, $0B, $18\n'
        '    dc.b    $18, $16, $0E, $1B, $0A, $17, $10, $24, $24, $24, $24, $24, $16, $0A, $10, $12\n'
        '    dc.b    $0C, $0A, $15, $FF, $12, $0B, $18, $18, $16, $0E, $1B, $0A, $17, $10, $FF, $07\n'
        '    dc.b    $0B, $18, $16, $0B, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $0B, $18\n'
        '    dc.b    $20, $FF, $07, $0A, $1B, $1B, $18, $20, $24, $24, $24, $24, $24, $24, $24, $24\n'
        '    dc.b    $1C, $12, $15, $1F, $0E, $1B, $FF, $14, $0A, $1B, $1B, $18, $20, $FF, $07, $0B\n'
        '    dc.b    $15, $1E, $0E, $24, $24, $24, $24, $24, $24, $24, $24, $24, $24, $1B, $0E, $0D\n'
        '    dc.b    $FF, $06, $0C, $0A, $17, $0D, $15, $0E, $24, $24, $24, $24, $24, $24, $24, $24\n'
        '    dc.b    $0C, $0A, $17, $0D, $15, $0E, $FF, $07, $0B, $15, $1E, $0E, $24, $24, $24, $24\n'
        '    dc.b    $24, $24, $24, $24, $24, $24, $1B, $0E, $0D, $FF, $07, $1B, $12, $17, $10, $24\n'
        '    dc.b    $24, $24, $24, $24, $24, $24, $24, $24, $24, $1B, $12, $17, $10, $FF, $07, $19\n'
        '    dc.b    $18, $20, $0E, $1B, $24, $24, $24, $24, $24, $24, $24, $1B, $0E, $0C, $18, $1B\n'
        '    dc.b    $0D, $0E, $1B, $FF, $05, $0B, $1B, $0A, $0C, $0E, $15, $0E, $1D, $FF, $07, $1B\n'
        '    dc.b    $0A, $0F, $1D, $24, $24, $24, $24, $24, $24, $24, $1C, $1D, $0E, $19, $15, $0A\n'
        '    dc.b    $0D, $0D, $0E, $1B, $FF, $06, $16, $0A, $10, $12, $0C, $0A, $15, $24, $24, $24\n'
        '    dc.b    $24, $24, $24, $0B, $18, $18, $14, $24, $18, $0F, $FF, $08, $1B, $18, $0D, $24\n'
        '    dc.b    $24, $24, $24, $24, $24, $24, $24, $24, $16, $0A, $10, $12, $0C, $FF, $08, $14\n'
        '    dc.b    $0E, $22, $24, $24, $24, $24, $24, $24, $24, $24, $16, $0A, $10, $12, $0C, $0A\n'
        '    dc.b    $15, $FF, $15, $14, $0E, $22, $FF, $08, $16, $0A, $19, $24, $24, $24, $24, $24\n'
        '    dc.b    $24, $24, $24, $0C, $18, $16, $19, $0A, $1C, $1C, $FF, $0C, $1D, $1B, $12, $0F\n'
        '    dc.b    $18, $1B, $0C, $0E, $FF, $04, $15, $12, $0F, $0E, $24, $19, $18, $1D, $12, $18\n'
        '    dc.b    $17, $24, $24, $24, $02, $17, $0D, $24, $19, $18, $1D, $12, $18, $17, $FF, $06\n'
        '    dc.b    $15, $0E, $1D, $1D, $0E, $1B, $24, $24, $24, $24, $24, $24, $24, $24, $0F, $18\n'
        '    dc.b    $18, $0D, $FF\n'
        '\n'
        '    even\n'
        'DemoLineTextAddrs:\n'
        '; 29 word offsets into DemoTextFields (for M68K direct ROM addressing)\n'
        '    dc.w    $0000, $0022, $0037, $003E, $0052, $01E5, $01FF, $0067\n'
        '    dc.w    $007B, $0082, $0098, $00AD, $00C4, $00CF, $00E2, $00F7\n'
        '    dc.w    $00FE, $0111, $0127, $013A, $014E, $0164, $016E, $0185\n'
        '    dc.w    $019B, $01AE, $01C2, $01C7, $01DB'
    )
    if old_text_stub in text:
        text = text.replace(old_text_stub, new_text_data, 1)
        print("  _patch_z02 P7: DemoTextFields/DemoLineTextAddrs data extracted from NES ROM")
    else:
        print("  WARNING: _patch_z02 P7 -- DemoTextFields stub not found")

    # ---- Patch 8: Fix story text pointer resolution ----
    # Replace NES indirect-pointer text lookup with direct M68K addressing.
    # DemoLineTextAddrs now contains word offsets into DemoTextFields.
    old_text_ptr = (
        '    move.b  ($042E,A4),D0\n'
        '    lsl.b  #1,D0   ; ASL A\n'
        '    moveq   #0,D2\n'
        '    move.b  D0,D2\n'
        '    moveq   #0,D3\n'
        '    lea     (DemoLineTextAddrs).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0000,A4)\n'
        '    lea     (DemoLineTextAddrs+1).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0001,A4)\n'
        '    move.b  ($00,A4),D1   ; ptr lo\n'
        '    move.b  ($01,A4),D4  ; ptr hi\n'
        '    andi.w  #$00FF,D1         ; zero-extend lo byte\n'
        '    lsl.w   #8,D4\n'
        '    or.w    D1,D4             ; D4 = NES ptr addr\n'
        '    ext.l   D4\n'
        '    add.l   #NES_RAM,D4       ; \u2192 Genesis addr\n'
        '    movea.l D4,A0\n'
        '    move.b  (A0,D3.W),D0     ; LDA ($nn),Y\n'
        '    moveq   #0,D2\n'
        '    move.b  D0,D2\n'
        '    even\n'
        '_L_z02_AnimateDemoPhase1Subphase2_CopyLine:\n'
        '    ; X is an offset into the destination line.\n'
        '    ; Y is an offset into the source tiles of the current record.\n'
        '    ;\n'
        '    ; Get the next source tile.\n'
        '    addq.b  #1,D3\n'
        '    move.b  ($00,A4),D1   ; ptr lo\n'
        '    move.b  ($01,A4),D4  ; ptr hi\n'
        '    andi.w  #$00FF,D1         ; zero-extend lo byte\n'
        '    lsl.w   #8,D4\n'
        '    or.w    D1,D4             ; D4 = NES ptr addr\n'
        '    ext.l   D4\n'
        '    add.l   #NES_RAM,D4       ; \u2192 Genesis addr\n'
        '    movea.l D4,A0\n'
        '    move.b  (A0,D3.W),D0     ; LDA ($nn),Y\n'
        '    cmpi.b  #$FF,D0\n'
        '    beq  _L_z02_AnimateDemoPhase1Subphase2_EndLine\n'
        '    lea     ($0305,A4),A0\n'
        '    move.b  D0,(A0,D2.W)\n'
        '    addq.b  #1,D2\n'
        '    jmp     _L_z02_AnimateDemoPhase1Subphase2_CopyLine'
    )
    new_text_ptr = (
        '    ; PATCHED (P8): Replace broken NES indirect-pointer text lookup with\n'
        '    ; direct M68K addressing. DemoLineTextAddrs contains word offsets.\n'
        '    move.b  ($042E,A4),D0\n'
        '    andi.w  #$00FF,D0\n'
        '    lsl.w   #1,D0                ; * 2 for word-sized offset table\n'
        '    lea     (DemoLineTextAddrs).l,A0\n'
        '    move.w  (A0,D0.W),D0        ; D0.w = offset into DemoTextFields\n'
        '    lea     (DemoTextFields).l,A0\n'
        '    adda.w  D0,A0               ; A0 -> text field entry in ROM\n'
        '    moveq   #0,D3               ; Y index into text field\n'
        '    move.b  (A0,D3.W),D0        ; first byte = column offset\n'
        '    moveq   #0,D2\n'
        '    move.b  D0,D2\n'
        '    even\n'
        '_L_z02_AnimateDemoPhase1Subphase2_CopyLine:\n'
        '    ; X (D2) = offset into destination line.\n'
        '    ; Y (D3) = offset into source tiles of current text record.\n'
        '    ; A0 = pointer to current text field (preserved across loop).\n'
        '    addq.b  #1,D3\n'
        '    move.b  (A0,D3.W),D0        ; read next tile from ROM\n'
        '    cmpi.b  #$FF,D0\n'
        '    beq  _L_z02_AnimateDemoPhase1Subphase2_EndLine\n'
        '    lea     ($0305,A4),A1\n'
        '    move.b  D0,(A1,D2.W)\n'
        '    addq.b  #1,D2\n'
        '    jmp     _L_z02_AnimateDemoPhase1Subphase2_CopyLine'
    )
    if old_text_ptr in text:
        text = text.replace(old_text_ptr, new_text_ptr, 1)
        print("  _patch_z02 P8: story text pointer -> direct M68K addressing")
    else:
        print("  WARNING: _patch_z02 P8 -- story text pointer pattern not found")

    # ---- Patch 9: StoryPaletteTransferRecord — add comment (data unchanged) ----
    # Genesis has only 4 CRAM palettes shared between BG and sprites.
    # NES sprite pals 0,2 both map to CRAM pal 2; 1,3 map to CRAM pal 3.
    # Sequential processing means last write wins: spr pal 2-3 are the
    # final values, which is correct (spr pal 2 has red for hearts/swords).
    old_story_pal = (
        'StoryPaletteTransferRecord:\n'
        '    dc.b    $3F, $00, $20, $0F, $30, $30, $30, $0F\n'
        '    dc.b    $21, $30, $30, $0F, $16, $30, $30, $0F\n'
        '    dc.b    $29, $1A, $09, $0F, $29, $37, $17, $0F\n'
        '    dc.b    $02, $22, $30, $0F, $16, $27, $30, $0F\n'
        '    dc.b    $0B, $1B, $2B, $FF'
    )
    new_story_pal = (
        'StoryPaletteTransferRecord:\n'
        '    ; Full 32-byte NES palette record (BG 0-3 + spr 0-3).\n'
        '    ; Sprite pals 0,2 both map to CRAM pal 2; 1,3 both map to CRAM pal 3.\n'
        '    ; Sequential processing: last write wins \xe2\x86\x92 spr pal 2-3 are the final values.\n'
        '    dc.b    $3F, $00, $20, $0F, $30, $30, $30, $0F\n'
        '    dc.b    $21, $30, $30, $0F, $16, $30, $30, $0F\n'
        '    dc.b    $29, $1A, $09, $0F, $29, $37, $17, $0F\n'
        '    dc.b    $02, $22, $30, $0F, $16, $27, $30, $0F\n'
        '    dc.b    $0B, $1B, $2B, $FF'
    )
    if old_story_pal in text:
        text = text.replace(old_story_pal, new_story_pal, 1)
        print("  _patch_z02 P9: add comment to StoryPaletteTransferRecord (data unchanged)")
    else:
        print("  WARNING: _patch_z02 P9 -- StoryPaletteTransferRecord not found")

    # ---- Patch 10: Clear both nametables during Phase 1 init ----
    # After title screen fades to black, stale title nametable tiles
    # remain in VRAM.  Clear both NT0 and NT1 in V64 plane before story scroll.
    old_story_tiles_init = (
        'InitDemoSubphaseTransferStoryTiles:\n'
        '    addq.b  #1,($005C,A4)'
    )
    new_story_tiles_init = (
        'InitDemoSubphaseTransferStoryTiles:\n'
        '    ; PATCHED (P10): Clear both nametables (V64 plane) at story scroll init\n'
        '    move.b  #$20,D0\n'
        '    move.b  #$24,D2\n'
        '    moveq   #0,D3\n'
        '    bsr     _clear_nametable_fast\n'
        '    move.b  #$28,D0\n'
        '    bsr     _clear_nametable_fast\n'
        '    addq.b  #1,($005C,A4)'
    )
    if old_story_tiles_init in text:
        text = text.replace(old_story_tiles_init, new_story_tiles_init, 1)
        print("  _patch_z02 P10: clear both NTs (V64) at story scroll init")
    else:
        print("  WARNING: _patch_z02 P10 -- InitDemoSubphaseTransferStoryTiles not found")

    # ---- Patch 11: Set/clear VRamForceBlankGate around file-select init chain ----
    # Sets VRamForceBlankGate=1 at the top of UpdateMode0Demo_Sub0 (the Start-press
    # handler that kicks off the file-select init chain) and clears it at the end
    # of InitMode1_Sub6 (the last InitMode1 submode before the game transitions
    # to normal Mode1 gameplay).  While the gate is held, _ppu_write_1 in
    # nes_io.asm masks BG+sprite enable bits off so the VDP stays in force-blank,
    # preventing a beam-race if the user presses Start mid-frame while CHR/VRAM
    # is still streaming.  VRamForceBlankGate lives at $FF083D.
    # NOTE: _patch_z02 runs BEFORE _promote_nonlocal_bsr_to_jsr, so the input
    # text here still has the pre-promotion short forms ("beq Exit", "bsr ...").
    old_sub0_force_blank = (
        'UpdateMode0Demo_Sub0:\n'
        '    move.b  ($00F8,A4),D0\n'
        '    andi.b #$10,D0\n'
        '    beq  Exit\n'
        '    move.b  D0,($00F6,A4)\n'
        '    moveq   #0,D0\n'
        '    move.b  D0,($0600,A4)\n'
        '    bsr     SilenceAllSound'
    )
    new_sub0_force_blank = (
        'UpdateMode0Demo_Sub0:\n'
        '    move.b  ($00F8,A4),D0\n'
        '    andi.b #$10,D0\n'
        '    beq  Exit\n'
        '    move.b  #1,($00FF083D).l    ; PATCH P11: hold VRamForceBlankGate\n'
        '    move.b  #1,($00FF042B).l    ; PATCH P12: arm FrontendStartReleaseGate\n'
        '    move.b  D0,($00F6,A4)\n'
        '    moveq   #0,D0\n'
        '    move.b  D0,($0600,A4)\n'
        '    bsr     SilenceAllSound'
    )
    if old_sub0_force_blank in text:
        text = text.replace(old_sub0_force_blank, new_sub0_force_blank, 1)
        print("  _patch_z02 P11a: set VRamForceBlankGate in UpdateMode0Demo_Sub0")
    else:
        idx_dbg = text.find('UpdateMode0Demo_Sub0:')
        if idx_dbg < 0:
            print("  WARNING: _patch_z02 P11a -- label 'UpdateMode0Demo_Sub0:' absent entirely")
        else:
            print("  WARNING: _patch_z02 P11a -- region mismatch, first 300 chars:")
            print("    " + repr(text[idx_dbg:idx_dbg+300]))

    old_sub6_release = (
        '    moveq   #0,D0\n'
        '    move.b  D0,($0013,A4)\n'
        '    addq.b  #1,($0011,A4)\n'
        '    rts\n'
        '\n'
        '    even\n'
        'Mode1CursorSpriteTriplet:'
    )
    new_sub6_release = (
        '    moveq   #0,D0\n'
        '    move.b  D0,($0013,A4)\n'
        '    addq.b  #1,($0011,A4)\n'
        '    clr.b   ($00FF083D).l       ; PATCH P11: release VRamForceBlankGate\n'
        '    rts\n'
        '\n'
        '    even\n'
        'Mode1CursorSpriteTriplet:'
    )
    if old_sub6_release in text:
        text = text.replace(old_sub6_release, new_sub6_release, 1)
        print("  _patch_z02 P11b: clear VRamForceBlankGate at end of InitMode1_Sub6")
    else:
        print("  WARNING: _patch_z02 P11b -- InitMode1_Sub6 tail not found")

    # ---- Patch 12: FrontendStartReleaseGate in UpdateMode1Menu_Sub0 ----
    # Attempt 6a (diary 2026-04-04 13:16:58).  When the title -> file-select
    # transition fires, the Start button is still held from the tap that caused
    # it.  The unpatched UpdateMode1Menu_Sub0 treats that held press as "user
    # wants to leave file-select" and instantly advances to Sub1 (gameplay).
    # Gate the Sub0 entry on $00FF042B: while the gate is non-zero and Start
    # is still held, Sub0 returns without advancing.  The moment Start
    # releases, the gate is cleared and normal Sub0 logic resumes.
    old_sub0_menu = (
        'UpdateMode1Menu_Sub0:\n'
        '    move.b  ($00F8,A4),D0\n'
        '    andi.b #$10,D0\n'
        '    bne  _L_z02_UpdateMode1Menu_Sub0_Exit\n'
    )
    new_sub0_menu = (
        'UpdateMode1Menu_Sub0:\n'
        '    tst.b   ($00FF042B).l          ; PATCH P12: FrontendStartReleaseGate\n'
        '    beq.s   .p12_mode1_sub0_pass\n'
        '    move.b  ($00F8,A4),D0\n'
        '    andi.b  #$10,D0\n'
        '    beq.s   .p12_mode1_sub0_release\n'
        '    rts                             ; Start still held -> stay in Sub0\n'
        '.p12_mode1_sub0_release:\n'
        '    clr.b   ($00FF042B).l          ; Start released -> clear gate\n'
        '.p12_mode1_sub0_pass:\n'
        '    move.b  ($00F8,A4),D0\n'
        '    andi.b #$10,D0\n'
        '    bne  _L_z02_UpdateMode1Menu_Sub0_Exit\n'
    )
    if old_sub0_menu in text:
        text = text.replace(old_sub0_menu, new_sub0_menu, 1)
        print("  _patch_z02 P12: FrontendStartReleaseGate in UpdateMode1Menu_Sub0")
    else:
        print("  WARNING: _patch_z02 P12 -- UpdateMode1Menu_Sub0 head not found")

    # ---- Patch 13: ModeE_SyncCharBoardCursorToIndex (Attempt 6a part 2) ----
    # Diary 2026-04-04 13:16:58.  Replace the old Attempt-5f hidden-slot clamp
    # with a source-of-truth sync between CharBoardIndex ($041F) and the char
    # board cursor (ObjX=$0071, ObjY=$0085).  Called from FinishInput so that
    # after every direction move the index is clamped mod 44 and the cursor
    # coords are regenerated from a small lookup (col*$10+$30, row*$10+$87).
    # Hidden slot = idx 43; it is snapped to idx 9 ('J').  The existing Right
    # wrap code already maps idx 42->0 through CycleCharBoardCursorY, so the
    # "right-from-hidden -> A" rule is handled by the existing path; the sync
    # only fixes "other hidden landings -> 9".
    # P25 (Phase 10.5-fix, Zelda27.81): FS2-F console-freeze suspect.
    # Builds/reports/fs2f_audit.md identifies P13 as the only helper reached
    # by the direction handlers that the A-press path does NOT call.  On
    # BizHawk the grid walk is clean; on real MegaDrive hardware EVERY
    # direction press stalls.  Disable the FinishInput jsr into P13 to see
    # whether the freeze clears.  The P13 body at 2240+ stays injected as
    # dead code (no caller) so the file still assembles and 10.7's P13 Y
    # constant fix still has an anchor if we re-enable it later.
    old_finish_input = (
        '_L_z02_ModeE_HandleDirectionButton_FinishInput:\n'
        '    moveq   #1,D0\n'
        '    move.b  D0,($0428,A4)\n'
        '    move.b  D0,($0602,A4)\n'
    )
    new_finish_input = (
        '_L_z02_ModeE_HandleDirectionButton_FinishInput:\n'
        '    ; PATCH P25: P13 sync call DISABLED for FS2-F console freeze\n'
        '    moveq   #1,D0\n'
        '    move.b  D0,($0428,A4)\n'
        '    move.b  D0,($0602,A4)\n'
    )
    if old_finish_input in text:
        text = text.replace(old_finish_input, new_finish_input, 1)
        print("  _patch_z02 P13a: jsr ModeE_SyncCharBoardCursorToIndex in FinishInput")
    else:
        print("  WARNING: _patch_z02 P13a -- FinishInput head not found")

    # Inject the sync function body right after LA10A_Exit (the CycleCharBoard
    # tail) so it sits adjacent to the code it supports.
    old_la10a_tail = (
        '_L_z02_CycleCharBoardCursorY_ReturnValue:\n'
        '    move.b  D3,($042A,A4)\n'
        '    even\n'
        'LA10A_Exit:\n'
        '    rts\n'
    )
    new_la10a_tail = (
        '_L_z02_CycleCharBoardCursorY_ReturnValue:\n'
        '    move.b  D3,($042A,A4)\n'
        '    even\n'
        'LA10A_Exit:\n'
        '    rts\n'
        '\n'
        '; PATCH P13: ModeE_SyncCharBoardCursorToIndex (Attempt 6a part 2).\n'
        '; Source-of-truth sync for the char board cursor.  Normalizes\n'
        '; CharBoardIndex ($041F) mod 44, snaps the hidden slot (idx 43)\n'
        '; to idx 9, and regenerates (ObjX=$0071, ObjY=$0085) from the\n'
        '; index using row = idx/11, col = idx%11, ObjX = $30+col*$10,\n'
        '; ObjY = $87+row*$10.  Call this after any direction move.\n'
        '    even\n'
        'ModeE_SyncCharBoardCursorToIndex:\n'
        '    move.l  D0,-(A7)\n'
        '    move.l  D1,-(A7)\n'
        '    move.b  ($041F,A4),D0\n'
        '    btst    #7,D0\n'
        '    beq.s   .p13_ck_high\n'
        '    addi.b  #44,D0         ; underflow wrap (-1 -> 43)\n'
        '.p13_ck_high:\n'
        '    cmpi.b  #44,D0\n'
        '    bcs.s   .p13_ck_hidden\n'
        '    subi.b  #44,D0         ; overflow wrap\n'
        '.p13_ck_hidden:\n'
        '    cmpi.b  #43,D0\n'
        '    bne.s   .p13_compute\n'
        '    moveq   #9,D0          ; hidden slot -> idx 9\n'
        '.p13_compute:\n'
        '    move.b  D0,($041F,A4)\n'
        '    moveq   #0,D1\n'
        '.p13_row_loop:\n'
        '    cmpi.b  #11,D0\n'
        '    bcs.s   .p13_row_done\n'
        '    subi.b  #11,D0\n'
        '    addq.b  #1,D1\n'
        '    bra.s   .p13_row_loop\n'
        '.p13_row_done:\n'
        '    lsl.b   #4,D0\n'
        '    addi.b  #$30,D0\n'
        '    move.b  D0,($0071,A4)\n'
        '    lsl.b   #4,D1\n'
        '    addi.b  #$88,D1         ; PATCH P26: Phase 10 FS2-B Y base +1 px\n'
        '    move.b  D1,($0085,A4)\n'
        '    move.l  (A7)+,D1\n'
        '    move.l  (A7)+,D0\n'
        '    rts\n'
    )
    if old_la10a_tail in text:
        text = text.replace(old_la10a_tail, new_la10a_tail, 1)
        print("  _patch_z02 P13b: ModeE_SyncCharBoardCursorToIndex body injected")
    else:
        print("  WARNING: _patch_z02 P13b -- LA10A_Exit tail not found")

    # ---- Patch 14: Zelda16.11 -- 9th letter wrap gate on $0070==$B0 ----
    # Diary Finding #29.  The old gate tested "$0423 & $0F == 6" to decide
    # whether the VRAM address had walked past the name field.  But
    # UpdateWaterfallAnimation in title mode rewrites $0423 to $C0 during its
    # BG animation, so by the time REGISTER runs the gate's premise is dead
    # and the wrap never fires.  Re-gate on the cursor pixel X instead: the
    # cursor is at $0070=$B0 exactly when it has walked off the 8th letter
    # column, which is the true wrap condition.  The secondary clamp at
    # line ~2770 ("cmpi.b #$B0" before the 112/$70 reset) already keys on
    # $0070 and stays as-is.
    old_wrap_gate = (
        '    move.b  ($0423,A4),D0\n'
        '    andi.b #$0F,D0\n'
        '    cmpi.b  #$06,D0\n'
        '    bne  _L_z02_ModeE_HandleAOrB_Exit\n'
    )
    new_wrap_gate = (
        '    move.b  ($0070,A4),D0      ; PATCH P14: Zelda16.11\n'
        '    cmpi.b  #$B0,D0\n'
        '    bne  _L_z02_ModeE_HandleAOrB_Exit\n'
    )
    if old_wrap_gate in text:
        text = text.replace(old_wrap_gate, new_wrap_gate, 1)
        print("  _patch_z02 P14: Zelda16.11 9th letter wrap gate -> $0070==$B0")
    else:
        print("  WARNING: _patch_z02 P14 -- wrap gate pattern not found")

    # P15, P19a, P19b removed: superseded by transpiler-side SBC X-flag
    # polarity fix (subx.b now wrapped with `eori #$10,CCR` pair). These
    # were compensating for the M68K SUBX off-by-one vs 6502 SEC;SBC, which
    # no longer exists. T34 D-pad movement parity (8/8 PASS) confirms.

    # ------------------------------------------------------------------
    # P21: Phase 9.8 — wire save-slot writes through cart SRAM.
    #
    # NES Zelda's three save slots live in the work-RAM mirror at NES_SRAM
    # ($FF6000-$FF67FF) and are written by FormatFileB / UpdateModeERegister
    # / various in-game save paths.  All of those eventually return through
    # UpdateModeDSave_Sub2 (the "save → return to title" funnel at z_02.asm
    # line 4467 area).  Inserting `jsr _sram_commit_save_slots` at the head
    # of that function copies the entire 2 KB mirror to cart SRAM in one
    # shot, persisting all three slots in a single hook point.
    #
    # The matching boot-time `jsr _sram_load_save_slots` lives in
    # genesis_shell.asm EntryPoint and restores the mirror from cart SRAM
    # before Zelda runs.
    # ------------------------------------------------------------------
    old_save_sub2_head = (
        'UpdateModeDSave_Sub2:\n'
        '    moveq   #0,D0\n'
        '    move.b  D0,($0012,A4)\n'
    )
    new_save_sub2_head = (
        'UpdateModeDSave_Sub2:\n'
        '    jsr     _sram_commit_save_slots  ; PATCH P21: Phase 9.8 persist save slots\n'
        '    moveq   #0,D0\n'
        '    move.b  D0,($0012,A4)\n'
    )
    if old_save_sub2_head in text:
        text = text.replace(old_save_sub2_head, new_save_sub2_head, 1)
        print("  _patch_z02 P21: Phase 9.8 SRAM commit hook in UpdateModeDSave_Sub2")
    else:
        print("  WARNING: _patch_z02 P21 -- UpdateModeDSave_Sub2 head not found")

    # ------------------------------------------------------------------
    # P22: Phase 10 FS1-B — stop the Mode 1 Link slot loop from drifting
    # the sprite descriptor attrs between iterations.
    #
    # `Mode1_WriteLinkSprites` reuses ($0004,A4)/($0005,A4) as BOTH the
    # Anim_SetSpriteDescriptorAttributes attr bytes AND as the slot-loop
    # counter.  At the bottom of the loop it does:
    #
    #     addq.b #1,($0004,A4)
    #     addq.b #1,($0005,A4)
    #     move.b ($0004,A4),D0
    #     cmpi.b #$03,D0
    #     bne    _L_z02_Mode1_WriteLinkSprites_LoopSlot
    #
    # On NES that is harmless because sprite sub-palettes 0/1/2 all carry
    # the same Link colors.  On Genesis via the CHR-expansion palette
    # bridge, sub-pal N routes to CRAM PAL N, so slots 1 and 2 render with
    # PAL1/PAL2 (blue/green) instead of PAL0.  FS1 probe fs1_p10_diag.txt
    # confirms spr04/05 attr=$00, spr06/07 attr=$01, spr08/09 attr=$02.
    #
    # Fix: route the slot counter through a fresh scratch byte ($0006,A4)
    # — unused anywhere else in z_02.asm per grep — so the descriptor
    # attrs remain at $00 for every slot.  The Anim setup at 3927 already
    # seeds both halves to $00 via `moveq #0,D0 ; jsr
    # Anim_SetSpriteDescriptorAttributes`, so the loop body can stop
    # touching $0004/$0005 entirely.
    # ------------------------------------------------------------------
    p22_old_loop_tail = (
        '    move.b  D0,($0001,A4)\n'
        '    addq.b  #1,($0004,A4)\n'
        '    addq.b  #1,($0005,A4)\n'
        '    move.b  ($0004,A4),D0\n'
        '    cmpi.b  #$03,D0\n'
        '    bne  _L_z02_Mode1_WriteLinkSprites_LoopSlot\n'
        '    rts\n'
    )
    p22_new_loop_tail = (
        '    move.b  D0,($0001,A4)\n'
        '    addq.b  #1,($0006,A4)   ; PATCH P22: slot counter in scratch byte\n'
        '    move.b  ($0006,A4),D0\n'
        '    cmpi.b  #$03,D0\n'
        '    bne  _L_z02_Mode1_WriteLinkSprites_LoopSlot\n'
        '    rts\n'
    )
    p22_old_slot_lookup = (
        '    moveq   #0,D3\n'
        '    move.b  ($0004,A4),D3\n'
        '    lea     ($062D,A4),A0\n'
        '    move.b  (A0,D3.W),D0\n'
        '    beq  _L_z02_Mode1_WriteLinkSprites_NextSlot\n'
    )
    p22_new_slot_lookup = (
        '    moveq   #0,D3\n'
        '    move.b  ($0006,A4),D3   ; PATCH P22: read slot idx from scratch\n'
        '    lea     ($062D,A4),A0\n'
        '    move.b  (A0,D3.W),D0\n'
        '    beq  _L_z02_Mode1_WriteLinkSprites_NextSlot\n'
    )
    # NOTE: _patch_common promotes bsr->jsr AFTER _patch_z02 runs, so the
    # init anchor must match the pre-promotion `bsr` form.
    p22_old_init = (
        '    moveq   #0,D0\n'
        '    bsr     Anim_SetSpriteDescriptorAttributes\n'
        '    ; We want to start with sprite 4 (offset $10).\n'
    )
    p22_new_init = (
        '    moveq   #0,D0\n'
        '    bsr     Anim_SetSpriteDescriptorAttributes\n'
        '    moveq   #0,D0\n'
        '    move.b  D0,($0006,A4)   ; PATCH P22: init slot counter\n'
        '    ; We want to start with sprite 4 (offset $10).\n'
    )

    if False:  # PHASE 12 REVERTED -- P22 does not fix per-slot Link attr (Fact A/B)
        p22_hits = 0
        if p22_old_loop_tail in text:
            text = text.replace(p22_old_loop_tail, p22_new_loop_tail, 1)
            p22_hits += 1
        if p22_old_slot_lookup in text:
            text = text.replace(p22_old_slot_lookup, p22_new_slot_lookup, 1)
            p22_hits += 1
        if p22_old_init in text:
            text = text.replace(p22_old_init, p22_new_init, 1)
            p22_hits += 1
        if p22_hits == 3:
            print("  _patch_z02 P22: Mode1_WriteLinkSprites attr drift fix (FS1-B)")
        elif p22_hits > 0:
            print(f"  WARNING: _patch_z02 P22 -- only {p22_hits}/3 anchors matched (FS1-B)")
        else:
            print("  WARNING: _patch_z02 P22 -- no anchors matched (FS1-B)")
    else:
        print("  _patch_z02 P22: REVERTED (Phase 12)")

    # ------------------------------------------------------------------
    # P23a: Phase 10 FS1-A — Mode 1 slot-Link Y seed
    #
    # The Mode 1 cursor writer at z_02.asm:3822-3823 seeds the Link ladder
    # at $0001 = 88.  Mode1_WriteLinkSprites then writes the three slot
    # Link pairs at Y = 88, 112, 136 (seed, seed+24, seed+48).  The heart
    # cursor table Mode1CursorSpriteYs is $5C,$74,$8C,$A8,$B8 = 92,116,
    # 140,168,184, so the three save-slot cursor positions are 92/116/
    # 140 — the Link ladder is 4 pixels higher than the cursor row on
    # every slot.  Fix the seed from 88 to 92.
    #
    # Anchored on the exact 4-line sequence immediately after the
    # Mode1CursorSpriteYs store at 3820-3821 so we can't match a stray
    # `moveq #88,D0` elsewhere in z_02.asm.
    # ------------------------------------------------------------------
    p23a_old = (
        '    move.b  D0,($0200,A4)\n'
        '    moveq   #88,D0\n'
        '    move.b  D0,($0001,A4)\n'
        '    moveq   #48,D0\n'
        '    move.b  D0,($0000,A4)\n'
    )
    p23a_new = (
        '    move.b  D0,($0200,A4)\n'
        '    moveq   #92,D0   ; PATCH P23a: Phase 10 FS1-A Link seed Y\n'
        '    move.b  D0,($0001,A4)\n'
        '    moveq   #48,D0\n'
        '    move.b  D0,($0000,A4)\n'
    )
    if False and p23a_old in text:  # PHASE 12 REVERTED: user says sprites too low; 88 is correct NES value
        text = text.replace(p23a_old, p23a_new, 1)
        print("  _patch_z02 P23a: Mode 1 Link seed 88 -> 92 (FS1-A)")
    else:
        print("  _patch_z02 P23a: REVERTED (Phase 12 — NES seed 88 correct)")

    # ------------------------------------------------------------------
    # P24: Phase 10 FS2-A — Mode $0E Link ladder seed
    #
    # InitModeEandF_Full's tail (`_anon_z02_5` at z_02.asm:2133-2139) seeds
    # the three slot Link positions before jumping into
    # Mode1_WriteLinkSprites.  The NES source stores X -> $0000 first then
    # Y -> $0001; Mode1_WriteLinkSprites reads $0001 as Y and $0000 as X.
    # Current seeds: $0000=80 ($50), $0001=48 ($30).  That drops Link at
    # Y=48,72,96 and X=80 - too high and off-center, floating above the
    # REGISTER/ELIMINATE keyboard.
    #
    # The Mode 1 slot display uses X=48 Y=92 (matching
    # Mode1CursorSpriteYs after P23a).  Mode $0E's three-slot list is the
    # same layout with a keyboard added below, so reuse the Mode 1 seeds
    # exactly: X=48, Y=92.  Link Ys become 92/116/140 matching FS1.
    # ------------------------------------------------------------------
    p24_old = (
        '_anon_z02_5:\n'
        '    moveq   #80,D0\n'
        '    move.b  D0,($0000,A4)\n'
        '    moveq   #48,D0\n'
        '    move.b  D0,($0001,A4)\n'
    )
    p24_new = (
        '_anon_z02_5:\n'
        '    moveq   #48,D0   ; PATCH P24: Phase 10 FS2-A Link seed X\n'
        '    move.b  D0,($0000,A4)\n'
        '    moveq   #92,D0   ; PATCH P24: Phase 10 FS2-A Link seed Y\n'
        '    move.b  D0,($0001,A4)\n'
    )
    if False:  # PHASE 12 REVERTED -- user reports FS2 Link "way too far down" after P24
        if p24_old in text:
            text = text.replace(p24_old, p24_new, 1)
            print("  _patch_z02 P24: Mode $0E Link seeds X=48 Y=92 (FS2-A)")
        else:
            print("  WARNING: _patch_z02 P24 -- _anon_z02_5 seed anchor not found (FS2-A)")
    else:
        print("  _patch_z02 P24: REVERTED (Phase 12)")

    # ------------------------------------------------------------------
    # P25b: Phase 10.6 FS2-E — REGISTER-mode backspace
    #
    # _L_z02_ModeE_HandleAOrB_CheckAB (z_02.asm:2681) dispatches:
    #   - A (bit $80) -> char write, falls into MoveCursor (advance)
    #   - B (bit $40) -> jumps directly to MoveCursor (advance only)
    #
    # User expectation: B = backspace = retreat cursor one slot and erase.
    # Split the B branch to a new handler _L_z02_ModeE_HandleAOrB_Backspace
    # that decrements NameCharOffset ($0421), VRAM low byte ($0423), and
    # the name cursor sprite X ($0070), and writes a space tile ($24) to
    # the erased position in the name buffer ($0638 + $0421).  Clamps at
    # SlotToNameOffset[$0016] so we cannot backspace into the previous
    # slot's name.
    #
    # Two-anchor patch:
    #   (a) redirect the cmpi/bne in CheckAB from MoveCursor -> Backspace
    #   (b) inject the Backspace body immediately before the existing
    #       _L_z02_ModeE_HandleAOrB_Exit label
    # ------------------------------------------------------------------
    p25b_old_dispatch = (
        '    ; A or B was pressed.\n'
        '    ;\n'
        '    cmpi.b  #$80,D0\n'
        '    bne  _L_z02_ModeE_HandleAOrB_MoveCursor\n'
    )
    p25b_new_dispatch = (
        '    ; A or B was pressed.\n'
        '    ;\n'
        '    cmpi.b  #$40,D0  ; PATCH P29: swap so NES-B (Gen A) = write, NES-A (Gen B) = bksp\n'
        '    bne  _L_z02_ModeE_HandleAOrB_Backspace   ; PATCH P25b: B = backspace\n'
    )
    p25b_old_exit = (
        '    moveq   #112,D0\n'
        '    move.b  D0,($0070,A4)\n'
        '    even\n'
        '_L_z02_ModeE_HandleAOrB_Exit:\n'
        '    jmp     ModeE_SetNameCursorSpriteX\n'
    )
    p25b_new_exit = (
        '    moveq   #112,D0\n'
        '    move.b  D0,($0070,A4)\n'
        '    even\n'
        '; PATCH P25b: FS2-E backspace handler.\n'
        '; Entered when bit $40 (B) is set in $00F8 & $C0. Decrements\n'
        '; NameCharOffset, VRAM low byte, and name cursor sprite X by\n'
        '; one column (8 px), and writes a space ($24) to the erased\n'
        '; position. Clamps at SlotToNameOffset[$0016] so the backspace\n'
        '; cannot cross into a previous slot\'s name field.\n'
        '_L_z02_ModeE_HandleAOrB_Backspace:\n'
        '    moveq   #0,D3\n'
        '    move.b  ($0016,A4),D3        ; D3 = current slot\n'
        '    lea     (SlotToNameOffset).l,A0\n'
        '    move.b  (A0,D3.W),D1         ; D1 = slot start offset\n'
        '    move.b  ($0421,A4),D0        ; D0 = current NameCharOffset\n'
        '    cmp.b   D1,D0\n'
        '    bls     _L_z02_ModeE_HandleAOrB_Exit   ; at/below start, no-op\n'
        '    subq.b  #1,D0\n'
        '    move.b  D0,($0421,A4)        ; NameCharOffset -= 1\n'
        '    subq.b  #1,($0423,A4)        ; VRAM low byte -= 1\n'
        '    move.b  ($0070,A4),D1\n'
        '    subi.b  #8,D1\n'
        '    move.b  D1,($0070,A4)        ; name cursor X -= 8\n'
        '    moveq   #$24,D1              ; space tile\n'
        '    moveq   #0,D3\n'
        '    move.b  D0,D3                ; D3 = erased offset\n'
        '    lea     ($0638,A4),A0\n'
        '    move.b  D1,(A0,D3.W)         ; namebuf[offset] = space\n'
        '    jmp     _L_z02_ModeE_HandleAOrB_Exit\n'
        '    even\n'
        '_L_z02_ModeE_HandleAOrB_Exit:\n'
        '    jmp     ModeE_SetNameCursorSpriteX\n'
    )
    p25b_hits = 0
    if p25b_old_dispatch in text:
        text = text.replace(p25b_old_dispatch, p25b_new_dispatch, 1)
        p25b_hits += 1
    if p25b_old_exit in text:
        text = text.replace(p25b_old_exit, p25b_new_exit, 1)
        p25b_hits += 1
    if p25b_hits == 2:
        print("  _patch_z02 P25b: FS2-E REGISTER backspace handler (+ P29 button swap)")
    else:
        print(f"  WARNING: _patch_z02 P25b -- only {p25b_hits}/2 anchors matched (FS2-E)")

    # ------------------------------------------------------------------
    # P28: Phase 12 FS1-A heart cursor horizontal alignment.
    #
    # Probe data (phase12_probe.txt) shows heart sprite X=40 vs Link X=48.
    # P23a moved Link X to $30 but the Mode1CursorSpriteTriplet table
    # still has heart X=$28. Bump it 8 pixels right so the heart
    # visually lines up with the Link sprite pair on each save slot row.
    # ------------------------------------------------------------------
    p28_old = (
        'Mode1CursorSpriteTriplet:\n'
        '    dc.b    $F3, $03, $28\n'
    )
    p28_new = (
        'Mode1CursorSpriteTriplet:\n'
        '    dc.b    $F3, $03, $30       ; PATCH P28: heart X $28->$30 align Link\n'
    )
    if False and p28_old in text:  # PHASE 12 REVERTED: fs_compare proved NES heart X~41, Gen pre-P28 X=40 was closer than X=48
        text = text.replace(p28_old, p28_new, 1)
        print("  _patch_z02 P28: FS1 heart cursor X align with Link (FS1-A)")
    else:
        print("  _patch_z02 P28: REVERTED (compare data showed wrong direction)")

    # ------------------------------------------------------------------
    # P30: Phase 12 FS1-B Link sprite color fix.
    #
    # Mode1_WriteLinkSprites steps ($0004,A4)/($0005,A4) per slot so that
    # Anim_WriteSpritePairNotFlashing reads a different NES sub-palette
    # (0->1->2) on each iteration. On NES all 4 sub-pals held the same
    # Link tunic green, so stepping was invisible. Under CHR_EXPANSION,
    # each sub-pal routes to a DIFFERENT packed tile bank — which is why
    # fs1_compare.png showed slot 0 = green (bank A correct), slot 1 =
    # blue (bank B), slot 2 = red (bank C).
    #
    # Fix: save/restore $04/$05 around the jsr and clear them to 0 during
    # the call, pinning the descriptor attr to 0 for ALL slots (force
    # bank A). The surrounding loop still uses $04 as the slot index for
    # IsSaveSlotActive lookup (3984) and the loop-exit check (4017), so
    # we MUST restore the original value immediately after the jsr.
    # ------------------------------------------------------------------
    # NOTE: _patch_common's bsr->jsr promotion runs AFTER _patch_z02, so the
    # anchor here must use `bsr` not `jsr`. The promoter will rewrite the jsr
    # form in our replacement back to bsr only if it's a local call; since
    # Anim_WriteSpritePairNotFlashing is non-local the promoter will upgrade.
    p30_old = (
        '    move.b  D0,-(A5)  ; PHA\n'
        '    bsr     Anim_WriteSpritePairNotFlashing\n'
        '    moveq   #0,D2\n'
    )
    p30_new = (
        '    move.b  D0,-(A5)  ; PHA\n'
        '    move.w  ($0004,A4),D1       ; PATCH P30: save $04/$05\n'
        '    move.w  D1,-(A7)            ; PATCH P30: push to stack\n'
        '    clr.w   ($0004,A4)          ; PATCH P30: pin Link attr=0 (bank A = green)\n'
        '    bsr     Anim_WriteSpritePairNotFlashing\n'
        '    move.w  (A7)+,D1            ; PATCH P30: pop\n'
        '    move.w  D1,($0004,A4)       ; PATCH P30: restore slot index\n'
        '    moveq   #0,D2\n'
    )
    if p30_old in text:
        text = text.replace(p30_old, p30_new, 1)
        print("  _patch_z02 P30: Mode1 Link attr=0 pin (FS1-B green Link)")
    else:
        print("  WARNING: _patch_z02 P30 -- Mode1 Link bsr anchor not found")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def _patch_z03(path):
    """Inject bank-window guards into ROM-pointer consumers (bank-3 pinned).
    When ZELDA_BANK_MODE_03 == "c", strip all code and emit only data labels
    plus a TransferLevelPatternBlocks stub that jumps to the C shim."""

    # Stage 2d: "c" mode emits data-only asm + C-shim jump for the entry point.
    ZELDA_BANK_MODE_03 = "c"

    if ZELDA_BANK_MODE_03 == "c":
        _patch_z03_c_mode(path)
        return

    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()

    hooks = [
        ('FetchPatternBlockAddrUW', 3),
        ('FetchPatternBlockInfoOW', 3),
        ('FetchPatternBlockAddrUWSpecial', 3),
        ('FetchPatternBlockUWBoss', 3),
    ]
    hits = 0
    for func, bank_num in hooks:
        text, ok, err = _insert_fixed_bank_window_call(text, func, bank_num)
        if ok:
            hits += 1
        else:
            print(f"  WARNING: _patch_z03 -- {err}")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)

    print(f"  _patch_z03: fixed bank-window guards injected {hits}/{len(hooks)} hooks")


def _patch_z03_c_mode(path):
    """Stage 2d: strip code functions from z_03.asm, keep only data labels.
    Emit a TransferLevelPatternBlocks entry that jumps to the C shim."""
    import re

    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Find the first data label (LevelPatternBlockSrcAddrs) — everything before
    # the first `even` + data label is header/comments, keep it.
    # Find the last code instruction (rts at end of TransferPatternBlock_Bank3)
    # — everything between header and first data label AND between
    # TransferLevelPatternBlocks and the end of TransferPatternBlock_Bank3 is code.

    # Strategy: keep only lines that are:
    # 1. Header comments (before first label)
    # 2. Data labels + dc.b/dc.w/dc.l lines
    # 3. `even` directives before data labels
    # Replace all code with a single entry-point stub.

    # Identify code labels (functions we're replacing with C)
    code_labels = {
        'TransferLevelPatternBlocks', 'ResetPatternBlockIndex',
        'TransferLevelPatternBlocksUW', 'FetchPatternBlockAddrUW',
        'FetchPatternBlockInfoOW', 'FetchPatternBlockAddrUWSpecial',
        'FetchPatternBlockUWBoss', 'FetchPatternBlockSizeUW',
        'TransferPatternBlock_Bank3',
    }

    # Data labels (keep these + their dc.b/dc.w blocks)
    data_labels = {
        'LevelPatternBlockSrcAddrs', 'BossPatternBlockSrcAddrs',
        'PatternBlockSrcAddrsUW', 'PatternBlockSrcAddrsOW',
        'PatternBlockPpuAddrs', 'PatternBlockPpuAddrsExtra',
        'PatternBlockSizesOW', 'PatternBlockSizesUW',
        'PatternBlockUWBG', 'PatternBlockOWBG', 'PatternBlockOWSP',
        'PatternBlockUWSP358', 'PatternBlockUWSP469', 'PatternBlockUWSP',
        'PatternBlockUWSP127', 'PatternBlockUWSPBoss1257',
        'PatternBlockUWSPBoss3468', 'PatternBlockUWSPBoss9',
    }

    # Build output: header, then xdefs for data, then entry stub, then data blocks.
    out = []

    # Copy header (lines before first non-comment, non-blank label)
    header_end = 0
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped and not stripped.startswith(';') and not stripped.startswith(
                '; ') and ':' in stripped and not stripped.startswith('dc.'):
            header_end = i
            break
    out.extend(lines[:header_end])

    # Add xdefs for all data labels so C can reference them
    out.append('\n; Stage 2d: data-only mode (code ported to src/gen/z_03.c)\n')
    for lbl in sorted(data_labels):
        out.append(f'    xdef    {lbl}\n')
    out.append('\n')

    # Entry point stub
    out.append('    even\n')
    out.append('TransferLevelPatternBlocks:\n')
    out.append('    jmp     c_transfer_level_pattern_blocks\n')
    out.append('\n')

    # Now emit all data blocks. Walk through lines, identify data regions.
    in_data = False
    for i, line in enumerate(lines):
        stripped = line.strip()
        # Check if this line is a data label
        if ':' in stripped:
            label_match = re.match(r'^(\w+):', stripped)
            if label_match:
                lbl = label_match.group(1)
                if lbl in data_labels:
                    in_data = True
                    out.append(f'    even\n{lbl}:\n')
                    continue
                elif lbl in code_labels or lbl.startswith('_L_z03_') or lbl.startswith('__far_z_03'):
                    in_data = False
                    continue
                else:
                    # Unknown label inside data region — keep if in_data
                    if in_data:
                        out.append(line)
                    continue
        if in_data:
            if stripped.startswith('dc.') or stripped.startswith('; .INCBIN') or stripped == '':
                out.append(line)
            elif stripped == 'even':
                pass  # we add our own even before each label
            elif stripped.startswith(';'):
                out.append(line)
            else:
                # End of data region (hit code)
                in_data = False

    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(out)

    print(f"  _patch_z03: C-mode data-only emit (code -> src/gen/z_03.c)")


import re as _re_stub

def _stub_func(text, label, c_shim):
    """Replace a function body (from label: to next top-level label) with a jmp stub."""
    pat = _re_stub.compile(
        r'^(' + _re_stub.escape(label) + r':)\s*\n'
        r'(.*?)(?=^[A-Za-z]\w*:|\Z)',
        _re_stub.MULTILINE | _re_stub.DOTALL
    )
    m = pat.search(text)
    if m:
        stub = f"{label}:\n    jmp     {c_shim}\n\n"
        text = text[:m.start()] + stub + text[m.end():]
        print(f"  _stub_func: {label} -> {c_shim}")
    else:
        print(f"  WARNING: _stub_func -- {label} anchor not found")
    return text


def _patch_z04(path):
    """Post-process patches for z_04.asm — C function stubs."""
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()

    # --- Stage 4b batch 6: z_04 C function stubs ---
    text = _stub_func(text, 'HideSpritesOverLink', 'c_hide_sprites_over_link')

    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def _patch_z05(path):
    """Inject bank-window guards into room-layout ROM-pointer consumers (bank-5 pinned)."""
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()

    # ------------------------------------------------------------------
    # P34a: Convert z05 room-layout pointer tables to direct 32-bit labels.
    # ------------------------------------------------------------------
    p34_tables = [
        ('RoomLayoutsOWAddr', ['RoomLayoutsOW'], 1),
        ('ColumnHeapOWAddr', ['ColumnHeapOW0'], 1),
        ('SubroomLayoutAddrs', ['RoomLayoutOWCave0', 'RoomLayoutOWCave1', 'RoomLayoutUWCellar0', 'RoomLayoutUWCellar1'], 4),
        ('ColumnDirectoryUW', [f'ColumnHeapUW{i}' for i in range(10)], 10),
    ]
    p34_table_hits = 0
    for label, entries, expected in p34_tables:
        text, ok, err = _replace_addr_table_block(text, label, entries, expected_count=expected)
        if ok:
            p34_table_hits += 1
        else:
            print(f"  WARNING: _patch_z05 P34a -- {err}")
    if p34_table_hits:
        print(f"  _patch_z05 P34a: converted {p34_table_hits}/{len(p34_tables)} z05 pointer tables to dc.l")

    # ------------------------------------------------------------------
    # P34b: LayoutRoomOW room-layout base pointer transport -> A2 direct ROM ptr.
    # ------------------------------------------------------------------
    p34_lrow_header_old = (
        'LayoutRoomOW:\n'
        '    ; Load the address of room column directory in [$02:03].\n'
        '    ;\n'
        '    move.b  (RoomLayoutsOWAddr).l,D0\n'
        '    move.b  D0,($0002,A4)\n'
        '    move.b  (RoomLayoutsOWAddr+1).l,D0\n'
        '    move.b  D0,($0003,A4)\n'
        '    moveq   #0,D0\n'
        '    move.b  D0,($0006,A4)\n'
    )
    p34_lrow_header_new = (
        'LayoutRoomOW:\n'
        '    ; PATCH P34b: direct ROM base pointer for OW room-layout directory.\n'
        '    movea.l (RoomLayoutsOWAddr).l,A2\n'
        '    moveq   #0,D0\n'
        '    move.b  D0,($0006,A4)\n'
    )
    if p34_lrow_header_old in text:
        text = text.replace(p34_lrow_header_old, p34_lrow_header_new, 1)
        print("  _patch_z05 P34b: LayoutRoomOW base pointer -> A2 (dc.l)")
    else:
        print("  WARNING: _patch_z05 P34b -- LayoutRoomOW header anchor not found")

    p34_lrow_add_old = (
        '    ; Add ((unique room ID) * $10) to address in [$02:03]. Each unique room has $10 columns.\n'
        '    ;\n'
        '    lsl.b  #1,D0   ; ASL A\n'
        '    lsl.b  #1,D0   ; ASL A\n'
        '    move.b  ($0006,A4),D1\n'
        '    roxl.b  #1,D1   ; ROL $06\n'
        '    move.b  D1,($0006,A4)\n'
        '    lsl.b  #1,D0   ; ASL A\n'
        '    move.b  ($0006,A4),D1\n'
        '    roxl.b  #1,D1   ; ROL $06\n'
        '    move.b  D1,($0006,A4)\n'
        '    lsl.b  #1,D0   ; ASL A\n'
        '    move.b  ($0006,A4),D1\n'
        '    roxl.b  #1,D1   ; ROL $06\n'
        '    move.b  D1,($0006,A4)\n'
        '    move.b  ($0002,A4),D1\n'
        '    addx.b  D1,D0   ; ADC $02\n'
        '    move.b  D0,($0002,A4)\n'
        '    move.b  ($0006,A4),D0\n'
        '    move.b  ($0003,A4),D1\n'
        '    addx.b  D1,D0   ; ADC $03\n'
        '    move.b  D0,($0003,A4)\n'
    )
    p34_lrow_add_new = (
        '    ; PATCH P34b: advance A2 by (unique room ID * $10) bytes.\n'
        '    moveq   #0,D3\n'
        '    move.b  D0,D3\n'
        '    andi.w  #$003F,D3                  ; PATCH P34g: keep low 6-bit unique room ID\n'
        '    lsl.w   #4,D3\n'
        '    adda.w  D3,A2\n'
        '    move.l  A2,($00FF1102).l         ; PATCH P34f: cache OW layout base ptr\n'
    )
    if p34_lrow_add_old in text:
        text = text.replace(p34_lrow_add_old, p34_lrow_add_new, 1)
        print("  _patch_z05 P34b: LayoutRoomOW offset add -> A2 arithmetic")
    else:
        print("  WARNING: _patch_z05 P34b -- LayoutRoomOW offset-add anchor not found")

    # ------------------------------------------------------------------
    # P34c: SubroomLayoutAddrs transport -> A2 direct ROM ptr (dc.l).
    # ------------------------------------------------------------------
    p34_subroom_old = (
        'LayoutCaveAndAvanceSubmode:\n'
        '    moveq   #0,D2\n'
        '_anon_z05_147:\n'
        '    lea     (SubroomLayoutAddrs).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0002,A4)\n'
        '    lea     (SubroomLayoutAddrs+1).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0003,A4)\n'
        '    addq.b  #1,($0013,A4)\n'
        '    jmp     LayoutRoomOrCaveOW'
    )
    p34_subroom_new = (
        'LayoutCaveAndAvanceSubmode:\n'
        '    moveq   #0,D2\n'
        '_anon_z05_147:\n'
        '    add.w   D2,D2                       ; PATCH P34c: 2-byte -> 4-byte index\n'
        '    lea     (SubroomLayoutAddrs).l,A0\n'
        '    movea.l (A0,D2.W),A2                ; PATCH P34c: direct ROM ptr\n'
        '    move.l  A2,($00FF1102).l            ; PATCH P34f: cache subroom layout ptr\n'
        '    addq.b  #1,($0013,A4)\n'
        '    jmp     LayoutRoomOrCaveOW'
    )
    if p34_subroom_old in text:
        text = text.replace(p34_subroom_old, p34_subroom_new, 1)
        print("  _patch_z05 P34c: LayoutCaveAndAvanceSubmode -> A2 from dc.l")
    else:
        print("  WARNING: _patch_z05 P34c -- subroom anchor not found")

    # ------------------------------------------------------------------
    # P34d: LayoutRoomOrCaveOW reads room descriptors via A2 (direct ROM ptr).
    # ------------------------------------------------------------------
    p34_room_read_re = re.compile(
        r'^\s*move\.b\s+\(\$02,A4\),D1\s+; ptr lo\s*\n'
        r'^\s*move\.b\s+\(\$03,A4\),D4\s+; ptr hi\s*\n'
        r'^\s*andi\.w\s+#\$00FF,D1.*\n'
        r'^\s*lsl\.w\s+#8,D4\s*\n'
        r'^\s*or\.w\s+D1,D4.*\n'
        r'^\s*ext\.l\s+D4\s*\n'
        r'^\s*add\.l\s+#NES_RAM,D4.*\n'
        r'^\s*movea\.l\s+D4,A0\s*\n'
        r'^\s*move\.b\s+\(A0,D3\.W\),D0\s+; LDA \(\$nn\),Y\s*\n',
        re.MULTILINE,
    )
    lines = text.splitlines()
    fn_start = None
    fn_end = None
    for i, line in enumerate(lines):
        if line.strip() == 'LayoutRoomOrCaveOW:':
            fn_start = i
            break
    if fn_start is not None:
        fn_end = len(lines)
        for i in range(fn_start + 1, len(lines)):
            s = lines[i].strip()
            if s.endswith(':') and not s.startswith('_') and not s.startswith('.') and not s.startswith(';'):
                fn_end = i
                break
    room_read_hits = 0
    if fn_start is not None and fn_end is not None:
        block = '\n'.join(lines[fn_start:fn_end]) + '\n'
        block, room_read_hits = p34_room_read_re.subn(
            '    move.b  (A2,D3.W),D0     ; PATCH P34d: direct ROM read\n',
            block,
            count=2,
        )
        lines[fn_start:fn_end] = block.rstrip('\n').splitlines()
        text = '\n'.join(lines)
    if room_read_hits == 2:
        print("  _patch_z05 P34d: LayoutRoomOrCaveOW room-layout reads -> A2")
    else:
        print(f"  WARNING: _patch_z05 P34d -- expected 2 room-layout read anchors, got {room_read_hits}")

    # ------------------------------------------------------------------
    # P34f: OW descriptor read must be call-safe per column.
    # Cache base ptr in $FF1102, reload per column, keep descriptor reads
    # in-memory (NES parity) instead of caching in volatile D7.
    # ------------------------------------------------------------------
    p34f_desc_old = (
        '_L_z05_LayoutRoomOrCaveOW_LoopColumnOW:\n'
        '    moveq   #0,D3\n'
        '    move.b  ($0006,A4),D3\n'
        '    move.b  (A2,D3.W),D0     ; PATCH P34d: direct ROM read\n'
        '    andi.b #$F0,D0\n'
        '    lsr.b  #1,D0   ; LSR A\n'
        '    lsr.b  #1,D0   ; LSR A\n'
        '    lsr.b  #1,D0   ; LSR A\n'
        '    moveq   #0,D2\n'
        '    move.b  D0,D2\n'
        '    ; Load the column table address for this descriptor in [$04:05].\n'
        '    ;\n'
        '    lea     (ColumnDirectoryOW).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0004,A4)\n'
        '    lea     (ColumnDirectoryOW+1).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0005,A4)\n'
        '    move.b  (A2,D3.W),D0     ; PATCH P34d: direct ROM read\n'
        '    andi.b #$0F,D0\n'
    )
    p34f_desc_new = (
        '_L_z05_LayoutRoomOrCaveOW_LoopColumnOW:\n'
        '    moveq   #0,D3\n'
        '    move.b  ($0006,A4),D3\n'
        '    movea.l ($00FF1102).l,A2            ; PATCH P34f: reload call-safe layout ptr\n'
        '    move.b  (A2,D3.W),D0                ; PATCH P34f: descriptor read (NES parity)\n'
        '    andi.b #$F0,D0\n'
        '    lsr.b  #1,D0   ; LSR A\n'
        '    lsr.b  #1,D0   ; LSR A\n'
        '    lsr.b  #1,D0   ; LSR A\n'
        '    moveq   #0,D2\n'
        '    move.b  D0,D2\n'
        '    ; Load the column table address for this descriptor in [$04:05].\n'
        '    ;\n'
        '    lea     (ColumnDirectoryOW).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0004,A4)\n'
        '    lea     (ColumnDirectoryOW+1).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0005,A4)\n'
        '    move.b  (A2,D3.W),D0                ; PATCH P34f: descriptor reread for low nibble\n'
        '    andi.b #$0F,D0\n'
    )
    if p34f_desc_old in text:
        text = text.replace(p34f_desc_old, p34f_desc_new, 1)
        print("  _patch_z05 P34f: call-safe cached ptr + in-memory descriptor reread")
    else:
        print("  WARNING: _patch_z05 P34f -- descriptor rewrite anchor not found")

    # ------------------------------------------------------------------
    # P34h: OW column-source transport/read path -> direct 32-bit pointer.
    # Keep pointer call-safe via $FF1106 cache.
    # ------------------------------------------------------------------
    p34h_table_old = (
        'ColumnHeapOWAddr:\n'
        '    dc.l    ColumnHeapOW0\n'
        '\n'
        '    even\n'
        'WallTileList:\n'
    )
    p34h_table_new = (
        'ColumnHeapOWAddr:\n'
        '    dc.l    ColumnHeapOW0\n'
        '\n'
        '    even\n'
        'ColumnDirectoryOWPtrs:\n'
        '    dc.l    ColumnHeapOW0\n'
        '    dc.l    ColumnHeapOW1\n'
        '    dc.l    ColumnHeapOW2\n'
        '    dc.l    ColumnHeapOW3\n'
        '    dc.l    ColumnHeapOW4\n'
        '    dc.l    ColumnHeapOW5\n'
        '    dc.l    ColumnHeapOW6\n'
        '    dc.l    ColumnHeapOW7\n'
        '    dc.l    ColumnHeapOW8\n'
        '    dc.l    ColumnHeapOW9\n'
        '    dc.l    ColumnHeapOWA\n'
        '    dc.l    ColumnHeapOWB\n'
        '    dc.l    ColumnHeapOWC\n'
        '    dc.l    ColumnHeapOWD\n'
        '    dc.l    ColumnHeapOWE\n'
        '    dc.l    ColumnHeapOWF\n'
        '\n'
        '    even\n'
        'WallTileList:\n'
    )
    if p34h_table_old in text:
        text = text.replace(p34h_table_old, p34h_table_new, 1)
        print("  _patch_z05 P34h: ColumnDirectoryOWPtrs (dc.l) injected")
    else:
        print("  WARNING: _patch_z05 P34h -- ColumnDirectoryOWPtrs anchor not found")

    p34h_dir_load_old = (
        '    lea     (ColumnDirectoryOW).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0004,A4)\n'
        '    lea     (ColumnDirectoryOW+1).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0005,A4)\n'
    )
    p34h_dir_load_new = (
        '    add.w   D2,D2                       ; PATCH P34h: 2-byte -> 4-byte index\n'
        '    lea     (ColumnDirectoryOWPtrs).l,A0\n'
        '    movea.l (A0,D2.W),A3                ; PATCH P34h: direct OW column ptr\n'
        '    move.l  A3,($00FF1106).l            ; PATCH P34h: cache call-safe OW column ptr\n'
    )
    text, ok, err = _replace_in_function_block(
        text,
        'LayoutRoomOrCaveOW',
        p34h_dir_load_old,
        p34h_dir_load_new,
        count=1,
    )
    if ok:
        print("  _patch_z05 P34h: OW column-directory transport -> direct ptr")
    else:
        print(f"  WARNING: _patch_z05 P34h -- {err}")

    lines = text.splitlines()
    fn_start = None
    fn_end = None
    for i, line in enumerate(lines):
        if line.strip() == 'LayoutRoomOrCaveOW:':
            fn_start = i
            break
    if fn_start is not None:
        fn_end = len(lines)
        for i in range(fn_start + 1, len(lines)):
            s = lines[i].strip()
            if s.endswith(':') and not s.startswith('_') and not s.startswith('.') and not s.startswith(';'):
                fn_end = i
                break
    if fn_start is not None and fn_end is not None:
        block = '\n'.join(lines[fn_start:fn_end]) + '\n'

        p34h_col_read_re = re.compile(
            r'^\s*move\.b\s+\(\$04,A4\),D1\s+; ptr lo\s*\n'
            r'^\s*move\.b\s+\(\$05,A4\),D4\s+; ptr hi\s*\n'
            r'^\s*andi\.w\s+#\$00FF,D1.*\n'
            r'^\s*lsl\.w\s+#8,D4\s*\n'
            r'^\s*or\.w\s+D1,D4.*\n'
            r'^\s*ext\.l\s+D4\s*\n'
            r'^\s*add\.l\s+#NES_RAM,D4.*\n'
            r'^\s*movea\.l\s+D4,A0\s*\n'
            r'^\s*move\.b\s+\(A0,D3\.W\),D0\s+; LDA \(\$nn\),Y\s*\n',
            re.MULTILINE,
        )
        block, p34h_read_hits = p34h_col_read_re.subn(
            '    movea.l ($00FF1106).l,A3            ; PATCH P34h: reload OW column ptr\n'
            '    move.b  (A3,D3.W),D0                ; PATCH P34h: direct OW column read\n',
            block,
            count=3,
        )
        if p34h_read_hits == 3:
            print("  _patch_z05 P34h: OW column reads -> direct ptr")
        else:
            print(f"  WARNING: _patch_z05 P34h -- expected 3 OW read anchors, got {p34h_read_hits}")

        p34h_add_to_col_re = re.compile(
            r'^\s*move\.b\s+D3,D0(?:\s*;[^\n]*)?\s*\n'
            r'^\s*(?:bsr|jsr)\s+AddToInt16At4(?:\s*;[^\n]*)?\s*\n',
            re.MULTILINE,
        )
        block, p34h_add_hits = p34h_add_to_col_re.subn(
            '    movea.l ($00FF1106).l,A3            ; PATCH P34h: reload OW column ptr\n'
            '    adda.w  D3,A3                       ; PATCH P34h: advance to found column\n'
            '    move.l  A3,($00FF1106).l            ; PATCH P34h: store updated ptr\n',
            block,
            count=1,
        )
        if p34h_add_hits == 1:
            print("  _patch_z05 P34h: column-start pointer advance -> A3")
        else:
            print(f"  WARNING: _patch_z05 P34h -- expected AddToInt16At4 anchor, got {p34h_add_hits}")

        p34h_add1_re = re.compile(
            r'^\s*(?:bsr|jsr)\s+Add1ToInt16At4(?:\s*;[^\n]*)?\s*\n',
            re.MULTILINE,
        )
        block, p34h_add1_hits = p34h_add1_re.subn(
            '    movea.l ($00FF1106).l,A3            ; PATCH P34h: reload OW column ptr\n'
            '    addq.l  #1,A3                       ; PATCH P34h: advance to next column byte\n'
            '    move.l  A3,($00FF1106).l            ; PATCH P34h: store updated ptr\n',
            block,
            count=1,
        )
        if p34h_add1_hits == 1:
            print("  _patch_z05 P34h: per-square pointer increment -> A3")
        else:
            print(f"  WARNING: _patch_z05 P34h -- expected Add1ToInt16At4 anchor, got {p34h_add1_hits}")

        lines[fn_start:fn_end] = block.rstrip('\n').splitlines()
        text = '\n'.join(lines)
    else:
        print("  WARNING: _patch_z05 P34h -- LayoutRoomOrCaveOW function block not found")

    # ------------------------------------------------------------------
    # P34e: LayoutUWFloor ColumnDirectoryUW consumer -> A3 direct ROM ptr.
    # ------------------------------------------------------------------
    p34_uw_col_dir_old = (
        '    lea     (ColumnDirectoryUW).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0004,A4)\n'
        '    lea     (ColumnDirectoryUW+1).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0005,A4)\n'
    )
    p34_uw_col_dir_new = (
        '    add.w   D2,D2                       ; PATCH P34e: 2-byte -> 4-byte index\n'
        '    lea     (ColumnDirectoryUW).l,A0\n'
        '    movea.l (A0,D2.W),A3                ; PATCH P34e: direct ROM ptr\n'
    )
    if p34_uw_col_dir_old in text:
        text = text.replace(p34_uw_col_dir_old, p34_uw_col_dir_new, 1)
        print("  _patch_z05 P34e: LayoutUWFloor ColumnDirectoryUW -> A3 (dc.l)")
    else:
        print("  WARNING: _patch_z05 P34e -- ColumnDirectoryUW consumer anchor not found")

    p34_uw_col_read_re = re.compile(
        r'^\s*move\.b\s+\(\$04,A4\),D1\s+; ptr lo\s*\n'
        r'^\s*move\.b\s+\(\$05,A4\),D4\s+; ptr hi\s*\n'
        r'^\s*andi\.w\s+#\$00FF,D1.*\n'
        r'^\s*lsl\.w\s+#8,D4\s*\n'
        r'^\s*or\.w\s+D1,D4.*\n'
        r'^\s*ext\.l\s+D4\s*\n'
        r'^\s*add\.l\s+#NES_RAM,D4.*\n'
        r'^\s*movea\.l\s+D4,A0\s*\n'
        r'^\s*move\.b\s+\(A0,D3\.W\),D0\s+; LDA \(\$nn\),Y\s*\n',
        re.MULTILINE,
    )
    lines = text.splitlines()
    fn_start = None
    fn_end = None
    for i, line in enumerate(lines):
        if line.strip() == 'LayoutUWFloor:':
            fn_start = i
            break
    if fn_start is not None:
        fn_end = len(lines)
        for i in range(fn_start + 1, len(lines)):
            s = lines[i].strip()
            if s.endswith(':') and not s.startswith('_') and not s.startswith('.') and not s.startswith(';'):
                fn_end = i
                break
    uw_hits = 0
    if fn_start is not None and fn_end is not None:
        block = '\n'.join(lines[fn_start:fn_end]) + '\n'
        block, uw_hits = p34_uw_col_read_re.subn(
            '    move.b  (A3,D3.W),D0     ; PATCH P34e: direct ROM read\n',
            block,
            count=3,
        )
        lines[fn_start:fn_end] = block.rstrip('\n').splitlines()
        text = '\n'.join(lines)
    if uw_hits == 3:
        print("  _patch_z05 P34e: LayoutUWFloor column reads -> A3")
    else:
        print(f"  WARNING: _patch_z05 P34e -- expected 3 LayoutUWFloor column-read anchors, got {uw_hits}")

    # ------------------------------------------------------------------
    # P35a/P35b: OW workbuf pointer closure.
    # Source bytes are already parity-correct; remaining divergence is in
    # workbuf decode/write lifetime. For OW room layout only, cache a direct
    # 32-bit workbuf pointer in $FF110A and route writes through an OW-only
    # helper that writes tiles at offsets +0,+1,+$16,+$17. This removes
    # mixed 16-bit AddToInt16At0 / ($00:$01) transport from the OW room-load
    # path while leaving UW and dynamic square writers on the original code.
    # ------------------------------------------------------------------
    p35_init_old = (
        '    move.b  (NES_SRAM+$0BB0).l,D0\n'
        '    move.b  D0,($0009,A4)\n'
        '    jsr     FetchTileMapAddr\n'
        '    ; For each column in room, indexed by [06]:\n'
    )
    p35_init_new = (
        '    move.b  (NES_SRAM+$0BB0).l,D0\n'
        '    move.b  D0,($0009,A4)\n'
        '    jsr     FetchTileMapAddr\n'
        '    move.b  ($00,A4),D1                    ; PATCH P35a: workbuf ptr lo\n'
        '    move.b  ($01,A4),D4                    ; PATCH P35a: workbuf ptr hi\n'
        '    andi.w  #$00FF,D1\n'
        '    lsl.w   #8,D4\n'
        '    or.w    D1,D4\n'
        '    ext.l   D4\n'
        '    add.l   #NES_RAM,D4\n'
        '    move.l  D4,($00FF110A).l              ; PATCH P35a: cached OW workbuf ptr\n'
        '    ; For each column in room, indexed by [06]:\n'
    )
    if p35_init_old in text:
        text = text.replace(p35_init_old, p35_init_new, 1)
        print("  _patch_z05 P35a: cached OW workbuf ptr init")
    else:
        p35_init_re = re.compile(
            r'(\s*move\.b\s+\(NES_SRAM\+\$0BB0\)\.l,D0\s*\n'
            r'\s*move\.b\s+D0,\(\$0009,A4\)\s*\n'
            r'\s*(?:bsr|jsr)\s+FetchTileMapAddr\s*\n)',
            re.MULTILINE,
        )
        text, p35_init_hits = p35_init_re.subn(
            r'\1'
            + '    move.b  ($00,A4),D1                    ; PATCH P35a: workbuf ptr lo\n'
            + '    move.b  ($01,A4),D4                    ; PATCH P35a: workbuf ptr hi\n'
            + '    andi.w  #$00FF,D1\n'
            + '    lsl.w   #8,D4\n'
            + '    or.w    D1,D4\n'
            + '    ext.l   D4\n'
            + '    add.l   #NES_RAM,D4\n'
            + '    move.l  D4,($00FF110A).l              ; PATCH P35a: cached OW workbuf ptr\n',
            text,
            count=1,
        )
        if p35_init_hits == 1:
            print("  _patch_z05 P35a: cached OW workbuf ptr init (regex)")
        else:
            print("  WARNING: _patch_z05 P35a -- workbuf init anchor not found")

    p35_square_old = (
        '    jsr     CheckTileObject\n'
        '    moveq   #0,D3\n'
        '    jsr     WriteSquareOW\n'
        '    moveq   #2,D0\n'
        '    jsr     AddToInt16At0\n'
    )
    p35_square_new = (
        '    jsr     CheckTileObject\n'
        '    jsr     WriteSquareOW_P35             ; PATCH P35b: OW direct workbuf write\n'
        '    movea.l ($00FF110A).l,A1              ; PATCH P35a: advance cached OW workbuf ptr\n'
        '    addq.l  #2,A1\n'
        '    move.l  A1,($00FF110A).l\n'
        '    move.l  A1,D4\n'
        '    sub.l   #NES_RAM,D4\n'
        '    move.b  D4,($0000,A4)\n'
        '    lsr.l   #8,D4\n'
        '    move.b  D4,($0001,A4)\n'
    )
    if p35_square_old in text:
        text = text.replace(p35_square_old, p35_square_new, 1)
        print("  _patch_z05 P35a/P35b: per-square OW workbuf advance via cached ptr")
    else:
        p35_square_re = re.compile(
            r'(\s*(?:bsr|jsr)\s+CheckTileObject\s*\n'
            r'\s*moveq\s+#0,D3\s*\n'
            r'\s*(?:bsr|jsr)\s+WriteSquareOW\s*\n'
            r'\s*moveq\s+#2,D0\s*\n'
            r'\s*(?:bsr|jsr)\s+AddToInt16At0\s*\n)',
            re.MULTILINE,
        )
        text, p35_square_hits = p35_square_re.subn(
            '    jsr     CheckTileObject\n'
            '    jsr     WriteSquareOW_P35             ; PATCH P35b: OW direct workbuf write\n'
            '    movea.l ($00FF110A).l,A1              ; PATCH P35a: advance cached OW workbuf ptr\n'
            '    addq.l  #2,A1\n'
            '    move.l  A1,($00FF110A).l\n'
            '    move.l  A1,D4\n'
            '    sub.l   #NES_RAM,D4\n'
            '    move.b  D4,($0000,A4)\n'
            '    lsr.l   #8,D4\n'
            '    move.b  D4,($0001,A4)\n',
            text,
            count=1,
        )
        if p35_square_hits == 1:
            print("  _patch_z05 P35a/P35b: per-square OW workbuf advance via cached ptr (regex)")
        else:
            print("  WARNING: _patch_z05 P35a/P35b -- per-square anchor not found")

    p35_col_old = (
        '    ; At the end of a column, we\'ve reached the top of the next one.\n'
        '    ; Move one more column over to get to the next square column.\n'
        '    moveq   #22,D0\n'
        '    jsr     AddToInt16At0\n'
    )
    p35_col_new = (
        '    ; At the end of a column, we\'ve reached the top of the next one.\n'
        '    ; Move one more column over to get to the next square column.\n'
        '    movea.l ($00FF110A).l,A1              ; PATCH P35a: end-column OW workbuf advance\n'
        '    adda.w  #$0016,A1\n'
        '    move.l  A1,($00FF110A).l\n'
        '    move.l  A1,D4\n'
        '    sub.l   #NES_RAM,D4\n'
        '    move.b  D4,($0000,A4)\n'
        '    lsr.l   #8,D4\n'
        '    move.b  D4,($0001,A4)\n'
    )
    if p35_col_old in text:
        text = text.replace(p35_col_old, p35_col_new, 1)
        print("  _patch_z05 P35a: end-column OW workbuf advance via cached ptr")
    else:
        p35_col_re = re.compile(
            r'(\s*;\s+At the end of a column, we\'ve reached the top of the next one\.\s*\n'
            r'\s*;\s+Move one more column over to get to the next square column\.\s*\n'
            r'\s*moveq\s+#22,D0\s*\n'
            r'\s*(?:bsr|jsr)\s+AddToInt16At0\s*\n)',
            re.MULTILINE,
        )
        text, p35_col_hits = p35_col_re.subn(
            '    ; At the end of a column, we\'ve reached the top of the next one.\n'
            '    ; Move one more column over to get to the next square column.\n'
            '    movea.l ($00FF110A).l,A1              ; PATCH P35a: end-column OW workbuf advance\n'
            '    adda.w  #$0016,A1\n'
            '    move.l  A1,($00FF110A).l\n'
            '    move.l  A1,D4\n'
            '    sub.l   #NES_RAM,D4\n'
            '    move.b  D4,($0000,A4)\n'
            '    lsr.l   #8,D4\n'
            '    move.b  D4,($0001,A4)\n',
            text,
            count=1,
        )
        if p35_col_hits == 1:
            print("  _patch_z05 P35a: end-column OW workbuf advance via cached ptr (regex)")
        else:
            print("  WARNING: _patch_z05 P35a -- end-column anchor not found")

    p35_helper_anchor = (
        '; Params:\n'
        '; A: primary square\n'
        '; Y: offset from [$00:01]\n'
        '; [$0D]: square index\n'
        '; [$00:01]: pointer to play area\n'
        ';\n'
        ';\n'
        '; Get square index.\n'
        '    even\n'
        'WriteSquareOW:\n'
    )
    p35_helper_insert = (
        '; Params:\n'
        '; A: primary square\n'
        '; PATCH P35b: OW-only direct workbuf writer using cached long ptr at\n'
        '; $FF110A. Callers keep source/decode semantics unchanged and only swap\n'
        '; write transport.\n'
        '    even\n'
        'WriteSquareOW_P35:\n'
        '    moveq   #0,D2\n'
        '    move.b  ($000D,A4),D2\n'
        '    movea.l ($00FF110A).l,A1\n'
        '    cmpi.b  #$10,D2\n'
        '    bcs.s   _L_z05_WriteSquareOW_P35_Type3\n'
        '    moveq   #0,D2\n'
        '    move.b  D0,D2\n'
        '    move.b  D2,($0000,A1)\n'
        '    addq.b  #1,D2\n'
        '    move.b  D2,($0001,A1)\n'
        '    addq.b  #1,D2\n'
        '    move.b  D2,($0016,A1)\n'
        '    addq.b  #1,D2\n'
        '    move.b  D2,($0017,A1)\n'
        '    rts\n'
        '\n'
        '    even\n'
        '_L_z05_WriteSquareOW_P35_Type3:\n'
        '    move.b  D2,D0\n'
        '    lsl.b   #1,D0\n'
        '    lsl.b   #1,D0\n'
        '    moveq   #0,D2\n'
        '    move.b  D0,D2\n'
        '    lea     (SecondarySquaresOW).l,A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0000,A1)\n'
        '    addq.b  #1,D2\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0001,A1)\n'
        '    addq.b  #1,D2\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0016,A1)\n'
        '    addq.b  #1,D2\n'
        '    move.b  (A0,D2.W),D0\n'
        '    move.b  D0,($0017,A1)\n'
        '    rts\n'
        '\n'
        '    even\n'
        'WriteSquareOW:\n'
    )
    if p35_helper_anchor in text:
        text = text.replace(p35_helper_anchor, p35_helper_insert, 1)
        print("  _patch_z05 P35b: WriteSquareOW_P35 helper inserted")
    else:
        print("  WARNING: _patch_z05 P35b -- helper anchor not found")

    # ------------------------------------------------------------------
    # P36: producer-side transfer pointer closure.
    # Room decode is already stable. Remaining room77 divergence appears in
    # the dynamic transfer producer path, where CopyColumnToTileBuf /
    # CopyRowToTileBuf still rebuild and walk 16-bit NES pointers through
    # AddToInt16At0/Add1ToInt16At0. Replace those inner loops with direct
    # long-address walks over the playmap in RAM.
    # ------------------------------------------------------------------
    p36_copy_column_block = (
        'CopyColumnToTileBuf:\n'
        '    moveq   #26,D0\n'
        '    move.b  D0,($0000,A4)\n'
        '    moveq   #101,D0\n'
        '    move.b  D0,($0001,A4)\n'
        '    moveq   #0,D2\n'
        '    move.b  ($00E8,A4),D2\n'
        '    subq.b  #1,D2\n'
        '    move.b  D2,D0\n'
        '    moveq   #0,D3\n'
        '    move.b  ($0301,A4),D3\n'
        '    lea     ($0303,A4),A0\n'
        '    move.b  D0,(A0,D3.W)\n'
        '    moveq   #33,D0\n'
        '    lea     ($0302,A4),A0\n'
        '    move.b  D0,(A0,D3.W)\n'
        '    movea.l #NES_RAM+$651A,A1            ; PATCH P36: direct playmap base\n'
        '    even\n'
        '_L_z05_CopyColumnToTileBuf_AdvanceCol:\n'
        '    adda.w  #$0016,A1                    ; PATCH P36: next source column\n'
        '    subq.b  #1,D2\n'
        '    bpl  _L_z05_CopyColumnToTileBuf_AdvanceCol\n'
        '    move.b  #$96,D0\n'
        '    lea     ($0304,A4),A0\n'
        '    move.b  D0,(A0,D3.W)\n'
        '    move.b  D2,D0\n'
        '    lea     ($031B,A4),A0\n'
        '    move.b  D0,(A0,D3.W)\n'
        '    moveq   #0,D2\n'
        '    move.b  D3,D2\n'
        '    moveq   #22,D5\n'
        '    lea     ($0305,A4),A0\n'
        '    even\n'
        '_L_z05_CopyColumnToTileBuf_Copy:\n'
        '    move.b  (A1)+,D0                     ; PATCH P36: direct source walk\n'
        '    move.b  D0,(A0,D2.W)\n'
        '    addq.b  #1,D2\n'
        '    subq.b  #1,D5\n'
        '    bne  _L_z05_CopyColumnToTileBuf_Copy\n'
        '    addq.b  #1,D2\n'
        '    addq.b  #1,D2\n'
        '    addq.b  #1,D2\n'
        '    move.b  D2,($0301,A4)\n'
        '    move.l  A1,D4                        ; PATCH P36: keep ptr mirror coherent\n'
        '    sub.l   #NES_RAM,D4\n'
        '    move.b  D4,($0000,A4)\n'
        '    lsr.l   #8,D4\n'
        '    move.b  D4,($0001,A4)\n'
        '    rts\n'
        '\n'
        '    even\n'
    )
    text, ok, err = _replace_global_block(text, 'CopyColumnToTileBuf', 'CopyRowToTileBuf', p36_copy_column_block)
    if ok:
        print("  _patch_z05 P36a: CopyColumnToTileBuf -> direct long source walk")
    else:
        print(f"  WARNING: _patch_z05 P36a -- {err}")

    p36_copy_row_block = (
        'CopyRowToTileBuf:\n'
        '    ; Put in 00:01 the address of the\n'
        '    ; first tile of current row in play area.\n'
        '    moveq   #101,D0\n'
        '    move.b  D0,($0001,A4)\n'
        '    move.b  ($00E9,A4),D0\n'
        '    moveq   #0,D2\n'
        '    move.b  D0,D2\n'
        '    andi    #$EE,CCR  ; CLC: clear C+X\n'
        '    move.b  #$30,D1\n'
        '    addx.b  D1,D0   ; ADC #$30 (X flag = 6502 C)\n'
        '    move.b  D0,($0000,A4)\n'
        '    bcc  _L_z05_CopyRowToTileBuf_RowAddrReady\n'
        '    addq.b  #1,($0001,A4)\n'
        '_L_z05_CopyRowToTileBuf_RowAddrReady:\n'
        '    ; Indicate the target VRAM address:\n'
        '    ; $2100 + (CurRow * $20)\n'
        '    moveq   #32,D0\n'
        '    move.b  D0,($0302,A4)\n'
        '    move.b  #$E0,D0\n'
        '    move.b  D0,($0303,A4)\n'
        '    even\n'
        '_L_z05_CopyRowToTileBuf_Add20H_P36:\n'
        '    move.b  ($0303,A4),D0\n'
        '    andi    #$EE,CCR  ; CLC: clear C+X\n'
        '    move.b  #$20,D1\n'
        '    addx.b  D1,D0   ; ADC #$20 (X flag = 6502 C)\n'
        '    move.b  D0,($0303,A4)\n'
        '    bcc  _L_z05_CopyRowToTileBuf_Add20CarryDone_P36\n'
        '    addq.b  #1,($0302,A4)\n'
        '_L_z05_CopyRowToTileBuf_Add20CarryDone_P36:\n'
        '    subq.b  #1,D2\n'
        '    bpl  _L_z05_CopyRowToTileBuf_Add20H_P36\n'
        '    moveq   #32,D0\n'
        '    move.b  D0,($0304,A4)\n'
        '    move.b  D2,($0325,A4)\n'
        '    ; Copy a row from column map in RAM to tile buf.\n'
        '    ;\n'
        '    movea.l #NES_RAM+$6530,A1            ; PATCH P36: playmap row base\n'
        '    moveq   #0,D4\n'
        '    move.b  ($00E9,A4),D4\n'
        '    adda.w  D4,A1                        ; PATCH P36: row offset\n'
        '    moveq   #0,D2\n'
        '    lea     ($0305,A4),A0\n'
        '    even\n'
        '_L_z05_CopyRowToTileBuf_Copy_P36:\n'
        '    move.b  (A1),D0                      ; PATCH P36: direct source walk\n'
        '    move.b  D0,(A0,D2.W)\n'
        '    adda.w  #$0016,A1                    ; PATCH P36: next column same row\n'
        '    addq.b  #1,D2\n'
        '    cmpi.b  #$20,D2\n'
        '    bcs  _L_z05_CopyRowToTileBuf_Copy_P36\n'
        '    moveq   #35,D0\n'
        '    move.b  D0,($0301,A4)\n'
        '    move.l  A1,D4                        ; PATCH P36: keep ptr mirror coherent\n'
        '    sub.l   #NES_RAM,D4\n'
        '    move.b  D4,($0000,A4)\n'
        '    lsr.l   #8,D4\n'
        '    move.b  D4,($0001,A4)\n'
        '    rts\n'
        '\n'
        '    even\n'
    )
    text, ok, err = _replace_global_block(text, 'CopyRowToTileBuf', 'TileObjectTypes', p36_copy_row_block)
    if ok:
        print("  _patch_z05 P36b: CopyRowToTileBuf -> direct long source walk")
    else:
        print(f"  WARNING: _patch_z05 P36b -- {err}")

    hooks = [
        ('LayoutRoomOW', 5),
        ('LayoutRoomOrCaveOW', 5),
        ('PatchColumnDirectoryForCellar', 5),
        ('LayoutCaveAndAvanceSubmode', 5),
        ('LayoutUWFloor', 5),
    ]
    hits = 0
    for func, bank_num in hooks:
        text, ok, err = _insert_fixed_bank_window_call(text, func, bank_num)
        if ok:
            hits += 1
        else:
            print(f"  WARNING: _patch_z05 -- {err}")

    # P33c: every FetchTileMapAddr call in bank 5 is followed by ROM-pointer
    # deref work. Re-pin bank 5 after each call.
    fetch_re = re.compile(r'(^\s*(?:bsr|jsr)\s+FetchTileMapAddr\b[^\n]*\n)', re.MULTILINE)

    def _p33c_repl(match):
        return (
            match.group(1)
            + '    moveq   #5,D0\n'
            + '    jsr     _copy_bank_to_window   ; PATCH P33c: re-pin bank 5 after FetchTileMapAddr\n'
        )

    text, p33c_hits = fetch_re.subn(_p33c_repl, text)
    if p33c_hits > 0:
        print(f"  _patch_z05 P33c: re-pin bank 5 after FetchTileMapAddr ({p33c_hits} sites)")
    else:
        print("  WARNING: _patch_z05 P33c -- no FetchTileMapAddr sites patched")

    # ------------------------------------------------------------------
    # P34i: Extend ClearRam tail loop from $00-$EF to $00-$FF so controller
    # state bytes $F8/$F9/$FA/$FB get zero-init at boot. Without this the
    # newly-pressed mask $F8 = new & ~prev sees stale $FA bits -> Start
    # never registers as "newly pressed" (ModeE stuck) and T34 Left-bit
    # miss at t=211. Reference NES has `LDY #$EF` literally; M68K port
    # has no such constraint since zeropage has no special hardware.
    # ------------------------------------------------------------------
    p34i_old = 'move.b  #$EF,D3\n_anon_z05_192:'
    p34i_new = 'move.b  #$FF,D3   ; PATCH P34i: clear $00-$FF (covers ctrl state $F8/$FA)\n_anon_z05_192:'
    if p34i_old in text:
        text = text.replace(p34i_old, p34i_new, 1)
        print("  _patch_z05 P34i: ClearRam extended to $00-$FF (ctrl state $F8/$FA)")
    else:
        print("  WARNING: _patch_z05 P34i -- ClearRam anchor not found")

    # ------------------------------------------------------------------
    # P41: Remove `even` directives between consecutive ColumnHeapOWn
    # labels. The column decoder reads heap bytes sequentially; when a
    # column's descriptors cross the boundary into the next heap
    # segment the decoder consumes whatever byte is there. A single
    # $00 alignment byte injected by `even` is interpreted as a bogus
    # descriptor, producing a 1-metatile shift in any affected room.
    # Verified on room $75 ($00 at ROM offset $4317D between
    # ColumnHeapOW0 and ColumnHeapOW1).
    # ------------------------------------------------------------------
    _p41_pattern = re.compile(r'    even\n(ColumnHeapOW[0-9A-F]:\n)')
    text, _p41_n = _p41_pattern.subn(r'\1', text)
    if _p41_n:
        print(f"  _patch_z05 P41: stripped {_p41_n} `even` directives between ColumnHeapOWn blocks")
    else:
        print("  WARNING: _patch_z05 P41 -- no ColumnHeapOWn `even` directives found")

    # ------------------------------------------------------------------
    # P38: Restore missing JSR CheckTileObject in LayoutRoomOrCaveOW.
    # The transpiler absorbs the "JSR CheckTileObject" line following a
    # PLA with a long comment into the PLA's emitted comment string,
    # producing:
    #     move.b  (A5)+,D0  ; PLA    jsr     CheckTileObject
    # instead of the intended two-instruction sequence:
    #     move.b  (A5)+,D0  ; PLA
    #     jsr     CheckTileObject
    #
    # CheckTileObject swaps the primary square from the $E5-$EA range
    # (tree/rockwall/armos) to the corresponding cave-entrance tile
    # (primary $C8..$D8) when a room's secret has been found. Without
    # the call, rock-wall ($E6) primaries never get rewritten to the
    # cave-stair ($D8) primary, and room76/77 parity reports see
    # row-of-$E6-tiles where NES emits row-of-$D8-tiles.
    # See patches/z_05_patch_P38_check_tile_object.md.
    # ------------------------------------------------------------------
    p38_old = '    move.b  (A5)+,D0  ; PLA    jsr     CheckTileObject'
    p38_new = '    move.b  (A5)+,D0  ; PLA\n    jsr     CheckTileObject   ; PATCH P38: restore dropped JSR'
    if p38_old in text:
        text = text.replace(p38_old, p38_new, 1)
        print("  _patch_z05 P38: restored JSR CheckTileObject in LayoutRoomOrCaveOW")
    else:
        print("  WARNING: _patch_z05 P38 -- CheckTileObject PLA-comment anchor not found")

    # ------------------------------------------------------------------
    # P39: Fix ObjListAddrs inline table byte shift.
    #
    # reference/aldonunez/dat/ObjListAddrs.inc was extracted from NES bank
    # 5 including a stray $27 byte at the start (from the preceding data
    # table) AND ~1000 trailing code bytes. The stray $27 shifts every
    # 16-bit address entry by 1 byte, causing the 6502 indirect pointer
    # reader to read bytes as (HI, LO) instead of (LO, HI). On room $75
    # the monster list lookup resolves to $8F86 (which is 6502 code) instead
    # of $868F (ObjList05). The "code" bytes ($0C $F0 $11 $A5 $70 $D5)
    # include types >= $6A which trigger InitCave, writing the cave
    # dialog "IT'S DANGEROUS TO GO ALONE, TAKE THIS" into the nametable
    # on top of the overworld.
    #
    # Fix: rewrite the first 60 bytes of the inline table (4 dc.b lines,
    # 16+16+16+12 of which are table bytes, remaining 4 bytes of line 4
    # preserved). Total block size unchanged, so subsequent label
    # addresses (InitMode4 etc.) don't shift.
    # ------------------------------------------------------------------
    p39_old = (
        '    dc.b    $27, $76, $86, $7B, $86, $7F, $86, $85, $86, $89, $86, $8F, $86, $95, $86, $9A\n'
        '    dc.b    $86, $9E, $86, $A3, $86, $A8, $86, $AE, $86, $B6, $86, $BE, $86, $C6, $86, $CE\n'
        '    dc.b    $86, $D6, $86, $DE, $86, $E4, $86, $EC, $86, $F4, $86, $FC, $86, $04, $87, $0A\n'
        '    dc.b    $87, $12, $87, $1A, $87, $1F, $87, $27, $87, $2F, $87, $37, $87, $A6, $13, $F0\n'
    )
    p39_new = (
        '    ; PATCH P39: stray $27 byte dropped (was upstream extraction bleed);\n'
        '    ; table now contains 30 valid (lo,hi) entries pointing to ObjList00..29 in bank 5.\n'
        '    ; Total block size preserved (last 4 bytes of 4th line kept as before).\n'
        '    dc.b    $76, $86, $7B, $86, $7F, $86, $85, $86, $89, $86, $8F, $86, $95, $86, $9A, $86\n'
        '    dc.b    $9E, $86, $A3, $86, $A8, $86, $AE, $86, $B6, $86, $BE, $86, $C6, $86, $CE, $86\n'
        '    dc.b    $D6, $86, $DE, $86, $E4, $86, $EC, $86, $F4, $86, $FC, $86, $04, $87, $0A, $87\n'
        '    dc.b    $12, $87, $1A, $87, $1F, $87, $27, $87, $2F, $87, $37, $87, $87, $A6, $13, $F0\n'
    )
    if p39_old in text:
        text = text.replace(p39_old, p39_new, 1)
        print("  _patch_z05 P39: fixed ObjListAddrs byte shift (old-man-on-$75 bug)")
    else:
        print("  WARNING: _patch_z05 P39 -- ObjListAddrs anchor not found")

    # ------------------------------------------------------------------
    # P40: Fix SpawnPosListAddrs off-by-one.
    #
    # Upstream extraction placed the 4 SpawnPosListAddrsLo entries at
    # $4D,$56,$5F,$68 but the actual NES addresses are $864E,$8657,$8660,
    # $8669 (verified by pattern-matching the 9-byte SpawnPosList data in
    # bank 5 of the NES ROM). Result: each list's first read returns a
    # stray $86 byte (from the preceding pointer table's HI column),
    # decoding to X=$60 Y=$8D — and every subsequent spawn position
    # shifts by one slot. Symptom: enemies spawn at wrong coordinates
    # (often from the bottom/top edge of the room) on any overworld
    # screen that goes through AssignObjSpawnPositions.
    # ------------------------------------------------------------------
    p40_old = (
        '    dc.b    $4D   ; <SpawnPosList0 (NES=$864D)\n'
        '    dc.b    $56   ; <SpawnPosList1 (NES=$8656)\n'
        '    dc.b    $5F   ; <SpawnPosList2 (NES=$865F)\n'
        '    dc.b    $68   ; <SpawnPosList3 (NES=$8668)\n'
    )
    p40_new = (
        '    ; PATCH P40: +1 byte to each LO — upstream table was shifted 1 byte\n'
        '    ; into the preceding HI column, producing a stray $86 first read.\n'
        '    dc.b    $4E   ; <SpawnPosList0 (NES=$864E)\n'
        '    dc.b    $57   ; <SpawnPosList1 (NES=$8657)\n'
        '    dc.b    $60   ; <SpawnPosList2 (NES=$8660)\n'
        '    dc.b    $69   ; <SpawnPosList3 (NES=$8669)\n'
    )
    if p40_old in text:
        text = text.replace(p40_old, p40_new, 1)
        print("  _patch_z05 P40: fixed SpawnPosListAddrsLo off-by-one (enemy-bottom-spawn bug)")
    else:
        print("  WARNING: _patch_z05 P40 -- SpawnPosListAddrsLo anchor not found")

    # ------------------------------------------------------------------
    # P42: Bypass the "monsters from edges" short-circuit in
    # AssignObjSpawnPositions so initial spawn positions are always taken
    # from SpawnPosListN (matching the NES t=0 state on cold boot in
    # edge-spawn rooms like $73).
    #
    # Evidence (2026-04-17):
    #   NES room $73 at t=0:  slot1 at (X=$70, Y=$9D)  — SpawnPosList1[$97]
    #   Gen room $73 at t=0:  slot1 at (X=$B0, Y=$DD)  — edge cell, stuck
    #
    # Both have $04CD=$08 (bit 3 "edge-spawn" set) and byte-identical
    # playmap, yet NES uses SpawnPosList1 coords at t=0 while Gen jumps
    # straight to the edge-cell placement. The observable effect on Gen
    # is that two Moblins are permanently stranded at Y=$DD because the
    # edge-cell tiles underneath them are unwalkable and the per-frame
    # Walker_Move loop never finds an escape direction.
    #
    # Forcing AssignObjSpawnPositions to fall through to the normal
    # spawn loop in OW (regardless of the bit-3 edge-spawn flag) gives
    # Gen the same initial positions as NES. The edge-spawn mechanism
    # itself (in InitObject's UninitMonsterFromEdge path) is untouched
    # and still drives kill/respawn from the room edges.
    # ------------------------------------------------------------------
    p42_old = (
        '    move.b  ($0010,A4),D0\n'
        '    bne  _anon_z05_56\n'
        '    move.b  ($04CD,A4),D0\n'
        '    andi.b #$08,D0\n'
        '    bne  _L_z05_AssignObjSpawnPositions_AssignSpecialPositions\n'
        '_anon_z05_56:\n'
    )
    p42_new = (
        '    ; PATCH P42: skip OW edge-spawn short-circuit so initial positions\n'
        '    ; always come from SpawnPosListN (NES-accurate t=0 state).\n'
        '    move.b  ($0010,A4),D0\n'
        '    ; bne -> anon56 and bit-3 check removed (P42).\n'
        '_anon_z05_56:\n'
    )
    if p42_old in text:
        text = text.replace(p42_old, p42_new, 1)
        print("  _patch_z05 P42: AssignObjSpawnPositions now always runs normal spawn in OW")
    else:
        print("  WARNING: _patch_z05 P42 -- AssignObjSpawnPositions anchor not found")

    # ------------------------------------------------------------------
    # P44: Replace the NES-style ($06),Y indirect SpawnPosListN fetch
    # with a Gen-native direct lookup.
    #
    # On NES, SpawnPosListAddrsLo/Hi hold 16-bit pointers into ROM bank 5
    # ($8657 etc.). The transpiled code saves those bytes to $06/$07 and
    # dereferences via `add.l #NES_RAM,D4; movea.l D4,A0`. That produces
    # Gen address $FF8657 — which is not where Gen stores its
    # SpawnPosList0..3 tables (those live at ROM $00040EF4 onward per the
    # listing). Result: every spawn read returns open-bus / garbage bytes,
    # so AssignObjSpawnPositions writes junk coordinates for slots 1..9.
    # That's why P42 alone failed to place enemies at SpawnPosList
    # positions — the normal-spawn loop was running, but reading garbage.
    #
    # Fix: add a 4-entry 32-bit Gen pointer table `SpawnPosListPtrsGen`
    # and have the loop resolve A0 directly from D3_dir * 4 instead of
    # going through the NES pointer translation.
    # ------------------------------------------------------------------
    p44_setup_old = (
        '    ; Put the address of the spawn list for Link\'s direction in [06:07].\n'
        '    ;\n'
        '    lea     (SpawnPosListAddrsLo).l,A0\n'
        '    move.b  (A0,D3.W),D0\n'
        '    move.b  D0,($0006,A4)\n'
        '    lea     (SpawnPosListAddrsHi).l,A0\n'
        '    move.b  (A0,D3.W),D0\n'
        '    move.b  D0,($0007,A4)\n'
    )
    p44_setup_new = (
        '    ; PATCH P44: Gen-native SpawnPosListN pointer resolution.\n'
        '    ; Save direction index (D3=0..3) to $06 for loop to use.\n'
        '    move.b  D3,($0006,A4)\n'
    )
    p44_loop_old = (
        '_L_z05_AssignObjSpawnPositions_LoopSpawnSpot:\n'
        '    move.b  ($06,A4),D1   ; ptr lo\n'
        '    move.b  ($07,A4),D4  ; ptr hi\n'
        '    andi.w  #$00FF,D1         ; zero-extend lo byte\n'
        '    lsl.w   #8,D4\n'
        '    or.w    D1,D4             ; D4 = NES ptr addr\n'
        '    ext.l   D4\n'
        '    add.l   #NES_RAM,D4       ; → Genesis addr\n'
        '    movea.l D4,A0\n'
        '    move.b  (A0,D3.W),D0     ; LDA ($nn),Y\n'
    )
    p44_loop_new = (
        '_L_z05_AssignObjSpawnPositions_LoopSpawnSpot:\n'
        '    ; PATCH P44: Gen-native direct lookup.\n'
        '    moveq   #0,D4\n'
        '    move.b  ($06,A4),D4              ; direction index (0..3)\n'
        '    lsl.w   #2,D4                    ; *4 for dc.l entries\n'
        '    lea     (SpawnPosListPtrsGen).l,A0\n'
        '    movea.l (A0,D4.W),A0             ; A0 = Gen addr of SpawnPosList{D4/4}\n'
        '    move.b  (A0,D3.W),D0             ; fetch spawn cell at SpawnCycle index\n'
    )
    # Also append the Gen-native pointer table after SpawnPosListAddrsHi.
    p44_table_old = (
        '    dc.b    $86   ; >SpawnPosList3 (NES=$8668)\n'
        '\n'
        '    even\n'
        'SpawnPosList0:\n'
    )
    p44_table_new = (
        '    dc.b    $86   ; >SpawnPosList3 (NES=$8668)\n'
        '\n'
        '    ; PATCH P44: Gen-native 32-bit pointer table. Indexed by\n'
        '    ; direction index (0..3) * 4.\n'
        '    even\n'
        'SpawnPosListPtrsGen:\n'
        '    dc.l    SpawnPosList0\n'
        '    dc.l    SpawnPosList1\n'
        '    dc.l    SpawnPosList2\n'
        '    dc.l    SpawnPosList3\n'
        '\n'
        '    even\n'
        'SpawnPosList0:\n'
    )
    p44_ok = True
    if p44_setup_old in text:
        text = text.replace(p44_setup_old, p44_setup_new, 1)
    else:
        p44_ok = False
        print("  WARNING: _patch_z05 P44 -- setup anchor not found")
    if p44_loop_old in text:
        text = text.replace(p44_loop_old, p44_loop_new, 1)
    else:
        p44_ok = False
        print("  WARNING: _patch_z05 P44 -- loop anchor not found")
    if p44_table_old in text:
        text = text.replace(p44_table_old, p44_table_new, 1)
    else:
        p44_ok = False
        print("  WARNING: _patch_z05 P44 -- table anchor not found")
    if p44_ok:
        print("  _patch_z05 P44: Gen-native SpawnPosListN direct lookup")

    # ------------------------------------------------------------------
    # P46: Reseed CurEdgeSpawnCell ($0525) on entry to edge-spawn rooms.
    #
    # FindNextEdgeSpawnCell walks CCW from $0525 looking for a walkable
    # cell (tile < $84). The walk has boundary bugs at corners ($4F, $E0)
    # where it temporarily escapes into out-of-bounds playmap addresses
    # and reads garbage bytes. On NES, those garbage bytes happen to land
    # in SRAM locations with specific values, so the walk terminates
    # pseudo-deterministically at top-edge cells like $4X (Y=$3D,
    # enemies walk down into the room). On Gen, the garbage bytes come
    # from different RAM and the walk terminates at bottom-edge cells
    # ($EX), where the tiles are unwalkable for the UP direction — so
    # enemies can never move into the play area.
    #
    # Force $0525 to $48 (top-edge cell, mid-screen) whenever the room
    # has RoomAttrsOW_F bit 3 set on entry. Enemies spawn from the top,
    # which is the NES-visible behavior players expect for edge-spawn
    # rooms like $73, $5B, $68, etc.
    # ------------------------------------------------------------------
    p46_old = '    move.b  D0,($04CD,A4)\n    bsr     ResetInvObjState\n'
    p46_new = (
        '    move.b  D0,($04CD,A4)\n'
        '    ; PATCH P46: reseed CurEdgeSpawnCell to top-edge for\n'
        '    ; edge-spawn rooms, so enemies always enter from top where\n'
        '    ; tiles are walkable downward (Gen-specific workaround for\n'
        '    ; FindNextEdgeSpawnCell boundary bug at corners).\n'
        '    btst    #3,D0\n'
        '    beq.s   _L_z05_skip_p46_reseed\n'
        '    move.b  #$48,($0525,A4)\n'
        '_L_z05_skip_p46_reseed:\n'
        '    bsr     ResetInvObjState\n'
    )
    # P46 DISABLED 2026-04-18: always-reseed was too aggressive, clustering
    # all edge-spawns near top-edge mid ($48). NES $0525 advances naturally
    # through rooms, spreading spawns across top/left/right edges. Rely on
    # P47's pre/post-walk bottom-edge snap to avoid stuck cases without
    # collapsing every room's spawns to one spot.
    if False and p46_old in text:
        text = text.replace(p46_old, p46_new, 1)
        print("  _patch_z05 P46: reseed CurEdgeSpawnCell to $48 on edge-spawn room entry")
    else:
        print("  _patch_z05 P46: DISABLED (clustering)")

    # --- Stage 4a: C function stubs ---
    text = _stub_func(text, 'CopyColumnToTileBuf', 'c_copy_column_to_tilebuf')
    text = _stub_func(text, 'CopyRowToTileBuf', 'c_copy_row_to_tilebuf')
    text = _stub_func(text, 'AddDoorFlagsToCurOpenedDoors', 'c_add_door_flags')
    text = _stub_func(text, 'CalcOpenDoorwayMask', 'c_calc_open_doorway_mask')
    text = _stub_func(text, 'HasCompass', 'c_has_compass')
    text = _stub_func(text, 'HasMap', 'c_has_map')

    # --- Stage 4b: more z_05 leaf functions ---
    text = _stub_func(text, 'SplitRoomId', 'c_split_room_id')
    text = _stub_func(text, 'IsDarkRoom_Bank5', 'c_is_dark_room')
    text = _stub_func(text, 'SetDoorFlag', 'c_set_door_flag')
    text = _stub_func(text, 'ResetDoorFlag', 'c_reset_door_flag')
    text = _stub_func(text, 'CheckHasLivingMonsters', 'c_check_has_living_monsters')
    text = _stub_func(text, 'SilenceSound', 'c_silence_sound')
    text = _stub_func(text, 'SetEnteringDoorwayAsCurOpenedDoors', 'c_set_entering_doorway')

    # --- Stage 4b batch 3: more z_05 leaf functions ---
    text = _stub_func(text, 'WriteAndEnableSprite0', 'c_write_and_enable_sprite0')
    text = _stub_func(text, 'PutLinkBehindBackground', 'c_put_link_behind_background')
    text = _stub_func(text, 'ResetInvObjState', 'c_reset_inv_obj_state')
    text = _stub_func(text, 'MaskCurPpuMaskGrayscale', 'c_mask_cur_ppu_mask_grayscale')
    text = _stub_func(text, 'SetupObjRoomBounds', 'c_setup_obj_room_bounds')
    text = _stub_func(text, 'FillPlayAreaAttrs', 'c_fill_play_area_attrs')

    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)

    print(f"  _patch_z05: fixed bank-window guards injected {hits}/{len(hooks)} hooks")


def _patch_z06(path):
    """Post-process patches for z_06.asm -- replace TransferTileBuf/ContinueTransferTileBuf.

    Replace the slow byte-by-byte tile buffer executor (ContinueTransferTileBuf
    calling _ppu_write_7 per byte) with a single call to _transfer_tilebuf_fast
    in nes_io.asm.  This is the main NMI cadence fix.

    When ZELDA_BANK_MODE_06 == "c", strip all code and emit only data labels
    plus entry stubs that jump to C shims."""

    ZELDA_BANK_MODE_06 = "c"

    # In C mode: first run all normal patches (TransferBufPtrs table, 32-bit
    # lookup, P32e, P33, DynTileBuf pre-check, etc.), THEN strip only the
    # level-load code functions and replace them with C-shim stubs.
    # This preserves TransferCurTileBuf/TransferTileBuf in asm.

    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Find ContinueTransferTileBuf: label (start of region to replace)
    ctb_start = None
    for i, line in enumerate(lines):
        if line.strip() == 'ContinueTransferTileBuf:':
            ctb_start = i
            break

    if ctb_start is None:
        print("  WARNING: _patch_z06 -- ContinueTransferTileBuf label not found")
        return

    # Find TransferTileBuf: label
    ttb_label = None
    for i in range(ctb_start, len(lines)):
        if lines[i].strip() == 'TransferTileBuf:':
            ttb_label = i
            break

    if ttb_label is None:
        print("  WARNING: _patch_z06 -- TransferTileBuf label not found")
        return

    # Find the end of TransferTileBuf: the next top-level label after it
    # (e.g., Mode1TileTransferBuf:) that isn't _anon_ or _L_ prefixed
    ttb_end = None
    for i in range(ttb_label + 1, len(lines)):
        stripped = lines[i].strip()
        if (stripped.endswith(':')
                and not stripped.startswith('_')
                and not stripped.startswith('.')
                and not stripped.startswith(';')):
            ttb_end = i
            break

    if ttb_end is None:
        print("  WARNING: _patch_z06 -- could not find end of TransferTileBuf region")
        return

    replacement = [
        'ContinueTransferTileBuf:\n',
        'TransferTileBuf:\n',
        '    ; PATCHED: fast tile buffer interpreter (bypasses per-byte _ppu_write_7)\n',
        '    bsr     _transfer_tilebuf_fast\n',
        '    rts\n',
        '\n',
        '    even\n',
    ]

    lines[ctb_start:ttb_end] = replacement
    print("  _patch_z06: TransferTileBuf -> _transfer_tilebuf_fast")

    # ---- Patch 2: Add TransferBufPtrs 32-bit table and fix TransferCurTileBuf ----
    text = ''.join(lines)

    # 2a: Replace TransferCurTileBuf's 16-bit lookup with 32-bit lookup
    old_tcb = ('TransferCurTileBuf:\n'
               '    moveq   #0,D2\n'
               '    move.b  ($0014,A4),D2\n'
               '    lea     (TransferBufAddrs).l,A0\n'
               '    move.b  (A0,D2.W),D0\n'
               '    move.b  D0,($0000,A4)\n'
               '    lea     (TransferBufAddrs+1).l,A0\n'
               '    move.b  (A0,D2.W),D0\n'
               '    move.b  D0,($0001,A4)\n'
               '    bsr     TransferTileBuf')
    new_tcb = ('TransferCurTileBuf:\n'
               '    ; PATCHED: use 32-bit pointer table to resolve ROM-resident buffers.\n'
               '    ; $0014 is a 2-byte index (0, 2, 4, …).  Convert to 4-byte index and\n'
               '    ; load the full 68K address from TransferBufPtrs.\n'
               '    moveq   #0,D2\n'
               '    move.b  ($0014,A4),D2\n'
               '    add.w   D2,D2                       ; 2-byte index -> 4-byte index\n'
               '    lea     (TransferBufPtrs).l,A1\n'
               '    move.l  (A1,D2.W),D0               ; D0 = 32-bit buffer pointer\n'
               '    movea.l D0,A0                      ; A0 = 32-bit buffer pointer\n'
               '    bsr     TransferTileBuf')
    if old_tcb in text:
        text = text.replace(old_tcb, new_tcb, 1)
        print("  _patch_z06 P2a: TransferCurTileBuf -> 32-bit lookup")
    else:
        print("  WARNING: _patch_z06 P2a -- TransferCurTileBuf not found")

    # 2b: Add TransferBufPtrs 32-bit table after TransferBufAddrs
    # Find the last DynTileBuf entry in TransferBufAddrs
    marker = ("    dc.b    (DynTileBuf)&$FF, (DynTileBuf>>8)&$FF"
              "   ; NES .ADDR (little-endian)\n"
              "\n"
              "    even\n"
              "TransferCurTileBuf:")
    ptrs_table = ("    dc.b    (DynTileBuf)&$FF, (DynTileBuf>>8)&$FF"
                  "   ; NES .ADDR (little-endian)\n"
                  "\n"
                  "; -- 32-bit absolute pointer table (same order as TransferBufAddrs) --\n"
                  "; EQU symbols (NES RAM offsets): NES_RAM + offset\n"
                  "; ROM labels: assembler resolves to 68K ROM addr\n"
                  "    even\n"
                  "TransferBufPtrs:\n"
                  "    dc.l    NES_RAM+DynTileBuf                              ; idx  0 ($00)\n"
                  "    dc.l    StoryTileAttrTransferBuf                         ; idx  1 ($02)\n"
                  "    dc.l    Mode8TextTileBuffer                              ; idx  2 ($04)\n"
                  "    dc.l    LevelPaletteRow7TransferBuf                      ; idx  3 ($06)\n"
                  "    dc.l    AquamentusPaletteRow7TransferBuf                 ; idx  4 ($08)\n"
                  "    dc.l    OrangeBossPaletteRow7TransferBuf                 ; idx  5 ($0A)\n"
                  "    dc.l    LevelNumberTransferBuf                           ; idx  6 ($0C)\n"
                  "    dc.l    StatusBarStaticsTransferBuf                      ; idx  7 ($0E)\n"
                  "    dc.l    GameTitleTransferBuf                              ; idx  8 ($10)\n"
                  "    dc.l    MenuPalettesTransferBuf                           ; idx  9 ($12)\n"
                  "    dc.l    Mode1TileTransferBuf                              ; idx 10 ($14)\n"
                  "    dc.l    ModeFCharsTransferBuf                             ; idx 11 ($16)\n"
                  "    dc.l    NES_RAM+LevelInfo_PalettesTransferBuf             ; idx 12 ($18)\n"
                  "    dc.l    NES_RAM+DynTileBuf                              ; idx 13 ($1A)\n"
                  "    dc.l    NES_RAM+DynTileBuf                              ; idx 14 ($1C)\n"
                  "    dc.l    BlankTextBoxLines                                 ; idx 15 ($1E)\n"
                  "    dc.l    GhostPaletteRow7TransferBuf                      ; idx 16 ($20)\n"
                  "    dc.l    GreenBgPaletteRow7TransferBuf                    ; idx 17 ($22)\n"
                  "    dc.l    BrownBgPaletteRow7TransferBuf                    ; idx 18 ($24)\n"
                  "    dc.l    CellarAttrsTransferBuf                            ; idx 19 ($26)\n"
                  "    dc.l    NES_RAM+DynTileBuf                              ; idx 20 ($28)\n"
                  "    dc.l    BlankPersonWares                                  ; idx 21 ($2A)\n"
                  "    dc.l    Mode11DeadLinkPalette                             ; idx 22 ($2C)\n"
                  "    dc.l    LevelNumberTransferBuf                           ; idx 23 ($2E)\n"
                  "    dc.l    InventoryTextTransferBuf                          ; idx 24 ($30)\n"
                  "    dc.l    SubmenuBoxesTopsTransferBuf                       ; idx 25 ($32)\n"
                  "    dc.l    SubmenuBoxesSidesTransferBuf                     ; idx 26 ($34)\n"
                  "    dc.l    GanonPaletteRow7TransferBuf                      ; idx 27 ($36)\n"
                  "    dc.l    SelectedItemBoxBottomTransferBuf                  ; idx 28 ($38)\n"
                  "    dc.l    UseBButtonTextTransferBuf                         ; idx 29 ($3A)\n"
                  "    dc.l    InventoryBoxBottomTransferBuf                     ; idx 30 ($3C)\n"
                  "    dc.l    CaveBgPaletteRowsTransferBuf                     ; idx 31 ($3E)\n"
                  "    dc.l    SubmenuMapRemainderTransferBuf                    ; idx 32 ($40)\n"
                  "    dc.l    SheetMapBottomEdgeTransferBuf                     ; idx 33 ($42)\n"
                  "    dc.l    NES_RAM+LevelInfo_StatusBarMapTransferBuf         ; idx 34 ($44)\n"
                  "    dc.l    GameOverTransferBuf                               ; idx 35 ($46)\n"
                  "    dc.l    SubmenuAttrs1TransferBuf                          ; idx 36 ($48)\n"
                  "    dc.l    SubmenuAttrs2TransferBuf                          ; idx 37 ($4A)\n"
                  "    dc.l    BlankBottomRowNT2TransferBuf                      ; idx 38 ($4C)\n"
                  "    dc.l    BlankRowTransferBuf                               ; idx 39 ($4E)\n"
                  "    dc.l    SubmenuTriforceApexTransferBuf                    ; idx 40 ($50)\n"
                  "    dc.l    TriforceRow0TransferBuf                           ; idx 41 ($52)\n"
                  "    dc.l    TriforceRow1TransferBuf                           ; idx 42 ($54)\n"
                  "    dc.l    TriforceRow2TransferBuf                           ; idx 43 ($56)\n"
                  "    dc.l    TriforceRow3TransferBuf                           ; idx 44 ($58)\n"
                  "    dc.l    SubmenuTriforceBottomTransferBuf                  ; idx 45 ($5A)\n"
                  "    dc.l    TriforceTextTransferBuf                           ; idx 46 ($5C)\n"
                  "    dc.l    Mode11BackgroundPaletteBottomHalfTransferBuf      ; idx 47 ($5E)\n"
                  "    dc.l    Mode11PlayAreaAttrsTopHalfTransferBuf             ; idx 48 ($60)\n"
                  "    dc.l    Mode11PlayAreaAttrsBottomHalfTransferBuf          ; idx 49 ($62)\n"
                  "    dc.l    NES_RAM+DynTileBuf                              ; idx 50 ($64)\n"
                  "    dc.l    NES_RAM+DynTileBuf                              ; idx 51 ($66)\n"
                  "    dc.l    NES_RAM+DynTileBuf                              ; idx 52 ($68)\n"
                  "    dc.l    EndingPaletteTransferBuf                          ; idx 53 ($6A)\n"
                  "    dc.l    BombCapacityPriceTextTransferBuf                  ; idx 54 ($6C)\n"
                  "    dc.l    NES_RAM+DynTileBuf                              ; idx 55 ($6E)\n"
                  "    dc.l    NES_RAM+DynTileBuf                              ; idx 56 ($70)\n"
                  "    dc.l    NES_RAM+DynTileBuf                              ; idx 57 ($72)\n"
                  "    dc.l    NES_RAM+DynTileBuf                              ; idx 58 ($74)\n"
                  "    dc.l    LifeOrMoneyCostTextTransferBuf                    ; idx 59 ($76)\n"
                  "    dc.l    WhitePaletteBottomHalfTransferBuf                 ; idx 60 ($78)\n"
                  "    dc.l    RedArmosPaletteRow7TransferBuf                   ; idx 61 ($7A)\n"
                  "    dc.l    GleeokPaletteRow7TransferBuf                     ; idx 62 ($7C)\n"
                  "    dc.l    NES_RAM+DynTileBuf                              ; idx 63 ($7E)\n"
                  "\n"
                  "    even\n"
                  "TransferCurTileBuf:")
    if marker in text:
        text = text.replace(marker, ptrs_table, 1)
        print("  _patch_z06 P2b: TransferBufPtrs 32-bit table added")
    else:
        print("  WARNING: _patch_z06 P2b -- TransferBufAddrs marker not found")

    # ---- Patch 3: DynTileBuf pending-record pre-check in TransferCurTileBuf ----
    # Generalized Bug C fix: on NES, DynTileBuf can be consumed on the next NMI
    # before TileBufSelector changes to a later static buffer. On Genesis, a
    # timing difference can let the selector overwrite happen first, dropping
    # the pending dynamic record. If DynTileBuf is non-empty while selector is
    # non-zero, drain DynTileBuf now and preserve TileBufSelector for the next
    # NMI so the later static buffer still dispatches in order.
    old_tcb3 = ('TransferCurTileBuf:\n'
                '    ; PATCHED: use 32-bit pointer table to resolve ROM-resident buffers.\n'
                '    ; $0014 is a 2-byte index (0, 2, 4, …).  Convert to 4-byte index and\n'
                '    ; load the full 68K address from TransferBufPtrs.\n'
                '    moveq   #0,D2\n'
                '    move.b  ($0014,A4),D2\n'
                '    add.w   D2,D2                       ; 2-byte index -> 4-byte index\n'
                '    lea     (TransferBufPtrs).l,A1\n'
                '    move.l  (A1,D2.W),D0               ; D0 = 32-bit buffer pointer\n'
                '    movea.l D0,A0                      ; A0 = 32-bit buffer pointer\n'
                '    bsr     TransferTileBuf\n'
                '    moveq   #63,D0\n')
    new_tcb3 = ('TransferCurTileBuf:\n'
                '    ; PATCHED: DynTileBuf pending-record pre-check (generalized Bug C fix).\n'
                '    ; If DynTileBuf is non-empty while TileBufSelector already points at a\n'
                '    ; later static buffer, consume DynTileBuf first and leave selector intact\n'
                '    ; for the next NMI. This preserves NES ordering for dynamic room/menu\n'
                '    ; records that would otherwise be dropped by selector timing drift.\n'
                '    lea     (NES_RAM+DynTileBuf).l,A0\n'
                '    cmpi.b  #$FF,(A0)                  ; DynTileBuf empty sentinel?\n'
                '    beq.s   .no_pending_dyn\n'
                '    tst.b   ($0014,A4)                  ; TileBufSelector = 0 => normal DynTileBuf path\n'
                '    beq.s   .no_pending_dyn\n'
                '    movem.l D0-D2/A0,-(SP)             ; save regs around JSR\n'
                '    jsr     _transfer_tilebuf_fast      ; process pending DynTileBuf now\n'
                '    movem.l (SP)+,D0-D2/A0             ; restore regs\n'
                '    move.b  #$FF,(NES_RAM+DynTileBuf).l ; reset sentinel\n'
                '    moveq   #63,D0\n'
                '    move.b  D0,($0300,A4)\n'
                '    moveq   #0,D2\n'
                '    move.b  D2,($005C,A4)\n'
                '    move.b  D2,($0301,A4)\n'
                '    rts\n'
                '.no_pending_dyn:\n'
                '    ; 32-bit pointer table lookup for main dispatch.\n'
                '    moveq   #0,D2\n'
                '    move.b  ($0014,A4),D2\n'
                '    add.w   D2,D2                       ; 2-byte index -> 4-byte index\n'
                '    lea     (TransferBufPtrs).l,A1\n'
                '    move.l  (A1,D2.W),D0               ; D0 = 32-bit buffer pointer\n'
                '    movea.l D0,A0                      ; A0 = 32-bit buffer pointer\n'
                '    bsr     TransferTileBuf\n'
                '    moveq   #63,D0\n')
    if old_tcb3 in text:
        text = text.replace(old_tcb3, new_tcb3, 1)
        print("  _patch_z06 P3: DynTileBuf contention pre-check generalized")
    else:
        print("  WARNING: _patch_z06 P3 -- TransferCurTileBuf body not found")

    # ------------------------------------------------------------------
    # P32a-d: Keep room-load CopyBlock ROM path reproducible in transpiler.
    # Convert core level/data source tables to dc.l labels.
    # ------------------------------------------------------------------
    p32_tables = [
        ('LevelBlockAddrsQ1', [
            'LevelBlockOW',
            'LevelBlockUW1Q1',
            'LevelBlockUW1Q1',
            'LevelBlockUW1Q1',
            'LevelBlockUW1Q1',
            'LevelBlockUW1Q1',
            'LevelBlockUW1Q1',
            'LevelBlockUW2Q1',
            'LevelBlockUW2Q1',
            'LevelBlockUW2Q1',
        ], 10),
        ('LevelInfoAddrs', [
            'LevelInfoOW',
            'LevelInfoUW1',
            'LevelInfoUW2',
            'LevelInfoUW3',
            'LevelInfoUW4',
            'LevelInfoUW5',
            'LevelInfoUW6',
            'LevelInfoUW7',
            'LevelInfoUW8',
            'LevelInfoUW9',
        ], 10),
        ('CommonDataBlockAddr_Bank6', [
            'CommonDataBlock_Bank6',
        ], 1),
        ('LevelBlockAddrsQ2', [
            'LevelBlockOW',
            'LevelBlockUW1Q2',
            'LevelBlockUW1Q2',
            'LevelBlockUW1Q2',
            'LevelBlockUW1Q2',
            'LevelBlockUW1Q2',
            'LevelBlockUW1Q2',
            'LevelBlockUW2Q2',
            'LevelBlockUW2Q2',
            'LevelBlockUW2Q2',
        ], 10),
    ]
    p32_table_hits = 0
    for label, entries, expect in p32_tables:
        text, ok_tbl, err_tbl = _replace_addr_table_block(text, label, entries, expected_count=expect)
        if ok_tbl:
            p32_table_hits += 1
        else:
            print(f"  WARNING: _patch_z06 P32 table {label} -- {err_tbl}")
    if p32_table_hits == len(p32_tables):
        print("  _patch_z06 P32a-d: level/common source tables converted to dc.l")
    else:
        print(f"  WARNING: _patch_z06 P32a-d -- only {p32_table_hits}/{len(p32_tables)} tables converted")

    # ------------------------------------------------------------------
    # P32e-h: CopyBlock ROM path + callers (InitMode2_Sub0/Sub1 + common data).
    # ------------------------------------------------------------------
    def _replace_global_block(src_text, label, replacement_lines):
        src_lines = src_text.splitlines()
        start = None
        for i, ln in enumerate(src_lines):
            if ln.strip() == f'{label}:':
                start = i
                break
        if start is None:
            return src_text, False, f"block {label} not found"
        end = len(src_lines)
        for i in range(start + 1, len(src_lines)):
            s = src_lines[i].strip()
            if re.match(r'^[A-Za-z]\w*:$', s):
                end = i
                break
        src_lines[start:end] = replacement_lines
        return '\n'.join(src_lines), True, None

    p32_sub0 = [
        'InitMode2_Sub0:',
        '    ; PATCH P32f: load level block source from 32-bit table and copy from ROM.',
        '    move.b  ($0010,A4),D0',
        '    lsl.b  #1,D0   ; ASL A',
        '    moveq   #0,D2',
        '    move.b  D0,D2',
        '    add.w   D2,D2                       ; 2-byte index -> 4-byte dc.l index',
        '    moveq   #0,D3',
        '    move.b  ($0016,A4),D3',
        '    lea     ($062D,A4),A0',
        '    move.b  (A0,D3.W),D0',
        '    bne.s   _L_z06_InitMode2_Sub0_SecondQuest_P32',
        '    lea     (LevelBlockAddrsQ1).l,A0',
        '    bra.s   _L_z06_InitMode2_Sub0_LoadSrc_P32',
        '',
        '    even',
        '_L_z06_InitMode2_Sub0_SecondQuest_P32:',
        '    lea     (LevelBlockAddrsQ2).l,A0',
        '',
        '    even',
        '_L_z06_InitMode2_Sub0_LoadSrc_P32:',
        '    movea.l (A0,D2.W),A2',
        '    jsr     FetchLevelBlockDestInfo',
        '    jsr     CopyBlock_ROM',
        '    rts',
        '',
    ]
    text, ok_sub0, err_sub0 = _replace_global_block(text, 'InitMode2_Sub0', p32_sub0)
    if ok_sub0:
        print("  _patch_z06 P32f: InitMode2_Sub0 -> 32-bit table + CopyBlock_ROM")
    else:
        print(f"  WARNING: _patch_z06 P32f -- {err_sub0}")

    p32_sub1 = [
        'InitMode2_Sub1:',
        '    ; PATCH P32g: load level info source from 32-bit table and copy from ROM.',
        '    move.b  ($0010,A4),D0',
        '    lsl.b  #1,D0   ; ASL A',
        '    moveq   #0,D2',
        '    move.b  D0,D2',
        '    add.w   D2,D2                       ; 2-byte index -> 4-byte dc.l index',
        '    lea     (LevelInfoAddrs).l,A0',
        '    movea.l (A0,D2.W),A2',
        '    jsr     FetchLevelInfoDestInfo',
        '    jsr     CopyBlock_ROM',
        '    moveq   #0,D0',
        '    move.b  D0,($0013,A4)',
        '    addq.b  #1,($0011,A4)',
        '    rts',
        '',
    ]
    text, ok_sub1, err_sub1 = _replace_global_block(text, 'InitMode2_Sub1', p32_sub1)
    if ok_sub1:
        print("  _patch_z06 P32g: InitMode2_Sub1 -> 32-bit table + CopyBlock_ROM")
    else:
        print(f"  WARNING: _patch_z06 P32g -- {err_sub1}")

    p32_common = [
        'CopyCommonDataToRam:',
        '    ; PATCH P32h: copy common data directly from ROM source pointer.',
        '    lea     (CommonDataBlockAddr_Bank6).l,A0',
        '    movea.l (A0),A2',
        '    jsr     FetchDestAddrForCommonDataBlock',
        '    jsr     CopyBlock_ROM',
        '    moveq   #0,D0',
        '    move.b  D0,($0013,A4)',
        '    rts',
        '',
    ]
    text, ok_common, err_common = _replace_global_block(text, 'CopyCommonDataToRam', p32_common)
    if ok_common:
        print("  _patch_z06 P32h: CopyCommonDataToRam -> CopyBlock_ROM")
    else:
        print(f"  WARNING: _patch_z06 P32h -- {err_common}")

    p32_copyblock = [
        'CopyBlock:',
        '    ; PATCH P32e: compatibility wrapper now routes through ROM source path.',
        '    jmp     CopyBlock_ROM',
        '',
        '    even',
        'CopyBlock_ROM:',
        '    moveq   #0,D3',
        '    even',
        '_L_z06_CopyBlock_ROM_Loop:',
        '    move.b  (A2,D3.W),D0               ; source byte from ROM',
        '    move.b  ($02,A4),D1   ; ptr lo',
        '    move.b  ($03,A4),D4  ; ptr hi',
        '    andi.w  #$00FF,D1         ; zero-extend lo byte',
        '    lsl.w   #8,D4',
        '    or.w    D1,D4',
        '    ext.l   D4',
        '    add.l   #NES_RAM,D4',
        '    movea.l D4,A0',
        '    move.b  D0,(A0,D3.W)     ; STA ($nn),Y',
        '    move.b  ($0002,A4),D0',
        '    move.b  ($0004,A4),D1',
        '    cmp.b   D1,D0',
        '    bne.s   _L_z06_CopyBlock_ROM_Next',
        '    move.b  ($0003,A4),D0',
        '    move.b  ($0005,A4),D1',
        '    cmp.b   D1,D0',
        '    bne.s   _L_z06_CopyBlock_ROM_Next',
        '    addq.b  #1,($0013,A4)',
        '    rts',
        '',
        '    even',
        '_L_z06_CopyBlock_ROM_Next:',
        '    move.b  ($0002,A4),D0',
        '    andi    #$EE,CCR  ; CLC: clear C+X',
        '    move.b  #$01,D1',
        '    addx.b  D1,D0   ; ADC #$01 (X flag = 6502 C)',
        '    move.b  D0,($0002,A4)',
        '    move.b  ($0003,A4),D0',
        '    move.b  #$00,D1',
        '    addx.b  D1,D0   ; ADC #$00 (X flag = 6502 C)',
        '    move.b  D0,($0003,A4)',
        '    addq.l  #1,A2',
        '    jmp     _L_z06_CopyBlock_ROM_Loop',
        '',
    ]
    text, ok_copy, err_copy = _replace_global_block(text, 'CopyBlock', p32_copyblock)
    if ok_copy:
        print("  _patch_z06 P32e: CopyBlock -> CopyBlock_ROM")
    else:
        print(f"  WARNING: _patch_z06 P32e -- {err_copy}")

    # Demand-driven bank window: pin to bank 6 for z_06 ROM-pointer deref path.
    text, ok_bw, err_bw = _insert_fixed_bank_window_call(text, 'UpdateMode2Load_Full', 6)
    if ok_bw:
        print("  _patch_z06 P33: injected fixed bank-window guard in UpdateMode2Load_Full")
    else:
        print(f"  WARNING: _patch_z06 P33 -- {err_bw}")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)

    if ZELDA_BANK_MODE_06 == "c":
        _patch_z06_c_mode(path)


def _patch_z06_c_mode(path):
    """Stage 3a post-processor: emit data-only asm + TransferCurTileBuf asm.
    Reads the already-patched z_06.asm (with 32-bit table, DynTileBuf pre-check)
    and rebuilds: header + xdefs + level-load stubs + TransferCurTileBuf asm +
    TransferBufPtrs table + all data blocks."""
    import re

    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # --- Parse top-level label ranges ---
    label_starts = []  # (line_idx, label_name)
    for i, line in enumerate(lines):
        m = re.match(r'^([A-Za-z]\w*):', line)
        if m:
            label_starts.append((i, m.group(1)))

    def _get_block(label):
        """Return lines from label start to next top-level label."""
        for idx, (start, name) in enumerate(label_starts):
            if name == label:
                end = label_starts[idx+1][0] if idx+1 < len(label_starts) else len(lines)
                return lines[start:end]
        return []

    # --- Header (everything before first top-level label) ---
    header_end = label_starts[0][0] if label_starts else len(lines)
    out = list(lines[:header_end])

    # --- Data labels to preserve ---
    data_labels = {
        'LevelBlockAddrsQ1', 'LevelBlockAddrsQ2', 'LevelInfoAddrs',
        'CommonDataBlockAddr_Bank6',
        'LevelBlockAttrsBQ2ReplacementOffsets', 'LevelBlockAttrsBQ2ReplacementValues',
        'LevelInfoUWQ2Replacements1', 'LevelInfoUWQ2Replacements2',
        'LevelInfoUWQ2Replacements3', 'LevelInfoUWQ2Replacements4',
        'LevelInfoUWQ2Replacements5', 'LevelInfoUWQ2Replacements6',
        'LevelInfoUWQ2Replacements7', 'LevelInfoUWQ2Replacements8',
        'LevelInfoUWQ2Replacements9',
        'LevelInfoUWQ2ReplacementAddrs', 'LevelInfoUWQ2ReplacementSizes',
        'LevelBlockOW', 'LevelBlockUW1Q1', 'LevelBlockUW2Q1',
        'LevelBlockUW1Q2', 'LevelBlockUW2Q2',
        'LevelInfoOW', 'LevelInfoUW1', 'LevelInfoUW2', 'LevelInfoUW3',
        'LevelInfoUW4', 'LevelInfoUW5', 'LevelInfoUW6', 'LevelInfoUW7',
        'LevelInfoUW8', 'LevelInfoUW9',
        'CommonDataBlock_Bank6',
        'ColumnDirectoryOW', 'ColumnDirectoryUW',
        'TransferBufAddrs', 'TransferBufPtrs',
        'LevelNumberTransferBuf', 'LevelPaletteRow7TransferBuf',
        'MenuPalettesTransferBuf',
        'SubmenuTriforceBottomTransferBuf', 'TriforceTextTransferBuf',
        'Mode1TileTransferBuf', 'ModeFCharsTransferBuf',
        'GanonPaletteRow7TransferBuf', 'EndingPaletteTransferBuf',
        'BlankTextBoxLines', 'BlankPersonWares',
        'SubmenuTriforceApexTransferBuf',
        'StoryTileAttrTransferBuf', 'Mode8TextTileBuffer',
        'StatusBarStaticsTransferBuf', 'GameTitleTransferBuf',
        'GhostPaletteRow7TransferBuf', 'GreenBgPaletteRow7TransferBuf',
        'BrownBgPaletteRow7TransferBuf', 'CaveBgPaletteRowsTransferBuf',
        'CellarAttrsTransferBuf',
        'WhitePaletteBottomHalfTransferBuf',
        'RedArmosPaletteRow7TransferBuf', 'GleeokPaletteRow7TransferBuf',
        'AquamentusPaletteRow7TransferBuf', 'OrangeBossPaletteRow7TransferBuf',
        'BombCapacityPriceTextTransferBuf', 'LifeOrMoneyCostTextTransferBuf',
        'InventoryTextTransferBuf',
        'SubmenuBoxesTopsTransferBuf', 'SubmenuBoxesSidesTransferBuf',
        'SelectedItemBoxBottomTransferBuf', 'UseBButtonTextTransferBuf',
        'InventoryBoxBottomTransferBuf',
        'SubmenuMapRemainderTransferBuf', 'SheetMapBottomEdgeTransferBuf',
        'SubmenuAttrs1TransferBuf', 'SubmenuAttrs2TransferBuf',
        'BlankBottomRowNT2TransferBuf', 'BlankRowTransferBuf',
        'Mode11DeadLinkPalette', 'GameOverTransferBuf',
        'Mode11BackgroundPaletteBottomHalfTransferBuf',
        'Mode11PlayAreaAttrsTopHalfTransferBuf',
        'Mode11PlayAreaAttrsBottomHalfTransferBuf',
        'TriforceRow0TransferBuf', 'TriforceRow1TransferBuf',
        'TriforceRow2TransferBuf', 'TriforceRow3TransferBuf',
    }

    # ASM functions to preserve verbatim from the patched output
    keep_asm = ['TransferCurTileBuf', 'ContinueTransferTileBuf', 'TransferTileBuf']

    # All exported labels
    all_exports = sorted(data_labels | set(keep_asm) |
                         {'InitMode2_Submodes', 'CopyCommonDataToRam',
                          'UpdateMode2Load_Full'})

    out.append('\n; Stage 3a: data-only mode (code ported to src/gen/z_06.c)\n')
    for lbl in all_exports:
        out.append(f'    xdef    {lbl}\n')
    out.append('\n')

    # --- Level-load C stubs ---
    out.append('    even\n')
    out.append('InitMode2_Submodes:\n')
    out.append('    jmp     c_init_mode2_submodes\n\n')
    out.append('    even\n')
    out.append('CopyCommonDataToRam:\n')
    out.append('    jmp     c_copy_common_data_to_ram\n\n')
    out.append('    even\n')
    out.append('UpdateMode2Load_Full:\n')
    out.append('    jmp     c_update_mode2_load_full\n\n')

    # --- TransferCurTileBuf asm (extracted from patched output) ---
    for func in keep_asm:
        block = _get_block(func)
        if block:
            out.append('    even\n')
            out.extend(block)

    # --- All data blocks ---
    for _, lbl in label_starts:
        if lbl in data_labels:
            block = _get_block(lbl)
            if block:
                out.append('    even\n')
                out.extend(block)

    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(out)

    print(f"  _patch_z06: C-mode data-only emit (code -> src/gen/z_06.c)")




def _patch_z07(path):
    """Post-process patches for z_07.asm — ClearNameTable fast path.

    Replace the slow ClearNameTable (1024+64 individual _ppu_write_7 calls)
    with a single call to _clear_nametable_fast in nes_io.asm.
    """
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Find ClearNameTable label and replace through _L_z07_ClearNameTable_RestoreX rts
    start_idx = None
    end_idx = None
    for i, line in enumerate(lines):
        if line.strip() == 'ClearNameTable:':
            start_idx = i
        if start_idx is not None and 'move.b  ($0001,A4),D2' in line and i > start_idx + 10:
            # This is the RestoreX line; rts is on the next line
            end_idx = i + 1  # include the rts line
            break

    if start_idx is None or end_idx is None or end_idx >= len(lines):
        print("  WARNING: _patch_z07 ClearNameTable -- markers not found, skipping")
    else:
        # Verify the rts is there
        if 'rts' not in lines[end_idx]:
            print("  WARNING: _patch_z07 ClearNameTable -- expected rts, skipping")
        else:
            replacement = [
                'ClearNameTable:\n',
                '    ; PATCHED: fast nametable clear (bypasses 1088 _ppu_write_7 calls)\n',
                '    ; D0.b = PPU hi byte ($20/$28), D2.b = tile index, D3.b = attr byte\n',
                '    bsr     _clear_nametable_fast\n',
                '    rts\n',
            ]
            lines[start_idx:end_idx+1] = replacement
            print("  _patch_z07: ClearNameTable -> _clear_nametable_fast")

    # ------------------------------------------------------------------
    # P48 (/mathproblem Phase 0): hand-write MoveObject + inlined q-speed
    # fraction semantics in native M68K. The transpiled version wraps
    # every plain add/sub in eori/addx/eori CCR sandwiches and the
    # AddQSpeedToPositionFraction / SubQSpeedFromPositionFraction helpers
    # in z_01.asm use PHP/PLP (software stack `-(A5)`/`(A5)+`) to serialize
    # carry through bounds checks. Net cost: ~4700 68K cycles per object
    # per frame, which drops room $73 (3-Moblin arrow ambush) to ~44 fps
    # with audibly slow music.
    #
    # This patch replaces the MoveObject block (labels MoveObject,
    # _L_z07_MoveObject_ApplyQSpeedToPosition, _L_z07_MoveObject_Exit,
    # _L_z07_MoveObject_Down, _L_z07_MoveObject_Right, _L_z07_MoveObject_Left)
    # up to but not including PlayerScreenEdgeBounds. The global
    # AddQSpeedToPositionFraction / SubQSpeedFromPositionFraction labels
    # in z_01.asm stay intact — other callers still use the transpiled
    # version. (Plan-file constraint: don't widen risk to all callers of
    # the helpers just to fix the $73 walker hot path.)
    #
    # Uses scc to extract the M68K carry into a 0/1 step amount, then
    # plain add.b / sub.b on ObjGridOffset and ObjX/Y. Limit checks
    # against PositiveGridCellSize ($010E) and NegativeGridCellSize
    # ($010F) use cmp + conditional branch, no PHP/PLP.
    #
    # Sentinel comments `PATCH P48 BEGIN/END` tag the region so later
    # CFG / peephole passes skip the hand-written body.
    # ------------------------------------------------------------------
    # P48_MODE:
    #   "asm" — hand-written M68K body below (original Phase 0 P48)
    #   "c"   — tail-jmp to _c_move_object_shim (Stage 2c C port).
    #           Shim + C function are in src/c_shims.asm +
    #           src/c_move_object.c; built by build.bat.
    P48_MODE = "off"
    P48_WALKER = (P48_MODE in ("asm", "c"))

    if P48_WALKER:
        mo_start = None
        mo_end = None
        for i, line in enumerate(lines):
            if line.strip() == 'MoveObject:':
                mo_start = i
                break
        if mo_start is not None:
            for i in range(mo_start + 1, len(lines)):
                if lines[i].strip() == 'PlayerScreenEdgeBounds:':
                    # Back up past trailing `    even` / blank lines so
                    # the NES alignment directive for the next label
                    # stays intact on its own.
                    mo_end = i
                    while mo_end > mo_start + 1 and lines[mo_end - 1].strip() in ('', 'even'):
                        mo_end -= 1
                    break
        assert mo_start is not None, "P48: MoveObject label not found in z_07.asm"
        assert mo_end is not None and mo_end > mo_start, \
            f"P48: PlayerScreenEdgeBounds end boundary not found after MoveObject"

        if P48_MODE == "c":
            # Stage 2c: replace MoveObject with a single tail-jmp to the
            # C shim. Keeps the global label so every existing caller
            # (jsr MoveObject at z_07.asm:3137-3138 and elsewhere) still
            # resolves to a valid target. The shim marshals D2 → stack
            # and calls the C function; the C function's rts returns to
            # MoveObject's original caller via the shim.
            p48_body_text = (
                '    even\n'
                'MoveObject:\n'
                '; PATCH P48 BEGIN C-shim tail-jump (Stage 2c)\n'
                '    jmp     _c_move_object_shim\n'
                '; PATCH P48 END\n'
                '\n'
            )
            p48_body = p48_body_text.splitlines(keepends=True)
            lines[mo_start:mo_end] = p48_body
            print(f"  _patch_z07 P48: C-shim tail-jmp "
                  f"(replaced old block -> {len(p48_body)} lines)")
            # Skip the asm body emission below.
            P48_MODE_APPLIED = True
        else:
            P48_MODE_APPLIED = False

        if not P48_MODE_APPLIED:
            p48_body_text = (
                '    even\n'
                'MoveObject:\n'
                '; PATCH P48 BEGIN native walker chain (/mathproblem Phase 0)\n'
            '; D2 = object slot (0..11). Reads ($000F,A4) = direction bits.\n'
            '; Updates ObjX($70), ObjY($84), ObjGridOffset($0394),\n'
            '; ObjPosFrac($03A8); writes PositiveGridCellSize ($010E) and\n'
            '; NegativeGridCellSize ($010F). Clobbers D0/D1/D3/A0; preserves\n'
            '; D2/A4/A5. Returns with unspecified CCR (callers do not BCC).\n'
            ';\n'
            '; Addressing note: M68K (d,An,Dn.W) displacement is 8-bit\n'
            '; signed (-128..+127). ObjX at $70 fits directly; everything\n'
            '; beyond (ObjY $84, ObjGridOffset $394, ObjPosFrac $3A8,\n'
            '; ObjQSpeedFrac $3BC) must be reached via lea + (An,Dn.W).\n'
            '    ; Set grid-cell-size limits: slot 0 (Link) gets +8/-8, other\n'
            '    ; objects +16/-16.\n'
            '    tst.b   D2\n'
            '    bne.s   _L_z07_P48_nonlink\n'
            '    move.b  #$08,($010E,A4)\n'
            '    move.b  #$F8,($010F,A4)\n'
            '    bra.s   _L_z07_P48_chk_dir\n'
            '_L_z07_P48_nonlink:\n'
            '    move.b  #$10,($010E,A4)\n'
            '    move.b  #$F0,($010F,A4)\n'
            '_L_z07_P48_chk_dir:\n'
            '    ; Direction == 0: bail.\n'
            '    move.b  ($000F,A4),D0\n'
            '    beq     _L_z07_P48_exit\n'
            '    ; Apply quarter-speed 4 times. The first three bsrs return\n'
            '    ; back here; the fourth call is the fall-through into the\n'
            '    ; shared body, whose rts returns to MoveObject\'s caller.\n'
            '    bsr     _L_z07_P48_apply\n'
            '    bsr     _L_z07_P48_apply\n'
            '    bsr     _L_z07_P48_apply\n'
            '    ; fall through\n'
            '_L_z07_P48_apply:\n'
            '    ; Dispatch on direction bit. NES layout: bit0=R, bit1=L,\n'
            '    ; bit2=D, bit3=U. LSR chain matches NES @ApplyQSpeedToPosition.\n'
            '    move.b  ($000F,A4),D0\n'
            '    lsr.b   #1,D0\n'
            '    bcs.s   _L_z07_P48_right\n'
            '    lsr.b   #1,D0\n'
            '    bcs.s   _L_z07_P48_left\n'
            '    lsr.b   #1,D0\n'
            '    bcs.s   _L_z07_P48_down\n'
            '    ; Up: inline SubQSpeed, apply to ObjY.\n'
            '    bsr     _L_z07_P48_sub_qspeed\n'
            '    lea     ($0084,A4),A0\n'
            '    sub.b   D1,(A0,D2.W)\n'
            '    rts\n'
            '_L_z07_P48_down:\n'
            '    bsr     _L_z07_P48_add_qspeed\n'
            '    lea     ($0084,A4),A0\n'
            '    add.b   D1,(A0,D2.W)\n'
            '    rts\n'
            '_L_z07_P48_right:\n'
            '    bsr     _L_z07_P48_add_qspeed\n'
            '    add.b   D1,($0070,A4,D2.W)       ; $70 fits in 8-bit disp\n'
            '    rts\n'
            '_L_z07_P48_left:\n'
            '    bsr     _L_z07_P48_sub_qspeed\n'
            '    sub.b   D1,($0070,A4,D2.W)\n'
            '    rts\n'
            '_L_z07_P48_exit:\n'
            '    rts\n'
            '    ; --- Inlined AddQSpeedToPositionFraction ---\n'
            '    ; ObjPosFrac[D2] += ObjQSpeedFrac[D2] (plain add — no CLC).\n'
            '    ; D1 = 1 if fractional add overflowed, else 0. Limit check\n'
            '    ; against Positive/NegativeGridCellSize forces D1 = 0 (no\n'
            '    ; step) when ObjGridOffset is already at a limit. Applies\n'
            '    ; D1 to ObjGridOffset[D2]. Caller applies D1 to ObjX or ObjY.\n'
            '_L_z07_P48_add_qspeed:\n'
            '    lea     ($03A8,A4),A0             ; ObjPosFrac base\n'
            '    move.b  (A0,D2.W),D0              ; D0 = ObjPosFrac[D2]\n'
            '    lea     ($03BC,A4),A0             ; ObjQSpeedFrac base\n'
            '    add.b   (A0,D2.W),D0              ; D0 += ObjQSpeedFrac[D2]  <-- C set here\n'
            '    scs     D1                        ; capture C IMMEDIATELY before it gets clobbered\n'
            '    andi.b  #$01,D1                   ; D1 = 1 or 0\n'
            '    lea     ($03A8,A4),A0\n'
            '    move.b  D0,(A0,D2.W)              ; store ObjPosFrac[D2] (clobbers C, safe now)\n'
            '    lea     ($0394,A4),A0             ; ObjGridOffset base\n'
            '    move.b  (A0,D2.W),D3              ; D3 = ObjGridOffset[D2]\n'
            '    cmp.b   ($010E,A4),D3             ; D3 == PositiveGridCellSize?\n'
            '    beq.s   _L_z07_P48_add_clear\n'
            '    cmp.b   ($010F,A4),D3             ; D3 == NegativeGridCellSize?\n'
            '    bne.s   _L_z07_P48_add_apply\n'
            '_L_z07_P48_add_clear:\n'
            '    moveq   #0,D1                     ; at limit → no step\n'
            '_L_z07_P48_add_apply:\n'
            '    add.b   D1,(A0,D2.W)              ; ObjGridOffset[D2] += D1\n'
            '    rts\n'
            '    ; --- Inlined SubQSpeedFromPositionFraction ---\n'
            '    ; ObjPosFrac[D2] -= ObjQSpeedFrac[D2] (plain sub — no SEC).\n'
            '    ; D1 = 1 if underflow (step taken), else 0. Limit check\n'
            '    ; force-zeroes D1 when at a boundary.\n'
            '    ; CRITICAL: scs must run IMMEDIATELY after sub.b; any\n'
            '    ; intervening move.b/moveq clobbers the C flag.\n'
            '_L_z07_P48_sub_qspeed:\n'
            '    lea     ($03A8,A4),A0\n'
            '    move.b  (A0,D2.W),D0\n'
            '    lea     ($03BC,A4),A0\n'
            '    sub.b   (A0,D2.W),D0              ; C = 1 if borrow (step taken)\n'
            '    scs     D1                        ; capture borrow IMMEDIATELY\n'
            '    andi.b  #$01,D1                   ; D1 = 1 (step) or 0 (no step)\n'
            '    lea     ($03A8,A4),A0\n'
            '    move.b  D0,(A0,D2.W)              ; store (safe to clobber C now)\n'
            '    lea     ($0394,A4),A0\n'
            '    move.b  (A0,D2.W),D3\n'
            '    cmp.b   ($010E,A4),D3\n'
            '    beq.s   _L_z07_P48_sub_clear\n'
            '    cmp.b   ($010F,A4),D3\n'
            '    bne.s   _L_z07_P48_sub_apply\n'
            '_L_z07_P48_sub_clear:\n'
            '    moveq   #0,D1\n'
            '_L_z07_P48_sub_apply:\n'
            '    sub.b   D1,(A0,D2.W)\n'
            '    rts\n'
            '; PATCH P48 END native walker chain\n'
            '\n'
            )
            p48_body = p48_body_text.splitlines(keepends=True)
            lines[mo_start:mo_end] = p48_body
            print(f"  _patch_z07 P48: native MoveObject + inlined q-speed "
                  f"(replaced old block -> {len(p48_body)} lines)")

    # ---- Patch 1: Wire PPU scroll to VDP VSRAM ----
    # After the NMI handler's SetScroll block writes CurHScroll/CurVScroll
    # to PPU shadows, call _apply_genesis_scroll to push them to VDP VSRAM.
    # This only runs when SetScroll executes (game modes 0,5,9,$B,$C,$13 with
    # $0011!=0).  During init frames when NMI is gated or SetScroll is skipped,
    # VSRAM retains its previous value — matching NES behavior where scroll
    # doesn't change when PPU rendering is disabled.
    text = ''.join(lines)
    old_scroll = (
        '    move.b  ($00FF,A4),D0\n'
        '    bsr     _ppu_write_0  ; PPU $2000 write, D0=val\n'
        '    even\n'
        '_L_z07_IsrNmi_UpdateTimers:'
    )
    new_scroll = (
        '    move.b  ($00FF,A4),D0\n'
        '    bsr     _ppu_write_0  ; PPU $2000 write, D0=val\n'
        '    bsr     _apply_genesis_scroll  ; Apply scroll shadows to VDP VSRAM/H-scroll\n'
        '    even\n'
        '_L_z07_IsrNmi_UpdateTimers:'
    )
    if old_scroll in text:
        text = text.replace(old_scroll, new_scroll, 1)
        print("  _patch_z07 P1: added _apply_genesis_scroll after SetScroll")
    else:
        print("  WARNING: _patch_z07 P1 -- SetScroll pattern not found")

    # P2: Add a second _apply_genesis_scroll in EnableNMI (after game logic).
    # Game logic updates CurVScroll and sets SwitchNameTablesReq ($005C) AFTER
    # SetScroll runs, so the P1 call sees stale values.  This second call at
    # EnableNMI picks up the latest scroll state.  The pre-toggle in
    # _apply_genesis_scroll reads $005C (not yet cleared — that happens in
    # next frame's TransferCurTileBuf) and anticipates the NT flip.
    old_enablenmi = (
        '    bsr     _ppu_write_0  ; PPU $2000 write, D0=val\n'
        '    move.b  D0,($00FF,A4)\n'
        '    rts   ; RTI'
    )
    new_enablenmi = (
        '    bsr     _ppu_write_0  ; PPU $2000 write, D0=val\n'
        '    move.b  D0,($00FF,A4)\n'
        '    bsr     _apply_genesis_scroll  ; P2: re-apply scroll after game logic\n'
        '    rts   ; RTI'
    )
    if old_enablenmi in text:
        text = text.replace(old_enablenmi, new_enablenmi, 1)
        print("  _patch_z07 P2: added _apply_genesis_scroll in EnableNMI")
    else:
        print("  WARNING: _patch_z07 P2 -- EnableNMI pattern not found")

    # P3: Clear SwitchNameTablesReq ($005C) immediately after IsrNmi consumes it.
    # On NES the toggle request is implicitly one-shot (the code path that sets
    # it runs only when a toggle is wanted).  Transpiled to M68K the flag lingers
    # until z_06 TransferCurTileBuf finally clears it — several frames too late.
    # Meanwhile _apply_genesis_scroll (called by P1 *inside* IsrNmi right after
    # the PPU $2000 write) polls $005C in _ags_compute_stage to "anticipate" a
    # toggle; because the flag is still set, it pre-toggles a second time on a
    # $00FF value that IsrNmi just finished toggling — a double flip.  Clearing
    # the flag right after IsrNmi XORs the PPU shadow restores one-shot NES
    # semantics and prevents the double-toggle contamination.
    old_isrnmi_clear = (
        '    moveq   #0,D2\n'
        '    move.b  ($005C,A4),D2\n'
        '    beq  _anon_z07_0\n'
        '    eori.b #$02,D0\n'
        '_anon_z07_0:\n'
        '    andi.b #$7F,D0'
    )
    new_isrnmi_clear = (
        '    moveq   #0,D2\n'
        '    move.b  ($005C,A4),D2\n'
        '    beq  _anon_z07_0\n'
        '    eori.b #$02,D0\n'
        '_anon_z07_0:\n'
        '    clr.b   ($005C,A4)  ; PATCH P3: clear NMI NT toggle request flag\n'
        '    andi.b #$7F,D0'
    )
    if old_isrnmi_clear in text:
        text = text.replace(old_isrnmi_clear, new_isrnmi_clear, 1)
        print("  _patch_z07 P3: cleared $005C one-shot after IsrNmi consumes it")
    else:
        print("  WARNING: _patch_z07 P3 -- IsrNmi $005C read block not found")

    # ------------------------------------------------------------------
    # P4 (T38): preserve X flag across the RNG scramble loop's index ops.
    # The 6502 @LoopRandom uses ROR $00,X to chain a carry bit through 13
    # consecutive bytes ($18..$24). ROR maps to `roxr.b` on M68K, which uses
    # the X flag as the carry. The subsequent `addq.b #1,D2` / `subq.b #1,D3`
    # both clobber X, so bytes 1..7 of Random get 0 rotated in from the top
    # every NMI — all enemy slots end up reading Random[X>=1] = $00 and every
    # Octorok makes the same turn each frame. See patches/z_07_patch_rng.md.
    # ------------------------------------------------------------------
    old_rng = (
        '_L_z07_IsrNmi_LoopRandom:\n'
        '    move.b  ($00,A4,D2.W),D1\n'
        '    roxr.b  #1,D1   ; ROR $00,X\n'
        '    move.b  D1,($00,A4,D2.W)\n'
        '    addq.b  #1,D2\n'
        '    subq.b  #1,D3\n'
        '    bne  _L_z07_IsrNmi_LoopRandom'
    )
    new_rng = (
        '_L_z07_IsrNmi_LoopRandom:\n'
        '    move.b  ($00,A4,D2.W),D1\n'
        '    roxr.b  #1,D1   ; ROR $00,X\n'
        '    scs     D6             ; P4: save C (= rotated-out bit) *before* move clears it\n'
        '    move.b  D1,($00,A4,D2.W)\n'
        '    addq.b  #1,D2\n'
        '    subq.b  #1,D3\n'
        '    add.b   D6,D6          ; P4: restore X from D6 ($FF -> X=1, $00 -> X=0)\n'
        '    tst.b   D3             ; P4: re-set Z for loop branch\n'
        '    bne  _L_z07_IsrNmi_LoopRandom'
    )
    if old_rng in text:
        text = text.replace(old_rng, new_rng, 1)
        print("  _patch_z07 P4: RNG scramble loop X-flag preservation")
    else:
        print("  WARNING: _patch_z07 P4 -- RNG scramble loop pattern not found")

    # ------------------------------------------------------------------
    # P37 (DEBUG_TELEPORT): insert DPAD instant-teleport hook at the top
    # of `UpdateMode` (the mode-dispatch trampoline called every frame).
    # The routine `_debug_teleport_check` in genesis_shell.asm gates on
    # CurLevel==0, GameMode==$05, SubMode==$00 internally so placing
    # this hook one layer up (before table-jump) is safe: if it isn't
    # overworld-idle, the routine returns D0=0 and we fall through to
    # the normal dispatch.
    #
    # Previous placement inside `_L_z07_UpdateMode5Play_NotInMenu` never
    # fired because `UpdateMode` in this port sets IsUpdatingMode=1
    # mid-frame for mode transitions, so the "Update" table's
    # UpdateMode5Play entry rarely executes even at idle. Hooking before
    # the table-jump guarantees every frame is checked.
    # See src/zelda_translated/patches/z_07_patch_P37_debug_teleport.md.
    # ------------------------------------------------------------------
    # Anchor on the preceding `even` directive so the match can't drift
    # to `RunCrossRoomTasksAndBeginUpdateMode:` (which contains the
    # substring `UpdateMode:` but different body).
    # Hook in both InitMode and UpdateMode dispatchers so the teleport
    # check fires every frame regardless of IsUpdatingMode. When a DPAD
    # transition flips isupd mid-frame, only one of the two runs per
    # frame — covering both guarantees one fires in overworld idle.
    # Fresh transpile emits `bsr SwitchBank`; _promote_nonlocal_bsr_to_jsr
    # runs AFTER this patch and converts to `jsr`. Anchor on `bsr`.
    def _p37_hook(label, anchor_bank):
        """Build old/new text pair for a mode dispatcher label."""
        old = (
            '    even\n'
            f'{label}:\n'
            f'    moveq   #{anchor_bank},D0\n'
            '    bsr     SwitchBank\n'
        )
        new = (
            '    even\n'
            f'{label}:\n'
            '    ifne DEBUG_TELEPORT\n'
            f'    jsr     _debug_teleport_check      ; PATCH P37: DPAD teleport ({label})\n'
            '    tst.b   D0\n'
            f'    beq.s   _L_z07_{label}_noTp\n'
            '    rts\n'
            f'_L_z07_{label}_noTp:\n'
            '    endc\n'
            f'    moveq   #{anchor_bank},D0\n'
            '    bsr     SwitchBank\n'
        )
        return old, new

    for label, bank in (("UpdateMode", 2), ("InitMode", 5)):
        old, new = _p37_hook(label, bank)
        if old in text:
            text = text.replace(old, new, 1)
            print(f"  _patch_z07 P37: DEBUG_TELEPORT hook in {label}")
        else:
            print(f"  WARNING: _patch_z07 P37 -- {label} anchor not found")

    # ------------------------------------------------------------------
    # P39 (TURBO_LINK): insert jsr _turbo_link_boost after Walker_Move
    # in UpdatePlayer so Link gets +7 px/frame per held DPAD direction
    # on top of the normal 1 px collision-aware step. The boost lives in
    # genesis_shell.asm gated by TURBO_LINK; flag=0 strips the routine.
    # ------------------------------------------------------------------
    # P39 (TURBO_LINK): insert jsr _turbo_link_boost in UpdatePlayer.
    p39_applied = False
    for lhi in ('jsr', 'bsr'):
        for wm in ('jsr', 'bsr'):
            old = f'    {lhi}     Link_HandleInput\n    {wm}     Walker_Move\n'
            if old in text:
                new = (
                    old +
                    '    ifne TURBO_LINK\n'
                    '    jsr     _turbo_link_boost   ; PATCH P39: turbo Link speed boost\n'
                    '    endc\n'
                )
                text = text.replace(old, new, 1)
                print(f"  _patch_z07 P39: TURBO_LINK boost ({lhi}/{wm})")
                p39_applied = True
                break
        if p39_applied:
            break
    if not p39_applied:
        print("  WARNING: _patch_z07 P39 -- Link_HandleInput/Walker_Move anchor not found")

    # ------------------------------------------------------------------
    # P40 (TURBO_LINK no-clip): make Walker_CheckTileCollision a no-op
    # for Link (slot 0, D2 == 0) so tile collision never stops him.
    # Enemy collision behaviour is preserved (D2 != 0 paths untouched).
    # Only fires while TURBO_LINK is enabled.
    # ------------------------------------------------------------------
    p40_old = (
        'Walker_CheckTileCollision:\n'
        '    cmpi.b  #$00,D2\n'
    )
    p40_new = (
        'Walker_CheckTileCollision:\n'
        '    ; PATCH P40 (v2): no-clip moved to CheckTiles; see further\n'
        '    ; down in the file. Walker_CheckTileCollision runs its\n'
        '    ; normal bookkeeping (DoorwayDir / grid-offset / state\n'
        '    ; reset) for Link and every other object. Only the tile\n'
        '    ; walkability decision in CheckTiles is overridden.\n'
        '    cmpi.b  #$00,D2\n'
    )
    if p40_old in text:
        text = text.replace(p40_old, p40_new, 1)
        print("  _patch_z07 P40: TURBO_LINK no-clip in Walker_CheckTileCollision")
    else:
        print("  WARNING: _patch_z07 P40 -- Walker_CheckTileCollision anchor not found")

    # ------------------------------------------------------------------
    # P40b (TURBO_LINK no-clip, cleaner): in CheckTiles, if D2==0 (Link)
    # jump directly to GoWalkableDir, bypassing the actual tile fetch +
    # walkability compare. All of Walker_CheckTileCollision's pre-check
    # bookkeeping (DoorwayDir / grid-offset / $0E reset) still runs
    # untouched; only the walkability decision is overridden. This
    # avoids the $73 freeze that the old short-circuit P40 caused.
    # ------------------------------------------------------------------
    p40b_old = (
        'CheckTiles:\n'
        '    ; The code below applies to Link and other objects.\n'
    )
    p40b_new = (
        'CheckTiles:\n'
        '    ifne TURBO_LINK\n'
        '    ; PATCH P40b: Link no-clip — always treat target tile as\n'
        '    ; walkable. Pre-seeds ObjCollidedTile[0] ($049E) to $24.\n'
        '    tst.b   D2\n'
        '    bne.s   _L_z07_CheckTiles_notLink\n'
        '    move.b  #$24,($049E,A4)\n'
        '    jmp     GoWalkableDir\n'
        '_L_z07_CheckTiles_notLink:\n'
        '    endc\n'
        '    ; The code below applies to Link and other objects.\n'
    )
    if p40b_old in text:
        text = text.replace(p40b_old, p40b_new, 1)
        print("  _patch_z07 P40b: TURBO_LINK no-clip via CheckTiles short-circuit")
    else:
        print("  WARNING: _patch_z07 P40b -- CheckTiles anchor not found")

    # ------------------------------------------------------------------
    # P43 (Codex): Gate InitObject's edge-spawn overwrite on first frame
    # of a fresh room entry when the slot already has a residual position
    # from a previous room. Matches NES t=0 behavior in rooms like $73.
    #
    # NES enters edge-spawn rooms with $004B (MonstersFromEdgesLongTimer)
    # non-zero (leftover from earlier edge-spawn rooms) or one prescaler
    # tick from decrement, so UninitMonsterFromEdge hits the "gate" path
    # and leaves the enemy's previous-room position intact. The timer
    # itself does decrement — via the NMI sweep at z_07 _L_z07_IsrNmi_Update-
    # Timers ($26 prescaler; when $26 underflows, resets to 9 and
    # decrements $27..$4E, which includes $004B).
    #
    # Gen enters room $73 with $004B == 0 because its NMI/mode timing
    # differs slightly. Every slot's InitObject call then falls through
    # to InitMonsterFromEdge and overwrites the SpawnPosList placement
    # with an edge cell (Y=$DD, stuck because the tile there is
    # unwalkable).
    #
    # This patch, when $004B == 0, checks whether:
    #   [000F] == $FF  (fresh room entry: UpdateObject saves the original
    #                   Uninit flag there at z_07:5244)
    #   ObjX[slot] != 0 OR ObjY[slot] != 0  (has residual position)
    # If both hold, seed $004B = 1 and Uninit[slot] = 1, then RTS —
    # preserving the residual position for this frame. Otherwise the
    # original edge-spawn path runs (first-time rooms without residuals
    # still get a legitimate edge placement).
    # ------------------------------------------------------------------
    p43_old = (
        '_L_z07_InitObject_UninitMonsterFromEdge:\n'
        '    ; If the "monsters from edges" long timer expired, then\n'
        '    ; go bring the monster in.\n'
        '    ; Else revert the flag, so this monster becomes uninitialized.\n'
        '    ;\n'
        '    move.b  ($004B,A4),D0\n'
        '    beq  _L_z07_InitObject_InitMonsterFromEdge\n'
        '    lea     ($0492,A4),A0\n'
        '    move.b  D0,(A0,D2.W)\n'
        '    rts\n'
    )
    p43_new = (
        '_L_z07_InitObject_UninitMonsterFromEdge:\n'
        '    ; If the "monsters from edges" long timer expired, then\n'
        '    ; go bring the monster in.\n'
        '    ; Else revert the flag, so this monster becomes uninitialized.\n'
        '    ;\n'
        '    ; PATCH P43 (Codex): extra gate on fresh room-entry with\n'
        '    ; residual position so enemies keep their previous-room\n'
        '    ; positions instead of being re-edge-spawned (matches NES).\n'
        '    move.b  ($004B,A4),D0\n'
        '    bne     _L_z07_InitObject_UninitMonsterFromEdge_Gate\n'
        '    ; timer == 0. Check for fresh room-entry + residual position.\n'
        '    move.b  ($000F,A4),D0\n'
        '    cmpi.b  #$FF,D0\n'
        '    bne     _L_z07_InitObject_InitMonsterFromEdge\n'
        '    lea     ($0070,A4),A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    bne     _L_z07_InitObject_UninitMonsterFromEdge_Seed\n'
        '    lea     ($0084,A4),A0\n'
        '    move.b  (A0,D2.W),D0\n'
        '    beq     _L_z07_InitObject_InitMonsterFromEdge\n'
        '    even\n'
        '_L_z07_InitObject_UninitMonsterFromEdge_Seed:\n'
        '    moveq   #1,D0\n'
        '    move.b  D0,($004B,A4)\n'
        '    lea     ($0492,A4),A0\n'
        '    move.b  D0,(A0,D2.W)\n'
        '    rts\n'
        '    even\n'
        '_L_z07_InitObject_UninitMonsterFromEdge_Gate:\n'
        '    lea     ($0492,A4),A0\n'
        '    move.b  D0,(A0,D2.W)\n'
        '    rts\n'
    )
    if p43_old in text:
        text = text.replace(p43_old, p43_new, 1)
        print("  _patch_z07 P43: Codex UninitMonsterFromEdge residual-position gate")
    else:
        print("  WARNING: _patch_z07 P43 -- UninitMonsterFromEdge anchor not found")

    # ------------------------------------------------------------------
    # P47: Anti-bottom-edge snap. Before each edge-spawn walk, if
    # $0525 (CurEdgeSpawnCell) is on the bottom edge (hi-nibble == $E),
    # reset it to $48 (top-edge cell, mid-screen).
    #
    # FindNextEdgeSpawnCell walks CCW from $0525 and can land at bottom-
    # edge cells like $E5/$EB. Enemies placed there at Y=$DD are outside
    # RoomBoundDown ($CD) and their UP tile check fails ($C5 unwalkable)
    # so they can never enter the playfield. Forcing a snap-to-top when
    # the cursor is on the bottom edge guarantees subsequent spawns come
    # in from the top where Y=$3D is walkable downward.
    # ------------------------------------------------------------------
    p47_old = (
        '_L_z07_InitObject_InitMonsterFromEdge:\n'
        '    moveq   #0,D2\n'
        '    move.b  ($0340,A4),D2\n'
        '    moveq   #5,D0\n'
        '    bsr     SwitchBank\n'
        '    bsr     FindNextEdgeSpawnCell\n'
    )
    p47_new = (
        '_L_z07_InitObject_InitMonsterFromEdge:\n'
        '    moveq   #0,D2\n'
        '    move.b  ($0340,A4),D2\n'
        '    ; PATCH P47: pre- and post-walk $0525 validation + walkability.\n'
        '    ; Pre: snap OOB (hi < $40 or hi >= $E0) to $48.\n'
        '    ; Post1: if result hi=$E (bottom edge), redo from $48.\n'
        '    ; Post2: read chosen cell\'s tile; if unwalkable (>= $84),\n'
        '    ; rotate through FallbackCells until walkable or bail to $48.\n'
        '    ; (Debug instrumentation at $FF0500/0501/0508/050E/050F/0510\n'
        '    ; was removed 2026-04-19 — it aliased $0510..$054F which\n'
        '    ; overlaps BrighteningRoom ($051E) and CandleState ($051F),\n'
        '    ; corrupting them and causing a deterministic address-error\n'
        '    ; freeze at room $73 ~240 frames after entry. Root cause\n'
        '    ; identified by Codex static review.)\n'
        '_L_z07_P47_pre_check:\n'
        '    move.b  ($0525,A4),D0\n'
        '    andi.b  #$F0,D0\n'
        '    cmpi.b  #$40,D0\n'
        '    blo     _L_z07_P47_pre_snap\n'
        '    cmpi.b  #$E0,D0\n'
        '    blo     _L_z07_P47_pre_ok\n'
        '_L_z07_P47_pre_snap:\n'
        '    move.b  #$48,($0525,A4)\n'
        '_L_z07_P47_pre_ok:\n'
        '    moveq   #5,D0\n'
        '    bsr     SwitchBank\n'
        '    bsr     FindNextEdgeSpawnCell\n'
        '    ; Post-walk 1: bottom-edge snap.\n'
        '    move.b  ($0525,A4),D0\n'
        '    andi.b  #$F0,D0\n'
        '    cmpi.b  #$E0,D0\n'
        '    bne     _L_z07_P47_post1_ok\n'
        '    move.b  #$48,($0525,A4)\n'
        '    bsr     FindNextEdgeSpawnCell\n'
        '_L_z07_P47_post1_ok:\n'
        '    ; Post-walk 2: validate resulting cell is walkable.\n'
        '    ; Playmap addr = $FF6530 + (lo * 44) + ((hi - 4) * 2).\n'
        '    moveq   #0,D3\n'
        '    move.b  ($0525,A4),D3\n'
        '    andi.w  #$000F,D3\n'
        '    mulu.w  #44,D3\n'
        '    move.l  #$FF6530,D0\n'
        '    add.l   D3,D0\n'
        '    moveq   #0,D3\n'
        '    move.b  ($0525,A4),D3\n'
        '    lsr.w   #4,D3\n'
        '    subi.w  #4,D3\n'
        '    lsl.w   #1,D3\n'
        '    add.l   D3,D0\n'
        '    movea.l D0,A0\n'
        '    move.b  (A0),D0\n'
        '    cmpi.b  #$84,D0\n'
        '    blo     _L_z07_P47_post2_ok\n'
        '    ; Unwalkable — pick from fallback table, scan up to 8 tries.\n'
        '    ; Local counter lives in D4.b (caller-clobberable); no RAM\n'
        '    ; writes to the $05xx region.\n'
        '    moveq   #0,D4\n'
        '_L_z07_P47_fb_loop:\n'
        '    lea     _L_z07_P47_FallbackCells(pc),A0\n'
        '    move.b  (A0,D4.W),D1\n'
        '    move.b  D1,($0525,A4)\n'
        '    ; Validate fallback cell walkable.\n'
        '    moveq   #0,D3\n'
        '    move.b  D1,D3\n'
        '    andi.w  #$000F,D3\n'
        '    mulu.w  #44,D3\n'
        '    move.l  #$FF6530,D0\n'
        '    add.l   D3,D0\n'
        '    moveq   #0,D3\n'
        '    move.b  D1,D3\n'
        '    lsr.w   #4,D3\n'
        '    subi.w  #4,D3\n'
        '    lsl.w   #1,D3\n'
        '    add.l   D3,D0\n'
        '    movea.l D0,A0\n'
        '    cmpi.b  #$84,(A0)\n'
        '    blo     _L_z07_P47_post2_ok\n'
        '    addq.b  #1,D4\n'
        '    cmpi.b  #8,D4\n'
        '    blo     _L_z07_P47_fb_loop\n'
        '    ; All 8 fallback cells unwalkable — just use $48 (fails gracefully\n'
        '    ; rather than looping).\n'
        '    move.b  #$48,($0525,A4)\n'
        '_L_z07_P47_post2_ok:\n'
    )
    if p47_old in text:
        text = text.replace(p47_old, p47_new, 1)
        print("  _patch_z07 P47: anti-bottom-edge snap for CurEdgeSpawnCell")
    else:
        print("  WARNING: _patch_z07 P47 -- InitMonsterFromEdge anchor not found")

    # P47 fallback-cell table: 8 candidate top-edge cells. Cycling prevents
    # clustering. All are walkable on room $73 (verified 2026-04-18 via raw
    # playmap dump). For other rooms, most should be walkable; P47's own
    # tile validation on the chosen cell provides a second safety check.
    p47_table_marker = "_L_z05_FindNextEdgeSpawnCell_GetRowOffset:"
    p47_table = (
        "\n    even\n"
        "_L_z07_P47_FallbackCells:\n"
        "    dc.b $47, $48, $49, $4B, $4D, $49, $48, $47\n\n"
    )
    # Inject the table just before Obj_Shove definition so it's in bank 7
    # and reachable by the InitMonsterFromEdge code via PC-relative LEA.
    p47_table_anchor = "    even\nObj_Shove:\n"
    if p47_table_anchor in text and p47_table.strip() not in text:
        text = text.replace(p47_table_anchor, p47_table + p47_table_anchor, 1)
        print("  _patch_z07 P47: FallbackCells table injected")

    # --- Stage 4b batch 4: z_07 C function stubs ---
    text = _stub_func(text, 'HideAllSprites', 'c_hide_all_sprites')
    text = _stub_func(text, 'GetUniqueRoomId', 'c_get_unique_room_id')

    # --- Stage 4b batch 5: more z_07 C function stubs ---
    text = _stub_func(text, 'ClearRoomHistory', 'c_clear_room_history')
    text = _stub_func(text, 'ResetPlayerState', 'c_reset_player_state')
    text = _stub_func(text, 'ResetMovingDir', 'c_reset_moving_dir')
    text = _stub_func(text, 'EnsureObjectAligned', 'c_ensure_object_aligned')

    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def main():
    parser = argparse.ArgumentParser(description='6502 → M68K ASM transpiler')
    parser.add_argument('--bank', type=int, default=7,
                        help='Bank number to transpile (default: 7)')
    parser.add_argument('--all', action='store_true',
                        help='Transpile all 8 banks (T3)')
    parser.add_argument('--standalone', action='store_true',
                        help='Emit org $C000 for isolated assembly testing (T2/T3)')
    parser.add_argument('--no-stubs', action='store_true',
                        help='Skip NES I/O stubs — nes_io.asm provides real implementations (T5+)')
    args = parser.parse_args()

    os.makedirs(OUT_DIR, exist_ok=True)

    if args.all:
        banks = range(8)
    else:
        banks = [args.bank]

    try:
        nes_addr_maps = {b: build_nes_address_map(b) for b in banks}
        if args.all:
            _validate_nes_address_maps(nes_addr_maps)
        all_nes_addrs = {}
        for b in sorted(nes_addr_maps.keys()):
            all_nes_addrs.update(nes_addr_maps[b])
    except Exception as exc:
        print(f"ERROR: strict NES address prepass failed: {exc}")
        sys.exit(1)

    # In --all mode: pre-collect exports from all banks so stubs for cross-bank
    # symbols can be suppressed (the other banks will define them) and duplicate
    # label definitions can be IFND-guarded (only first-included bank keeps label).
    if args.all:
        bank_exports = {b: collect_exports_from_source(b) for b in range(8)}
        all_exports = set().union(*bank_exports.values())
        # Symbols exported from 2+ banks → need IFND guard on label definitions
        from collections import Counter
        exp_counts = Counter(sym for exps in bank_exports.values() for sym in exps)
        dup_exports = {sym for sym, cnt in exp_counts.items() if cnt > 1}
    else:
        bank_exports = {}
        all_exports = set()
        dup_exports = set()

    ok = True
    for b in banks:
        if args.all:
            other_exports = all_exports - bank_exports.get(b, set())
        else:
            other_exports = set()
        ok = transpile_bank(b, standalone=args.standalone,
                            no_stubs=args.no_stubs,
                            no_import_stubs=args.all,
                            other_exports=other_exports,
                            dup_exports=dup_exports,
                            all_nes_addrs=all_nes_addrs,
                            bank_nes_addrs=nes_addr_maps.get(b, {})) and ok

    if ok and args.all:
        try:
            _audit_bank_window_coverage()
            _audit_isrvector_dead_code()
            print("Transpiler audits passed (coverage + dead-vector).")
        except Exception as exc:
            print(f"ERROR: transpiler audit failed: {exc}")
            ok = False

    if ok:
        print("Transpiler done.")
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
