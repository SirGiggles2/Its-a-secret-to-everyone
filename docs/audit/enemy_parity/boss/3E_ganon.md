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

STUBS: BlueWizzrobe family
(TurnSometimesAndMoveAndCheckTile, Move) and PlaySample. Slot ticks
but Ganon stays stationary until Z_07 wizzrobe drain lands.
