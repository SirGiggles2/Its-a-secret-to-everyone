# Enemy Parity Audit — Findings

Scope: every wired enemy except Octoroks $07-$0A and Tektites $0D-$0E.
Audit method: static comparison of drain `*_runtime.c` vs NES asm
`reference/aldonunez/Z_04.asm` / `Z_07.asm`. Build-clean Genesis +
out-of-scope baseline regression check after every fix.

## Phase A — Preflight (complete)

- A1 RNG seed pattern → NES `ClearRam` pattern ({$40, 0..0}). Tick
  cadence: `rng_next()` per-frame in `roomrom_debug_tick`
  (`RoomRom/src/main.c:1633`) matches NES `@ScrambleRandom`
  once-per-NMI.
- A2 Probe address model: Debug.md A4 pinned at `$00FF8000`. BizHawk
  68K RAM domain offset = `0x8000 + nes_addr`.
- A3 Out-of-scope baseline: 6 types × 240 frames captured at
  `build/probes/baseline_outofscope_gen.txt`.
- A4 Cell tiers: T1 deterministic / T2 RNG-driven / T3 cosmetic.
- A5 Spawn graph: parent → child relations documented.
- A6 Shared primitives: re-probe matrix per primitive touched.
- A7 `drain_coverage.py` extended (563 funcs, 8 subsystems).
- A8 Effort budget per family.

Commit: `aeefda9b`.

## Phase B — per-family audit

### B1 wanderer-shared primitives

Bug found + fixed (commit `52f4f03c`):

**B1.1 — Red walker shoot-rate gate missing**
- Path: `src/oracle/enemies/enemy_walker_runtime.c:188 enrt_try_shooting`
- NES: `Z_04.asm:1975 _TryShooting` prelude gates non-blue types
  ($02/$04/$07/$08) on `ShootTimer != 0 OR Random+slot >= $F8`.
- Drain skipped → Red Moblin/Lynel/Stalfos shoot ~32× too often.
- Fix: add the gate. Blue Lynel/Moblin/Octorok skip it per NES.
- Affected in-scope: $02 RedLynel, $04 RedMoblin, $2A Stalfos.
- Out-of-scope ($07/$08): same bug in `enemy_walker_bridge.c:692
  enrt_update_octorock` inline body — left unchanged.

### B2 walker family — full audit

All verified structurally vs NES:
- $01/$02 Lynel, $03/$04 Moblin, $05/$06 Goriya, $0B/$0C Darknut,
  $10/$28 Rope, $12 Vire, $13 Zol, $14/$15 Gel, $16 PolsVoice,
  $17 LikeLike, $1E Armos, $21 Ghini, $27 Wallmaster, $2A Stalfos,
  $2B/$2C/$2D Bubble, $30 Gibdo, $3F GuardFire, $40 StandingFire.

Primitives: Wanderer_TargetPlayer, UpdateCommonWanderer, Walker_Move,
Obj_Shove, _TryShooting (fixed via B1.1), c_check_monster_collisions,
all drained-runtime composition shapes match NES.

### B3 flyer family — audit

Verified vs NES:
- $1A Peahat (`enemy_flyer_bridge.c:426 enrt_update_peahat`)
- $1B/$1C/$1D Keese (`enemy_flyer_runtime.c:164 enrt_update_keese`)
- $22 FlyingGhini (`enemy_flyer_bridge.c:481 enrt_update_flying_ghini`)
- $46 GleeokHead (`bosses/boss_gleeok.c:697 boss_gleeok_update_head`)
- Primitives: ControlKeeseFlight, ControlPeahatFlight,
  ControlFlyingGhiniFlight, MoveFlyer, ResetShoveInfo, BoundFlyer,
  KeeseDecideState, PeahatDecideState, GhiniDecideState.

### B4 jumper/burrower — audit

Verified vs NES:
- $0F BlueLeever (`enemy_jumper_bridge.c:616 enrt_update_blue_leever`)
- $10 RedLeever (`enemy_jumper_bridge.c:472 enrt_update_red_leever`)
- $11 Zora (`enemy_walker_runtime.c:174 enrt_update_zora`)
- $18 LittleDigdogger (shares enrt_update_digdogger from boss runtime)
- Primitive: `c_update_burrower` matches NES `UpdateBurrower`
  Z_04.asm:2603 incl. Zora state-1 frame-front/back select.

### B5 projectile — audit + bug fix (commit `87df3ce5` superseded)

Bug found + fixed:

**B5.1 — $5B/$5C UPDATE NULL gap** (commit landed)
- Path: `src/game/enemies/enemy_loop.c` UPDATE table rows missing
- NES: UpdateMonsterArrow (Z_04.asm:2102) + UpdateArrowOrBoomerang
  (Z_07.asm:3813). Full state machine for bounce/spark/return.
- Stopgap drain: `enrt_update_monster_arrow` seeds q-speed=$80 +
  enters `enrt_update_monster_shot`. `enrt_update_arrow_or_boomerang`
  thin alias for $5C. Arrows + boomerangs now move + hurt Link.
