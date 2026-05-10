# Round 1 — Codex Verdict: Plan A

Pick **Plan A**. D ships in the same commit, but it is not the SAT plan.

A wins because it restores the NES timing model: write shadow sprites during the tick, then perform one SAT transfer during VBlank.

## SGDK facts

- `VDP_setSpriteFull` only writes `vdpSpriteCache[]` RAM (`sgdk/src/vdp_spr.c:160-168`). It does not flush SAT.
- `VDP_updateSprites` is the flush point: it calls `DMA_transfer(tm, DMA_VRAM, vdpSpriteCache, VDP_SPRITE_TABLE, ...)` (`vdp_spr.c:224-233`).
- `DMA` is immediate DMA; `DMA_QUEUE` queues for next VBlank (`sgdk/inc/dma.h:51-56`, `sgdk/src/dma.c:322-342`).
- `SYS_doVBlankProcess` waits for VBlank, then `PROCESS_DMA_TASK` calls `DMA_flushQueue()` before user VBlank callback and joy update (`sgdk/src/sys.c:660-697`, `752-791`). It flushes queued DMA, **not** dirty sprites.

## Plan A executed

Delete the 22 setter-local `VDP_updateSprites(N, DMA)` calls and add one `VDP_updateSprites(10, DMA_QUEUE)` after gameplay sprite mutation and before `roomrom_debug_publish_state_mirror()`. Current slots are 0..9, so `10` is the real SAT span.

## Attacks

**Attack B**: false premise. There is no automatic shadow SAT flush in `SYS_doVBlankProcess`. If setters only touch `vdpSpriteCache[]`, VRAM SAT freezes at the last explicit update.

**Attack C**: wrong owner. A second native SAT buffer creates two writers against SGDK's SAT path. Manual `DMA_doDma` bypasses queue capacity/accounting and future SGDK sprite users.

**Attack hybrid**: useful only if it means "A plus D". Any hybrid containing B inherits no-flush freeze. Any hybrid containing C inherits dual-writer SAT tearing.

## HUD D

Same commit. `roomrom_hud_refresh_dynamic()` is active-display VDP register traffic every tick. Dirty-gating it is orthogonal, tiny, and removes the next stall source before performance diagnosis gets muddied.
