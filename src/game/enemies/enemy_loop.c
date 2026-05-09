/* Phase 7 Task 7.2 step 3 — wire first init dispatch row (slow octorok / ghini).
 *
 * Drain Rule D1 stance: EXTEND. Function-pointer tables are the dispatch
 * shape (verbatim NES InitObject_JumpTable at Z_07.asm:5601). Tasks 7.3-7.7
 * fill rows one family at a time, paired with the shim plumbing each
 * family needs.
 *
 * Step 3 wires INIT only for ENEMY_TYPE 0x07 (RedSlowOctorock / Ghini).
 * Update-side dispatch is still NULL — enrt_update_rope and friends call
 * c_walker_move / z07_anim_advance_and_fetch / c_check_monster_collisions
 * which are not yet linked into Debug.md. Update wiring lands in Task 7.3
 * paired with native drain or shim plumbing for those primitives. Per
 * Drain Rule D1 we route z07_reset_obj_state to the already-linked
 * core_reset_obj_state body in src/game/core/core_dispatch.c (drain at
 * src/core/core_runtime.c:327). Forwarder is one line, not a stub.
 *
 * Hard rule WT-5 (RoomRom freeze, 2026-05-09): this file lives at
 * src/game/enemies/ instead of RoomRom/src/. ENEMY_* macros are still
 * supplied by RoomRom/src/roomrom_enemy_state.h until Task 7.7 lands a
 * promoted version under src/state/.
 */

#include "enemy_loop.h"
#include "roomrom_enemy_state.h"          /* still in RoomRom/src/ pre-WT-5 */
#include "platform_abi.h"
#include "probes/enemy_loop_probe.h"      /* step 4 live-tick publish */

/* Forward decls — defined in src/oracle/enemies/enemy_walker_runtime.c
 * (init), src/oracle/enemies/enemy_wanderer_runtime.c (goriya update),
 * src/game/enemies/enemy_walker_bridge.c (step-6 native octorock),
 * and src/game/core/core_dispatch.c (reset). All linked into Debug.md
 * per build_debug.py ROOMROM_C_SOURCES + step-6 unblock stubs. */
extern void enrt_init_slow_octorock_or_ghini(unsigned int slot);
extern void enrt_init_walker(unsigned int slot);                 /* step 7 */
extern void enrt_init_darknut(unsigned int slot);                /* step 7 */
extern void enrt_init_fast_octorock(unsigned int slot);          /* step 7 */
extern void enrt_update_octorock(unsigned int slot);  /* step 6 native */
extern void enrt_update_moblin(unsigned int slot);               /* step 7 */
extern void enrt_update_goriya(unsigned int slot);               /* step 7 */
extern void enrt_update_stalfos(unsigned int slot);              /* step 7 */
extern void enrt_update_darknut(unsigned int slot);              /* step 11 */
extern void enrt_update_monster_shot(unsigned int slot);         /* step 12 */
extern void enrt_update_fireball(unsigned int slot);             /* step 12 */
extern void update_meta_object(unsigned int slot);               /* step 20 */
extern void enrt_init_blue_keese(unsigned int slot);             /* step 3 */
extern void enrt_init_red_or_black_keese(unsigned int slot);     /* step 3 */
extern void enrt_update_keese(unsigned int slot);                /* step 3 */
extern void enrt_init_gel(unsigned int slot);                    /* step 4 */
extern void enrt_update_zol(unsigned int slot);                  /* step 4 */
extern void enrt_update_gel(unsigned int slot);                  /* step 4 */
extern void enrt_init_rope(unsigned int slot);                   /* step 5 */
extern void enrt_update_rope(unsigned int slot);                 /* step 5 */
extern void enrt_init_peahat(unsigned int slot);                 /* step 6 */
extern void enrt_update_peahat(unsigned int slot);               /* step 6 */
extern void enrt_update_vire(unsigned int slot);                 /* step 7 */
extern void enrt_init_boulder(unsigned int slot);                /* 7.4 step 2a */
extern void enrt_init_boulder_set(unsigned int slot);            /* 7.4 step 2a */
extern void enrt_update_boulder_set(unsigned int slot);          /* 7.4 step 2a */
extern void enrt_update_tektite_or_boulder(unsigned int slot);   /* 7.4 step 2a */
extern void enrt_update_zora(unsigned int slot);                 /* 7.4 step 2b */
extern void enrt_update_ghini(unsigned int slot);                /* 7.4 step 3 */
extern void enrt_update_flying_ghini(unsigned int slot);         /* 7.4 step 6a */
extern void enrt_update_armos(unsigned int slot);                /* 7.4 step 6b */
extern void enrt_update_gibdo(unsigned int slot);                /* 7.4 step 6d */
extern void enrt_update_bubble(unsigned int slot);               /* 7.4 step 6d */
extern void enrt_init_tektite(unsigned int slot);                /* 7.4 step 6e */
extern void enrt_init_bubble(unsigned int slot);                 /* 7.4 step 6e */
extern void enrt_init_armos_or_flying_ghini(unsigned int slot);  /* 7.4 step 6c */
/* 7.4 step 7 — whirlwind + trap UPDATE + INIT (trap_dispatch.c).
 * Native drains already linked into Debug.md; just need externs +
 * dispatch rows. NES SwitchBank #$01 collapses to no-op on Genesis. */
extern void trap_update_whirlwind_full(unsigned int slot);
extern void trap_update_trap_full(unsigned int slot);
extern void trap_init_trap_full(unsigned int slot);
/* 7.4 step 8 — fire-shooter UPDATE rows.
 *   $3F GuardFire    -> enrt_update_guard_fire (native NES Z_04.asm:9684
 *                       drain in enemy_walker_bridge.c).
 *   $40 StandingFire -> enrt_update_standing_fire (already drained at
 *                       enemy_walker_runtime.c:146). */
extern void enrt_update_guard_fire(unsigned int slot);
extern void enrt_update_standing_fire(unsigned int slot);
/* 7.4 step 10 — Aquamentus boss INIT + UPDATE.
 *   $3D Aquamentus -> enrt_init_aquamentus + enrt_update_aquamentus
 *                     (drained at enemy_boss_runtime.c:102/108).
 *   c_aquamentus_{move,shoot,draw} native bodies in enemy_boss_bridge.c.
 *   draw_write_boss_sprite primitive drained into draw_dispatch.c. */
