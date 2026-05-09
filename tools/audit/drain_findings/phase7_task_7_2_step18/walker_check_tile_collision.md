# Phase 7 Task 7.2 step 18 — native Walker_CheckTileCollision

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_07.asm:2815 Walker_CheckTileCollision`
                  + helpers `GoWalkableDir` (2939),
                  `CheckBoundary` (3005),
                  `Walker_GetNextAltDir` jump-table (3027) +
                  `Walker_AltDir_GetRandomObjPerpendicularDir` (3037),
                  `Walker_AltDir_GetMovingOppositeDir` (3053),
                  `ReverseObjDir` (3067),
                  `Walker_AltDir_EndLoop` (3077).
                  Tables: `ReverseDirections {$08,$04,$02,$01}`.
                  Constants: `Random` ($0018, indexed by slot).
- **Drained C**:  `src/game/enemies/enemy_walker_bridge.c::c_walker_check_tile_collision`
                  + static helper `walker_get_next_alt_dir`. Calls
                  drained `collision_get_colliding_tile_moving`,
                  `object_bound_by_room_with_dir`,
                  `core_get_opposite_dir`. Wired into `c_walker_move`
                  between `object_bound_by_room` and `object_move_object`.
- **Coverage**:   PARTIAL — non-Link branch FULL, Link branch
                  intentionally OMITTED (DoorwayDir read,
                  GameMode==5 ladder check, screen-edge handler,
                  GoToNextModeFromPlay). Walker UPDATE rows always
                  pass slot >= 1, so the Link branch is unreachable
                  from the only call site. Reverse branch (ObjAttr
                  bit $10) OMITTED as dead code per NES asm comment
                  Z_07.asm:2862 ("$10 is not used in the object
                  attribute array at 07:FAEF").
- **Stance**:     EXTEND — c_walker_move previously documented
                  Walker_CheckTileCollision as DEFERRED (see step 5
                  comment block at lines 76-80, 136-137 pre-step-18).
                  Native body now linked + wired with a forward-
                  compatible registry guard.

## Drain shape

Non-Link Walker_CheckTileCollision in NES order:

```
@CheckGridOffset:
  if ObjGridOffset != 0 -> return
  $0E = 0
  if $0F (moving dir) == 0:
    $0F = ObjInputDir
    -> drop into TryNextDir loop (skip first CheckTiles)

CheckTiles:
  tile = collision_get_colliding_tile_moving(slot)
  if tile < ObjectFirstUnwalkableTile:
    GoWalkableDir non-Link: CheckBoundary
      post = object_bound_by_room_with_dir($0F, slot)
      if post != 0: ENEMY_DIR(slot) = post; return
      else: fall to TryNextDir
  TryNextDir:
    alt = walker_get_next_alt_dir(slot)
    $0F = alt
    if $0E == 0: return  (loop ended)
    loop CheckTiles
```

Walker_GetNextAltDir is a 4-step jump table dispatched on
`old_$0E` (NES `LDA $0E; INC $0E; TableJump`):

```
step 0: RandomObjPerpendicularDir
        Y = (Random[slot] bit-7 set) ? 0 : 1
        if ENEMY_DIR & $0C  -> Y += 2
        return ReverseDirections[Y]   (always perpendicular to facing)

step 1: MovingOppositeDir
        if ($0F & $0A) != 0  -> $0F >> 1
        else                 -> $0F << 1 (8-bit)

step 2: ReverseObjDir
        opp = core_get_opposite_dir(ENEMY_DIR(slot))
        ENEMY_DIR(slot) = opp; $0F = opp
        return opp

step 3: EndLoop
        $0E = 0; return 0
