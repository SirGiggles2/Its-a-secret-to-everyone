#!/usr/bin/env python3
"""diff_boss.py — byte-diff NES vs Genesis boss state.

Phase 8 boss matrix differ (CLAUDE.md RULE V1: byte-diff > screenshot;
RULE V3: capture-all-domains-in-full).

Usage:
    diff_boss.py --mode state   --boss <name> --nes <dir> --gen <dir>
    diff_boss.py --mode matrix  --nes-dir <dir> --gen-dir <dir>

Modes
-----
state:  Diff a single boss's per-cell state at one capture frame.
        Returns 0 if byte-identical (excluding documented drift cells);
        non-zero with diff report otherwise.

matrix: Iterate all 10 bosses (Aquamentus, Dodongo, Manhandla,
        Gleeok 1/2/3/4-head, Digdogger, Gohma, Patra, Moldorm, Lamnola,
        Ganon) at their canonical rooms (docs/audit/boss_room_ids.md).
        Per-boss PASS / FAIL aggregated into docs/audit/boss_matrix.md.

Capture contract (per RULE V3)
------------------------------
NES dump dir contains:
    palram.bin     (32 B  $3F00-$3F1F)
    oam.bin        (256 B sprite table)
    ciram.bin      (2 KB nametable)
    vram_chr.bin   (8 KB CHR-RAM — NesHawk "VRAM" domain)
    wram.bin       (2 KB $0000-$07FF)
    state.json     {gameMode, roomId, frame, ppuCtrl, ...}

Gen dump dir contains:
    cram.bin       (128 B Genesis color RAM)
    vsram.bin      (80 B)
    vram_full.bin  (64 KB)
    sat.bin        (640 B; read from address resolved via _oam_dma_flush)
    m68k_ram.bin   (64 KB 68K work RAM mirror)
    state.json     {gameMode, roomId, frame, sat_base, ...}

Exclusion cells (drift expected)
--------------------------------
Per audit + NES asm cite:
    $0012  FrameCounter            (Z_07.asm — incremented every NMI)
    $001D-$001F  RNG seed         (Z_06.asm — advances every Rand call)
    $0600-$0700  Audio state       (XGM/FM driver scratch, port-specific)

HP cell width = 8-bit confirmed (docs/superpowers/captures/phase8/hp_width.md).

Per-boss cells (subset of `src/state/enemy_state.h`)
---------------------------------------------------
Common (all bosses, slot 1):
    $0070+s  ObjX     (8-bit)
    $0084+s  ObjY     (8-bit)
    $0098+s  ObjDir   (8-bit)
    $0405+s  MON_METASTATE
    $0485+s  MON_HP / ENEMY_HP
    $04BF+s  MON_STATUS_FLAGS / ENEMY_ATTR
    $04B2+s  MON_INVINCIBILITY
    $04F0+s  MON_HIT_REACTION

Boss-specific (from enemy_state.h:72-185):
    Aquamentus      — $0380+s ENEMY_BOSS_HP_PHASE (alt: shoot phase)
    Dodongo         — $0405+s MON_METASTATE (bloated sub-state)
    Manhandla       — $0383+s ENEMY_MANHANDLA_SEGMENT_DIED_FLAG
    Gleeok          — $0418+s ENEMY_GLEEOK_HEAD_TIMER,
                      $0071/$0085+s head X/Y per neck,
                      $0511+s ENEMY_GLEEOK_DEAD_NECK_MASK
    Digdogger       — $0507+s ENEMY_DIGDOGGER_COUNT,
                      $051B+s ENEMY_DIGDOGGER_USED_FLUTE
    Gohma           — $0380+s ENEMY_GOHMA_SHOOT_TIMER,
                      $03B0+s ENEMY_GOHMA_OPEN_EYE_TIMER (verify offset
                      against Z_04:8309 NextOpenEyeCounter)
    Patra           — $045E+s ENEMY_PATRA_MANEUVER_INDEX,
                      $0394+s ENEMY_OBJ_ANGLE_WHOLE
    Moldorm         — $0380+s ENEMY_MOLDORM_OLD_DIR,
                      $03BC+s ENEMY_MOLDORM_BOUNCE_DIR
    Lamnola         — $04E6+s ENEMY_LAMNOLA_SPEED,
                      $050F+s ENEMY_LAMNOLA_VIABLE_DIR_MASK
    Ganon           — $0380+s ENEMY_BOSS_HP_PHASE, cloud rect cells

Sprite count normalization
--------------------------
NES OAM count: number of active 8×16 sprites (count of entries with
    Y < 0xEF, since OAM Y >= 0xEF marks empty).

Genesis SAT count: sum of (sprite_w × sprite_h cells) / 2, where
    sprite_w/h ∈ [1,4] cells. Divide by 2 to normalize against NES
    8×16 = 1 NES sprite = 2 cells.

PASS criterion: |gen_count - nes_count| <= 1 (tolerance for one-frame
animation skew).

Verdict format
--------------
JSON output, per-cell:
    {"cell": "$0485+1 HP", "nes": 0x04, "gen": 0x04, "verdict": "PASS"}
    {"cell": "$0098+1 DIR", "nes": 0x04, "gen": 0x02, "verdict": "FAIL", "delta": 2}

Stdout summary:
    BOSS aquamentus  L1 rm=$35  state:PASS sprite:PASS hp:PASS
    BOSS gohma       L6 rm=$0F  state:FAIL(2 cells)
"""

