#!/usr/bin/env python3
"""
audit_macro_shims.py — Workstream G: State Contract Audit

Scans every src/state/*.h file for RAM() and OBJ() macro definitions,
extracts macro name, offset expression, subsystem (from filename), and
line number, then writes docs/audit/state_macro_inventory.md sorted by
numeric offset.

Usage:
    python tools/state/audit_macro_shims.py [--repo-root PATH]

Exits 0 on success.
"""

import argparse
import os
import re
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Regex patterns
# ---------------------------------------------------------------------------

# Matches: #define MACRO_NAME(args) RAM(expr)   or   #define MACRO_NAME RAM(expr)
# Captures: (name, args_or_empty, offset_expr)
RAM_PATTERN = re.compile(
    r"^\s*#define\s+(\w+)(\([^)]*\))?\s+RAM\(([^)]+)\)"
)

# Matches: #define MACRO_NAME(args) OBJ(off_expr, slot_expr)
# Captures: (name, args_or_empty, off_expr, slot_expr)
OBJ_PATTERN = re.compile(
    r"^\s*#define\s+(\w+)(\([^)]*\))?\s+OBJ\(([^,]+),\s*([^)]+)\)"
)

# Matches a bare hex literal like 0x0412
HEX_LITERAL = re.compile(r"^0[xX][0-9a-fA-F]+$")

# Matches a decimal literal
DEC_LITERAL = re.compile(r"^\d+$")


def parse_offset(expr: str) -> int | None:
    """
    Try to evaluate a constant offset expression to a numeric value.
    Returns None if the expression is not purely constant (contains
    symbolic constants from platform_abi.h that we don't inline-expand here).
    """
    expr = expr.strip()
    if HEX_LITERAL.match(expr):
        return int(expr, 16)
    if DEC_LITERAL.match(expr):
        return int(expr)
    # Try Python eval for simple constant arithmetic like 0x6000u + 0x0BB1
    sanitized = expr.replace("u", "").replace("U", "")
    try:
        val = eval(sanitized, {"__builtins__": {}})  # noqa: S307
        if isinstance(val, int):
            return val
    except Exception:
        pass
    return None


# ---------------------------------------------------------------------------
# Known symbolic constant values from platform_abi.h
# (extend this table when new named offsets are added)
# ---------------------------------------------------------------------------
SYMBOL_TABLE: dict[str, int] = {
    "NES_OBJ_X":               0x0070,
    "NES_OBJ_Y":               0x0084,
    "NES_OBJ_GRID_OFFSET":     0x0394,
    "NES_OBJ_POS_FRAC":        0x03A8,
    "NES_OBJ_QSPD_FRAC":       0x03BC,
    "NES_OBJ_TYPE":            0x034F,
    "NES_OBJ_DIR":             0x000F,
    "NES_TMP0":                0x0000,
    "NES_TMP1":                0x0001,
    "NES_TMP2":                0x0002,
    "NES_TMP3":                0x0003,
    "NES_TMP4":                0x0004,
    "NES_SHOT_COLLISION_FLAG": 0x000E,
    "NES_POS_GRID_LIMIT":      0x010E,
    "NES_NEG_GRID_LIMIT":      0x010F,
    "NES_OBJ_TILE_X_BASE":     0x0070,
    "NES_OBJ_TILE_Y_BASE":     0x0084,
    "NES_OBJ_TILE_NEXT_BASE":  0x049E,
    "NES_OBJ_ALIGN_FLAG_BASE": 0x0394,
    "NES_OBJ_TYPE_BASE":       0x034F,
    "NES_OBJ_FLAG_BASE":       0x0098,
    "NES_OBJ_STATE_BASE":      0x00AC,
    "NES_OBJ_METASTATE_BASE":  0x0405,
    "NES_OBJ_SHOVE_DIR_BASE":  0x00C0,
    "NES_OBJ_SHOVE_DIST_BASE": 0x00D3,
    "NES_OBJ_ANIM_CNTR_BASE":  0x03D0,
    "NES_OBJ_HFLIP_BASE":      0x03E4,
    "NES_OBJ_INV_TIMER_BASE":  0x04F0,
    "NES_OAM_BASE":            0x0200,
    "NES_CUR_LEVEL":           0x0010,
    "NES_GAME_MODE_PREV":      0x0011,
    "NES_GAME_MODE":           0x0012,
    "NES_SUB_MODE":            0x0013,
    "NES_ROOM_XFER_BUF_SELECT":0x0014,
    "NES_FRAME_TICK":          0x0015,
    "NES_SAVE_SLOT":           0x0016,
    "NES_TILE_XFER_COL":       0x00E8,
    "NES_TILE_XFER_ROW":       0x00E9,
    "NES_CUR_ROOM_ID":         0x00EB,
    "NES_PPU_MASK_SHADOW":     0x00FE,
    "NES_TILE_XFER_BUF_IDX":   0x0301,
    "NES_TILE_XFER_BUF_BASE":  0x0302,
    "NES_TILE_XFER_BUF_END":   0x0325,
    "NES_ROOM_LAYOUT_SCRATCH": 0x051A,
    "NES_ROOM_ID_ALT":         0x0526,
    "NES_ROOM_HISTORY_IDX":    0x0529,
    "NES_ROOM_HISTORY_BASE":   0x0621,
    "NES_CONTINUE_COUNT_BASE": 0x0630,
    "NES_ITEMS_BY_LEVEL_BASE": 0x0657,
    "NES_LINK_MOVING_DIR":     0x000F,
    "NES_MODE11_DEATH_TIMER":  0x0033,
    "NES_LINK_ROOM_SCRATCH":   0x0059,
    "NES_DEATH_FRAME_COUNTER": 0x0602,
    "NES_LINK_HALT_FLAG":      0x066C,
    "NES_SFX_PRIMARY":         0x0600,
    "NES_SRAM_BASE":           0x6000,
    "NES_SRAM_ROOM_UNIQUE_ID_BASE": 0x09FE,
    "NES_SRAM_ROOM_FLAGS_PTR_LO": 0x0BAF,
    "NES_SRAM_ROOM_FLAGS_PTR_HI": 0x0BB0,
    "NES_BOUND_LEFT":          0x0346,
    "NES_BOUND_RIGHT":         0x0347,
    "NES_BOUND_TOP":           0x0348,
    "NES_BOUND_BOTTOM":        0x0349,
}


