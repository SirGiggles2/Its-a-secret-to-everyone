# NES Ground Truth — Task 5.5 Door System

Source: `reference/aldonunez/Z_05.asm`. Line numbers cited inline.

## Door bit layout

`Z_05.asm:4513-4516` — `DoorBits` constants:

| Direction | Bit |
|-----------|-----|
| E         | $01 |
| W         | $02 |
| S         | $04 |
| N         | $08 |

Matches `RoomRom/src/uw_door_state.h:DOOR_BIT_*`. ✓

## LevelBlock attrs decode

`Z_05.asm:4520 FindDoorAttrByDoorBit` — direction iteration N=3, S=2, W=1, E=0.
For dir index < 2 (E=0, W=1): use `LevelBlockAttrsB[room_id]`.
For dir index >= 2 (S=2, N=3): use `LevelBlockAttrsA[room_id]`.

Bit positions within attribute byte:
- attr_b: bits 2..4 = E door type, bits 5..7 = W door type
- attr_a: bits 2..4 = S door type, bits 5..7 = N door type

Cross-checked against `RoomRom/tools/audit_uw_walkability_all.py:79-81`:

```python
attrs_b = data[base + 128 + room_id]
east = (attrs_b >> 2) & 7
west = (attrs_b >> 5) & 7
```

Same shift offsets. ✓

## Door type values

`Z_05.asm:4779-4789` — comment table mapping door attr (DA) to provisional face (PF):

| DA | Meaning      | PF (closed) | PF (open) |
|----|--------------|-------------|-----------|
| 0  | open         | 4           | 4         |
| 1  | wall         | 1           | 1         |
| 2  | false wall   | 2           | 2         |
| 3  | false wall 2 | 3           | 3         |
| 4  | bombable     | 8           | 9 (hole)  |
| 5  | key          | 5           | 4         |
| 6  | key 2        | 6           | 4         |
| 7  | shutter      | 7           | 4         |

Matches `RoomRom/src/uw_door_state.h:DOOR_TYPE_*`. ✓

## TouchDoor jump table

`Z_05.asm:3882-3890`:

```
0 → TouchDoorOpen
1 → TouchDoorWall
2 → TouchDoorFalse
3 → TouchDoorFalse
4 → TouchDoorBombable
5 → TouchDoorKey
6 → TouchDoorKey       (KEY2 uses same handler as KEY)
7 → TouchDoorShutter
```

Note: KEY2 (DA=6) shares `TouchDoorKey` handler with KEY (DA=5). The
"boss key" distinction is a graphical/flag-bit concern, not a behavior
branch in TouchDoor.

## TouchDoor*: per-type behavior

### TouchDoorOpen — `Z_05.asm:3895`
RTS. Always passable. `[0E]` untouched.

### TouchDoorWall — `Z_05.asm:3892`
`LDY #$FF / STY $0E / RTS`. Always blocked.

### TouchDoorFalse — `Z_05.asm:3898`
First touch (ObjTimer == 0): set ObjTimer=$18, block.
Subsequent: ObjTimer == 1 → passable; else block.

So FALSE blocks for $18 frames per touch session. Pass occurs on the
exact frame timer reaches 1.

### TouchDoorBombable — `Z_05.asm:3914`
If door bit in CurOpenedDoors: passable. Else: block.

Opening a BOMBABLE door is done by the bomb-collision path (not in
TouchDoor); persistence via `SetDoorFlag` so re-entry preserves open
state.

### TouchDoorKey — `Z_05.asm:3942`
1. If door bit already in CurOpenedDoors: passable, no key consumed.
2. If TriggeredDoorCmd != 0: BlockUntilTime (block while ObjTimer > 0).
3. Else if InvMagicKey != 0: trigger door open WITHOUT consuming a key.
4. Else if InvKeys != 0: DEC InvKeys (consume one key), trigger open.
5. Else (no keys): BlockAtWall.
6. After triggering open: ObjTimer = $20 frames, BlockAtWall (Link locked
   in place during open animation).

**No double-spend**: once door is in CurOpenedDoors, subsequent
TouchDoorKey returns early (step 1). Key is consumed exactly once.

