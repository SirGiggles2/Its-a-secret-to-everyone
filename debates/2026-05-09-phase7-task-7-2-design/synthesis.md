# Phase 7 Task 7.2 step 2 — debate synthesis

**Closed:** 2026-05-09
**Style:** adversarial / 1 round / 4 participants
**Topic:** [topic.md](topic.md)
**Verdict:** 3-of-4 minimum on every sub-question; Opus's Q5 "router" complement absorbed.

## Round 1 verdict tally

| Q | Codex | Gemini | Sonnet | Opus | Final |
|---|-------|--------|--------|------|-------|
| Q1 spawn data    | (a) port ObjLists | (a) port ObjLists | (b) test table | (a) port ObjLists | **(a) — 3-1** |
| Q2 placement     | (c) scroll-stable | (c) scroll-stable | (c) scroll-stable | (c) scroll-stable | **(c) — 4-0** |
| Q3 dispatch      | (b) fn-ptr table  | (b) fn-ptr table  | (a) switch    | (b) fn-ptr table  | **(b) — 3-1** |
| Q4 probe room    | (c) OW $7C        | (c) OW $7C        | (c) OW $7C    | (c) OW $7C        | **(c) — 4-0** |
| Q5 substrate     | (b) reserve slots | (b) reserve slots | (b) reserve slots | (a)+router    | **(b) + router — 3-1** |

## Why each verdict carried

### Q1 = (a) port `ObjListAddrs.inc` + `ObjLists.inc`