def resolve_offset(expr: str) -> int | None:
    """
    Resolve an offset expression to an integer, using the symbol table to
    expand named constants from platform_abi.h.
    """
    expr = expr.strip()
    val = parse_offset(expr)
    if val is not None:
        return val

    # Substitute known symbols and retry
    substituted = expr
    for sym, num in SYMBOL_TABLE.items():
        substituted = re.sub(r"\b" + re.escape(sym) + r"\b", hex(num), substituted)

    return parse_offset(substituted)


# ---------------------------------------------------------------------------
# Entry record
# ---------------------------------------------------------------------------

class MacroEntry:
    __slots__ = ("name", "args", "kind", "offset_expr", "resolved_offset",
                 "subsystem", "filename", "lineno")

    def __init__(self, name, args, kind, offset_expr, resolved_offset,
                 subsystem, filename, lineno):
        self.name = name
        self.args = args            # "" for scalar, "(slot)" etc. for indexed
        self.kind = kind            # "RAM" or "OBJ"
        self.offset_expr = offset_expr.strip()
        self.resolved_offset = resolved_offset   # int or None
        self.subsystem = subsystem
        self.filename = filename
        self.lineno = lineno

    def display_offset(self) -> str:
        if self.resolved_offset is not None:
            return f"0x{self.resolved_offset:04X}"
        return self.offset_expr


# ---------------------------------------------------------------------------
# Scanner
# ---------------------------------------------------------------------------

def scan_file(path: Path) -> list[MacroEntry]:
    subsystem = path.stem  # e.g. "enemy_state" -> subsystem label
    entries: list[MacroEntry] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    for lineno, line in enumerate(text.splitlines(), 1):
        # Skip commented-out lines
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("*"):
            continue

        m = OBJ_PATTERN.match(line)
        if m:
            name, args, off_expr, _slot = m.groups()
            resolved = resolve_offset(off_expr)
            entries.append(MacroEntry(
                name=name,
                args=(args or "").strip(),
                kind="OBJ",
                offset_expr=off_expr,
                resolved_offset=resolved,
                subsystem=subsystem,
                filename=path.name,
                lineno=lineno,
            ))
            continue

        m = RAM_PATTERN.match(line)
        if m:
            name, args, off_expr = m.groups()
            resolved = resolve_offset(off_expr)
            entries.append(MacroEntry(
                name=name,
                args=(args or "").strip(),
                kind="RAM",
                offset_expr=off_expr,
                resolved_offset=resolved,
                subsystem=subsystem,
                filename=path.name,
                lineno=lineno,
            ))

    return entries


def scan_all(state_dir: Path) -> list[MacroEntry]:
    entries: list[MacroEntry] = []
    for h in sorted(state_dir.glob("*.h")):
        entries.extend(scan_file(h))
    return entries


# ---------------------------------------------------------------------------
# Collision detection
# ---------------------------------------------------------------------------

