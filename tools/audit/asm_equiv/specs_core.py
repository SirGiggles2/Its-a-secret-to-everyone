"""asm_equiv specs: core movement / collision / bounds drains (T-171 sweep).

Each spec runs the NES routine and the drained C on the same random NES
memory. Inputs are biased toward the branch conditions of the routine;
everything else stays random.
"""
from __future__ import annotations

import ctypes

U = ctypes.c_uint
DIRS = [0, 1, 2, 4, 8]

COLLIDE_ASM = [
    ("Z_07.asm", "PlayAreaColumnAddrs:", "RunGame:"),
    ("Z_07.asm", "WalkableTiles:", "GetCollidableTileStill:"),
    ("Z_07.asm", "GetCollidableTileStill:", "Obj_Shove:"),
]
COLLIDE_C = ["src/game/combat/collision_dispatch.c"]


def pick(r, common, p=0.85):
    return r.choice(common) if r.random() < p else r.randrange(256)


def gen_tile(r, m, moving=False):
    x = r.choice([0, 0, 1, 2, 5, 11, 0x0D, 0x10, 0x12])
    m[0x0F] = pick(r, DIRS)
    m[0x10] = 0 if r.random() < 0.5 else r.randrange(1, 10)
    if r.random() < 0.2:
        m[0xEB] = 0x1F
        m[0x70] = 0x80
        m[0x84] = r.randrange(0x30, 0x60)
    m[0x70 + x] = pick(r, [0x00, 0x08, 0x0F, 0x10, 0x11, 0xEF, 0xF0, 0xF8, 0x78])
    m[0x84 + x] = pick(r, [0x3D, 0x45, 0xD1, 0xD2, 0xD3, 0xDD, 0x8D, 0x35])
    # Walkable-list tiles and their neighbours in the play-area columns.
    for a in range(0x6530, 0x67F0):
        if r.random() < 0.15:
            m[a] = r.choice([0x8D, 0x91, 0x9C, 0xAC, 0xAD, 0xCC, 0xD2, 0xD5, 0xDF, 0x26])
    case = {"mem": m, "x": x}
    if not moving:
        case["y"] = pick(r, [0x00, 0xF8, 0xF0, 0x08, 0x10])
    return case


def gen_bound(r, m):
    x = r.choice([0, 1, 5, 11, 0x0D, 0x0E, 0x10, 0x12])
    m[0x0F] = pick(r, [0, 1, 2, 4, 8, 3, 0x0C, 0x0F])
    if r.random() < 0.3:
        m[0x34F + x] = 0x5C
    for a in (0x346, 0x347, 0x348, 0x349):
        m[a] = r.randrange(256)
    m[0x70 + x] = (m[r.choice([0x346, 0x347])] + r.randrange(-0x20, 0x20)) & 0xFF
    m[0x84 + x] = (m[r.choice([0x348, 0x349])] + r.randrange(-0x24, 0x24)) & 0xFF
    return {"mem": m, "x": x}


def gen_qspeed(r, m):
    x = r.choice([0, 1, 5, 11, 0x0D, 0x12])
    m[0x10E] = r.choice([0x08, 0x10])
    m[0x10F] = r.choice([0xF8, 0xF0])
    m[0x394 + x] = pick(r, [m[0x10E], m[0x10F], 0, 1, 0xFF, 7, 0xF9])
    m[0x3A8 + x] = r.randrange(256)
    m[0x3BC + x] = pick(r, [0x20, 0x60, 0x80, 0xC0, 0x30, 0xFF, 0x00])
    return {"mem": m, "x": x}


def gen_move(r, m):
    c = gen_qspeed(r, m)
    m[0x0F] = pick(r, [0, 1, 2, 4, 8, 3, 0x0C, 0x05, 0x0A])
    return c


def gen_move_shot(r, m):
    c = gen_bound(r, m)
    x = c["x"]
    m[0x394 + x] = pick(r, [0, 1, 7, 8, 0x10, 0xF0, 0xF8, 0xFF])
    m[0x3A8 + x] = r.randrange(256)
    m[0x3BC + x] = pick(r, [0x20, 0x60, 0x80, 0xC0, 0xFF])
    m[0x0E] = pick(r, [0, 0, 0x80, 1])
    c["a"] = pick(r, [1, 2, 4, 8, 3, 0])
    return c