extern void enrt_init_aquamentus(unsigned int slot);
extern void enrt_update_aquamentus(unsigned int slot);
extern void core_reset_obj_metastate_and_timer(unsigned int slot); /* 7.4 step 2b ($11 INIT) */
extern unsigned char core_reset_obj_state(unsigned int slot);
/* 7.5 step 2 — special-enemy UPDATE bridge bodies (enemy_special_bridge.c).
 *   $17 LikeLike   -> enrt_update_like_like   (NES Z_04.asm:6818).
 *   $16 PolsVoice  -> enrt_update_pols_voice  (NES Z_04.asm:6533, step 3).
 *   $27 Wallmaster -> enrt_update_wallmaster  (NES Z_04.asm:4121, step 4). */
extern void enrt_update_like_like(unsigned int slot);
extern void enrt_update_pols_voice(unsigned int slot);
extern void enrt_update_wallmaster(unsigned int slot);
/* 7.6 step 1 — leever INIT ($0F BlueLeever / $10 RedLeever).
 * NES Z_07.asm:5617 InitObject_JumpTable rows $0F/$10 -> InitLeever.
 * Body drained at src/oracle/enemies/enemy_walker_runtime.c:37
 * (RedLeeverLongTimer=5 + z07_reset_obj_metastate_and_timer). */
extern void enrt_init_leever(unsigned int slot);
/* 7.6 step 2 — BlueLeever UPDATE bridge ($0F). NES UpdateBlueLeever
 * @ Z_04.asm:2599 — sets ObjTurnRate ($041F = ENEMY_AIR_SPEED) to
 * $A0, calls Wanderer_TargetPlayer, falls through to UpdateBurrower
 * (c_update_burrower already drained in enemy_jumper_bridge.c). */
extern void enrt_update_blue_leever(unsigned int slot);

/* z07_reset_obj_state forwarder. enrt_octorock_common (same TU as the
 * init we wire below) calls this symbol. The drained body lives at
 * src/core/core_runtime.c:327 and was promoted into the native core
 * dispatch as core_reset_obj_state — call it directly. Avoids dragging
 * in src/gen/z_07.c (which would also pull room_runtime + core_runtime
 * + collision_runtime + their state header chains). Per --gc-sections
 * + -ffunction-sections, only this single forwarder is retained. */
unsigned char z07_reset_obj_state(unsigned int slot)
{
    return core_reset_obj_state(slot);
}

/* Function-pointer tables. Designated initializers leave unset rows at
 * NULL. Tasks 7.3-7.7 fan out by adding rows here without otherwise
 * modifying the file. */
