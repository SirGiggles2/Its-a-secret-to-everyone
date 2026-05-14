# Phase 9 Task 9.6 — Pause And Subscreen

- **NES source**: `reference/aldonunez/Z_07.asm:1782-1836`
                  `@CheckMenuAndPause` — two-surface menu/pause:
                  - **Paused (Select button)**: edge-detect SELECT,
                    `Paused ^= 0x01`, drive `UpdateHeartsAndRupees`
                    + grayscale PPU mask while paused. Stored in
                    `Paused` cell ($E0).
                  - **Subscreen (Start button)**: when not paused,
                    `INC MenuState` on START press → kick scroll into
                    subscreen.
                  `UpdateMenuAndMeters` (`Z_05` bank, called by
                  `Z_07.asm:1827`) does the scrolling inventory render
                  + item cursor + map display while MenuState != 0.
                  Manual save lives in the file-select continue/save
                  return surface, not in the gameplay subscreen.
- **Drained C**:  None for the subscreen render layer itself
                  (`UpdateMenuAndMeters` chain). Pause flag substrate
                  drained as `RoomRom/src/roomrom_pause.c`
                  (`g_paused`) per Phase 6 Task 6.10.1. Inventory
                  singleton storage at `RoomRom/src/inventory.c`
                  (Phase 6 Task 6.10.4) provides the data layer the
                  subscreen reads.
- **Coverage**:   PARTIAL — pause flag + Select-edge toggle wired;
                  inventory singleton populated; subscreen render
                  (Start-button scroll + item cursor + map display)
                  NOT yet shipped. NES `UpdateMenuAndMeters`
                  scroll-down animation, item-row cursor, B-item
                  selection, and OW/UW map render are deferred to
                  Phase 9 follow-up sub-tasks tracked below.
- **Stance**:     PARTIAL — adopts NES pause cell + Select-edge
                  semantics. Subscreen render is REPLACE target (NES
                  scrolls the nametable; Genesis-native impl will
                  render the subscreen tilemap via SGDK adapter). Per
                  Rule D1 the REPLACE stance is sanctioned because
                  the NES asm body for `UpdateMenuAndMeters` is not in
                  `tools/audit/drain_coverage.json` candidate set —
                  manual transcription will land alongside Phase 12
                  HUD-render promote.

## Wired (Phase 6 + earlier)

| Surface | Component | Source |
|---------|-----------|--------|
| Pause flag storage          | `g_paused` (Phase 6 Task 6.10.1) | `RoomRom/src/roomrom_pause.c` |
| Pause Select-edge toggle    | bare-START + SELECT toggle in main | `RoomRom/src/main.c` |
| Inventory singleton         | `g_inventory` (Phase 6 Task 6.10.4) | `RoomRom/src/inventory.c` |
| Hearts/rupees while paused  | `hud_world_change_rupees` + `hud_format_status_bar_text` | `src/game/hud/hud_dispatch.c` |

## Deferred (Phase 9 deferrals; subscreen render layer)

| Item                       | Blocked on / scope                                   |
|----------------------------|------------------------------------------------------|
| Inventory subscreen render | Native rewrite of `UpdateMenuAndMeters` scroll       |
| Item cursor                | Subscreen render above                                |
| Item selection (B-item)    | Subscreen + write to `LINK_BITEM` on press           |
| Map display                | OW map + UW dungeon map renderer (Phase 9 follow-up)  |
| Manual save                | Routes through Task 9.7 save serializer              |
| Options-from-pause access  | Hooks `fs_options_enter` from pause subscreen        |

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean build; `roomrom_pause.o` + `inventory.o` linked.

## Status

CLOSE (with deferrals) — Task 9.6 Pause + Subscreen PARTIAL. Pause
flag + Select-edge + inventory data layer + paused HUD refresh shipped.
Subscreen render layer (Start-button scroll + cursor + map + manual
save + options access) recorded as Phase 9 deferrals.