def gen_anim_walk(r, m):
    x = r.choice([0, 0, 1, 5, 11])
    m[0x3D0 + x] = pick(r, [1, 1, 2, 6, 0])
    m[0x3E4 + x] = r.randrange(2) if r.random() < 0.8 else r.randrange(256)
    m[0x98 + x] = pick(r, [1, 2, 4, 8, 0, 0x0C])
    m[0xAC] = pick(r, [0, 0x10, 0x11, 0x20, 0x21, 0x30, 0x31, 0x40, 0x50])
    return {"mem": m, "x": x}


def gen_cycle(r, m):
    m[0x341] = pick(r, [0, 1, 0x26, 0x27, 0x28, 0x10])
    return {"mem": m}


def carry_bit(v):
    return 1 if v & 0x100 else 0


SPECS = [
    dict(name="GetCollidableTile", doc="Z_07 GetCollidableTile vs collision_get_collidable_tile",
         asm=COLLIDE_ASM, c_sources=COLLIDE_C, entry="GetCollidableTile",
         gen=lambda r, m: gen_tile(r, m),
         call=lambda lib, c: lib.collision_get_collidable_tile(U(c["y"]), U(c["x"])),
         ret="A"),
    dict(name="GetCollidableTileStill", doc="Z_07 GetCollidableTileStill",
         asm=COLLIDE_ASM, c_sources=COLLIDE_C, entry="GetCollidableTileStill",
         gen=lambda r, m: gen_tile(r, m, moving=True),
         call=lambda lib, c: lib.collision_get_collidable_tile_still(U(c["x"])),
         ret="A"),
    dict(name="GetCollidingTileMoving", doc="Z_07 GetCollidingTileMoving incl. [00:01]",
         asm=COLLIDE_ASM, c_sources=COLLIDE_C, entry="GetCollidingTileMoving",
         gen=lambda r, m: gen_tile(r, m, moving=True),
         call=lambda lib, c: lib.collision_get_colliding_tile_moving(U(c["x"])),
         ret="A"),
    dict(name="BoundByRoom", doc="Z_01 BoundByRoom vs object_bound_by_room",
         asm=[("Z_01.asm", "BoundDirectionHorizontally:", "AddQSpeedToPositionFraction:"),
              ("Z_07.asm", "ResetMovingDir:", "GoWalkableDir:")],
         c_sources=["src/game/world/object_dispatch.c"], entry="BoundByRoom",
         gen=gen_bound, call=lambda lib, c: lib.object_bound_by_room(U(c["x"])), ret="A"),
    dict(name="AddQSpeed", doc="Z_01 AddQSpeedToPositionFraction",
         asm=[("Z_01.asm", "AddQSpeedToPositionFraction:", "SubQSpeedFromPositionFraction:")],
         c_sources=["src/game/world/object_dispatch.c"], entry="AddQSpeedToPositionFraction",
         gen=gen_qspeed,
         call=lambda lib, c: lib.object_add_q_speed_to_position_fraction(U(c["x"])),
         ret="C", carry_of=carry_bit),
    dict(name="SubQSpeed", doc="Z_01 SubQSpeedFromPositionFraction",
         asm=[("Z_01.asm", "SubQSpeedFromPositionFraction:", "OppositeDirs:")],
         c_sources=["src/game/world/object_dispatch.c"], entry="SubQSpeedFromPositionFraction",
         gen=gen_qspeed,
         call=lambda lib, c: lib.object_sub_q_speed_from_position_fraction(U(c["x"])),
         ret="C", carry_of=carry_bit),
    dict(name="MoveObject", doc="Z_07 MoveObject vs object_move_object",
         asm=[("Z_07.asm", "MoveObject:", "PlayerScreenEdgeBounds:"),
              ("Z_01.asm", "AddQSpeedToPositionFraction:", "OppositeDirs:")],
         c_sources=["src/game/world/object_dispatch.c"], entry="MoveObject",
         gen=gen_move, call=lambda lib, c: lib.object_move_object(ctypes.c_ushort(c["x"]))),
    dict(name="MoveShot", doc="Z_01 MoveShot vs object_move_shot",
         asm=[("Z_01.asm", "MoveShot:", "GetDirectionsAndDistancesToTarget:"),
              ("Z_01.asm", "BoundDirectionHorizontally:", "OppositeDirs:"),
              ("Z_07.asm", "MoveObject:", "PlayerScreenEdgeBounds:"),
              ("Z_07.asm", "ResetMovingDir:", "GoWalkableDir:")],
         c_sources=["src/game/world/object_dispatch.c"], entry="MoveShot",
         gen=gen_move_shot,
         call=lambda lib, c: lib.object_move_shot(ctypes.c_ubyte(c["a"]), U(c["x"]))),
    dict(name="AnimateObjectWalking", doc="Z_07 AnimateObjectWalking vs sprite_animate_object_walking",
         asm=[("Z_07.asm", "AnimateObjectWalking:", "AnimateLinkObjState:"),
              ("Z_07.asm", "AnimateLinkObjState:", "; Unknown block"),
              ],
         c_sources=["src/game/world/sprite_dispatch.c"], entry="AnimateObjectWalking",
         gen=gen_anim_walk,
         call=lambda lib, c: lib.sprite_animate_object_walking(U(c["x"]))),
    dict(name="CycleCurSpriteIndex", doc="Z_01 CycleCurSpriteIndex",
         asm=[("Z_01.asm", "CycleCurSpriteIndex:", "CheckPersonBlocking:")],
         c_sources=["src/game/world/sprite_dispatch.c"], entry="CycleCurSpriteIndex",
         gen=gen_cycle, call=lambda lib, c: lib.sprite_cycle_cur_sprite_index()),
]


