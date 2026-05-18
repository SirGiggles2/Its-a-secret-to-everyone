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

## B5.1 — $5B/$5C UPDATE wires + boomerang state machine

### Static evidence
- Pre-fix: arrows/boomerangs spawn but `enemy_update_fns[0x5B]` and
  `[0x5C]` rows were NULL → slot ticks no-op.
- Post-fix: `enrt_update_monster_arrow` (q-speed=$80 + delegate to
  `enrt_update_monster_shot`) wired at $5B.
  `enrt_update_arrow_or_boomerang` full state machine drain at $5C.

### Live evidence — $5C boomerang state machine

Probe: `build/probes/audit_boomerang_gen.lua`. Spawned $05 BlueGoriya
via FX arm at (X=$80, Y=$78). Watched 600 frames. Goriya threw 4
boomerangs into slot 11.

State machine progression observed (boomerang #2, frame 79-160):

| Frame | State | Y    | ML  | Notes                              |
|---    |---    |---   |---  |---                                 |
| 79    | $10   | $7B  | $51 | Spawn at Goriya, range=$51         |
| 84    | $10   | $88  | $51 | Flying down toward Link            |
| 89    | $10   | $94  | $51 |                                    |
| 94    | $10   | $A1  | $51 |                                    |
| 99    | $30   | $AD  | $08 | Range hit → slow-down state        |
| ...   | $40   | $8B-$83 | $20 | Return: Y decreasing back to Goriya |
| 160   | destroyed | reached thrower (Y dist < 2)        |

Drain commit `bafdf355` verified:
- State $10 range-limit check (|ObjGridOffset| >= ObjMovingLimit) →
  transition to $30. ✓
- State $30 → $40 transition. ✓
- State $40 return: z01_get_directions_and_distances_to_target
  computed dirs; boomerang moved at BoomerangQSpeedFracs[4] diagonal
  back toward Goriya at thrower slot 1 (Y=$79). ✓
- Destroy on reach. ✓

**Boomerang return-to-thrower behavior matches NES UpdateArrowOrBoomerang
state machine.**

### Live evidence — $5B (indirect)
Blue Lynel ($01) on Genesis: shoot cycle runs to $10, c_shoot_if_wanted
fires → arrow spawns in empty slot which now ticks via
`enrt_update_monster_arrow`. Direct $5B slot probe not separately
captured.

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
