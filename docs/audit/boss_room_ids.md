# Phase 0.C — Boss room IDs (updated 2026-09-23)

Current `Debug.md` entry probe resolves L9Q1 room `$42` as Ganon: installed
AttrsC=`$3E`, BossRoomId=`$42`, and enemy slot 1=`$3E` on the next frame.
This supersedes the older missing-spawn finding for Ganon. See
`builds/reports/recovery/ganon-room-entry-20260923/trace.txt`. Other old
boss-room claims below retain their historical evidence scope.

**Status:** the original table here was WRONG for 8/10 bosses — derived
from `probe_nes_known_bosses.lua` whose mode-poke warp ($12=$06→$05) lands
in the room but does NOT load objects (skips Z1 `InitMode4`/
`InitMode_EnterRoom`), so its room ids were never spawn-validated and 8/10
are not real rooms in their dungeons.

**Re-derived + SPAWN-VERIFIED** by warping Debug.md to each room and
confirming the boss ObjType lands in enemy slot 1 (engine resolves the
room's ObjList from `LevelBlockAttrsC/D`; boss room = where
`monster_list_id` == boss ObjType per `Z_05.asm @PlaceObjects` +
`Z_07.asm InitObject_JumpTable`). ObjTypes confirmed from that jump table.

## Boss rooms (✓ = spawn-verified on Genesis)

| Level | Room ($EB) | Boss | ObjType | Status |
|---|---|---|---|---|
| L1 | **$35** | Aquamentus    | $3D | ✓ slot1=$3D (+$55 fireballs) |
| L2 | **$56** | Dodongo       | $31 | ✓ 6×$31 |
| L3 | **$10** | Manhandla     | $3C | ✓ 5×$3C segments ($4D also has $3C) |
| L4 | **$13** | Gleeok 2-head | $43 | ✓ slot1=$43 |
| L5 | **?**   | Digdogger     | $38 | ✗ GAP — absent from port LBA |
| L6 | **?**   | Gohma Red     | $33 | ✗ GAP — absent from port LBA |
| L7 | **$2A** | Aquamentus #2 | $3D | ✓ slot1=$3D |
| L8 | **$3C** | Gleeok 4-head | $45 | ✓ slot1=$45 |
| L9 | **$52** | Patra Red     | $47 | ✓ slot1=$47 (+$25 children) |
| L9 | **$42** | Ganon         | $3E | ✓ current Debug.md slot1=$3E (2026-09-23) |

Old (wrong) ids for reference: L2 $73, L3 $0F, L4 $45, L5 $06, L6 $0F,
L7 $23, L8 $1F, L9 $1E/$1F. Only L1 $35 was correct.

## Historical three-gap finding (2026-05-30 build)

The older probe found the following with its then-current blob; the Ganon
claim is superseded by the current spawn probe. L5/L6 need fresh checks
before this paragraph can describe the current build.

`level_info_install_uw` installs `LevelBlockAttrs` as SHARED blocks
(block 0 = L1-L6 Q1, block 1 = L7-L9 Q1; verified byte-identical across
L2/L5 captures). Block 0 contains L1-L4 boss placements but NOT $38
(Digdogger) or $33 (Gohma); block 1 lacks a spawning Ganon. So
`data/rooms/dungeons.c` `rooms_dungeons[]` was reported missing L5/L6/Ganon
boss object data. The current pointer-derived Q1/Q2 blob has Ganon AttrsC
`$3E` at room `$42`, and he spawns there. L5/L6 still need current evidence.

## Derivation tooling

- `tools/parity/probe_gen_boss_direct.lua` — warp + slot-1 spawn check.
- `tools/parity/probe_gen_boss_scan_l56.lua` — scans list-type rooms.
- LBA read: `nes_ram[$697E+room]` (C) / `[$69FE+room]` (D), Genesis mirror
  at `$8000+addr`. ObjType ranges (boss): $31-34, $38-3E, $41-48.

## Known downstream issues (separate from room ids)
- Non-L1 boss rooms render black: absent from `g_uw_room_nt` visual blob.
- Boss sprites draw garbage: `translate_tile` (`enemy_render.c:521`) uses
  enemy base $8E; boss bank loads NES $C0+ at the same VRAM slot 659 →
  needs a boss-bank-active branch (base $C0). Confirm via CHR byte-diff.