# ------------------------------------------------------------ batch 2

WALKER_ASM = [
    ("Z_07.asm", "TableJump:", "HideAllSprites:"),
    ("Z_07.asm", "EnsureObjectAligned:", "WalkableTiles:"),
    ("Z_07.asm", "Obj_Shove:", "FluteRoomSecretsOW:"),
    ("Z_07.asm", "L1EFCF_Exit:", "Walker_Move:"),
    ("Z_07.asm", "Walker_Move:", "Walker_GetNextAltDir:"),
    ("Z_07.asm", "Walker_GetNextAltDir:", "LinkToLadderOffsetsX:", "", ""),
    ("Z_01.asm", "ReverseDirections:", "SaveFileAAddressSets:"),
    ("Z_01.asm", "BoundDirectionHorizontally:", "MoveShot:"),
    ("Z_01.asm", "CycleCurSpriteIndex:", "FormatDecimalByte:"),   # CheckPersonBlocking
] + COLLIDE_ASM
OBJ_ATTRS = [0x00, 0x05, 0x81, 0x01, 0x43, 0xC3, 0x89, 0x83, 0xC9, 0xA9, 0x41,
             0xC1, 0xA1, 0xE3, 0xE1]
WALKER_C = ["src/game/enemies/enemy_walker_bridge.c", "src/game/world/object_dispatch.c",
            "src/game/combat/collision_dispatch.c", "src/game/core/core_dispatch.c"]