const enemy_init_fn enemy_init_fns[ENEMY_LOOP_TYPE_MAX] = {
    /* NES InitObject_JumpTable @ Z_07.asm:5601.
     * $01-$06 = InitWalker (Lynel/Moblin/Goriya families).
     * $07/$09 = InitSlowOctorockOrGhini (sets WALK_SPEED=$20).
     * $08/$0A = InitFastOctorock (sets WALK_SPEED=$30).
     * $0B/$0C = InitDarknut (INVINCIBILITY $F6 + WALK_SPEED $20/$28).
     * $2A     = InitWalker (Stalfos).
     *
     * RedSlowOctorock body: enrt_octorock_common(slot, 32) →
     * enrt_init_walker(slot) — sets WALK_SPEED, MOVE_TIMER=(slot+1)<<4,
     * OBJ_STATE=0, DRAW_FRAME=0, ANIM_TIMER=6, then computes DIR from
     * LINK_X/LINK_Y vs OBJ_X/OBJ_Y (h_dir or v_dir, whichever has
     * larger diff). */
    [0x01] = enrt_init_walker,                 /* BlueLynel */
    [0x02] = enrt_init_walker,                 /* RedLynel */
    [0x03] = enrt_init_walker,                 /* BlueMoblin */
    [0x04] = enrt_init_walker,                 /* RedMoblin */
    [0x05] = enrt_init_walker,                 /* BlueGoriya */
    [0x06] = enrt_init_walker,                 /* RedGoriya */
    [0x07] = enrt_init_slow_octorock_or_ghini, /* RedSlowOctorock */
    [0x08] = enrt_init_fast_octorock,          /* RedFastOctorock */
    [0x09] = enrt_init_slow_octorock_or_ghini, /* BlueSlowOctorock */
    [0x0A] = enrt_init_fast_octorock,          /* BlueFastOctorock */
    [0x0B] = enrt_init_darknut,                /* BlueDarknut */
    [0x0C] = enrt_init_darknut,                /* RedDarknut */
    [0x2A] = enrt_init_walker,                 /* Stalfos */
    /* Task 7.3 step 3 — keese family INIT wired (NES Z_07.asm:5601). */
    [0x1B] = enrt_init_blue_keese,             /* BlueKeese */
    [0x1C] = enrt_init_red_or_black_keese,     /* RedKeese */
    [0x1D] = enrt_init_red_or_black_keese,     /* BlackKeese */
    /* Task 7.3 step 4 — zol/gel family INIT wired. NES InitObject_JumpTable
     * @ Z_07.asm:5601: $13/$14 = InitWalker (Zol/RedZol — bare walker init,
     * no special body); $15 = InitGel (sets STATE_TIMER=2 then InitWalker).
     * Bodies drained at enemy_walker_runtime.c:42 (InitWalker) and :92
     * (InitGel). */
    [0x13] = enrt_init_walker,                 /* Zol */
    [0x14] = enrt_init_walker,                 /* RedZol */
    [0x15] = enrt_init_gel,                    /* Gel */
    /* Task 7.3 step 5 — rope INIT (NES Z_07.asm:5601 InitObject_JumpTable
     * $28 = InitRope). Body drained at enemy_walker_runtime.c:71 — sets
     * CHARGE_SPEED=$10 (or $40 for second-quest) then InitWalker. */
    [0x28] = enrt_init_rope,                   /* Rope */
    /* Task 7.3 step 6 — peahat INIT (NES Z_07.asm:5601 $1A = InitPeahat).
     * Body drained at enemy_flyer_runtime.c:100 — z07_reset_obj_metastate
     * + DIR=$08 (down) + EndInitFlyer. */
    [0x1A] = enrt_init_peahat,                 /* Peahat */
    /* Task 7.3 step 7 — vire INIT (NES Z_07.asm:5601 InitObject_JumpTable
     * index $12 = InitWalker — vire shares the bare walker init body, no
     * vire-specific drain needed). enrt_init_walker drained at
     * enemy_walker_runtime.c:42. */
    [0x12] = enrt_init_walker,                 /* Vire */
    /* Task 7.4 step 2a — projectile-family carrier INIT rows (boulder
     * subset). NES Z_07.asm:5601 InitObject_JumpTable:
     *   $1F = InitBoulderSet (rock spawner) — drained at
     *         enemy_projectile_runtime.c:40.
     *   $20 = InitBoulder (rock projectile) — drained at
     *         enemy_projectile_runtime.c:35.
     * $11 Zora deferred to step 2b — needs UpdateBurrower drain chain. */
    [0x1F] = enrt_init_boulder_set,            /* BoulderSet (statue spawner) */
    [0x20] = enrt_init_boulder,                /* Boulder (rock projectile) */
    /* Task 7.4 step 2b — $11 Zora INIT. NES InitObject_JumpTable @
     * Z_07.asm:5601 row $11 = ResetObjMetastateAndTimer. Body drained
     * at src/game/core/core_dispatch.c:455 (one-line: ENEMY_MOVE_TIMER=0
     * + core_reset_obj_metastate). */
    [0x11] = core_reset_obj_metastate_and_timer, /* Zora */
    /* Task 7.4 step 3 — $21 Ghini INIT shares InitSlowOctorockOrGhini
     * (NES Z_07.asm:5601 row $21). Body drained at
     * src/oracle/enemies/enemy_walker_runtime.c:34
     * (enrt_init_slow_octorock_or_ghini). Reused here. */
    [0x21] = enrt_init_slow_octorock_or_ghini,   /* Ghini */
    /* Task 7.4 step 6e — tektite + bubble INIT wires.
     *
     * NES Z_07.asm:5601 InitObject_JumpTable:
     *   $0D BlueTektite -> InitTektite.
     *   $0E RedTektite  -> InitTektite.
     *   $2B BlueBubble  -> InitBubble.
     *   $2C RedBubble   -> InitBubble.
     *   $2D BlueBubble2 -> InitBubble.
     *
     * enrt_init_tektite (boss_runtime.c:119): RNG_B & 3 -> dir lookup +
     *   MOVE_TIMER = dir << 2. TektiteStartingDirs lives in
     *   enemy_jumper_bridge.c (already linked).
     * enrt_init_bubble (walker_runtime.c:66): WALK_SPEED=64 + InitWalker
     *   (link-relative dir seeding). */
    [0x0D] = enrt_init_tektite,                  /* BlueTektite */
    [0x0E] = enrt_init_tektite,                  /* RedTektite */
    [0x2B] = enrt_init_bubble,                   /* BlueBubble */
    [0x2C] = enrt_init_bubble,                   /* RedBubble */
    [0x2D] = enrt_init_bubble,                   /* BlueBubble2 */
    /* Task 7.4 step 6c — armos + flying-ghini INIT wires (closes step 6).
     *
     * NES Z_07.asm:5601 InitObject_JumpTable:
     *   $1E Armos       -> InitArmosOrFlyingGhini (armos branch).
     *   $22 FlyingGhini -> InitArmosOrFlyingGhini (flying-ghini branch).
     *
     * Native body lives at src/game/enemies/enemy_walker_bridge.c
     * (enrt_init_armos_or_flying_ghini). Composes:
     *   - SecretArmosRoomIds + SecretArmosXs scan (7-entry table).
     *   - dyn_tile_change_tile_obj_tiles (src/game/world/dyn_tile_dispatch.c —
     *     native ChangeTileObjTiles drain unblocking step 6c).
     *   - progress_get_room_flag_uw_item_state (already drained).
     *   - enemy_play_secret_found_tune (already drained).
     *   - enrt_end_init_flyer (already drained, $22 path).
     *   - core_reset_obj_metastate_and_timer (already drained, $22 path).
     *   - armos_draw_and_check_collisions (enemy_walker_bridge.c, $1E path).
     *
     * Closes Task 7.4 step 6 family: $1E + $22 INIT now wired alongside
     * UPDATE rows ($1E from 6b, $22 from 6a). */
    [0x1E] = enrt_init_armos_or_flying_ghini,    /* Armos */
    [0x22] = enrt_init_armos_or_flying_ghini,    /* FlyingGhini */
    /* Task 7.4 step 7 — trap INIT wires.
     *
     * NES Z_07.asm:5601 InitObject_JumpTable rows:
     *   $49 Trap -> InitTrap (Z_07.asm:5712 -> InitTrap_Full Z_01.asm).
     *   $4A Trap -> InitTrap.
     *   $2E Whirlwind -> DoNothing (no init body — NULL).
     *
     * Native body trap_init_trap_full @ src/game/world/trap_dispatch.c
     * (drained from src/oracle/world/trap_runtime.c:4). Spawns a
     * 4 / 6-trap cluster from TrapXs/TrapYs into TRAP_BASE_SLOT+i.
     * Composes core_init_one_simple_object (already drained). */
    [0x49] = trap_init_trap_full,                /* Trap */
    [0x4A] = trap_init_trap_full,                /* Trap (alt) */
    /* Task 7.4 step 9 — gibdo INIT pair-close.
     *
     * NES Z_07.asm:5601 InitObject_JumpTable row $30 Gibdo -> InitWalker
     * (bare walker init). $30 UPDATE was wired in step 6d
     * (enrt_update_gibdo); this row closes the pair so freshly-spawned
     * gibdos enter the walker init seed (DIR/MOVE_TIMER/anim defaults)
     * before the dispatch table picks up update side. */
    [0x30] = enrt_init_walker,                   /* Gibdo */
    /* Task 7.4 step 10 — Aquamentus INIT.
     *
     * NES Z_07.asm:5601 InitObject_JumpTable row $3D Aquamentus ->
     * SwitchBank #$01 + JMP InitAquamentus @ Z_04.asm region (sets
     * INVINCIBILITY=$E2, SFX_BOSS_CRY=16, X=$B0, Y=$80). Drained at
     * enemy_boss_runtime.c:102. Primitives self-contained — only writes
     * 4 RAM cells, no callouts. */
    [0x3D] = enrt_init_aquamentus,               /* Aquamentus */
    /* Task 7.4 step 11 — projectile-family INIT close.
     *
     * NES Z_07.asm:5601 InitObject_JumpTable rows:
     *   $11 Zora  -> ResetObjMetastateAndTimer (already drained as
     *                core_reset_obj_metastate_and_timer; extern'd
     *                since 7.4 step 2b for use by other rows).
     *   $21 Ghini -> InitSlowOctorockOrGhini (already extern'd +
     *                wired for $07/$09; reused here per NES table). */
    [0x11] = core_reset_obj_metastate_and_timer, /* Zora */
    [0x21] = enrt_init_slow_octorock_or_ghini,   /* Ghini */
    /* Task 7.5 step 1 — special-enemy INIT wins.
     *
     * NES Z_07.asm:5601 InitObject_JumpTable rows:
     *   $16 PolsVoice  -> InitWalker (bare walker init seed; full
     *                     pols-voice spawn state set by UpdatePolsVoice
     *                     state-1 path).
     *   $17 LikeLike   -> InitWalker (bare walker init seed; like-like
     *                     state machine driven entirely by UpdateLikeLike).
     *   $27 Wallmaster -> ResetObjMetastateAndTimer (state machine
     *                     entered from State 0; UPDATE drives the rest).
     *
     * All three INIT bodies are already drained + extern'd above
     * (enrt_init_walker for $16/$17, core_reset_obj_metastate_and_timer
     * for $27). Stance: ADOPT — single-row table-deltas, no bridges. */
    [0x16] = enrt_init_walker,                   /* PolsVoice */
    [0x17] = enrt_init_walker,                   /* LikeLike */
    [0x27] = core_reset_obj_metastate_and_timer, /* Wallmaster */
    /* Task 7.6 step 1 — leever INIT pair (NES Z_07.asm:5617 rows $0F/$10
     * both -> InitLeever). Body drained at enemy_walker_runtime.c:37 —
     * sets RedLeeverLongTimer=5 then z07_reset_obj_metastate_and_timer.
     * Body-shared between BlueLeever and RedLeever per NES asm. ADOPT
     * stance — drained twin reused, no bridge edits. */
    [0x0F] = enrt_init_leever,                   /* BlueLeever */
    [0x10] = enrt_init_leever,                   /* RedLeever */
};

