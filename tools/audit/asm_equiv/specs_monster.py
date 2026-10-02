"""Monster AI specs (T-171): per-type update routines vs the drained C.

NES side: closure.py, everything reachable from the update routine in the
game banks. C side: the whole enemy runtime (ENEMY_C_ALL).
Boundary, logged stubs on both sides: the sprite draws (DrawObject[Not]-
Mirrored[OverLink]: frame, slot, [00], [01], [0F]), CheckMonsterCollisions
(own spec) and CheckLinkCollision (slot). Everything else runs for real.
"""
from __future__ import annotations

import ctypes

from specs_core import gen_walker

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
DrawObjectMirroredOverLink:
    STA $5005
    LDA #'O'
    JSR EqLogDraw
    LDA $5005
    RTS
DrawObjectNotMirroredOverLink:
    STA $5005
    LDA #'P'
    JSR EqLogDraw
    LDA $5005
    RTS
Link_EndMoveAndAnimate_Bank4:
    LDA #'A'
    JSR LogA
    LDA ObjX
    JSR LogA
    LDA ObjY
    JMP LogA
Anim_WriteItemSprites:
    STX H_TMPX
    PHA
    LDA #'I'
    JSR LogA
    TYA
    JSR LogA
    LDA H_TMPX
    JSR LogA
    LDA $00
    JSR LogA
    LDA $01
    JSR LogA
    LDA $04
    JSR LogA
    LDA $05
    JSR LogA
    LDA $0C
    JSR LogA
    LDA $0F
    JSR LogA
    PLA
    LDX H_TMPX
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

MONSTER_COMMON = dict(asm_stubs=STUBS_MONSTER_ASM, incs=["ObjVars.inc"],
                      c_stub_files=["stubs_monster.c"],
                      # Genesis options pinned to their NES (vanilla) setting.
                      c_stubs="unsigned char options_consumer_get_like_like_behavior(void) "
                              "{ return 0; }   /* OPTIONS_LIKELIKE_VANILLA */\n",
                      # [00]-[03] hold TableJump's ROM pointers on the NES
                      # side: ignored only in cases that ran TableJump.
                      ignore_if_run={"TableJump": {0x00, 0x01, 0x02, 0x03}})
BANKS = ["Z_04.asm", "Z_07.asm", "Z_01.asm", "Z_05.asm"]


def pick(r, common, p=0.85):
    return r.choice(common) if r.random() < p else r.randrange(256)


def gen_monster_slots(r, m, x):
    """Shared walker/shooter context: other slots, shots, AI cells."""
    m[0x340] = x                                           # CurObjIndex
    m[0x341] = r.randrange(0x28)                           # RollingSpriteIndex 0..$27
    for s in range(1, 12):
        if s != x:
            m[0x34F + s] = 0 if r.random() < 0.25 else r.randrange(1, 0x80)
    m[0x34C] = r.choice([0, 1, 2, 3, 4])                   # ActiveMonsterShots
    m[0x657] = r.choice([1, 2, 3])                         # sword level (a sword is out)
    m[0x451 + x] = r.choice([0, 0, 0, 1, 2, 0x10, 0x11, 0x0F, 0x30, r.randrange(0x31)])
    m[0x412 + x] = r.choice([0, 1])                        # ObjWantsToShoot
    m[0x478 + x] = r.choice([0, 0, 1, r.randrange(256)])   # ObjTurnTimer
    m[0x4F0 + x] = 0 if r.random() < 0.85 else r.randrange(1, 0x20)
    m[0x3D0 + x] = r.choice([1, 1, 2, 6, r.randrange(1, 256)])   # ObjAnimCounter
    m[0x3E4 + x] = r.choice([0, 3])                        # ObjAnimFrame
    m[0xAC] = 0xFF if r.random() < 0.05 else m[0xAC]       # Link state $FF path
    m[0x61], m[0x62] = (m[0x70 + x] + r.randrange(-12, 13)) & 0xFF, \
        (m[0x84 + x] + r.randrange(-12, 13)) & 0xFF        # ChaseTarget near