def gen_walker(r, m, slots=range(1, 12)):
    x = r.choice(slots)
    m[0x12] = r.choice([5, 5, 5, 9, 0x0B])
    m[0x10] = 0 if r.random() < 0.5 else r.randrange(1, 10)
    m[0x66C] = 0 if r.random() < 0.9 else r.randrange(1, 256)          # InvClock
    m[0x3D + x] = 0 if r.random() < 0.85 else r.randrange(1, 256)       # ObjStunTimer
    shove = r.random() < 0.3
    m[0xC0 + x] = (r.choice([1, 2, 4, 8]) | r.choice([0, 0x80])) if shove else 0
    m[0xD3 + x] = pick(r, [0, 1, 4, 8, 0x10, 0x20])
    # ObjInputDir: 0 or valid directions. A nonzero value without direction
    # bits makes GetOppositeDir read OppositeDirs/ReverseDirections+$FF,
    # whose ROM byte this harness layout cannot reproduce (never set so).
    m[0x3F8 + x] = r.choice([0, 1, 2, 4, 8, 3, 0x0C, 0x09])
    m[0x98 + x] = r.choice([1, 2, 4, 8])                                 # ObjDir: one bit
    # ObjGridOffset: -$F..$F (MoveObject/Obj_Shove reset it at multiples of $10).
    m[0x394 + x] = r.choice([0, 0, 0, 1, 7, 8, 0x0F, 0xF8, 0xF1, 0xF9, r.randrange(-15, 16) & 0xFF])
    m[0x3BC + x] = pick(r, [0x20, 0x40, 0x60, 0x80])
    # ObjAttr: values of ObjectTypeToAttributes / InitTileObjOrItem only
    # ($10 "reverse when blocked" never occurs in the ROM tables).
    m[0x4BF + x] = r.choice(OBJ_ATTRS)
    if r.random() < 0.15:
        m[0x350] = r.choice([0x36, 0x4B, 0x4E, 0x52])                    # person in slot 1
    m[0x34A] = pick(r, [0x78, 0x84, 0x26, 0x8D, 0xF4, 0x89, 0x00])
    for a in (0x346, 0x347, 0x348, 0x349):
        m[a] = [0x10, 0xE0, 0x40, 0xD0][a - 0x346] if r.random() < 0.7 else r.randrange(256)
    m[0x70 + x] = pick(r, [0x10, 0x20, 0x30, 0x80, 0xD0, 0xE0, 0xE8])
    m[0x84 + x] = pick(r, [0x45, 0x4D, 0x5D, 0x8D, 0xBD, 0xCD, 0xD5])
    for a in range(0x6530, 0x67F0):
        m[a] = r.choice([0x26, 0x26, 0x26, 0x74, 0xF4, 0x8D, 0x89, 0xB0, r.randrange(256)])
    m[0x34F + x] = pick(r, [0x01, 0x07, 0x0D, 0x2A, 0x5C, 0x12])
    return {"mem": m, "x": x}


def gen_collide(r, m):
    for a in (0x02, 0x03, 0x04, 0x05):
        m[a] = r.randrange(256)
    m[0x04] = (m[0x02] + r.randrange(-24, 24)) & 0xFF
    m[0x05] = (m[0x03] + r.randrange(-24, 24)) & 0xFF
    m[0x0D] = pick(r, [8, 9, 0x0C, 0x10, 0x80])
    m[0x0E] = pick(r, [8, 9, 0x0C, 0x10, 0x80])
    return {"mem": m}


def gen_empty_slot(r, m):
    for s in range(1, 12):
        m[0x34F + s] = 0 if r.random() < 0.15 else r.randrange(1, 256)
    return {"mem": m}


def gen_slot(r, m, lo=0, hi=0x13):
    x = r.randrange(lo, hi)
    # Direction 0: GetOppositeDir reads OppositeDirs+$FF; core_get_opposite_dir
    # models the real ROM byte ($A9, T-171), this harness layout cannot.
    m[0x98 + x] = r.choice([1, 2, 4, 8, 3, 0x0C, 0x0F])
    return {"mem": m, "x": x}


def gen_hearts(r, m):
    m[0x66F] = r.randrange(256)                      # HeartValues
    return {"mem": m}


def gen_decimal(r, m):
    return {"mem": m, "a": r.randrange(256)}


def gen_mazes(r, m):
    m[0x10] = 0 if r.random() < 0.9 else 1
    m[0xEB] = r.choice([0x1B, 0x61, r.randrange(128)])
    m[0xEC] = r.choice([0x1B, 0x61, 0x1A, 0x60, 0x0B, 0x51, r.randrange(128)])
    m[0x98] = r.choice([1, 2, 4, 8])
    m[0x52F] = r.randrange(4)                        # MazeStep 0..3 (game range)
    return {"mem": m}


def gen_rupees(r, m):
    m[0x66D] = pick(r, [0, 1, 0xFE, 0xFF, 0x80])     # InvRupees
    m[0x67D] = pick(r, [0, 1, 2, 0x80])              # RupeesToAdd
    m[0x67E] = pick(r, [0, 1, 2, 0x80])              # RupeesToSubtract
    m[0x14] = pick(r, [0, 0, 2])
    m[0x15] = r.randrange(256)
    return {"mem": m}


def gen_room_flags(r, m):
    m[0x10] = r.randrange(10)
    m[0xEB] = r.randrange(128)
    # LevelInfo_WorldFlagsAddr: OW $067F, L1-6 $06FF, L7-9 $077F.
    m[0x6BAF], m[0x6BB0] = r.choice([(0x7F, 0x06), (0xFF, 0x06), (0x7F, 0x07)])
    return {"mem": m}


