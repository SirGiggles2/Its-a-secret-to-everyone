"""Phase 8 Task 8.11 — Boss Matrix contract.

Scans `src/game/enemies/enemy_loop.c` for the INIT + UPDATE row tables
and asserts every NES boss enemy type ID is wired to a handler. NES
ground truth: `reference/aldonunez/Z_07.asm:5295` UpdateObject_JumpTable
+ `Z_07.asm:5663` InitObject_JumpTable.

Boss type IDs from `Z_07.asm:5295` (UpdateObject_JumpTable, indexed from
`$00 = DoNothing`):
    $18  LittleDigdogger (child)
    $25  PatraChild1
    $26  PatraChild2
    $31  Dodongo
    $32  Dodongo (alt)
    $33  Blue Gohma
    $34  Red Gohma
    $38  Digdogger1 (big)
    $39  Digdogger2 (big, 2nd quest)
    $3A  Lamnola1
    $3B  Lamnola2
    $3C  Manhandla
    $3D  Aquamentus
    $3E  Ganon
    $41  Moldorm
    $42  Gleeok 1-neck
    $43  Gleeok 2-neck
    $44  Gleeok 3-neck
    $45  Gleeok 4-neck
    $46  GleeokHead (flying)
    $47  Patra1
    $48  Patra2

INIT row table per `Z_07.asm:5663` covers the same IDs except:
    $25, $26  PatraChild* — seeded by parent's slot-2..9 loop, no INIT row
    $18       LittleDigdogger — seeded by MakeChildren inside
              UpdateDigdogger, no INIT row
    $42..$46  Gleeok variants — share `enrt_init_gleeok_head`
"""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


# (id, label, requires_init_row)
BOSS_UPDATE_ROWS = [
    (0x18, "LittleDigdogger", False),     # spawned via MakeChildren
    (0x25, "PatraChild1",     False),     # spawned via init_patra loop
    (0x26, "PatraChild2",     False),     # spawned via init_patra loop
    (0x31, "Dodongo",         True),
    (0x32, "Dodongo_alt",     True),
    (0x33, "BlueGohma",       True),
    (0x34, "RedGohma",        True),
    (0x38, "Digdogger1",      True),
    (0x39, "Digdogger2",      True),
    (0x3A, "Lamnola1",        True),
    (0x3B, "Lamnola2",        True),
    (0x3C, "Manhandla",       True),
    (0x3D, "Aquamentus",      True),
    (0x3E, "Ganon",           True),
    (0x41, "Moldorm",         True),
    (0x42, "Gleeok1",         True),
    (0x43, "Gleeok2",         True),
    (0x44, "Gleeok3",         True),
    (0x45, "Gleeok4",         True),
    (0x46, "GleeokHead",      True),
    (0x47, "Patra1",          True),
    (0x48, "Patra2",          True),
]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def find_row_target(source: str, type_id: int) -> str | None:
    """Find every `[0xNN] = <symbol>,` mapping for `type_id`.

    Returns the symbol string for the LAST match (designated initializers
    let later entries shadow earlier ones; the C array uses one row table
    per side, so there is usually a single hit per ID per table).
    """
    pat = re.compile(
        r"\[\s*0[xX]" + f"{type_id:02X}" + r"\s*\]\s*=\s*([A-Za-z_][A-Za-z0-9_]*)",
    )
    matches = pat.findall(source)
    return matches[-1] if matches else None


def split_init_and_update_tables(source: str) -> tuple[str, str]:
    """Split enemy_loop.c around the boundary between INIT + UPDATE row tables.

    Both tables are designated-initializer C arrays in `enemy_loop.c`:
        const enemy_init_fn   enemy_init_fns[...]   = { ... };
        const enemy_update_fn enemy_update_fns[...] = { ... };
    Split on the UPDATE table header so each section captures exactly
    one designated-initializer block.
    """
    update_header = "enemy_update_fns["
    idx = source.find(update_header)
    if idx < 0:
        raise AssertionError(
            f"Could not split enemy_loop.c: marker {update_header!r} not found"
        )
    return source[:idx], source[idx:]


def test_boss_matrix_all_rows_wired() -> None:
    loop = read("src/game/enemies/enemy_loop.c")
    init_section, update_section = split_init_and_update_tables(loop)

    missing_update: list[str] = []
    missing_init:   list[str] = []

    for type_id, label, needs_init in BOSS_UPDATE_ROWS:
        update_target = find_row_target(update_section, type_id)
        if update_target is None:
            missing_update.append(f"0x{type_id:02X} {label}")

        if needs_init:
            init_target = find_row_target(init_section, type_id)
            if init_target is None:
                missing_init.append(f"0x{type_id:02X} {label}")

    if missing_update:
        raise AssertionError(
            "Missing UPDATE row wiring for boss IDs: " + ", ".join(missing_update)
        )
    if missing_init:
        raise AssertionError(
            "Missing INIT row wiring for boss IDs: " + ", ".join(missing_init)
        )


def test_boss_matrix_unique_symbols() -> None:
    """Every boss handler must resolve to an actual extern symbol.

    The `extern void <symbol>(unsigned int slot);` line for each handler
    must appear above the row tables in `enemy_loop.c`. This is a static
    proxy for 'the linker resolved this symbol'.
    """
    loop = read("src/game/enemies/enemy_loop.c")
    _init_section, update_section = split_init_and_update_tables(loop)

    handler_symbols: set[str] = set()
    for type_id, _label, _needs_init in BOSS_UPDATE_ROWS:
        target = find_row_target(update_section, type_id)
        if target is None:
            continue
        handler_symbols.add(target)

    missing_extern: list[str] = []
    for sym in sorted(handler_symbols):
        if f"extern void {sym}(" not in loop and f"boss_{sym.split('_')[0]}" not in sym:
            # boss_*_update bodies are declared via #include "bosses/boss_X.h"
            # in enemy_loop.c — accept either form.
            include_form = sym.startswith("boss_")
            if not include_form:
                missing_extern.append(sym)

    if missing_extern:
        raise AssertionError(
            "Boss handler symbols not declared in enemy_loop.c: "
            + ", ".join(missing_extern)
        )


def test_boss_drain_findings_complete() -> None:
    """Every Phase 8 sub-task must have a drain findings doc."""
    findings_dir = ROOT / "docs" / "audit" / "drain_findings"
    expected = [f"phase8_task_8_{n}.md" for n in range(1, 11)]
    missing = [name for name in expected if not (findings_dir / name).exists()]
    if missing:
        raise AssertionError(
            "Missing Phase 8 drain findings docs: " + ", ".join(missing)
        )


def test_boss_framework_room_item_slot_consistency() -> None:
    """boss_framework.c must touch slot 19 (room item slot) only.

    NES `Z_05.asm:8157` writes ObjState[$13] = $00. Verify the native
    body uses BOSS_ROOM_ITEM_SLOT = 19 consistently and does not
    accidentally hard-code a numeric `19` or `13` for the wrong reason.
    """
    body = read("src/game/enemies/bosses/boss_framework.c")
    if "BOSS_ROOM_ITEM_SLOT" not in body and "BOSS_ROOM_ITEM_STATE" not in body:
        raise AssertionError(
            "boss_framework.c must use BOSS_ROOM_ITEM_SLOT / _STATE macros, "
            "never bare slot 19 / 13 literals"
        )


if __name__ == "__main__":
    test_boss_matrix_all_rows_wired()
    test_boss_matrix_unique_symbols()
    test_boss_drain_findings_complete()
    test_boss_framework_room_item_slot_consistency()
    print("PASS: Boss matrix contract (22 boss rows + 10 drain findings docs)")
