# $3E Ganon

- **NES source**: reference/aldonunez/Z_04.asm Ganon_ScenePhase{0,1,2}
- **Drained C**:  src/oracle/enemies/enemy_ganon_runtime.c enrt_update_ganon
- **Coverage**:   PARTIAL
- **Stance**:     PARTIAL

Behavior: full umbrella body covering ScenePhase0/1/2 + Ganon_Dying +
DrawBody + DrawAshes + DrawCloud + DrawBurst + SetUpBurstRays +
CheckCollisions + AppendPaletteRowTransferRecord_Brown/Blue/Triforce.
Composes drained enrt_ganon_{randomize_location, activate_room_item,
get_cur_cloud_*}, enrt_play_boss_hit_cry_if_needed,
enrt_play_boss_death_cry, enrt_update_candle, plus
core_reset_obj_metastate_and_timer + shove + collision primitives.

The linked update now calls the same `enrt_blue_wizzrobe_turn_sometimes_and_move_and_check_tile`
routine as Blue Wizzrobes. Its tile query, wall reversal, and obstacle response
replace the former Ganon-only movement copy, which skipped the tile check.
Burst rays share `enrt_blue_wizzrobe_move`. `PlaySample` routes to the audio
adapter. A focused L9Q1 `$42` BizHawk entry check now confirms spawn, the
scene phase reaching and staying at 2, movement, and a live `$56` fireball.
The former code used `ENEMY_AI_STATE(slot)` (`Obj+$0444`) for NES `ObjState`
(`Obj+$00AC`); at slot 1 that aliased global `Ganon_ScenePhase` `$0445`,
causing a phase-1/phase-2 loop. It also checked the wrong arrow slot state.
Those reads now use `ENEMY_STATE_TIMER`.

The linked `enemy_ganon_bridge.c` previously supplied no-op implementations
for sword collision, arrow/rod collision, Link contact, and sprite-position
fetch. The native dispatchers were already linked, so the bridge now forwards
to them. In an isolated Genesis BizHawk L9Q1 `$42` fixture, a real A-button
wooden-sword swing overlapping visible Ganon left state `$00` and HP `$10`;
with his visibility timer zero, a second swing changed state to `$FE` (the
`$FF` brown state began counting down) and restored HP to `$F0`. A subsequent
controller-fired ordinary arrow did not advance the death phase; a silver
arrow did, and phase `$A0` cleared the room-item gate and incremented the
kill count once. Evidence: `builds/reports/recovery/ganon-room-entry-20260923/`
(`combat.lua`, `arrow.lua`, their traces and runners). These stage the boss
position/timer to isolate collision, so they do not establish a connected
fight, rendered death/reward appearance, Zelda handoff, ending, or NES visual
parity.
