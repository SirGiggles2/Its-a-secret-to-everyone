# Phase 8 Task 8.5 — Gleeok

- **NES source**: `reference/aldonunez/Z_07.asm:5295` UpdateObject_JumpTable
                  rows $42/$43/$44/$45 → `Z_04.asm:8601` UpdateGleeok
                  (4-neck dispatch); row $46 → `Z_04.asm:8527`
                  UpdateGleeokHead.
                  `Z_07.asm:5601` InitObject_JumpTable rows $42-$45 →
                  `Z_04.asm:7649` InitGleeok; row $46 →
                  enrt_init_gleeok_head (drained).
                  Plus per-segment helpers: `Z_04.asm:8695`
                  Gleeok_FetchNeckAddrs, `Z_04.asm:8717` Gleeok_MoveNeck,
                  `Z_04.asm:8902` CalcSegmentLimits, `Z_04.asm:8937`
                  Gleeok_StretchNeck (with Z_04:8944 SBC ObjX+3,X bug
                  flagged UNKNOWN in NES disasm), `Z_04.asm:9100`
                  DrawHeadAndCheckCollisions, `Z_04.asm:9102`
                  DrawSegmentAndCheckCollisions, `Z_04.asm:9272`
                  Gleeok_MoveHead, `Z_04.asm:9369` Gleeok_DrawBody.
                  Object var layout from `reference/aldonunez/ObjVars.inc:95-133`
                  (Gleeok_NeckXs0..3 := $438, $452, $46C, $395;
                  Gleeok_NeckYs0..3 := $445, $45F, $479, $3BD;
                  Gleook_HeadInfo0..3 := $420, $42D, $381, $3A9;
                  Gleeok_ObjHeadInfo working area := $413..$418).
- **Drained C**:  `src/oracle/enemies/enemy_gleeok_runtime.c` —
                  segment-mgmt PRIMARY: `enrt_init_gleeok_head`,
                  `enrt_update_gleeok` (4-neck dispatch),
                  `enrt_gleeok_check_collisions`,
                  `enrt_gleeok_store_ref_seg_distance`,
                  `enrt_gleeok_set_segment_x/y`,
                  `enrt_gleeok_contract_segment_x/y/segment`,
                  `enrt_gleeok_dec_head_timer`,
                  `enrt_gleeok_ignore_segment`. Drain primary for the
                  segment-mgmt slice.
- **Coverage**:   PARTIAL — top-level `InitGleeok` + `UpdateGleeokHead`
                  + 8 gleeok-specific primitives (`c_gleeok_draw_body`,
                  `c_gleeok_fetch_neck_addrs`, `c_gleeok_move_neck`,
                  `c_gleeok_move_head`, `c_gleeok_calc_segment_limits`,
                  `c_gleeok_stretch_neck`,
                  `c_gleeok_draw_head_and_check_collisions`,
                  `c_gleeok_draw_segment_and_check_collisions`) NOT
                  drained — this TU carries native NES ports for them.
                  Drained per-segment helpers consumed verbatim.
- **Stance**:     EXTEND — drained per-segment helpers consumed
                  verbatim from `enemy_gleeok_runtime.c`; native bridge
                  in `boss_gleeok.c` supplies the rest from per-line
                  `Z_04.asm` transcription. Faithful to NES (including
                  the Z_04:8944 "SBC ObjX+3,X" oddity flagged UNKNOWN
                  in NES disasm — preserved verbatim in
                  `c_gleeok_stretch_neck`).

## Wired pipeline

`src/game/enemies/enemy_loop.c`:

```c
/* INIT */
[0x42] = boss_gleeok_init,         /* Gleeok 1-neck */
[0x43] = boss_gleeok_init,         /* Gleeok 2-neck */
[0x44] = boss_gleeok_init,         /* Gleeok 3-neck */
[0x45] = boss_gleeok_init,         /* Gleeok 4-neck */
[0x46] = enrt_init_gleeok_head,    /* GleeokHead (flying) */

/* UPDATE */
[0x42] = enrt_update_gleeok,       /* Gleeok 1-neck */
[0x43] = enrt_update_gleeok,       /* Gleeok 2-neck */
[0x44] = enrt_update_gleeok,       /* Gleeok 3-neck */
[0x45] = enrt_update_gleeok,       /* Gleeok 4-neck */
[0x46] = boss_gleeok_update_head,  /* GleeokHead (flying) */
```

Five-row Gleeok dispatch ($42-$46) — 1-4 neck variants + flying head
spawn. NES tables fan all four neck-count rows to the same UpdateGleeok
entry; neck count is derived from ENEMY_TYPE-$42 inside the body.

## Native bodies in boss_gleeok.c

- `boss_gleeok_init` (Z_04.asm:7649) — full per-line port. Seeds
  4-neck head info ($413..$418) per neck index, 6 segments per neck
  via Gleeok_NeckXs/Ys + GleeokSegmentYs offsets, picks initial dir
  via RNG, sets ENEMY_INVINCIBILITY=$E2, fans body palette / frame
  defaults.
