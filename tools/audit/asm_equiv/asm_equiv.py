#!/usr/bin/env python3
"""asm_equiv.py - run original NES routines (6502) against their C ports.

The NES routines are cut verbatim from reference/aldonunez/*.asm (label
ranges below), assembled with ca65/ld65 and executed in py65. The C ports
are compiled with the host gcc into a shared library. Both sides start
from the same randomized NES RAM and share identical callee stubs (see
harness_stubs.c and STUBS_ASM), so a difference is a port defect, not a
callee difference. Each case compares NES RAM $0000-$07FF byte for byte
(except the harness's own 6502 stack, $01C0-$01FF)
plus the ordered callee log (callee inputs: slots, directions, positions,
scratch).

Covers T-056: Z_05 CheckLadder, Z_07 Link_EndMoveAndAnimate (ladder half),
Z_04 UpdateDock.

Requires: ca65 + ld65 (cc65), py65 (pip), host gcc.
Usage: python tools/audit/asm_equiv/asm_equiv.py [--cases N] [--seed S]
Exit 1 on any mismatch or missing tool.
"""
from __future__ import annotations

import argparse
import ctypes
import random
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
REF = ROOT / "reference" / "aldonunez"
HERE = Path(__file__).resolve().parent

# (file, first label, end label exclusive, text appended after the cut)
RANGES = [
    ("Z_05.asm", "CheckLadder:", "FindNextEdgeSpawnCell:", ""),
    ("Z_07.asm", "LinkToLadderOffsetsX:", "LinkHeadTiles:", ""),
    ("Z_07.asm", "LadderRoomsOW:", "Link_EndMoveAndAnimate_Bank4:", ""),
    # Link_EndMoveAndAnimate up to @CheckWarps (CheckWarps/AnimateLinkBase
    # are not part of the ladder port; the Genesis keeps them elsewhere).
    ("Z_07.asm", "Link_EndMoveAndAnimate:", "@CheckWarps:", "@CheckWarps:\n    RTS\n"),
    ("Z_07.asm", "GoToNextModeFromPlay:", "CheckBoundary:", ""),
    ("Z_07.asm", "ResetShoveInfo:", "ShoveMoveMin:", ""),
    ("Z_07.asm", "DestroyMonster:", "InitTileObjOrItem:", ""),
    ("Z_07.asm", "Anim_FetchObjPosForSpriteDescriptor:", "RollOverAnimCounter:", ""),
    ("Z_01.asm", "OppositeDirs:", "MoveShot:", ""),
    ("Z_01.asm", "DestroyObject_WRAM:", "UpdateBombFlashEffect:", ""),
    ("Z_04.asm", "RaftDirections:", "UpdateFlyingGhini:", ""),
    ("Z_04.asm", "PlaySecretFoundTune:", "; Unknown block", ""),
]

# 6502 stubs mirroring harness_stubs.c.
STUBS_ASM = r"""
LOG_IDX  = $6000
CALL_IDX = $6001
TMPX     = $6002
TMPY     = $6003
LOG_BUF  = $6100
TILE_TAB = $6200
S00_TAB  = $6300
S01_TAB  = $6400

Trap:
    NOP
SwitchBank:
    RTS
LogA:
    LDY LOG_IDX
    STA LOG_BUF, Y
    INC LOG_IDX
    RTS
GetCollidingTileMoving:
    LDA #'G'
    JSR LogA
    TXA
    JSR LogA
    LDA $0F
    JSR LogA
    LDA ObjX, X
    JSR LogA
    LDA ObjY, X
    JSR LogA
    LDY CALL_IDX
    LDA S00_TAB, Y
    STA $00
    LDA S01_TAB, Y
    STA $01
    LDA TILE_TAB, Y
    STA ObjCollidedTile, X
    INC CALL_IDX
    RTS
Anim_WriteStaticItemSpritesWithAttributes:
    STX TMPX
    STY TMPY
    PHA
    LDA #'D'
    JSR LogA
    PLA
    JSR LogA
    LDA TMPX
    JSR LogA
    LDA TMPY
    JSR LogA
    LDA $00
    JSR LogA
    LDA $01
    JSR LogA
    LDA $0F
    JSR LogA
    LDX TMPX
    RTS
AnimateObjectWalking:
    STX TMPX
    LDA #'W'
    JSR LogA
    LDA TMPX
    JSR LogA
    LDX TMPX
    RTS
Link_EndMoveAndAnimate_Bank4:
    STX TMPX
    LDA #'L'
    JSR LogA
    LDX TMPX
    RTS
"""

