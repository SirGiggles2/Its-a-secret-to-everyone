# $41 Moldorm

- **NES source**: reference/aldonunez/Z_04.asm:4907 UpdateMoldorm
- **Drained C**:  src/oracle/enemies/enemy_moldorm_runtime.c:170 enrt_update_moldorm
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: full InitMoldorm + UpdateMoldorm + ControlMoldormFlight +
Moldorm_{Chase, Wander, ChangeFlyingState, PropagateDirs}. Head-only
flight on slots 5/$A. Body segments tail-swap into $5D DeadDummy on
metastate.