const enemy_update_fn enemy_update_fns[ENEMY_LOOP_TYPE_MAX] = {
    /* NES UpdateObject_JumpTable @ Z_04.asm:5295.
     * $03/$04 = UpdateMoblin (turn rate $A0 + Wanderer + _TryShoot $5B).
     * $05/$06 = UpdateGoriya (Wanderer + boomerang $5C try).
     * $07-$0A = UpdateOctorock (this file, native, step 6).
     * $2A     = UpdateStalfos (Wanderer + animate-and-draw + sword $57).
     *
     * Step 6 fixed $07 = RedSlowOctorock semantically (was reusing
     * enrt_update_rope which is actually $29). Step 7 wires the rest of
     * the walker family using already-drained UPDATE bodies in
     * src/oracle/enemies/{enemy_walker,enemy_wanderer}_runtime.c.
     *
     * NOTE: enrt_update_moblin is intentionally bare in the drain
     * (no anim/draw/collision tail) — NES UpdateMoblin tail-jumps to
     * _TryShooting which returns directly to the dispatch caller. The
     * NES dispatcher (UpdateObject) handles post-call animate/draw
     * centrally. Our enemy_loop_tick does not yet have a central
     * post-dispatch animate/draw, so moblin walks but does not draw
     * sprites until that hook lands (step 8 / next task).
     *
     * Future rows ($01/$02 lynel, $0B/$0C darknut, $29 rope) need new
     * drain bodies (no _runtime.c entry yet) and will land in step 8+. */
    [0x03] = enrt_update_moblin,    /* BlueMoblin (drained, anim/draw deferred) */
    [0x04] = enrt_update_moblin,    /* RedMoblin */
    [0x05] = enrt_update_goriya,    /* BlueGoriya (drained, full body) */
    [0x06] = enrt_update_goriya,    /* RedGoriya */
    [0x07] = enrt_update_octorock,  /* RedSlowOctorock (step 6 native) */
    [0x08] = enrt_update_octorock,  /* RedFastOctorock — color/qspeed branch in body */
    [0x09] = enrt_update_octorock,  /* BlueSlowOctorock */
    [0x0A] = enrt_update_octorock,  /* BlueFastOctorock */
    [0x0B] = enrt_update_darknut,   /* BlueDarknut (step 11 native drain) */
    [0x0C] = enrt_update_darknut,   /* RedDarknut */
    [0x2A] = enrt_update_stalfos,   /* Stalfos (drained, full body) */
    /* Task 7.3 step 3 — keese family UPDATE wired (NES Z_04.asm:5295
     * UpdateObject_JumpTable). enrt_update_keese consumes flyer
     * primitives now resolved by src/game/enemies/enemy_flyer_bridge.c
     * (Directions8, c_move_flyer, c_control_keese_flight,
     * c_reset_shove_info, c_draw_object_mirrored_with_frame). */
    [0x1B] = enrt_update_keese,     /* BlueKeese */
    [0x1C] = enrt_update_keese,     /* RedKeese */
    [0x1D] = enrt_update_keese,     /* BlackKeese */
    /* Task 7.3 step 4 — zol/gel family UPDATE wired (NES Z_04.asm:5295).
     * NES UpdateObject_JumpTable: $13 = UpdateZol; $14 RedZol uses
     * UpdateGel (alias); $15 = UpdateGel. Bodies drained at
     * enemy_walker_runtime.c:156/163. Primitives resolved by
     * src/game/enemies/enemy_common_bridge.c (c_update_zol_state,
     * c_zol_check_collisions, c_gel_move, c_gel_check_collisions, plus
     * native c_shoot_limited drain for Zol state-2 split path). */
    [0x13] = enrt_update_zol,       /* Zol */
    [0x14] = enrt_update_gel,       /* RedZol — NES alias to UpdateGel */
    [0x15] = enrt_update_gel,       /* Gel */
    /* Task 7.3 step 5 — rope UPDATE (NES Z_04.asm:5295 $28 = UpdateRope).
     * Body drained at enemy_walker_runtime.c:97 — full leever-style
     * speed-ramp + dir-switch behavior. All primitives (c_walker_move,
     * c_draw_object_not_mirrored_with_frame, c_check_monster_collisions,
     * z07_anim_advance_and_fetch, z01_anim_set_sprite_desc_attrs, z01_abs)
     * already resolved by enemy_walker_bridge.c (Task 7.2 step 4..18). */
    [0x28] = enrt_update_rope,      /* Rope */
    /* Task 7.3 step 6 — peahat UPDATE (NES Z_04.asm:4014 UpdatePeahat).
     * Native drain in enemy_flyer_bridge.c — composes c_obj_shove,
     * c_control_peahat_flight (state-1 = enrt_flyer_peahat_decide_state,
     * other states share keese rows), c_move_flyer, draw + collisions. */
    [0x1A] = enrt_update_peahat,    /* Peahat */
    /* Task 7.3 step 7 — vire UPDATE wired (NES Z_04.asm:5295 $12 UpdateVire).
     * Drained body at enemy_boss_runtime.c:339 — composes
     * enrt_update_vire_state (state machine + jump-offset table +
     * c_gel_move_splitting + z04_update_common_wanderer),
     * enrt_check_vire_collisions, enrt_draw_vire, plus shoot/destroy
     * primitives. Bridge primitives carried in enemy_boss_bridge.c. */
    [0x12] = enrt_update_vire,      /* Vire */

    /* Step 12: shot UPDATE rows (Z_07.asm:5379-5388 dispatch).
     * NES UpdateMonsterShot (Z_04.asm:820) covers $53/$54 flying-rocks +
     * $57/$58/$59/$5A sword/magic/boomerang shots.
     * NES UpdateFireball (Z_04.asm offsets) covers $55/$56 fireballs.
     * Step 12 also fixed drain bug — enrt_update_monster_shot now falls
     * through to enrt_draw_shot (NES L_DrawShot label).
     * UpdateMonsterArrow ($5B) + UpdateArrowOrBoomerang ($5C) have
     * separate NES bodies — NOT yet drained, rows left NULL. */
    [0x53] = enrt_update_monster_shot,  /* FlyingRock (octorok shot) */
    [0x54] = enrt_update_monster_shot,  /* (alt rock) */
    [0x55] = enrt_update_fireball,      /* Fireball */
    [0x56] = enrt_update_fireball,      /* Fireball2 */
    [0x57] = enrt_update_monster_shot,  /* SwordShot */
    [0x58] = enrt_update_monster_shot,  /* MagicShot */
    [0x59] = enrt_update_monster_shot,  /* (shot variant) */
    [0x5A] = enrt_update_monster_shot,  /* (shot variant) */
    /* Task 7.4 step 2a — projectile-family carrier UPDATE rows (boulder
     * subset). NES Z_07.asm:5295 UpdateObject_JumpTable:
     *   $1F = UpdateBoulderSet  - enemy_projectile_runtime.c:98
     *   $20 = UpdateTektiteOrBoulder (Boulder branch)
     *                            - enemy_boss_runtime.c:126
     * $11 Zora deferred to step 2b — needs UpdateBurrower drain chain. */
    [0x1F] = enrt_update_boulder_set,       /* BoulderSet */
    [0x20] = enrt_update_tektite_or_boulder,/* Boulder */
    /* Task 7.4 step 2b — $11 Zora UPDATE. NES UpdateObject_JumpTable @
     * Z_04.asm:5295 row $11 = UpdateZora (Z_04.asm:1920). Drain at
     * src/oracle/enemies/enemy_walker_runtime.c:174. Native
     * c_update_burrower body in enemy_jumper_bridge.c (step 2b). */
    [0x11] = enrt_update_zora,              /* Zora */
    /* Task 7.4 step 3 — $21 Ghini UPDATE (NES Z_07.asm:5295 row $21 =
     * UpdateGhini @ Z_04.asm:3067). Drain at
     * src/oracle/enemies/enemy_walker_runtime.c:313 — composes
     * enrt_update_common_wanderer($FF), enrt_draw_ghini_and_check_collisions,
     * c_check_monster_collisions, plus per-slot loop killing $22 flying
     * ghini when ghini dies. All primitives already linked. */
    [0x21] = enrt_update_ghini,             /* Ghini */
    /* Task 7.4 step 6a — $22 FlyingGhini UPDATE (NES Z_04.asm:3967
     * UpdateFlyingGhini). Native drain in enemy_flyer_bridge.c —
     * composes c_control_flying_ghini_flight (6-row dispatch with
     * enrt_flyer_ghini_decide_state at state-1, flyer_chase/wander
     * shared with keese/peahat), c_move_flyer, and the existing
     * enrt_draw_ghini_and_check_collisions tail (walker_runtime.c:295).
     *
     * INIT row deferred to step 6b — InitArmosOrFlyingGhini body is
     * shared with $1E armos and reaches into ChangeTileObjTiles +
     * SecretArmosRoomIds + GetRoomFlagUWItemState which require their
     * own native drains (c_change_tile_obj_tiles only resolves via
     * c_shims.asm bank, not linked into Debug.md). */
    [0x22] = enrt_update_flying_ghini,      /* FlyingGhini */
    /* Task 7.4 step 6b — $1E Armos UPDATE (NES Z_04.asm:3302 UpdateArmos).
     * Native drain in enemy_walker_bridge.c — composes enrt_update_goriya
     * (already drained, type-$1E specialization at wanderer_runtime.c:176)
     * + ObjShoveDir / ObjAnimCounter gates + DrawArmosAndCheckCollisions
     * (sprite_anim_advance_and_fetch + dir-keyed frame select +
     * link/monster collision tail with $5D dead-dummy convert on death).
     *
     * INIT row $1E + $22 still deferred — InitArmosOrFlyingGhini reaches
     * ChangeTileObjTiles + secret-armos table not yet drained. */
    [0x1E] = enrt_update_armos,             /* Armos */
    /* Task 7.4 step 6d — bubble + gibdo UPDATE wires.
     *
     * NES Z_07.asm:5295 UpdateObject_JumpTable rows:
     *   $2B BlueBubble  -> UpdateBubble (Z_04.asm:bubble entry).
     *   $2C RedBubble   -> UpdateBubble.
     *   $2D BlueBubble2 -> UpdateBubble.
     *   $30 Gibdo       -> UpdateGibdo (Z_04.asm:7012 region).
     *
     * Both drained: enemy_walker_runtime.c:14 (bubble) and
     * enemy_common_runtime.c:22 (gibdo). All composed primitives
     * already linked into Debug.md:
     *   - wanderer_update_common / enrt_update_common_wanderer
     *     (enemy_wanderer_runtime.c — already used by ghini/moblin).
     *   - z01_anim_set_sprite_desc_attrs / enrt_animate_and_draw_common_object
     *     (enemy_walker_bridge.c:182/195/206).
     *   - z01_check_link_collision (enemy_projectile_bridge.c:53).
     *   - c_check_monster_collisions (link_collision_dispatch.c).
     *   - c_draw_object_not_mirrored_with_frame (draw_dispatch.c).
     *   - z07_anim_set_obj_hflip (enemy_walker_bridge.c:187). */
    [0x2B] = enrt_update_bubble,            /* BlueBubble */
    [0x2C] = enrt_update_bubble,            /* RedBubble */
    [0x2D] = enrt_update_bubble,            /* BlueBubble2 */
    [0x30] = enrt_update_gibdo,             /* Gibdo */
    /* Task 7.4 step 6e — tektite UPDATE rows.
     *
     * NES Z_07.asm:5295 UpdateObject_JumpTable rows:
     *   $0D BlueTektite -> UpdateTektiteOrBoulder (Tektite branch).
     *   $0E RedTektite  -> UpdateTektiteOrBoulder.
     *
     * Body drained at enemy_boss_runtime.c:126 (already wired for $20
     * Boulder in step 2a). Type-keyed branches at enemy_boss_runtime.c:218
     * ($20 boulder skips reversal-timer randomization) and :228
     * ($0D blue-tektite skips the &$7F mask in the post-land timer
     * randomization). */
    [0x0D] = enrt_update_tektite_or_boulder, /* BlueTektite */
    [0x0E] = enrt_update_tektite_or_boulder, /* RedTektite */
    /* Task 7.4 step 7 — whirlwind + trap UPDATE wires.
     *
     * NES Z_07.asm:5295 UpdateObject_JumpTable rows:
     *   $2E Whirlwind -> UpdateWhirlwind (SwitchBank #$01 + JMP
     *                    UpdateWhirlwind_Full Z_01.asm:1765).
     *   $49 Trap      -> UpdateTrap (SwitchBank #$01 + JMP
     *                    UpdateTrap_Full Z_01.asm:2434).
     *   $4A Trap      -> UpdateTrap.
     *
     * Native bodies already drained + linked via
     * src/game/world/trap_dispatch.c (trap_update_whirlwind_full /
     * trap_update_trap_full). All composed primitives resolved:
     *   - core_set_up_whirlwind, core_destroy_whirlwind,
     *     core_init_one_simple_object, core_get_opposite_dir,
     *     core_anim_set_sprite_desc_attrs (core_dispatch.c).
     *   - link_collision_check_link_collision (link_collision_dispatch.c).
     *   - sprite_anim_advance_and_fetch / sprite_anim_set_obj_hflip
     *     / sprite_anim_fetch_obj_pos (sprite_dispatch.c).
     *   - draw_object_not_mirrored_with_frame (draw_dispatch.c).
     *   - room_go_to_next_mode_from_play (room_dispatch.c).
     *   - uw_person_person_draw_and_check_collisions (uw_person_dispatch.c).
     *
     * SwitchBank #$01 collapses to no-op (single linear address space). */
    [0x2E] = trap_update_whirlwind_full,    /* Whirlwind */
    [0x49] = trap_update_trap_full,         /* Trap */
    [0x4A] = trap_update_trap_full,         /* Trap (alt) */
    /* Task 7.4 step 8 — fire-shooter UPDATE wires.
     *
     * NES Z_07.asm:5295 UpdateObject_JumpTable rows:
     *   $3F GuardFire    -> UpdateGuardFire (Z_04.asm:9684).
     *   $40 StandingFire -> UpdateStandingFire (Z_04.asm:257).
     *
     * UpdateGuardFire body (6 instructions): rate-6 animate-and-draw
     * + monster collisions + DeadDummy convert on kill (metastate
     * non-zero). Native drain in enemy_walker_bridge.c
     * (enrt_update_guard_fire). No INIT row — both default to bare
     * scratch init (NES Z_07.asm:5601 rows $3F/$40 not in the
     * InitObject_JumpTable's specialized list).
     *
     * UpdateStandingFire body: c_check_link_collision + palette=2 +
     * DIR=8 + animate-walking + (FRAME_FLAGS=0 if type != $40) +
     * draw_not_mirrored. Drain at enemy_walker_runtime.c:146.
     * Primitives all linked via walker_bridge / projectile_bridge
     * (z07_animate_object_walking forwarder added in step 8). */
    [0x3F] = enrt_update_guard_fire,        /* GuardFire (native EXTEND drain) */
    [0x40] = enrt_update_standing_fire,     /* StandingFire (oracle drain) */
    /* Task 7.4 step 10 — Aquamentus UPDATE.
     *
     * NES Z_07.asm:5295 UpdateObject_JumpTable row $3D Aquamentus ->
     * UpdateAquamentus (Z_04.asm:5594-5607). Drained at
     * enemy_boss_runtime.c:108 — composes c_aquamentus_{move,shoot,draw}
     * + c_check_monster_collisions + enrt_play_boss_hit_cry_if_needed.
     *
     * Native bridge bodies for c_aquamentus_{move,shoot,draw} added in
     * enemy_boss_bridge.c (per-line translation of Z_04.asm:5612/5684/5764).
     * draw_write_boss_sprite primitive (WriteBossSprite + Anim_EndWriteSprite
     * fused) lives in draw_dispatch.c. ENEMY_PAUSE_FLAG gate handled inside
     * enrt_update_aquamentus drain body. */
    [0x3D] = enrt_update_aquamentus,        /* Aquamentus */
    /* Task 7.5 step 2 — special-enemy UPDATE: $17 LikeLike.
     *
     * NES Z_07.asm:5295 UpdateObject_JumpTable row $17 LikeLike ->
     * UpdateLikeLike @ Z_04.asm:6818. Top-level state machine not
     * directly drained; native bridge body in enemy_special_bridge.c
     * carries per-line NES translation. Composes z04_update_common_wanderer
     * (already drained in enemy_boss_bridge.c) + z07_anim_fetch_obj_pos +
     * draw_object_mirrored_with_frame + draw_object_mirrored_over_link
     * (new public API in draw_dispatch.c step 2) + c_check_monster_collisions
     * + enemy_hide_sprites_over_link.
     *
     * Two paths driven by ObjCaptureTimer (= ENEMY_TURN_TIMER alias at
     * $042C):
     *   - 0: free-roam wander + 4-frame anim + capture-detect
     *        post-collision; if capture fired, seed monster X/Y =
     *        Link X/Y, clear Link's timer/metastate/shove, reset
     *        monster anim, INC LinkParalyzed.
     *   - != 0: animate up to frame 3, INC capture timer, drop magic
     *           shield at >= $60, draw mirrored OVER Link (sprites
     *           $10/$11), check death; on death (metastate != 0)
     *           clear LinkParalyzed + hide over-Link sprites. */
    [0x17] = enrt_update_like_like,         /* LikeLike */
    /* 7.5 step 3 — $16 PolsVoice UPDATE wired.
     * NES Z_04.asm:6533 UpdatePolsVoice. Native bridge body in
     * enemy_special_bridge.c. Two-state walker/jumper. Composes
     * enrt_pols_voice_move_x + enrt_pols_voice_is_square_walkable
     * (already drained in enemy_boss_runtime.c) + z07_anim_advance_and_fetch
     * + draw_object_mirrored_with_frame + c_check_monster_collisions.
     *
     *   State 0 (walking): decrement ObjRemDistance, ADC walk-speed-Y
     *                       per-direction, walkability probe; on tile
     *                       $B0 or $F4..$FF -> set state 1; on other
     *                       block -> flip dir (horizontal: EOR $03 +
     *                       2x MoveX; vertical: EOR $0C).
     *
     *   State 1 (jumping): vertical accel $38 frac + carry whole, ObjY
     *                       += whole; on speed-positive AND ObjY >=
     *                       TargetY -> state 0, randomize dir
     *                       ($01/$02/$04/$08) + distance ($31/$71),
     *                       grid-snap X/Y.
     *
     *   Pre-pass guards: InvClock or ObjStunTimer, OR odd FrameCounter
     *                    -> draw + collisions only.
     *   Tail: AdvanceAnim($08), DrawObjectMirrored, mask=$FE, collisions. */
    [0x16] = enrt_update_pols_voice,        /* PolsVoice */

    /* 7.5 step 4: $27 Wallmaster UPDATE. NES UpdateWallmaster
     * (Z_04.asm:4121). Native bridge body in enemy_special_bridge.c
     * carries per-line NES translation. State machine:
     *
     *   State 0 (idle): gated on Link's ObjState[0]==$40 + ObjTimer+1==0
     *                   + Link standing in a wall trigger zone (X in
     *                   {$20,$D0} for side walls, Y in {$5D,$BD} for
     *                   top/bottom). Calls drained
     *                   enrt_wallmaster_calc_start_position to compute
     *                   emergence offset + initial X/Y; seeds dir from
     *                   k_wallmaster_dirs_and_attrs[ObjStep], timer1=$60
     *                   / qspeed=$18 / animcount=$08, INC ObjState.
     *
     *   State 1 (walking): each frame, if shoved -> Obj_Shove; else if
     *                      magic clock or stun, draw only; else
     *                      MoveObject in current dir; on grid alignment
     *                      ($10/$F0), advance step + dir + tiles
     *                      crossed; on 7th tile end-of-trip: if
     *                      ObjCaptureTimer != 0 -> HideSpritesOverLink +
     *                      GameMode=3 + reset Link/IsUpdatingMode/
     *                      GameSubmode; either way ObjState[slot]=0
     *                      and exit (return to wall).
     *
     *   Draw + collisions tail:
     *     - If captured: reposition Link onto monster, force frame=1
     *       hand-closed, draw OverLink, patch sprites at hardcoded
     *       OAM offsets $40/$44.
     *     - Else: CheckMonsterCollisions (may set capture); save sprite
     *       cursor, PrepareToDraw + DrawObjectNotMirrored, restore
     *       cursor, look up SpriteOffsets[idx], patch $9C->$AC keese-
     *       tile fixup on closed-hand frame. */
    [0x27] = enrt_update_wallmaster,        /* Wallmaster */
    /* Task 7.6 step 2 — BlueLeever UPDATE ($0F). NES UpdateBlueLeever
     * @ Z_04.asm:2599-2647: ObjTurnRate=$A0 (ENEMY_AIR_SPEED=$A0) +
     * Wanderer_TargetPlayer + UpdateBurrower fall-through. Bridge body
     * at enemy_jumper_bridge.c:enrt_update_blue_leever — composes
     * enrt_wanderer_target_player (drained twin) + c_update_burrower
     * (already drained for $11 Zora UPDATE chain). */
    [0x0F] = enrt_update_blue_leever,       /* BlueLeever */
};