LD_CFG = """MEMORY { ROM: start = $8000, size = $8000, fill = yes; }
SEGMENTS { CODE: load = ROM, type = ro; }
"""

C_SOURCES = ["src/game/world/link_ladder.c", "src/game/world/dock.c",
             "src/game/core/core_dispatch.c", "src/game/room/room_dispatch.c"]
# Data symbols the C objects reference but do not define (dummy storage);
# every other unresolved symbol becomes an aborting function.
C_DATA_STUBS = {"LevelNumberTransferBuf", "MenuPalettesTransferBuf",
                "SaveSlotToPaletteRowOffset"}


def cut(fname: str, start: str, end: str) -> str:
    lines = (REF / fname).read_text(encoding="latin-1").splitlines()
    i = next(k for k, l in enumerate(lines) if l.startswith(start))
    j = next(k for k in range(i + 1, len(lines)) if lines[k].startswith(end))
    return "\n".join(lines[i:j]) + "\n"


def build_6502(td: Path) -> tuple[bytes, dict[str, int]]:
    src = ['.INCLUDE "Variables.inc"', '.INCLUDE "CommonVars.inc"',
           '.SEGMENT "CODE"', STUBS_ASM]
    for f, a, b, extra in RANGES:
        # Z_07's L1F1FC_Exit (an RTS just above LinkToLadderOffsetsX) is a
        # short-branch target of Link_EndMoveAndAnimate: keep it in reach.
        pre = "L1F1FC_Exit:\n    RTS\n" if a == "Link_EndMoveAndAnimate:" else ""
        src.append(f"; ---- {f} {a} .. {b}\n" + pre + cut(f, a, b) + extra)
    (td / "eq.s").write_text("\n".join(src), encoding="latin-1")
    (td / "eq.cfg").write_text(LD_CFG)
    subprocess.run(["ca65", "-g", "-I", str(REF), "-o", str(td / "eq.o"), str(td / "eq.s")],
                   check=True)
    subprocess.run(["ld65", "-C", str(td / "eq.cfg"), "-o", str(td / "eq.bin"),
                    "-Ln", str(td / "eq.lbl"), str(td / "eq.o")], check=True)
    labels = {}
    for line in (td / "eq.lbl").read_text().splitlines():
        p = line.split()
        if len(p) == 3 and p[0] == "al":
            labels[p[2].lstrip(".")] = int(p[1], 16)
    return (td / "eq.bin").read_bytes(), labels


