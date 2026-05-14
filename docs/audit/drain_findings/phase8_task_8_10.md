# Phase 8 Task 8.10 — Ganon

- **NES source**: `reference/aldonunez/Z_07.asm:5295` UpdateObject_JumpTable
                  row `$3E` Ganon → `Z_04.asm:10708` UpdateGanon umbrella.
                  `Z_07.asm:5601` InitObject_JumpTable row `$3E` →
                  `Z_04.asm:9913` InitGanon. Scene-phase sub-routines:
                  ScenePhase0 / ScenePhase1 / ScenePhase2, Ganon_Dying,
                  DrawBody, DrawAshes, DrawCloud, DrawBurst,
                  SetUpBurstRays, CheckCollisions,
                  AppendPaletteRowTransferRecord_{Brown,Blue,Triforce}.
                  Triforce-piece pickup re-arms slot 19 via
                  `Z_04.asm:10999` Ganon_ActivateRoomItem (consumed by
                  the boss-framework substrate built in Task 8.1).
                  Movement reuses BlueWizzrobe family
                  (`TurnSometimesAndMoveAndCheckTile`, `Move`) and
                  `PlaySample`.
- **Drained C**:  `src/oracle/enemies/enemy_ganon_runtime.c:169` —
                  `enrt_init_ganon`; line 187 — `enrt_update_ganon` full
                  umbrella + ScenePhase0/1/2 + Ganon_Dying + DrawBody +
                  DrawAshes + DrawCloud + DrawBurst + SetUpBurstRays +
                  CheckCollisions +
                  AppendPaletteRowTransferRecord_{Brown,Blue,Triforce}.
                  Plus `enrt_ganon_{randomize_location,
                  activate_room_item, get_cur_cloud_left/top/right/bottom}`,
                  `enrt_play_boss_hit_cry_if_needed`,
                  `enrt_play_boss_death_cry`, `enrt_update_candle`. Drain
                  PRIMARY for the entire Ganon body.
- **Coverage**:   PARTIAL — Ganon umbrella + scene-phase dispatcher +
                  death + draw + cloud + burst + collision-check +
                  triforce-piece room-item re-arm all drained.
                  BlueWizzrobe-family movement primitives
                  (`TurnSometimesAndMoveAndCheckTile`, `Move`) and the
                  `PlaySample` audio shim are STUBBED — slot ticks but
                  Ganon stays stationary until the `Z_07` wizzrobe drain
                  lands as a follow-up to this task.
- **Stance**:     PARTIAL — composes already-drained
                  `enrt_ganon_{randomize_location,activate_room_item,
                  get_cur_cloud_*}` + collision + boss-cry primitives.
                  Stubs deferred to Phase 8 follow-up (wizzrobe-family
                  movement drain) — tracked as `deferrals[]` after
                  phase commit.

## Wired pipeline (`src/game/enemies/enemy_loop.c`)

```
[0x3E] = enrt_init_ganon,        /* Ganon */
[0x3E] = enrt_update_ganon,      /* Ganon */
```

`Z_04.asm:10999` Ganon_ActivateRoomItem re-arms object slot 19 with the
triforce-piece reward — touches the same RAM cells (RoomItemId,
ObjState/Type/X/Y[19]) that Task 8.1 boss-framework substrate documents.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean build; only pre-existing `LINK_X` / `LINK_Y` redefinition warnings.

## Deferrals

- Wizzrobe-family movement drain (`TurnSometimesAndMoveAndCheckTile`,
  `Move`) — currently stubbed in `enrt_update_ganon`. Record in
  `prime_refresh.py --record-deferral 8 wizzrobe_movement_drain "Ganon
  stationary until BlueWizzrobe family drain lands"` after phase commit.
- `PlaySample` audio shim for Ganon death cry — currently stubbed.
  Routes through the broader audio-finalization track (Phase 10).

## Status

CLOSE (with deferrals) — Task 8.10 Ganon drain-direct wired. PARTIAL
coverage faithful to NES for everything except the BlueWizzrobe family
movement / audio shims, which defer to Phase 10 audio finalization +
Phase 7 enemy-family follow-up.