/* Internal: clear an enemy slot's scratch state per NES room-init
 * (Z_05.asm:1684-1699 — the per-slot init loop run for slots $B..1
 * BEFORE InitObject_JumpTable[ObjType,X]).
 *
 * Step 10 finding: prior implementation zeroed WALK_SPEED / ANIM_TIMER
 * / METASTATE — wrong vs NES, which seeds defaults:
 *   ObjQSpeedFrac = $20  (Z_05.asm:1696 — DEFAULT speed)
 *   ObjAnimCounter = 1   (Z_05.asm:1694 — INC from 0)
 *   ObjMetastate   = 1   (Z_05.asm:1695 — INC from 0; "first cloud state")
 * Octorok/Darknut init wrappers explicitly override WALK_SPEED so they
 * are unaffected. Bare-InitWalker types ($01-$06,$2A) inherit the $20
 * default — that's what unblocks goriya/stalfos walking (their UPDATE
 * bodies don't re-seed WALK_SPEED; first quest stalfos UPDATE BEQs out
 * past the @SetSpeed branch entirely). */
static void clear_slot_scratch(unsigned int slot)
{
    ENEMY_DIR(slot)            = 0u;
    ENEMY_STATE_TIMER(slot)    = 0u;
    ENEMY_LIFE(slot)           = 0u;
    ENEMY_METASTATE(slot)      = 1u;          /* NES default: first cloud state */
    ENEMY_PUSH_TIMER(slot)     = 0u;
    ENEMY_AIR_SPEED(slot)      = 0u;
    ENEMY_TURN_TIMER(slot)     = 0u;
    ENEMY_AI_STATE(slot)       = 0u;
    ENEMY_BLOATED_TIMER(slot)  = 0u;
    ENEMY_BOUNCE_FLAGS(slot)   = 0u;
    ENEMY_CHARGE_SPEED(slot)   = 0u;
    ENEMY_COLLIDED_TILE(slot)  = 0u;
    ENEMY_INVINCIBILITY(slot)  = 0u;
    ENEMY_HIT_REACTION(slot)   = 0u;
    ENEMY_DRAW_FRAME(slot)     = 0u;
    ENEMY_WALK_SPEED(slot)     = 0x20u;       /* NES Z_05.asm:1696 default */
    ENEMY_ANIM_TIMER(slot)     = 1u;          /* NES default INC from 0 */
    ENEMY_PUSH_DIR_SCRATCH(slot) = 0u;
    ENEMY_FLAP_PHASE(slot)     = 0u;
    ENEMY_FLYER_X_FINE(slot)   = 0u;
    ENEMY_STUN_TIMER(slot)     = 0u;          /* Z_05.asm:1693 ObjStunTimer */
    ENEMY_OBJ_SHOVE_DIR(slot)  = 0u;          /* ResetShoveInfo */
    OBJ(0x00D3u, slot)         = 0u;          /* ObjShoveDistance */
    ENEMY_MOVE_TIMER(slot)     = (unsigned char)slot;  /* InitObject preamble */
    ENEMY_ALIVE_FLAG(slot)     = 1u;          /* mark slot occupied */
}