def build_c(td: Path) -> ctypes.CDLL:
    sys.path.insert(0, str(ROOT / "tools" / "debug"))
    argv, sys.argv = sys.argv, [sys.argv[0]]
    import build_debug as b  # noqa: E402
    sys.argv = argv
    flags = [f for f in b.CFLAGS if f not in ("-m68000", "-ffixed-a4", "-O3")]
    flags += ["-DROOMROM_BUILD", "-O1", "-fPIC", "-w", "-Dalways_inline=noinline"]
    incs = [f"-I{HERE.parent / 'host_sgdk_stub'}"] + b.include_args()
    objs = []
    for k, s in enumerate(C_SOURCES + [str(HERE / "harness_stubs.c")]):
        o = td / f"c{k}.o"
        subprocess.run(["gcc", "-c"] + flags + incs + [s, "-o", str(o)], cwd=ROOT, check=True)
        objs.append(o)
    defined, undef = set(), set()
    for o in objs:
        for line in subprocess.run(["nm", str(o)], capture_output=True, text=True).stdout.splitlines():
            p = line.split()
            if len(p) == 3 and p[1] in "TDRBC":
                defined.add(p[2])
            elif len(p) == 2 and p[0] == "U":
                undef.add(p[1])
    missing = sorted(u for u in undef - defined if not u.startswith("_GLOBAL_OFFSET"))
    stub = ["#include <stdlib.h>"]
    for m in missing:
        stub.append(f"unsigned char {m}[256];" if m in C_DATA_STUBS
                    else f"void {m}(void) {{ abort(); }}")
    (td / "missing.c").write_text("\n".join(stub) + "\n")
    subprocess.run(["gcc", "-c", "-fPIC", "-w", str(td / "missing.c"), "-o", str(td / "missing.o")],
                   check=True)
    so = td / "eq.so"
    subprocess.run(["gcc", "-shared", "-o", str(so)] + [str(o) for o in objs] +
                   [str(td / "missing.o")], check=True)
    return ctypes.CDLL(str(so))


class Nes:
    def __init__(self, rom: bytes, labels: dict[str, int]):
        from py65.devices.mpu6502 import MPU
        self.MPU = MPU
        self.rom, self.labels = rom, labels

    def run(self, mem: bytearray, entry: str, x: int = 0) -> bytearray:
        mpu = self.MPU()
        m = bytearray(0x10000)
        m[0:0x8000] = mem
        m[0x8000:0x10000] = self.rom
        mpu.memory = m
        trap = self.labels["Trap"]
        mpu.sp = 0xFF
        ret = trap - 1
        mpu.memory[0x100 + mpu.sp] = (ret >> 8) & 0xFF; mpu.sp -= 1
        mpu.memory[0x100 + mpu.sp] = ret & 0xFF; mpu.sp -= 1
        mpu.pc, mpu.x, mpu.a, mpu.y = self.labels[entry], x, 0, 0
        for _ in range(100000):
            if mpu.pc == trap:
                return bytearray(m[0:0x8000])
            mpu.step()
        raise RuntimeError(f"{entry}: no return")


# ---------------------------------------------------------------- inputs

DIRS = [1, 2, 4, 8]


def pick(r: random.Random, common, p=0.85):
    return r.choice(common) if r.random() < p else r.randrange(256)


def base_mem(r: random.Random) -> bytearray:
    mem = bytearray(r.randrange(256) for _ in range(0x8000))
    mem[0x6000] = 0                       # LOG_IDX
    mem[0x6001] = 0                       # CALL_IDX
    for k in range(16):                   # callee results
        mem[0x6200 + k] = r.choice([0xF4, 0x8D, 0x98, 0x99, 0x8C, 0x26, 0x00, r.randrange(256)])
        mem[0x6300 + k] = r.randrange(256) if r.random() < 0.8 else 0
        mem[0x6400 + k] = r.randrange(256)
    return mem


def case_check_ladder(r: random.Random) -> bytearray:
    m = base_mem(r)
    x = r.randrange(1, 12) if r.random() < 0.9 else 0
    m[0x64] = x
    lx, ly = r.randrange(256), r.randrange(256)
    m[0x70], m[0x84] = lx, ly
    if x:
        m[0xAC + x] = r.choice([0, 1, 2, 1, 2, r.randrange(256)])
        d = r.choice(DIRS) if r.random() < 0.9 else r.randrange(1, 16)
        m[0x98 + x] = d
        off = r.choice([0, 1, 4, 8, 0x0F, 0x10, 0x11, 0xF0, 0xF8, 0xFF, 0xF1, r.randrange(256)])
        if d & 0x0C:
            m[0x70 + x] = lx if r.random() < 0.85 else r.randrange(256)
            m[0x84 + x] = (ly + 3 - off) & 0xFF
        else:
            m[0x84 + x] = (ly + 3) & 0xFF if r.random() < 0.85 else r.randrange(256)
            m[0x70 + x] = (lx - off) & 0xFF
    m[0x98] = r.choice(DIRS) if r.random() < 0.9 else r.randrange(1, 16)
    m[0x3F8] = pick(r, [0, 1, 2, 4, 8, 8, 4])
    m[0x0F] = pick(r, [0, 1, 2, 4, 8])
    m[0x34A] = pick(r, [0x78, 0x84, 0x26, 0x8D, 0xF4])
    return m


