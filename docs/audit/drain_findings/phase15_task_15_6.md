# Phase 15 Task 15.6 — Sprite Hardware Optimization

- **NES source**: NES OAM = 64 sprites, 8 per scanline. Genesis SAT
                  = 80 sprites, 20 per scanline at 320 mode. NES
                  multi-OAM objects (e.g. Link 2x2 tiles) can collapse
                  into single larger Genesis sprites.
- **Drained C**:  Sprite render at `RoomRom/src/roomrom_sprites.c`
                  (37 KB) + per-subsystem OAM build sites. SAT link
                  ordering enforced inline during Phase 6.
- **Coverage**:   PARTIAL — multi-OAM-collapse work happened inline
                  during Phases 6-8 per-subsystem (Link, items,
                  bosses, enemies). Stress probes for enemy-heavy /
                  boss+projectiles / 4-player NOT yet shipped.
                  Phase 13 sprite-budget pre-flight already computed
                  (56 of 80 SAT entries under multiplayer worst-case).
- **Stance**:     PARTIAL — collapse work ADOPT; stress probes
                  deferred.

## Deferred stress probes

| Probe                              | Scope                                    |
|------------------------------------|------------------------------------------|
| `probe_enemy_heavy_room_sprites`   | 11-slot enemy density + 4-corner spawn   |
| `probe_boss_with_projectiles`      | Gleeok 4-neck + fireballs (max OAM load) |
| `probe_4player_with_enemies`       | gated on Phase 13 (DEFERRED_FEATURE)     |

## Status

CLOSE (with stress-probe deferral) — Task 15.6 inline 15a collapse
work in tree; stress probes deferred.
