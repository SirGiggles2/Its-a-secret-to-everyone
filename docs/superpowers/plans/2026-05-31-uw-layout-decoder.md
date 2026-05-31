# Plan — UW room LAYOUT DECODER (permanent: every dungeon room renders from block data)

**Goal:** Replace the capture-dependent UW room blob with a NES-faithful
`LayoutUWFloor` decoder so EVERY underworld room (incl. all boss rooms +
uncaptured rooms) renders its correct BG from the shared LevelBlock data — no
per-room NES capture, no per-level manifest dependency. This is the long-term
fix for the residual "uncaptured boss room renders black" gap (e.g. L2 $05
Dodongo, L9 $17 Ganon).

**Why now:** boss sprites + palette are fixed + general (committed); boss-room
BG renders only for rooms the Phase-B capture happened to record. The decoder
makes BG render for ALL rooms, permanently.

## Foundation already in place (reuse, do NOT rebuild)
- **Decoder logic EXISTS in python:** `tools/builder/extract_uw_collision.py`
  already parses `RoomLayoutsUW` / `ColumnHeapUW0-9` / `PrimarySquaresUW` from
  `data/rooms/dungeons.c` and walks them (`decode_heap_column`,
  `build_room_grid`) to a 12×7 primary-square grid. `unique_room_id =
  LevelBlockAttrsD[room]&0x3F` (= NES GetUniqueRoomId). It currently maps each
  primary square -> a 2-bit collision class; we instead need the tiles.
- **NES authority:** Z_05.asm `LayoutUWFloor`(5307) + `WriteSquareUW`(5413):
  - room = 12 encoded cols × 7 encoded square-rows; play-area top-left NT
    addr $658C; each square = 2×2 tiles; advance +2 per square down a column,
    +$1E to next column.
  - `PrimarySquaresUW = {B0,74,94,B4,70,68,F4,24}`.
  - WriteSquareUW: Type1 (primary $70..$F2): TL=p, BL=p+1, TR=p+2, BR=p+3
    (the +$15 NT row stride between the two rows of the square). Type2 (else):
    all 4 tiles = primary.
- **Gen blob format:** `uw_room_blob.c` per-room `nt[row*ROOMROM_UW_BLOB_COLS+col]`;
  `uw_render.c blit_blob(idx)` blits it to plane A; `fill_plane_a` falls to
  `draw_placeholder` when `find_blob_entry` misses (the black/placeholder rooms).

## Steps (each verifiable)
1. **Generator** `tools/builder/gen_uw_room_tiles.py` — reuse extract_uw_collision's
   parse + `decode_heap_column`; for every (block, room slot used by any level)
   emit the full tile nametable: 12×7 squares → 2×2 `WriteSquareUW` expansion →
   the `ROOMROM_UW_BLOB_COLS`-wide grid with the same border/offset the captured
   blob uses. Output a candidate blob (all rooms).
2. **VERIFY (the gate, offline, no ROM):** byte-diff the generated nametable
   vs the existing captured `uw_room_blob` for ALL 171 captured rooms. They MUST
   be byte-identical (proves the decoder reproduces NES exactly). Fix the
   expansion/offset until 171/171 match. (This is the RULE-ZERO/V1 gate — do not
   wire until the generator matches the captured truth.)
3. **Regen** the full `uw_room_blob.c` from the generator (all rooms, all 4
   blocks) — now includes every boss room + every uncaptured room.
4. **Wire:** `find_blob_entry` already covers all rooms once the blob is
   complete; the sibling fallback becomes a no-op (kept as defense). Drop
   `draw_placeholder` reliance for real rooms.
5. **Verify live:** rebuild; BG sweep L1-L9 still 171/171 byte-exact (regression
   gate); boss rooms (L2 $05, L9 $17, …) now render their BG; Aquamentus +
   other bosses render room + sprites + palette.

## DERIVED so far (2026-05-31, tools/builder/derive_uw_nt.py)
- Decoder VERIFIED: decoding room $73 (uid=62 from LBA_D&0x3F) via
  extract_uw_collision's `decode_heap_column` yields a 12-col × 7-square grid
  whose tile families ($24/$68/$74/$94/$B4/$F4) all appear in the real NES
  CIRAM — the decode half is correct.
- WriteSquareUW addressing (from Z_05.asm pointer math): with play-area ptr P,
  TL=P+0, BL=P+1, TR=P+$16(22), BR=P+$17(23) -> the play-area buffer is
  COLUMN-MAJOR with 22 rows/col (+1 = down a row, +22 = right a col = the 22
  play rows). LayoutUWFloor: P0=$658C; +2 per square down a column; +$1E after
  7 squares -> column stride = 14+$1E = $2C (44). So square[c][r] TL buffer
  offset = ($658C-$6500) + c*$2C + r*2 = $8C + c*$2C + r*2.
- OPEN (final calibration): naive 2x2 placement scored only ~30% vs CIRAM
  because (a) $74 floor is ubiquitous (weak signal) and (b) the base $8C +
  column-order needs matching against the CAPTURED blob (row-major 22x32, what
  blit_blob consumes), not CIRAM. NEXT: emulate the exact P arithmetic into a
  32x22 column-major buffer, index blob[row][col]=buffer[col*22+row], and
  byte-diff vs the captured uw_room_blob nt for $73 (+ a few) until 0-diff;
  THEN sweep all 171 captured rooms (Gate A). Distinctive-tile rooms (arches
  $94/$B4, stairs $68) give a stronger alignment signal than $74.

## Verification
- Gate A (offline): generated nt == captured nt for all 171 rooms (0 byte diff).
- Gate B (live): `run_dungeon_sweep.py` L1-L9 still 171/171; spot-probe boss
  rooms render (no black, no placeholder).
- RULE V1: gates are byte-diffs, not screenshots.

## Status of the boss work this session (committed, verified)
- BUG1 BG sibling-fallback (uw_render.c) — boss rooms captured under a sibling
  render. BUG2 SAT-count publish (enemy_render.c) — full 6-sprite boss. Boss
  palette: per-level SPR sub-pal 3 -> PAL2 (uw_render.c) — NES-green boss.
- L1 Aquamentus verified: room BG + 6 green sprites. L2 Dodongo: sprites+palette
  OK, BG black (uncaptured) — THIS plan fixes that class permanently.
