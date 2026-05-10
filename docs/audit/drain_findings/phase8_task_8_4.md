# Phase 8 Task 8.4 — Manhandla

- **NES source**: `reference/aldonunez/Z_07.asm:5295` UpdateObject_JumpTable
                  row $3C → `Z_04.asm:7842` UpdateManhandla;
                  `Z_07.asm:5601` InitObject_JumpTable row $3C →
                  `Z_04.asm:7747` InitManhandla;
                  `reference/aldonunez/ObjVars.inc:71-76`
                  (Manhandla_ObjSpeedAccum=$412,
                  Manhandla_ObjSpeedFrac=$41F,
                  Manhandla_ObjSpeedWhole=$42C,
                  Manhandla_ObjPrevFrame=$437,
                  Manhandla_ObjFrameAccum=$451,
                  Manhandla_ObjFrame=$478).
                  Plus `Z_04.asm:11859` TurnRandomlyDir8 +
                  `Z_04.asm:11883` GetObjDir8Index for the random-turn
                  fork inside UpdateManhandla.
- **Drained C**:  `src/oracle/enemies/enemy_manhandla_runtime.c:20`
                  `enrt_init_manhandla`; same file: `enrt_update_manhandla`
                  (line 44), `enrt_manhandla_set_all_segments_direction`,
                  `enrt_manhandla_check_collisions`,
                  `enrt_manhandla_move`, `enrt_manhandla_draw`. Drain
                  primary — covers every Z_04 UpdateManhandla branch
                  including the 5-segment loop, Manhandla_BounceDir /
                  Manhandla_SegmentJustDied flags, TurnTowardsPlayer8
                  vs TurnRandomlyDir8 pick, $56 fireball spawn gate,
                  and the mirrored vs not-mirrored draw fork.
- **Coverage**:   FULL — `enrt_init_manhandla` + `enrt_update_manhandla`
                  carry the full INIT + UPDATE + helper pipeline. No
                  per-line transcription of un-drained branches needed
                  (contrast Task 8.3 Dodongo, where the State0/Sub_Wait
                  dispatchers were not drained).
- **Stance**:     ADOPT — drained Manhandla primitives consumed
                  verbatim. The only Phase 8 work is (a) wiring INIT +
                  UPDATE rows in `enemy_loop.c`, (b) registering
                  `enemy_manhandla_runtime.c` + `boss_manhandla.c`
                  in the Debug.md TU list, and (c) resolving four extern
                  primitives the drain references that don't have a
                  c_*-prefixed twin in the existing bridges.

## Wired pipeline

`src/game/enemies/enemy_loop.c`:

```c
[0x3C] = enrt_init_manhandla,    /* INIT */
[0x3C] = enrt_update_manhandla,  /* UPDATE */
```

Manhandla is a single-row enemy ($3C) — unlike Dodongo ($31/$32) and
Aquamentus / Patra / Lamnola pairs, NES tables only fan one row.

## Callee shims for the drain

`src/oracle/enemies/enemy_manhandla_runtime.c` references several
extern primitives via `enemy_runtime_private.h`. Most are already
present under c_*-prefixed names in the existing bridges:

| Drain extern | Resolved to | Bridge |
|--------------|-------------|--------|
| `c_turn_towards_player8` | inline native (uses ENEMY_THROWER_SLOT) | `enemy_flyer_bridge.c:297` |
| `c_check_monster_collisions` | `enrt_check_monster_collisions` adapter | `enemy_walker_bridge.c:166` |
| `c_reset_shove_info` | inline native (clears push timer + flags) | `enemy_flyer_bridge.c:128` |
| `c_shoot_fireball` | inline native (slot 7 spawn) | `enemy_boss_bridge.c:278` |
| `c_bound_flyer` | inline native (clamp to room bounds) | `enemy_jumper_bridge.c:65` |
| `c_draw_object_not_mirrored` | inline native | `enemy_projectile_bridge.c:21` |
| `z07_anim_fetch_obj_pos` | inline native | `enemy_projectile_bridge.c:99` |
| `z01_anim_set_sprite_desc_attrs` | inline native | `enemy_walker_bridge.c:212` |
| `Directions8` | linked data table | `enemy_flyer_bridge.c:72` |

Four are not present under c_*-prefixed names anywhere in the link.
`src/game/enemies/bosses/boss_manhandla.c` carries forwarders for them:

