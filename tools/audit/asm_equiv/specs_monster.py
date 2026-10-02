"""Monster AI specs (T-171 batch 6): per-type update routines vs the drained C.

Boundary: DrawObjectMirrored / DrawObjectNotMirrored and CheckMonsterCollisions
are logged stubs on both sides (frame, slot, [00], [01], [0F] / slot).
Everything else (Walker_Move, Wanderer_TargetPlayer, _TryShooting,
_ShootIfWanted, Anim_FetchObjPosForSpriteDescriptor) runs for real.
"""
from __future__ import annotations

import ctypes

from specs_core import WALKER_ASM, WALKER_C, gen_walker

U = ctypes.c_uint

STUBS_MONSTER_ASM = r"""
EqLogDraw:
    STX H_TMPX
    JSR LogA
    LDA $5005
    JSR LogA
    LDA H_TMPX
    JSR LogA
    LDA $00
    JSR LogA
    LDA $01
    JSR LogA
    LDA $0F
    JSR LogA
    LDX H_TMPX
    RTS
DrawObjectMirrored:
    STA $5005
    LDA #'M'
    JSR EqLogDraw
    LDA $5005
    RTS
DrawObjectNotMirrored:
    STA $5005
    LDA #'N'
    JSR EqLogDraw
    LDA $5005
    RTS
CheckMonsterCollisions:
    STX H_TMPX
    LDA #'K'
    JSR LogA
    LDA H_TMPX
    JSR LogA
    LDX H_TMPX
    RTS
"""

MONSTER_ASM = WALKER_ASM + [
    # UpdateCommonWanderer, Wanderer_TargetPlayer, UpdateGoriya and the
    # boomerang tail in one piece (they branch into each other).
    ("Z_04.asm", "UpdateCommonWanderer:", "BlockPushDirections:"),
    ("Z_04.asm", "UpdateMoblin:", "UpdateMonsterArrow:"),
    ("Z_04.asm", "_ShootIfWanted:", "UpdateCandle:"),
    ("Z_07.asm", "SetTypeAndClearObject:", "InitTileObjOrItem:"),
    ("Z_07.asm", "Anim_AdvanceAnimCounterAndSetObjPosForSpriteDescriptor:", "AnimateLinkObjState:"),
    ("Z_01.asm", "DestroyObject_WRAM:", "UpdateBombFlashEffect:"),
]
MONSTER_C = WALKER_C + ["src/oracle/enemies/enemy_wanderer_runtime.c",
                        "src/game/world/sprite_dispatch.c"]
MONSTER_COMMON = dict(asm_stubs=STUBS_MONSTER_ASM, incs=["ObjVars.inc"],
                      c_stub_files=["stubs_monster.c"],
                      # [00]-[03]: TableJump pointer scratch inside Walker_Move
                      # (see Walker_Move spec); the draw stubs log [00]/[01]
                      # as passed, so the drawn position is still compared.
                      ignore={0x00, 0x01, 0x02, 0x03})


def gen_monster_slots(r, m, x):
    """Shared walker/shooter context: other slots, shots, AI cells."""
    m[0x340] = x                                           # CurObjIndex
    for s in range(1, 12):
        if s != x:
            m[0x34F + s] = 0 if r.random() < 0.25 else r.randrange(1, 0x80)
    m[0x34C] = r.choice([0, 1, 2, 3, 4])                   # ActiveMonsterShots
    m[0x451 + x] = r.choice([0, 0, 0, 1, 2, 0x10, 0x11, 0x0F, 0x30, r.randrange(0x31)])
    m[0x412 + x] = r.choice([0, 1])                        # ObjWantsToShoot
    m[0x478 + x] = r.choice([0, 0, 1, r.randrange(256)])   # ObjTurnTimer
    m[0x4F0 + x] = 0 if r.random() < 0.85 else r.randrange(1, 0x20)
    m[0x3D0 + x] = r.choice([1, 1, 2, 6, r.randrange(1, 256)])   # ObjAnimCounter
    m[0x3E4 + x] = r.choice([0, 3])                        # ObjAnimFrame
    m[0xAC] = 0xFF if r.random() < 0.05 else m[0xAC]       # Link state $FF path
    m[0x61], m[0x62] = (m[0x70 + x] + r.randrange(-12, 13)) & 0xFF, \
        (m[0x84 + x] + r.randrange(-12, 13)) & 0xFF        # ChaseTarget near