SPECS += [
    dict(name="Walker_Move", doc="Z_07 Walker_Move (monster slots) vs c_walker_move: shove, "
         "stun, input pick, BoundByRoom, Walker_CheckTileCollision, MoveObject",
         asm=WALKER_ASM, c_sources=WALKER_C, entry="Walker_Move", gen=gen_walker,
         call=lambda lib, c: lib.c_walker_move(U(c["x"])),
         # [00]-[03]: TableJump's pointer scratch (ROM addresses on the
         # NES side), only in cases that ran TableJump.
         ignore_if_run={"TableJump": {0x00, 0x01, 0x02, 0x03}}),
    dict(name="DoObjectsCollideWithThresholds", doc="Z_01 DoObjectsCollideWithThresholds",
         asm=[("Z_01.asm", "DoObjectsCollideWithThresholds:", "BeginShove:"),
              ("Z_01.asm", "Abs:", "MoveShot:")],
         c_sources=COLLIDE_C, entry="DoObjectsCollideWithThresholds", gen=gen_collide,
         call=lambda lib, c: lib.collision_do_objects_collide_with_thresholds(), ret="A"),
    dict(name="FindEmptyMonsterSlot", doc="Z_07 FindEmptyMonsterSlot vs c_find_empty_monster_slot",
         asm=[("Z_07.asm", "FindEmptyMonsterSlot:", "InitTileObjOrItem:")],
         c_sources=["src/game/enemies/enemy_boss_bridge.c"], entry="FindEmptyMonsterSlot",
         gen=gen_empty_slot, call=lambda lib, c: lib.c_find_empty_monster_slot()),
    dict(name="ReverseObjDir", doc="Z_07 ReverseObjDir vs core_reverse_obj_dir",
         asm=[("Z_07.asm", "ReverseObjDir:", "Walker_AltDir_EndLoop:"),
              ("Z_01.asm", "OppositeDirs:", "Abs:")],
         c_sources=["src/game/core/core_dispatch.c"], entry="ReverseObjDir",
         gen=lambda r, m: gen_slot(r, m), call=lambda lib, c: lib.core_reverse_obj_dir(U(c["x"]))),
    dict(name="GetObjectMiddle", doc="Z_01 GetObjectMiddle vs world_get_object_middle",
         asm=[("Z_01.asm", "GetObjectMiddle:", "CheckLinkCollision:")],  # RTS = table byte $60
         c_sources=["src/game/world/world_dispatch.c"], entry="GetObjectMiddle",
         gen=lambda r, m: gen_slot(r, m), call=lambda lib, c: lib.world_get_object_middle(U(c["x"]))),
    dict(name="CompareHeartsToContainers", doc="Z_01 CompareHeartsToContainers",
         asm=[("Z_01.asm", "CompareHeartsToContainers:", "L_TakePowerTriforce:")],
         c_sources=["src/game/core/core_dispatch.c"], entry="CompareHeartsToContainers",
         gen=gen_hearts, call=lambda lib, c: lib.core_compare_hearts_to_containers(), ret="A"),
    dict(name="FormatDecimalByte", doc="Z_01 FormatDecimalByte vs cave_format_decimal_byte",
         asm=[("Z_01.asm", "FormatDecimalByte:", "FormatHeartsInTextBuf:")],
         c_sources=["src/game/cave/cave_dispatch.c"], entry="FormatDecimalByte",
         gen=gen_decimal, call=lambda lib, c: lib.cave_format_decimal_byte(ctypes.c_ubyte(c["a"]))),
    dict(name="CheckMazes", doc="Z_01 CheckMazes vs world_check_mazes",
         asm=[("Z_01.asm", "ForestMazeDirs:", "MapScreenPosToPpuAddr:")],
         c_sources=["src/game/world/world_dispatch.c"], entry="CheckMazes",
         gen=gen_mazes, call=lambda lib, c: lib.world_check_mazes()),
    dict(name="World_ChangeRupees", doc="Z_01 World_ChangeRupees vs hud_world_change_rupees",
         asm=[("Z_01.asm", "BeginUpdateMode:", "ReverseDirections:"),  # falls into FormatStatusBarText
              ("Z_01.asm", "FormatDecimalByte:", "SilenceAllSound:")],
         c_sources=["src/game/hud/hud_dispatch.c", "src/game/cave/cave_dispatch.c",
                    "src/game/core/core_dispatch.c"], entry="World_ChangeRupees",
         gen=gen_rupees, call=lambda lib, c: lib.hud_world_change_rupees()),
    dict(name="GetRoomFlags", doc="Z_07 GetRoomFlags vs room_get_room_flags",
         asm=[("Z_07.asm", "GetRoomFlags:", "AnimateRoomItemOnMonster:")],
         c_sources=["src/game/room/room_dispatch.c"], entry="GetRoomFlags",
         gen=gen_room_flags, call=lambda lib, c: lib.room_get_room_flags(), ret="A"),
]


