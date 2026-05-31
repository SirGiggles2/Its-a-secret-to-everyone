# Phase 0.C — Boss room IDs (CORRECTED 2026-05-30)

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
ALL 10 LIVE SPAWN-VERIFIED 2026-05-31 (gen_boss_direct, Debug.md byte-diff)
after the Q1-LBA fix (519b9949) + WorldFlagsAddr fix. slot-1 ObjType below is
the live Genesis read, byte-matching the NES boss ObjType:

| L1 | **$35** | Aquamentus    | $3D | ✓ slot1=$3D (+$55 fireballs) |
| L2 | **$56** | Dodongo       | $31 | ✓ slot1=$31 (×3) |
| L3 | **$10** | Manhandla     | $3C | ✓ 5×$3C segments |
| L4 | **$13** | Gleeok 2-head | $43 | ✓ slot1=$43 (+$56) |
| L5 | **$24** | Digdogger     | $39 | ✓ slot1=$38 (Digdogger2 $39 morphs →$38 InitDigdogger2) |
| L6 | **$1C** | Gohma (blue)  | $34 | ✓ slot1=$34 (+$56) |
| L7 | **$2A** | Aquamentus #2 | $3D | ✓ slot1=$3D (+$55) |
| L8 | **$3C** | Gleeok 4-head | $45 | ✓ slot1=$45 (+$56) |
| L9 | **$52** | Patra Red     | $47 | ✓ slot1=$47 (+8×$25 children) ($21/$61 dup) |
| L9 | **$42** | Ganon         | $3E | ✓ slot1=$3E |

Room ids + ObjTypes cross-confirmed by TWO static sources (LBA monster_list_id
in `reference/aldonunez/dat/LevelBlockUW{1,2}Q1.dat` AND `LevelInfo_BossRoomId`)
THEN live-spawn-verified on Genesis.

Old (wrong) ids for reference: L2 $73, L3 $0F, L4 $45, L5 $06, L6 $0F,
L7 $23, L8 $1F, L9 $1E/$1F. Only L1 $35 was correct.

## #1 RESOLVED — not missing data, WRONG boss ObjType (2026-05-31)

Earlier "L5/L6/Ganon missing from LBA" was a FALSE conclusion from probing
the wrong ObjType. The data + routing are correct:
- NES level→block routing (`Z_06.asm:14 LevelBlockAddrsQ1`): L0=OW, **L1-6
  → UW1Q1, L7-9 → UW2Q1** — `level_info_install_uw` matches it exactly.
  NOT a routing bug.
- `reference/aldonunez/dat/ObjLists.dat` == port `obj_lists.c z1_obj_lists`
  byte-exact (201 B). Extraction faithful. NOT a data-extraction bug.
- The bosses ARE in UW1Q1, under the **variant ObjType** the room actually
  uses: L5 Digdogger spawns as **$39 (Digdogger2)** at **$24** (InitDigdogger2
  → becomes $38, Z_04.asm:4879); L6 Gohma spawns as **$34** (Gohma, blue
  variant) at **$1C**. I scanned for $38/$33 → found nothing → wrongly
  called it a gap. `enemy_init_fns[$39]`/`[$34]` + `enemy_update_fns` are
  already wired (`enemy_loop.c`). Ganon $3E @ $42 in UW2Q1 (the block L9
  loads) — also present.

**Fix for #1 = correct room ids + ObjTypes (this doc + probes + diff_boss),
NO code/data change.** Genesis verify: warp Debug.md to $24/$1C/$42, confirm
slot 1 = $39/$34/$3E (pending — uses Debug.md, NOT the NES ROM).

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
