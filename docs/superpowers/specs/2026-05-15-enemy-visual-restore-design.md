# Enemy Visual Restore — Design Spec

**Date:** 2026-05-15
**Status:** Draft
**Author:** Claude (Opus 4.7, caveman mode)
**Context commit:** `9b49b983` (smooth 60fps after native renderer)

## Context

The Genesis-native enemy renderer (commit `ba12e7c8`) replaces the
NES OAM-scatter bridge with a per-slot side-channel cache. The cache
captures the FIRST `anim_write_sprite` call per enemy slot per frame
(tile, attrs, x, y) and emits one Genesis SAT entry at `SIZE(1,2)`
8×16 per alive slot. Combined with downstream perf polish (commit
`9b49b983`), gameplay runs at smooth 60 fps even with 11 alive
enemies — but the simplification sacrifices several pieces of NES
Z1 visual fidelity.

This spec lays out a phased plan to restore full visual parity
without losing the 60 fps lock.

## Goals

1. Every NES Z1 enemy renders with the correct number of sprite
   tiles (no missing halves, hands, necks, satellites, heads).
2. Hit-flash palette cycles correctly during invincibility.
3. Death sparks and spawn clouds animate visibly.
4. Per-tile h_flip on multi-tile bodies (Aquamentus, etc.) lands
   on the right tile.
5. Frame-rate stays at smooth 60 fps in every reproducible scene.

## Non-goals

- No change to enemy AI behaviour (`enemy_loop_tick`, per-type update
  fns) — visuals only.
- No change to projectile rendering on sprite_render.c slots 0..9
  (already correct).
- No change to NES Z1 OAM-scatter writes inside
  `anim_write_sprite_drained` — the side-channel cache stays the
  consumed surface.

## Current visual gaps (recon summary)

| # | Gap                                  | Affected enemies                                     | Visual today              |
|---|--------------------------------------|------------------------------------------------------|---------------------------|
| 1 | Single-tile latch on >1 tile bodies  | Aquamentus 3×2, Dodongo body, individual large tiles | 1 tile only renders       |
| 2 | Death spark frames not written       | All dying enemies                                    | Vanish — no spark         |
| 3 | Spawn cloud frames not written       | All spawning enemies                                 | Pop in — no cloud         |
| 4 | Hit-flash palette frozen at latch    | All damaged enemies                                  | Stuck palette, no cycle   |
| 5 | Per-tile h_flip ignored              | Multi-tile bosses                                    | Mirrored tiles misaligned |
| 6 | Patra satellites have no slots       | Patra                                                | 8 satellites invisible    |
| 7 | Gleeok neck chain exceeds 11 slots   | Gleeok                                               | Necks beyond slot cap miss|
| 8 | Animation 1-frame lag                | Most walkers                                         | Acceptable, no fix        |

Slot-per-segment bosses (Manhandla = 5 slots) already render
correctly; the cache captures each segment independently.

## Approach

Phased commits, each ≤ ~250 LOC, each verified live with a probe.
Order chosen for risk: cheapest + most-visible first.

### Phase A — `SIZE(1,2)` → `SIZE(2,2)` for 16×16 enemies

Render each enemy at Genesis `SIZE(2,2)` 16×16 instead of `SIZE(1,2)`
8×16. NES Z1's 8×16-mode OAM pair stores the left half at tile `$XX`
(spanning `$XX, $XX+1`) and the right half at tile `$XX+2`
(spanning `$XX+2, $XX+3`). Genesis `SIZE(2,2)` at base tile `$XX`
reads four contiguous tiles `$XX..$XX+3` column-major — exactly the
NES pair layout if VRAM tile arrangement preserves the consecutive
ordering, which `roomrom_sprites_upload_persistent_chr` already does
for the `COMMON` block.

**Implementation:**
- `enemy_render_native_sweep` writes `RENDER_SPRITE_SIZE(2, 2)`.
- Verify x-offset: NES left-half OAM `x` is the visual left edge of
  the full 16×16 enemy. Genesis SAT `x` is also visual left edge.
  No offset adjustment needed.
- One-line code change plus visual verification.

**Risk:** non-square enemies (Aquamentus 24×16, single 8×8 sub-tiles)
won't fit `SIZE(2,2)`. Phase A leaves them as-is; Phase B fixes.

### Phase B — Per-`ENEMY_TYPE` size table