def gen_typed(types, states=None, slots=range(1, 12)):
    """Walker context for one of types in one of slots; ObjState from
    states when given."""
    def gen(r, m):
        c = gen_walker(r, m, slots)
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
        if states is not None:
            m[0xAC + x] = r.choice(states)
        return c
    return gen


def gen_shot(types, states):
    """Projectile context: bounce direction is one of the four directions
    (Link's facing when the shield bounced it), bounce distance even < $20."""
    base = gen_typed(types, states)

    def gen(r, m):
        c = base(r, m)
        x = c["x"]
        m[0x380 + x] = r.choice([1, 2, 4, 8])                 # Shot_ObjBounceDir
        m[0x394 + x] = r.choice([0, 2, 0x10, 0x1C, 0x1E])     # Shot_ObjBounceDist
        m[0x98 + x] = r.choice([1, 2, 4, 8])
        return c
    return gen


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


def gen_zol(types):
    base = gen_typed(types, [0, 0, 1, 2, 0, 1])                # Zol state 0..2

    def gen(r, m):
        c = base(r, m)
        m[0x3D0 + c["x"]] = r.choice([1, 2, 0x10, r.randrange(1, 256)])
        return c
    return gen


def _enemy_c_all() -> list[str]:
    """Every Debug-build TU of the enemy runtime and its substrate, except
    render/probe code. The draw / Link-collision owners are linked; the
    runner weakens the functions the stub files replace."""
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
             "src/game/enemies/obj_lists.c", "src/game/room/room_dispatch.c",
             "src/game/world/world_dispatch.c", "src/game/combat/combat_dispatch.c",
             # owners of the logged stubs: those functions are weakened
             "src/game/combat/link_collision_dispatch.c", "src/game/world/draw_dispatch.c",
             "src/game/items/candle_fire.c", "src/game/items/bomb.c",
             "src/game/combat/targeting_dispatch.c"}
    drop = ("enemy_render.c", "/probes/")
    out = []
    for src, _ in b.ROOMROM_C_SOURCES:
        src = str(src).replace("\\", "/")
        if (src.startswith(keep) or src in extra) and not any(d in src for d in drop):
            out.append(src)
    return out


ENEMY_C_ALL = _enemy_c_all()
SHOT_FIRED = lambda c, n: n[0x34C] != c["mem"][0x34C]          # noqa: E731


def monster_spec(entry, cfun, gen, active=None, doc=""):
    d = dict(name=entry, doc=f"Z_04 {entry} vs {cfun}" + (f" ({doc})" if doc else ""),
             closure={"files": BANKS}, c_sources=ENEMY_C_ALL, entry=entry, gen=gen,
             call=lambda lib, c: getattr(lib, cfun)(U(c["x"])), **MONSTER_COMMON)
    if active:
        d["active"] = active
    return d


SPECS = [
    monster_spec("UpdateOctorock", "enrt_update_octorock", gen_typed([0x07, 0x08, 0x09, 0x0A]),
                 SHOT_FIRED, "turn rate, wanderer, rock, frame select"),
    monster_spec("UpdateMoblin", "enrt_update_moblin", gen_typed([0x03, 0x04]), SHOT_FIRED),
    monster_spec("UpdateLynel", "enrt_update_lynel", gen_typed([0x01, 0x02]), SHOT_FIRED),
    monster_spec("UpdateGoriya", "enrt_update_goriya", gen_typed([0x05, 0x06]), SHOT_FIRED),
    monster_spec("UpdateStalfos", "enrt_update_stalfos", gen_typed([0x2A]), SHOT_FIRED),
    monster_spec("UpdateDarknut", "enrt_update_darknut", gen_typed([0x0B, 0x0C])),
    monster_spec("UpdateRope", "enrt_update_rope", gen_typed([0x28])),
    monster_spec("UpdateZol", "enrt_update_zol", gen_zol([0x13]),
                 lambda c, n: n[0x34F + c["x"]] != c["mem"][0x34F + c["x"]], "split"),
    monster_spec("UpdateGel", "enrt_update_gel", gen_zol([0x14, 0x15])),
    monster_spec("UpdateGhini", "enrt_update_ghini", gen_typed([0x21])),
    monster_spec("UpdateFlyingGhini", "enrt_update_flying_ghini", gen_flyer([0x22])),
    monster_spec("UpdatePeahat", "enrt_update_peahat", gen_flyer([0x1A])),
    monster_spec("UpdateKeese", "enrt_update_keese", gen_flyer([0x1B, 0x1C, 0x1D])),
]

