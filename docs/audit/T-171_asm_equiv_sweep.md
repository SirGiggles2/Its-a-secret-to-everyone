# T-171 — asm_equiv sweep: drained C vs NES 6502, routine level

Status: ACTIVE (Claude). Linux cloud session: no SGDK, BizHawk or NES ROM.
Every result below is routine-level equivalence against the reference
disassembly; none is a live NES-vs-Genesis capture.

## Method

`tools/audit/asm_equiv/asm_equiv.py` (specs in `specs.py`, `specs_core.py`):

- The NES routine is cut verbatim from `reference/aldonunez/*.asm`, assembled
  with ca65/ld65 at `$8000` and run in py65.
- The C port is compiled as a host shared object (`-DROOMROM_BUILD`,
  `nes_ram` = `g_mem`).
- Both sides start from the same random 32 KB image and use identical callee
  stubs that log their calls in order.
- Compared per case:
  - NES RAM `$0000-$01BF` and `$0200-$07FF` (the 6502 stack page differs by harness design);
  - WRAM `$6000-$7FFF`;
  - the callee log;
  - the A register or carry when the spec sets `ret`.
- Labels or symbols that are not resolved become "unexpected call" traps on
  both sides; a trap that fires fails the case.
- Harness-only memory is `$5000-$5FFF` (see `harness_core.c`).

Run with `python tools/audit/asm_equiv/asm_equiv.py [SPEC...] --cases N [--seed S]`.
Use `--debug K --cells ...` for a NES label trace of case K.

## Result (seed default, 1000 cases per spec, 29 specs)

```
ALL PASS
```

Per spec: CheckLadder, LadderSetup, UpdateDock, GetCollidableTile,
GetCollidableTileStill, GetCollidingTileMoving, GetCollidingTileMovingNes,
BoundByRoom, AddQSpeed, SubQSpeed, MoveObject, MoveShot, AnimateObjectWalking,
CycleCurSpriteIndex, Walker_Move, DoObjectsCollideWithThresholds,
FindEmptyMonsterSlot, ReverseObjDir, GetObjectMiddle, CompareHeartsToContainers,
FormatDecimalByte, CheckMazes, World_ChangeRupees, GetRoomFlags,
CheckMonsterCollisions, TakeItem, IsDistanceSafeToSpawn, World_FillHearts,
KeeseFlight. Deeper runs: TakeItem 2000, KeeseFlight 2000,
IsDistanceSafeToSpawn 1500, T-056 specs 2500 — all PASS. The "active" count
printed is nonzero only for specs that define an `active` predicate (T-056).

## Defects found and fixed (each FAIL before, PASS after)

| Routine | Drained C | Defect | Live impact |
|---|---|---|---|
| World_ChangeRupees (`Z_01`) | `src/game/hud/hud_dispatch.c` | Rupee-tile `$65` cleared `$0620` (CurRoomHistoryIndex) instead of `$0529` | Yes: corrupted room history on rupee spend/gain path |
| Magic-rod fire placement (`PlaceWeapon` fire) | `src/game/items/bomb.c` `bomb_fire_place_weapon` | NES leaves `[00]=$00 [01]=$10 [02]=$F0` for the caller; drain left stale scratch | Yes: stale scratch drove the following collision pass (multi-kill) |
| SubQSpeedFromPositionFraction (`Z_01`) | `src/game/world/object_dispatch.c` | Returned carry clear at the grid limit; NES returns carry set | No live caller found; drain corrected |
| Flyer_CompareMaxSpeed caller (`Z_04`) | `src/oracle/enemies/enemy_flyer_runtime.c` | Compared raw speed; NES compares `speed & $E0` | None for ROM maxima `$40/$80/$A0/$C0/$E0`; now exact for any value |

Mutation checks (T-056 doc) confirm the harness detects single-constant port errors.

## Documented harness limits

- GetOppositeDir with direction 0 reads ROM byte `$A9` past OppositeDirs;
  generators never feed direction 0 there (the game never does).
- TableJump pointer scratch `$02/$03` is not compared.
- ObjAttr `$10` does not occur in ROM tables; generators use real values.
- Plain collision entry points skip the NES `[00:01]` scratch (T-172 budget);
  `collision_get_colliding_tile_moving_nes` writes it and is checked separately.
- TakeItem generator excludes item ids `$0E`, `$12`, `$13` (paths into
  TakePowerTriforce / palette transfers, stubbed on both sides).
- KeeseFlight ignores scratch `$00-$03`.

## Not covered by this gate

Integration order, OAM output, timing and lag. Those remain lockstep + screen
sweep gates on Windows.
