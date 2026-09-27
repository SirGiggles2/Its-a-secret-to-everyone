# T-134 Cave entry: NES black load, no Link fighting the stairs

Found while checking T-125 cave-load lag (`t120_cave_person`).

## NES (captured, t120)

f64 mode $10 (stairs), Link Y $4E -> $5D at 1 px / 4 frames; f124 mode
$0B; f126 (submode 2) playfield black, HUD stays; black while the cave is
laid out; f155 (submode 8) cave shown at once, Link at $DD walking up.

## Genesis before

1. Holding a direction during the descent moved Link (the movement code ran
   during cave_fade): with Up held Link went $4D -> $54, snapped back to $4F,
   ... (framebuffer f110-f124: ~90 px off, Link visibly above the NES Link).
2. The overworld stayed on screen through the load hold, then the cave was
   painted over 9 visible frames (write_tile_at, ~107 instructions a tile,
   one 9-frame tick).

## Fix

- Input is read (NES $F8/$FA) but not acted on while cave_fade runs; $3F8
  keeps its value (NES sets it only in mode 5).
- `on_load_blank(stage)`: stage 0 at the descent end hides Link (sprite
  writes reach VRAM at the next VBlank), stage 1 on the next tick blanks the
  play area; both show on the NES frame.
- OW/cave column renderer split into compute / store / write; columns are
  streamed with one VDP address each (all OW room draws). The cave is
  computed during the black hold (2 columns a tick, RAM only) and the swap
  queues its 22 plane rows for the VBlank DMA: it appears in one frame.

## Evidence (t120_cave_person, framebuffer vs NES, colour-mapped)

- descent f70/f90/f110/f120/f124: 0 px each (f125: 6 px, last step).
- f126 black playfield: 0 px. Genesis lag frames in t120: 0 (was 9).
- cave first frame (gen f146 vs nes f156, both Link Y $DB): 0 px.
- Genesis shows the cave 10 frames earlier than NES (faster load).

Suite `t134a`: lag GEN 201 / NES 369 (T-125: 277). Traces differ from the
first OW room scroll on because that scroll no longer drops NES-like lag
frames and the harness scripts inputs by video frame: with lag frames
removed from both traces, hud_marker is identical old vs new build for 228
game ticks (harness fix tracked as T-136).
