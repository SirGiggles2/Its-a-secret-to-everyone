#!/usr/bin/env python3
"""Diff two normalized scene schemas (S1 Phase H1, Q4 schema validation).

Reads JSON output from normalize_nes.py / normalize_gen.py and reports
where the two scenes diverge in the canonical schema fields. Useful for
NES vs Genesis parity checking once the S2 tile-mapping table makes
bg_tile / sprite tile_id directly comparable across platforms.

Status at S1 close:
    - Schema shape comparison works today. Run on a NES + Genesis pair
      to validate the schema is sufficient to express observable scene
      state (Q4 validation).
    - Tile-id comparison is not meaningful until S2 fills in the
      NES->Genesis tile-mapping table. Until then, this tool reports
      structural diffs (missing fields, wrong types, count mismatches)
      and per-cell pal/priority/scroll diffs.

Usage:
    python tools/probes/diff_normalized.py <a.json> <b.json>
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


def diff_dicts(a: dict, b: dict, prefix: str = "") -> list[str]:
    out: list[str] = []
    keys = sorted(set(a) | set(b))
    for k in keys:
        full = f"{prefix}.{k}" if prefix else k
        if k not in a:
            out.append(f"+ {full} (only in B): {b[k]!r}")
            continue
        if k not in b:
            out.append(f"- {full} (only in A): {a[k]!r}")
            continue
        av, bv = a[k], b[k]
        if av != bv:
            out.append(f"~ {full}: {av!r} != {bv!r}")
    return out


def diff_schemas(a: dict[str, Any], b: dict[str, Any]) -> int:
    if a.get("schema_version") != b.get("schema_version"):
        print(f"schema_version mismatch: {a.get('schema_version')} vs {b.get('schema_version')}")
        return 1

    differences = 0

    # Frame counter sanity (informational, not a fail signal).
    print(f"frame:    A={a.get('frame')}  B={b.get('frame')}")
    print(f"platform: A={a.get('platform')}  B={b.get('platform')}")
    print()

    # Bg fields: per-cell diff but cap output.
    for field in ("bg_tile", "bg_palette", "bg_priority"):
        af = a.get(field, {})
        bf = b.get(field, {})
        diffs = []
        keys = sorted(set(af) | set(bf))
        for k in keys:
            if af.get(k) != bf.get(k):
                diffs.append((k, af.get(k), bf.get(k)))
        if diffs:
            differences += len(diffs)
            print(f"[{field}] {len(diffs)} cells differ:")
            for k, av, bv in diffs[:20]:
                print(f"  ({k}): A={av} B={bv}")
            if len(diffs) > 20:
                print(f"  ... +{len(diffs) - 20} more")
        else:
            print(f"[{field}] match ({len(keys)} cells)")

    # Sprite list.
    asp = a.get("sprite", [])
    bsp = b.get("sprite", [])
    if len(asp) != len(bsp):
        print(f"[sprite] count differs: A={len(asp)} B={len(bsp)}")
        differences += 1
    n = min(len(asp), len(bsp))
    sprite_diffs = 0
    for i in range(n):
        if asp[i] != bsp[i]:
            sprite_diffs += 1
            if sprite_diffs <= 10:
                print(f"  sprite[{i}]: A={asp[i]} B={bsp[i]}")
    if sprite_diffs:
        print(f"[sprite] {sprite_diffs} of {n} entries differ")
        differences += sprite_diffs
    else:
        print(f"[sprite] match ({n} entries)")

    # Scroll.
    if a.get("scroll") != b.get("scroll"):
        print(f"[scroll] differ: A={a.get('scroll')} B={b.get('scroll')}")
        differences += 1
    else:
        print(f"[scroll] match ({a.get('scroll')})")

    print()
    print(f"TOTAL differences: {differences}")
    print("VERDICT:", "PASS" if differences == 0 else "FAIL")
    return 0 if differences == 0 else 1


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        sys.stderr.write("usage: diff_normalized.py <a.json> <b.json>\n")
        return 2
    a = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    b = json.loads(Path(argv[2]).read_text(encoding="utf-8"))
    return diff_schemas(a, b)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
