# Round 2 — Codex Rebuttal

I concede one narrow SGDK fact: SGDK **does** have boot-time DMA queue auto-flush. The symbol/API is `DMA_AUTOFLUSH` / `DMA_setAutoFlush()`: `DMA_initEx()` enables it by default and sets `VBlankProcess |= PROCESS_DMA_TASK` (`sgdk/src/dma.c:52-58`, `sgdk/src/dma.c:93-103`). The header says this auto-calls `DMA_flushQueue()` for operations **pending in the queue** (`sgdk/inc/dma.h:127-128`).

That does **not** make Plan B work.

## The missing link: SAT enqueue

`VDP_setSpriteFull()` only writes RAM shadow entries in `vdpSpriteCache[index]` (`sgdk/src/vdp_spr.c:160-168`). The actual SAT upload is `VDP_updateSprites()`, which transfers `vdpSpriteCache` to `VDP_SPRITE_TABLE` via `DMA_transfer(...)` (`sgdk/src/vdp_spr.c:224-233`).

`SYS_doVBlankProcess()` waits for VBlank (`sgdk/src/sys.c:655-665`), then if `PROCESS_DMA_TASK` is set, calls `DMA_flushQueue()` (`sgdk/src/sys.c:679-696`). It does not call `VDP_updateSprites()`. The process flags are bitmap, DMA, XGM, scroll, and XGM2 fade only; no sprite/SAT task exists (`sgdk/inc/sys.h:15-19`). The only `VDP_updateSprites()` calls in `sys.c` are frame-load cursor show/hide helpers, not the VBlank process (`sgdk/src/sys.c:901`, `sgdk/src/sys.c:914`).

So Gemini is right about **queued DMA auto-flush**, wrong about **shadow SAT auto-flush**. Without an explicit `VDP_updateSprites(..., DMA_QUEUE)` or equivalent `DMA_queueDma*`, Plan B leaves updated shadow SAT in RAM and never enqueues the SAT copy.

## Final verdict

**Plan A + D, same commit.** A gives one explicit SAT queue per tick/VBlank using SGDK's single-writer SAT path. B freezes/stales sprites. C bypasses SGDK ownership. D should ship with A because HUD VDP writes are the next active-display stall source and the dirty gate is low-risk.
