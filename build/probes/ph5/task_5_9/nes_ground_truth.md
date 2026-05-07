# Task 5.9 — NES Ground Truth Dump (Keys/Map/Compass/Triforce)

Verified 2026-05-07.

## Inventory storage (Variables.inc + state header)

- `Items := $657` (Variables.inc:236) — 32-byte inventory array.
  Each byte is level-masked.
- Per-slot indices used in slice-1:
  - slot 16 = compass byte (`InvCompass` per per-quest split, but
    NES `room_has_compass()` reads `Items[16]`)
  - slot 17 = map byte
  - slot for keys + slot for triforce — derived from
    NES item id table (see below).
- `LevelMasks := $01, $02, $04, $08, $10, $20, $40, $80`
  (Z_07.asm:747-748). `has_X(level)` test: `Items[slot] & LevelMasks[level-1]`.

## Drained predicate calls (callable surface)

- `room_has_compass()` — `src/game/room/room_dispatch.c:597`.
  Reads `INVENTORY_VALUE(16) & LevelMasks[CUR_LEVEL-1]`.
- `room_has_map()` — `src/game/room/room_dispatch.c:603`. Reads
  `INVENTORY_VALUE(17)` similarly.
- `item_take_item(id)` — `src/game/items/item_dispatch.c:152`.
  **NOT called from RoomRom slice-1** (G3): externs not linked
  (`ItemIdToSlot`, `ItemIdToDescriptor`, `LevelMasks`,
  `SaveSlotToPaletteRowOffset`, `MenuPalettesTransferBuf`).
  RoomRom-local pickup wrapper writes `INVENTORY_VALUE(slot)` direct.

## Triforce mode-change conflict (G5)

`item_take_item($1B)` triforce branch sets `GAME_MODE = 18`
(end-level transition) — `src/game/items/item_dispatch.c:63`.
Slice-1 wrapper bypasses entirely; sets only the inventory bit
+ slice-1 stub state. No GAME_MODE write. Documented as Phase 6
deferral.

## Item-room placement (Z_05.asm:8169-8222)

Authoritative algorithm:

```
LDY RoomId
LDA LevelBlockAttrsE, Y
AND #$1F                ; Room item id (0..31)
CMP #$03
BNE :+
DEC ObjState+19         ; ID 3 = "no item" sentinel
:
STA RoomItemId

LDA LevelBlockAttrsF, Y
AND #$07                ; Secret trigger
CMP #$03
BEQ @Deactivate
CMP #$07
BNE :+
@Deactivate:
DEC ObjState+19         ; trigger 3=last boss / 7=foes-for-item
                        ; -> deactivate item until trigger fires.
:
LDA LevelBlockAttrsD, Y
AND #$40                ; Push block?
BEQ :+
JSR FindAndCreatePushBlockObject

JSR GetShortcutOrItemXY
@StoreLocation:
STA ObjX+19
STY ObjY+19

LDY RoomId
LDA LevelBlockAttrsE, Y
AND #$1F
CMP #$1B                ; Triforce piece
BNE :+
LDA ObjX+19
SEC
SBC #$08                ; Move triforce left 8 px
STA ObjX+19
:
RTS
```

`GetShortcutOrItemXYForRoom(room)` (Z_01.asm:4002-4020):

```
LDA LevelBlockAttrsF, Y
AND #$30                ; bits 4-5 = position index (0..3)
LSR x4                  ; idx = (AttrsF & $30) >> 4
TAY
LDA LevelInfo_ShortcutOrItemPosArray, Y
PHA                     ; pos_byte
AND #$0F
ASL x4                  ; Y_coord = (pos & $0F) << 4
TAY
PLA
AND #$F0                ; X_coord = pos & $F0
RTS
```

So per-room item position derives from:
- AttrsF[room] & $30 → index into 4-entry array
  `LevelInfo_ShortcutOrItemPosArray`
- pos_byte = array[index]
- X (px) = pos_byte & $F0 (top-left, hi-nibble × 16)
- Y (px) = (pos_byte & $0F) × 16 (top-left, lo-nibble × 16)
- If item == $1B (triforce): X -= 8.

Per [RoomRom/tools/uw_reachability.py:81](RoomRom/tools/uw_reachability.py:81):
`SHORTCUT_REL = 0x05` (offset relative to FoeCounts anchor within
LevelInfo block).

## L1Q1 item-room decode

For L1Q1 (LevelBlockUW1Q1 base $0000, FoeCounts offset $20):
- AttrsE base = $0200
- AttrsF base = $0280
- LevelInfo L1 base = $0C00
- LevelInfo L1 FoeCounts at $0C00 + $20 = $0C20
- ShortcutOrItemPosArray at $0C25 (4 bytes)

Per-room item: only rooms where `AttrsE[room] & $1F != 3` AND not
deactivated by AttrsF & $07 trigger 3/7 are visible-at-spawn.

Decoded set TBD via Python in generator.

## Mode_EndLevel ID (G5)

NES end-level transition: GAME_MODE = $12 (= 18 decimal) per
src/game/items/item_dispatch.c:63 (drained from NES). Slice-1
bypasses (would crash without end-level renderer).

## RoomRom slice-1 implementation

- INVENTORY_VALUE(slot) macro from item_state.h:26 reads
  `RAM($0657 + slot)`. Within RoomRom 2 KB nes_ram bounds.
- HUD render reads `room_has_map()` / `room_has_compass()` via
  drained dispatch (safe — read $0657+slot).
- Item pickup wrapper sets `INVENTORY_VALUE(slot) |= LevelMask`
  directly (no `item_take_item()` call).
- Triforce wrapper sets InvTriforce bit; flips
  `s_triforce_pickup_active`; paints overlay; freezes input. No
  GAME_MODE write.

## Slice-1 minimum verification

L1Q1 has at least:
- Compass room (per NES vanilla wiki, L1 compass = $42 typically;
  TBD from generator).
- Map room (L1 map = $52 typically).
- Triforce room ($36 — boss room per uw_level1_quest1_rooms.json:6).

User-test path (auto-probe will substitute if user away):
- TELEPORT to compass/map room → walk over item → HUD reveal.
- Walk to $36 → step on triforce → stub overlay fires.
- Debug chord `Y+Z+START` toggles inventory bits for HUD-only
  verification without pickup mechanism.