- `boss_gleeok_update_head` (Z_04.asm:8527) — flying-head 5-state
  dispatch. State 0 = enrt_init_gleeok_head terminator + spawn keese
  via z04_init_blue_keese; state 1 = enrt_flyer_gleeok_head_decide_state;
  states 2/3 = c_move_flyer + (Flyer_Chase / Flyer_Wander shared with
  keese flight back-end via enrt_flyer_speed_up dispatch); fireball
  spawn at FrameCounter & 7 == 0 + ENEMY_TYPE($B) == 0 cap. Reuses
  c_check_monster_collisions / c_reset_shove_info for tail.
- `c_gleeok_fetch_neck_addrs` (Z_04.asm:8695) — neck X/Y/misc base
  pointers into ZP_TMP0..5 for the active neck.
- `c_gleeok_move_neck` (Z_04.asm:8717) — primary axis advance via
  SPEEDX/SPEEDY accumulators, secondary axis via DIRCOUNTER{H,V}, dir
  change via DIRCHANGECNT countdown, segment slot defer via DELAY.
- `c_gleeok_move_head` (Z_04.asm:9272) — head segment X/Y advance from
  $0413..$0418 working area + speed flags.
- `c_gleeok_calc_segment_limits` (Z_04.asm:8902) — per-axis primary /
  secondary / tertiary limit derivation for stretch_neck.
- `c_gleeok_stretch_neck` (Z_04.asm:8937) — per-segment expand /
  contract dispatcher with the JT-idx 4-tier branch. Z_04:8944 SBC
  oddity preserved verbatim (H-distance always 0 → JT idx never gains
  H-tier bumps; matches NES emulator behavior).
- `c_gleeok_draw_head_and_check_collisions` (Z_04.asm:9100) +
  `c_gleeok_draw_segment_and_check_collisions` (Z_04.asm:9102) — frame
  attribute compose + draw_object_mirrored composite + monster
  collision tail.
- `c_gleeok_draw_body` (Z_04.asm:9369) — base-segment 6-frame body
  composite via GleeokBodyTiles0/1/2 + GleeokBodyBaseTileOffsets.

## Callee shims for the drain

`src/oracle/enemies/enemy_gleeok_runtime.c` references several extern
primitives via `enemy_runtime_private.h`. Most resolve to existing
linked symbols:

| Drain extern | Resolved to | Bridge |
|--------------|-------------|--------|
| `c_check_monster_collisions` | `enrt_check_monster_collisions` adapter | `enemy_walker_bridge.c:166` |
| `c_reset_shove_info` | inline native (clears push timer + flags) | `enemy_flyer_bridge.c:128` |
| `c_shoot_fireball` | inline native (slot 7 spawn) | `enemy_boss_bridge.c:278` |
| `c_play_boss_hit_cry_if_needed` | `enemy_play_boss_hit_cry_if_needed` | `enemy_dispatch.c:157` |
| `c_play_boss_death_cry` | `enemy_play_boss_death_cry` | `enemy_dispatch.c:42` |
| `z01_abs` | inline native | `enemy_walker_bridge.c` |
| `LevelMasks[8]` | new global definition | `boss_gleeok.c` (PR-local) |

Three are not present under c_*-prefixed names anywhere in the link.
`src/game/enemies/bosses/boss_gleeok.c` carries forwarders for them:

| Drain extern | Resolved to | Source |
|--------------|-------------|--------|
| `c_gleeok_*` (8 primitives above) | inline native (Z_04.asm transcriptions) | new |
| `c_write_blank_priority_sprites` | `core_write_blank_priority_sprites` | `core_dispatch.c` |
| `c_reset_obj_metastate` | `core_reset_obj_metastate` | `core_dispatch.c` |
| `core_set_shove_info_with0` | direct call (val=0, slot) | `core_dispatch.c:203` |
| `z04_gleeok_set_segment_x/y` | forwarder → `enrt_gleeok_set_segment_x/y` | drained twin |
| `z04_init_blue_keese` | forwarder → `enrt_init_blue_keese` | drained twin |

Shared state with the drain: `LevelMasks[8]` was extern-decl'd in 4
oracle headers but never globally defined. Defined in `boss_gleeok.c`
as the canonical owner — first TU to need it across the link.

## Anim primitive native ports

NES `Anim_WriteSpecificSprite` (Z_01.asm:2500) and
`Anim_WriteLevelPaletteSprite` (Z_01.asm:2532) live as static helpers
`gleeok_anim_write_specific_sprite` / `gleeok_anim_write_level_palette_sprite`
in this TU. The Z_01 M68K transpile is not in the link — these were
the cleanest surfaces to re-port for the gleeok composite draw paths.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean. New TUs added to the link set:
- `src/oracle/enemies/enemy_gleeok_runtime.c`
- `src/game/enemies/bosses/boss_gleeok.c`

## Live-room probe deferral

Same caveat as Tasks 8.2/8.3/8.4: in-emulator Level 4/7 (Gleeok rooms)
boss probe requires the `InitMode_EnterRoom` gameplay state machine
(`Z_05.asm:1700-1820`) to be wired through scroll / pause / shutter.
Tracked under Task 8.11 Boss Matrix.

## Status

CLOSE — Gleeok PARTIAL coverage (drain segment-mgmt PRIMARY + native
top-level + 8 c_gleeok_* primitives EXTEND). Drain consumed verbatim;
native bridge supplies un-drained branches per per-line Z_04.asm
transcription. Five-row $42-$46 dispatch wired. Three callee shims
resolve the drain's extern decls. No primitive gaps at link.
