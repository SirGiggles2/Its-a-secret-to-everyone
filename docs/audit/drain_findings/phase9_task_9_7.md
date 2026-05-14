# Phase 9 Task 9.7 — Save / Death / Continue

- **NES source**: Multi-mode save+death+continue chain:
                  - `Z_05.asm:7375` `InitSaveRam` (SRAM init w/ `$5A` /
                    `$A5` sentinels — referenced by Task 9.2).
                  - `Z_05.asm:2207` `UpdateMode8ContinueQuestion_Full`
                    (continue-prompt mode renderer + input handler).
                  - `Z_07.asm:1622` `Mode8` dispatch row + `:1647`
                    `UpdateMode8ContinueQuestion` thunk into the
                    Z_05 full body.
                  - `Z_06.asm:816` `GameOverTransferBuf` (Game Over
                    tilemap transfer template).
                  - Death sequence: Z_07 Link-state machine drops
                    into Mode 7 (`Mode_Dying`) → Mode 6 (`Mode_GameOver`)
                    → Mode 8 (`Mode_ContinueQuestion`); UpdateLink
                    handles the per-frame death pose +
                    fade-to-grayscale.
- **Drained C**:  `src/state/save_serializer.{h,c}` — per-slot
                  serialize / deserialize / validate / checksum (Task
                  9.2 substrate, ADOPT). Death / continue / game-over
                  mode handlers NOT yet drained:
                  `UpdateMode8ContinueQuestion_Full` is not in
                  `tools/audit/drain_coverage.json` — manual
                  transcription target.
- **Coverage**:   PARTIAL — save-slot serialize / deserialize / valid
                  shipped (Task 9.2); death sequence + continue prompt
                  + game-over render + save-and-quit flow + FS return
                  boundary all DEFERRED. Mode 7 (`Mode_Dying`) Mode 6
                  (`Mode_GameOver`) Mode 8 (`Mode_ContinueQuestion`)
                  handlers all wait on Phase 9 follow-up tasks.
- **Stance**:     PARTIAL — save serializer ADOPT-stance (NES sentinel
                  + inventory mirror parity); death / continue
                  handlers REPLACE-stance pending drain or manual
                  transcription. Recording deferrals preserves audit
                  trail and lets Phase 9 close on the substrate slice
                  while the gameplay-flow slice tracks alongside Phase
                  12 promote.

## Wired (Task 9.2 + earlier)

| Component                    | Source / API                                          |
|------------------------------|-------------------------------------------------------|
| Per-slot serializer (43 B)   | `save_slot_serialize` (`src/state/save_serializer.c`) |
| Per-slot deserializer        | `save_slot_deserialize`                                |
| Magic + checksum validate    | `save_slot_validate`, `save_slot_compute_checksum`     |
| Multi-slot stride            | `SAVE_SLOT_STRIDE = 682`, `SAVE_SLOT_COUNT = 3`        |
| Inventory mirror             | `$0657..$067E` (40 bytes)                              |
| NES sentinel parity          | `$5A`/`$A5` (matches `Z_05.asm:7375` `InitSaveRam`)    |

## Deferred (Phase 9 deferrals)

| Item                       | Blocked on                                                  |
|----------------------------|-------------------------------------------------------------|
| Death sequence (Mode 7)    | Native rewrite of UpdateLink death pose + fade                |
| Game Over render (Mode 6)  | Native rewrite of `GameOverTransferBuf` transfer thread       |
| Continue question (Mode 8) | Drain or transcribe `UpdateMode8ContinueQuestion_Full`        |
| Save-and-quit              | Continue-question SAVE branch routes to `save_slot_serialize` |
| Game-over → FS return      | FS handoff layer at `src/frontend/fs/fs_handoff.c` extension  |

`save_slot_serialize` already provides the SRAM-side persistence; the
deferred work is the gameplay-flow harness that *calls* it at the
right modes. Each follow-up PR will:
1. Land the per-mode renderer.
2. Wire the mode→`save_slot_*` call.
3. Add a probe row to verify the round-trip.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean build; `state_save_serializer.o` +
`state_save_serializer_probe.o` linked.

## Status

CLOSE (with deferrals) — Task 9.7 Save / Death / Continue PARTIAL.
Save serializer substrate landed; death / game-over / continue-question
mode handlers + save-and-quit + FS-return path recorded as Phase 9
deferrals.
