"""Specs for asm_equiv.py: NES routine (6502) vs C port.

Spec keys:
  name, doc      identifier / one line
  asm            [(file, first label, end label exclusive[, prefix, suffix])]
                 cut verbatim from reference/aldonunez; unresolved labels are
                 auto-stubbed as "unexpected call" traps
  asm_stubs      6502 stub code (labels the cut code calls on purpose)
  incs           extra reference/aldonunez .inc files (e.g. ObjVars.inc)
  entry          6502 entry label
  c_sources      C translation units (repo-relative); missing symbols are
                 auto-stubbed as "unexpected call"
  c_stub_files / c_stubs   C stubs mirroring asm_stubs
  gen(r, mem)    -> case dict: mem, a, x, y, carry, ignore, note
  call(lib, case)          run the C port on g_mem, return its result
  ret            "A": compare the returned value with the NES A register;
                 "C": compare carry_of(returned value) with the NES carry
  post(case, nes, c)       adjust the C image for a documented divergence
  ignore         addresses never compared (documented per spec)
  active(case, nes)        counts cases that took the interesting path
"""
from __future__ import annotations

import ctypes

DIRS = [1, 2, 4, 8]


def pick(r, common, p=0.85):
    return r.choice(common) if r.random() < p else r.randrange(256)


# ------------------------------------------------------------------ T-056

STUBS_T056_ASM = r"""
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
    LDY H_CALL_IDX
    LDA $5300, Y
    STA $00
    LDA $5400, Y
    STA $01
    LDA $5200, Y
    STA ObjCollidedTile, X
    INC H_CALL_IDX
    RTS
Anim_WriteStaticItemSpritesWithAttributes:
    STX H_TMPX
    PHA
    LDA #'D'
    JSR LogA
    PLA
    JSR LogA
    LDA H_TMPX
    JSR LogA
    TYA
    JSR LogA
    LDA $00
    JSR LogA
    LDA $01
    JSR LogA
    LDA $0F
    JSR LogA
    RTS
AnimateObjectWalking:
    STX H_TMPX
    LDA #'W'
    JSR LogA
    LDA H_TMPX
    JSR LogA
    RTS
Link_EndMoveAndAnimate_Bank4:
    LDA #'L'
    JSR LogA
    RTS
"""

T056_ASM = [
    ("Z_05.asm", "CheckLadder:", "FindNextEdgeSpawnCell:"),
    ("Z_07.asm", "LinkToLadderOffsetsX:", "LinkHeadTiles:"),
    ("Z_07.asm", "LadderRoomsOW:", "Link_EndMoveAndAnimate_Bank4:"),
    # Up to @CheckWarps: CheckWarps/AnimateLinkBase are not part of the
    # ladder port. Z_07's L1F1FC_Exit (an RTS) is kept in branch reach.
    ("Z_07.asm", "Link_EndMoveAndAnimate:", "@CheckWarps:",
     "L1F1FC_Exit:\n    RTS\n", "@CheckWarps:\n    RTS\n"),
    ("Z_07.asm", "GoToNextModeFromPlay:", "CheckBoundary:"),
    ("Z_07.asm", "ResetShoveInfo:", "ShoveMoveMin:"),
    ("Z_07.asm", "DestroyMonster:", "InitTileObjOrItem:"),
    ("Z_07.asm", "Anim_FetchObjPosForSpriteDescriptor:", "RollOverAnimCounter:"),
    ("Z_01.asm", "OppositeDirs:", "MoveShot:"),
    ("Z_01.asm", "DestroyObject_WRAM:", "UpdateBombFlashEffect:"),
    ("Z_04.asm", "RaftDirections:", "UpdateFlyingGhini:"),
    ("Z_04.asm", "PlaySecretFoundTune:", "; Unknown block"),
]
T056_C = ["src/game/world/link_ladder.c", "src/game/world/dock.c",
          "src/game/core/core_dispatch.c", "src/game/room/room_dispatch.c"]


def gen_check_ladder(r, m):
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
    # Direction 0 never reaches GetOppositeDir here (ObjDir is set).
    m[0x98] = r.choice(DIRS) if r.random() < 0.9 else r.randrange(1, 16)
    m[0x3F8] = pick(r, [0, 1, 2, 4, 8, 8, 4])
    m[0x0F] = pick(r, [0, 1, 2, 4, 8])
    m[0x34A] = pick(r, [0x78, 0x84, 0x26, 0x8D, 0xF4])
    return {"mem": m}


