# T-171 — asm_equiv sweep: drained C vs NES 6502, routine level

Status: ACTIVE (Claude). Linux cloud session: no SGDK, BizHawk or NES ROM.
Every result below is routine-level equivalence against the reference
disassembly; none is a live NES-vs-Genesis capture.

## Method

`tools/audit/asm_equiv/asm_equiv.py`. Specs live in `specs.py`, `specs_core.py` and `specs_monster.py`.

- **NES side.** Either a cut list of `reference/aldonunez/*.asm` ranges (older specs), or `closure.py`.
  - The closure walks from the entry label through every referenced global label, plus:
    - fall-through blocks;
    - every block between a branch and its target (keeps branches in range);
    - neighbouring blocks for `:-` / `:+` anonymous labels.
  - It stops at stubs and at cross-bank `*_Bank<n>` trampolines.
  - Raw `JMP $EEB8` bytes are resolved through the Trax disassembly (`closure.RAW_TARGETS`).
  - A bank-local label defined in two banks (e.g. `Exit`) is renamed per bank.
  - Assembled with ca65/ld65 at `$8000`; runs in py65.
- **C side.** The drained C is compiled as a host shared object (`-DROOMROM_BUILD`, `nes_ram` = `g_mem`).
  - Monster specs link the whole enemy runtime (`specs_monster.ENEMY_C_ALL`, built from `build_debug.py`).
  - A function also defined by a stub file is weakened in its own TU (`objcopy -W`), so the stub wins and the rest of the TU stays real.
- **Inputs.** Both sides start from the same random 32 KB image, with game-range values for the cells the routine reads.
- **Compared per case:**
  - NES RAM `$0000-$01BF` and `$0200-$07FF`;
  - WRAM `$6000-$7FFF`;
  - the ordered callee log;
  - A or carry when the spec sets `ret`.
  - `$00-$03` are skipped only in cases where the NES side ran TableJump (its ROM pointer scratch).
- **Traps and guards.**
  - Unresolved names become "unexpected call" traps on both sides.
  - An auto-stubbed *data* label fails the build unless the spec lists it in `data_unreached`.
  - Each spec runs in its own process, so a crash is reported for that spec only.
- **Monster boundary.** Logged stubs on both sides; everything else runs for real. The stubs are:
  - DrawObject[Not]Mirrored[OverLink], logging frame, slot, `[00] [01] [0F]`;
  - Anim_WriteItemSprites, logging item, slot, `[00] [01] [04] [05] [0C] [0F]`;
  - CheckMonsterCollisions, which has its own spec;
  - CheckLinkCollision;
  - Link_EndMoveAndAnimate_Bank4, logging Link X/Y.
- **Genesis options** are pinned to vanilla (Like-Like eats the shield).

Run with `python tools/audit/asm_equiv/asm_equiv.py [SPEC...] --cases N [--seed S]`. Use `--debug K --cells ...` for a NES label trace of case K.

## Result (seed 56, 1000 cases per spec, 62 specs)

```
ALL PASS
```

| Group | Specs |
|---|---|
| Core | CheckLadder, LadderSetup, UpdateDock, GetCollidableTile, GetCollidableTileStill, GetCollidingTileMoving, BoundByRoom, AddQSpeed, SubQSpeed, MoveObject, MoveShot, AnimateObjectWalking, CycleCurSpriteIndex, Walker_Move, DoObjectsCollideWithThresholds, FindEmptyMonsterSlot, ReverseObjDir, GetObjectMiddle, CompareHeartsToContainers, FormatDecimalByte, CheckMazes, World_ChangeRupees, GetRoomFlags, CheckMonsterCollisions, TakeItem, IsDistanceSafeToSpawn, World_FillHearts, KeeseFlight |
| Monsters | UpdateOctorock, UpdateMoblin, UpdateLynel, UpdateGoriya, UpdateStalfos, UpdateDarknut, UpdateRope, UpdateZol, UpdateGel, UpdateGhini, UpdateFlyingGhini, UpdatePeahat, UpdateKeese, UpdateTektiteOrBoulder, UpdateBlueLeever, UpdateRedLeever, UpdateZora, UpdatePolsVoice, UpdateLikeLike, UpdateArmos, UpdateBoulderSet, UpdateBlueWizzrobe, UpdateRedWizzrobe, UpdateWallmaster, UpdateBubble, UpdateGibdo, UpdateGuardFire, UpdateStandingFire, UpdateMonsterShot, UpdateFireball, UpdateMonsterArrow, UpdateArrowOrBoomerang, UpdateDeadDummy |

Bosses and the remaining object types are in progress. Their specs exist and fail; they do not count above.

## Defects found and fixed (each FAIL before, PASS after)

