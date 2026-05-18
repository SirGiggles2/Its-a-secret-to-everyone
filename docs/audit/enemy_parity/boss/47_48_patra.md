# $47 Patra1 / $48 Patra2

- **NES source**: reference/aldonunez/Z_04.asm:10070 UpdatePatra
- **Drained C**:  src/game/enemies/bosses/boss_patra.c boss_patra_update
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: bridge orchestrator over enrt_flyer_speed_up +
enrt_flyer_patra_decide_state + c_control_keese_flight (states 2/3) +
c_move_flyer + enrt_animate_and_draw_common_object(2) + child-loop +
TryChangeManeuver flip. boss_patra.c:101 calls
enrt_play_boss_death_cry_if_needed. Children $25/$26 spawned in INIT
slot 2..9 loop.
