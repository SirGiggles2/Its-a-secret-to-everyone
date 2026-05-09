# Opus — Round 1 verdict

**Stance:** adversarial / 1 round / Opus 4.7

## Q1 — Spawn data source: **(a) port `ObjListAddrs.inc` + `ObjLists.inc`**

Drain Rule D1 priority + CLAUDE.md priority 1 (long-term outcome) say port the
real NES table once. (b) "throwaway test table" is the textbook drift trap —
Tasks 7.3-7.7 will consume the placeholder, real port never lands, parity
matrix gets faked from test data. **Failure mode of (b):** test scaffolding
becomes production by neglect; six months later we still have hardcoded
1-octorok and no one remembers why room $7C is "broken". **Failure mode of
(c):** ObjList is screen-indexed not room-indexed (`ObjListAddrs.inc:1-130`);
folding into `overworld.c` couples two unrelated lookup keys and burns the
existing room blob's memory layout. Pick (a). Port verbatim. Expose
`const ObjList *obj_list_for_room(uint8_t room_id, uint8_t scene)`.

## Q2 — Iterator placement: **(c) scroll-stable branch only**

NES gates updates by `IsSprite0CheckActive` at `Z_07.asm:496` — enemies do
NOT tick during room transition. (a) post-DMA pre-scroll runs enemies on
stale scroll Y and they jitter visibly. (b) post-scroll-finalize ticks
during transition — drift accumulates against NES capture every scroll.
**Failure mode of (b):** parity diff has unexplained ±N-pixel offset right
after every scroll; takes weeks to root-cause back to here. (c) is the only
choice that matches NES asm verbatim.

## Q3 — Dispatch shape: **(b) function-pointer table indexed by `ENEMY_TYPE`**

NES `InitObject_JumpTable` at `Z_07.asm:5601` is a 70+ entry table — the
spec is a table, the impl should be a table. Tasks 7.3-7.7 each fill ~10
slots; merge conflicts are zero because each task lands in disjoint table
rows. **Failure mode of (a):** switch over 70+ ENEMY_TYPE values means
seven incoming PRs all touch the same `switch(t)` block; merge-conflict
storm guaranteed. **Failure mode of (c):** hybrid invents a "family bucket"
abstraction that doesn't exist in NES; first task to need a multi-family
type (e.g. trap / fairy / fire) breaks the bucket assumption. Pick (b),
declare two parallel arrays `init_fns[ENEMY_TYPE_MAX]` and
`update_fns[ENEMY_TYPE_MAX]`, NULL-fill non-walker slots in this step.

## Q4 — First probe room: **(c) overworld $7C slow octorok column**

(a) OW $77 has no NES enemies — the parity test is meaningless without a
real ground truth. (b) L1 UW requires teleport-debug + UW CHR + UW scroll
state; three independent moving parts on a first-light probe = three
suspects when the diff is non-zero. (c) is reachable in ~10 frames from
spawn (one screen-down scroll), uses overworld CHR already loaded, and the
slow octorok's RNG-dependent direction pick is the highest-priority
parity-matrix row per `docs/audit/enemy_parity_matrix.md` (Wizzrobe-align is
higher but Wizzrobe is UW). **Failure mode of (a):** can't probe parity if
there's nothing to compare against. **Failure mode of (b):** debugging
setup is harder than the test.

## Q5 — Substrate edit: **(a) RoomRom-only — but with mandatory OAM router shim**

WT-1 keeps substrate (`src/state/`, `src/sgdk_adapter/`, `src/abi/`,
`src/audio_driver.asm`, `data/`) main-only. `roomrom_vram_map.h` lives in
`RoomRom/src/` — it is NOT substrate. The real risk isn't the SAT slot
range, it's that drained `c_walker_move` + `z01_anim_set_sprite_desc_attrs`
write Title-side OAM via the linked-in `src/zelda_translated/z_01.asm` —
which doesn't know RoomRom's SGDK SAT. **Failure mode of (a) naive:** the
octorok updates fine but doesn't render because Title OAM writes never reach
SGDK SAT. **Solution within (a):** add `RoomRom/src/roomrom_oam_router.c`
(~80 LOC) that translates the NES OAM-shadow region (`$0200..$02FF`,
already mirrored at `nes_ram[0x200]`) into `VDP_setSpriteFull` calls each
frame. This stays inside RoomRom; substrate untouched. (c) preempts PR-4b
enemy_chr.c — out of scope, blast radius all of Phase 7. (b) is fine but
unnecessary if router translates NES OAM index → SGDK slot. Pick (a) +
router.

## Integrated framework (4-6 sentences)

Port the NES ObjList table verbatim into `RoomRom/data/obj_lists.c` (Q1=a).
Add `roomrom_enemy_loop_{tick,room_init}` in `RoomRom/src/roomrom_enemy_loop.c`,
called from `roomrom_debug_tick` only inside the scroll-stable branch
(Q2=c) to mirror NES `IsSprite0CheckActive` gating. Dispatch via parallel
function-pointer tables `enemy_init_fns[ENEMY_TYPE_MAX]` and
`enemy_update_fns[...]` indexed by `ENEMY_TYPE` (Q3=b), NULL-filled for
families landing in 7.3-7.7. Probe in overworld $7C slow octorok column
(Q4=c) — reachable in ~10 frames, RNG-pick is highest-priority parity row.
Keep edits RoomRom-only (Q5=a) with a new `roomrom_oam_router.c` that
flushes the NES OAM shadow at `nes_ram[0x200..0x2FF]` into SGDK SAT each
frame, bridging the drain's Title-side `z01_anim_set_sprite_desc_attrs`
writes to RoomRom's sprite list without substrate edits. Total ~490 LOC,
single commit, fan-out-ready for Tasks 7.3-7.7.
