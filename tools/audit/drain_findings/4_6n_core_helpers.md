# Drain Finding — Phase 4 Task 4.6 (native port) — core helpers

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for 4 trivial
core helpers that unblock Phase 3 cave deferred stubs. Establishes
`src/game/core/core_dispatch.{h,c}` scaffold + `NATIVE_CORE` cutover gate.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/core/core_dispatch.{h,c}` | `core_unhalt_link`, `core_inc_cave_state`, `core_cue_transfer_buf_and_advance_state`, `core_abs` |
| Drain | `src/core/core_runtime.c` | 56-58, 60-62, 160-163, 219+ |
| NES asm | `reference/aldonunez/Z_01.asm` | UnhaltLink (100), IncCaveState, CueTransferBufAndAdvanceState (521), Abs |
| NES vars | various trivial ($00AC = ObjState = OBJ_STATE(0), $00AD = ObjState+1 = CAVE_PERSON_STATE = OBJ_STATE(1), $0014 = ROOM_TRANSFER_BUF_SELECT) |

## Drain MATCH proof — `core_unhalt_link`

| Drain (56-58) | NES UnhaltLink (Z_01.asm:100) | Verdict |
|---------------|-------------------------------|---------|
| `OBJ_STATE(0) = 0` | `LDA #$00 / STA ObjState / RTS` | **MATCH** |

## Drain MATCH proof — `core_inc_cave_state`

| Drain (60-62) | NES IncCaveState | Verdict |
|---------------|-------------------|---------|
| `OBJ_STATE(1)++` | `INC ObjState+1 / RTS` | **MATCH** |

## Drain MATCH proof — `core_cue_transfer_buf_and_advance_state`

| Drain (160-163) | NES CueTransferBufAndAdvanceState (Z_01.asm:521) | Verdict |
|------------------|-------------------------------------------------|---------|
| `ROOM_TRANSFER_BUF_SELECT = val` | `STA TileBufSelector` (= $0014) | **MATCH** |
| `corert_inc_cave_state()` | NES falls through to `INC ObjState+1 / RTS` | **MATCH** |

## Drain MATCH proof — `core_abs`

| Drain (219+) | NES Abs | Verdict |
|--------------|----------|---------|
| `signed s = (signed char)val; return s < 0 ? -s : s` | NES bit-7 test + 2's-complement negate | **MATCH** |

**Drain verdict: 4 functions FULL MATCH** vs NES.

## Native port

Mechanical translation. No semantic changes. Pure C, no shims.

| Function | Drain | Native | Verdict |
|----------|-------|--------|---------|
| unhalt_link | drain | drop-in | **MATCH** |
| inc_cave_state | drain | drop-in | **MATCH** |
| cue_transfer_buf_and_advance_state | drain (calls inc_cave_state) | drop-in (calls native sub) | **MATCH** |
| abs | drain | drop-in | **MATCH** |

**Native verdict: FULL MATCH** for all 4. No deferred TODOs.

## Cutover gate

- New gate: `NATIVE_CORE` (independent from prior gates).
- 4 hand-written z01_* wrappers in src/gen/z_01.c.
- Default OFF → oracle drain (corert_*).
- Defined ON → native (drop-in FULL MATCH).
- RoomRom links core_dispatch.o unconditionally.

## Phase 3 cave back-fill (this commit)

Three cave Phase-4 deferred stubs filled with native core helpers:

| Cave function | Stub | Filled with |
|---------------|------|-------------|
| `cave_update_talk_shop_or_door_charge` (ware-take path) | `// TODO Phase 4: cue_transfer_buf_and_advance_state(30)` | `core_cue_transfer_buf_and_advance_state(30u)` |
| `cave_write_prices_to_dynamic_transfer_buf` | `// TODO Phase 4: cue_transfer_buf_and_advance_state(10)` | `core_cue_transfer_buf_and_advance_state(10u)` |
| `cave_update_hint_or_money_game` (hint cave branch) | `// TODO Phase 4: cue_transfer_buf_and_advance_state(30)` | `core_cue_transfer_buf_and_advance_state(30u)` |

Cave's `z01_unhalt_link` was already inlined as `CAVE_LINK_ACTION_TIMER = 0u`
(matches NES UnhaltLink semantics). cave's `z01_inc_cave_state` was
already inlined as `CAVE_PERSON_STATE++`. cave's `z01_abs` was already
inlined as `cave_abs_inline`. No changes needed for those.

## Stance update

Phase 4 Task 4.6 (Stance: ADOPT) — first core batch. 4 helpers ported.
Many other corert_* functions remain (large file: ~30+ functions).
Most are heavier; this batch focused on the cave-unblockers.

Next likely batches: post_debit / post_credit (HUD-anim deferred for
LINK_RUPEES — also unblocks cave talk_shop / hint_or_money_game),
take_one_rupee, take_5_rupees, init_one_simple_object,
set_up_common_cave_objects (cave init's deferred call).

## Provenance

- 2026-05-03. Author: Claude Opus.