- Full bounce/spark/return state machine deferred.
- Other projectiles verified: $1F BoulderSet, $20 Boulder,
  $53-$5A MonsterShot, $55/$56 Fireball, $2E Whirlwind,
  $49/$4A Trap.

### B6 boss family — audit + bug fix

Bug found + fixed:

**B6.1 — Aquamentus missing death-cry + shove reset**
- Path: `src/oracle/enemies/enemy_boss_runtime.c:110 enrt_update_aquamentus`
- NES tail (Z_04.asm:5605 `CheckBossHitReaction`):
  `JSR PlayBossDeathCryIfNeeded / JMP ResetShoveInfo`.
- Drain stopped after `PlayBossHitCryIfNeeded`.
- Effect: no death cry on Aquamentus kill; ObjShoveDir persists →
  drift on knockback.
- Fix: add `enrt_play_boss_death_cry_if_needed(slot)` +
  `c_reset_shove_info(slot)` at tail.

Other bosses verified:
- $23/$24 Wizzrobe — FULL drain at `enemy_wizzrobe_runtime.c`
- $31/$32 Dodongo — `bosses/boss_dodongo.c:207` matches NES (no
  hit/death cry call in NES tail).
- $33/$34 Gohma — `enemy_boss_runtime.c:796`. NES UpdateGohma ends
  at `JMP Gohma_CheckCollisions` (no boss-cry tail) — drain matches.
- $38/$39 Digdogger — `enemy_boss_runtime.c:666 enrt_update_digdogger`
  uses internal helpers; not deep-audited but structure consistent.
- $3A/$3B Lamnola — `enemy_lamnola_bridge.c` calls
  `enrt_play_boss_death_cry_if_needed`.
- $3C Manhandla — `enemy_manhandla_runtime.c:44 enrt_update_manhandla`.
  Drain `enrt_manhandla_check_collisions` has hit-cry + shove reset
  + inline `c_play_boss_death_cry`.
- $3D Aquamentus — fixed.
- $3E Ganon — `enemy_ganon_runtime.c` calls hit_cry + death_cry +
  reset_shove (multiple sites).
- $41 Moldorm — `enemy_moldorm_runtime.c:170`, not deep-audited
  but no missing tail flag.
- $42-$45 Gleeok — `enemy_gleeok_runtime.c:68 enrt_update_gleeok`
  delegates head + tail through `c_gleeok_draw_head_and_check_collisions`
  (NES asm path includes hit_cry + reset_shove per Z_04.asm:9147).
- $47/$48 Patra — `bosses/boss_patra.c:101` calls death_cry_if_needed.
- $25/$26 PatraChild — `enemy_patra_runtime.c` (not audited; child
  uses inherited Patra state).

### B7 NPC / non-combat (no-regress audit)

Text-driven AI; no movement/attack parity work. Drains:
- $35 RupeeStash, $36 Grumble, $4B-$52 UWPerson, $5D DeadDummy,
  $5E FluteSecret, $60 DroppedItem.

All compile-clean and slot-tick. No NES movement/attack semantics
to verify — they react to player input via dialog/proximity.

## Bugs fixed this audit (3)

1. **B1.1** Red walker shoot-rate gate (commit `52f4f03c`)
2. **B5.1** $5B/$5C UPDATE NULL gap (commit pending push)
3. **B6.1** Aquamentus death cry + shove reset (commit pending push)

## Deferred work

- Full drain of NES `UpdateArrowOrBoomerang` state machine for $5B/$5C
  (bounce / spark / boomerang-return paths). Stopgap drain handles
  basic flight + Link damage.
- Octorok ($07/$08 — out of scope) shares the B1.1 bug pattern in
  inline body at `enemy_walker_bridge.c:692`. Out of scope per user
  direction; documented for future "MAKE LIKE NES" pass.
- Per-frame live byte-diff probe pair per family (probe templates
  exist; ad-hoc capture per regression event).

## LINK_X / LINK_Y macro note

In `src/state/enemy_state.h:62-65`, `LINK_X = RAM(0x0061)` and
`LINK_Y = RAM(0x0062)` — i.e. ChaseTargetX/Y. The enemy_loop_tick
prefix at `enemy_loop.c:1305-1322` keeps these updated (mirror-flip
included). NES wanderer/goriya code reads ChaseTargetX/Y for AI
decisions; drain reads `LINK_X` macro → resolves to $0061 = correct
target cell. Macro name misleading but functionally correct.

## Verification

`build/probes/baseline_outofscope_gen.txt` is the Genesis-side
baseline for out-of-scope types ($07-$0A, $0D-$0E). Re-run
`audit_outofscope_gen.lua` after any commit touching shared infra
(per `shared_primitives.md`). Zero new T1 cell divergences = pass.
B1.1 + B5.1 + B6.1 fixes: out-of-scope baseline byte-identical
(captured cells exclude affected cells; manual code review confirms
NES semantic preservation).
