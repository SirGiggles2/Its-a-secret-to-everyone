from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SGDK = ROOT / "sgdk"
TOOLBIN = ROOT / "build" / "toolchain" / "sgdk_bin" / "bin"
LIB = SGDK / "lib"
PROJ = ROOT / "build" / "debug_project"
OUT = PROJ / "out"
ROM_RAW = OUT / "Debug_raw.md"
ROM_OUT = ROOT / "builds" / "Debug.md"

GCC = TOOLBIN / "gcc.exe"
OBJCOPY = TOOLBIN / "objcopy.exe"


CFLAGS = [
    "-DSGDK_GCC",
    "-DROOMROM_NO_STANDALONE_MAIN",
    "-m68000",
    "-Wall",
    "-Wno-main",
    "-Wno-unused-parameter",
    "-fno-builtin",
    "-ffunction-sections",
    "-fdata-sections",
    "-fms-extensions",
    "-Os",
    "-fomit-frame-pointer",
    "-ffixed-a4",
]

INCS = [
    ROOT / "src",
    ROOT / "src" / "abi",
    ROOT / "src" / "debug",
    ROOT / "src" / "frontend",
    ROOT / "src" / "frontend" / "intro",
    ROOT / "src" / "sgdk_adapter",
    ROOT / "RoomRom" / "src",
    ROOT / "src" / "state",
    ROOT / "src" / "game",
    ROOT / "src" / "game" / "cave",
    ROOT / "src" / "game" / "world",
    ROOT / "src" / "game" / "core",
    ROOT / "src" / "game" / "enemies",
    ROOT / "src" / "game" / "enemies" / "probes",
    ROOT / "src" / "game" / "combat",
    ROOT / "src" / "game" / "room",
    ROOT / "src" / "game" / "hud",
    ROOT / "src" / "game" / "items",
    ROOT / "src" / "oracle" / "room",
    ROOT / "src" / "core",
    SGDK / "inc",
    SGDK / "res",
]

TITLE_C_SOURCES = [
    ("src/sgdk_adapter/render_adapter.c", "render_adapter.o"),
    ("src/frontend/intro/intro_phase.c", "intro_phase.o"),
    ("src/frontend/intro/intro_title.c", "intro_title.o"),
    ("src/frontend/intro/intro_story.c", "intro_story.o"),
    ("data/intro/intro_font_chr.c", "intro_font_chr.o"),
    ("data/intro/intro_art_chr.c", "intro_art_chr.o"),
    ("data/intro/intro_palette.c", "intro_palette.o"),
    ("data/intro/intro_story_tilemap.c", "intro_story_tilemap.o"),
    ("data/intro/intro_restore_chr.c", "intro_restore_chr.o"),
    ("data/intro/intro_restore_palette.c", "intro_restore_palette.o"),
    ("data/intro/intro_title_bg_chr.c", "intro_title_bg_chr.o"),
    ("data/intro/intro_title_sprite_chr.c", "intro_title_sprite_chr.o"),
    ("data/intro/intro_title_palette.c", "intro_title_palette.o"),
    ("data/intro/intro_title_tilemap.c", "intro_title_tilemap.o"),
    ("data/intro/intro_title_fade.c", "intro_title_fade.o"),
    ("data/intro/intro_title_glow.c", "intro_title_glow.o"),
    ("data/intro/intro_common_bg_chr.c", "intro_common_bg_chr.o"),
    ("data/intro/intro_sprite_chr.c", "intro_sprite_chr.o"),
    ("data/intro/intro_misc_chr.c", "intro_misc_chr.o"),
    ("data/intro/intro_punct_chr.c", "intro_punct_chr.o"),
    ("data/intro/intro_blink_chr.c", "intro_blink_chr.o"),
    ("data/intro/intro_combined_palette.c", "intro_combined_palette.o"),
    ("data/intro/intro_treasures_tilemap.c", "intro_treasures_tilemap.o"),
]