def gen_octorock(r, m):
    c = gen_walker(r, m)
    x = c["x"]
    m[0x34F + x] = r.choice([0x07, 0x08, 0x09, 0x0A])
    gen_monster_slots(r, m, x)
    return c


SPECS = [
    dict(name="UpdateOctorock", doc="Z_04 UpdateOctorock (turn rate, Wanderer_TargetPlayer, "
         "_TryShooting rock, frame select, draw) vs enrt_update_octorock",
         asm=MONSTER_ASM + [("Z_04.asm", "UpdateOctorock:", "UpdateGhini:")],
         c_sources=MONSTER_C, entry="UpdateOctorock", gen=gen_octorock,
         call=lambda lib, c: lib.enrt_update_octorock(U(c["x"])),
         active=lambda c, n: n[0x34C] != c["mem"][0x34C], **MONSTER_COMMON),
]


WANDERER_ASM = MONSTER_ASM + [
    ("Z_04.asm", "AnimateAndDrawCommonObject:", "UpdateKeese:"),
    ("Z_07.asm", "Anim_SetObjHFlipForSpriteDescriptor:", "SetUpHorizontalWalkingSprites:"),

]
WANDERER_C = MONSTER_C + ["src/oracle/enemies/enemy_walker_runtime.c"]


def gen_typed(types):
    def gen(r, m):
        c = gen_walker(r, m)
        x = c["x"]
        m[0x34F + x] = r.choice(types)
        gen_monster_slots(r, m, x)
        # Goriya delay-after-shot state ($80+) and the armos exemption
        # (ObjType+1 = $1E) are both reachable.
        m[0xAC + x] = r.choice([0, 0, 0, 0x80, 0x81, r.randrange(256)])
        if r.random() < 0.1:
            m[0x350 + x] = 0x1E
        m[0x28 + x] = r.choice([0, 0, r.randrange(256)])   # ObjTimer (boomerang gate)
        m[0x16] = r.randrange(3)                          # CurSaveSlot
        m[0x62D + m[0x16]] = r.choice([0, 1])             # QuestNumbers
        return c
    return gen


def wanderer_spec(name, entry, types, cfun, nes_end, doc):
    return dict(name=name, doc=doc, asm=WANDERER_ASM + nes_end, c_sources=WANDERER_C,
                entry=entry, gen=gen_typed(types),
                call=lambda lib, c: getattr(lib, cfun)(U(c["x"])),
                active=lambda c, n: n[0x34C] != c["mem"][0x34C], **MONSTER_COMMON)


SPECS += [
    wanderer_spec("UpdateMoblin", "UpdateMoblin", [0x03, 0x04], "enrt_update_moblin", [],
                  "Z_04 UpdateMoblin (Wanderer_TargetPlayer + arrow) vs enrt_update_moblin"),
    wanderer_spec("UpdateLynel", "UpdateLynel", [0x01, 0x02], "enrt_update_lynel", [],
                  "Z_04 UpdateLynel (UpdateGoriya AI + sword shot) vs enrt_update_lynel"),
    wanderer_spec("UpdateGoriya", "UpdateGoriya", [0x05, 0x06], "enrt_update_goriya", [],
                  "Z_04 UpdateGoriya (AI + boomerang) vs enrt_update_goriya"),
    wanderer_spec("UpdateStalfos", "UpdateStalfos", [0x2A], "enrt_update_stalfos",
                  [("Z_04.asm", "UpdateStalfos:", "InitMoldorm:")],
                  "Z_04 UpdateStalfos (common wanderer, draw, Q2 sword shot) vs enrt_update_stalfos"),
    wanderer_spec("UpdateDarknut", "UpdateDarknut", [0x0B, 0x0C], "enrt_update_darknut",
                  [("Z_04.asm", "UpdateDarknut:", "PolsVoiceWalkSpeedsX:")],
                  "Z_04 UpdateDarknut (common wanderer, frame select) vs enrt_update_darknut"),
]
