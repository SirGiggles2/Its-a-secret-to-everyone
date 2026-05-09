# Phase 6 Task 6.8 — Recorder (Flute) Verification

- **NES source**: `reference/aldonunez/Z_07.asm:2449` WieldFlute (NES Z1 calls it "Flute" in code; "Recorder" is the manual term); `Z_01.asm:1745` InitWhirlwind / `:1753` SetUpWhirlwind / `:1762` WhirlwindPrevRoomIdList / `:1765` UpdateWhirlwind_Full / `:1877` DestroyWhirlwind / `:1891` SummonWhirlwind / `:1973` DrawWhirlwind / `:1994` CheckInitWhirlwindAndBeginUpdate; `Z_07.asm:5698` UpdateWhirlwind; `Variables.inc:12` FluteTimer ($3C zeropage); `Variables.inc:167` UsedFlute ($051B); `Z_04.asm:5164` Digdogger_AfterFlute (boss interaction)
- **Drained C**:  N/A — RoomRom-native (NOT YET IMPLEMENTED)
- **Coverage**:   NONE (entire subsystem deferred — recorder/whirlwind tied to OW + UW Digdogger + secret-reveal mechanics that don't yet exist)
- **Stance**:     EXTEND (no implementation in v6 RoomRom; defer wholesale to Task 6.10 Inventory + Phase 8 Overworld + Phase 8 Task 8.x Digdogger boss)

## NES behavior summary (for re-entry context)

- **Activation** (`Z_07.asm:2452-2457`): `Tune1Request = $10` (flute song), `FluteTimer = $98 = 152 frames`.
- **UW dispatch** (`:2460-2461,2546-2551`): `INC UsedFlute` once per dungeon (used to wake Digdogger after damage).
- **OW dispatch** (`:2462-2503`): only fires if `GameMode = 5` (gameplay). Indexes `FluteRoomSecretsOW[$00..$09]` (10 rooms).
  - **Whirlwind summoned** ($00 in Q2; $01-$09 in Q1): `JSR SummonWhirlwind` allocates Obj slot, sets type $2E, drives Link X across screen → loads new room (`WhirlwindPrevRoomIdList[]` per-zone destination).
  - **Secret revealed** ($00 in Q1; $01-$09 in Q2): `SecretColorCycle` non-zero gates; otherwise allocates `ObjType+1[Y] = $5E` (flute-secret animator) — typically warps in the heart container or fairy.
- **Whirlwind state machine** (`Z_01.asm:1771-1872`): X+=2/frame, on collision teleport Link, on X reach $F0 destroy whirlwind + load new room. Palette-row flash via FrameCounter.

## Why deferred (NONE coverage)

| Required infra | Status in RoomRom | Re-entry trigger |
| --- | --- | --- |
| Tune1 audio request | RoomRom has no SongRequest dispatch (audio scaffold work). Music substrate works (memory `project_midi_substrate_works`) but FX channel routing absent | Audio scaffold task |
| `FluteTimer` (zero-page $3C) + per-frame countdown | No global frame-driven sub-system tick beyond per-item update | Task 6.10 (state) |
| `UsedFlute` flag — once-per-dungeon limiter for Digdogger awaken | UW dungeon state subsystem absent | Task 6.8 + Phase 7 (Enemies — Digdogger) |
| `FluteRoomSecretsOW` 10-room table + Q1/Q2 quest selector | OW room state absent | Phase 8 (Overworld) |
| Whirlwind object slot ($2E) + UpdateWhirlwind state machine | Object pool absent in RoomRom (single-slot per item) | Phase 7 (Enemies + Object Pool) |
| OW teleport / room load on whirlwind X = $F0 | Cross-room load not implemented in RoomRom debug harness (probe loads single fixed room $73) | Phase 8 (Overworld scrolling) |
| `WhirlwindPrevRoomIdList[]` zone destination table | OW screen-graph absent | Phase 8 |
| `SecretColorCycle` palette flash sequence | Palette-cycling subsystem absent | Phase 8 |
| Flute secret object type $5E (`Anim_FluteSecret`) | Object animator pool absent | Phase 7 |
| Digdogger awaken side-effect | Digdogger boss absent | Phase 8 boss verification |

## Deferred — re-entry triggers (Task 6.8-followup)

| Behavior | NES anchor | Re-entry trigger |
| --- | --- | --- |
| WieldFlute itself + Tune1 dispatch | `Z_07.asm:2449` | Audio scaffold (Phase 9-ish) — first concrete task in 6.8 ladder |
| Whirlwind summon + travel | `Z_01.asm:1891-1872` | Phase 7 object pool + Phase 8 OW load |
| OW secret reveal (heart/fairy at column-cycle complete) | `Z_07.asm:2504-2526` | Phase 8 OW scripted-secret subsystem |
| `UsedFlute` UW once-per-dungeon flag | `Z_07.asm:2549-2551` | Phase 7 Digdogger boss verification |
| FluteRoomSecretsOW table extraction | `Z_05.asm:7294` (data table somewhere in bank 5) | Phase 8 OW data tables — extract alongside RoomId map |
| Q1 vs Q2 quest selector | `Z_07.asm:2469-2503` `QuestNumbers, Y` | Phase 0/12 (Save/load + quest mode) |

## Probe / contract

- No probe possible until activation primitive exists.
- Static contract goal (post-implementation): `tools/debug/test_recorder_contract.py` —
  Tune1 = $10, FluteTimer init = $98, UsedFlute increments once,
  whirlwind state machine X-stride and X = $F0 trigger, OW vs UW dispatch.

## Gate

- 4-line task header: filled.
- Gate 1: not applicable (no impl).
- Gate 2: deferred — Task 6.8 will not close until at least the Tune1 dispatch + FluteTimer countdown land. Marker placeholder in tracker.
- Gate 3: deferred to Phase 8 milestone (OW teleport functional).

## Action items added to deferral ledger

1. Extract `FluteRoomSecretsOW[10]` from PRG bank 5 into `data/ow_flute_rooms.h`.
2. Extract `WhirlwindPrevRoomIdList[]` zone destinations alongside.
3. Fold WieldFlute audio dispatch into the audio scaffold task (Tune1Request = $10).
4. Fold `UsedFlute` into Phase 7 Digdogger boss verification.
5. Implement whirlwind object slot in Phase 7 object pool work.
