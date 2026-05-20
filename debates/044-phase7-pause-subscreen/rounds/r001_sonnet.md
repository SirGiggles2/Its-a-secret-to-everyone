# r001 — Pragmatic Implementer (Sonnet) — AGAINST Phase 7 PX0-PX9

## PX7 is already dead — read your own init_video()

The plan recommends "Plane B + priority swap" for VScroll. Look at
`RoomRom/src/main.c:487`:

```c
VDP_setBGBAddress(0xC000u);  // BG_B intentionally shares BG_A's table
```

BG_A and BG_B are **aliased to the same nametable**. PX7 cannot silently
slide the inventory into Plane B — there is no independent Plane B. Making
Plane B distinct requires relocating one nametable, recomputing stride,
and touching the scroll mode — that's a PR-2 Option G, not a Phase 7 task.
Estimate blows up from 3h to 12h before writing a single inventory tile.

## PX9 "all diff counts = 0" is a false goal

NES OAM coordinates are raw pixel values. Genesis sprite X/Y require
+128 and +128 offsets per VDP spec. Byte-for-byte sprite position match
is physically impossible. PX9 as written either (a) silently excludes
sprite diffs and isn't actually "pixel-exact," or (b) blocks forever. The
plan needs to define exactly which byte streams are being diffed and what
coordinate transform is applied. Gemini flagged 4 px/frame vs 3 px/frame
— that's also a PX9 blocker unless the scroll math is fixed in PX7 first.

## PX4 sequencing error: table archaeology before capture

PX4 ports `SubmenuTransferBufSelectors` before PX1 has run a single NES
capture. The NES inline tile bytes map to a specific CHR bank loaded
**only during pause**. If the bg_sparse_tile_lut doesn't have those tiles
covered (the LUT was built from gameplay CHR, not pause-mode CHR), you'll
port a blob that produces BLANK_TILE for half the cells. Run PX1 first,
diff against the LUT, identify missing tiles — then decide if PX4 is even
needed or if a targeted atlas fill is cheaper.

## Missing task: SAT link chain invalidation on exit

`inventory_subscreen_exit()` clears only the cursor SAT slot. During
SCROLL_ACTIVE, `draw_item_sprites()` wrote N item slots into the live SAT
with `link = s_next_sat_slot + 1`. On exit, those slots remain with
stale link values. On the very next gameplay frame, the sprite renderer
chains through those slots and renders garbage. The plan has no PXN for
SAT cleanup on exit. This will appear as one-frame sprite corruption
after every inventory close — invisible in PX9's per-frame diff if the
capture ends before exit completes.

## 70% match at 20% effort looks like this

1. PX1 NES capture + PX2 Genesis baseline (non-negotiable, ~3h).
2. Replace `write_inventory_row()` ASCII text with NES PRG tile bytes —
   no new atlas tiles needed if the BG bank is already loaded (~2h).
3. Replace sprite X positions with `SubmenuItemXs` table values + fixed
   +128 Genesis offset (~1h).
4. CRAM swap (PX8) — single CRAM write on enter/exit, already wired in
   `inventory_subscreen_enter()` (~1h).

That's ~7h for tilemap parity + correct item positions + correct palette.
Result: visually identical to NES in every frame that isn't the scroll
transition. Skip PX7 (Plane B can't be used) and PX3 (custom diff
engine). PX9 runs with scroll rows excluded from the diff; call that
"phase visual parity" not "pixel-exact" and re-evaluate PX7 if the user
still needs scroll match after seeing the result.
