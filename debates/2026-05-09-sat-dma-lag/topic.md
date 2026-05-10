# Debate — SAT DMA Lag Fix Plan

## Context

RoomRom Genesis port of NES Zelda 1. Debug.md ROM lags severely during normal gameplay. Root cause: 22 `VDP_updateSprites(N, DMA)` calls fire per frame across `RoomRom/src/roomrom_sprites.c` (20 callsites) + `RoomRom/src/roomrom_candle_fire.c` (2 callsites).

Each per-frame sprite setter (link_pose, sword, boomerang, arrow, bomb, candle, magic_shot, room_item, explosion) ends with its own `VDP_updateSprites(N, DMA)` — SGDK's blocking SAT DMA. Result: 5–9 SAT DMAs land per frame instead of 1.

NES Z1 model: one OAM DMA via `$4014` per VBlank.

Genesis-native equivalent: single SAT DMA per VBlank.

Build target: `Debug.md` only (sole target per CLAUDE.md HARD rule).

## Candidate plans

**A. Strip + single-flush.** Remove all 22 `VDP_updateSprites(N, DMA)` from setters. Add one `VDP_updateSprites(MAX_USED_SLOT, DMA_QUEUE)` at end of `roomrom_debug_tick` before publish_state_mirror. SGDK queues into VBlank DMA window.

**B. Auto-flush via VBlank handler.** Setters become pure shadow-SAT writes (`VDP_setSpriteFull` only — no flush call). `SYS_doVBlankProcess` already flushes shadow SAT each VBlank. Boot-time policy set, no per-tick flush call needed.

**C. Native SAT shadow buffer.** Roll our own `VDPSprite[80]` shadow in RAM. Per-frame: scan shadow → manual `DMA_doDma(DMA_VRAM, ..., SAT_BASE, ...)` once in VBlank. Bypasses SGDK SAT machinery entirely. Closest to NES OAM DMA model.

## Secondary fix candidate

**D. HUD dirty-gate.** `roomrom_hud_refresh_dynamic` writes ~15 `VDP_setTileMapXY` per frame (active display, blocking on CTRL/DATA). Add `s_hud_dirty` flag, set on inventory mutation (rupee_tick, heart change, item pickup, key change). Skip refresh when clean. Skip rate ~99%.

## Constraints

- NES accuracy = spec. Genesis-native impl.
- Build target: `Debug.md` (CombinedDebug renamed 2026-05-08).
- No new files in `RoomRom/src/` (HARD rule WT-5). Edits only.
- Substrate edits = main worktree only.
- Drain coverage rule: NES disasm secondary, drained C primary. Setter rewrite is sprite-pipeline plumbing, not gameplay logic — no drain candidate.
- Single-writer SGDK SAT machinery; mixing C with manual DMA risks tearing.

## Question for debate

Which plan (A, B, C, or hybrid) is the best long-term fix per CLAUDE.md decision rules:
1. Best long-term outcome
2. Best coding practice
3. Maximal efficiency
4. NES accuracy as spec; Genesis-native as impl

Should HUD dirty-gate (D) ship in same commit, follow-up commit, or skip?

## Format

Adversarial, 2 rounds. Round 1: each participant picks plan + states why others are wrong. Round 2: rebut strongest opposing argument; converge or hold.
