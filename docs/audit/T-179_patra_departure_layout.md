# T-179 — missing Patra departure layouts changed enemy collision

2026-10-02, Codex. P3 / P5. Drain stance: retain linked Gel/walker/collision code. Fix generated data coverage, not AI. Owners: `tools/builder/inject_boss_rooms.py`, existing generated `RoomRom/src/uw_room_blob.c`; runtime consumer `src/game/dungeon/uw_render.c:find_blob_entry/fill_one_col_at`.

## Identify / research

Long T-003 blue Patra controller fight exits Q1 L9 $16 south to $26 at1501. At1585 Gel slot2 moves down on NES ($60,$7E,dir4), right on Genesis ($61,$7D,dir1). Slot7 also diverges1628. RNG, room, initial position/direction and state agree before the first turn. NES/Genesis live capture at1584/1585 rules out an AI/RNG guess.

Room $26 has no direct or same-UW2-block sibling blob entry. `fill_one_col_at` then leaves plane/raw tiles unchanged. Inherited $16 floor has24 tile differences: at collision hotspot ($60,$90), NES tile74 walkable, GenesisB0 blocked; the adjacent tile76/B2 also differs. The Gel correctly chooses an alternate direction around a block which should not exist. ROM `LayoutUWFloor` (Z_05.asm:5308 onward) decodes unique layout25. Existing `gen_uw_room_tiles.compose("UW2",1,$26)` is **704/704** equal to live NES room playfield; attribute majority is **64/64** equal. Generated level palette BG16/16 matches; sprite PALRAM byte17 reflects live room-specific sprite selection, and runtime uses installed level/object palette consumers. Post-fix screen comparison establishes the actual presentation.

## Structural correction

Required-room generator now includes each Patra's legal immediate departures, read from ROM AttrsA/B door types (type1 solid wall excluded; bounds/row wrap checked). Generation cannot omit the connected destination while accepting a boss room. `--dry-run` reports the missing inventory without changing files.

Adds17 Original L9 entries, Q1:06/11/15/17/22/26/31/37/51/62/71; Q2:00/06/11/36/47/56. Existing667 entries' NT, attributes and palettes remain byte-identical. Generated blob now684 entries (366 Original,318 Redux). ROM-table gate **366/366 Original exact**;98 pre-existing Redux door-state variants unchanged, zero floor/frame/underrun errors. Sparse atlas regenerated: unchanged677 tiles; no VRAM budget increase. Rerunning inventory yields no missing required departures. Sentinel updates limited to uw_blob/bg_sparse; Claude atlas/item/sprite sentinel WIP preserved.

This establishes data coverage for all17 added layouts, plus live integration for $26. It does not mark every new room mechanic, dungeon or Quest2 route complete. Broader room coverage remains T-058 / connected quest acceptance.

## Verification

`Debug.bat` PASS, freshness9/9, frozen `builds/playtests/Debug-T179.md` SHA-256 **AA64D45F23A0A2391156040D753E73E77C131762DB7D7FC9D5857FF897B1D8A5**. Same preserved Claude ladder/item WIP as T-003; no gameplay-code modification. Before uses frozen T-0032B0094D5; after uses frozenT-179, unique reports.

- Focused first-turn reproduction:1587 ticks before, occupied Gel KEY mismatch1585; after1587/1587 zero KEY failures, live collision grid704/704 equal, screens1585/1586 MATCH.
- Named second-Gel and return consumer: full1856/1856 GATE PASS, no KEY allowances,67-cell familiar startup/OAM/VScrollAddrHi baseline. Both turns and all subsequent enemy state match; return boss stays dead. Screens1628 and1855 MATCH.
- Focused full video trace: zero slower-than-NES rows, worst scanlineD9 < E0. No broad dungeon/enemy suite repeated.
- All old667 data records compared, none changed. Data regeneration is reproducible from extracted ROM tables plus existing accepted frame/door/palette references; builder packaging/extraction completeness remains T-080.

Reproduction preset `tools/lockstep/presets/t179_gel_dungeon_turn.json`; baseline same name. Reports: `t179_gel_dungeon_turn_codex_before`, `_after`, `_full`; before longer route also `t003_patra_revisit_codex_saved`. Generation summary `build/scratch/t179_generation.json`. T-003 SRAM/world-region evidence remains applicable: unchanged accepted rooms and serializer, new layouts only. OW raft T-056 and `lag_gate.py` error propagation T-180 remain open.
