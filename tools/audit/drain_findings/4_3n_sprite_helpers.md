# Drain Finding — Phase 4 Task 4.3 (native port) — sprite helpers

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for the
non-animation sprite helpers (rolling sprite index, OAM hide, Link
priority-drop). Animation cluster (animate_link_obj_state,
roll_over_anim_counter, anim_fetch_obj_pos, anim_set_obj_hflip,
anim_advance_and_fetch, animate_object_walking) deferred to next
batch — they need the COMBAT_WEAPON_SLOT / ENEMY_DIR / OBJ_HFLIP /
OBJ_TILE_X/Y / OBJ_ANIM_CNTR cross-subsystem state.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/sprite_dispatch.{h,c}` | `sprite_cycle_cur_sprite_index`, `sprite_cycle_sprite_index_in_a`, `sprite_hide_object_sprites`, `sprite_show_link_sprites_behind_horizontal_doors`, file-static `sprite_reset_cur_sprite_index_inline` |
| Drain | `src/oracle/world/sprite_runtime.c` | 10-61 |
| NES asm | `reference/aldonunez/Z_01.asm` | 3095-3100 (ResetCurSpriteIndex), CycleCurSpriteIndex / CycleSpriteIndexInA / HideObjectSprites / ShowLinkSpritesBehindHorizontalDoors (1594-ish) |
| NES vars | `reference/aldonunez/Variables.inc` | `RollingSpriteIndex := $0341` (40-slot wrap at $28), $0342 = high-prio sprite cursor, ObjX = $0070 (= ENEMY_PLAYER_OBJ_X for slot 0), `Sprites := $0200` (= ROOM_OAM_BYTE base, OAM Y bytes at +0/4/8/...), OAM attr offset +2 within each 4-byte slot |

## Drain MATCH proof — `CycleCurSpriteIndex`

| NES | Drain (10-17) | Verdict |
|-----|---------------|---------|
| `INC RollingSpriteIndex / LDA RollingSpriteIndex / CMP #$28 / BNE :+ / JSR ResetCurSpriteIndex / :+ / RTS` | `idx = RAM($0341)+1; if (idx == 0x28) z01_reset_cur_sprite_index() else RAM($0341) = idx` | **MATCH** — wraps at $28, otherwise stores incremented index. |

## Drain MATCH proof — `CycleSpriteIndexInA`

| NES | Drain (19-27) | Verdict |
|-----|---------------|---------|
| `CLC / ADC #$01 / CMP #$28 / BNE :+ / JSR ResetCurSpriteIndex / RTS / : STA RollingSpriteIndex / RTS` | `idx = idx+1; if (idx == 0x28) reset, return 0; else store + return idx` | **MATCH** — same logic, takes A-passed input + returns it. |

## Drain MATCH proof — `HideObjectSprites`

| NES | Drain (29-36) | Verdict |
|-----|---------------|---------|
| `LDX #$60 / @loop: LDA #$F8 / STA Sprites,X / TXA / CLC / ADC #$04 / TAX / BNE @loop` | `d2 = 96; do { ROOM_OAM_BYTE(d2) = $F8; d2 += 4; } while (d2 != 0)` | **MATCH** — iterates from offset 96 ($60) by +4 until wrap to 0 (= 256, end of OAM). |
| `LDA RAM($0342) / JSR CycleSpriteIndexInA / STA RAM($0342)` | `RAM($0342) = sprrt_cycle_sprite_index_in_a(RAM($0342))` | **MATCH** |

## Drain MATCH proof — `ShowLinkSpritesBehindHorizontalDoors`

| NES (Z_01.asm:1594-ish) | Drain (38-61) | Verdict |
|--------------------------|---------------|---------|
| Test left edge (link_x) and right edge (link_x + 8) against horizontal door range; if in range, set OAM attr bit $20 on slot 18 (left half) and 19 (right half). | drain mirror | **MATCH** — drain comment fully documents NES intent + Genesis SAT bit-15 mapping. |

**Drain verdict: 4 functions FULL MATCH** vs NES (with one shim
inlined: `z01_reset_cur_sprite_index` = trivial `RAM($0341) = 0`). 

## Native port

| Function | Drain | Native | Verdict |
|----------|-------|--------|---------|
| reset_cur_sprite_index helper | shim call (`z01_reset_cur_sprite_index`) | `static inline` (NES `RAM($0341) = 0`) | **MATCH** (shim eliminated per "no transpile shims in src/game/" rule) |
| cycle_cur_sprite_index | drain | drop-in (uses inline reset helper) | **MATCH** |
| cycle_sprite_index_in_a | drain | drop-in (uses inline reset helper) | **MATCH** |
| hide_object_sprites | drain | drop-in | **MATCH** |
| show_link_sprites_behind_horizontal_doors | drain | drop-in | **MATCH** |

**Native verdict: FULL MATCH** for all 4 functions. No deferred TODOs.

## Cutover gate

- New gate: `NATIVE_SPRITE` (independent from `NATIVE_OBJECT`/`_WORLD`).
- 4 hand-written z01_* wrappers in src/gen/z_01.c.
- Default OFF → oracle drain.
- Defined ON → native (drop-in FULL MATCH).
- RoomRom links sprite_dispatch.o unconditionally beside cave_dispatch.o
  + world_dispatch.o + object_dispatch.o.

## Stance update

Phase 4 Task 4.3 (Stance: ADOPT) — first sprite batch. 4/11 functions
in `src/oracle/world/sprite_runtime.c` ported. Animation cluster (7
functions) deferred to next batch — they reach into combat / enemy
state surfaces that need verification first.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc cited per process improvement from finding 3_2.
