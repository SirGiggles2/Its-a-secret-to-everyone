# Phase 13 Task 13.4 — Multiplayer Rules

- **NES source**: N/A — Genesis-only.
- **Drained C**:  N/A — no implementation yet.
- **Coverage**:   NONE.
- **Stance**:     DEFERRED_FEATURE.

## Rule decisions (per master plan + PrimeDirective default)

| Rule                       | Decision                                           |
|----------------------------|----------------------------------------------------|
| Inventory                  | **Shared** — single bag of items / keys / bombs / rupees. Simplifies UI; matches NES philosophy of "Link's quest." |
| Rupees / bombs / keys      | **Shared** (with inventory).                       |
| Hearts                     | **Per-player** — independent HP for playability.  |
| Same-room constraint       | **Yes** — only one screen at a time, lead player drives transitions. |
| Screen transition          | When lead player exits, pull trailing players to the corresponding entry edge. |
| Trailing player pull-to    | Snap to nearest valid walkable tile on entry edge. |
| Friendly collision         | **Disabled** by default — players can pass through each other. Option flag for hardcore mode. |
| Revive / death             | Per-player dead state; revive by stepping on a heart container drop or fairy fountain. Total wipe = game over. |

## Implementation plan (when picked up)

1. `players[i].hearts` per-player; `inventory_t g_inventory`
   stays shared.
2. `lead_player` index updated on screen-transition cross.
3. `transition_pull_trailing()` runs after `world_transition`
   finishes; iterates players, snaps to nearest walkable on entry
   edge.
4. `players[i].is_alive` boolean; render path skips dead
   players, collision path skips dead players.
5. Revive: when any player picks up a heart container drop while
   another player is dead, that dead player respawns with 3
   hearts.

## Status

DEFERRED_FEATURE — gated on Tasks 13.1 / 13.2 / 13.3.
