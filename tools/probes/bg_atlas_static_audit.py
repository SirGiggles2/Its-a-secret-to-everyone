"""bg_atlas_static_audit.py — exhaustive byte-diff of Genesis BG atlas vs
NES CHR ground truth. No runtime, no probe — pure static analysis.

For each in-scope (NES tile_id, NES sub_pal) per in_scope_tile_table.json:
  1. Resolve Genesis VRAM slot via bg_sparse_tile_lut[256][4]
  2. Extract 32 bytes from bg_sparse_chr_<variant> blob at slot*32
  3. Read corresponding 16-byte NES 2bpp tile from the .dat file
  4. Expand NES 2bpp → Genesis 4bpp with pixel-bias for sub_pal:
        out = (in == 0) ? 0 : (sub_pal * 4 + in)
  5. Byte-compare 32 B. Surface mismatches.

NES BG tile_id -> .dat source mapping (per Z_02.asm:69 + Z_03.asm):
  $00..$6F  CommonBackgroundPatterns.dat (offset = tile_id * 16)
  $70..$EF  PatternBlockOWBG.dat / UWBG.dat depending on variant
            (offset = (tile_id - $70) * 16)
  $F0..$FF  CommonMiscPatterns.dat — tile_id $F2..$FF mapped to bytes
            $00..$DF of the .dat (14 tiles cover $F2..$FF; $F0, $F1
            blank).

Output: docs/atlas/tilegrid_audit.md per-tile per-subpal status.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys


REPO = pathlib.Path(__file__).resolve().parents[2]


def parse_blob(text: str, name: str) -> bytes:
    m = re.search(
        rf"{re.escape(name)}\s*\[\d+\][^=]*=\s*\{{(.*?)\}};",
        text, re.DOTALL)
    if not m:
        raise KeyError(f"blob {name} not found")
    body = m.group(1)
    # Strip comments + extract 0xHH literals in order
    body = re.sub(r"/\*.*?\*/", "", body, flags=re.DOTALL)
    body = re.sub(r"//[^\n]*", "", body)
    nums = re.findall(r"0x([0-9A-Fa-f]{1,2})", body)
    return bytes(int(n, 16) for n in nums)


def parse_lut(text: str) -> dict:
    m = re.search(
        r"bg_sparse_tile_lut\[256\]\[4\][^=]*=\s*\{(.*?)\};",
        text, re.DOTALL)
    if not m:
        raise KeyError("bg_sparse_tile_lut not found")
    body = m.group(1)
    rows = re.findall(
        r"\{\s*0x([0-9A-Fa-f]{4})\s*,\s*0x([0-9A-Fa-f]{4})\s*,"
        r"\s*0x([0-9A-Fa-f]{4})\s*,\s*0x([0-9A-Fa-f]{4})\s*\}",
        body)
    return {i: [int(c, 16) for c in row] for i, row in enumerate(rows)}


def nes_2bpp_to_genesis_4bpp(nes16: bytes, sub_pal: int) -> bytes:
    """Convert 16-byte NES 2bpp tile to 32-byte Genesis 4bpp w/ pixel-bias."""
    out = bytearray(32)
    for row in range(8):
        p0 = nes16[row]
        p1 = nes16[row + 8]
        for col in range(8):
            bit0 = (p0 >> (7 - col)) & 1
            bit1 = (p1 >> (7 - col)) & 1
            pix2 = (bit1 << 1) | bit0
            pix4 = 0 if pix2 == 0 else (sub_pal * 4 + pix2)
            byte_idx = row * 4 + (col // 2)
            if col % 2 == 0:
                out[byte_idx] |= pix4 << 4
            else:
                out[byte_idx] |= pix4
    return bytes(out)


def get_nes_bg_tile(tile_id: int, common_bg: bytes, scene_bg: bytes,
                    common_misc: bytes) -> bytes | None:
    """Return 16-byte NES BG tile for tile_id from the appropriate bank.
    Returns None if tile_id falls in a blank/unmapped region."""
    if 0x00 <= tile_id <= 0x6F:
        off = tile_id * 16
        if off + 16 > len(common_bg):
            return None
        return common_bg[off:off + 16]
    if 0x70 <= tile_id <= 0xEF:
        idx = tile_id - 0x70
        off = idx * 16
        if off + 16 > len(scene_bg):
            return None
        return scene_bg[off:off + 16]
    if 0xF2 <= tile_id <= 0xFF:
        # Common Misc holds tile_ids $F2..$FF (14 tiles) starting at .dat
        # offset 0 (=PPU $1F20). tile_id $F0, $F1 are blank (no CHR).
        idx = tile_id - 0xF2
        off = idx * 16
        if off + 16 > len(common_misc):
            return None
        return common_misc[off:off + 16]
    return None  # $F0, $F1 — blank


def audit_variant(variant: str, sparse_text: str, lut: dict,
                  in_scope: list, ow_or_uw: str) -> list:
    """Audit one Genesis blob variant (orig_ow / orig_uw / redux_ow /
    redux_uw). Returns list of mismatch tickets."""
    blob_name = f"bg_sparse_chr_{variant}"
    try:
        blob = parse_blob(sparse_text, blob_name)
    except KeyError:
        return [{"error": f"blob {blob_name} not found in bg_sparse_chr.c"}]
    if len(blob) != 17024:
        return [{"error": f"blob {blob_name} size {len(blob)} != 17024"}]

    # Load NES CHR sources per variant
    dat = REPO / "reference" / "aldonunez" / "dat"
    common_bg = (dat / "CommonBackgroundPatterns.dat").read_bytes()
    common_misc = (dat / "CommonMiscPatterns.dat").read_bytes()
    scene_bg_name = "PatternBlockOWBG.dat" if ow_or_uw == "ow" else "PatternBlockUWBG.dat"
    scene_bg = (dat / scene_bg_name).read_bytes()

    tickets = []
    for entry in in_scope:
        tile_id = entry["tile_id"]
        sub_pal = entry["sub_pal"]
        slot = entry["slot"]
        if slot == 0xFFFF:
            continue  # already filtered, defensive
        # Genesis bytes
        gen_bytes = blob[slot * 32:slot * 32 + 32]
        # NES expected
        nes16 = get_nes_bg_tile(tile_id, common_bg, scene_bg, common_misc)
        if nes16 is None:
            tickets.append({
                "tile_id": tile_id, "sub_pal": sub_pal, "slot": slot,
                "class": "PROVENANCE_GAP",
                "detail": f"NES tile_id ${tile_id:02X} not in any known .dat for variant {variant}"
            })
            continue
        expected = nes_2bpp_to_genesis_4bpp(nes16, sub_pal)
        if gen_bytes != expected:
            mismatch_bytes = sum(1 for a, b in zip(gen_bytes, expected) if a != b)
            tickets.append({
                "tile_id": tile_id, "sub_pal": sub_pal, "slot": slot,
                "class": "B" if mismatch_bytes >= 16 else "A",
                "detail": f"{mismatch_bytes}/32 bytes diverge",
                "expected_hex": expected.hex(),
                "actual_hex":   gen_bytes.hex(),
            })
    return tickets


def emit_md(results: dict, out_path: pathlib.Path) -> None:
    out = ["# Tile-Grid Atlas Audit\n\n"]
    out.append("Generated by `tools/probes/bg_atlas_static_audit.py`. "
               "Per-variant byte-diff of `bg_sparse_chr_<variant>` (Genesis) "
               "vs NES Z1 CHR `.dat` files (NES ground truth) for every "
               "in-scope (tile_id, sub_pal) per `in_scope_tile_table.json`.\n\n")
    out.append("Pixel-bias formula: `out = (in == 0) ? 0 : (sub_pal * 4 + in)` "
               "per `bg_sparse_chr.h:8`.\n\n")
    out.append("## Class legend\n\n")
    out.append("- **A** — partial mismatch (<16 of 32 bytes diverge) — "
               "likely pixel-bias / sub-pal route bug.\n")
    out.append("- **B** — heavy mismatch (>=16 of 32 bytes diverge) — "
               "likely wrong NES CHR bank or extraction provenance bug.\n")
    out.append("- **PROVENANCE_GAP** — NES tile_id falls in a region the .dat "
               "bank doesn't cover (e.g. $F0/$F1 = no CHR). Informational.\n\n")

    total = sum(len(t) for t in results.values())
    out.append(f"## Summary — {total} mismatches across {len(results)} variants\n\n")
    out.append("| Variant | Mismatches | Provenance gaps |\n|---|---|---|\n")
    for v, tickets in results.items():
        real = [t for t in tickets if t.get("class") in ("A", "B")]
        gaps = [t for t in tickets if t.get("class") == "PROVENANCE_GAP"]
        out.append(f"| {v} | {len(real)} | {len(gaps)} |\n")
    out.append("\n---\n\n")

    for variant, tickets in results.items():
        out.append(f"## {variant}\n\n")
        if not tickets:
            out.append("_All in-scope tiles match expected NES bytes._\n\n")
            continue
        # Group by tile_id
        by_tile = {}
        for t in tickets:
            by_tile.setdefault(t.get("tile_id", -1), []).append(t)
        for tile_id in sorted(by_tile):
            entries = by_tile[tile_id]
            if tile_id < 0:
                out.append(f"### (error)\n\n")
                for e in entries:
                    out.append(f"- `{e.get('error', e)}`\n")
                continue
            out.append(f"### Tile $0x{tile_id:02X}\n\n")
            for t in entries:
                sub_pal = t["sub_pal"]
                slot = t["slot"]
                cls = t["class"]
                detail = t.get("detail", "")
                out.append(f"- sub_pal {sub_pal}, slot {slot}: Class {cls} — {detail}\n")
                if "expected_hex" in t:
                    out.append(f"  - expected: `{t['expected_hex']}`\n")
                    out.append(f"  - actual:   `{t['actual_hex']}`\n")
            out.append("\n")
        out.append("---\n\n")

    out_path.write_text("".join(out), encoding="utf-8")


def main():
    sparse_c = REPO / "RoomRom" / "src" / "bg_sparse_chr.c"
    in_scope_json = REPO / "tools" / "probes" / "in_scope_tile_table.json"
    out_md = REPO / "docs" / "atlas" / "tilegrid_audit.md"

    sparse_text = sparse_c.read_text(encoding="utf-8", errors="ignore")
    lut = parse_lut(sparse_text)
    print(f"parsed bg_sparse_tile_lut: {len(lut)} tile_ids")

    in_scope_data = json.loads(in_scope_json.read_text(encoding="utf-8"))
    in_scope = in_scope_data["bg_in_scope"]
    print(f"loaded {len(in_scope)} in-scope (tile, sub_pal) combos")

    variants = [
        ("orig_ow", "ow"),
        ("orig_uw", "uw"),
        # redux variants exist but PatternBlock files for redux not present;
        # audit those once tools/extract_chr.py exposes redux .dat sources.
    ]
    results = {}
    for variant, scene in variants:
        tickets = audit_variant(variant, sparse_text, lut, in_scope, scene)
        results[variant] = tickets
        real = [t for t in tickets if t.get("class") in ("A", "B")]
        print(f"  {variant}: {len(real)} real mismatches, {len(tickets) - len(real)} gaps")

    emit_md(results, out_md)
    print(f"wrote {out_md}")


if __name__ == "__main__":
    sys.exit(main())