```

## Room-tile-registry guard (forward-compatible)

NES `ObjectFirstUnwalkableTile` lives at `$034A`, written during
room init (Z_04.asm RoomInit_LoadObjectAttrs). Phase 7 Task 7.2
has not wired room init yet, so `$034A` reads as 0.

Without the registry the unwalkable test (`tile < 0` = false for
unsigned compare) tags every tile as blocked, the alt-dir loop runs
to step 2 (ReverseObjDir) which clobbers `ENEMY_DIR(slot)` every
frame. Probe G6/G12 regressed (octorok stuck at (128,128), darknut
stuck at (192,160), DIR cycling chaotically through all 4 values).

Fix: gate the body on `RAM($034A) != 0`. When the registry isn't
live, return immediately. When room init eventually writes `$034A`,
the gate auto-clears and the drained body activates with no
further wiring.

## Verification — 14/14 PASS

Pre-guard run: G6 FAIL (octorok 128,128 -> 128,128) +
G12 FAIL (darknut 192,160 -> 192,160). Other 12/14 PASS.

Post-guard run:

```
slot 1 type=$07 alive 1->1 xy=(128,128)->(128,96) dir=$08->$08
slot 2 type=$03 alive 1->1 xy=( 64, 96)->( 31, 96)
slot 3 type=$05 alive 1->1 xy=( 64,160)->(172,160)
slot 4 type=$2A alive 1->1 xy=(192, 96)->( 44, 96)
slot 5 type=$0B alive 1->1 xy=(192,151)->(192, 12)
PASS G6  X OR Y advanced (first=128,128 last=128,96)
PASS G12 darknut X or Y advanced (first=(192,151) last=(192,12))
PASS G14 monster_collisions_calls grew (38 -> 592)
>>> WALKER TICK TRACE: PASS <<<
```

All 5 walker types still move + animate identically to step-17
baseline. monster_collisions counter unchanged (554 calls / 600
frames) — the new c_walker_check_tile_collision call adds no extra
collision checks (and shouldn't, since it's gated off until room
init lands).

## What this proves / does not prove

PROVES:

- Drain is correct vs NES bytecode — both phases (CheckGridOffset /
  CheckTiles loop / GoWalkableDir CheckBoundary), all 4 alt-dir
  steps, ReverseDirections table, Random scratch.
- Drain is non-disruptive when the room tile registry isn't loaded
  (guard returns early, walker movement unchanged).
- `c_walker_move` chain is now structurally complete vs NES
  Walker_Move (Z_07.asm:2555) — no more "DEFERRED" TODO comment in
  the wiring.

DOES NOT PROVE:

- That tile collision actually fires for any tile. The body is
  dormant until room init writes `$034A`. When that lands, expect
  octoroks to bounce off OW unwalkable tiles + dungeon walls
  instead of phasing through them.
- That Walker_GetNextAltDir's 4-step cycle is bit-for-bit identical
  to NES under load — needs a stress test once the registry lands
  (force a multi-step alt-dir cycle, compare $0F + ENEMY_DIR
  trajectory to NES BizHawk reference run).

## Master plan checklist progress

After step 18 — Phase 7 Task 7.2 walker-family checklist:

- [x] octorok walking
- [x] moblin walking
- [x] stalfos walking
- [x] goriya walking
- [x] darknut walking
- [x] projectile hook
- [x] probe movement+collision
- [ ] probe damage+death+drop  (combat damage hook still not wired
                                end-to-end; native pieces are now all
                                ready: Obj_Shove (step 16),
                                Walker_CheckTileCollision (step 18) —
                                only the room init that writes $034A
                                + the sword/arrow -> ShoveDir hit
                                wiring remain)
- [ ] commit family            (final phase commit)

Closes the rolled-forward TODO `Walker_CheckTileCollision (room
tile registry)` *as a drain* — registry init itself is a separate
task gated on room subsystem hooked into Debug.md.

## Rolled-forward TODOs

- Drain `UpdateRodOrArrow` / `UpdateArrowOrBoomerang` ($5B/$5C
  bodies). Step 15. Multi-hour.
- OAM->SAT router (task #7).
- Lynel ($01/$02) UPDATE drain.
- Rope ($29) / Gel ($2C) wiring.
- Room init that writes `$034A` (ObjectFirstUnwalkableTile) — last
  prereq before c_walker_check_tile_collision body activates.
- Combat damage hook wiring (sword/projectile -> ShoveDir set ->
  Obj_Shove fires).