def case_end_move(r: random.Random) -> bytearray:
    m = base_mem(r)
    if r.random() < 0.5:
        # Every precondition met, then at most one perturbed below.
        m[0x522], m[0x12], m[0x394], m[0x53], m[0x663] = 0, 5, 0, 0, 1
        m[0xAC], m[0x64] = 0, 0
        m[0x10] = r.choice([0, r.randrange(1, 10)])
        m[0xEB] = r.choice([0x17, 0x18, 0x19, 0x27, 0x4F, 0x5F])
        d = r.choice(DIRS)
        m[0x98] = m[0x3F8] = d
        for k in range(4):
            m[0x6200 + k] = 0xF4 if m[0x10] else r.choice([0x8D, 0x90, 0x98])
        for s in range(1, 12):
            m[0x34F + s] = 0 if r.random() < 0.3 else r.randrange(1, 256)
        cell = r.choice([None, None, 0x522, 0x12, 0x394, 0x53, 0x663, 0xAC, 0x64, 0x3F8, 0xEB, 0x6200])
        if cell is not None:
            m[cell] = r.randrange(256)
            if cell == 0x394 and m[cell] & 7 == 0 and m[cell] != 0:
                m[cell] |= 1
        return m
    m[0x522] = 0 if r.random() < 0.9 else r.randrange(1, 256)
    m[0x12] = r.choice([5, 5, 5, 5, 4, 6, 7, 0x0B, r.randrange(256)])
    # ObjGridOffset: 0 or not a multiple of 8 (the Genesis mover truncates
    # +-8 before this point; the NES does it here).
    g = r.choice([0, 0, 0, r.randrange(256)])
    if g & 7 == 0 and g != 0:
        g |= 1
    m[0x394] = g
    m[0x10] = 0 if r.random() < 0.5 else r.randrange(1, 10)
    m[0xEB] = r.choice([0x17, 0x18, 0x19, 0x27, 0x4F, 0x5F, r.randrange(256)])
    m[0x53] = 0 if r.random() < 0.85 else r.randrange(1, 256)
    m[0x663] = 1 if r.random() < 0.85 else 0
    m[0xAC] = r.choice([0, 0, 0, 0x40, 0x41, 0x10, 0x80, r.randrange(256)])
    m[0x64] = 0 if r.random() < 0.85 else r.randrange(1, 256)
    d = r.choice(DIRS) if r.random() < 0.9 else r.randrange(1, 16)
    m[0x98] = d
    m[0x3F8] = d if r.random() < 0.7 else pick(r, [0, 1, 2, 4, 8])
    for s in range(1, 12):
        m[0x34F + s] = 0 if r.random() < 0.3 else r.randrange(1, 256)
    return m


def case_dock(r: random.Random) -> tuple[bytearray, int]:
    m = base_mem(r)
    slot = r.randrange(1, 12)
    m[0x660] = 1 if r.random() < 0.9 else 0
    m[0xAC + slot] = r.choice([0, 0, 1, 2, r.randrange(256)])
    m[0xEB] = r.choice([0x55, 0x3F, r.randrange(256)])
    m[0x70] = r.choice([0x80, 0x60, r.randrange(256)])
    m[0x84] = r.choice([0x3D, 0x7D, 0x3E, 0x7E, 0x7F, 0x80, 0x3C, r.randrange(256)])
    return m, slot


