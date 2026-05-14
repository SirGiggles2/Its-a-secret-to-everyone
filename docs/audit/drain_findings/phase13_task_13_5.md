# Phase 13 Task 13.5 — Multiplayer Combat

- **NES source**: N/A — Genesis-only.
- **Drained C**:  N/A — no implementation yet.
- **Coverage**:   NONE.
- **Stance**:     DEFERRED_FEATURE.

## Plan (when picked up)

1. **Multiple swords.** Each player's sword swing is a separate
   projectile slot. Sword beam reuses existing
   `roomrom_combat.c` (post-Phase-12 promote: `src/game/combat/`)
   per-player.
2. **Multiple item uses.** Each player has a cooldown on their
   active B-item. Resource consumption (bombs / arrows / candle)
   still pulls from shared inventory.
3. **Enemy targeting.** Wanderers / Walkers / Flyers retarget on
   nearest live player every N frames. Existing
   `enrt_wanderer_target_player` (drained) extends to take a
   player-index arg.
4. **Boss targeting.** Bosses pick lowest-index live player as
   target by default; can be overridden by per-boss heuristic
   (e.g. closest, lowest-HP).
5. **Drop pickup.** First player to touch a drop claims it (writes
   to shared inventory).
6. **VBlank + sprite budget.** Re-verify under multiplayer dense
   scenario (4 players + 4 enemies + 2 boss heads) — must stay
   under cycle ceiling. Per-frame instrumentation from Phase 15.1.

## Status

DEFERRED_FEATURE — gated on Tasks 13.1-13.4.
