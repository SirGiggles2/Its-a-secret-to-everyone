# Phase 7 Task 7.5 step 8 — special-enemy family close

## Task header (Drain Rule D1)

- **NES source**: `Z_04.asm:5170 InitObject_JumpTable` rows $16/$17/$27
                  + `Z_04.asm:5295 UpdateObject_JumpTable` rows
                  $16/$17/$27/$2B-$2D/$12. Family bodies:
                  - `UpdatePolsVoice` @ `Z_07.asm` (Wanderer-stub +
                    targeted bomb-arrow detection).
                  - `UpdateLikeLike` @ `Z_07.asm` (state-machine
                    capture-Link + spit-Link-and-die).
                  - `UpdateWallmaster` @ `Z_04.asm:4121-4413` (state-0
                    trigger gating + state-1 walk + emerge / capture
                    Link / unfurl).
                  - `UpdateBubble` @ `Z_07.asm` (already drained as
                    `enrt_update_bubble` Task 7.4 step 6d).
                  - `UpdateVire` @ `Z_07.asm` (already drained as
                    `enrt_update_vire` Task 7.3 step 7; on-death
                    spawns 2x RedKeese via `c_shoot(28)`).

- **Drained C**:  - `enrt_update_pols_voice` @ `enemy_special_bridge.c`
                    (step 3, native bridge body).
                  - `enrt_update_like_like` @ `enemy_special_bridge.c`
                    (step 2, native bridge body).
                  - `enrt_update_wallmaster` @ `enemy_special_bridge.c`
                    (step 4, native bridge body — uses 3 drained
                    helpers in `src/oracle/enemies/enemy_wallmaster_runtime.c`).
                  - `enrt_update_bubble` @
                    `src/oracle/enemies/enemy_walker_runtime.c:14`
                    (drained twin).
                  - `enrt_update_vire` @
                    `src/oracle/enemies/enemy_boss_runtime.c:339-358`
                    (drained twin).

- **Coverage**:   FULL for all 5 family rows across $16/$17/$27/
                  $2B-$2D/$12 — INIT + UPDATE wired, no remaining
                  unresolved special-enemy entries in the master plan
                  Task 7.5 list except the cross-family $52
                  UnderworldPersonLifeOrMoney (deferred — UW persons
                  drain belongs in Task 7.7 NPC family, not 7.5).

- **Stance**:     EXTEND (PolsVoice / LikeLike / Wallmaster: bridge
                  bodies translated per-line from NES with audit
                  trail; helpers already drained) + ADOPT (Bubble /
                  Vire: drained twins reused as-is, no bridge edits).

## Wired dispatch (Task 7.5 net delta vs Task 7.4 close baseline)

INIT delta:

| Hex | NES type    | INIT row                              | step |
|-----|-------------|---------------------------------------|------|
| $16 | PolsVoice   | `enrt_init_walker`                    | 1    |
| $17 | LikeLike    | `enrt_init_walker`                    | 1    |
| $27 | Wallmaster  | `core_reset_obj_metastate_and_timer`  | 1    |

UPDATE delta:

| Hex | NES type    | UPDATE row                | step |
|-----|-------------|---------------------------|------|
| $16 | PolsVoice   | `enrt_update_pols_voice`  | 3    |
| $17 | LikeLike    | `enrt_update_like_like`   | 2    |
| $27 | Wallmaster  | `enrt_update_wallmaster`  | 4    |

Confirm-only (already wired in earlier tasks):

| Hex     | NES type      | UPDATE row              | wired by         |
|---------|---------------|-------------------------|------------------|
| $2B-$2D | Bubble triple | `enrt_update_bubble`    | 7.4 step 6d      |
| $12     | Vire          | `enrt_update_vire`      | 7.3 step 7       |

## Task 7.5 dispatch coverage end-state

INIT  table: 37 -> 40 wired rows (+3).
UPDATE table: 45 -> 48 wired rows (+3).

Net family closure: $16 PolsVoice / $17 LikeLike / $27 Wallmaster
both INIT + UPDATE rows resolved. No remaining special-enemy ($16-$2D)
rows have unwired drained twins.

## Out-of-scope — deferred from Task 7.5

