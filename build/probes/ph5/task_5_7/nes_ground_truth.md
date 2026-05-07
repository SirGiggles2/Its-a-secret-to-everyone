# Task 5.7 — NES Ground Truth Dump (Push Blocks)

Verified 2026-05-07.

## NES Push-Block State Machine (Z_04.asm)

### `BlockPushDirections` (Z_04.asm:615-616)

```
BlockPushDirections:
    .BYTE $08, $04, $02, $01
```

Mapping (NES JoypadInput / ObjInputDir bits):
- `$08` = UP (N)
- `$04` = DOWN (S)
- `$02` = LEFT (W)
- `$01` = RIGHT (E)

### `UpdateBlock` jump table (Z_04.asm:618-625)

```
UpdateBlock:
    LDA ObjState, X
    AND #$03
    JSR TableJump
UpdateBlock_JumpTable:
    .ADDR UpdateBlock0Idle      ; state $00
    .ADDR UpdateBlock1Moving    ; state $01
    .ADDR UpdateBlock2Done      ; state $02
```

### `UpdateBlock0Idle` (Z_04.asm:627-718)

1. **RoomAllDead gate** (line 630): if there are monsters in the
   room, reset push timer and return.

2. **Alignment check** (line 632-655): Link's `ObjX` must equal the
   block's `ObjX` (Y register = $00, vertical alignment for N/S
   push), OR Link's `ObjY + 3` must equal the block's `ObjY` (Y =
   $02, horizontal alignment for W/E push). If neither, reset push
   timer.

3. **Direction selection** (line 663-685): from the signed delta:
   - `Y=$00, delta>0` (Link below) → BlockPushDirections[0] = `$08` = N
   - `Y=$00, delta<0` (Link above) → idx=1 → `$04` = S
   - `Y=$02, delta>0` (Link right) → idx=2 → `$02` = W
   - `Y=$02, delta<0` (Link left)  → idx=3 → `$01` = E

4. **Distance gate** (line 677): `|delta| < $11` (= 17 px = ~1
   metatile).