Three-way agreement (Codex, Gemini, Opus): hardcoded test tables are a
parity trap — "probe passes against fiction" (Codex). Sonnet's failure-
mode argument was real (don't bury shim bugs under data complexity) but
addressed by **probing a single octorok pulled from the real table** —
gets the plumbing tested without faking parity data. Long-term outcome
priority + drain rule D1 spirit win. Tasks 7.7 enemy-room matrix is a
single matrix-fill against the real port instead of a rewrite.

### Q2 = (c) scroll-stable branch only

Unanimous. NES `Z_07.asm:496` `IsSprite0CheckActive` gates updates during
scroll. (a)/(b) accumulate transition desync that only surfaces under
seeded-trace diff — week-long debug. (c) costs nothing.

### Q3 = (b) function-pointer table indexed by `ENEMY_TYPE`

Three-way agreement (Codex, Gemini, Opus): mirror NES `InitObject_JumpTable`
shape (`Z_07.asm:5601`); Tasks 7.3-7.7 fill disjoint table rows with zero
merge conflict. Sonnet's NULL-call concern (legitimate) absorbed by
**explicit early-return NULL check inside the iterator + compile-time
asserted `enemy_init_fns[ENEMY_TYPE_MAX]` array length**. Switch loses
because seven incoming PRs all hit the same `switch(t)` block.

### Q4 = (c) overworld $7C slow octorok column

Unanimous. (a) sterile lab room — can't probe parity against zero
enemies. (b) UW + teleport + non-octorok adds three suspects to a
first-light test. (c) is reachable in ~10 frames from spawn, OW CHR
already loaded, slow octorok = highest-priority RNG-dir-pick row in
`docs/audit/enemy_parity_matrix.md`.

### Q5 = (b) reserve enemy SAT slot range + (Opus) OAM router shim

Three-way agreement (Codex, Gemini, Sonnet): drained
`z01_anim_set_sprite_desc_attrs` writes Title-side OAM that doesn't know
SGDK SAT. (a) naive collides with Link/items the first frame. Opus's
router proposal (`roomrom_oam_router.c`) is **complementary, not
competing** with (b): reserve SAT slots in `roomrom_vram_map.h` AND
write the router that translates NES OAM shadow `nes_ram[0x200..0x2FF]`
into `VDP_setSpriteFull` calls against those reserved slots. Both
proposals address the same bug from opposite ends.

## Drain Rule D1 stance

**EXTEND** — drained walker family in `src/oracle/enemies/` is PRIMARY,
already linked into `Debug.md` (commit `b5026c1a`). RoomRom adds:
- iterator + dispatch wrapper (no NES drain exists for "Genesis main
  enemy loop" — RoomRom's tick is the substrate equivalent)
- spawn data table (data not function — D1 covers function drain only)
- OAM-shadow router (Genesis-native; NES had direct OAM access, we don't)

Zero GREENFIELD function bodies. Every `enrt_*` call goes to the drain.

## Integrated framework (locked)

```
RoomRom/data/obj_lists.c              [Q1=a, ~200 LOC]
  - ObjListAddrs[128] -> ObjList* (per overworld room)
  - DungeonObjListAddrs[...] -> ObjList* (per dungeon room)
  - obj_list_for_room(room_id, scene_id) -> const ObjList*

RoomRom/src/roomrom_enemy_loop.h      [~30 LOC]
  - void roomrom_enemy_loop_room_init(uint8_t room_id, uint8_t scene_id);
  - void roomrom_enemy_loop_tick(void);
  - extern const init_fn_t  enemy_init_fns[ENEMY_TYPE_MAX];
  - extern const update_fn_t enemy_update_fns[ENEMY_TYPE_MAX];

RoomRom/src/roomrom_enemy_loop.c      [Q3=b, ~150 LOC]
  - parallel fn-ptr tables, NULL-filled outside walker family
  - room_init: decode obj_list, write ENEMY_TYPE/X/Y/DIR per slot,
    call init_fns[t]() if non-NULL
  - tick: for slot 1..11, if alive, call update_fns[t]() if non-NULL
  - NES InitObject preamble (Z_07.asm:5466+) mirrored: clear scratch,
    set ALIVE, then dispatch init

RoomRom/src/roomrom_vram_map.h        [Q5=b, +5 LOC]
  - reserve SAT_ENEMY_BASE..SAT_ENEMY_END (slots 16..47 = 32 SAT entries
    for 11 enemies + projectile spillover)

RoomRom/src/roomrom_oam_router.c      [Q5+router, ~80 LOC]
  - flush_nes_oam_to_sgdk(): scans nes_ram[0x200..0x2FF] every frame
  - decodes Y/tile/attr/X quads, maps to SAT_ENEMY_BASE+(idx/4)
  - calls VDP_setSpriteFull per non-zero entry
  - hides Title-side OAM writes from SGDK without substrate edits

RoomRom/src/main.c (patch)            [Q2=c, ~20 LOC]
  - call roomrom_enemy_loop_room_init() on room-load + scroll-finalize
  - call roomrom_enemy_loop_tick() inside scroll-stable branch
  - call roomrom_oam_router_flush() after enemy_loop_tick

RoomRom/src/probes/enemy_walker_probe.c  [~60 LOC]
  - exposes slot-1 ENEMY_TYPE/X/Y/DIR + RNG state to a known WRAM addr
  - PROBE_WALKER_BASE = 0x0700 (free WRAM region, see vram_map.h)

tools/debug/build_debug.py            [+5-7 source list adds]

tools/debug/probe_walker_parity.lua   [Q4=c, ~80 LOC]
  - boot, scroll to OW $7C (south once from $77 spawn), seed RNG to
    known value at $0018..$0024, capture 60-frame X/Y trace

tools/parity/diff_walker_trace.py     [~50 LOC]
  - parse NES + Genesis traces, output per-frame diff, target ≤1px
```

## Risk + mitigation lock

| Risk | Mitigation |
|------|-----------|
| Drain shim writes Title OAM | OAM router (Q5+) flushes shadow → SGDK SAT |
| `LinkX/LinkY` macros vs `players[0].x/y` mismatch | Verify `RAM(0x0061)` mirrors `players[0].x` in D1 step before code |
| Enemy CHR not loaded | OW CHR already loaded for $7C; UW deferred until 7.3 stalfos/goriya |
| 11-slot SAT range collides with items/HUD | Reserve in vram_map.h (Q5=b) BEFORE first build |
| Scroll-Y stale when tick runs | Q2=c gating + read scroll AFTER scroll-state finalize |

## Single-commit deliverable

The framework lands as **one commit** per master plan §1251-1257
(framework-then-fan-out blocking commit). Subsequent Tasks 7.3-7.7 fill
NULL slots in `enemy_init_fns[]` / `enemy_update_fns[]` without
modifying the framework files.

**LOC estimate:** ~570 (was 410, +160 for OAM router + obj_lists port).
**Single commit. ~5-7 working hours.**

## Cost

Codex 101k tokens; Gemini 2.5-flash retry after Pro quota;
Sonnet ~26k tokens via Agent; Opus inline.
