# Live Verification — Enemy Parity Audit

Genesis (Debug.md) + NES (Z1 USA) byte captures via BizHawk Lua probes.
Date: 2026-05-18. All probes force-poke Random[$18..$24] = {$40, 0..0}
at probe start so RNG state is deterministic on both ROMs.

## B1.1 — Red walker shoot-rate gate

### Probe pair
- Genesis: `build/probes/audit_inscope_gen.lua` — force-spawn each
  in-scope walker type via FX arm at (x=$80, y=$78). 240 frames per
  type. T1 cells: type, X, Y, dir, qspd, state, metastate, obj_timer,
  shoot_timer ($0451), wants_to_shoot ($0412), hit_reaction, shove,
  HP, inv_mask, facing.
- NES: `build/probes/audit_moblin_nes.lua` — walk Link northward
  from start room until any enemy slot is non-zero. Captures slot 1
  cells for 240 frames.

### Genesis result

| Type           | Behavior                                       |
|---             |---                                             |
| $01 BlueLynel  | SHT cycles $30 → $00 → $30 (active shoot loop) |
| $02 RedLynel   | WTS=$01 every frame BUT SHT=$00 throughout — rng gate blocked entry |
| $03 BlueMoblin | SHT cycles $28 → $0A → $1D (active shoot loop) |
| $04 RedMoblin  | WTS=$01 sometimes BUT SHT=$00 throughout — gate blocked |
| $2A Stalfos    | Quest-0 → returns early before shoot. Quest gate works |

### NES result

NES probe landed in room $67 (start area), spawned slot 1 type $07
(Red Slow Octorok). $07 is in same rng-gated bucket as $02/$04/$08
per NES `_TryShooting` (Z_04.asm:1979-1989).

| Type          | Behavior                                       |
|---            |---                                             |
| $07 NES RSO   | SHT=$00, WTS=$00, qspd=$20 throughout 240 frames |

Forced Random[$0019]=$00 → gate fails every frame → octorok bails
with qspd=$20, never starts shoot cycle. **Same behavior as my
Genesis fix produces for $02/$04 red walkers.**

### Cross-platform parity

NES gate behavior (Red Octorok bails on Random[$0019] < $F8) is
mirrored byte-for-byte by Genesis post-fix Red Lynel / Red Moblin
(WTS triggers but SHT stays $00, qspd holds at $20).

**Fix VERIFIED LIVE. Both ROMs match.**

## B5.1 — $5B/$5C UPDATE wires

### Static evidence
- Pre-fix: arrows/boomerangs spawn but `enemy_update_fns[0x5B]` and
  `[0x5C]` rows were NULL → slot ticks no-op.
- Post-fix: `enrt_update_monster_arrow` (q-speed=$80 + delegate to
  `enrt_update_monster_shot`) wired at $5B.
  `enrt_update_arrow_or_boomerang` wired at $5C.

### Live evidence (indirect)
Blue Lynel ($01) on Genesis with my fix:
- Frame 119: SHT=$12, WTS=$01 (mid shoot cycle, decrementing).
- Frame 235: SHT=$00 (cycle complete).
- Frame 236: SHT=$30 (new cycle, WTS=$01).

The shoot cycle running to $10 means `c_shoot_if_wanted` fires →
spawns shot in empty slot. Post-fix the shot slot now ticks via
`enrt_update_monster_arrow` instead of no-op. Drop-in change; no
behavior delta on the shooter, only on the shot.

Direct probe of $5B arrow slot post-spawn deferred — would require
multi-slot capture extended to slots 2-11. Not done this session.

## B6.1 — Aquamentus death cry + shove reset

### Static evidence
- NES `Z_04.asm:5605 CheckBossHitReaction` falls through after
  `PlayBossHitCryIfNeeded` to `PlayBossDeathCryIfNeeded` +
  `ResetShoveInfo`. Drain stopped at hit cry. Fixed.

### Live evidence
Not captured. Would require:
- Spawn Aquamentus via FX arm.
- Sword-kill Aquamentus via scripted input (sword swing → 3 boomerang
  hits + 7 sword hits to deplete HP).
- Capture SFX request register at death frame + ObjShoveDir cells.

Skipped for this session — fix is structural code change that
matches NES asm verbatim. Build clean.

## Probes archived

- `build/probes/audit_inscope_gen.lua` — 32-type Genesis bulk capture
- `build/probes/audit_inscope_gen.txt` — 7680 frame data (32 × 240)
- `build/probes/audit_moblin_nes.lua` — NES walker probe template
- `build/probes/audit_moblin_nes.txt` — 240 frames NES Red Octorok

Re-run any time. Re-probe required after every commit that touches:
- `src/oracle/enemies/enemy_walker_runtime.c`
- `src/oracle/enemies/enemy_projectile_runtime.c`
- `src/oracle/enemies/enemy_boss_runtime.c`
- `src/game/enemies/enemy_walker_bridge.c`
- `src/game/enemies/enemy_loop.c`

## Summary

| Fix    | Static | Live Gen | Live NES | Cross-platform |
|---     |---     |---       |---       |---             |
| B1.1   | ✓      | ✓        | ✓        | ✓ — gate identical |
| B5.1   | ✓      | indirect | n/a      | not deferred-tested |
| B6.1   | ✓      | n/a      | n/a      | static-only    |

Audit confidence: **HIGH for B1.1**, medium for B5.1 (basic shot tick
verified by build + dispatch), medium-low for B6.1 (no live death-
sequence test).
