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
CheckLinkCollision:
    STX H_TMPX
    LDA #'L'
    JSR LogA
    LDA H_TMPX
    JSR LogA
    LDX H_TMPX
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


# ------------------------------------------------ rope, zol, gel

COMMON_C = WANDERER_C + ["src/game/enemies/enemy_common_bridge.c",
                         "src/game/enemies/enemy_projectile_bridge.c",
                         "src/game/enemies/enemy_flyer_bridge.c",
                         "src/oracle/enemies/enemy_common_runtime.c"]
ZOL_ASM = WANDERER_ASM + [
    ("Z_04.asm", "UpdateZol:", "StatueRoomLayouts:"),     # incl. ZolGelDelays
    ("Z_07.asm", "DestroyMonster:", "InitTileObjOrItem:"),
    ("Z_01.asm", "Anim_SetSpriteDescriptorAttributes:", "Anim_WriteLevelPaletteSprite:"),
]


def gen_zol(types):
    base = gen_typed(types)

    def gen(r, m):
        c = base(r, m)
        x = c["x"]
        m[0xAC + x] = r.choice([0, 0, 1, 2, 0, 1])          # Zol state 0..2
        m[0x3D0 + x] = r.choice([1, 2, 0x10, r.randrange(1, 256)])
        return c
    return gen


SPECS += [
    dict(name="UpdateRope", doc="Z_04 UpdateRope (walk, charge at $60, Q2 palette) vs enrt_update_rope",
         asm=ZOL_ASM + [("Z_04.asm", "UpdateRope:", "UpdateStalfos:")],
         c_sources=COMMON_C, entry="UpdateRope", gen=gen_typed([0x28]),
         call=lambda lib, c: lib.enrt_update_rope(U(c["x"])), **MONSTER_COMMON),
    dict(name="UpdateZol", doc="Z_04 UpdateZol (state machine, split into gels) vs enrt_update_zol",
         asm=ZOL_ASM, c_sources=COMMON_C, entry="UpdateZol", gen=gen_zol([0x13]),
         call=lambda lib, c: lib.enrt_update_zol(U(c["x"])),
         active=lambda c, n: n[0x34F + c["x"]] != c["mem"][0x34F + c["x"]], **MONSTER_COMMON),
    dict(name="UpdateGel", doc="Z_04 UpdateGel (Gel_Move, draw at X+4) vs enrt_update_gel",
         asm=ZOL_ASM, c_sources=COMMON_C, entry="UpdateGel", gen=gen_zol([0x14, 0x15]),
         call=lambda lib, c: lib.enrt_update_gel(U(c["x"])), **MONSTER_COMMON),
]


# ------------------------------------------------ ghini, flyers

FLYER_ASM = ZOL_ASM + [
    ("Z_04.asm", "UpdateKeese:", "UpdateZol:"),
    ("Z_04.asm", "Directions8:", "PatraSines:"),
    ("Z_04.asm", "UpdateGhini:", "SecretArmosRoomIds:"),
    ("Z_04.asm", "UpdateFlyingGhini:", "PlaySecretFoundTune:"),
    ("Z_07.asm", "ResetMovingDir:", "GoWalkableDir:"),
    ("Z_07.asm", "ResetShoveInfo:", "ShoveMoveMin:"),
]
FLYER_C = COMMON_C + ["src/oracle/enemies/enemy_flyer_runtime.c",
                      "src/game/enemies/enemy_dispatch.c",
                      "src/game/enemies/enemy_jumper_bridge.c"]


def gen_flyer(types):
    base = gen_typed(types)

    def gen(r, m):
        c = base(r, m)
        x = c["x"]
        m[0x444 + x] = r.randrange(6)                         # Flyer_ObjFlyingState
        m[0x42C + x] = pick(r, [0, 1, 2, 6])                  # Flyer_ObjTurns
        m[0x41F + x] = pick(r, [0x00, 0x20, 0x40, 0x80, 0xA0, 0xC0])
        m[0x98 + x] = r.choice([8, 9, 1, 5, 4, 6, 2, 0x0A])
        m[0x70 + x], m[0x84 + x] = r.randrange(0x10, 0xF0), r.randrange(0x40, 0xE0)
        return c
    return gen


def pick(r, common, p=0.85):
    return r.choice(common) if r.random() < p else r.randrange(256)


SPECS += [
    dict(name="UpdateGhini", doc="Z_04 UpdateGhini (wanderer $FF, draw, kill flying ghinis) vs enrt_update_ghini",
         asm=FLYER_ASM, c_sources=FLYER_C, entry="UpdateGhini", gen=gen_typed([0x21]),
         call=lambda lib, c: lib.enrt_update_ghini(U(c["x"])), **MONSTER_COMMON),
    dict(name="UpdateFlyingGhini", doc="Z_04 UpdateFlyingGhini vs enrt_update_flying_ghini",
         asm=FLYER_ASM, c_sources=FLYER_C, entry="UpdateFlyingGhini", gen=gen_flyer([0x22]),
         call=lambda lib, c: lib.enrt_update_flying_ghini(U(c["x"])), **MONSTER_COMMON),
    dict(name="UpdatePeahat", doc="Z_04 UpdatePeahat vs enrt_update_peahat",
         asm=FLYER_ASM, c_sources=FLYER_C, entry="UpdatePeahat", gen=gen_flyer([0x1A]),
         call=lambda lib, c: lib.enrt_update_peahat(U(c["x"])), **MONSTER_COMMON),
    dict(name="UpdateKeese", doc="Z_04 UpdateKeese (flight, draw, collisions, shove reset) vs enrt_update_keese",
         asm=FLYER_ASM, c_sources=FLYER_C, entry="UpdateKeese", gen=gen_flyer([0x1B, 0x1C, 0x1D]),
         call=lambda lib, c: lib.enrt_update_keese(U(c["x"])), **MONSTER_COMMON),
]