| Drain extern | Resolved to | Source |
|--------------|-------------|--------|
| `c_turn_randomly_dir8(slot)` | inline native (Z_04.asm:11859 transcription) | new |
| `c_play_boss_hit_cry_if_needed(slot)` | `enemy_play_boss_hit_cry_if_needed` | `enemy_dispatch.c:157` |
| `c_play_boss_death_cry()` | `enemy_play_boss_death_cry` | `enemy_dispatch.c:42` |
| `c_draw_object_mirrored(slot)` | `draw_object_mirrored(0u, slot)` | `draw_dispatch.c:408` |

The `c_turn_randomly_dir8` shim is the only new logic in
`boss_manhandla.c` — a 22-line per-line port of Z_04.asm:11859. Logic:

```c
GetObjDir8Index(slot) -> idx          /* find ENEMY_DIR in Directions8 */
rnd = ENEMY_RNG_B(slot)
if (rnd >= 0xA0) ;                    /* don't turn */
else if (rnd >= 0x50) idx = (idx + 1) & 7   /* INY: turn right */
else                  idx = (idx + 6) & 7   /* DEY DEY: turn left */
ENEMY_DIR(slot) = Directions8[idx]
```

The flyer-bridge has a private `flyer_get_obj_dir8_index` static helper
with identical logic, but it is not externalised. Inlining is cheaper
than promoting + including; this TU is the only Manhandla consumer.

## State / segment model

NES Manhandla occupies object slots 1..5:
- Slots 1-4 = hands ($3C ObjType each)
- Slot 5 = base ($3C ObjType, also dispatched via $3C row)

The base segment (slot 5) drives the global state:
- `Manhandla_SegmentJustDied` ($0383 = `ENEMY_MANHANDLA_SEGMENT_DIED_FLAG`)
  — incremented by check_collisions on hand death; consumed by base's
  speed-acceleration loop (adds $80 to each ObjSpeedFrac+1 entry).
- `Manhandla_BounceDir` ($0385) — written by post-move dir-change check
  on base; consumed by `set_all_segments_direction`.
- `$0384` (saved pre-move dir scratch) — base only.

Per-segment state ($0420/$042D for ObjSpeedFrac/Whole indexed at +1):
- `ObjSpeedFrac+1, Y` ($0420+Y for Y in 0..4)
- `ObjSpeedWhole+1, Y` ($042D+Y)

The base also picks turn-toward-player vs turn-randomly via
`ENEMY_RNG_A(slot) >= 0x80`, then copies the new dir to all hands +
the bounce dir.

## Frame / fireball gate (Z_04.asm:7919-7970)

After move + collision:

1. frame_bit = (`ENEMY_MANHANDLA_FRAME_ACCUM(slot)` & $10) >> 4
2. new_attrs = (`ENEMY_MANHANDLA_FRAME_ATTR(slot)` & $FE) | frame_bit
3. Base (slot 5) → draw and exit.
4. Hands: if attrs unchanged → draw. Else store new attrs into
   `Manhandla_ObjPrevFrame` (= `OBJ(0x0437, slot)` = `ENEMY_FLAP_PHASE`).
5. If frame_bit == 1 → draw.
6. If `ENEMY_RNG_B(slot)` < $E0 → draw.
7. If `ENEMY_TYPE(7)` != 0 → draw (fireball cap, max 4 in flight).
8. Else `c_shoot_fireball(86, slot)` (fireball type $56) then draw.

This faithfully matches the NES "max 4 fireballs" gate without exposing
slot-7 implementation in C — the drained `c_shoot_fireball` writes the
new fireball into slot 7.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean. New TUs added to the link set:
- `src/oracle/enemies/enemy_manhandla_runtime.c`
- `src/game/enemies/bosses/boss_manhandla.c`

## Live-room probe deferral

Same caveat as Tasks 8.2/8.3: in-emulator Level 2 (Manhandla room)
boss probe requires the `InitMode_EnterRoom` gameplay state machine
(`Z_05.asm:1700-1820`) to be wired through scroll / pause / shutter.
Tracked under Task 8.11 Boss Matrix.

## Status

CLOSE — Manhandla full INIT + UPDATE coverage. Drain consumed verbatim.
Single-row $3C dispatch wired. Four callee shims resolve the drain's
extern decls. No primitive gaps at link.