| Routine (NES) | Drained C | Defect | Effect in game |
|---|---|---|---|
| World_ChangeRupees (Z_01) | `hud/hud_dispatch.c` | Tile `$65` cleared `$0620` (CurRoomHistoryIndex) instead of `$0529` | Room history corrupted |
| Fire PlaceWeapon (Z_01) | `items/bomb.c` | `[00]=$00 [01]=$10 [02]=$F0` not left for the caller | Stale scratch in the next collision pass |
| SubQSpeedFromPositionFraction (Z_01) | `world/object_dispatch.c` | Carry clear at the grid limit | No live caller found |
| Flyer_CompareMaxSpeed (Z_04) | `oracle/enemies/enemy_flyer_runtime.c` | Raw speed compared, NES uses `speed & $E0` | None for ROM maxima |
| UpdateGoriya (Z_04) | `oracle/enemies/enemy_wanderer_runtime.c` | `STY $0E` missing | Scratch only |
| UpdateRope (Z_04) | `oracle/enemies/enemy_walker_runtime.c` | Turn timer did not call `_FaceUnblockedDir`; lined up on the chase target instead of Link's ObjX/ObjY | Ropes never turned on their timer; charged at bait instead of Link |
| Walker_CheckTileCollision (Z_07) | `enemies/enemy_walker_bridge.c` | Stale `$034A == 0` early return | None (room load writes `$034A`) |
| UpdateTektiteOrBoulder (Z_04) | `oracle/enemies/enemy_boss_runtime.c` | Shoved: NES runs Obj_Shove (raw `JMP $EEB8`, Trax bank 4 `$108FC`) and skips draw/collisions | Tektites/boulders were never knocked back |
| Jumper_AnimateAndCheckCollisions, Jumper_MoveY (Z_04) | same | `[0D]`, `[00]`, `[02]` not stored | Scratch only |
| UpdatePolsVoice (Z_04) | `enemies/enemy_special_bridge.c` | Landing direction/distance read `Random+1` | Different (deterministic) landing choice |
| Wizzrobe_DrawAndCheckCollisions (Z_04) | `oracle/enemies/enemy_wizzrobe_runtime.c` | Used the CheckMonsterCollisions umbrella (adds boomerang and arrow hits, a second Link check); flip on facing right instead of left | Wizzrobes hit by boomerang/arrow paths; drawn facing the wrong way horizontally |
| ShootMagicShot (Z_04) | same | Sound to `$0608` instead of Tune0Request `$0604` | Wizzrobe magic sound never played |
| Obj_Shove (Z_07) | `enemies/enemy_walker_bridge.c` | `[02]` step and `[03]` counter kept in locals | Scratch only |
| _TryShooting / _ShootIfWanted (Z_04) | `oracle/enemies/enemy_walker_runtime.c`, `enemy_walker_bridge.c` | `[01]` qspeed, `[00]` shot type not stored; Octorock had its own copy; `DEY/BPL` timer test approximated | Scratch only; one shared helper now |
| GetCollidableTile (Z_07) | `combat/collision_dispatch.c` | Plain entries skipped the `[00:01]` column address (T-172 budget choice, 2 stores) | Scratch only; `_nes` entry removed |
| BounceShot (Z_04) | `oracle/enemies/enemy_projectile_runtime.c` | Two-byte ShotBounceWidths read with Y 0..3 (runs into ShotBounceHeights), drain masked Y & 1 | Wrong sideways step when a shot bounces off the shield |
| UpdateMonsterArrow (Z_04) | same | Tested `[0C]` (set by a parry) instead of `[06]`; non-`$1x/$2x/$30` states bounced | Parried arrows vanished instead of bouncing |
| DrawArrow vs DrawArrowOrBoomerangAndCheckCollisions (Z_07) | `world/draw_dispatch.c` | Spark frame/flip applied inside DrawArrow | Sparking arrow drawn from `@CheckShooter` showed the spark frame |
| CalcBoomerangFrame (Z_07) | same | Wrote `[05]`; NES writes `[04]` only | Right half uses NES's stale `[05]` again (see Windows checks) |

Mutation checks (T-056 doc, Octorock anim/turn-rate constants) confirm the harness catches single-constant errors.

## Documented harness limits

- GetOppositeDir with direction 0 reads ROM byte `$A9` past OppositeDirs. Generators never pass direction 0 there; the game never does.
- ObjAttr `$10` does not occur in the ROM tables; generators use real values.
- TakeItem excludes item ids `$0E`, `$12`, `$13`. The ring palette tables are `data_unreached`.
- Generators keep game ranges where the NES indexes tables:
  - RollingSpriteIndex `0..$27`;
  - sword level 1..3;
  - shot bounce direction one of 1/2/4/8;
  - leever state 0..5.
- Not compared, by boundary:
  - sprite bytes (the screen sweep checks those);
  - Link's own movement inside Link_EndMoveAndAnimate;
  - the Genesis render cache.

## Windows checks needed (Astra)

1. `Debug.bat`, full suite and `lag_gate.py`. GetCollidableTile now does two stores per call; the shot and shove helpers do a few more.
2. Screen at `t057_food_bait` t605: the Goriya boomerang's right half now takes its attribute from the stale `[05]`, as the NES does. Expect OAM `$00/$40` as captured before. A mismatch means an earlier `[05]` writer still differs.
3. Routes with ropes, tektites, wizzrobes, Pols Voice and arrow-shooting moblins: RAM parity is expected to improve. Re-bless only from NES captures.

## Not covered by this gate

Integration order, OAM output, timing and lag. Those remain lockstep and screen-sweep gates on Windows.