Some enemies use sizes other than 16×16. Add a const lookup table:

```c
static const unsigned char k_enemy_size[ENEMY_LOOP_TYPE_MAX] = {
    [ENEMY_TYPE_TEKTITE]    = RENDER_SPRITE_SIZE(2, 2),
    [ENEMY_TYPE_OCTOROCK]   = RENDER_SPRITE_SIZE(2, 2),
    [ENEMY_TYPE_AQUAMENTUS] = RENDER_SPRITE_SIZE(3, 2),  /* 24×16  */
    [ENEMY_TYPE_DODONGO]    = RENDER_SPRITE_SIZE(2, 2),
    [ENEMY_TYPE_GLEEOK_BODY]= RENDER_SPRITE_SIZE(4, 4),  /* 32×32  */
    /* ... default = RENDER_SPRITE_SIZE(2, 2) */
};
```

`enemy_render_native_sweep` looks up size by `ENEMY_TYPE(slot)`.
Default value for unmapped types stays `SIZE(2, 2)` (safe fallback).
Bigger enemies render as one Genesis SAT entry covering the whole
body via a single contiguous tile range in VRAM.

**Dependency:** confirm VRAM CHR upload places multi-tile enemy
tiles in contiguous column-major order. The atlas system
(`src/oracle/sprites/`) and `ROOMROM_SCENE_OBJ_TILE_BASE` layout
should preserve this — verify per-type before committing.

### Phase C — Hit-flash live refresh

Move the invincibility palette compute from cache-population time
(inside `anim_write_sprite_drained`) to render time (inside the
native sweep). Sweep reads `ENEMY_INVINCIBILITY(slot)` live, and
if non-zero, overrides the palette bits of `s_enemy_attrs[slot]`
with `FrameCounter & 0x03`.

**Implementation:**
- Drop the invincibility-palette branch in `anim_write_sprite_drained`.
- Add to native sweep:
  ```c
  unsigned char attrs = s_enemy_attrs[slot];
  if (ENEMY_INVINCIBILITY(slot) != 0u) {
      attrs = (attrs & 0xFC) | (RAM(NES_FRAME_COUNTER) & 0x03u);
  }
  ```
- Palette cycles every frame regardless of when the enemy last drew.

### Phase D — Death spark + spawn cloud frames

`update_meta_object` runs during the dying / spawning sequence but
doesn't call `anim_write_sprite`. Add a side-channel publish: when
metastate is non-zero, write the spark/cloud sprite frame directly
into `s_enemy_*` arrays, mark `s_enemy_seen[slot] = 1`.

**Implementation:**
- In `update_meta_object` (`src/game/enemies/enemy_walker_bridge.c`),
  add a `enemy_render_publish_meta(slot, frame)` call that fills the
  cache.
- Frame source: NES Z1 spark = 4-frame burst (tile $66..$68 or
  per-type death tile), cloud = 4-frame appear (tile $60..$62).
- Sweep already handles cache entries → no sweep changes.

### Phase E — Multi-latch array per slot

For enemies that need >1 tile per slot (Aquamentus 6-tile body,
Dodongo body+head segments), grow the cache from one entry per slot
to an array of up to 4. Each `anim_write_sprite_drained` call
appends; `s_enemy_count[slot]` tracks fill.

**Implementation:**
```c
#define ENEMY_RENDER_MAX_PER_SLOT  4u
static struct {
    unsigned char tile;
    unsigned char attrs;
    unsigned char x;
    unsigned char y;
} s_enemy_entries[ENEMY_LOOP_SLOT_LAST + 1u][ENEMY_RENDER_MAX_PER_SLOT];
static unsigned char s_enemy_count[ENEMY_LOOP_SLOT_LAST + 1u];
```

Native sweep iterates `slot × count[slot]`, emits N SAT entries.
Worst case: 11 slots × 4 entries = 44 SAT writes/frame (vs current
11, vs pre-native 50+). Stays under the H32 SAT capacity.

Phase A `SIZE(2,2)` upgrade handles the common case (most enemies
use 2 anim_write calls per frame = 1 paired Genesis sprite). Phase E
handles the residual.

