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

## CRACKED (2026-05-31) — decoder verified byte-exact, RULE ZERO

The LayoutUWFloor decode is SOLVED + byte-verified against the captured blob
(ground truth), no ROM launch. Tools: `tools/builder/match_uw_nt.py` (single
room align) + `tools/builder/verify_uid_offset.py` (all-blocks sweep).

**Two bugs were blocking it:**
1. `extract_uw_collision.decode_heap_column` does `pos += 1` past the high-bit
   COLUMN-MARKER byte before the row loop — but NES `@FoundColumn` sets `$04`
   AT the marker and `@LoopSquareRow` reads it as ROW 0. Off-by-one: the
   shipping decoder drops the first row descriptor. Corrected decoder backs
   `pos -= 1` so the marker IS row 0.
2. The unique_room_id that indexes `RoomLayoutsUW` is NOT
   `LBA_D[room]&0x3F` straight from dungeons.c — it needs **+22**, and LBA_D
   must be read from the CORRECT per-(block,quest) LevelBlock sub-table D
   (`LevelBlockUW{1|2}Q{1|2}` +0x180), not a flat `data[0x180+room]`.

**The proven rule (UNANIMOUS, delta=22 across all 4 blocks):**
```
uid = (data[LevelBlock{UW1|UW2}Q{1|2}.off + 0x180 + room] & 0x3F) + 22
cols[c] = decode_marker_inclusive(ColumnHeapUW{hi}, lo)  for desc in RoomLayoutsUW[uid*12 : +12]
square[c][r] (c 0..11, r 0..6), WriteSquareUW expand:
  Type1 ($70<=p<$F3): TL=p, BL(+1 down)=p+1, TR(+$16 right)=p+2, BR=p+3
  Type2: all four = p
place into 22x32 blob: corner (dx,dy) -> nt[(4+2r+dy)*32 + (4+2c+dx)]
```
**Verified:** exact floor match 202/202 (UW1Q1), 164/164 (UW1Q2), 112/112
(UW2Q1), 108/108 (UW2Q2) = 586/586 rooms whose floor has no door/stair
intrusion. The remaining 40 captured rooms match the floor but have
doors/stairs that intrude the 4..27 x 4..17 interior — those need the door/
stair OVERLAY layer (next), not a different uid (still du+22).

**Remaining for a full byte-exact generator (Gate A vs all 626 blobs):**
- WALL/border template (rows 0-3,18-21 + cols 0-3,28-31): constant per block;
  lift from a captured sibling or port the room-frame writer.
- DOOR/stair overlay: per-room door type from LevelBlock sub-tables ->
  port WriteDoor/stair tiles into the wall bands + (for the 40) interior.
- Then regen the blob INCLUDING uncaptured boss rooms; black rooms gone.

## COMPLETE GENERATOR (2026-05-31) — gen_uw_room_tiles.py, Gate A passed

Every UW room nt is now generated byte-exact from NES data tables, no capture:
```
room_nt = GLOBAL_FRAME  (+)  DECODED_FLOOR(uid)  (+)  DOOR_OVERLAYS(block,room)
```
- **GLOBAL_FRAME**: the non-floor/non-door cells are a SINGLE constant across all
  636 captured rooms AND both blocks (verified: UW1≡UW2, 0 diffs). Lift from any room.
- **DECODED_FLOOR**: LayoutUWFloor, uid = per-block LevelBlockUW{1,2}Q{1,2}[+0x180+
  room]&0x3F + 22, marker-inclusive heap decode reading the CONTIGUOUS ColumnHeapUW
  region (0x1820..0x18FE) so columns crossing a heap boundary decode like the NES
  pointer (fixing 50 false "underruns"). Fills rows4-17 cols4-27 (24x14).
- **DOOR_OVERLAYS**: 4 regions (N rows1-3/S rows18-20 cols14-17; W cols1-3/E cols28-30
  rows9-12). Door type per room = (A>>2=S, A>>5=N, B>>2=E, B>>5=W) from LevelBlock
  sub-tables A(+0)/B(+0x80). Per (block,region,type) per-cell MAJORITY tile from
  captures = the resting (closed) load-state.

**Gate A (offline, vs all 636 captured blobs):** 538/636 byte-exact;
**0 FLOOR-region mismatches, 0 frame mismatches, 0 underruns**. The 98 non-exact
are DOOR-STATE-ONLY (2-8 bytes each; captured tile values $88-$95 = OPEN-doorway
passage tiles) — the blob snapshotted some doors OPEN; the generator draws the
resting/closed load-state. Generator is byte-exact for the STATIC room layout.

**The 4 black boss rooms (now fixed by the generator):** L6 $1C (uid28), L7 $2A
(uid26), L8 $3C (uid27), L9 $42 (uid62) were black because captured only under a
DIFFERENT block's level (cross-block, sibling fallback can't reach) or not at all
(L8 $3C). All 4 now compose to full 704/704-tile rooms (floor uid-correct via
same-uid sibling validation; frame constant; resting doors).

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