| Hex | NES type                    | Status                  | Owner task |
|-----|------------------------------|-------------------------|------------|
| $52 | UnderworldPersonLifeOrMoney  | UW NPC, ~5-state TableJump + Person_DrawAndCheckCollisions + DrawLifeOrMoneyItems + AnimateItemObject + CueTransfer chain | Task 7.7 |
| $4B-$51 | UnderworldPerson family | NPC family bodies        | Task 7.7 |

Rationale: $52 is the master-plan "shield consumption / rupee option"
checkbox, but its body is the UW persons family (door charge / money
game / hint), not the special-enemy family this task covers. Per Drain
Rule D1 stance compliance, that should land in Task 7.7 with the rest
of the UW persons drain so dispatch + drain-coverage stays semantically
clean.

## New native bodies in `src/game/enemies/`

`enemy_special_bridge.c` (created step 2, extended steps 3 + 4):
- `enrt_update_like_like(slot)`            — step 2.
- `enrt_update_pols_voice(slot)`           — step 3.
- `enrt_update_wallmaster(slot)`           — step 4.
- `wm_link_end_move_and_animate_bank4_stub` — STAGE-1 no-op for cap-link path.

Plus a single TU addition to `tools/debug/build_debug.py`:
- `src/oracle/enemies/enemy_wallmaster_runtime.c` linked so
  `enrt_wallmaster_prepare_to_draw` / `enrt_wallmaster_calc_start_position`
  / `enrt_wallmaster_put_sprites_behind_bg_if_needed` are not
  --gc-sections'd. Required by the step 4 bridge.

## Helpers / data already linked from prior tasks

These are reused by the step 2/3/4 bridge bodies; no new copies:
- `c_obj_shove`, `c_move_object`, `core_set_type_and_clear_object`
  (Task 7.2 / 7.3).
- `draw_object_not_mirrored_with_frame`, `draw_object_not_mirrored_over_link`
  (Task 7.4 step 10).
- `enemy_hide_sprites_over_link`, `sprite_show_link_sprites_behind_horizontal_doors`
  (Phase 4 sprite plumbing).
- `k_sprite_offsets[41]` (Task 7.4 step 10 — Wallmaster keese-tile patch).
- `enrt_wanderer_update`, `enrt_animate_and_draw_object` (drained walker
  helpers — PolsVoice falls through to these per NES).

Stance compliance: every wire uses ADOPT or EXTEND. No GREENFIELD
violations — bridge bodies translate NES asm per-line; ADOPT rows reuse
drained-C bodies straight from `src/oracle/enemies/*_runtime.c`.

## Build verification

`python tools/debug/build_debug.py` — clean post step 4 wire and post
step 8 close (no build-affecting edits in step 8 — audit + plan tick
only).

## Phase 7 Task 7.5 closure summary

Steps 1..8 net delta vs Task 7.4 baseline:
- INIT  rows: 37 -> 40 wired (+3 — $16/$17/$27).
- UPDATE rows: 45 -> 48 wired (+3 — $16/$17/$27).
- Confirm-only rows verified: $2B-$2D bubble, $12 vire.
- New TU: `src/oracle/enemies/enemy_wallmaster_runtime.c`.
- New bridge file: `src/game/enemies/enemy_special_bridge.c` (~3 native
  UPDATE bodies, ~700 lines).
- No new files in `RoomRom/`. Sole-target `builds/Debug.md` only.

## Step 9 sequencing (Task 7.6 hand-off)

Task 7.6 picks up Aquatic / Terrain Family — zora / tektite / leevers /
water+terrain constraints. Tektite and zora UPDATE/INIT already wired
in Task 7.4; Task 7.6 closes leevers ($0F/$10) and any water/terrain
constraint plumbing. Lighter step than 7.5 — most of the family is
already drained + linked.

Task 7.6 prerequisites in place after step 8:
- Drained twins for $0F/$10 leever (TBD coverage check at task open).
- Tektite ($0D/$0E) UPDATE + INIT wired.
- Zora ($11) UPDATE + INIT wired.
- Bubble ($2B-$2D) UPDATE wired (terrain-ish behavior — block-flash).