def call_check_ladder(lib, case):
    gmem = (ctypes.c_ubyte * 0x8000).in_dll(lib, "g_mem")
    lib.link_ladder_check()
    case["f0"] = gmem[0x0F]
    lib.link_ladder_draw()
    return 0


def post_check_ladder(case, n, c):
    # The deferred draw's own [0F] = 0 is Genesis-side (the NES writes
    # [0F] = moving dir after its inline draw).
    c[0x0F] = case["f0"]


def gen_end_move(r, m):
    if r.random() < 0.5:
        # Every precondition met, then at most one perturbed below.
        m[0x522], m[0x12], m[0x394], m[0x53], m[0x663] = 0, 5, 0, 0, 1
        m[0xAC], m[0x64] = 0, 0
        m[0x10] = r.choice([0, r.randrange(1, 10)])
        m[0xEB] = r.choice([0x17, 0x18, 0x19, 0x27, 0x4F, 0x5F])
        d = r.choice(DIRS)
        m[0x98] = m[0x3F8] = d
        for k in range(4):
            m[0x5200 + k] = 0xF4 if m[0x10] else r.choice([0x8D, 0x90, 0x98])
        for s in range(1, 12):
            m[0x34F + s] = 0 if r.random() < 0.3 else r.randrange(1, 256)
        cell = r.choice([None, None, 0x522, 0x12, 0x394, 0x53, 0x663, 0xAC, 0x64, 0x3F8, 0xEB, 0x5200])
        if cell is not None:
            m[cell] = r.randrange(256)
    else:
        m[0x522] = 0 if r.random() < 0.9 else r.randrange(1, 256)
        m[0x12] = r.choice([5, 5, 5, 5, 4, 6, 7, 0x0B, r.randrange(256)])
        m[0x394] = r.choice([0, 0, 0, r.randrange(256)])
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
    # ObjGridOffset a nonzero multiple of 8 is truncated by the Genesis
    # mover before this point; the NES truncates it here.
    if m[0x394] & 7 == 0 and m[0x394] != 0:
        m[0x394] |= 1
    return {"mem": m}


def gen_dock(r, m):
    slot = r.randrange(1, 12)
    m[0x660] = 1 if r.random() < 0.9 else 0
    m[0xAC + slot] = r.choice([0, 0, 1, 2, r.randrange(256)])
    m[0xEB] = r.choice([0x55, 0x3F, r.randrange(256)])
    m[0x70] = r.choice([0x80, 0x60, r.randrange(256)])
    m[0x84] = r.choice([0x3D, 0x7D, 0x3E, 0x7E, 0x7F, 0x80, 0x3C, r.randrange(256)])
    return {"mem": m, "x": slot}


T056_COMMON = dict(asm=T056_ASM, asm_stubs=STUBS_T056_ASM, c_sources=T056_C,
                   c_stub_files=["stubs_t056.c"])

SPECS = [
    dict(name="CheckLadder", doc="T-056 Z_05 CheckLadder vs link_ladder_check+draw",
         entry="CheckLadder", gen=gen_check_ladder, call=call_check_ladder,
         post=post_check_ladder,
         active=lambda c, n: b"D" in bytes(n[0x5100:0x5100 + n[0x5000]]), **T056_COMMON),
    dict(name="LadderSetup", doc="T-056 Z_07 Link_EndMoveAndAnimate ladder half",
         entry="Link_EndMoveAndAnimate", gen=gen_end_move,
         call=lambda lib, c: lib.link_ladder_end_move(),
         active=lambda c, n: n[0x64] != c["mem"][0x64], **T056_COMMON),
    dict(name="UpdateDock", doc="T-056 Z_04 UpdateDock vs world_update_dock",
         entry="UpdateDock", gen=gen_dock,
         call=lambda lib, c: lib.world_update_dock(ctypes.c_uint(c["x"])),
         active=lambda c, n: n[0xAC + c["x"]] != c["mem"][0xAC + c["x"]] or n[0x84] != c["mem"][0x84],
         **T056_COMMON),
]

from specs_core import SPECS as _CORE  # noqa: E402
SPECS += _CORE
