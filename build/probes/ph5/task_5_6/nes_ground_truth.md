# NES Ground Truth — Task 5.6 Stairs and Passages

Source: `reference/aldonunez/Z_05.asm`. Line numbers cited inline.

## CheckWarps UW branch

`Z_05.asm:7253-7301` — UW stair entry path:

```
7253    ; In UW.
7254-60 ; If tile is not part of stairs square (tiles $70 to $73), return.
        CMP #$70
        BCC L1746E_Exit
        CMP #$74
        BCS L1746E_Exit
7263    JSR SaveKillCount
7264-65 LDA RoomId / STA CellarSourceRoomId
7266-79 ; Scan LevelInfo_CellarRoomIdArray for cellar where
        ; LevelBlockAttrsA[cellar] OR LevelBlockAttrsB[cellar] == RoomId
7282    STY RoomId          ; cellar found = current room
7283    LDA #$09             ; TargetMode = $09 (cellar)
7284    SetTargetMode:
7285    STA TargetMode
7286-95 ; Sound silence (skipped only if target is cave $0B)
7298    LDA #$10
7299    STA GameMode         ; transition mode
```

Stair tile range: `$70..$73` (inclusive; `BCS #$74` excludes `$74`).
Tile `$24` and `$88` are OW-only entrance tiles, NOT used in UW path
per the explicit `BCC #$70` exit gate.

## TargetMode variants (`Z_05.asm:7284 SetTargetMode`)

| Value | Meaning           | Trigger                           |
|-------|-------------------|-----------------------------------|
| $02   | level (dungeon)   | OW warp tile + selector < $40     |
| $09   | cellar            | UW stair tile                     |
| $0B   | cave (general)    | OW warp tile + selector >= $40    |
| $0C   | cave (shortcut)   | OW selector == $50                |

Slice-1 `ANIM` placeholder runs 0-frame for all four variants. Future
mode-`$10` visible work consumes this slot per Task 5.4 deferral.

## CellarSourceRoomId persistence

NES Variables.inc:178 — `CellarSourceRoomId := $527`. RAM byte;
persists across cellar visit. NES game state save (NV-RAM via SRAM at
end of `EndPrepareMode`-equivalent flow) preserves it. Slice-1 RoomRom
uses volatile `rr_warp_save_state_t.source_room_id` (P0-3 reuse, no
field duplication). NV-RAM persistence deferred (Task 5.4 inheritance).

## LevelInfo_CellarRoomIdArray

`Variables.inc:340 = $6BB2`. Per-level LevelInfo blob offset `$0x10`
(per `RoomRom/tools/uw_reachability.py:78 CELLAR_ARRAY_REL`), 10
bytes. `$FF` marks unused slots.

For L1Q1: array contains `$7F` and 9 × `$FF` placeholders.

## L1Q1 cellar pair (verified pre-plan dump)

Decoded from `data/rooms/dungeons.c` LevelBlockUW1Q1 attrs:

| Field            | Value | Notes                                    |
|------------------|-------|------------------------------------------|
| Cellar id        | `$7F` | Per L1Q1 manifest cellar_targets         |
| `AttrsA[$7F]`    | `$22` | Source room A                            |
| `AttrsB[$7F]`    | `$22` | Source room B (same — single-source pair)|

L1Q1 cellar `$7F` reached **only from `$22`**. Single source room.

## $22 stair tile placement (verified pre-plan dump)

`g_uw_room_nt[idx_$22]` (idx=0 in blob) row 10-11 cols 16-17 = stair square:

```
r10 col 16 = $70  col 17 = $72
r11 col 16 = $71  col 17 = $73
```

Standard 2x2 NES stair square. Link entry coords for coordinator
detection (rule 4 + rule 3):
- `link_x = 128` ($80, `& $0F = 0` ✓)
- `link_y = 133` ($85, `& $0F = $05` ✓ per RoomRom 5.4 derivation)
- Foot tile sample: `(link_x >> 3, (link_y + $0B - 56) >> 3) = (16, 11) = $71`
- Rule 5: `$71 ∈ {$70..$73}` ✓

Coordinator fires when Link stands at exactly that position in $22.

## L1Q1 cellar `$7F` blob coverage gap

`g_uw_room_nt[]` index search for `(map=0, quest=1, level=1, room=$7F)`
returns no entry. Existing entries: `(map=0, quest=1, level=8, room=$7F)`
and `(map=0, quest=2, level=7, room=$7F)`. L1Q1 cellar art is missing
from blob extraction.

**Slice-1 implication**: cellar render falls into `draw_placeholder`
(line 330 of `uw_room_render_roomrom.c`). Coordinator dispatch + state
machine verify regardless of cellar art quality. Real cellar art
extraction logged as deferral.

## NES alignment (rule 3 + 4)

`Z_05.asm:7220-7244` — same as OW non-`$22` path:
- `link_x & $0F == 0` (X aligned to metatile boundary)
- `link_y & $0F == $0D` (NES); RoomRom equivalent `$05` (per 5.4
  derivation: NES playfield-Y origin `$5D` vs RoomRom `$38`).

## Tile collapse (rule 7)

`Z_05.asm:7331-7332` (under HandleWarpOW but applies to UW path
post-store): `$70..$73 → $70` for `UndergroundEntranceTile` storage.
Slice-1 reuses Task 5.4 collapse helper.

## Summary — slice-1 verification rules

| Rule | Description | Source |
|------|-------------|--------|
| 0    | scene == SCENE_UW | new |
| 1    | underground_exit_type == 0 | NES 7217 |
| 2    | grid_offset == 0 | NES 7218 |
| 3    | link_x & 0x0F == 0 | NES 7235-7237 |
| 4    | link_y & 0x0F == 0x05 | RoomRom-derived from NES 7241-7244 |
| 5    | raw_tile ∈ {$70, $71, $72, $73} | NES 7257-7260 |
| 6    | cellar resolution succeeds (entry: source→cellar; exit: cellar→saved source) | NES 7264-7282 |
| 7    | tile collapse $70..$73 → $70 | NES 7331-7332 |

Cross-room independence: cellar entry latches `save->source_room_id =
current_room_id`; exit replays it. Two source rooms (A, B) per cellar
in NES — slice-1 single L1 pair has A == B == `$22`.