# ------------------------------------------------------------ batch 3: combat

MONSTER_TYPES = [0x01, 0x03, 0x05, 0x07, 0x08, 0x0B, 0x0D, 0x0F, 0x12, 0x14, 0x17, 0x1B,
                 0x1E, 0x23, 0x27, 0x2A, 0x2B, 0x2E, 0x31, 0x33, 0x3D, 0x41, 0x48, 0x53, 0x55]
COMBAT_ASM = [
    ("Z_01.asm", "CheckMonsterCollisions:", "Filler_7751:"),
    ("Z_01.asm", "OppositeDirs:", "MoveShot:"),
    ("Z_01.asm", "PlaySample:", "InitModeB_EnterCave_Bank5:"),
    ("Z_07.asm", "DecrementInvincibilityTimer:", "FindEmptyMonsterSlot:"),
    ("Z_07.asm", "ResetShoveInfo:", "ShoveMoveMin:"),
    ("Z_07.asm", "HandleShotBlocked:", "SpreadShot:"),
    ("Z_07.asm", "EndGameMode:", "UpdateMode3Unfurl:"),
    ("Z_04.asm", "Gohma_HandleWeaponCollision:", "UpdateGleeokHead:"),
    ("Z_04.asm", "PlayBossHitCryIfNeeded:", "InitMonsterShot:"),
    ("Z_04.asm", "PlayBossDeathCry:", "NoDropMonsterTypes:"),
    ("Z_01.asm", "PlaceWeaponForPlayerStateAndAnimAndWeaponState:", "WieldCandle:"),
    ("Z_01.asm", "WieldCandle:", "GetShortcutOrItemXY:"),
    ("Z_01.asm", "DestroyObject_WRAM:", "UpdateBombFlashEffect:"),
    ("Z_07.asm", "ResetObjState:", "MakeSwordShot:"),
]
COMBAT_C = ["src/game/combat/link_collision_dispatch.c", "src/game/combat/collision_dispatch.c",
            "src/game/world/world_dispatch.c", "src/game/core/core_dispatch.c",
            "src/game/combat/combat_dispatch.c", "src/game/enemies/enemy_dispatch.c",
            "src/game/items/candle_fire.c", "src/game/items/bomb.c"]


def near(r, v, d=20):
    return (v + r.randrange(-d, d + 1)) & 0xFF


