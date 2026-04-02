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
            gen_read('D2', val, idx)
        else:
            e(f'; [LDX unhandled mode={mode}] {stripped}')

    elif mnem == 'LDY':
        if mode == 'IMM':
            e(f'    moveq   #{val},D3') if -128 <= val <= 127 else e(f'    move.b  #${val:02X},D3')
        elif mode in ('ABS', 'ABS_X'):
            idx = 'X' if mode == 'ABS_X' else None
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
        e('    move.b  D0,D2')
    elif mnem == 'TAY':
        e('    move.b  D0,D3')
    elif mnem == 'TXA':
        e('    move.b  D2,D0')
    elif mnem == 'TYA':
        e('    move.b  D3,D0')
    elif mnem == 'TXS':
        e('    move.b  D2,D7   ; TXS: fake SP update (D7=NES SP shadow)')
    elif mnem == 'TSX':
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
    if bank_num == 1:
        _patch_z01(out_path)
    if bank_num == 2:
        _patch_z02(out_path)
    if bank_num == 7:
        _patch_z07(out_path)

    print(f" {len(body_lines)} lines")
    return True


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

    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(lines)


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