**Per-tile h_flip (gap #5) resolves automatically** — each latched
entry stores its own attrs.

### Phase F — Patra satellites

NES Z1 Patra tracks 8 satellite positions in `PatraXFracs` /
`PatraYFracs` substrate (drained in `src/oracle/enemies/enemy_patra_runtime.c`).
The 8 satellites have no `ENEMY_LOOP_SLOT` slots — they're tracked
in a sub-array.

**Implementation:**
- In `enemy_patra_runtime.c` draw fn, after the body anim_write,
  loop 8 satellites and write each into a satellite-side cache.
- Add `enemy_render_patra_publish(idx, x, y, tile, attrs)`.
- Native sweep, after main slot loop, iterates Patra satellites
  if Patra is alive in any slot. Emit 8 SAT entries.

### Phase G — Gleeok neck chain

NES Z1 Gleeok has 4 necks, each with up to 6 segments. Segment
positions tracked in `GleeokNeckSegs` arrays. Total visible sprites:
1 body + 4 heads + up to 24 segment tiles = up to 29.

This **exceeds H32 SAT capacity** when combined with other
on-screen sprites. NES Z1 uses sprite priority + per-scanline limit
to gracefully drop low-priority segments.

**Implementation:**
- Per-segment cache similar to Patra satellites.
- Cap total Gleeok SAT writes at 20 (body + 4 heads + first
  4 segments per neck visible). Beyond → priority drop.
- Acceptable: NES does the same dropping on real hardware.

### Phase H — Verify + integrate

After each phase:
1. Build `Debug.bat` clean.
2. Live BizHawk verify: `vscroll_up_v2.lua` probe — must hold
   ≥58 fps effective game rate.
3. Visual screenshot diff for affected enemy types vs NES Z1
   capture in `tools/nes_capture/captures.json` library.
4. Per-phase commit message includes before/after fps + sprite
   count.

Final phase H also runs:
- `python tools/audit/drain_coverage.py`
- `python tools/gates/check_banned_filename.py`
- `python RoomRom/tools/verify_vram_budget.py`
- `python tools/run_regression_matrix.py`
- PD tracker `--record-out-of-phase` entry.

## Verification scenarios

Per phase, verify the affected enemy renders correctly:

| Phase | Enemy(ies)            | Scenario probe                              |
|-------|-----------------------|---------------------------------------------|
| A     | Tektite, Octorock     | OW room 0x77 — should now show full bodies  |
| B     | Aquamentus            | UW L1 boss room — full 3×2 mouth + flanks   |
| C     | Any walker            | Player sword hits enemy — palette cycles    |
| D     | Any walker            | Player kills enemy — spark frames visible   |
| E     | Aquamentus, Dodongo   | Multi-tile body fully rendered              |
| F     | Patra                 | UW L8 — 8 satellites orbiting               |
| G     | Gleeok                | UW L4 — body + heads + visible segments     |

Each scenario captures pre/post screenshots + fps; commit message
embeds the delta.

## Critical files

- `src/game/enemies/enemy_render.c` — native sweep + cache
- `src/game/enemies/enemy_render.h` — public surface
- `src/game/enemies/enemy_walker_bridge.c` — `update_meta_object`
- `src/oracle/enemies/enemy_patra_runtime.c` — satellite draw
- `src/oracle/enemies/enemy_gleeok_runtime.c` — neck draw
- `src/oracle/enemies/enemy_dodongo_runtime.c` — body draw
- `src/oracle/enemies/enemy_aquamentus_runtime.c` — body draw
- `src/state/enemy_state.h` — `ENEMY_*` macro consumers

## Out-of-scope follow-ups (deferred)

- True animation lag elimination (1-frame behind DRAW_FRAME) — only
  matters for tight rhythmic gameplay; defer.
- Boss-specific palette swaps (Aquamentus white-out on death,
  Ganon flash) — wire after Phase D base.
- Wallmaster grab animation — separate boss path, defer.
- Like-Like swallow animation — separate, defer.

## Assumptions

- VRAM tile layout: NES tile $XX and $XX+1 land in consecutive
  Genesis tiles, and OAM pair tiles ($XX, $XX+2) align with column-
  major Genesis `SIZE(2,2)`. Verify per-enemy-type before relying.
- Multi-latch (Phase E) max-4 cap is sufficient for current bosses.
  Gleeok requires a separate sub-array path (Phase G).
- 60 fps stays locked throughout: each phase < 4% added cost.
  Multi-latch + flash-refresh likely costs ≤2% combined.