def gen_monster_collisions(r, m):
    x = r.randrange(1, 12)
    t = r.choice(MONSTER_TYPES)
    m[0x34F + x] = t
    m[0x405 + x] = 0 if r.random() < 0.85 else r.choice([1, 0x10, 0x11])   # ObjMetastate
    m[0x4BF + x] = r.choice(OBJ_ATTRS)
    m[0x4F0 + x] = 0 if r.random() < 0.8 else r.randrange(1, 0x20)        # invincibility
    mx, my = r.randrange(0x10, 0xE0), r.randrange(0x40, 0xD0)
    m[0x70 + x], m[0x84 + x] = mx, my
    m[0x485 + x] = pick(r, [0x10, 0x20, 0x40, 0x80, 0xF0, 0x00])          # ObjHP
    m[0x98 + x] = r.choice([1, 2, 4, 8])
    for s in (13, 14, 15, 16, 17, 18):
        active = r.random() < 0.35
        m[0xAC + s] = r.choice({13: [1, 2, 3], 14: [0x10, 0x11, 0x80], 15: [1, 2, 3, 0x80],
                                16: [0x12, 0x13, 0x22], 17: [0x12, 0x13, 0x22],
                                18: [0x10, 0x30, 0x31]}[s]) if active else 0
        m[0x70 + s], m[0x84 + s] = near(r, mx), near(r, my)
        m[0x98 + s] = r.choice([1, 2, 4, 8])
    m[0x70], m[0x84] = near(r, mx, 24), near(r, my, 24)                    # Link
    m[0x98] = r.choice([1, 2, 4, 8])
    m[0xAC] = pick(r, [0, 0, 0x10, 0x20, 0x40])
    m[0x4F0] = 0 if r.random() < 0.8 else r.randrange(1, 0x30)
    m[0xC0], m[0xD3] = 0, 0
    m[0x657] = r.choice([1, 2, 3])                                          # sword
    m[0x662] = r.choice([0, 1, 2])                                          # ring
    m[0x66F] = r.choice([0x22, 0x55, 0xFF, 0x20])                           # HeartValues
    m[0x670] = pick(r, [0x00, 0x80, 0xFF])
    m[0x12] = 5
    return {"mem": m, "x": x}


SPECS += [
    dict(name="CheckMonsterCollisions", doc="Z_01 CheckMonsterCollisions..BeginShove (weapons, "
         "Link harm, shove, damage) vs link_collision_check_monster_collisions",
         asm=COMBAT_ASM, c_sources=COMBAT_C, entry="CheckMonsterCollisions", incs=["ObjVars.inc"],
         gen=gen_monster_collisions,
         call=lambda lib, c: lib.link_collision_check_monster_collisions(U(c["x"]))),
]


# ------------------------------------------------------------ batch 4: items

def gen_take_item(r, m):
    # Excluded: rings $12/$13 (the NES patches MenuPalettesTransferBuf in
    # WRAM; the Genesis keeps that buffer outside NES RAM, its own palette
    # path, T-175) and the Triforce of Power $0E (TakePowerTriforce
    # fanfare, separate spec).
    item = r.choice([i for i in range(0x24) if i not in (0x0E, 0x12, 0x13)])
    m[0x12] = r.choice([5, 5, 5, 0x0B, 9])
    for a in range(0x657, 0x680):           # inventory: small realistic values
        m[a] = r.choice([0, 0, 1, 2, 3, r.randrange(256)])
    m[0x66F] = r.choice([0x22, 0x55, 0xFF, 0x20, 0xEE])
    m[0x670] = pick(r, [0x00, 0x80, 0xFF])
    m[0x66E] = pick(r, [0, 1, 9, 0xFF])     # keys
    m[0x658] = pick(r, [0, 1, 8, 0x10])     # bombs
    m[0x67C] = pick(r, [8, 0x0C, 0x10])     # max bombs
    return {"mem": m, "a": item}


SPECS += [
    dict(name="TakeItem", doc="Z_01 TakeItem (classes, complex items, hearts) vs item_take_item",
         asm=[("Z_01.asm", "ItemIdToSlot:", "SetRoomFlagUWItemState:"),
              ("Z_07.asm", "LevelMasks:", "AnimateRoomItemOnMonster:"),
              ("Z_07.asm", "EndGameMode:", "UpdateMode3Unfurl:"),
              ("Z_01.asm", "TakeItem:", "AnimateWorldFading:")],
         c_sources=["src/game/items/item_dispatch.c", "src/game/items/item_tables.c",
                    "src/game/core/core_dispatch.c", "src/game/enemies/bosses/boss_gleeok.c",
                    "src/state/inventory.c", "src/game/room/room_dispatch.c"],
         # Genesis HUD presentation hook (heart-container fill animation);
         # no NES RAM effect.
         c_stubs="void hud_heart_container_anim_start(void) { }\n",
         # Ring palette path only (ring ids $12/$13 are not generated).
         data_unreached={"LinkColors_CommonCode", "MenuPalettesTransferBuf",
                         "SaveSlotToPaletteRowOffset"},
         entry="TakeItem", gen=gen_take_item,
         call=lambda lib, c: lib.item_take_item(ctypes.c_ubyte(c["a"]))),
]


# ------------------------------------------------------------ batch 5: monsters

