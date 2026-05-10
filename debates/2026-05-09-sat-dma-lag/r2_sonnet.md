# Round 2 — Sonnet Rebuttal

## Addressing Gemini's hidden-dependency argument (steel-man first)

Gemini's strongest point: a single end-of-tick flush in `roomrom_debug_tick` creates a **hidden structural dependency** — if the tick exits early (guard clause, mode switch, error path), the flush is skipped, sprites freeze one frame. This is a real risk. Gemini is not wrong that a single mandatory call is more fragile than zero mandatory calls.

Steel-man accepted. Now the counter:

The dependency is **explicit, localized, and auditable.** One grep for `VDP_updateSprites` in the file finds it immediately. Compare to Plan B's dependency: the flush happens only if something was queued AND `PROCESS_DMA_TASK` is set in `VBlankProcess`. If that bit is ever cleared by unrelated SGDK init code, sprites silently freeze with no callsite to grep. Plan B trades a visible dependency for an invisible one baked into SGDK runtime state.

Moreover, the early-exit risk is controlled: `roomrom_debug_tick` is a flat loop body. Any early exit that skips the flush also skips gameplay mutation — no sprites changed, no stale SAT. The one-frame flicker scenario requires both (a) sprites mutated AND (b) flush skipped. That is a tighter failure mode than Gemini implies.

## Re-affirming Plan A is correct, Plan B is broken

SGDK source confirms Gemini's Plan B premise is false.

`vdp_spr.c:160-168` — `VDP_setSpriteFull` writes `vdpSpriteCache[]` only. No flush, no queue enqueue, no dirty flag set.

`sys.c:685-696` — `SYS_doVBlankProcessEx` calls `DMA_flushQueue()` only when `PROCESS_DMA_TASK` is set. `DMA_flushQueue` drains descriptors previously enqueued by `DMA_transfer(DMA_QUEUE, ...)`. Shadow SAT writes via `VDP_setSpriteFull` never enqueue a descriptor. **`SYS_doVBlankProcess` has no auto-flush path for dirty sprites.** This is not a reading of intent — the function body is 130 lines; there is no call to `VDP_updateSprites` anywhere in it (confirmed: grep `sys.c` for `updateSprites` returns zero hits inside `doVBlankProcess`).

Gemini's claim that "relying on `SYS_doVBlankProcess`" flushes the SAT is factually false. Plan B as described produces a frozen SAT.

`sys.c:901,914` shows SGDK itself calls `VDP_updateSprites(1, DMA_QUEUE)` explicitly in its own sprite engine flush — it does not rely on auto-flush either.

## Plan A hidden dependency: net verdict

Fragility acknowledged, not decisive. The fix: add a comment at the flush callsite and a `static_assert`-style guard in a future audit pass. That costs two lines, not a plan change.

## D timing

Same commit. HUD tilemap writes are active-display blocking VDP traffic. After A lands, `roomrom_debug_tick` recovers 5–9 DMA stalls but still bleeds ~15 `VDP_setTileMapXY` calls through the display window every frame. D is orthogonal, the `s_hud_dirty` flag is 3 lines, and deferring it risks the "good enough" drift Gemini correctly flagged as the "wait for follow-up fallacy" — ironic that Gemini argued this while advocating the wrong main plan.

---

**Final verdict: Plan A + D, same commit.**
