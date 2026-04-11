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
                    other_exports=None, dup_exports=None):
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

            if uline.startswith('.ADDR'):
                data_str = stripped[5:].strip()
                data_str = re.sub(r'\s*;.*$', '', data_str)
                if in_jump_table[0]:
                    # Jump table entry: _m68k_tablejump reads dc.l (32-bit M68K addresses)
                    emit(f'    dc.l    {data_str}   ; jump table entry (32-bit for _m68k_tablejump)')
                else:
                    # Data pointer table: NES .ADDR is 16-bit little-endian (lo byte first).
                    # Emit dc.b to preserve NES byte order; M68K dc.w would
                    # big-endian-swap and break byte-indexed table reads.
                    emit(f'    dc.b    ({data_str})&$FF, ({data_str}>>8)&$FF   ; NES .ADDR (little-endian)')
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
        if mode == 'IMM':
            e(f'    move.b  #${val:02X},D1')
            e(f'    subx.b  D1,D0   ; SBC #${val:02X}')
        elif mode == 'ABS':
            gen_read('D1', val)
            e(f'    subx.b  D1,D0   ; SBC {val}')
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
        # After any branch, reset carry state (branch target may come from any path)
        carry_state['inverted'] = False

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
        e('    rts')

    elif mnem == 'RTI':
        # On NES, RTI returns from NMI/IRQ (pops P,PCL,PCH).
        # On Genesis, IsrNmi is called via BSR/JSR from VBlankISR (not via exception).
        # VBlankISR owns the RTE. IsrNmi must end with RTS.
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
                   other_exports=None, dup_exports=None):
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
                                 dup_exports=dup_exports)

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