DIRS8 = [1, 2, 4, 5, 6, 8, 9, 0x0A]                       # Directions8


def gen_digdogger(types, states):
    base = gen_typed(types, states)

    def gen(r, m):
        c = base(r, m)
        x = c["x"]
        m[0x98 + x] = r.choice(DIRS8)
        m[0x45E + x] = r.choice([0, 1])                       # SpeedFlag
        m[0x46B + x] = r.choice([0, 0, 1])                    # IsChild
        child = m[0x46B + x]
        m[0x42C + x] = r.choice([0, child])                   # SpeedWhole
        m[0x444 + x] = r.choice([0, child])                   # TargetSpeedWhole
        m[0x437 + x] = r.choice([0x40, 0x80, m[0x41F + x]])   # TargetSpeedFrac
        m[0x51B] = r.choice([0, 0, 1])                        # UsedFlute
        m[0x507] = r.choice([0, 1, 2, 3])                     # ChildDigdoggerCount
        m[0x478 + x] = r.randrange(4)                         # CurPart
        return c
    return gen


# entry, C function, types, ObjState values (the routine's real range)
STATEFUL = [
    ("UpdateTektiteOrBoulder", "enrt_update_tektite_or_boulder", [0x0D, 0x0E, 0x20], range(4)),
    ("UpdateBlueLeever", "enrt_update_blue_leever", [0x0F], range(6)),
    ("UpdateRedLeever", "enrt_update_red_leever", [0x10], range(6)),
    ("UpdateZora", "enrt_update_zora", [0x11], range(6)),
    ("UpdatePolsVoice", "enrt_update_pols_voice", [0x16], range(4)),
    ("UpdateLikeLike", "enrt_update_like_like", [0x17], range(4)),
    ("UpdateArmos", "enrt_update_armos", [0x1E], range(4)),
    ("UpdateBoulderSet", "enrt_update_boulder_set", [0x1F], range(4)),
    ("UpdateBlueWizzrobe", "enrt_update_blue_wizzrobe", [0x23], range(4)),
    ("UpdateRedWizzrobe", "enrt_update_red_wizzrobe", [0x24], range(4)),
    ("UpdateWallmaster", "enrt_update_wallmaster", [0x27], range(4)),
    ("UpdateBubble", "enrt_update_bubble", [0x2B, 0x2C, 0x2D], range(4)),
    ("UpdateGibdo", "enrt_update_gibdo", [0x30], range(4)),
    ("UpdateGuardFire", "enrt_update_guard_fire", [0x3F], range(4)),
    ("UpdateStandingFire", "enrt_update_standing_fire", [0x40], range(4)),
    ("UpdateMonsterShot", "enrt_update_monster_shot", [0x53, 0x54, 0x57, 0x58, 0x59, 0x5A],
     [0x10, 0x10, 0x11, 0x20, 0x21, 0]),
    ("UpdateFireball", "enrt_update_fireball", [0x55, 0x56], [0x10, 0x10, 0x11, 0]),
    ("UpdateMonsterArrow", "enrt_update_monster_arrow", [0x5B], [0x10, 0x10, 0x11, 0x20, 0]),
    ("UpdateArrowOrBoomerang", "enrt_update_arrow_or_boomerang", [0x5C],
     [0x10, 0x10, 0x11, 0x20, 0x30, 0]),
    ("UpdateDeadDummy", "z07_update_dead_dummy", [0x5D], range(4)),
    # bosses and specials
    ("UpdateVire", "enrt_update_vire", [0x12], [0, 0, 1]),
    ("UpdateDigdogger", "enrt_update_digdogger", [0x18, 0x38], range(4)),
    ("UpdatePatraChild", "enrt_update_patra_child", [0x25, 0x26], range(4)),
    ("UpdatePondFairy", "enrt_update_pond_fairy", [0x2F], range(4)),
    ("UpdateDodongo", "boss_dodongo_update", [0x31, 0x32], range(3)),
    ("UpdateGohma", "enrt_update_gohma", [0x33, 0x34], range(4)),
    ("UpdateZelda", "enrt_update_zelda", [0x37], range(4)),
    ("UpdateLamnola", "enrt_update_lamnola", [0x3A, 0x3B], range(4)),
    ("UpdateManhandla", "enrt_update_manhandla", [0x3C], range(4)),
    ("UpdateAquamentus", "enrt_update_aquamentus", [0x3D], range(4)),
    ("UpdateGanon", "enrt_update_ganon", [0x3E], range(4)),
    ("UpdateMoldorm", "enrt_update_moldorm", [0x41], range(4)),
    ("UpdateGleeok", "enrt_update_gleeok", [0x42, 0x43, 0x44, 0x45], range(4)),
    ("UpdateGleeokHead", "boss_gleeok_update_head", [0x46], range(4)),
    ("UpdatePatra", "boss_patra_update", [0x47, 0x48], range(4)),
]
SHOTS = {"UpdateMonsterShot", "UpdateFireball", "UpdateMonsterArrow", "UpdateArrowOrBoomerang"}
GENS = {e: gen_shot for e in SHOTS}
GENS["UpdateDigdogger"] = gen_digdogger