ROOMROM_C_SOURCES = [
    ("src/game/cave/cave_dispatch.c", "cave_dispatch.o"),
    ("src/game/world/world_dispatch.c", "world_dispatch.o"),
    ("src/game/world/object_dispatch.c", "object_dispatch.o"),
    ("src/game/world/sprite_dispatch.c", "sprite_dispatch.o"),
    ("src/game/world/progress_dispatch.c", "progress_dispatch.o"),
    ("src/game/world/trap_dispatch.c", "trap_dispatch.o"),
    ("src/game/core/core_dispatch.c", "core_dispatch.o"),
    ("src/game/enemies/enemy_dispatch.c", "enemy_dispatch.o"),
    ("src/game/combat/collision_dispatch.c", "collision_dispatch.o"),
    ("src/game/room/room_dispatch.c", "room_dispatch.o"),
    ("src/game/hud/hud_dispatch.c", "hud_dispatch.o"),
    ("src/game/items/weapon_dispatch.c", "weapon_dispatch.o"),
    ("src/game/combat/targeting_dispatch.c", "targeting_dispatch.o"),
    ("src/game/combat/combat_dispatch.c", "combat_dispatch.o"),
    ("src/game/cave/uw_person_dispatch.c", "uw_person_dispatch.o"),
    ("src/game/combat/link_collision_dispatch.c", "link_collision_dispatch.o"),
    ("src/game/world/draw_dispatch.c", "draw_dispatch.o"),
    # Phase 7 Task 7.4 step 6c — native ChangeTileObjTiles drain. Shared
    # play-area dynamic-tile editing primitives consumed by armos secret
    # reveals, push-block secrets, bombable walls, burning brush.
    ("src/game/world/dyn_tile_dispatch.c", "dyn_tile_dispatch.o"),
    ("src/game/items/item_dispatch.c", "item_dispatch.o"),
    ("RoomRom/src/main.c", "roomrom_main.o"),
    ("RoomRom/src/ow_room_render_roomrom.c", "ow_room_render.o"),
    ("RoomRom/src/roomrom_hud.c", "roomrom_hud.o"),
    ("RoomRom/src/uw_room_render_roomrom.c", "uw_room_render.o"),
    ("RoomRom/src/uw_room_blob.c", "uw_room_blob.o"),
    ("RoomRom/src/uw_collision_data.c", "uw_collision_data.o"),
    ("RoomRom/src/uw_walk_model.c", "uw_walk_model.o"),
    ("RoomRom/src/uw_door_state.c", "uw_door_state.o"),
    ("RoomRom/src/roomrom_sprites.c", "roomrom_sprites.o"),
    ("RoomRom/src/roomrom_combat.c", "roomrom_combat.o"),
    ("RoomRom/src/roomrom_boomerang.c", "roomrom_boomerang.o"),
    ("RoomRom/src/roomrom_arrow.c", "roomrom_arrow.o"),
    ("RoomRom/src/roomrom_bomb.c", "roomrom_bomb.o"),
    ("RoomRom/src/roomrom_bg_palette.c", "roomrom_bg_palette.o"),
    ("RoomRom/src/roomrom_scene_load.c", "roomrom_scene_load.o"),
    # Task 5.4: warp coordinator + OW metadata accessor + level/quest table + Gate D probe
    ("RoomRom/src/ow_room_meta.c", "ow_room_meta.o"),
    ("RoomRom/src/roomrom_world_transition.c", "roomrom_world_transition.o"),
    ("RoomRom/data/levelinfo_start_rooms.c", "levelinfo_start_rooms.o"),
    ("RoomRom/src/probes/metadata_probe.c", "metadata_probe.o"),
    # Task 5.5: door-type expected table for L1Q1 verification
    ("RoomRom/data/uw_l1q1_expected_doors.c", "uw_l1q1_expected_doors.o"),
    # Task 5.6: cellar pair table + accessor module + LevelInfo offsets
    ("data/rooms/dungeons_offsets.c", "dungeons_offsets.o"),
    ("RoomRom/data/uw_l1q1_cellar_pairs.c", "uw_l1q1_cellar_pairs.o"),
    ("RoomRom/src/uw_cellar_meta.c", "uw_cellar_meta.o"),
    # Task 5.7: push-block manifest + accessor + state machine
    ("RoomRom/data/uw_l1q1_pushblocks.c", "uw_l1q1_pushblocks.o"),
    ("RoomRom/src/uw_push_block_meta.c", "uw_push_block_meta.o"),
    ("RoomRom/src/roomrom_pushblock.c", "roomrom_pushblock.o"),
    # Task 5.8: dark-room manifest + accessor + lit-state
    ("RoomRom/data/uw_dark_rooms.c", "uw_dark_rooms.o"),
    ("RoomRom/src/uw_dark_meta.c", "uw_dark_meta.o"),
    # Task 5.9: item-room manifest + accessor + pickup wrapper
    ("RoomRom/data/uw_item_rooms.c", "uw_item_rooms.o"),
    ("RoomRom/src/uw_item_room_meta.c", "uw_item_room_meta.o"),
    # Task 5.8.1: candle fire projectile (slot 8)
    ("RoomRom/src/roomrom_candle_fire.c", "roomrom_candle_fire.o"),
    ("RoomRom/src/roomrom_magic_shot.c", "roomrom_magic_shot.o"),
    ("RoomRom/src/roomrom_ow_palette.c", "roomrom_ow_palette.o"),
    ("src/state/palette_tick.c", "palette_tick.o"),
    # Task 6.1: PlayerState[4] shape (Phase 13 multiplayer-ready by construction).
    ("src/state/player_state.c", "player_state.o"),
    # Task 6.10.4: inventory_t struct mirroring NES Variables.inc cells.
    ("RoomRom/src/inventory.c", "inventory.o"),
    # Task 6.10.1: Paused flag (NES $E0).
    ("RoomRom/src/roomrom_pause.c", "roomrom_pause.o"),
    # Task 6.11.1/6.11.3: HeartValues damage path + ObjInvincibilityTimer.
    ("RoomRom/src/roomrom_link_damage.c", "roomrom_link_damage.o"),
    ("RoomRom/src/roomrom_palette_tick.c", "roomrom_palette_tick.o"),
    # Task 7.1: enemy framework (RNG byte-for-byte port of @ScrambleRandom).
    ("RoomRom/src/roomrom_rng.c", "roomrom_rng.o"),
    # Task 7.2: walker-family drain (octorok / moblin / stalfos / goriya /
    # darknut / rope / gel). enemy_walker_runtime.c carries init+update for
    # walker types; enemy_wanderer_runtime.c is the perpendicular-turn
    # helper; enemy_common_runtime.c is the shared zol/gel update; c_wanderer.c
    # is the c_walker_move primitive.
    ("src/oracle/enemies/c_wanderer.c", "oracle_c_wanderer.o"),
    ("src/oracle/enemies/enemy_common_runtime.c", "oracle_enemy_common.o"),
    ("src/oracle/enemies/enemy_wanderer_runtime.c", "oracle_enemy_wanderer.o"),
    ("src/oracle/enemies/enemy_walker_runtime.c", "oracle_enemy_walker.o"),
    # Task 7.2 step 12: shot UPDATE rows ($53/$54/$57-$5A monster shots,
    # $55/$56 fireballs). enemy_projectile_runtime.c carries
    # enrt_update_monster_shot / enrt_update_fireball / enrt_destroy_monster_shot
    # + L_DrawShot fall-through.
    ("src/oracle/enemies/enemy_projectile_runtime.c", "oracle_enemy_projectile.o"),
    # Task 7.3 step 1: flyer/jumper-family drain (keese, peahat). Drain Rule
    # D1 ADOPT — enemy_flyer_runtime.c carries enrt_init_peahat +
    # enrt_update_keese. --gc-sections strips until dispatch rows wire
    # them in step 2+.
    ("src/oracle/enemies/enemy_flyer_runtime.c", "oracle_enemy_flyer.o"),
    # Task 7.3 step 7: boss-family runtime TU. enrt_update_vire chain
    # ($12 Vire) lives here. --gc-sections + -ffunction-sections retains
    # only enrt_update_vire transitive callees; aquamentus/jumper/gleeok/
    # dodongo/manhandla/lamnola bodies stay stripped until their rows wire.
    ("src/oracle/enemies/enemy_boss_runtime.c", "oracle_enemy_boss.o"),
    # Phase 8 Task 8.3: Dodongo drained primitives. enrt_init_dodongo +
    # enrt_dodongo_check_collisions / _check_bomb_hit / _draw +
    # enrt_update_dodongo_state2_stunned + enrt_update_dodongo_state1_bloated_sub_die
    # + enrt_update_dodongo_bloated_sub_end live here. Native bridge body
    # for UpdateDodongo composes them in src/game/enemies/bosses/boss_dodongo.c.
    ("src/oracle/enemies/enemy_dodongo_runtime.c", "oracle_enemy_dodongo.o"),
    # Phase 8 Task 8.4: Manhandla drained primitives. enrt_init_manhandla +
    # enrt_update_manhandla (full UpdateManhandla body) +
    # enrt_manhandla_set_all_segments_direction / _check_collisions /
    # _move / _draw live here. Callee shims in
    # src/game/enemies/bosses/boss_manhandla.c.
    ("src/oracle/enemies/enemy_manhandla_runtime.c", "oracle_enemy_manhandla.o"),
    # Phase 8 Task 8.5: Gleeok drained segment-mgmt primitives.
    # enrt_init_gleeok_head + enrt_update_gleeok +
    # enrt_gleeok_check_collisions / _store_ref_seg_distance /
    # _set_segment_x/y / _contract_segment_x/y/segment / _dec_head_timer /
    # _ignore_segment live here. Native InitGleeok + UpdateGleeokHead +
    # 8 c_gleeok_* primitives in src/game/enemies/bosses/boss_gleeok.c.
    ("src/oracle/enemies/enemy_gleeok_runtime.c", "oracle_enemy_gleeok.o"),
    # Task 7.5 step 4: Wallmaster scratch/draw helpers. Drained
    # enrt_wallmaster_calc_start_position +
    # enrt_wallmaster_put_sprite{,s}_behind_bg_if_needed live here. Pulled
    # in by enemy_special_bridge.c's enrt_update_wallmaster ($27 UPDATE).
    ("src/oracle/enemies/enemy_wallmaster_runtime.c", "oracle_enemy_wallmaster.o"),
    # Task 7.2 step 2: enemy slot iterator + dispatch + ObjLists port (WT-5
    # promotion — gameplay code under src/game/, not RoomRom/).
    ("src/game/enemies/enemy_loop.c", "game_enemy_loop.o"),
    ("src/game/enemies/obj_lists.c", "game_enemy_obj_lists.o"),
    # Task 7.2 step 4: walker UPDATE primitives bridge — forwarders to
    # already-drained native bodies (link_collision/draw/sprite/core) +
    # Walker_Move stub. Per debate 2026-05-09 verdict (Option C). Wired
    # into UPDATE table below; --gc-sections retains only what enrt_update_*
    # transitively reaches.
    ("src/game/enemies/enemy_walker_bridge.c", "game_enemy_walker_bridge.o"),
    # Step 12: shot UPDATE primitives bridge (forwarders for c_move_object,
    # z01_bound_by_room, z07_destroy_monster, etc — same model as walker_bridge).
    ("src/game/enemies/enemy_projectile_bridge.c", "game_enemy_projectile_bridge.o"),
    # Task 7.3 step 3: flyer UPDATE primitives bridge — Directions8 +
    # c_move_flyer/c_control_keese_flight/c_reset_shove_info/
    # c_draw_object_mirrored_with_frame, with Flyer_Chase + Flyer_Wander
    # native drains from NES Z_04.asm:11707/11844.
    ("src/game/enemies/enemy_flyer_bridge.c", "game_enemy_flyer_bridge.o"),
    # Task 7.3 step 4: zol/gel UPDATE primitives bridge — forwarders to
    # already-drained enemy_common_runtime.c twins
    # (c_update_zol_state/c_zol_check_collisions/c_gel_move/
    # c_gel_check_collisions) + native c_shoot_limited drain
    # (NES Z_04.asm:11369). Wires $13 Zol / $14 RedZol / $15 Gel rows.
    ("src/game/enemies/enemy_common_bridge.c", "game_enemy_common_bridge.o"),
    # Task 7.3 step 7: vire UPDATE primitives bridge — c_gel_move_splitting,
    # z04_update_common_wanderer, c_anim_advance_and_fetch,
    # c_find_empty_monster_slot, c_shoot. Forwarders to drained twins in
    # enemy_common_runtime / enemy_wanderer_runtime / enemy_runtime / boss
    # runtime + sprite_dispatch back-end. Wires $12 Vire UPDATE row.
    ("src/game/enemies/enemy_boss_bridge.c", "game_enemy_boss_bridge.o"),
    # Phase 7 Task 7.4 step 2a — jumper/projectile bridge.
    # TektiteStartingDirs data drain + c_bound_flyer forwarder +
    # z07_find_empty_monster_slot native body. Wires $1F BoulderSet +
    # $20 Boulder dispatch rows.
    ("src/game/enemies/enemy_jumper_bridge.c", "game_enemy_jumper_bridge.o"),
    # Phase 7 Task 7.5 step 2 — special-enemy UPDATE bridge.
    # Native enrt_update_like_like body (NES Z_04.asm:6818) — the top-level
    # UPDATE state machines for $16 PolsVoice / $17 LikeLike / $27
    # Wallmaster are not directly drained, only their helpers are; this
    # bridge carries the per-line NES translation (same model as
    # enemy_boss_bridge.c for Aquamentus / Vire).
    ("src/game/enemies/enemy_special_bridge.c", "game_enemy_special_bridge.o"),
    # Phase 8 Task 8.1 — Boss Framework. Native CreateRoomObjects body
    # (Z_05.asm:8154-8250) wires the room-item slot 19 reward path.
    # Per-boss INIT/UPDATE bodies live in enemy_boss_bridge.c +
    # enemy_boss_runtime.c; this TU only carries the framework shell.
    ("src/game/enemies/bosses/boss_framework.c", "game_enemy_boss_framework.o"),
    # Phase 8 Task 8.3 — Dodongo bridge body. UpdateDodongo native umbrella
    # (Z_04.asm:5856) plus native State0_Move + State1_Bloated dispatcher +
    # Sub_Wait that the drain doesn't carry. Forwards c_get_object_middle /
    # c_check_monster_sword_collision / z07_update_dead_dummy /
    # z04_update_dodongo_bloated_sub_end to the dispatcher entry points
    # already in the link.
    ("src/game/enemies/bosses/boss_dodongo.c", "game_enemy_boss_dodongo.o"),
    # Phase 8 Task 8.4 — Manhandla callee shims. Resolves
    # c_turn_randomly_dir8 / c_play_boss_hit_cry_if_needed /
    # c_play_boss_death_cry / c_draw_object_mirrored to dispatcher entry
    # points (enemy_play_boss_*_cry, draw_object_mirrored) for the
    # drained enemy_manhandla_runtime.c body.
    ("src/game/enemies/bosses/boss_manhandla.c", "game_enemy_boss_manhandla.o"),
    # Phase 8 Task 8.5 — Gleeok native bridge. Carries InitGleeok
    # (Z_04.asm:7649) + UpdateGleeokHead (Z_04.asm:8527) + 8 c_gleeok_*
    # primitives (draw_body, fetch_neck_addrs, move_neck, move_head,
    # calc_segment_limits, stretch_neck, draw_head_and_check_collisions,
    # draw_segment_and_check_collisions). Drained per-segment helpers
    # consumed verbatim from enemy_gleeok_runtime.c.
    ("src/game/enemies/bosses/boss_gleeok.c", "game_enemy_boss_gleeok.o"),
    # Phase 8 Task 8.7 — Gohma callee shims. Resolves c_gohma_animate_and_draw
    # (Z_04.asm:8392) + c_gohma_check_collisions (Z_04.asm:8453) for the
    # drained enrt_update_gohma body in enemy_boss_runtime.c. Composes
    # sprite_anim_* + draw_object_*_with_frame + enrt_gohma_set_sprite_attributes
    # + c_check_monster_collisions — all already linked.
    ("src/game/enemies/bosses/boss_gohma.c", "game_enemy_boss_gohma.o"),
    # Phase 8 Task 8.8 — Patra drain. Carries kPatraSines /
    # kPatraChildStartAngles / kPatraChild1{Cosine,Sine}Bits /
    # kPatraChild2Bits + ShiftMultiply / DecreaseObjectAngle /
    # RotateObjectLocation helpers + enrt_init_patra (Z_04.asm:9552) +
    # enrt_update_patra_child (Z_04.asm:10164 — State 0 staged spawn +
    # State 1 orbit/draw/collision/dead-dummy). All math local to TU.
    ("src/oracle/enemies/enemy_patra_runtime.c", "oracle_enemy_patra.o"),
    # Phase 8 Task 8.8 — Patra bridge. boss_patra_update orchestrator
    # (NES UpdatePatra @ Z_04.asm:10070 + ControlPatraFlight @ 10124).
    # Composes enrt_flyer_speed_up + enrt_flyer_patra_decide_state +
    # c_control_keese_flight (states 2/3 reuse keese-head Chase/Wander) +
    # c_move_flyer + enrt_animate_and_draw_common_object(2) + child-loop
    # + TryChangeManeuver flip. ADOPT stance.
    ("src/game/enemies/bosses/boss_patra.c", "game_enemy_boss_patra.o"),
    # Phase 8 Task 8.9 — Lamnola drain. enrt_init_lamnola (Z_04.asm:9502)
    # + enrt_update_lamnola (Z_04.asm:9699) + enrt_lamnola_update_head +
    # enrt_lamnola_move. Composes c_anim_write_sprite,
    # c_check_monster_collisions, c_reset_shove_info, c_reset_obj_metastate,
    # c_get_opposite_dir, c_bound_by_room, c_get_colliding_tile_moving.
    # ADOPT stance.
    ("src/oracle/enemies/enemy_lamnola_runtime.c", "oracle_enemy_lamnola.o"),
    # Phase 8 Task 8.9 — Moldorm drain. enrt_init_moldorm (Z_04.asm:4763)
    # + enrt_update_moldorm (Z_04.asm:4907) + ControlMoldormFlight JT +
    # Moldorm_{Chase,Wander,ChangeFlyingState,PropagateDirs}. Composes
    # already-drained primitives (c_flyer_chase, c_flyer_wander,
    # c_move_flyer, c_check_monster_collisions, c_anim_write_sprite,
    # c_reset_obj_metastate, enrt_check_boss_hit_reaction,
    # enrt_flyer_moldorm_decide_state). ADOPT stance.
    ("src/oracle/enemies/enemy_moldorm_runtime.c", "oracle_enemy_moldorm.o"),
    # Phase 8 Task 8.9 — Lamnola+Moldorm shim bridge. Native shims for
    # c_anim_write_sprite (stub) / c_get_opposite_dir / c_bound_by_room /
    # c_get_colliding_tile_moving / z04_play_boss_death_cry_if_needed /
    # z07_set_shove_info_with0 — first dispatch wiring that exposes these
    # transitive callees. EXTEND stance.
    ("src/game/enemies/enemy_lamnola_bridge.c", "game_enemy_lamnola_bridge.o"),
    # Phase 8 Task 8.10 — Ganon ($3E) drain. enrt_init_ganon (Z_04.asm:9599)
    # + enrt_update_ganon umbrella (Z_04.asm:10321) + ScenePhase0/1/2 +
    # Ganon_Dying + DrawBody + DrawAshes + DrawCloud + DrawBurst +
    # SetUpBurstRays + CheckCollisions +
    # AppendPaletteRowTransferRecord_{Brown,Blue,Triforce}. Composes
    # already-drained enrt_ganon_{randomize_location,activate_room_item,
    # get_cur_cloud_*}, enrt_play_boss_{hit_cry_if_needed,death_cry},
    # enrt_update_candle, c_draw_object_{,not_}mirrored_with_frame,
    # c_anim_write_sprite, c_shoot_fireball, c_reset_obj_metastate,
    # core_reset_{obj_metastate_and_timer,shove_info_and_inv_timer},
    # colrt_check_monster_{sword,arrow_or_rod}_collision,
    # lcrt_check_link_collision_preinit, sprrt_anim_fetch_obj_pos.
    # PARTIAL stance — wizzrobe family motion stubbed (deferred to Phase 8
    # Task 8.11+); slot still ticks + scene phase machine evaluated.
    ("src/oracle/enemies/enemy_ganon_runtime.c", "oracle_enemy_ganon.o"),
    # Phase 8 Task 8.10 — Ganon shim bridge. Resolves GanonStartXs +
    # z01_* + sprrt_/lcrt_/colrt_ undefined refs surfaced by wiring
    # $3E into the enemy_loop dispatch table.
    ("src/game/enemies/enemy_ganon_bridge.c", "game_enemy_ganon_bridge.o"),
    ("src/game/enemies/probes/enemy_loop_probe.c", "game_enemy_loop_probe.o"),
    ("RoomRom/src/expanded_bg_chr.c", "expanded_bg_chr.o"),
    ("RoomRom/src/atlas/items_chr_x4.c", "atlas_items_chr_x4.o"),
    # PR-4a: scene-bank scaffolding + DMA state machine.
    ("RoomRom/src/atlas/roomrom_scene_vram_contracts.c", "atlas_scene_vram_contracts.o"),
    ("RoomRom/src/atlas/level_chr_swap.c", "atlas_level_chr_swap.o"),
    # PR-4b: UWSP enemy CHR banks (3 banks, 4x sub-pal expanded).
    ("RoomRom/src/atlas/enemy_chr.c", "atlas_enemy_chr.o"),
    # PR-5: UWSP boss CHR banks (3 banks, 1x sub-pal, SCENE_OBJ-shared).
    ("RoomRom/src/atlas/boss_chr.c", "atlas_boss_chr.o"),
    ("data/rooms/overworld.c", "overworld.o"),
    ("data/chr/overworld_bg.c", "overworld_bg.o"),
    ("data/rooms/dungeons.c", "dungeons.o"),
    ("data/chr/underworld_bg.c", "underworld_bg.o"),
    ("RoomRom/src/redux_overworld.c", "redux_overworld.o"),
    ("RoomRom/src/redux_overworld_bg.c", "redux_overworld_bg.o"),
    ("RoomRom/src/redux_uw_bg.c", "redux_uw_bg.o"),
    ("RoomRom/src/redux_hud_chr.c", "redux_hud_chr.o"),
    ("data/chr/common.c", "common.o"),
    ("data/chr/sprites.c", "sprites.o"),
    ("data/misc/palettes.c", "palettes.o"),
]


