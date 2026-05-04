# Drain Finding — Phase 4 Task 4.12 (native port) — draw_object pipeline

**Per Rule D1 Gate 1.** Native rewrite of the NES sprite-descriptor /
OAM-mirror writer chain. Establishes
`src/game/world/draw_dispatch.{h,c}` scaffold. Highest-leverage
unblock — opens the door for native cave/uw_person/trap/enemy full
updaters that currently STAGE-1 STUB their c_draw_object_* call.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/draw_dispatch.{h,c}` | `draw_object_mirrored`, `draw_object_not_mirrored`, `draw_object_mirrored_with_frame`, `draw_object_not_mirrored_with_frame`. Internal: `draw_object_with_type`, `draw_object_with_anim`, `draw_object_with_anim_and_specific_sprites`, `anim_write_horizontally_flippable_sprite_pair`, `anim_write_mirrored_sprite_pair`, `anim_write_sprite_pair`, `anim_write_sprite_pair_not_flashing` |
| NES asm | `reference/aldonunez/Z_01.asm:1958-2477` |
| Tables baked | `k_obj_animations[127]`, `k_obj_anim_frame_heap[228]`, `k_obj_anim_attr_heap[228]`, `k_sprite_offsets[41]` |
| State accessors | `src/state/scratch_state.h` ZP_TMP0..ZP_TMPF, `src/state/object_state.h` OBJ_TYPE, `src/state/combat_state.h` MON_STATUS_FLAGS, MON_HIT_REACTION |
| Cross-deps native | `core_anim_set_sprite_desc_attrs`, `sprite_cycle_cur_sprite_index` |

## Stance

**REWRITE-MIRROR** (no oracle drain exists for this chain — the
transpile pipeline lives only in `src/zelda_translated/z_01.asm`,
exported via `c_draw_object_*` shims in `src/c_shims.asm`).

NES asm passes parameters through ZP scratch slots ($00..$0F) and
RAM($0341/$0343/$0344) sprite-descriptor registers. Native port
preserves that ABI byte-for-byte: each ZP slot keeps its NES
semantic (DRAW_X = ZP_TMP0 = nes_ram[0x0000] etc.) so the OAM mirror
at $0200..$02FF is written identically to Title.md's transpile
output.

## Pipeline

```
draw_object_mirrored / draw_object_not_mirrored
  -> draw_object_with_type     (DRAW_ANIM_INDEX = OBJ_TYPE+1)
  -> draw_object_with_anim     (DRAW_FRAME, sprite-offset lookup)
  -> draw_object_with_anim_and_specific_sprites
       (look up tile/attr from heaps, branch on slot/status)
  -> anim_write_horizontally_flippable_sprite_pair
     OR anim_write_mirrored_sprite_pair
  -> anim_write_sprite_pair    (hit-flash palette override)
  -> anim_write_sprite_pair_not_flashing  -- writes 2 sprites to
     nes_ram[$0200..$02FF] OAM mirror via offsets in
     DRAW_LEFT_SPRITE_OFFSET / DRAW_RIGHT_SPRITE_OFFSET.
```

Special cases preserved:
- Link slot (0): hardcoded sprite offsets $48/$4C; always
  horizontally-flippable (never mirrored).
- Status flag bit $02 (half-width draw): decrement DRAW_HAS_TWO_SIDES,
  jump straight to anim_write_sprite_pair (skip attr setup).
- Status flag bit $08 (ignore attr table): skip
  core_anim_set_sprite_desc_attrs.
- DRAW_FLIP_H flag: swap left/right tiles + toggle attr bit 6.
- MON_HIT_REACTION non-zero: override low 2 bits of attrs (palette
  flash on damage frame).

## Cutover

No `NATIVE_DRAW` gate yet — Title.md continues to use the transpile
asm DrawObjectMirrored chain (it's already in z_01.asm and not
manifest-routed via z01_*). RoomRom links `draw_dispatch.o`
unconditionally, so native callers (future cave/uw_person/trap full
updaters) can call `draw_object_*` directly instead of routing
through the c_draw_object_* shim.

The follow-up work — flipping uw_person_update_grumble_full,
cavert_draw_cave_person body, trprt_draw_whirlwind, per-monster
updaters — replaces their `c_draw_object_*` calls with
`draw_object_*` native calls. Each such cutover gets its own gate
(NATIVE_UW_PERSON_DRAW etc.) and finding.

## Verification

- `build_all.ps1` green: Title.md + RoomRom.md both link.
- ROM Title.md checksum unchanged ($D6CA — no Title.md path uses the
  native draw yet).
- Tables verified byte-for-byte against Z_01.asm:1958-2041.
- ZP slot mapping verified via the (offset, A4, idx.W) addressing
  pattern in Z_01.asm:2272-2317 — every read/write maps to the
  same nes_ram index in native.

## Phase 4 status

Phase 4 cutover gates: 19 (no new gate this commit; pipeline is
the substrate, callers add gates).

This unblocks: cavert_draw_cave_person body, cavert_draw_cave_items
body, trprt_draw_whirlwind, trprt_update_rupee_stash_full's
c_draw_item_in_inventory call (different chain — Anim_WriteItemSprites
— deferred), uwrt_person_draw_and_check_collisions's
c_draw_object_mirrored call, uwrt_update_grumble_full's
c_draw_object_not_mirrored call, plus the entire enemy per-monster
updater family that currently STAGE-1 STUBS draws.