def gen_fill_hearts(r, m):
    m[0x63] = pick(r, [0, 1, 1, 1])                       # World_IsFillingHearts
    m[0x670] = pick(r, [0x00, 0x06, 0xF2, 0xF7, 0xF8, 0xFE, 0xFF])
    hv = r.randrange(16) << 4
    m[0x66F] = hv | r.choice([hv >> 4, max(0, (hv >> 4) - 1), r.randrange(16)])
    return {"mem": m}


def gen_distance(r, m):
    x = r.randrange(1, 12)
    m[0x70 + x] = near(r, m[0x70], 0x30)
    m[0x84 + x] = near(r, m[0x84], 0x30)
    return {"mem": m, "x": x}


def gen_keese(r, m):
    x = r.randrange(1, 12)
    m[0x34F + x] = r.choice([0x1B, 0x1C, 0x1D])
    m[0x444 + x] = r.randrange(6)                         # Flyer_ObjFlyingState 0..5
    m[0x42C + x] = pick(r, [0, 1, 2, 6])                  # Flyer_ObjTurns
    m[0x41F + x] = pick(r, [0x00, 0x20, 0x40, 0x80, 0xA0, 0xC0])   # Flyer_ObjSpeed
    m[0x98 + x] = r.choice([8, 9, 1, 5, 4, 6, 2, 0x0A])   # Directions8 values
    m[0x70 + x], m[0x84 + x] = r.randrange(0x10, 0xF0), r.randrange(0x40, 0xE0)
    for a in (0x346, 0x347, 0x348, 0x349):
        m[a] = [0x10, 0xE0, 0x40, 0xD0][a - 0x346]
    m[0x66C] = 0
    return {"mem": m, "x": x}


SPECS += [
    dict(name="IsDistanceSafeToSpawn", doc="Z_05 IsDistanceSafeToSpawn vs enemy_edge_distance_safe",
         asm=[("Z_05.asm", "IsDistanceSafeToSpawn:", "InitMode11:"),
              ("Z_01.asm", "Abs:", "MoveShot:")],
         c_sources=["src/game/enemies/obj_lists.c"], entry="IsDistanceSafeToSpawn",
         gen=gen_distance, call=lambda lib, c: lib.enemy_edge_distance_safe(U(c["x"])),
         ret="C", carry_of=lambda v: 0 if (v & 0xFF) else 1),
]

SPECS += [
    dict(name="World_FillHearts", doc="Z_05 World_FillHearts vs hud_world_fill_hearts",
         asm=[("Z_05.asm", "World_FillHearts:", "SubmenuTransferBufSelectorsUW:"),
              ("Z_01.asm", "CompareHeartsToContainers:", "L_TakePowerTriforce:")],
         c_sources=["src/game/hud/hud_dispatch.c"], entry="World_FillHearts",
         gen=gen_fill_hearts, call=lambda lib, c: lib.hud_world_fill_hearts()),
    dict(name="KeeseFlight", doc="Z_04 ControlKeeseFlight + MoveFlyer (flyer state machine) vs "
         "c_control_keese_flight + c_move_flyer",
         asm=[("Z_04.asm", "UpdateKeese:", "UpdateZol:"),
              ("Z_04.asm", "Directions8:", "PatraSines:"),
              ("Z_07.asm", "TableJump:", "HideAllSprites:"),
              ("Z_01.asm", "BoundDirectionHorizontally:", "MoveShot:"),
              ("Z_07.asm", "ResetMovingDir:", "GoWalkableDir:")],
         asm_stubs="EqKeese:\n    JSR ControlKeeseFlight\n    JMP MoveFlyer\n",
         incs=["ObjVars.inc"],
         c_sources=["src/game/enemies/enemy_flyer_bridge.c",
                    "src/oracle/enemies/enemy_flyer_runtime.c",
                    "src/game/core/core_dispatch.c", "src/game/world/object_dispatch.c",
                    "src/game/enemies/enemy_dispatch.c", "src/game/enemies/enemy_jumper_bridge.c"],
         entry="EqKeese", gen=gen_keese,
         call=lambda lib, c: (lib.c_control_keese_flight(U(c["x"])), lib.c_move_flyer(U(c["x"])))[1],
         ignore_if_run={"TableJump": {0x00, 0x01, 0x02, 0x03}}),
]
