# RoomRom S7 — Sword Swing + Beam (Combat Baseline)

**Date:** 2026-04-30
**Status:** Draft (autonomous)
**Predecessor:** S6.5 real scroll
**Successor (planned):** S8 enemies (octorok / stalfos)

## Goal

Press A → Link swings sword in current facing. At "full HP" (RoomRom hard-codes
true since no health system yet) the swing emits a sword beam projectile that
travels in the facing direction for ~32 frames or until it leaves the screen.
NES-accurate timing, sprite layout, and beam animation. No enemy interaction
yet (S8).

## NES reference (from z_05.asm WieldSword + Z1 sprite docs)

| Phase | Frames | Effect |
|---|---|---|
| State 1 (extend) | 5 | Link's hand pose changes; sword sprite drawn at offset; beam spawns at frame 1 |
| State 2 (retract) | 1 | Sword sprite hidden; Link returns to walk pose |
| Cooldown | 0 | Re-swing allowed once state returns to 0 |

NES `$03D0+slot` = state countdown timer; `$00AC+slot` = state ID. Sword
slot = 13. (z_05.asm:WieldSword).

Sword sprite tile IDs (NES CHR pattern table 1 — `common_chr` + tile*32 in
RoomRom layout, **to be verified by probe** before implementation):

| Facing | NES tile | Notes |
|---|---|---|
| DOWN | $1C | 8x16 vertical sword, blade pointing down |
| UP | $1C + vflip | same tile, vflipped |
| LEFT | $1D | 8x16 horizontal, blade pointing left |
| RIGHT | $1D + hflip | same tile, hflipped |

Sword position offset from Link (16x16 sprite):

| Facing | Sword X offset | Sword Y offset |
|---|---|---|
| DOWN | 0 | +16 |
| UP | 0 | -16 |
| LEFT | -16 | 0 |
| RIGHT | +16 | 0 |

Sword beam (4-frame animation cycle, ~6 frames per anim frame):

- NES tile IDs cycle: $20, $21, $22, $23 (**probe to confirm**)
- Beam size: 16x16 (2x2 sprite)
- Beam velocity: 4 px/frame in facing direction
- Beam lifetime: until off-screen (no enemy hit yet — that's S8)
- Beam palette: PAL3 same as Link

## Architecture

New module `RoomRom/src/roomrom_combat.[ch]`:

```c
typedef enum {
    COMBAT_IDLE = 0,
    COMBAT_SWORD_EXTEND,   /* 5 frames */
    COMBAT_SWORD_RETRACT   /* 1 frame */
} combat_state_t;

void roomrom_combat_init(void);
void roomrom_combat_try_swing(link_face_t face, short link_x, short link_y);
void roomrom_combat_update(short link_x, short link_y, link_face_t face);
unsigned char roomrom_combat_link_locked(void);  /* 1 = swing in progress */
```

**Sprite slot allocation (Genesis SAT):**
- slot 0: Link (existing)
- slot 1: Sword (S7 new)
- slot 2: Beam (S7 new)
- slot 3: terminator

`roomrom_sprites.c` extended to:
- Upload sword tile ($1C) + 4 beam tiles ($20-$23) into LINK_VRAM_TILE region
  using same baked-flip approach used for Link poses
- Add `roomrom_sprites_set_sword_pose(face, x, y)` and `_clear_sword`
- Add `roomrom_sprites_set_beam_pose(frame, x, y)` and `_clear_beam`
- Multi-sprite `VDP_updateSprites(N, DMA)` with proper SAT link chain

**main.c** integration:

```c
/* Outside scroll/transition state */
u16 pressed_a = pressed & BUTTON_A;
if (pressed_a && !roomrom_combat_link_locked()) {
    roomrom_combat_try_swing(s_link_face, s_link_x, s_link_y);
}
roomrom_combat_update(s_link_x, s_link_y, s_link_face);

/* If combat_link_locked: skip movement update; Link's pose
 * frozen on the swing pose for state 1, returns on state 2. */
```

## Why this is best practices long-term

- **Single owner per gameplay system.** Combat owns sword + beam state. Link
  movement code in main.c stays untouched. Sprite uploads consolidated in
  `roomrom_sprites.c` (one CHR upload pass at boot).
- **NES-accurate timing.** State 1 = 5 frames matches z_05.asm:WieldSword.
  Beam velocity / lifetime probed live, not guessed.
- **Forward-compatible with S8.** Beam already has a position; S8 enemies add
  hit-test against beam bbox. No combat refactor needed.
- **No CHR runtime swap.** Sword + beam tiles uploaded once at boot
  (LINK_VRAM_TILE region grows by 5 tiles). Combat module flips SAT entries
  only.

## Verification (probe-driven)

Single Lua probe — `RoomRom/probe_nes_sword_capture.lua`:

1. Load NES Zelda 1 ROM (`Legend of Zelda, The (USA).nes`).
2. Load a savestate of Link with sword in OW (or, fallback: walk Link to
   start cave, get sword, exit — automated input sequence). Savestate path
   to be created by user once or generated on first run.
3. Walk Link to known-empty space.
4. Press A.
5. Capture each frame for 16 frames:
   - OAM dump
   - Screenshot
   - $00AC+13 (state) and $03D0+13 (timer) from RAM
6. Identify sword + beam OAM entries by tile-ID heuristic (NEW tiles that
   appear during swing, vs Link's tiles which are stable).
7. Output `tools/out/nes_sword_capture.json` with: tile IDs per facing,
   frame counts per state, beam velocity (Δposition / frame).

After implementation:

8. Build RoomRom, launch with sword probe lua: A press triggers swing in
   each facing, screenshot at peak extend frame.
9. Compare to NES capture screenshots (same facing, same frame). Identical
   sword sprite position + beam velocity = pass.

## Risks

| Risk | Mitigation |
|---|---|
| Sword/beam tile IDs guessed wrong | Probe captures actual NES tile IDs; spec values are placeholders until probe runs. |
| Beam goes off-screen but stays alive | Lifetime gate: despawn when X/Y outside playfield bbox (cols 0..31 * 8, play rows). |
| A button collides with existing UW level cycle (`A` toggles level 1..9) | Gate the level-cycle on `s_scene == SCENE_UW` AND `!combat_link_locked()` AND a held-modifier (e.g., `BUTTON_A | BUTTON_C`). Or split: A = swing always; SELECT (or held-A) = level cycle. Pick the simpler keymap pivot in implementation. |
| Sword sprite priority over door arch | Sword sprite uses same low priority as Link (PAL3, prio=0). Same NES feel — sword arc disappears behind door arch when extending across a doorway. |
| Multi-sprite SAT link chain | `VDP_updateSprites(3, DMA)` writes the chain; SGDK handles link field for sequential entries. Sword/beam slots can be hidden by setting Y to 0 (off-screen). |

## Out of scope

- Enemy hit detection (S8)
- Damage points / different sword tiers (white/magical) — S?
- Sword aura on critical HP (NES has no such effect; skip)
- Sound effects (audio system not yet wired in RoomRom)
- B-button items (boomerang, bombs, candle) — separate slice
