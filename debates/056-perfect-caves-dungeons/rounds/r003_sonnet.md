# Round 3 — Pragmatic Implementer (Sonnet)

## Q1: SAT publish ORDER — FIFO match confirmed

The Genesis draw path goes through `draw_object_with_anim`
(`src/game/world/draw_dispatch.c:411`), which reads
`DRAW_CUR_SPRITE_INDEX = RAM(0x0341)` — this is the NES
`RollingSpriteIndex` ($0341). The sprite_offsets table
`k_sprite_offsets[41]` (`draw_dispatch.c:210`) is indexed by this same
cursor to pick OAM mirror byte-offsets (`draw_dispatch.c:418`). That is
the NES FIFO mechanism verbatim.

Genesis has NO separate slot pool for enemy sprites. Bonfires
(type=$40) call `enrt_update_standing_fire`
(`enemy_walker_runtime.c:146`) → `c_draw_object_not_mirrored_with_frame`
→ `draw_object_not_mirrored` → `draw_object_with_type` — same FIFO path.
The cave NPC (slot 1) also goes through `draw_object_mirrored`
(`cave_dispatch.c:~693`) → same path.

However, Genesis STATIC gameplay sprites (Link, sword, beam, boomerang,
etc.) use a SEPARATE hard-coded slot contract defined in
`sprite_slots.h:33-42` (slots 0..11) written via `VDP_setSpriteFull`.
These are NOT published through `RollingSpriteIndex`. The FIFO path
(`RAM(0x0341)`) covers only the enemy/NPC/bonfire OAM mirror writes
(`$0200..$02FF`), which are then batch-uploaded to SAT by the Genesis
SAT flush in `sprite_render.c:195` (`render_set_sprite_full`).

**OAM byte-diff will catch ordering divergences** because the OAM mirror
at `$0200` is written left-to-right by the same cursor the NES uses.
The Genesis SAT flush order follows OAM mirror order. NES OAM priority
is by OAM index 0..63; Genesis SAT priority by slot 0..63. Both derive
from the same `RollingSpriteIndex` increment. Match.

## Q2: PALETTE per-cave_id — ONE fixed palette, correct per NES

`src/game/world/render/cave_palette.c:11` — `cave_palette_apply()` loads
a single 8-entry array `k_cave_subpal_2_3_nes[8]` sourced from
`Z_06.asm:714` and uploads to CRAM slots 8..15. No cave_id switch.

This is correct per NES: the NES cave scene has one palette for ALL
caves. The "orange NPC" and "orange bonfire" you see is sub-pal 3 entry
3 ($17 = orange) shared by both — that is the NES-authoritative color
(`k_cave_subpal_2_3_nes[7] = 0x17`). No per-cave_id palette dispatch
exists in NES Z_06.asm or Z_01.asm. The fixed palette is not a bug.

## Q3: ITEM rendering for cave $6A

Items come from `LevelBlockAttrsE` (NES SRAM $6A7E, `Variables.inc:328`).
`cave_dispatch.c:90-91`:
```c
#define NES_SRAM_LBA_E_BASE  0x6A7Eu   /* LevelBlockAttrsE */
#define NES_SRAM_LBA_E_PRICE 0x6ABAu   /* LBA_E + 60 */
```
cave_idx=0 (cave_id=$6A), ware bytes = `nes_ram[0x6A7E + 0..2]`.

There is NO static `.dat` file for LBA_E in this repo — it lives only
in NES SRAM, populated at runtime by InitMode2Load from CHR bank data.
**Do not read a file for this: probe it.**

To know cave $6A's items, run a NES BizHawk probe: navigate to cave
$6A (OW room where OverworldPersonTextSelectors[0] = $40 → text-block
$00, selector top-bits $40 = cave type flags), then dump
`nes_ram[0x0422..0x0424]` after InitCaveContinue completes (frame
after GameMode=$0B). The $6A text selector $40 (index 0) and $C0 flags
suggest it is a "donate rupees" (letter) cave — likely 0 wares (items
$00/$00/$00) and prices $00. Cave $6A = "It's a secret to everybody" —
Old Man, no shop items. But this MUST be verified by probe, not assumed.

`draw_animate_item_object` (`draw_dispatch.c:674`) handles whatever
item_id is found. Item ids $00 = nothing (sentinel handled at
`draw_dispatch.c:695` → descriptor 0x01 → value 0xFF = no draw).

## Q4: Q2 cave differences — OW entry only, NOT cave interior

`Z_06.asm:263-267` defines `LevelBlockAttrsBQ2ReplacementOffsets` (8
bytes) and `LevelBlockAttrsBQ2ReplacementValues` (8 bytes). The patch
loop at `Z_06.asm:241-246` writes to `LevelBlockAttrsB` only — that is
the OW room block that controls WHICH entry tiles/warps are present in
each OW room.

`LevelBlockAttrsB` controls the OW room tile/warp structure. It does
NOT write to `LevelBlockAttrsE` (the cave item/price data). The Q2 patch
changes WHICH OW rooms have cave entries (and where), but the cave
interior content (items, text, prices) is keyed by cave_id, which is
read from `LevelBlockAttrsE` — unchanged in Q2.

Confirmed in `level_info_install.c:45-47`: "NES Z_05.asm InitMode2Load
applies per-quest patches AFTER the base block lands; those patches are
PER-QUEST replacement of specific bytes." Only dungeon LevelInfo gets Q2
replacements; `LevelBlockAttrsE` (cave ware data) has no Q2 patch table.

**Conclusion:** cave INTERIOR content is Q-independent. 20 cave scenarios
cover both quests. No 40-scenario split needed.

## Q5: NES capture strategy for byte-diff

**Recommendation: Force-state via Lua (option B).** Savestates are 12MB
of binary blobs that drift on ROM change and can't be scripted.

Force-state is safe if you write a minimal consistent set. The engine
enters cave mode via `InitCave` / `InitCaveContinue` which reads
`LevelBlockAttrsE` from SRAM ($6A7E+). On NES, SRAM is battery-backed
and always valid after a proper boot. The risk is that cave RAM cells
are stale from a prior scene.

**Minimum NES RAM cells to write for a force-state cave capture:**

| Cell | NES addr | Value |
|---|---|---|
| GameMode | $0012 | $0B (cave mode) |
| CurLevel | $0010 | $00 (OW) |
| RoomId | $00EB | target OW room |
| ObjType+1 | $0350 | cave_id ($6A..$7D) |
| PersonState | $00AD | $00 |
| CaveFlags | $0413 | (let engine recompute, or write 0) |
| ObjX+1, ObjY+1 | $0071, $0085 | $78, $80 (NPC position) |
| ObjState+0 (Link) | $00AC | $40 (halted) |

After writing, advance 3 frames to let InitCaveContinue populate
`$0422..$0424` (CaveItemIds) and `$0430..$0432` (CavePrices) from SRAM.
Capture OAM/PALRAM/CIRAM at frame+3. Dump all domains per standing
directive (OAM/PALRAM/CIRAM/CRAM/RAM cells/screenshot).

The one real risk: `LevelBlockAttrsE` at SRAM $6A7E may not be valid
if SRAM was not populated. Verify by checking `nes_ram[0x6A7E]` != 0xFF
before capture. If invalid, navigate to OW first (Mode $09) for one
frame to trigger InitMode2Load, then force-state.
