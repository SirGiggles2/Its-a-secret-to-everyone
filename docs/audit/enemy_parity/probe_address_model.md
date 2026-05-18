# Probe Address Model — NES ↔ Genesis (Debug.md)

## Source of truth

`src/abi/platform_abi.h:10-14` — Debug.md A4 boot shell
(`src/debug/a4_probe_asm.s`) executes:

```
lea 0x00FF8000,%a4
```

Genesis physical address of NES cell `$XXXX` = `$00FF8000 + $XXXX`.

NES work-RAM is 2 KB ($0000-$07FF); Debug.md mirror occupies
$FF8000-$FF87FF. The full 13-bit RAM bank used by drained C extends
past $07FF (NES Z1 uses up to $07FF; everything beyond is pure C scratch
in `src/state/`). NES asm references go up to ~$07F9 (RoomRom sentinel
in main.c:1797).

## BizHawk domain translation

| ROM      | BizHawk domain | Address formula                  |
|---       |---             |---                               |
| NES      | `"RAM"`        | `nes_addr` (direct)              |
| Genesis  | `"68K RAM"`    | `0x8000 + nes_addr`              |

Why `0x8000`: BizHawk's Genesis core exposes "68K RAM" as a 64 KB
window starting at $FF0000. Cell at physical $FF8000 = offset $8000
within the domain.

## Helper Lua

```lua
-- probe_addr.lua  --  include from family probes.
local M = {}

function M.nes_addr(nes_off)
  return nes_off  -- BizHawk NES "RAM" domain is direct
end

function M.gen_addr(nes_off)
  return 0x8000 + nes_off  -- Debug.md mirror at $FF8000 in 68K RAM
end

-- For Genesis-native state (NOT in nes_ram[]). These live in BSS at
-- linker-assigned addresses. Discover per-symbol from builds/Debug.elf
-- via objdump --syms. None used by current enemy AI; add here if needed.
M.gen_native_symbols = {
  -- ['symbol_name'] = absolute_address,
}

return M
```

## Audit cell list (NES → Genesis)

Per `/enemy_fix` skill — every cell the audit reads. All in `nes_ram[]`
(NES RAM mirror). Genesis address = `0x8000 + nes_addr` in 68K RAM
domain.

| NES cell        | NES addr        | Genesis 68K addr | Meaning                              |
|---              |---              |---               |---                                   |
| Random[0]       | `$0018`         | `$8018`          | RNG byte 0 (seeded $40 per ClearRam) |
| Random[1]       | `$0019`         | `$8019`          | RNG byte 1 (consumed by walker dir)  |
| Random[2..12]   | `$001A..$0024`  | `$801A..$8024`   | RNG bytes (rest of array)            |
| FrameCounter    | `$0015`         | `$8015`          | NMI tick counter (gates inv dec etc.) |
| ChaseTargetX    | `$0061`         | `$8061`          | Walker chase target X                |
| ChaseTargetY    | `$0062`         | `$8062`          | Walker chase target Y                |
| ChaseOther      | `$0060`         | `$8060`          | Chase mirror-flip flag               |
| ChaseLongTimer  | `$004A`         | `$804A`          | Reroll timer for chase target        |
| ObjX[slot]      | `$0070+s`       | `$8070+s`        | Object X position                    |
| ObjY[slot]      | `$0084+s`       | `$8084+s`        | Object Y position                    |
| ObjDir[slot]    | `$008C+s`       | `$808C+s`        | Object direction bitmap              |
| LinkX           | `$0070`         | `$8070`          | Link X (alias of slot 0)             |
| LinkY           | `$0084`         | `$8084`          | Link Y                               |
| LinkFace        | `$008C`         | `$808C`          | Link facing                          |
| RoomId          | `$00EB`         | `$80EB`          | Current room                         |
| CurLevel        | `$0010`         | `$8010`          | Current dungeon level                |
| GameMode        | `$0012`         | `$8012`          | Game mode (5 = Play)                 |
| ObjTimer[slot]  | `$0028+s`       | `$8028+s`        | Generic per-slot timer               |
| StunTimer[slot] | `$003D+s`       | `$803D+s`        | Per-slot stun timer                  |
| ObjQSpdFrac[s]  | `$03BC+s`       | `$83BC+s`        | Q-speed fraction byte                |
| ObjQSpdAcc[s]   | `$03A8+s`       | `$83A8+s`        | Q-speed accumulator                  |
| ObjType[slot]   | `$034F+s`       | `$834F+s`        | Slot type id ($01-$5E)               |
| ObjAttr[slot]   | `$04BF+s`       | `$84BF+s`        | Attribute byte (collide/draw)        |
| ObjState[slot]  | `$00AC+s`       | `$80AC+s`        | Object state byte                    |
| ObjMetastate[s] | `$04D8+s`       | `$84D8+s`        | Animation cluster (spawn-cloud)      |
| ObjAnimCnt[s]   | `$03C8+s`       | `$83C8+s`        | Animation counter                    |
| MoveTimer[s]    | `$0006+s` (?)   | `$8006+s` (?)    | Verify per Z_07.asm                  |
| HitReaction[s]  | `$04F0+s`       | `$84F0+s`        | Invincibility / hit-stun timer       |
| MonHP[slot]     | `$04B8+s`       | `$84B8+s`        | Monster HP (packed nibble)           |
| FirstUnwalk     | `$034A`         | `$834A`          | OW=$BE / UW=$? floor tile gate       |
| ShoveDir[slot]  | `$0490+s`       | `$8490+s`        | Shove direction byte                 |
| ShoveDist[slot] | `$0498+s`       | `$8498+s`        | Shove remaining distance             |