def gen_patra_child(types, states):
    """Children live in slots 2..9 (Patra in slot 1, maneuver index 0..1)."""
    base = gen_typed(types, states, range(2, 10))

    def gen(r, m):
        c = base(r, m)
        m[0x45E + 1] = r.choice([0, 1])                       # Patra_ObjManeuverIndex+1
        return c
    return gen


GENS["UpdatePatraChild"] = gen_patra_child


def gen_patra(types, states):
    """Patra in slot 1: flying state 0..3, 8-way direction, maneuver index
    0..1; children ($25/$26) in slots 2..9, all, some or none."""
    base = gen_typed(types, states, [1])

    def gen(r, m):
        c = base(r, m)
        m[0x444 + 1] = r.randrange(4)                         # Flyer_ObjFlyingState
        m[0x98 + 1] = r.choice(DIRS8)
        m[0x45E + 1] = r.choice([0, 1])                       # Patra_ObjManeuverIndex
        m[0x42C + 1] = pick(r, [0, 1, 2, 8])                  # Flyer_ObjTurns
        child = 0x25 if m[0x34F + 1] == 0x47 else 0x26
        mode = r.choice(["all", "some", "none"])
        for s_ in range(2, 10):
            if mode == "all" or (mode == "some" and r.random() < 0.5):
                m[0x34F + s_] = child
            elif m[0x34F + s_] in (0x25, 0x26):
                m[0x34F + s_] = 0
        m[0x70 + 1], m[0x84 + 1] = r.randrange(0x20, 0xE0), r.randrange(0x50, 0xD0)
        return c
    return gen


GENS["UpdatePatra"] = gen_patra


def gen_dodongo(types, states):
    """State 0..2; bloated substate 0..4, bomb hits 0..2, single-bit dir."""
    base = gen_typed(types, states)

    def gen(r, m):
        c = base(r, m)
        x = c["x"]
        m[0x42C + x] = r.randrange(5)                         # Dodongo_ObjBloatedSubstate
        m[0x437 + x] = r.choice([0, 1, 2])                    # Dodongo_ObjBombHits
        m[0x45E + x] = pick(r, [0, 1, 0x20, 0x40])            # Dodongo_ObjBloatedTimer
        m[0x98 + x] = r.choice([1, 2, 4, 8])
        return c
    return gen


GENS["UpdateDodongo"] = gen_dodongo
SPECS += [monster_spec(e, f, GENS.get(e, gen_typed)(t, list(st)))
          for e, f, t, st in STATEFUL]
