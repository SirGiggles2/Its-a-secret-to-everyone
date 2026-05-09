# Phase 6 Task 6.10.6 Step A — HUD live-read of inventory_t

- **NES source**: `reference/aldonunez/Z_01.asm:2804` StatusBarTransferBufTemplate; `:2922` FormatDecimalCountByte; `:2862` FormatHeartsInTextBuf
- **Drained C**:  `RoomRom/src/roomrom_hud.c` (`draw_count_cell`, `draw_hearts_row`, `roomrom_hud_refresh_dynamic`)
- **Coverage**:   PARTIAL — direct `g_inventory` read instead of NES DynTileBuf path. NES-faithful StatusBarTransferBuf form lands as Step B (Task 6.10.6 follow-up).
- **Stance**:     EXTEND (scaffolding step that unlocks observation; replaced by transfer-buf path later).

## What landed

- `draw_count_cell(value, col, row, pal)` — three-cell decimal renderer matching NES `FormatDecimalCountByte` semantics (`123` → "123", `23` → "X23", `3` → "X3 "). Caps display at 999 because RoomRom widens rupees to 16-bit.
- `draw_hearts_row(col, row, hud_id)` — reads `heart_values_max(hv)`, `heart_values_cur(hv)`, `heart_partial`. Tile mapping: `$F2` full / `$F3` half / `$F4` empty. Visible cap = 3 hearts pending the row-5 outline pass (Step B+ work).
- `roomrom_hud_refresh_dynamic()` — per-frame overlay of count + heart cells from `g_inventory`. Cheap (~15 VDP_setTileMapXY calls). Wired into the main pause-gated update block alongside the rupee tick + Link-damage tick (`RoomRom/src/main.c:1382-1388`).
- `roomrom_hud_draw()` caches `hud_id` so `refresh_dynamic` can repaint without re-running the static transfer macro.

## Decision evidence

Debate `debates/2026-05-08-phase6-next-move/`: unanimous `A` from Codex / Gemini / Sonnet / Opus. Trade-off accepted: mild NES-routing-layer accuracy debt (direct read vs DynTileBuf transfer). Redeemed when 6.10.6 transfer-buf form lands.

## Focused probe

Probe script: `tools/debug/probes/probe_phase6_step_a.lua`
ROM: `builds/Debug.md` (sole target).

Scenario:
1. Boot Debug.md, hold A+B+C chord 90 frames to enter RoomRom gameplay.
2. Capture baseline screenshot of HUD (UW redux room $73, all-zero inventory + 3 hearts default).
3. Poke `g_inventory` cells via `memory.write_u8` in 68K RAM domain:
   - `$FF001A + 1`  bombs        ← 0x08
   - `$FF001A + 21` rupees lo    ← 0x2A (=42)
   - `$FF001A + 22` keys         ← 0x03
   - `$FF001A + 23` heart_values ← 0x54 (max=5, cur=4)
   - `$FF001A + 24` heart_partial ← 0x80
4. Wait 6 frames so `roomrom_hud_refresh_dynamic` repaints.
5. Capture poked screenshot.

Expected (and observed):
- Rupee cell: `X 0` → `X42`
- Key cell:   `X 0` → `X 3`
- Heart-count cell (redux row 4 placeholder): `X 0` → `X 4`
- Bomb cell:  `X 0` → `X 8`
- Heart row at col 4 row 5: 3 fulls (cap; hp=$80 falls outside visible cap until Step B+ extends the row).

## Artifacts

- `docs/audit/drain_findings/phase6_evidence/phase6_step_a_baseline.png`
- `docs/audit/drain_findings/phase6_evidence/phase6_step_a_poked.png`
- `docs/audit/drain_findings/phase6_evidence/phase6_step_a_focused.log`

## Gate

- 4-line task header: filled.
- Gate 1 (per-function diff vs NES): `draw_count_cell` matches `FormatDecimalCountByte` 3-character formatting rule; `draw_hearts_row` consumes the same `HeartValues` hi/lo packing as NES `FormatHeartsInTextBuf`.
- Gate 2 (per-RAM-cell trace): not blocked — `g_inventory` is the canonical RAM mirror; cells map 1:1 to NES Variables.inc per `RoomRom/src/inventory.h`.
- Gate 3 (per-scenario oracle): deferred to milestone tag (full status-bar parity post-Step B).

## Follow-ups

- Step B (Task 6.10.6 final): NES DynTileBuf StatusBarTransferBuf path per Z_01.asm:2850 FormatStatusBarText. Replaces direct read.
- Task 6.10.5: Items bitfield writers/readers (item-pickup paths).
- Task 6.10.11: Audio dispatch (rupee-tick `Tune0Request`, harm sound).
- Step A overflow row 5 hearts (8-cell extension) lands when StatusBarTransferBuf consumer is proven.
