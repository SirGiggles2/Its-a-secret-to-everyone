# Round 1 — Sonnet Voice (pragmatic, evidence-driven)

## Verdict: Plan A wins. B is plausible but wrong. C is a liability.

---

### The actual bug, stated precisely

`VDP_updateSprites(N, DMA)` calls `DMA_transfer(DMA, ...)` — see
`sgdk/src/vdp_spr.c:233`. `DMA` mode (not `DMA_QUEUE`) means
**synchronous, blocking CPU-stall transfer**, not queued. The M68K spins on
`GET_VDP_STATUS(VDP_DMABUSY_FLAG)` (or equivalent bus arbitration) until
the VDP DMA engine finishes. 5–9 of these per frame = 5–9 full DMA stalls
inside the active-display window = CPU time eaten alive, frame budget blown.

`roomrom_sprites.c` confirms: every setter terminates with
`VDP_updateSprites(N, DMA)`. Lines 247, 260, 347, 362, 391, 447, 459, 502,
513, 529, 540, 583, 594, 615, 626, 671, 682, 722, 731. That is 19 confirmed
blocking DMA callsites in this file alone.

---

### Plan A: Strip + single `DMA_QUEUE` flush

**This is the correct Genesis-native equivalent of NES OAM DMA.**

NES model: CPU writes sprites into $0200–$02FF (shadow buffer), issues one
`STA $4014` = one OAM DMA per VBlank. Nothing happens mid-frame.

Plan A maps exactly: `VDP_setSpriteFull` = shadow-write into
`vdpSpriteCache[]` (pure RAM, `vdp_spr.c:161–168`, zero bus cost). One
`VDP_updateSprites(MAX_SLOT, DMA_QUEUE)` at tick end enqueues into the DMA
queue. `SYS_doVBlankProcess()` (`sys.c:685–693`) flushes the queue during
the VBlank window via `DMA_flushQueue()` only when `PROCESS_DMA_TASK` is
set. Result: **one SAT DMA per VBlank, inside VBlank, no mid-frame stall.**
This is the correct answer.

Mechanics:
- `DMA_QUEUE` → `DMA_transfer(DMA_QUEUE, ...)` → enqueues descriptor, no
  immediate bus access.
- `DMA_flushQueue()` in `SYS_doVBlankProcessEx` fires after `VDP_waitVBlank`
  confirms we are in the blank window.
- The `num` argument to the final flush is `MAX_USED_SLOT` (highest active
  slot index + 1), not a hardcoded 22. `highestVDPSpriteIndex` tracks this.

The change is mechanical: grep all 22 `VDP_updateSprites` callsites,
delete them, add one call at the bottom of `roomrom_debug_tick`. No new
files, no new abstractions, no SGDK internals bypassed.

---

### Plan B: "B is plausible but wrong"

B claims `SYS_doVBlankProcess` auto-flushes the shadow SAT. It does not.
Reading `sys.c:679–708`: `PROCESS_DMA_TASK` flushes `DMA_flushQueue()`, but
that only fires if something has been *queued*. Shadow SAT writes via
`VDP_setSpriteFull` do not enqueue anything — they are RAM writes.
`SYS_doVBlankProcess` has **no code path that automatically calls
`VDP_updateSprites`**. B's premise is false. If you strip all flush calls
and add nothing, the SAT in VRAM never updates. Sprites freeze.

B would only work if SGDK had a "dirty shadow SAT" auto-flush hook.
It does not (v2.11, `sys.c` is the entire `doVBlankProcess` — no SAT
section exists). B is a latent frame-corruption bug waiting to surface.

---

### Plan C: Roll your own SAT shadow buffer

Hard no. SGDK already owns `vdpSpriteCache` (global, `vdp_spr.c:14`). A
second shadow creates two sources of truth for VRAM SAT. The constraint
document says it explicitly: *"Single-writer SGDK SAT machinery; mixing C
with manual DMA risks tearing."* This is true. Any `VDP_setSpriteFull` call
from any SGDK subsystem (frame-load cursor at `sys.c:762–787`, sprite
engine if ever enabled) will write `vdpSpriteCache` but not your buffer.
You will get mysterious one-frame ghosts exactly when CPU load peaks — the
hardest class of bug to reproduce. C also requires audit of every future
SGDK callsite. This is not "closest to NES OAM DMA", it is closest to NES
OAM corruption.

C also violates best coding practice: don't fork a subsystem you don't own
when the owner already exposes the correct API (`DMA_QUEUE`).

---

### HUD dirty-gate (D)

**Same commit.** Here is why: `roomrom_hud_refresh_dynamic` is a blocking
`VDP_setTileMapXY` loop (~15 CTRL/DATA writes). These are *active-display*
register pokes — they fire every tick regardless of DMA queue state. At
~99% skip rate the budget recovery is real and immediate, and the `s_hud_dirty`
flag is a 3-line add. If D ships as a follow-up it will drift because the
tick cadence will feel "fixed enough" after A lands. Commit A+D together;
the dirty-gate is not risky and its cost is zero.

---

### Summary

| Plan | VRAM update model | Mid-frame stall? | Owns shadow? | Verdict |
|------|------------------|-----------------|-------------|---------|
| A    | DMA_QUEUE → VBlank flush | No | Yes (SGDK) | **Win** |
| B    | Shadow-write, no flush | Never flushes | N/A | Broken |
| C    | Manual DMA, second buffer | One per VBlank | No (forked) | Liability |

Plan A. Same commit as D. Ship it.
