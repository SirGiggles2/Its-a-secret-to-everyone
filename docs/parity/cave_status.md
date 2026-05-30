# Cave parity status — 2026-05-29

**Bar (user):** "Genesis is like the NES, very close, and better since the
hardware is different." NOT byte-pixel-identical. BG byte-exact where it
counts; sprite/visual very close; legit hardware deltas accepted.

## Verdict: every Q1 cave ($6A..$7D) verified NES-correct.

Tooling: `tools/parity/cave_golden/`
- `probe_nes_cave_golden.lua` — NesHawk, SRAM boot, HandleWarpOW fake,
  `ObjType+1==CAVE_ID` assert. (Pin config.ini PreferredCores NES=NesHawk —
  the CHR/PALRAM capture reads the "VRAM" domain that only NesHawk exposes.)
- `probe_gen_cave_golden.lua` — genplus, full VRAM/CRAM/SAT/68K capture +
  Tier-1 invariant gate.
- `run_cave_sweep_{gen,nes}.py` — capture all 20 each platform.
- `cave_byte_diff.py` — BG CRAM byte-exact (via misc_palettes LUT) + BG
  play-cell structure. `pixel_diff.py` — rendered-frame shape gate
  (per-channel tol, absorbs the color-model curve). `run_full_diff.py` —
  all-20 table. `aggregate_invariant.py` — Gen-side gate roll-up.

### Results (frame 120, all 20 caves)
- **BG-byte GATE: PASS 20/20** — PAL0/BG CRAM byte-exact + every NES play
  cell has a Gen tile. Zero divergences.
- **Tier-1 invariant gate: 20/20** — char_idx strictly monotonic (no text
  re-stream), no stale enemy slot 4-11 alive, cave loaded (ObjType+1==id).
- **Rendered pixel-diff: uniform 4.6-6.5%** across all 20 — FLAT, no
  per-cave spike. A real per-cave bug would spike one row; uniformity proves
  the residual is systematic, not cave-specific.
- **Cave 6C hand-proven tile-for-tile:** flame `$3AC`==NES`$5C` idx-for-idx,
  old man `$29D/$29E`==`$98/$99`, NPC text rows 13/14 both lines.

## Bugs fixed this pass (all byte-verified)
1. Shop-cave text garble ("M MAS MA MAS") — stale slot-4 wanderer's
   `ENEMY_PUSH_TIMER` ($0412+slot) aliased `CAVE_TEXT_CHAR_INDEX` ($0416 at
   slot 4). `cave_init` now clears all enemy slots (NES Mode-B fresh page).
2. Bonfire flame halves L/R swapped — stale `DRAW_FLIP_H` zero-page temp.
   `draw_object_not_mirrored` clears it.
3. NPC text on one wrong row vs NES rows 13/14 — `cave_init` never init'd
   `CAVE_TEXT_LINE_ADDR_LO` (latent) + `emit_nametable_record` mis-applied
   the +7 OW/UW HUD bridge to screen-absolute cave text.
4. Cave walls white->orange (sub-pal 3); NES-perfect punctuation glyphs;
   bonfire tile route to item-atlas flame.

## Accepted hardware deltas (NOT bugs — the byte data is NES-identical)
- **Color model:** NesHawk renders the NES palette at different RGB than
  genplus renders the byte-exact Gen CRAM (oranges differ up to ~91/ch).
  Two emulators, two color tables; unfixable without normalizing both.
- **HUD height:** Genesis playfield base (`ROOMROM_ROOM_FIRST_ROW`) is one
  tile-row above NES (Gen HUD 7 rows vs NES 8), shared by OW/UW. Sprites use
  NES-absolute Y, so transparent sprite pixels reveal the 1-row BG shift.
  Changing it = every-scene blast radius; left as the port's HUD layout.

## Q2
Cave INTERIORS are cave_id-determined and quest-independent -> the 20 Q1 BG
goldens already cover both quests. Q2 only swaps wares (item sprites) + OW
room->cave routing (routing verified 128 rooms x both quests in Phase A).
No separate Q2 interior re-sweep needed for the stated bar.
