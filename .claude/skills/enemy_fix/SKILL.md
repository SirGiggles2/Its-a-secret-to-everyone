---
name: enemy_fix
description: Systematic NES vs Genesis enemy parity fix. Probe both ROMs, byte-diff state, port missing NES calls. Use for any enemy type that behaves wrong on Genesis.
argument-hint: <enemy_type_hex_or_name>
user-invocable: true
---

# enemy_fix — Systematic NES vs Genesis Enemy Parity

## Pattern

For any enemy type that misbehaves on Genesis:

### Phase 1: Probe NES (truth)

Capture live state at exact spawn moment:
- `build/probes/subpix_nes3.lua` style (boot dance + walk to target room)
- Domain = `"RAM"` for NES Z1
- Dump per slot: type, X, Y, dir, qspd, frac, grid, mvTm, stTm, meta, shTm, wTSh, bnc, hit, inDir
- Dump globals: LinkX/Y, ChaseTargetX/Y ($61/$62), RNG ($18..$1A), ObjectFirstUnwalkableTile ($34A)

### Phase 2: Probe Genesis (current)

Same probe shape, domain = `"68K RAM"`, addresses offset +$8000:
- NES $0070 → Genesis $8070 (etc.)
- NES $034F → Genesis $834F
- NES $00EB (RoomId) → Genesis $80EB (NOT $7205 — that's probe-arm magic)

### Phase 3: Byte-diff

`paste <(awk ...nes) <(awk ...gen)` over 60-240 frames. Find first divergent cell.

### Phase 4: Port missing NES call

Common divergence patterns:

| Symptom | Root cause | Fix |
|---|---|---|
| Stuck X/Y, mvTm dec rate ≠ NES | Double-decrement (main.c NMI port + drained dec) | Remove duplicate dec |
| Walker picks wrong dir at init | ChaseTargetX/Y = $00 (NES @CheckChaseTarget not ported) | Add NES Z_07.asm:1855-1914 logic at top of enemy_loop_tick |
| Wrong subpixel accumulation | qspd init wrong / MoveObject path differs | Verify enrt_init_* sets qspd matching NES enum |
| Spawn position drift | ObjectFirstUnwalkableTile wrong | OW=$89, UW=$78 per `ObjectRoomBoundsOW/UW[4]` |
| No damage on body bump | Missing `c_check_monster_collisions` per slot | Add gated call in enemy_loop_tick (gate on metastate==0 + ObjAttr bit 0 == 0) |
| Spawn cloud anim wrong frames | metastate=$01 setup BEFORE init_fn overrides ObjTimer | Order: preamble first, fn(slot) last |
| Cloud renders wrong palette | Common SPR bank has only sub-pal 0 bias | Add biased CHR copy (see k_cloud_chr_subpal1 in enemy_render.c) |
| Enemy stuck flashing | ObjInvincibilityTimer ($04F0+slot) never decremented | Add gated dec in enemy_loop_tick (every 2 frames via FrameCounter bit 0) |
| Wrong tile on rock projectile | InitObject preamble +1 on anim_idx | NES INY before anim lookup |

### Phase 5: Verify

Re-run probes, byte-diff again. Confirm cells match NES.

## Hard rules

- NEVER guess. Probe NES live first, every time.
- Genesis address = NES address + $8000 (NES RAM mapped at A4=$FF8000).
- NES BizHawk domain = `"RAM"` (not "WRAM" — fallback path).
- Genesis BizHawk domain = `"68K RAM"`.
- BizHawk Lua `IS_GEN` auto-detect runs BEFORE ROM domains load. Hardcode per-ROM probe.
- Pre-existing per-type collision calls in enemy_walker_bridge etc. — don't double-call when bit 0 of ObjAttr is set.

## Already-fixed shared infrastructure

These global fixes apply to ALL enemy slots/types:
- `enemy_loop_tick` prefix: @CheckChaseTarget port + ObjInvincibilityTimer dec
- `enemy_loop_room_init`: scroll-glitch guard, spawn cloud setup order, floor threshold
- `c_shoot_if_wanted`: ObjectTypeToAttributes lookup for $53-$5C
- `update_meta_object`: NES @AnimateCloud/@AnimateSpark verbatim

Don't re-port these. Build on them.

## Enemy types to fix

Per project punchlist:
- $03/$04 Moblins — anim/draw deferred
- $11 Zora — UpdateBurrower deferred
- $1E Armos + $22 Flying Ghini — init deferred
- $27 Wallmaster — grab mechanic
- $17 LikeLike — shield-eat
- Bubble — disable-sword timer
- Bosses (boss_framework.c LBA_D push-block stub)

Approach each one with this protocol. Probe, diff, port, verify.

## Workflow

1. User invokes `/enemy_fix $XX` (type id) or by name
2. Write per-ROM probes (NES + Genesis variants)
3. Run both ROMs, capture 60-120 frame trace
4. Byte-diff, find first divergence
5. Port missing NES logic to Genesis
6. Re-run probe, verify match
7. Commit with NES asm citation + probe filename

Reference files:
- `reference/aldonunez/Z_04.asm` — per-enemy update bodies
- `reference/aldonunez/Z_07.asm` — @LoopObject + init dispatch + chase target
- `reference/aldonunez/Z_01.asm` — collision + draw chain + heap
- `reference/aldonunez/Variables.inc` — NES RAM cell map
- `src/game/enemies/enemy_loop.c` — central dispatch
- `src/game/enemies/enemy_walker_bridge.c` — per-type drained bodies
- `src/oracle/enemies/` — drained C primitives

## Lesson log

- Don't trust auto-detect for BizHawk Lua domain — hardcode.
- ChaseTarget needs the swap-mirror toggle, not just `Chase = Link`.
- ObjectFirstUnwalkableTile = $89 OW (NOT $C0). Per `ObjectRoomBoundsOW[4]`.
- main.c already runs NES @UpdateTimers port for cells $27..$3C/$4E — don't double-dec.
- NES InitObject @NormalSpawn preamble runs BEFORE InitObject_JumpTable[type]. Cloud monsters set ObjTimer=slot in preamble, octorok overrides to $20 in init.
- NES DrawCloud `STA $0C` clobbers DRAW_MIRRORED → frames 1-3 hit @Mirrored path (tile_R = tile_L + h_flip).
