# Task 5.8 — NES Ground Truth Dump (Dark Rooms)

Verified 2026-05-07.

## NES Dark Room Predicate (Z_05.asm)

### `IsDarkRoom_Bank5` (Z_05.asm:7795-7801)

```
; Y: room ID
; Returns:
;   A: $80 if dark, else 0
IsDarkRoom_Bank5:
    LDA CurLevel
    BEQ :+              ; level 0 (overworld) -> not dark
    LDA LevelBlockAttrsE, Y
    AND #$80            ; bit 7 = dark flag
:
    RTS
```

**Authoritative bit: AttrsE & $80** (bit 7).

`LevelBlockAttrsE` table base per Variables.inc:328 = `$6A7E`
(SRAM-relative). 128 bytes per active LevelBlock; level switch
re-points the active block.

### Drained C — `room_is_dark_room` (src/game/room/room_dispatch.c:75)

```c
unsigned char room_is_dark_room(unsigned int col)
{
    if (CUR_LEVEL == 0) return 0;
    return nes_ram[NES_SRAM_BASE + 0x0A7E + col] & 0x80;
}
```

Confirms NES rule. Reads `nes_ram[$0A7E + col]` — that's the
RoomRom-level offset into the active LevelBlockAttrsE table (NES
SRAM offset $0A7E maps to LevelBlockAttrsE at $6A7E in the full
$6000-base address space; RoomRom drops the base-offset).

**G1 constraint**: RoomRom standalone has 2 KB nes_ram
(roomrom_nes_ram[0x800]); $0A7E (= 2686) is OUT OF BOUNDS.
Calling `room_is_dark_room()` from RoomRom runtime will read
garbage memory or crash. RoomRom MUST use the generated table
directly. Dispatch is generator-time only.

## NES Candle (Z_07.asm + Z_05.asm)

### `WieldCandle` import (Z_07.asm:80, Z_05.asm:42)

Implementation lives in bank 5 (Z_05.asm); Z_07 dispatcher imports.

### `UsedCandle` flag (Z_07.asm:3522-3530)

Per-room single-byte flag. Set when candle fired in current room
(reveals dark mask + spawns fire projectile). Reset on room enter.

```
LDA UsedCandle
PHA
LDA #$00
STA UsedCandle
JSR WieldCandle
PLA
STA UsedCandle
```

### Candle item slot

Search Items table for candle slot id: per Variables.inc and
Z_05.asm:924/931/1512/1532 references to `CandleState` — Candle
inventory slot is **slot $05** (per NES item table; one of the B-
items). RoomRom B_ITEM_CANDLE = 4 maps; inventory storage at
`nes_ram[$0657 + 5]` (level of candle: 0=none, 1=blue, 2=red).

## L1Q1 LevelBlockAttrsE Dark-Room Set

Decoded from `data/rooms/dungeons.c` blob via Python:

```
ATTRS_E_BASE = LevelBlockUW1Q1.base + AttrsE_REL = 0x0000 + 0x200 = 0x0200
```

**18 dark rooms across full L1 grid** (bit 7 set):

```
room $01  AttrsE=0x99    room $40  AttrsE=0x99
room $02  AttrsE=0x83    room $46  AttrsE=0x97
room $1A  AttrsE=0x99    room $50  AttrsE=0x83
room $21  AttrsE=0x97    room $57  AttrsE=0x8F
room $27  AttrsE=0x99    room $62  AttrsE=0x96
room $29  AttrsE=0x99    room $66  AttrsE=0x99
room $2D  AttrsE=0x99    room $7A  AttrsE=0x99
room $30  AttrsE=0x83
room $37  AttrsE=0x96
room $39  AttrsE=0x83
room $3C  AttrsE=0x80
```

**None of the 17 reachable L1Q1 rooms** ({$22, $23, $33, $35, $36,
$41-$45, $52-$54, $63, $72-$74}) have bit 7 set. L1 vanilla NES Z1
has dark rooms only in non-traversal paths or NES design bias.

### Slice-1 verification implication

User cannot reach a dark room via 5.5 door route in L1Q1. Two test
paths:

1. **TELEPORT mode** (X-button toggle, already wired): user teleports
   to a dark room (e.g., $46) → enters → confirms dark render fires
   → uses B+CANDLE → confirms reveal → leaves and re-enters →
   confirms persistence. Slice-1 acceptable.

2. **Debug "force dark" chord**: a chord (e.g., `Y+B+START`) toggles
   a debug flag making the CURRENT room dark regardless of NES
   metadata. Useful for verifying render path on any reachable room
   without TELEPORT navigation. Slice-1 nice-to-have.

Slice-1 implements TELEPORT path first (uses existing infra); the
debug chord is a follow-up if TELEPORT verification proves awkward.

## F4 Fix — `dungeon_state.h:89` correction

Current state ([dungeon_state.h:88-96](src/state/dungeon_state.h:88))
incorrectly says:
```
LevelBlockAttrsByteF ($04CD): cached byte from LevelBlockAttrsF
  bit 4 = dark room (IsDarkRoom_Bank5 checks this)
```

Correct (per Variables.inc:135 + Z_05.asm:7795):
- `LevelBlockAttrsByteF` at `$04CD` is a **cache of the F-byte for
  the current room** (NOT for AttrsE).
- `IsDarkRoom_Bank5` reads the **AttrsE** byte at `$6A7E + room`,
  bit 7 (`$80`).
- The "bit 4 = dark room" claim is wrong; the dark flag is bit 7
  of AttrsE, NOT bit 4 of AttrsF.

Fix: rewrite the comment block + add a canonical macro for AttrsE
dark predicate. Existing `DUNGEON_ATTRS_F_DARK_ROOM = 0x10` macro
must be removed or repurposed (no callers outside drained code per
grep).

## Slice-1 manifest row format

Generator emits master table keyed by (level, quest, room_id):

```c
struct uw_dark_room_meta {
    unsigned char level;
    unsigned char quest;
    unsigned char room_id;
    unsigned char attrs_e_byte;  /* full byte for diagnostic */
};
```

L1Q1 rows: 18 (per dump above). All 18 quest-levels processed in
generator; total row count TBD.