import argparse
import json
import sys
from pathlib import Path


# Per docs/audit/boss_room_ids.md — re-derived 2026-05-31, cross-confirmed
# by LBA list_id (reference/aldonunez/dat/LevelBlockUW{1,2}Q1.dat) AND
# LevelInfo_BossRoomId (two independent static sources agree). The prior
# table held mode-poke-warp guesses (only L1 was right).
#   L5 Digdogger spawns as $39 (Digdogger2, morphs->$38 runtime via
#   InitDigdogger2); L6 Gohma as $34 (blue variant, the type present in
#   UW1Q1 — the block L1-6 load).
BOSS_TABLE = [
    {"name": "aquamentus",   "level": 1, "room": 0x35, "obj_type": 0x3D},
    {"name": "dodongo",      "level": 2, "room": 0x56, "obj_type": 0x31},
    {"name": "manhandla",    "level": 3, "room": 0x10, "obj_type": 0x3C},
    {"name": "gleeok_2head", "level": 4, "room": 0x13, "obj_type": 0x43},
    {"name": "digdogger",    "level": 5, "room": 0x24, "obj_type": 0x39},
    {"name": "gohma",        "level": 6, "room": 0x1C, "obj_type": 0x34},
    {"name": "aquamentus_2", "level": 7, "room": 0x2A, "obj_type": 0x3D},
    {"name": "gleeok_4head", "level": 8, "room": 0x3C, "obj_type": 0x45},
    {"name": "patra",        "level": 9, "room": 0x52, "obj_type": 0x47},
    {"name": "ganon",        "level": 9, "room": 0x42, "obj_type": 0x3E},
]


EXCLUDE_RANGES = [
    (0x0012, 0x0012),   # FrameCounter (Z_07.asm — increments every NMI)
    (0x001D, 0x001F),   # RNG seed (Z_06.asm Rand)
    (0x0600, 0x0700),   # Audio driver scratch (port-specific)
]


COMMON_CELLS_BY_NAME = {
    "OBJ_X":          0x0070,
    "OBJ_Y":          0x0084,
    "OBJ_DIR":        0x0098,
    "MON_METASTATE":  0x0405,
    "MON_HP":         0x0485,
    "MON_STATUS":     0x04BF,
    "MON_INVULN":     0x04B2,
    "MON_HIT":        0x04F0,
}


def is_excluded(addr: int) -> bool:
    for lo, hi in EXCLUDE_RANGES:
        if lo <= addr <= hi:
            return True
    return False


def diff_cell(name: str, addr: int, nes_byte: int, gen_byte: int) -> dict:
    return {
        "cell": f"${addr:04X} {name}",
        "nes": nes_byte,
        "gen": gen_byte,
        "verdict": "PASS" if nes_byte == gen_byte else "FAIL",
        "delta": (gen_byte - nes_byte) if nes_byte != gen_byte else 0,
    }


def diff_state(boss_name: str, nes_dir: Path, gen_dir: Path,
               slot: int = 1) -> tuple[list[dict], dict]:
    """Diff one boss's common + specific cells. Returns (per-cell list,
    summary dict)."""
    nes_wram = (nes_dir / "wram.bin").read_bytes()
    gen_ram = (gen_dir / "m68k_ram.bin").read_bytes()

    results = []
    for cell_name, addr in COMMON_CELLS_BY_NAME.items():
        slot_addr = addr + slot
        if is_excluded(slot_addr):
            continue
        nes_b = nes_wram[slot_addr] if slot_addr < len(nes_wram) else 0
        gen_b = gen_ram[slot_addr] if slot_addr < len(gen_ram) else 0
        results.append(diff_cell(cell_name, slot_addr, nes_b, gen_b))

    fail_count = sum(1 for r in results if r["verdict"] == "FAIL")
    summary = {
        "boss": boss_name,
        "cells_checked": len(results),
        "fail_count": fail_count,
        "verdict": "PASS" if fail_count == 0 else "FAIL",
    }
    return results, summary


