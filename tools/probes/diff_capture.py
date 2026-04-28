#!/usr/bin/env python3
"""Diff two Genesis VDP capture dumps (S1 Phase F, Task F2).

Reads the binary dump format produced by tools/probes/bizhawk_capture_gen.lua,
compares two dumps region-by-region, and reports per-region byte mismatch
counts plus the first 100 mismatched offsets.

Exit code 0 iff every region in both dumps matches byte-for-byte. Used as the
acceptance gate for S1 Phase F frontend cutover ("logical parity diff = 0").

Usage:
    python tools/probes/diff_capture.py <baseline.bin> <candidate.bin>

Dump format:
    header:       4 bytes magic "GDMP"
                  4 bytes version u32 LE
                  4 bytes frame counter u32 LE
                  4 bytes payload-hash u32 LE
    regions:      4 bytes tag (ascii)
                  4 bytes length u32 LE
                  N bytes payload
    terminator:   tag "END_" with length 0
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

MAGIC = b"GDMP"
MAX_MISMATCH_DETAIL = 100


def read_dump(path: Path) -> tuple[dict[str, bytes], dict[str, int]]:
    """Return ({tag: payload}, {header_field: value})."""
    data = path.read_bytes()
    if len(data) < 16 or data[0:4] != MAGIC:
        raise ValueError(f"{path}: not a GDMP dump")

    version, frame, hash_trunc = struct.unpack_from("<III", data, 4)
    header = {"version": version, "frame": frame, "payload_hash": hash_trunc}

    regions: dict[str, bytes] = {}
    pos = 16
    while pos + 8 <= len(data):
        tag = data[pos : pos + 4].decode("ascii", errors="replace")
        length = struct.unpack_from("<I", data, pos + 4)[0]
        pos += 8
        if tag == "END_":
            break
        if pos + length > len(data):
            raise ValueError(
                f"{path}: region {tag!r} length {length} overruns file at pos {pos}"
            )
        regions[tag] = data[pos : pos + length]
        pos += length

    return regions, header


def diff_regions(a: bytes, b: bytes, tag: str) -> tuple[int, list[tuple[int, int, int]]]:
    """Return (mismatch_count, [(offset, a_byte, b_byte), ...])."""
    if len(a) != len(b):
        # If lengths differ, treat as full mismatch on the overlap and report
        # length divergence at end. Caller can decide how to surface.
        pass

    overlap = min(len(a), len(b))
    mismatches: list[tuple[int, int, int]] = []
    count = 0
    for i in range(overlap):
        if a[i] != b[i]:
            count += 1
            if len(mismatches) < MAX_MISMATCH_DETAIL:
                mismatches.append((i, a[i], b[i]))
    if len(a) != len(b):
        # Tail bytes from the longer side count as mismatches too.
        count += abs(len(a) - len(b))
    return count, mismatches


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        sys.stderr.write(
            "usage: diff_capture.py <baseline.bin> <candidate.bin>\n"
        )
        return 2

    base_path = Path(argv[1])
    cand_path = Path(argv[2])
    base_regions, base_header = read_dump(base_path)
    cand_regions, cand_header = read_dump(cand_path)

    print(f"baseline:  {base_path}  frame={base_header['frame']}  payload-hash=0x{base_header['payload_hash']:08X}")
    print(f"candidate: {cand_path}  frame={cand_header['frame']}  payload-hash=0x{cand_header['payload_hash']:08X}")
    print()

    all_tags = sorted(set(base_regions) | set(cand_regions))
    total_mismatches = 0
    region_results: list[tuple[str, int, int, int]] = []  # tag, mismatches, a_len, b_len

    for tag in all_tags:
        a = base_regions.get(tag, b"")
        b = cand_regions.get(tag, b"")
        if not a and not b:
            continue
        if not a:
            print(f"[{tag}] MISSING in baseline (candidate has {len(b)} bytes)")
            total_mismatches += len(b)
            region_results.append((tag, len(b), 0, len(b)))
            continue
        if not b:
            print(f"[{tag}] MISSING in candidate (baseline has {len(a)} bytes)")
            total_mismatches += len(a)
            region_results.append((tag, len(a), len(a), 0))
            continue

        count, details = diff_regions(a, b, tag)
        total_mismatches += count
        region_results.append((tag, count, len(a), len(b)))
        if count == 0:
            print(f"[{tag}] PASS  ({len(a)} bytes)")
        else:
            print(f"[{tag}] FAIL  {count} mismatched bytes (a={len(a)}, b={len(b)})")
            for off, av, bv in details:
                print(f"    @0x{off:04X}: baseline=0x{av:02X}  candidate=0x{bv:02X}")
            if count > MAX_MISMATCH_DETAIL:
                print(f"    ... and {count - MAX_MISMATCH_DETAIL} more")

    print()
    print(f"TOTAL mismatched bytes: {total_mismatches}")
    print("VERDICT:", "PASS" if total_mismatches == 0 else "FAIL")

    return 0 if total_mismatches == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
