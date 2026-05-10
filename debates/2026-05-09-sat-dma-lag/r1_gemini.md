# Round 1 — Gemini Voice (advocate for B+D hybrid)

## Verdict: Hybrid B+D

I am advocating for **Hybrid B+D**. This is the only path that fulfills the "Best Long-Term Outcome" and "Genesis-native impl" mandates by leaning into the SGDK framework rather than fighting it.

## Why B+D Wins

1.  **Best Coding Practice (Plan B):** SGDK is designed to manage a shadow SAT. Calling `VDP_updateSprites(..., DMA)` inside setters is an architectural anti-pattern; it forces an immediate, blocking DMA that stalls the 68k during active display. By stripping these and relying on `SYS_doVBlankProcess`, we move the SAT update to the VBlank window where it belongs. This is the Genesis-native equivalent of the NES `$4014` DMA.
2.  **Maximal Efficiency (Plan D):** Fixing SAT lag is useless if we continue to thrash the VDP with 15+ `VDP_setTileMapXY` calls every frame for a static HUD. HUD dirty-gating is not a "secondary" fix; it is mandatory to reclaim the VDP bandwidth necessary for a stable 60fps.
3.  **NES Accuracy:** The NES doesn't update OAM mid-frame per-object; it prepares a buffer and flushes once. Plan B mirrors this perfectly.

## Why Others Fail

*   **Plan A (Strip + Manual Flush) is Brittle:** It transforms 22 "bad" calls into one "special" call that must be manually maintained. If `roomrom_debug_tick` logic branches or exits early, the SAT doesn't flush, leading to one-frame flickers. It's a "patch" that creates a hidden dependency.
*   **Plan C (Native Shadow) is Over-Engineering:** Bypassing SGDK's `vdpSprite` machinery is a maintenance trap. We would have to manually manage sprite link-pointers and ordering — logic SGDK already handles correctly. Plan C introduces "clever" code that violates the long-term maintainability rule for negligible gains over a properly configured SGDK flush.
*   **The "Wait for Follow-up" Fallacy for Plan D:** Shipping B without D is half a fix. The "DMA Lag" reported is a symptom of total VDP contention. Addressing only the SAT while leaving the HUD to spam the VDP DATA port is an incomplete engineering response.

## Implementation Details

*   **Same Commit:** Plan D must ship with B. They are twin pillars of the VDP optimization strategy.
*   **SGDK Fact:** `VDP_updateSprites` with `DMA` mode is a synchronous, blocking operation. In a tight gameplay loop with multiple calls, the cumulative overhead of setup, bus arbitration, and transfer per-call is what's killing the frame budget. Plan B moves this to a single, efficient DMA queue operation handled by the system's VBlank suite.

## Conclusion

Plan B+D is the only "senior engineer" move. It restores architectural sanity by using the platform's intended vertical-blanking patterns.
