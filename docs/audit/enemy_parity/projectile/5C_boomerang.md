# $5C ArrowOrBoomerang (Goriya boomerang)

- **NES source**: reference/aldonunez/Z_07.asm:3813 UpdateArrowOrBoomerang
- **Drained C**:  src/oracle/enemies/enemy_projectile_runtime.c enrt_update_arrow_or_boomerang
- **Coverage**:   PARTIAL
- **Stance**:     EXTEND

Behavior: full state machine drain (commit `bafdf355`).
- $00 inactive
- $10 fly out (enrt_update_monster_shot + range check |ObjGridOffset|
  >= ObjMovingLimit → state $30)
- $20 spark sub-state (anim countdown to $40)
- $30 slow down (qspeed=$40, ObjMovingLimit decrement → $40)
- $40/$50 return to thrower (z01_get_directions_and_distances_to_target
  → move at BoomerangQSpeedFracs[4] diagonal). On reach: destroy +
  thrower idle timer $30/$50/$70 random.

Missing vs NES: exact MoveShot semantics (save/restore GridOffset +
[$0E] perpendicular propagation), CalcBoomerangFrame anim cycle,
PlayBoomerangSfx, BoomerangBaseSpriteAttrCycle.