void enemy_loop_room_init(unsigned char room_id, unsigned char scene_id)
{
    unsigned int slot;
    /* Clear all enemy slots on room load. */
    for (slot = ENEMY_LOOP_SLOT_FIRST; slot <= ENEMY_LOOP_SLOT_LAST; ++slot) {
        ENEMY_TYPE(slot) = 0u;        /* type 0 = DoNothing = empty */
        ENEMY_ALIVE_FLAG(slot) = 0u;
        ENEMY_X(slot) = 0u;
        ENEMY_Y(slot) = 0u;
    }

    /* Phase 7 step 2: room->template lookup deferred to Task 7.7.
     * For first probe (Q4=c) the test hook
     * enemy_loop_force_spawn_slow_octorock() fires from probe Lua to
     * seed slot 1 deterministically. Once the per-room ObjList
     * template_id table lands, this function will:
     *   1. lookup template_id = room_obj_template[scene_id][room_id]
     *   2. ptr = obj_list_for_template(template_id)
     *   3. for slot in 1..count: ENEMY_TYPE[slot] = ptr[slot-1]
     *   4. AssignObjSpawnPositions (NES Z_05.asm:1818)
     *   5. dispatch enemy_init_fns[ENEMY_TYPE[slot]]
     */
    (void)room_id;
    (void)scene_id;
}

