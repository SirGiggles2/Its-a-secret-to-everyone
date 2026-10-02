# T-056 — ladder and raft (Link_EndMoveAndAnimate, CheckLadder, UpdateDock)

Status: **REVIEW** — ported and checked at routine level in a Linux cloud
session (no SGDK toolchain, BizHawk or NES ROM there). Not built with
`Debug.bat`, not captured live. Runtime acceptance is the Windows step below.

## Task header (Rule D1)

- NES source: `Z_07.asm` Link_EndMoveAndAnimate (@CheckLadderRoom .. @CheckWarps,
  LadderRoomsOW, LinkToLadderOffsetsX/Y), `Z_05.asm` CheckLadder,
  `Z_04.asm` UpdateDock (+ RaftDirections, PlaySecretFoundTune).
- Drained C: none (no `_runtime.c` candidate; `drain_coverage` has none for these).
- Coverage: FULL for the three routines.
- Stance: GREENFIELD port. Before this, the ladder and the raft did nothing
  (`$61` had no update row; nothing read `InvLadder` or wrote `LadderSlot`).

## Code

| File | What |
|---|---|
| `src/game/world/link_ladder.c` | Ladder setup (Link_EndMoveAndAnimate), CheckLadder, deferred ladder draw |
| `src/game/world/dock.c` | UpdateDock (raft), registered as object `$61` in `enemy_loop.c` |
| `src/game/combat/collision_dispatch.c` | `collision_get_colliding_tile_moving_nes`: same tile, plus the NES `[00:01]` column address (CheckLadder reads `[00]` after case E). Plain entry points unchanged (no extra stores in busy rooms) |
| `src/game/world/draw_dispatch.c` | `draw_static_item_sprites` (Anim_WriteStaticItemSpritesWithAttributes entry) |
| `src/game/enemies/enemy_render.c` | Item tiles `$6C` (raft) and `$76` (ladder) use the live-extracted pause tiles (`inventory_sprite_chr` 4/5, 6/7). The item atlas has no `$6C`; its `$76` entry is other art (bytes compared: not the ladder) |
| `src/game/world/render/sprite_render.c` | All 16 pause tiles (VRAM 1280..1295, the pause inventory's own reservation) uploaded at gameplay boot instead of only the compass pair |
| `src/game/enemies/enemy_loop.c` | Room entry clears LadderSlot (ResetInvObjState's ladder half) |
| `RoomRom/src/main.c` | Hooks only where Link's typed state lives: CheckLadder after Walker_CheckTileCollision (not shoved/halted), CheckScreenEdge gated on LadderSlot (GoWalkableDir), ladder setup before AnimateLinkBase, ladder draw after the object-cache clear, `roomrom_main_link_sync_from_nes`, `roomrom_main_link_end_move_from_object` (UpdateDock's Link_EndMoveAndAnimate_Bank4), `roomrom_main_ow_scroll_from_object` (raft exit) |

## Gate 1 — per-function equivalence vs the NES asm

`python tools/audit/asm_equiv/asm_equiv.py CheckLadder LadderSetup UpdateDock --cases 2500` cuts the routines out
of `reference/aldonunez/*.asm` verbatim, assembles them (ca65/ld65) and runs
them in py65 against the host-compiled C from the same random NES RAM, with
identical callee stubs (GetCollidingTileMoving with logged inputs and preset
tile/scratch results, the draw, AnimateObjectWalking, Link_EndMoveAndAnimate_Bank4).
Compared: NES RAM `$0000-$07FF` (except the harness's 6502 stack `$01C0-$01FF`)
and the ordered callee log.

```
CheckLadder: 2500 cases, 1138 took the active path (ladder drawn / ladder placed / raft moved or halted)
EndMove: 2500 cases, 453 took the active path (ladder drawn / ladder placed / raft moved or halted)
UpdateDock: 2500 cases, 1433 took the active path (ladder drawn / ladder placed / raft moved or halted)
CheckLadder case E (tile 8 px up): 28 cases
PASS: NES RAM $0000-$07FF and callee logs identical in every case
```

Mutation check (the harness catches port defects): ladder Y offset `$FB→$FC`
FAIL 31, case-E `-8→-7` FAIL 9, raft stop `$7F→$7E` FAIL 42, raft Y `+6→+5`
FAIL 24; `d != $10 → d > $10` PASS (equivalent mutant: `d < $10` is handled first).

Scope limits of this gate: it is routine level. Excluded inputs: ObjGridOffset
a nonzero multiple of 8 in Link_EndMoveAndAnimate (the Genesis mover truncates
before the call), direction 0 for the ladder/Link ObjDir in CheckLadder (never
set there). The Genesis integration below is not covered by it.

## Known Genesis-side differences (documented, not NES behaviour)

- The ladder is drawn after the weapons instead of during UpdatePlayer (the
  object sprite cache is cleared after UpdatePlayer). Same sprites, same cursor
  total per frame; only OAM order differs (accepted overlap/no-flicker class).
  The deferred draw leaves `[0F] = 0`.
- On the raft's exit tick the scroll starts after the raft draw; the native
  sweep hides object sprites while scrolling, so the raft is not shown on that
  one frame.

## Windows acceptance (Astra)

1. `Debug.bat`; record SHA. Freshness 9/9, VRAM budget gate (1280..1295 is the
   existing pause reservation, now resident from boot).
2. `run_lockstep` for `t056_ladder_ow` (room `$5F`, heart container across two
   water columns), `t056_ladder_uw` (L1 `$23` moat), `t056_raft` (`$55` dock ↔
   `$45`). Expect KEY parity incl. `$64` LadderSlot, ladder slot `$34F+x`/`$AC+x`/
   `$70+x`/`$84+x`, `$AC` halt, `$84` raft ride, `$394` = 2 after the down ride.
   Presets were built from `ow_map.py` / `uw_room_blob.c` tile data, not from
   captures: adjust stage positions only if the NES capture shows a different
   approach, then bless.
3. Screen diff at ladder-out and mid-ride ticks: ladder `$76` and raft `$6C`
   tiles vs NES OAM/CHR.
4. Full suite + `lag_gate.py` (CheckLadder runs only with a ladder out; the
   hooks are a byte test otherwise).