def run(args: list[str | Path], *, cwd: Path = ROOT) -> None:
    subprocess.run([str(arg) for arg in args], cwd=cwd, check=True)


def gcc_prefix() -> list[str | Path]:
    return [GCC, "-B", f"{TOOLBIN}\\"]


def include_args() -> list[str]:
    args: list[str] = []
    for inc in INCS:
        args.append(f"-I{inc}")
    return args


def compile_c(src: str, obj_name: str) -> Path:
    src_path = ROOT / src
    obj_path = OUT / obj_name
    print(f"[3] Compiling {src}...")
    run(gcc_prefix() + CFLAGS + include_args() + ["-c", src_path, "-o", obj_path], cwd=PROJ)
    return obj_path


def compile_asm(src: Path, obj_name: str, label: str) -> Path:
    obj_path = OUT / obj_name
    print(f"[3] Compiling {label}...")
    run(
        gcc_prefix()
        + ["-x", "assembler-with-cpp", "-Wa,--register-prefix-optional,--bitwise-or"]
        + CFLAGS
        + include_args()
        + ["-c", src, "-o", obj_path],
        cwd=PROJ,
    )
    return obj_path


def main() -> int:
    if not GCC.exists():
        print(f"ERROR: gcc not found at {GCC}")
        return 1

    PROJ.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    ROM_OUT.parent.mkdir(parents=True, exist_ok=True)

    print("[Debug] check_sgdk_pin.py")
    run([sys.executable, ROOT / "tools" / "check_sgdk_pin.py"])

    # PR-1 CHR-FOUNDATION gates (per docs/superpowers/specs/2026-05-07-
    # whole-chr-rollout-design.md). Debug.md is sole target; mirror the
    # strict gates the RoomRom dev harness used to run.
    print("[Debug][CHR-1 gate] verify_item_chr_manifest.py --strict")
    run([sys.executable, ROOT / "RoomRom" / "tools" / "verify_item_chr_manifest.py", "--strict"])

    # [CHR-1 gate] verify_vram_budget.py — re-enabled PR-2c 2026-05-08.
    # PR-2b switched the runtime to 64x32 plane mode (render_mode_set_h64v32
    # + BGA/BGB address overrides), raising the tile-data ceiling from
    # $A800 (1344 tiles) to $C000 (1536 tiles). ITEM bank end tile 1460
    # now fits with 75-tile headroom.
    print("[Debug][CHR-1 gate] verify_vram_budget.py")
    run([sys.executable, ROOT / "RoomRom" / "tools" / "verify_vram_budget.py"])

    print("[Debug][CHR-1 gate] check_generated_freshness.py")
    run([sys.executable, ROOT / "tools" / "probes" / "check_generated_freshness.py"])

    print("[1] Compiling sgdk/src/boot/rom_head.c...")
    run(gcc_prefix() + CFLAGS + include_args() + ["-c", SGDK / "src" / "boot" / "rom_head.c", "-o", OUT / "rom_head.o"], cwd=PROJ)

    print("[1] objcopy rom_head.o -> rom_head.bin...")
    run([OBJCOPY, "-O", "binary", OUT / "rom_head.o", OUT / "rom_head.bin"], cwd=PROJ)

    print("[2] Compiling sgdk/src/boot/sega.s...")
    run(
        gcc_prefix()
        + ["-x", "assembler-with-cpp", "-Wa,--register-prefix-optional,--bitwise-or"]
        + CFLAGS
        + include_args()
        + ["-c", SGDK / "src" / "boot" / "sega.s", "-o", OUT / "sega.o"],
        cwd=PROJ,
    )

    objects = [
        compile_asm(ROOT / "src" / "debug" / "a4_probe_asm.s", "a4_probe_asm.o", "src/debug/a4_probe_asm.s"),
        compile_c("src/debug/a4_probe_main.c", "a4_probe_main.o"),
    ]

    for src, obj in TITLE_C_SOURCES:
        objects.append(compile_c(src, obj))

    for src, obj in ROOMROM_C_SOURCES:
        objects.append(compile_c(src, obj))

    print("[4] Linking...")
    run(
        gcc_prefix()
        + [
            "-m68000",
            "-n",
            "-T",
            SGDK / "md.ld",
            "-nostdlib",
            OUT / "sega.o",
        ]
        + objects
        + [
            LIB / "libmd.a",
            LIB / "libgcc.a",
            "-o",
            OUT / "Debug.out",
            "-Wl,--gc-sections",
        ],
        cwd=PROJ,
    )

    print("[5] objcopy ELF -> flat binary...")
    run([OBJCOPY, "-O", "binary", OUT / "Debug.out", ROM_RAW], cwd=PROJ)

    print("[5] fix_checksum...")
    run([sys.executable, ROOT / "tools" / "fix_checksum.py", ROM_RAW, ROM_OUT])
    if ROM_RAW.exists():
        ROM_RAW.unlink()

    print()
    print(f"Debug built: {ROM_OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