void enemy_loop_tick(void)
{
    unsigned int slot;
    /* Q3=(b): function-pointer table dispatch. NULL = no-op (family
     * not yet wired). Q2=(c) gating done by caller — this function is
     * ONLY called inside the scroll-stable + non-paused branch of the
     * gameplay tick. */
    /* Step 4 pre-tick snapshot — captures slot state BEFORE the
     * dispatch loop runs. Used to localize where TYPE clears: if pre
     * still shows $07 but post is $00, the dispatch / update body
     * killed the slot. */
    enemy_loop_probe_publish_pre();

    /* Step 20 DecTimers prepass. NES IsrNmi @UpdateTimers /
     * @LoopTimer (z_07.asm:1604-1616) decrements ObjTimer ($0028..)
     * for every slot every VBlank. Walker direction-decision logic
     * (enemy_walker_runtime.c:107) and update_meta_object spark/cloud
     * progression both gate on ObjTimer == 0. Without a tick the
     * walker never picks a new direction and the spawning-cloud /
     * death-spark animation never advances. This prepass is the
     * native equivalent of the VBlank dec loop. */
    for (slot = ENEMY_LOOP_SLOT_FIRST; slot <= ENEMY_LOOP_SLOT_LAST; ++slot) {
        if (ENEMY_MOVE_TIMER(slot) != 0u) {
            ENEMY_MOVE_TIMER(slot) = (unsigned char)(ENEMY_MOVE_TIMER(slot) - 1u);
        }
        if (ENEMY_STUN_TIMER(slot) != 0u) {
            ENEMY_STUN_TIMER(slot) = (unsigned char)(ENEMY_STUN_TIMER(slot) - 1u);
        }
    }

    for (slot = ENEMY_LOOP_SLOT_FIRST; slot <= ENEMY_LOOP_SLOT_LAST; ++slot) {
        unsigned char t;
        enemy_update_fn fn;
        if (ENEMY_ALIVE_FLAG(slot) == 0u) continue;
        /* Step 20 metastate gate. NES UpdateObject (Z_07.asm:5275) checks
         * ObjMetastate before falling through to the per-type body — when
         * non-zero, control diverts to UpdateMetaObject which animates the
         * death-spark / spawning-cloud and (on completion) converts the
         * slot to a $60 dropped-item via SetUpDroppedItem. Drained as
         * update_meta_object() in enemy_walker_bridge.c. */
        if (ENEMY_METASTATE(slot) != 0u) {
            update_meta_object(slot);
            continue;
        }
        t = (unsigned char)ENEMY_TYPE(slot);
        if (t >= ENEMY_LOOP_TYPE_MAX) continue;
        fn = enemy_update_fns[t];
        /* Task 7.4 step 2a — write CurObjIndex per-slot. NES UpdateObject
         * uses the X register implicitly; drained C primitives that call
         * c_turn_towards_player8 / c_shoot / enrt_shoot read
         * ENEMY_THROWER_SLOT ($0340 = NES CurObjIndex) instead. Closes
         * Task 7.3 known gap (vire split spawn slot computation). */
        ENEMY_THROWER_SLOT = (unsigned char)slot;
        if (fn != 0) fn(slot);
    }

    /* Step 4 live-tick publish — last so block reflects post-tick
     * cells. Lua reads $FF7F00 to confirm UPDATE chain ran. */
    enemy_loop_probe_publish_live();
}

