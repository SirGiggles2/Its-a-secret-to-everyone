# Phase 6 Task 6.10 — Inventory And Pause Verification

- **NES source**:
  - Pause toggle: `reference/aldonunez/Z_07.asm:1787-1796` Select-press toggles `Paused`; `Z_07.asm:472` `ORA Paused` gates frame update; `Z_05.asm:2061,3024,6746` Paused writes (status mode entry, potion forced-pause = 2, death sequence)
  - Status mode (sub-screen): `Z_05.asm:1374` InitMode8 + `Z_07.asm:229,1253` mode-8 dispatch; `Z_05.asm:2192-2204` Mode8BaseSpriteValues / Mode8SpriteYs / Mode8SelectionToMode / Mode8FlashTransferRecord / Mode8FlashAttrsAddrLo
  - Inventory cells (Variables.inc — already extracted): InvRupees, InvBombs, InvKeys, InvCandle, InvBow, InvArrows, InvWand, InvBoomerang, InvFlute, InvFood, InvLetter, InvPotion, InvLadder, InvRaft, InvBracelet, InvBook, InvRing, InvShield, InvMagicShield, InvHeartContainers, HeartPartial, Items (bitfield)
  - Status-bar render: `Z_01.asm:2804` StatusBarTransferBufTemplate + `:2823-2864` rupee tick countdown + `:2881-2885` key/bomb display
- **Drained C**:  N/A — RoomRom-native (NOT YET IMPLEMENTED beyond debug B-item cycle)
- **Coverage**:   PARTIAL (debug Z-cycle for B-item selection in `RoomRom/src/main.c:1497-1540`; everything else NONE)
- **Stance**:     EXTEND (large subsystem — split into sub-tasks; defer most to follow-up tasks)

## Verified parity (debug-mode only)

| NES behavior | NES anchor | RoomRom impl | Status |
| --- | --- | --- | --- |
| B-item slot select cycles inventory | NES status mode A-button cursor | `main.c:1497-1540` Z-press edge cycles `s_b_item` (BOOMERANG → ARROW → BOMB → CANDLE → ROD) | ✅ (debug-only — no NES UI) |
| B-press dispatches current item | `Z_07.asm` weapon-button dispatch | `main.c:1497-1540` switch on `s_b_item` calls roomrom_<item>_fire/spawn | ✅ |

## Required sub-tasks (Task 6.10 ladder)

The master plan checkbox list says: implement static text, dynamic text rendering, item count up/down, hardware status bar pinning, ABCDU select, animated pause, no-running-code-when-paused.

| Sub-task | NES anchor | Re-entry trigger |
| --- | --- | --- |
| 6.10.1 — `Paused` flag + Select-press toggle | `Z_07.asm:1787-1796` | This task |
| 6.10.2 — Suspend gameplay updates while paused | `Z_07.asm:472` `ORA Paused` BRA | This task — gate `roomrom_*_update` by `s_paused` |
| 6.10.3 — `World_IsFillingHearts` involuntary pause (potion) | `Z_05.asm:3022` `Paused = 2` | Task 6.10 followup once heart subsystem wired |
| 6.10.4 — Inventory state cells in RAM (InvRupees / InvBombs / InvKeys / InvCandle / etc) | `Variables.inc:152-200` | This task — declare struct in `RoomRom/src/inventory.h` |
| 6.10.5 — Items bitfield (Bow / Wand / Boomerang / Flute / Bait / Letter / Potion / Ladder / Raft / Bracelet / Book / Ring tier / Shield tier / Sword tier) | `Variables.inc` Items | This task |
| 6.10.6 — Status bar transfer buffer (top of screen, hearts + counts) | `Z_01.asm:2804` StatusBarTransferBufTemplate | This task — pin to BG plane top 2 rows |
| 6.10.7 — Status mode (Select-pressed inventory grid) | `Z_05.asm:1374` InitMode8 | Task 6.10-followup — own sub-task |
| 6.10.8 — Mode8 sprite indicator (selected B-item) | `Z_05.asm:2192-2196` Mode8BaseSpriteValues / Mode8SpriteYs | 6.10.7 |
| 6.10.9 — Status-bar dynamic text rendering | `Z_01.asm:2823-2885` FormatStatusBarText | This task |
| 6.10.10 — Status-bar item count up/down (rupee tick animation) | `Z_01.asm:2823-2864` RupeesToAdd / RupeesToSubtract | This task |
| 6.10.11 — `HeartPartial` handling (4-pixel partial heart) | `Z_05.asm:2062` HeartPartial reset on Mode11 | This task |

## Deferred (Task 6.10-followup)

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Save mode (B at status submenu) | `Z_05.asm:2198` Mode8SelectionToMode | Save subsystem absent | Phase 0 (Save/Load) |
| Quest selector (Q1/Q2) | `Z_07.asm:2469-2503` `QuestNumbers, Y` | Save subsystem absent | Phase 0 (Save/Load) |
| Mode8FlashTransferRecord palette flash | `Z_05.asm:2201` | Pause UI not yet drawn | 6.10.7 |
| Mode8FlashAttrsAddrLo selection-attribute strobe | `Z_05.asm:2204` | Pause UI not yet drawn | 6.10.7 |
| Pause-screen heart container animation | NES half-row redraw on pause entry | Status mode not yet drawn | 6.10.7 |
| OW vs UW status-bar variants | NES bottom-half map | Map subsystem absent | Phase 8 (Overworld map) |

## Probe / contract

- Static contract goal: `tools/debug/test_inventory_contract.py` —
  `Paused` flag toggles on Select edge, gameplay updates skip when
  paused, inventory struct shape matches NES Variables.inc cells,
  status-bar transfer buffer matches NES template byte-for-byte.
- Visual probe (post-impl): `tools/debug/probes/probe_pause_visual.lua`
  — press Select, snapshot status mode, verify item-grid layout vs NES.

## Gate

- 4-line task header: filled.
- Gate 1: not applicable (no full impl yet).
- Gate 2: deferred — Task 6.10 will not close until at minimum
  `Paused` flag + inventory struct + status-bar transfer buffer land.
- Gate 3: deferred to milestone tag (full pause-screen parity).

## Action items added to deferral ledger

1. Declare `inventory_t` in `RoomRom/src/inventory.h` matching
   NES Variables.inc cells exactly (InvRupees, InvBombs, InvKeys,
   InvCandle, InvBow, InvArrows, InvWand/Items.bit, InvBoomerang,
   InvFlute, InvFood, InvLetter, InvPotion, InvLadder, InvRaft,
   InvBracelet, InvBook, InvRing, InvShield, InvMagicShield,
   InvHeartContainers, HeartPartial, Items bitfield).
2. Wire `s_paused` global + Select edge-detect in main loop.
3. Gate `roomrom_*_update` calls on `s_paused == 0`.
4. Implement potion forced-pause (`Paused = 2`) + `World_IsFillingHearts`.
5. Pin status-bar transfer buffer to BG_A top 2 rows
   (matches NES NT0 status-bar region).
6. Format dynamic status bar text per NES `FormatStatusBarText`.
7. Implement rupee tick animation (`RupeesToAdd` / `RupeesToSubtract`).
8. Status mode (full inventory grid) — own sub-task, defer until 6.10.1-6.10.6 land.