def find_collisions(entries: list[MacroEntry]) -> list[tuple[MacroEntry, MacroEntry]]:
    """
    Return pairs of entries that map to the same resolved numeric offset
    under different macro names (same-kind pairs only: RAM-RAM and OBJ-OBJ
    share an address space; cross-kind pairs are by definition separate).
    """
    from collections import defaultdict
    by_key: dict[tuple[str, int], list[MacroEntry]] = defaultdict(list)
    for e in entries:
        if e.resolved_offset is None:
            continue
        key = (e.kind, e.resolved_offset)
        # Only collisions between DIFFERENT names
        by_key[key].append(e)

    collisions: list[tuple[MacroEntry, MacroEntry]] = []
    seen: set[frozenset[str]] = set()
    for entries_at_offset in by_key.values():
        unique_names = {e.name for e in entries_at_offset}
        if len(unique_names) < 2:
            continue
        for i, a in enumerate(entries_at_offset):
            for b in entries_at_offset[i + 1:]:
                if a.name == b.name:
                    continue
                key_pair = frozenset({a.name, b.name})
                if key_pair in seen:
                    continue
                seen.add(key_pair)
                collisions.append((a, b))

    collisions.sort(key=lambda p: (p[0].resolved_offset or 0, p[0].name))
    return collisions


# ---------------------------------------------------------------------------
# Markdown writer
# ---------------------------------------------------------------------------

def write_inventory(entries: list[MacroEntry], collisions, out_path: Path) -> None:
    # Sort: resolved offsets first (numerically), then unresolved alphabetically
    resolved = [e for e in entries if e.resolved_offset is not None]
    unresolved = [e for e in entries if e.resolved_offset is None]
    resolved.sort(key=lambda e: (e.resolved_offset, e.name))
    unresolved.sort(key=lambda e: (e.offset_expr, e.name))
    sorted_entries = resolved + unresolved

    lines = [
        "# State Macro Inventory",
        "",
        "> Auto-generated by `tools/state/audit_macro_shims.py`.",
        "> Do not edit by hand — regenerate with `python tools/state/audit_macro_shims.py`.",
        "",
        f"Total macros: **{len(entries)}** across {len({e.filename for e in entries})} headers.",
        "",
        "## All Macros (sorted by numeric offset)",
        "",
        "| Offset | Kind | Macro Name | Args | Raw Expr | Subsystem | File | Line |",
        "|--------|------|------------|------|----------|-----------|------|------|",
    ]

    for e in sorted_entries:
        offset_str = f"`0x{e.resolved_offset:04X}`" if e.resolved_offset is not None else f"`{e.offset_expr}`"
        lines.append(
            f"| {offset_str} | {e.kind} | `{e.name}` | `{e.args}` | "
            f"`{e.offset_expr.strip()}` | {e.subsystem} | {e.filename} | {e.lineno} |"
        )

    # Known alias collisions section
    lines += [
        "",
        "## Known Alias Collisions",
        "",
        "> Two distinct macro names mapping to the same NES RAM offset.",
        "> Each collision must be resolved (one canonical name chosen) before",
        "> the owning subsystem is promoted to typed structs.",
        "> See `tools/state/verify_no_alias_collisions.py` for the gate.",
        "",
    ]

    if not collisions:
        lines.append("_No alias collisions detected._")
    else:
        lines += [
            f"Total collisions: **{len(collisions)}**",
            "",
            "| Offset | Kind | Name A | A File | A Line | Name B | B File | B Line |",
            "|--------|------|--------|--------|--------|--------|--------|--------|",
        ]
        for a, b in collisions:
            offset_str = f"`0x{a.resolved_offset:04X}`"
            lines.append(
                f"| {offset_str} | {a.kind} | `{a.name}` | {a.filename} | {a.lineno} "
                f"| `{b.name}` | {b.filename} | {b.lineno} |"
            )

    lines += [
        "",
        "## Notes",
        "",
        "- `RAM(off)` macros are scalar; `OBJ(off, slot)` macros are slot-indexed.",
        "- Collision detection compares same-kind (RAM-RAM or OBJ-OBJ) pairs only.",
        "  Cross-kind collisions at the same offset are structurally distinct.",
        "- Offsets expressed as symbolic constants from `src/abi/platform_abi.h`",
        "  are resolved at scan time using a built-in symbol table; expressions",
        "  involving `+ slot` or other runtime variables are left as-is.",
    ]

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {out_path} ({len(entries)} entries, {len(collisions)} collisions)")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=None,
        help="Repository root (default: two levels up from this script's directory)",
    )
    args = parser.parse_args()

    if args.repo_root:
        repo_root = Path(args.repo_root).resolve()
    else:
        repo_root = Path(__file__).resolve().parent.parent.parent

    state_dir = repo_root / "src" / "state"
    out_path = repo_root / "docs" / "audit" / "state_macro_inventory.md"

    if not state_dir.is_dir():
        print(f"ERROR: state dir not found: {state_dir}", file=sys.stderr)
        return 1

    entries = scan_all(state_dir)
    collisions = find_collisions(entries)
    write_inventory(entries, collisions, out_path)

    print(f"Alias collisions found: {len(collisions)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