void enemy_loop_force_spawn_slow_octorock(unsigned int slot,
                                          unsigned char x,
                                          unsigned char y,
                                          unsigned char dir)
{
    /* Q4=(c) first probe seed: one slow octorok at known (x,y,dir).
     * Used by tools/debug/probes/probe_walker_parity.lua to capture a
     * 60-frame X/Y/DIR trace at matched RNG seed for diff vs NES.
     *
     * Step 2 writes state cells only (no enrt_init_ call yet — see
     * file-level comment). Probe verifies iterator + type lookup +
     * force_spawn cell writes. Task 7.3 wires walker init + ticks. */
    enemy_loop_force_spawn_typed(slot, 0x07u, x, y, dir);
}

void enemy_loop_force_spawn_typed(unsigned int slot,
                                  unsigned char enemy_type,
                                  unsigned char x,
                                  unsigned char y,
                                  unsigned char dir)
{
    /* Step 8 generic seed. Probe-side hook used to verify step-7
     * dispatch rows ($03/$04 moblin, $05/$06 goriya, $2A stalfos)
     * actually tick without crashing. Same shape as the octorok
     * seed: clear scratch, set type/x/y/dir, dispatch init row. */
    enemy_init_fn fn;
    if (slot < ENEMY_LOOP_SLOT_FIRST || slot > ENEMY_LOOP_SLOT_LAST) return;
    if (enemy_type >= ENEMY_LOOP_TYPE_MAX) return;

    ENEMY_TYPE(slot) = enemy_type;
    ENEMY_X(slot) = x;
    ENEMY_Y(slot) = y;
    clear_slot_scratch(slot);
    ENEMY_DIR(slot) = dir;

    fn = enemy_init_fns[enemy_type];
    if (fn != 0) fn(slot);
}

unsigned int enemy_loop_alive_count(void)
{
    unsigned int slot, n = 0u;
    for (slot = ENEMY_LOOP_SLOT_FIRST; slot <= ENEMY_LOOP_SLOT_LAST; ++slot) {
        if (ENEMY_ALIVE_FLAG(slot) != 0u) n++;
    }
    return n;
}

unsigned char enemy_loop_get_type(unsigned int slot)
{
    if (slot < ENEMY_LOOP_SLOT_FIRST || slot > ENEMY_LOOP_SLOT_LAST) return 0u;
    return (unsigned char)ENEMY_TYPE(slot);
}