def _patch_z00(path):
    """Post-process patches for z_00.asm — NOP DriveAudio.

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
    old_tbl = ('DemoPatternBlockAddrs:\n'
               '    dc.b    (DemoSpritePatterns)&$FF, (DemoSpritePatterns>>8)&$FF   ; NES .ADDR (little-endian)\n'
               '    dc.b    (DemoBackgroundPatterns)&$FF, (DemoBackgroundPatterns>>8)&$FF   ; NES .ADDR (little-endian)')
    new_tbl = ('DemoPatternBlockAddrs:\n'
               '    dc.l    DemoSpritePatterns        ; 32-bit Genesis ROM address\n'
               '    dc.l    DemoBackgroundPatterns     ; 32-bit Genesis ROM address')
    if old_tbl in text:
        text = text.replace(old_tbl, new_tbl, 1)
        print("  _patch_z01 P0: DemoPatternBlockAddrs dc.b -> dc.l")
    else:
        print("  WARNING: _patch_z01 P0 -- table not found")

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
    old_tbl = ('CommonPatternBlockAddrs:\n'
               '    dc.b    (CommonSpritePatterns)&$FF, (CommonSpritePatterns>>8)&$FF   ; NES .ADDR (little-endian)\n'
               '    dc.b    (CommonBackgroundPatterns)&$FF, (CommonBackgroundPatterns>>8)&$FF   ; NES .ADDR (little-endian)\n'
               '    dc.b    (CommonMiscPatterns)&$FF, (CommonMiscPatterns>>8)&$FF   ; NES .ADDR (little-endian)')
    new_tbl = ('CommonPatternBlockAddrs:\n'
               '    dc.l    CommonSpritePatterns       ; 32-bit Genesis ROM address\n'
               '    dc.l    CommonBackgroundPatterns    ; 32-bit Genesis ROM address\n'
               '    dc.l    CommonMiscPatterns          ; 32-bit Genesis ROM address')
    if old_tbl in text:
        text = text.replace(old_tbl, new_tbl, 1)
        print("  _patch_z02 P0: CommonPatternBlockAddrs dc.b -> dc.l")
    else:
        print("  WARNING: _patch_z02 P0 -- table not found")

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
    old_finish_input = (
        '_L_z02_ModeE_HandleDirectionButton_FinishInput:\n'
        '    moveq   #1,D0\n'
        '    move.b  D0,($0428,A4)\n'
        '    move.b  D0,($0602,A4)\n'
    )
    new_finish_input = (
        '_L_z02_ModeE_HandleDirectionButton_FinishInput:\n'
        '    jsr     ModeE_SyncCharBoardCursorToIndex  ; PATCH P13\n'
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
        '    addi.b  #$87,D1\n'
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

    # ---- Patch 15: Zelda16.12 -- SEC;SBC #$08 -1 fix at wrap site ----
    # Diary Finding #30.  Systemic SEC;SBC #imm transpile bug: the pattern
    # "ori #$11,CCR; subx.b D1,D0" subtracts imm+1 instead of imm because
    # the X flag is still set.  At this specific wrap site the 9th letter
    # ends up in column $CD instead of $CE.  Replace with a plain sub.b.
    # Anchored on the "$20D6 -> $20CE" comment to uniquely hit this site
    # without touching ModifyFlashingCursorY or ModeEandF_SetUpCursorSprites
    # (whose callers are tuned around the off-by-one, per diary scope note).
    old_sec_sbc_wrap = (
        '    ; For example, $20D6 -> $20CE.\n'
        '    ;\n'
        '    move.b  ($0423,A4),D0\n'
        '    ori     #$11,CCR  ; SEC: set C+X\n'
        '    move.b  #$08,D1\n'
        '    subx.b  D1,D0   ; SBC #$08\n'
        '    move.b  D0,($0423,A4)\n'
    )
    new_sec_sbc_wrap = (
        '    ; For example, $20D6 -> $20CE.\n'
        '    ;\n'
        '    move.b  ($0423,A4),D0  ; PATCH P15: Zelda16.12\n'
        '    sub.b   #$08,D0\n'
        '    move.b  D0,($0423,A4)\n'
    )
    if old_sec_sbc_wrap in text:
        text = text.replace(old_sec_sbc_wrap, new_sec_sbc_wrap, 1)
        print("  _patch_z02 P15: Zelda16.12 SEC;SBC -1 fix at wrap site")
    else:
        print("  WARNING: _patch_z02 P15 -- SEC;SBC wrap pattern not found")

    # ---- Patch 19: Phase 9.6 -- SEC;SBC -1 fix in Mode E direction handlers ----
    # Same systemic SEC;SBC transpile bug as P15, but in
    # _L_z02_ModeE_HandleDirectionButton_Up (idx -= $0B per Up press) and
    # the Down-wrap fixup (idx -= $2C when Down rolls past row 3).  Both
    # sites operate on CharBoardIndex [$041F], and P13's source-of-truth
    # sync makes the IDX off-by-one VISIBLE because P13 derives ObjX/ObjY
    # from idx after the move.
    #
    # Symptoms in tools/bizhawk_fs2_keyboard.lua before fix:
    #   - Every Up press shifts col -1 (idx -= 12 instead of -11) → diagonal
    #   - Down from row 3 col 0 wraps to row 0 col 9 (idx -= 45 instead of
    #     -44 → 255 → P13 hidden-slot snap to 9)
    #
    # Sites kept narrow: this does NOT touch the Left ObjX SEC;SBC at line
    # 2499-2503 (P13 overwrites ObjX from idx so the user never sees the
    # buggy x).  Only the two CharBoardIndex SEC;SBC instances are fixed.

    # P19a: Up move (idx -= $0B per Up press)
    old_up_idx_subx = (
        '    ; Decrease CharBoardIndex [$041F] by $B (one row up).\n'
        '    ;\n'
        '    move.b  ($041F,A4),D0\n'
        '    ori     #$11,CCR  ; SEC: set C+X\n'
        '    move.b  #$0B,D1\n'
        '    subx.b  D1,D0   ; SBC #$0B\n'
        '    move.b  D0,($041F,A4)\n'
    )
    new_up_idx_subx = (
        '    ; Decrease CharBoardIndex [$041F] by $B (one row up).\n'
        '    ;\n'
        '    move.b  ($041F,A4),D0  ; PATCH P19a: Phase 9.6 SEC;SBC -1 fix\n'
        '    sub.b   #$0B,D0\n'
        '    move.b  D0,($041F,A4)\n'
    )
    if old_up_idx_subx in text:
        text = text.replace(old_up_idx_subx, new_up_idx_subx, 1)
        print("  _patch_z02 P19a: SEC;SBC -1 fix in Up move (idx -= $0B)")
    else:
        print("  WARNING: _patch_z02 P19a -- Up SEC;SBC pattern not found")

    # P19b: Down wrap fixup (idx -= $2C when row3 -> row0)
    old_down_wrap_subx = (
        '    move.b  ($041F,A4),D0\n'
        '    ori     #$11,CCR  ; SEC: set C+X\n'
        '    move.b  #$2C,D1\n'
        '    subx.b  D1,D0   ; SBC #$2C\n'
        '    move.b  D0,($041F,A4)\n'
    )
    new_down_wrap_subx = (
        '    move.b  ($041F,A4),D0  ; PATCH P19b: Phase 9.6 SEC;SBC -1 fix\n'
        '    sub.b   #$2C,D0\n'
        '    move.b  D0,($041F,A4)\n'
    )
    if old_down_wrap_subx in text:
        text = text.replace(old_down_wrap_subx, new_down_wrap_subx, 1)
        print("  _patch_z02 P19b: SEC;SBC -1 fix in Down wrap (idx -= $2C)")
    else:
        print("  WARNING: _patch_z02 P19b -- Down wrap SEC;SBC pattern not found")

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

    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def _patch_z06(path):
    """Post-process patches for z_06.asm -- replace TransferTileBuf/ContinueTransferTileBuf.

    Replace the slow byte-by-byte tile buffer executor (ContinueTransferTileBuf
    calling _ppu_write_7 per byte) with a single call to _transfer_tilebuf_fast
    in nes_io.asm.  This is the main NMI cadence fix.
    """
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

    # ---- Patch 3: DynTileBuf palette pre-check in TransferCurTileBuf ----
    # Bug C fix: On NES, palette records in DynTileBuf are consumed before
    # TileBufSelector changes. On Genesis, timing difference can cause the
    # selector to be overwritten before NMI processes the palette. Fix: always
    # drain DynTileBuf palette records ($3F prefix) before normal dispatch.
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
                '    ; PATCHED: DynTileBuf palette pre-check (Bug C fix).\n'
                '    ; On NES, palette records in DynTileBuf are consumed before TileBufSelector\n'
                '    ; changes.  On Genesis, a timing difference can cause the selector to be\n'
                '    ; overwritten before NMI fires, so the palette is never processed.\n'
                '    ; Fix: always drain DynTileBuf palette records ($3F prefix) first.\n'
                '    lea     (NES_RAM+DynTileBuf).l,A0\n'
                '    cmpi.b  #$3F,(A0)                  ; $3F = palette PPU addr high byte?\n'
                '    bne.s   .no_pending_palette\n'
                '    movem.l D0-D2/A0,-(SP)             ; save regs around BSR\n'
                '    bsr     _transfer_tilebuf_fast      ; process palette from DynTileBuf\n'
                '    movem.l (SP)+,D0-D2/A0             ; restore regs\n'
                '    move.b  #$FF,(NES_RAM+DynTileBuf).l ; reset sentinel\n'
                '    tst.b   ($0014,A4)                  ; TileBufSelector = 0?\n'
                '    beq.s   .skip_main_dispatch         ; already processed DynTileBuf\n'
                '.no_pending_palette:\n'
                '    ; 32-bit pointer table lookup for main dispatch.\n'
                '    moveq   #0,D2\n'
                '    move.b  ($0014,A4),D2\n'
                '    add.w   D2,D2                       ; 2-byte index -> 4-byte index\n'
                '    lea     (TransferBufPtrs).l,A1\n'
                '    move.l  (A1,D2.W),D0               ; D0 = 32-bit buffer pointer\n'
                '    movea.l D0,A0                      ; A0 = 32-bit buffer pointer\n'
                '    bsr     TransferTileBuf\n'
                '.skip_main_dispatch:\n'
                '    moveq   #63,D0\n')
    if old_tcb3 in text:
        text = text.replace(old_tcb3, new_tcb3, 1)
        print("  _patch_z06 P3: DynTileBuf palette pre-check added")
    else:
        print("  WARNING: _patch_z06 P3 -- TransferCurTileBuf body not found")

    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


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
                            dup_exports=dup_exports) and ok

    if ok:
        print("Transpiler done.")
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