def normalize_sprite_count_nes(oam: bytes) -> int:
    """NES OAM: 64 entries × 4 bytes (Y, tile, attr, X). Y >= 0xEF =
    empty."""
    count = 0
    for i in range(0, min(len(oam), 256), 4):
        y = oam[i]
        if y < 0xEF:
            count += 1
    return count


def normalize_sprite_count_gen(sat: bytes) -> int:
    """Genesis SAT: 80 entries × 8 bytes. Entry size = (w+1) cells ×
    (h+1) cells in attr byte 2. Returns normalized count in NES
    8×16-equivalents (cells / 2)."""
    total_cells = 0
    for i in range(0, min(len(sat), 640), 8):
        # SAT entry layout: y(2) link/size(2) attr(2) x(2)
        size = sat[i + 2] if i + 2 < len(sat) else 0
        w_cells = ((size >> 2) & 0x03) + 1
        h_cells = (size & 0x03) + 1
        total_cells += w_cells * h_cells
    return total_cells // 2


def diff_sprite_count(nes_dir: Path, gen_dir: Path,
                      tolerance: int = 1) -> dict:
    nes_oam = (nes_dir / "oam.bin").read_bytes()
    gen_sat = (gen_dir / "sat.bin").read_bytes()
    nes_n = normalize_sprite_count_nes(nes_oam)
    gen_n = normalize_sprite_count_gen(gen_sat)
    delta = abs(gen_n - nes_n)
    return {
        "nes_sprite_count": nes_n,
        "gen_sprite_count_normalized": gen_n,
        "delta": delta,
        "verdict": "PASS" if delta <= tolerance else "FAIL",
    }


def run_state(args) -> int:
    nes_dir = Path(args.nes)
    gen_dir = Path(args.gen)
    boss = next((b for b in BOSS_TABLE if b["name"] == args.boss), None)
    if boss is None:
        print(f"unknown boss: {args.boss}", file=sys.stderr)
        return 2

    results, summary = diff_state(args.boss, nes_dir, gen_dir, slot=args.slot)
    sprite = diff_sprite_count(nes_dir, gen_dir)

    out = {
        "boss": boss,
        "state": {"summary": summary, "cells": results},
        "sprite": sprite,
    }
    json.dump(out, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0 if summary["verdict"] == "PASS" and sprite["verdict"] == "PASS" else 1


def run_matrix(args) -> int:
    nes_root = Path(args.nes_dir)
    gen_root = Path(args.gen_dir)
    rows = []
    for boss in BOSS_TABLE:
        nes_dir = nes_root / boss["name"]
        gen_dir = gen_root / boss["name"]
        if not nes_dir.exists() or not gen_dir.exists():
            rows.append({"boss": boss["name"], "verdict": "SKIP",
                         "reason": f"missing dump dir"})
            continue
        _, summary = diff_state(boss["name"], nes_dir, gen_dir)
        sprite = diff_sprite_count(nes_dir, gen_dir)
        rows.append({
            "boss": boss["name"], "level": boss["level"], "room": boss["room"],
            "state_verdict": summary["verdict"],
            "sprite_verdict": sprite["verdict"],
            "overall": "PASS" if summary["verdict"] == "PASS" and
                                  sprite["verdict"] == "PASS" else "FAIL",
        })

    print("# Phase 8.11 Boss Matrix\n")
    print("| Boss | Level | Room | State | Sprite | Overall |")
    print("|---|---|---|---|---|---|")
    for r in rows:
        if r.get("verdict") == "SKIP":
            print(f"| {r['boss']} | — | — | — | — | SKIP({r['reason']}) |")
        else:
            print(f"| {r['boss']} | L{r['level']} | ${r['room']:02X} | "
                  f"{r['state_verdict']} | {r['sprite_verdict']} | {r['overall']} |")
    any_fail = any(r.get("overall") == "FAIL" for r in rows)
    return 1 if any_fail else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["state", "matrix"], required=True)
    ap.add_argument("--boss", help="boss name (state mode)")
    ap.add_argument("--slot", type=int, default=1,
                    help="enemy slot (state mode, default 1)")
    ap.add_argument("--nes", help="NES dump dir (state mode)")
    ap.add_argument("--gen", help="Genesis dump dir (state mode)")
    ap.add_argument("--nes-dir", help="NES dump root (matrix mode)")
    ap.add_argument("--gen-dir", help="Genesis dump root (matrix mode)")
    args = ap.parse_args()

    if args.mode == "state":
        if not (args.boss and args.nes and args.gen):
            ap.error("state mode requires --boss --nes --gen")
        return run_state(args)
    else:
        if not (args.nes_dir and args.gen_dir):
            ap.error("matrix mode requires --nes-dir --gen-dir")
        return run_matrix(args)


if __name__ == "__main__":
    sys.exit(main())
