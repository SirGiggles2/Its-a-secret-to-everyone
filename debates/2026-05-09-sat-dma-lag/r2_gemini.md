I concede. Round 1's advocacy for "Hybrid B" rested on the assumption that `SYS_doVBlankProcess` performed a late-frame sweep of `vdpSpriteCache`. Verification of the SGDK source confirms Sonnet and Codex are correct: SGDK does not auto-flush the shadow SAT.

The "Stripping" logic in B, without an accompanying manual trigger, would result in the shadow SAT never reaching the VDP. `SYS_doVBlankProcess` flushes the *DMA queue*, but it does not populate it with sprite data.

**The citation that kills Pure-B:** `sgdk/src/sys.c:688-693`. 
The system task `PROCESS_DMA_TASK` calls `DMA_flushQueue()`, but there is no logic in the VBlank process loop to scan `vdpSpriteCache` or call `VDP_updateSprites`. Even `SPR_init()` (Sprite Engine) does not register a VBlank task to handle this automatically.

I converge on **A+D**:

1.  **Plan A (Strip + Manual Flush):** We must strip the 22 redundant `VDP_updateSprites(1, DMA)` calls—which are currently causing synchronous stalls—and replace them with a single `VDP_updateSprites(80, DMA_QUEUE)` at the end of the gameplay logic. This provides the "batching" efficiency I sought in B while ensuring the transfer actually occurs.
2.  **Plan D (HUD Gating):** This remains mandatory. Solving SAT lag is only half the battle; we must also eliminate the redundant `VDP_setTileMapXY` calls for the HUD to reclaim the VDP bandwidth necessary for a stable 60fps.

Converging on A+D respects SGDK’s architecture while finally addressing the root cause of VDP contention.
