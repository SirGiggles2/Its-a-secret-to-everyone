# $5C ArrowOrBoomerang (Goriya boomerang)

- **NES source**: reference/aldonunez/Z_07.asm:3813 UpdateArrowOrBoomerang
- **Drained C**:  src/oracle/enemies/enemy_projectile_runtime.c enrt_update_arrow_or_boomerang
- **Coverage**:   PARTIAL
- **Stance**:     EXTEND

Behavior: state-machine drain, extended and live-probed 2026-09-22.
- $00 inactive
- $10 fly out through the collision-aware `MoveShot` adapter, preserving
  cumulative `ObjGridOffset`; range or block → state $30
- $20 spark sub-state (anim countdown to $40)
- $30 slow down (qspeed=$40, ObjMovingLimit decrement → $40)
- $40/$50 return to thrower (z01_get_directions_and_distances_to_target
  → move at BoomerangQSpeedFracs[4] diagonal). On reach: destroy +
  thrower idle timer $30/$50/$70 random.

Verified in a live Blue Goriya encounter: outbound range advanced through
`ObjGridOffset`, slow return reached the thrower and cleared the projectile;
a later shot exercised collision spark and fast-return frame phases. The
draw path uses the NES boomerang frame and base-attribute tables. Detailed
build/probe evidence: `builds/reports/recovery/boomerang-return-20260922/`.

2026-09-23 source review found and corrected the return-distance scratch
precondition: NES `UpdateArrowOrBoomerang` clears zero-page `$00` before the
state dispatch, because `GetDirectionsAndDistancesToTarget` increments it
once per axis within eight pixels and catch tests require an initial zero.
The C caller now clears the same byte before dispatch. The rebuilt Debug ROM
passes the existing focused staged/connected Blue Goriya scenario and the
12-case regression matrix. Evidence: `builds/reports/recovery/boomerang-scratch-fixed-20260923/result.json`.

Still partial: no paired NES/Genesis frame oracle for exact direction,
distance, timing, wall response, and palette; Red Goriya RNG variants,
boomerang sound routing, a deliberate stale-scratch reproduction, and a
complete second throw/catch remain TODO.
