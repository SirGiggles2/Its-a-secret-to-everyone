# Debate Synthesis — SAT DMA Lag Fix

**Date:** 2026-05-09
**Format:** Adversarial, 2 rounds, 3 voices (Sonnet, Gemini, Codex)
**Verdict:** Unanimous — **Plan A + Plan D, same commit**

## Round summary

| Voice | Round 1 | Round 2 |
|-------|---------|---------|
| Sonnet | A + D | A + D (reaffirm; steel-mans Gemini's hidden-dependency point but rejects it) |
| Codex | A + D | A + D (reaffirm; concedes only the narrow `DMA_AUTOFLUSH` fact, proves it doesn't help B) |
| Gemini | Hybrid B + D | **Concedes** — converges on A + D after SGDK source citations |

## The disagreement that resolved

Gemini Round 1 claimed `SYS_doVBlankProcess` auto-flushes the shadow SAT each VBlank, making Plan B work without any explicit flush call.

Sonnet and Codex both refuted with concrete SGDK source:
- `VDP_setSpriteFull` writes only `vdpSpriteCache[]` RAM (`sgdk/src/vdp_spr.c:160-168`). No queue enqueue, no dirty flag.
- `VDP_updateSprites` is the actual flush — calls `DMA_transfer` to upload cache to `VDP_SPRITE_TABLE` (`sgdk/src/vdp_spr.c:224-233`).
- `SYS_doVBlankProcess` only calls `DMA_flushQueue()` when `PROCESS_DMA_TASK` is set (`sgdk/src/sys.c:679-696`). That drains queued descriptors. Shadow-SAT writes never enqueue a descriptor.
- `SYS_doVBlankProcess` has no call to `VDP_updateSprites` and no SAT task flag (`sgdk/inc/sys.h:15-19`). The only `VDP_updateSprites` calls in `sys.c` are frame-load cursor helpers (`sys.c:901`, `914`), not the VBlank process.

Codex's narrow concession: SGDK does have `DMA_AUTOFLUSH` (`sgdk/src/dma.c:52-58, 93-103`), but it auto-flushes the **DMA queue**, not the shadow SAT. Plan B never populates the queue. Pure-B freezes the SAT in VRAM at the last explicit update.

Gemini Round 2: explicit concession. Cited `sgdk/src/sys.c:688-693` as the killing evidence. Converged on A+D.

## Plan A — agreed implementation

1. Strip the 22 `VDP_updateSprites(N, DMA)` callsites from setters:
   - `RoomRom/src/roomrom_sprites.c` (20 callsites): lines 247, 260, 347, 361, 372, 391, 447, 458, 502, 513, 529, 540, 583, 594, 615, 626, 671, 682, 722, 731
   - `RoomRom/src/roomrom_candle_fire.c` (2 callsites)
2. Add one `VDP_updateSprites(MAX_USED_SLOT, DMA_QUEUE)` at the end of `roomrom_debug_tick` after gameplay sprite mutation, before `roomrom_debug_publish_state_mirror()`.
3. `MAX_USED_SLOT` = highest active slot index + 1 (current slots 0..9 → use 10, or compute via `highestVDPSpriteIndex` if SGDK exposes it).

## Plan D — agreed implementation

`roomrom_hud_refresh_dynamic` writes ~15 `VDP_setTileMapXY` per frame. Active-display register pokes blocking on CTRL/DATA. Add `s_hud_dirty` flag, set on inventory mutation (rupee_tick, heart change, item pickup, key change). Skip refresh when clean. ~99% skip rate.

Ship in same commit as A. Three reasons:
- Orthogonal change, low risk (3-line flag + 5-6 setter touches).
- HUD VDP traffic is the next active-display stall source after SAT DMAs are gone — measuring A in isolation gets noisy.
- Gemini correctly flagged the "wait for follow-up" fallacy. Don't drift.

## Plans rejected

- **Plan B (auto-flush via VBlank handler):** Broken. SGDK has no shadow-SAT auto-flush. Would freeze sprites in VRAM.
- **Plan C (native SAT shadow buffer):** Liability. Two writers against `VDP_SPRITE_TABLE` violate the single-writer constraint. Manual `DMA_doDma` bypasses SGDK queue accounting and any future SGDK sprite-engine use.

## Decision rules satisfied (per CLAUDE.md)

1. **Best long-term outcome:** A uses SGDK's own DMA queue + shadow SAT machinery as designed. No forked subsystem. Future SGDK upgrades stay compatible.
2. **Best coding practice:** One explicit, auditable flush callsite. No hidden dependency on SGDK runtime state bits.
3. **Maximal efficiency:** 5-9 blocking SAT DMAs/frame → 1 queued SAT DMA inside VBlank window. Plus ~99% HUD VDP-write reduction.
4. **NES accuracy as spec, Genesis-native as impl:** Maps NES `$4014` OAM DMA model (one shadow buffer, one DMA per VBlank) onto SGDK's `DMA_QUEUE` + `SYS_doVBlankProcess` flush. Exact equivalent.

## Files

- `r1_sonnet.md`, `r1_gemini.md`, `r1_codex.md` — Round 1 positions
- `r2_sonnet.md`, `r2_gemini.md`, `r2_codex.md` — Round 2 rebuttals/conclusions
- `topic.md` — debate context
- `synthesis.md` — this file