### TouchDoorShutter — `Z_05.asm:3922`
1. If TriggeredDoorCmd != 0: BlockAtWall (during open animation).
2. If door bit not in CurOpenedDoors: BlockAtWall (closed).
3. Else passable. Sets `$0519` per-frame "opened this frame" tracker.

So SHUTTER passable only after `ShutterTrigger` fires AND `LayOutDoors`
re-runs to set the bit in CurOpenedDoors.

## CurOpenedDoors source + persistence

`Z_05.asm:2112 SetDoorFlag` writes to per-room world flags via
`GetRoomFlags`. `Z_05.asm:2125 ResetDoorFlag` clears.

`Z_05.asm:4760-4768 LayOutDoors @ClearFromOpenedMask` — for door types
0..3 (open/wall/false/false2), clears the door bit from
`CurOpenedDoors` because they are not "true doors" with state.

`Z_05.asm:4820-4823 LayOutDoors @SetDoorFlag` — only types **5/6/Bombable**
call SetDoorFlag when opened bit set. **Type 7 (SHUTTER) is explicitly
skipped** by the `CMP #$07 / BEQ :+` branch.

Implication: KEY / KEY2 / BOMBABLE persist across room re-entry via
the per-room world-flags mechanism. SHUTTER does NOT persist via
SetDoorFlag — its open state is per-room-visit, requiring
`ShutterTrigger` to fire each visit (which in NES happens when the
room is cleared of enemies; the "cleared" state itself persists, so
re-entry into a cleared room re-fires `ShutterTrigger` immediately).

For slice-1 (no combat): SHUTTER opening tested via `uw_door_state_trigger_shutters()`
debug stub. Persistence-via-cleared-flag deferred to Phase 6.

## CheckShutters

`Z_05.asm:2133`:

1. If `ShutterTrigger == 0`: return (no work).
2. Loop direction bits N=$08, S=$04, W=$02, E=$01:
   a. If bit already in `CurOpenedDoors`: skip to next direction.
   b. `FindDoorAttrByDoorBit` for this bit.
   c. If type == 7 (SHUTTER):
      - If `TriggeredDoorCmd == 0`: set `TriggeredDoorCmd = direction`, mark this shutter for opening.
      - Break inner work for this direction.
   d. Else: continue loop.
3. After loop: clear `ShutterTrigger`.

So one shutter opens per `ShutterTrigger` fire. Multiple shutters
require multiple fires (or the trigger auto-re-fires; need to check
caller).

## KEY independence across rooms

NES persistence via per-room world flags. Door A→B opening from A's
side calls `SetDoorFlag` with X = direction in A's frame. The flag
written is in A's world-flag byte, indexed by A's room id.

When Link enters B, `LayOutDoors` for B runs, calls `GetRoomFlags`
for B's room id, reads B's world-flag byte. B's flags do NOT have
A's bit pattern (different room, different byte).

**Conclusion**: A→B and B→A are independent doors with independent
persistence. Opening A→B does NOT auto-open B→A. ✓

For slice-1 harness assertion: door A→B opened from A's side leaves
B→A door at its NES-attr-decoded original type when Link enters B.

## OpenDoorTileIds

NES uses several tables for door tile-id selection per direction +
state. Not needed for slice-1 verification — RoomRom's
`uw_door_state_patch_open_tiles` is already implemented and
verified at Phase 5.3 close. Tile-id parity is implicit in Gate D
of slice-1 (visual confirmation).

## Summary — slice-1 verification rules

| Door type | Behavior to verify | Slice-1 trigger |
|-----------|-------------------|-----------------|
| OPEN      | Always passable | n/a |
| WALL      | Always blocked, no state | n/a |
| FALSE/FALSE2 | First touch sets ObjTimer=$18, blocks; passes on timer==1 | hold direction $18 frames |
| BOMBABLE  | Blocked unless bit in CurOpenedDoors | bomb-stub-chord |
| KEY/KEY2  | Bit set: pass. Bit clear + keys>0: dec keys, trigger open. Bit clear + keys=0: block. Once opened: persist via SetDoorFlag. | walk into door with InvKeys >= 1 |
| SHUTTER   | Bit set: pass. Else: block. Opens on `uw_door_state_trigger_shutters`. | shutter-stub-chord |

Cross-room independence: door A→B and door B→A persist independently.

KEY consumption: exactly once per door per room (re-touch on opened
door does not re-consume).