5. **Input direction match** (line 684): `ObjInputDir` MUST equal
   the projected direction. (This gates "you must press the right
   key for your relative position".)

6. **Push timer** (line 691-696): increment `ObjPushTimer, X`. When
   it reaches `$10` (= 16 frames), commit:
   - `ObjDir, X = ObjInputDir` (line 701)
   - `ObjState, X = 1` → MOVING (line 702)
   - Source tile cluster overwritten with `$74` (floor)
     via `ChangeTileObjTiles` (line 704-705).

### `UpdateBlock1Moving` (Z_04.asm:720-746)

```
UpdateBlock1Moving:
    LDA ObjDir, X
    STA $0F
    JSR MoveObject              ; advance ObjX/Y at MoveObject speed
    JSR DrawBlock
    LDA ObjGridOffset, X
    CMP #$10
    BEQ :+                      ; rolled +$10 (E or S)
    CMP #$F0                    ; or rolled -$10 unsigned (W or N)
    BNE UpdateBlock2Done
:
    LDA #$04
    STA Tune1Request            ; play "secret revealed" tune
    INC ReturnToBank4
    LDA #$B0
    JSR ChangeTileObjTiles      ; paint $B0 cluster at destination
    INC ObjState, X             ; -> state 2 (DONE)
    INC BlockPushComplete       ; global flag, $4CF (Variables.inc:137)
```

### `UpdateBlock2Done` (Z_04.asm:747-748)

No-op (RTS).

### Secret-trigger linkage (Z_05.asm:2463-2484)

```
CheckSecretTriggerBlockDoor:
    LDA BlockPushComplete
    BEQ ReturnFalse
    BNE TriggerShutters

CheckSecretTriggerBlockStairs:
    LDA BlockPushComplete
    BEQ ReturnFalse
    LSR
    BCC ReturnFalse              ; BlockPushComplete=2: already consumed
    INC BlockPushComplete        ; 1 -> 2 (latch consumed)
```

So `BlockPushComplete`:
- `0` = idle (no push yet)
- `1` = pushed once, secret not yet consumed
- `2` = secret consumed (latched, stays this way)

## NES per-room Block Object Position

### `FindAndCreatePushBlockObject` (Z_05.asm:5461-5514)

Decoded algorithm:

1. **Special case for room $21**: block at fixed `($40, $80)`
   (line 5472-5479). TODO comment in NES source asks where $21 is
   used.

2. **General case**: scan BG row `$A` (= playfield row 10) of the
   play area, columns 4 through 26, looking for the FIRST tile equal
   to `$B0`.
   - X register loop: starts at $08, max $34, step 4 → 12 column
     candidates.
   - Block X = `(X / 2) * 8` (line 5505-5508).
   - Block Y = `$90` (= 144 px, = play-area-relative Y for row $A).
   - ObjType = `$68` (BlockObj type).

So **per NES**: pushable block in a room = the first $B0 tile found
when scanning BG row 10 from left to right. Other $B0 occurrences in
the same room (other rows, or the same row to the right of the first
match) are STATIC decorative wall tiles, NOT BlockObj.

### `BlockPushComplete` RAM cell (Variables.inc:137)

```
BlockPushComplete := $4CF
```

Single byte, NOT per-room. NES game state tracks one active block
per game state (one room visit at a time). RoomRom needs per-room
storage since the player can leave and re-enter rooms.

## L1Q1 Pre-Plan Tier-A Resolution: Verified

For each L1Q1 room with $B0 occurrences, scan BG row 10 of the
captured `g_uw_room_nt[]` (RoomRom/src/uw_room_blob.c) for the
FIRST $B0. That metatile is the pushable block per NES.

L1Q1 $22 NT row 10 (= line 658 of uw_room_blob.c, blob row 10):

```
0xf6, 0xf5, 0xde, 0xde, 0x74, 0x76, 0x74, 0x76, 0x74, 0x76,
0x74, 0x76, 0xb0, 0xb2, 0x74, 0x76, 0x70, 0x72, 0x74, 0x76,
0xb0, 0xb2, 0x74, 0x76, 0x74, 0x76, 0x74, 0x76, 0xa4, 0xa6,
0x87, 0xf6
```

First `$B0` at BG col 12. Block coordinates:
- BG (12, 10) — top-left of 2×2 block metatile
- Metatile **(6, 5)**
- ObjX = `(8 * 4) = $20` … wait, NES `(X/2)*8`: NES X loop var starts
  at $08 and increments 4. The col index = X/2 → 4..26. NES uses the
  COLUMN TABLE not the BG col directly. Column 4 → BG col 4 (since
  column table is per BG col, 1 entry every 4 bytes for ptr+ptr).
  At first $B0 hit (BG col 12), NES X = $18 → `$18*2 = $30 = 48px`.
  Wait the formula: `block_x = (X/2)*8`. X=$18 → block_x = $C * 8 =
  `$60 = 96 px`. Hmm — that conflicts with BG col 12 = 12*8 = 96 px.
  YES. Confirmed: block_x=$60, BG col 12, metatile col 6.

Other L1Q1 rooms with $B0 in row 10 (informational; deferred):
- Need to scan each L1Q1 room's blob NT row 10. Slice-1 ships only
  the $22 row.

## Slice-1 manifest row

```
{ level=1, quest=1, room_id=$22,
  block_col_mt=6, block_row_mt=5,
  allowed_dirs=$0F,        /* all four — NES derives from Link pos */
  trigger_kind=1 }         /* stair */
```

`allowed_dirs = $0F` because NES `UpdateBlock0Idle` derives push
direction purely from Link's relative position (Z_04.asm:632-685),
not from a per-room attribute. Any side Link approaches from is
valid; the player MUST press the right key for that side per NES
rule (line 684).

`trigger_kind = 1` because L1Q1 $22 is a cellar source (Task 5.6
verified) and the NES secret linkage for cellar/stair rooms uses
`CheckSecretTriggerBlockStairs` (Z_05.asm:2471). RoomRom slice-1
doesn't gate stair detection on `BlockPushComplete` — the 5.6
coordinator unconditionally accepts stair tiles $70..$73 — but the
generated metadata records the trigger kind so a future
post-cellar-blob slice can wire the secret check.

## Mode-$10 / TargetMode parity note (inherited from 5.4)

Push-block does NOT trigger a mode change directly; it's a per-tick
object update inside the active gameplay mode. No TargetMode write.
Mode-$10 deferral from 5.4 inherits unchanged.
