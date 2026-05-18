# Enemy Parity Audit — Findings (in-progress)

Scope: every wired enemy except Octoroks $07-$0A and Tektites $0D-$0E.
Audit method: static comparison of drain `*_runtime.c` vs NES asm
`reference/aldonunez/Z_04.asm` / `Z_07.asm`. Build-clean Genesis +
out-of-scope baseline regression check after every fix.

## Phase A — Preflight (complete)

- A1 RNG seed pattern → NES `ClearRam` pattern ({$40, 0..0}). Tick
  cadence: `rng_next()` per-frame in `roomrom_debug_tick`
  (`RoomRom/src/main.c:1633`) matches NES `@ScrambleRandom` once-per-NMI.
- A2 Probe address model: Debug.md A4 pinned at `$00FF8000`. BizHawk
  68K RAM domain offset = `0x8000 + nes_addr`.
- A3 Out-of-scope baseline: 6 types × 240 frames captured at
  `build/probes/baseline_outofscope_gen.txt`. Re-run after each
  shared-infra commit + diff.
- A4 Cell tiers: T1 deterministic / T2 RNG-driven / T3 cosmetic.
- A5 Spawn graph: parent → child relations documented.
- A6 Shared primitives: re-probe matrix per primitive touched.
- A7 `drain_coverage.py` extended to scan `src/oracle/**/*_runtime.c`.
  Now 563 drained funcs across 8 subsystems (was 63).
- A8 Effort budget: per-family timebox; abort if > 50% T1 cells
  diverge after shared-primitive fix.

Commit: `aeefda9b` enemy parity Phase A.

## Phase B1 — wanderer-shared primitives (audited)

Wanderer family + boss consumers share:
`enrt_wanderer_target_player`, `enrt_update_common_wanderer`,
`c_walker_move`, `c_obj_shove`, `c_check_monster_collisions`,
`enrt_try_shooting`.

### Bugs found + fixed

**B1.1 — Red walker shoot-rate gate missing**
- Path: `src/oracle/enemies/enemy_walker_runtime.c:188 enrt_try_shooting`
- NES: `Z_04.asm:1975 _TryShooting` prelude gates non-blue types
  ($02/$04/$07/$08) on `ShootTimer != 0 OR Random+slot >= $F8`.
- Drain skipped the gate → Red Moblin / Red Lynel / Stalfos enter
  shoot-prep cycle every wants-to-shoot frame (~32× too often).
- Fix: add the gate at top of `enrt_try_shooting`. Blue Lynel ($01),
  Blue Moblin ($03), Blue Slow Octorock ($09), Blue Fast Octorock
  ($0A) skip the gate per NES.
- Affected in-scope: $02 RedLynel, $04 RedMoblin, $2A Stalfos.
- Octorok inline body (`enemy_walker_bridge.c:692 enrt_update_octorock`)
  has same bug — out of scope so left unchanged.
- Out-of-scope baseline unchanged (captured cells exclude
  ShootTimer/WantsToShoot).
- Commit: `c4d0e35e` (or similar — see git log).

### Drains verified structurally vs NES

These drains compared line-by-line vs NES asm. No additional bugs:

| Type IDs        | Drain location                               | NES asm                          |
|---              |---                                           |---                               |
| $01/$02 Lynel   | `enemy_walker_runtime.c:243 enrt_update_lynel` | `Z_04.asm:1965 UpdateLynel`     |
| $03/$04 Moblin  | `enemy_walker_runtime.c:234 enrt_update_moblin` | `Z_04.asm:1956 UpdateMoblin`   |
| $05/$06 Goriya  | `enemy_wanderer_runtime.c:169 enrt_update_goriya` | `Z_04.asm:424 UpdateGoriya`   |
| $0B/$0C Darknut | `enemy_walker_runtime.c:281 enrt_update_darknut` | `Z_04.asm:6474 UpdateDarknut`  |
| $10/$28 Rope    | `enemy_walker_runtime.c:97 enrt_update_rope` | `Z_04.asm:4549 UpdateRope`       |
| $13 Zol         | `enemy_common_runtime.c:59 c_update_zol_state` | `Z_04.asm:1235 UpdateZol`      |
| $14 RedZol      | (alias to Gel — `enemy_walker_runtime.c:163 enrt_update_gel`) | `Z_04.asm:UpdateGel` |
| $15 Gel         | `enemy_common_runtime.c:158 enrt_gel_move`   | `Z_04.asm:1381 UpdateGel`        |
| $21 Ghini       | `enemy_walker_runtime.c:341 enrt_update_ghini` | `Z_04.asm:3067 UpdateGhini`    |
| $2A Stalfos     | `enemy_walker_runtime.c:248 enrt_update_stalfos` | `Z_04.asm:4670 UpdateStalfos` |
| $2B/$2C/$2D Bubble | `enemy_walker_runtime.c:14 enrt_update_bubble` | `Z_04.asm:UpdateBubble`       |
| $30 Gibdo       | `enemy_common_runtime.c:22 enrt_update_gibdo` | `Z_04.asm:6464 UpdateGibdo`     |
| $40 StandingFire | `enemy_walker_runtime.c:146 enrt_update_standing_fire` | `Z_04.asm:257`         |
| Wanderer shared | `enemy_wanderer_runtime.c:63 enrt_wanderer_target_player` | `Z_04.asm:300 Wanderer_TargetPlayer` |
| Walker move     | `enemy_walker_bridge.c:72 c_walker_move`     | `Z_07.asm:2555 Walker_Move`      |
| Shove           | `enemy_walker_bridge.c:258 c_obj_shove`      | `Z_07.asm:2274 Obj_Shove`        |

### LINK_X / LINK_Y macro note

In `src/state/enemy_state.h:62`, `LINK_X = RAM(0x0061)` and
`LINK_Y = RAM(0x0062)` — i.e. ChaseTargetX/Y, not the actual Link's
position at $0070/$0084. This is intentional per NES code that uses
ChaseTarget for AI decisions. The macro name is misleading but
behavior is correct.

In `src/state/world_state.h:65-66` the SAME macros are redefined as
the real Link position. Causes `-Wmacro-redefined` warnings during
build. Not a bug, but confusing.

## Phase B2-B7 — pending

Static audit of remaining in-scope walker types (Vire $12,
PolsVoice $16, LikeLike $17, Armos $1E, Wallmaster $27) deferred to
next session. Flyer, jumper, projectile, boss, NPC families also
pending.

Static audit pattern: read NES asm body, read drain body, compare
line-by-line. Bug pattern of "missing rng/type gate" already found
once (B1.1) — actively look for it elsewhere.

## Verification gate

Phase A out-of-scope baseline (`build/probes/baseline_outofscope_gen.txt`)
captured with current Debug.md. After every commit that touches
shared infra (per `shared_primitives.md`), re-run
`audit_outofscope_gen.lua` and diff. Zero new T1 divergences = pass.

B1.1 fix: baseline unchanged (captured cells don't include the cells
affected by the fix — ShootTimer/WantsToShoot/WalkSpeed only when
ShootTimer triggers). Manual code review confirms fix preserves NES
semantics.