# The harness enters with SP $FF; the call chains here stay above $01C0.
STACK_LO = 0x1C0


def compare(name: str, k: int, nes: bytearray, c: bytearray) -> list[str]:
    errs = []
    for a in range(0x800):
        if STACK_LO <= a <= 0x1FF:
            continue                      # 6502 return stack of this harness
        if nes[a] != c[a]:
            errs.append(f"{name} case {k}: RAM ${a:04X} NES {nes[a]:02X} C {c[a]:02X}")
    ln, lc = nes[0x6000], c[0x6000]
    if nes[0x6100:0x6100 + ln] != c[0x6100:0x6100 + lc]:
        errs.append(f"{name} case {k}: log NES {nes[0x6100:0x6100+ln].hex()} C {c[0x6100:0x6100+lc].hex()}")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cases", type=int, default=20000)
    ap.add_argument("--seed", type=int, default=56)
    a = ap.parse_args()
    for tool in ("ca65", "ld65", "gcc", "nm"):
        if not shutil.which(tool):
            print(f"FAIL: {tool} not found (cc65 / host gcc required)")
            return 1
    try:
        import py65  # noqa: F401
    except ImportError:
        print("FAIL: py65 not installed (pip install py65)")
        return 1
    r = random.Random(a.seed)
    with tempfile.TemporaryDirectory() as tdn:
        td = Path(tdn)
        rom, labels = build_6502(td)
        lib = build_c(td)
        nes = Nes(rom, labels)
        gmem = (ctypes.c_ubyte * 0x8000).in_dll(lib, "g_mem")

        def run_c(mem: bytearray, fn, *args) -> bytearray:
            ctypes.memmove(gmem, bytes(mem), 0x8000)
            fn(*args)
            return bytearray(gmem)

        errs: list[str] = []
        case_e = 0
        stats = {"CheckLadder": [0, 0], "EndMove": [0, 0], "UpdateDock": [0, 0]}
        for k in range(a.cases):
            m = case_check_ladder(r)
            n = nes.run(m, "CheckLadder")
            ctypes.memmove(gmem, bytes(m), 0x8000)
            lib.eq_check_ladder()
            f0 = gmem[0x0F]
            lib.eq_draw_ladder()
            c = bytearray(gmem)
            # The deferred draw's own [0F] = 0 is Genesis-side (the NES
            # writes [0F] = moving dir after its inline draw).
            c[0x0F] = f0
            e = compare("CheckLadder", k, n, c)
            errs += e
            stats["CheckLadder"][0] += 1
            log = bytes(n[0x6100:0x6100 + n[0x6000]])
            stats["CheckLadder"][1] += (b"D" in log)
            case_e += (log.count(b"G") > 0)

            m = case_end_move(r)
            n = nes.run(m, "Link_EndMoveAndAnimate")
            c = run_c(m, lib.eq_end_move)
            errs += compare("EndMove", k, n, c)
            stats["EndMove"][0] += 1
            stats["EndMove"][1] += (n[0x64] != m[0x64])

            m, slot = case_dock(r)
            n = nes.run(m, "UpdateDock", x=slot)
            c = run_c(m, lib.eq_dock, ctypes.c_uint(slot))
            errs += compare("UpdateDock", k, n, c)
            stats["UpdateDock"][0] += 1
            stats["UpdateDock"][1] += (n[0xAC + slot] != m[0xAC + slot] or n[0x84] != m[0x84])
            if len(errs) > 40:
                break
        for name, (total, active) in stats.items():
            print(f"{name}: {total} cases, {active} took the active path "
                  "(ladder drawn / ladder placed / raft moved or halted)")
        print(f"CheckLadder case E (tile 8 px up): {case_e} cases")
        if errs:
            print("\n".join(errs[:40]))
            print(f"FAIL: {len(errs)} differences")
            return 1
        print("PASS: NES RAM $0000-$07FF and callee logs identical in every case")
        return 0


if __name__ == "__main__":
    sys.exit(main())
