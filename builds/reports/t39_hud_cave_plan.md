# T39 Plan — Post-Cave-Exit HUD / BG Corruption

## User-visible symptom

Live play report: "the bg sprites in the cave. They're way off."
Confirmed via Gen cave-capture PNG (`builds/reports/t36_cave_gen_capture.png`)
at the end of the T36 scenario (post-cave-exit, back on overworld):

- Top HUD strip: replaced by a repeating white/brown stripe pattern
  instead of `X0 / B A / LIFE` indicators + rupee + key count.
- Middle of screen: residual cave textbox text (`HENGEKBNK TV…`)
  still painted into Plane A over the overworld field.
- Forest/field tiles below the corruption: rendering correctly.

NES reference at the same scenario point
(`builds/reports/t36_cave_nes_capture.png`) shows clean overworld
HUD + Link + cave entrance, no residual text.

## Parity state

`tools/compare_t36_cave_parity.py` against the current build:

```
T36_NES_CAPTURE_OK         PASS
T36_GEN_CAPTURE_OK         PASS
T36_NO_GEN_EXCEPTION       PASS
T36_BASELINE_PARITY        PASS
T36_WALK_TO_STAIR          PASS
T36_CAVE_ENTER_TRIGGERED   PASS
T36_CAVE_INTERIOR_MATCH    FAIL  (1-frame sub=7 lag, Stage L/M parked)
T36_CAVE_EXIT_TRIGGERED    PASS
T36_ROUND_TRIP_READY       PASS  (final state matches NES)
```

So memory state after exit matches NES exactly — this is a **pure
rendering-bridge divergence**, not a game-logic bug.

## Mechanism candidates

Ranked by likelihood based on what the corruption looks like:

1. **Plane A not repainted on cave→overworld transition.**  The
   cave interior writes Plane A tiles (walls / floor / textbox).
   On exit, the game is expected to repaint Plane A with overworld
   tiles.  If our transfer-interpreter or nametable-cache bridge
   misses the repaint command, stale cave Plane A survives.

2. **`_ppu_write_0` rebuild using stale NT_CACHE.**  When PPUCTRL
   bit 4 toggles (overworld BG pattern table = $0000, cave BG =
   $1000), `_ppu_write_0` rebuilds all 960 Plane A tile words from
   `NT_CACHE`.  If NT_CACHE has cave tile indices baked in at exit
   time (because the repaint went to somewhere else, or arrived via
   a transfer buffer path that didn't update the cache), the rebuild
   produces garbage.

3. **HUD-specific path bypass.**  Zelda renders the top status bar
   via a per-frame DMA slot (DynTileBuf + transfer interpreter).
   If cave-enter/exit flushes DynTileBuf asymmetrically on Gen, the
   HUD may not have its tiles refreshed for a transient window.

4. **CHR bank dirty.**  Cave uses different CHR.  Sprite/BG pattern
   VRAM tiles 0-255 might have cave CHR still loaded after exit, so
   even with correct nametable indices the glyphs drawn are cave
   glyphs.  The HUD stripe pattern would be consistent with this.

## Evidence needed before building

1. **In-cave screenshot.**  Current Gen PNG is post-exit only.
   Modify `bizhawk_t36_cave_gen_capture.lua` to take screenshots at
   three scenario timestamps: pre-cave (t=100), in-cave (t=400), and
   post-exit (t=800).  Compare all three to NES counterparts.

2. **NT_CACHE diff.**  Dump `NT_CACHE_BASE` (960 bytes) before
   cave enter and after cave exit.  Check whether the post-exit
   cache matches the expected overworld tile layout for room $77.

3. **VDP VRAM diff.**  Dump CHR tile VRAM around slots 0-255 before
   cave and after exit.  Confirm whether overworld CHR was restored
   to the same slots.

## Recommended build phase (only after evidence)

If (1) — Plane A not repainted: fix the transfer-interpreter path
that handles room-reload on mode transition.

If (2) — NT_CACHE stale: instrument `_ppu_write_7` nametable-write
path to confirm cache updates land for overworld repaint writes.

If (3) — HUD DMA slot: fix DynTileBuf handling across mode $0B.

If (4) — CHR slots still cave: fix CHR-reload on exit (likely the
same transfer-interpreter plumbing as (1)).

## Scope / milestone

Belongs to T39 (HUD render) in `docs/SPEC.md` — currently `Pending`.
Overlaps with the T35 Plane-A rendering story (resolved for static
rooms in `c7325af2`) and the cave-specific CHR/pattern switching
around MMC1 PRG banking.  The Stage K MMC1-auto-refresh disproof
(`builds/reports/t36_stage_k_mmc1_disproven.md`) rules out the PRG
bank window as a cause — this is a separate path.

## Deliberately not attempted this session

- Do not re-try MMC1 auto-refresh (disproven twice, /whatnext rule).
- Do not touch cave sub=7 handler (Stage L/M disproven; 1-frame lag
  is independent of the rendering issue).
- Do not modify transpiled cave code blindly — the memory state is
  correct, the bug is on the rendering bridge side.

## Handoff

Plan-only artifact.  Next session should:

1. Execute the three-screenshot diff to classify which mechanism
   is active (1 vs 2 vs 3 vs 4).
2. Commit evidence as `t39_stage_a_render_classification.md`.
3. Enter Build phase only after the mechanism is isolated.
