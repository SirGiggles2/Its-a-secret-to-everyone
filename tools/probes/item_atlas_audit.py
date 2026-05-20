"""item_atlas_audit.py — items_chr_x4.c byte diff against manifest source.

Source of truth: RoomRom/data/item_chr_manifest.json — each variant has a
`tiles` dict mapping NES tile_id (hex string) -> {bytes: NES 2bpp hex}.
gen_atlas.py:build_legacy_variant_blob assembles the variant blob by
iterating item_defs in order, dispatching on draw_rule:
  - 'wide_16x16_mirrored_8x16_*' : (top, bot) pairs -> top, bot, hflip(top), hflip(bot)
  - 'mirrored_*'                 : each tile -> gen, hflip(gen)
  - other                        : each tile -> gen

This audit replicates that build path EXACTLY from manifest bytes, then
diffs against the actual items_chr_x4.c sub_pal-0 stride (orig variant).

Zero mismatches = items_chr_x4 generation is byte-correct vs manifest.
Any mismatch = either a generation bug in gen_atlas.py OR a manifest entry
out of date relative to the committed blob.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys


REPO = pathlib.Path(__file__).resolve().parents[2]
ITEMS_C = REPO / "RoomRom" / "src" / "atlas" / "items_chr_x4.c"
ITEMS_H = REPO / "RoomRom" / "src" / "atlas" / "items_chr_x4.h"
MANIFEST = REPO / "RoomRom" / "data" / "item_chr_manifest.json"

BYTES_PER_NES_TILE = 16
BYTES_PER_GEN_TILE = 32


def parse_c_array(path: pathlib.Path, name: str) -> bytes:
    text = path.read_text(encoding="utf-8", errors="ignore")
    pat = re.compile(
        r"const\s+unsigned\s+char\s+" + re.escape(name) +
        r"(?:\s*\[\s*[A-Za-z0-9_]+\s*\]){1,2}\s*(?:[^=]*?)=\s*\{(.*?)\}\s*;",
        re.MULTILINE | re.DOTALL)
    m = pat.search(text)
    if not m:
        raise SystemExit(f"{path}: array `{name}` not found")
    body = m.group(1)
    return bytes(int(t.group(1), 16) for t in re.finditer(r"0x([0-9A-Fa-f]{1,2})", body))


def nes_tile_to_genesis(nes_tile: bytes) -> bytes:
    """Match gen_atlas.py:nes_tile_to_genesis exactly."""
    out = bytearray(BYTES_PER_GEN_TILE)
    for row in range(8):
        p0 = nes_tile[row]
        p1 = nes_tile[row + 8]
        for col in range(8):
            bit = 7 - col
            color = ((p0 >> bit) & 1) | (((p1 >> bit) & 1) << 1)
            byte_idx = row * 4 + col // 2
            if col & 1:
                out[byte_idx] |= color
            else:
                out[byte_idx] |= color << 4
    return bytes(out)


def hflip_genesis_tile(gen_tile: bytes) -> bytes:
    """Match gen_atlas.py:hflip_genesis_tile exactly."""
    out = bytearray(BYTES_PER_GEN_TILE)
    for row in range(8):
        for byte_idx in range(4):
            src = gen_tile[row * 4 + byte_idx]
            swapped = ((src & 0x0F) << 4) | ((src >> 4) & 0x0F)
            out[row * 4 + (3 - byte_idx)] = swapped
    return bytes(out)


def build_expected_orig_blob(manifest: dict) -> tuple[bytes, list[tuple[str, int, int]]]:
    """Replicate gen_atlas.py:build_legacy_variant_blob for variant 'orig'.

    Returns (blob_bytes, item_offsets) where item_offsets is a list of
    (item_name, tile_index_start, tile_count) triples for cross-referencing
    against items_chr_x4.h constants."""
    item_defs = manifest["item_defs"]
    variant = next(v for v in manifest["variants"] if v["rom_id"] == "orig")
    tiles_dict = variant["tiles"]

    out = bytearray()
    offsets = []
    cursor_tiles = 0

    for item_def in item_defs:
        name = item_def["name"]
        rule = str(item_def.get("draw_rule", ""))
        tile_ids = item_def["tile_ids"]
        is_8x16_mirrored = rule.startswith("wide_16x16_mirrored_8x16")
        bake_mirror = rule.startswith("mirrored_")

        start_tile = cursor_tiles

        def get_gen(tid_str):
            meta = tiles_dict.get(tid_str)
            if meta is None:
                raise SystemExit(f"manifest missing tile {tid_str} in variant orig")
            raw = bytes.fromhex(meta["bytes"])
            if len(raw) != BYTES_PER_NES_TILE:
                raise SystemExit(f"tile {tid_str} bytes wrong length: {len(raw)}")
            return nes_tile_to_genesis(raw)

        if is_8x16_mirrored:
            if len(tile_ids) % 2 != 0:
                raise SystemExit(f"{name}: rule {rule} requires even tile_ids")
            for i in range(0, len(tile_ids), 2):
                top = get_gen(tile_ids[i])
                bot = get_gen(tile_ids[i + 1])
                out.extend(top)
                out.extend(bot)
                out.extend(hflip_genesis_tile(top))
                out.extend(hflip_genesis_tile(bot))
                cursor_tiles += 4
        elif bake_mirror:
            for tid in tile_ids:
                gen = get_gen(tid)
                out.extend(gen)
                out.extend(hflip_genesis_tile(gen))
                cursor_tiles += 2
        else:
            for tid in tile_ids:
                gen = get_gen(tid)
                out.extend(gen)
                cursor_tiles += 1

        offsets.append((name, start_tile, cursor_tiles - start_tile))

    return bytes(out), offsets


def parse_items_h_tile_offsets(path: pathlib.Path) -> dict[str, int]:
    """Read #define ROOMROM_ITEM_TILE_<NAME> <N>u from items_chr_x4.h
    -> {name_lower: tile_index}."""
    text = path.read_text(encoding="utf-8", errors="ignore")
    pat = re.compile(r"#define\s+ROOMROM_ITEM_TILE_(\w+)\s+(\d+)u?")
    return {m.group(1).upper(): int(m.group(2)) for m in pat.finditer(text)}


def main():
    manifest = json.loads(MANIFEST.read_text())
    print(f"manifest: {len(manifest['item_defs'])} item_defs, "
          f"{len(manifest['variants'])} variants")

    expected_blob, item_offsets = build_expected_orig_blob(manifest)
    print(f"expected orig blob: {len(expected_blob)} bytes "
          f"({len(expected_blob)//32} tiles)")

    items_blob_all = parse_c_array(ITEMS_C, "roomrom_atlas_items_x4")
    print(f"actual blob (both variants): {len(items_blob_all)} bytes")
    # First half = orig variant
    per_variant = len(items_blob_all) // 2
    actual_blob = items_blob_all[:per_variant]
    print(f"actual orig blob: {len(actual_blob)} bytes ({len(actual_blob)//32} tiles)")

    # Header tile offsets (cross-check item_offsets matches header)
    header_offsets = parse_items_h_tile_offsets(ITEMS_H)
    print(f"header constants: {len(header_offsets)} items")

    # Byte-level diff
    if len(expected_blob) != len(actual_blob):
        print(f"\n[!] SIZE MISMATCH: expected={len(expected_blob)} actual={len(actual_blob)}")

    cmp_len = min(len(expected_blob), len(actual_blob))
    byte_mismatches = sum(1 for i in range(cmp_len) if expected_blob[i] != actual_blob[i])
    print(f"\nbyte diff: {byte_mismatches} / {cmp_len} bytes")

    # Tile-level breakdown
    tile_mismatches = []
    for tile_idx in range(cmp_len // BYTES_PER_GEN_TILE):
        off = tile_idx * BYTES_PER_GEN_TILE
        if expected_blob[off:off + BYTES_PER_GEN_TILE] != actual_blob[off:off + BYTES_PER_GEN_TILE]:
            tile_mismatches.append(tile_idx)
    print(f"tile diff: {len(tile_mismatches)} / {cmp_len // BYTES_PER_GEN_TILE} tiles")

    # Per-item attribution
    if tile_mismatches:
        print("\nMismatching tile indices and owning items:")
        for tidx in tile_mismatches[:40]:
            owning = None
            for name, start, count in item_offsets:
                if start <= tidx < start + count:
                    owning = (name, tidx - start)
                    break
            print(f"  tile {tidx}: {owning}")
        if len(tile_mismatches) > 40:
            print(f"  ... ({len(tile_mismatches) - 40} more)")

    # Header consistency check
    print("\nHeader vs computed offsets:")
    mismatched_offsets = []
    for name, start, count in item_offsets:
        header_val = header_offsets.get(name.upper())
        if header_val is None:
            print(f"  {name}: not in header (skipped)")
            continue
        if header_val != start:
            mismatched_offsets.append((name, start, header_val))
    if mismatched_offsets:
        print("  [!] OFFSET DRIFT:")
        for name, computed, header_val in mismatched_offsets:
            print(f"    {name}: computed={computed} header={header_val}")
    else:
        print("  OK — all matched item offsets agree with header")


if __name__ == "__main__":
    sys.exit(main())