## Slot conventions

Enemy slots span 0..11 ($00..$0B). Slot 0 is Link. Slots 1..9 are
monsters. Slot $A..$B are misc (rocks / refilled drops).
Per-slot probe loop: `for slot = 0, 11 do ... end`.

## Frame-zero handshake

To force RNG parity at probe start (regardless of BizHawk's NES RAM
init policy or prior frame history), every audit probe MUST do this
on its first frame:

```lua
-- NES probe
memory.usememorydomain("RAM")
memory.writebyte(0x0018, 0x40)
for i = 1, 12 do memory.writebyte(0x0018 + i, 0x00) end

-- Genesis probe
memory.usememorydomain("68K RAM")
memory.writebyte(0x8018, 0x40)
for i = 1, 12 do memory.writebyte(0x8018 + i, 0x00) end
```

After this poke, the scramble chain on the next frame produces
identical sequences on both ROMs as long as A1 fixes hold.

## Verification (A1 gate)

`build/probes/audit_rng_parity_nes.lua` and
`audit_rng_parity_gen.lua` — 600-frame capture of Random[0..12] every
frame.

### Status (2026-05-18)

- **NES probe**: works as expected. Initial state {$40, 0..0} (from
  ClearRam) scrambles per frame: $40 → $20 → $10 → $08 → $04 → $02 →
  $81 → $40,$80 → $20,$40 → ...
- **Genesis probe**: scramble fn byte-correct
  (`src/state/rng_state.c:31-45` verified vs NES `@ScrambleRandom`
  Z_07.asm:499-515 — frame 148→149 progression in capture matches
  manually-traced scramble). Seed fn now matches NES ClearRam pattern
  (Random[0]=$40, rest=$00).
- **Open issue**: 13-byte burst writes Random[$18..$24] to a non-seed,
  non-scramble state around frame 148 of post-entry log. Suspected
  cause: scene-load or some boot-time init touches the cells. Not yet
  traced. Suspect candidates: enemy_loop_room_init or scene CHR load.
- **Mitigation for audit**: per-family probes force-poke Random
  immediately before logging starts (per "Frame-zero handshake"
  section above). Both NES + Genesis enter logging with identical
  Random state, so subsequent scrambles match step-for-step.

Per-family audits use force-poke + T1-cell gate; bytewise RNG-stream
parity across multi-hundred-frame windows is desired but not required.