# ------------------------------------------------ closure-built specs
# The NES side comes from closure.py: everything reachable from the entry
# in the game banks below, stopping at the logged stubs.

BANKS = ["Z_04.asm", "Z_07.asm", "Z_01.asm", "Z_05.asm"]


def _enemy_c_all() -> list[str]:
    """Every Debug-build TU of the enemy runtime and its substrate, except
    the draw / Link-collision owners (logged stubs) and render/probe code."""
    import sys
    from pathlib import Path
    root = Path(__file__).resolve().parents[3]
    sys.path.insert(0, str(root / "tools" / "debug"))
    argv, sys.argv = sys.argv, [sys.argv[0]]
    import build_debug as b
    sys.argv = argv
    keep = ("src/oracle/enemies/", "src/game/enemies/")
    extra = {"src/game/core/core_dispatch.c", "src/game/world/object_dispatch.c",
             "src/game/world/sprite_dispatch.c", "src/game/combat/collision_dispatch.c",
             "src/game/enemies/obj_lists.c", "src/game/room/room_dispatch.c"}
    drop = ("enemy_render.c", "/probes/")
    out = []
    for src, _ in b.ROOMROM_C_SOURCES:
        src = str(src).replace("\\", "/")
        if (src.startswith(keep) or src in extra) and not any(d in src for d in drop):
            out.append(src)
    return out


ENEMY_C_ALL = _enemy_c_all()


def auto_spec(name, entry, types, cfun, c_sources, doc, gen=None, **kw):
    d = dict(name=name, doc=doc, closure={"files": BANKS, "stop": kw.pop("stop", [])},
             c_sources=c_sources, entry=entry, gen=gen or gen_typed(types),
             call=lambda lib, c: getattr(lib, cfun)(U(c["x"])))
    d.update(MONSTER_COMMON)
    d.update(kw)
    return d


SPECS += [
    auto_spec("UpdateOctorockAuto", "UpdateOctorock", [0x07, 0x08, 0x09, 0x0A],
              "enrt_update_octorock", ENEMY_C_ALL, "UpdateOctorock, closure-built NES side",
              gen=gen_octorock),
]


def gen_state(types, states):
    """gen_typed plus ObjState drawn from the routine's real state range."""
    base = gen_typed(types)

    def gen(r, m):
        c = base(r, m)
        m[0xAC + c["x"]] = r.choice(states)
        return c
    return gen


AUTO = [
    # name, NES entry, types, C function, ObjState values
    ("TektiteOrBoulder", "UpdateTektiteOrBoulder", [0x0D, 0x0E, 0x20], "enrt_update_tektite_or_boulder", range(4)),
    ("BlueLeever", "UpdateBlueLeever", [0x0F], "enrt_update_blue_leever", range(6)),
    ("RedLeever", "UpdateRedLeever", [0x10], "enrt_update_red_leever", range(6)),
    ("Zora", "UpdateZora", [0x11], "enrt_update_zora", range(6)),
    ("PolsVoice", "UpdatePolsVoice", [0x16], "enrt_update_pols_voice", range(4)),
    ("LikeLike", "UpdateLikeLike", [0x17], "enrt_update_like_like", range(4)),
    ("Armos", "UpdateArmos", [0x1E], "enrt_update_armos", range(4)),
    ("BoulderSet", "UpdateBoulderSet", [0x1F], "enrt_update_boulder_set", range(4)),
    ("BlueWizzrobe", "UpdateBlueWizzrobe", [0x23], "enrt_update_blue_wizzrobe", range(4)),
    ("RedWizzrobe", "UpdateRedWizzrobe", [0x24], "enrt_update_red_wizzrobe", range(4)),
    ("Wallmaster", "UpdateWallmaster", [0x27], "enrt_update_wallmaster", range(4)),
    ("Bubble", "UpdateBubble", [0x2B, 0x2C, 0x2D], "enrt_update_bubble", range(4)),
    ("Gibdo", "UpdateGibdo", [0x30], "enrt_update_gibdo", range(4)),
    ("GuardFire", "UpdateGuardFire", [0x3F], "enrt_update_guard_fire", range(4)),
    ("StandingFire", "UpdateStandingFire", [0x40], "enrt_update_standing_fire", range(4)),
    ("MonsterShot", "UpdateMonsterShot", [0x53, 0x54, 0x57, 0x58, 0x59, 0x5A], "enrt_update_monster_shot", [0x10, 0x10, 0x11, 0x20, 0x21, 0]),
    ("Fireball", "UpdateFireball", [0x55, 0x56], "enrt_update_fireball", [0x10, 0x10, 0x11, 0]),
    ("MonsterArrow", "UpdateMonsterArrow", [0x5B], "enrt_update_monster_arrow", [0x10, 0x10, 0x11, 0x20, 0]),
    ("ArrowOrBoomerang", "UpdateArrowOrBoomerang", [0x5C], "enrt_update_arrow_or_boomerang", [0x10, 0x10, 0x11, 0x20, 0x30, 0]),
    ("DeadDummy", "UpdateDeadDummy", [0x5D], "z07_update_dead_dummy", range(4)),
]
SPECS += [auto_spec("Update" + n, e, t, f, ENEMY_C_ALL, f"Z_04 {e} vs {f} (closure-built)",
                    gen=gen_state(t, list(st))) for n, e, t, f, st in AUTO]
