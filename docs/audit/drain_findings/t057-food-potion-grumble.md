# T-057 — food (bait), potion on B, Grumble, Goriya boomerang palette

NES source: `Z_05.asm` WieldFood (2994), WieldPotion (3011), WieldItem table;
`Z_07.asm` UpdateBoomerangOrFood (3719), @CheckChaseTarget (1855),
@CheckMenuAndPause (1782), CalcBoomerangFrame (4242);
`Z_01.asm` UpdateGrumble_Full / UpdateGrumble1 / UpdateGrumble3 (1480),
World_FillHearts, CheckMonsterBoomerangOrFoodCollision (5787).
Drained C: `uw_person_dispatch.c` (Grumble, drain of `uw_person_runtime.c`),
`collision_dispatch.c` (food skip), `room_dispatch.c` / `hud_dispatch.c`
(World_FillHearts), `draw_dispatch.c` draw_boomerang (monster boomerang).
Coverage: food and potion were stubs (B food zeroed InvFood; potion slot
mapped to no B item). Stance: GREENFIELD per asm for food/potion; REPLACE
for the Grumble Link animation and the monster boomerang palette (evidence
below).

## What changed

| Function | Before | NES / now |
|---|---|---|
| `roomrom_food_wield` (boomerang.c) | B food set InvFood 0 | WieldFood: slot $0F state $80, ObjTimer $FF, PlaceWeaponForPlayerStateAndAnim, ±$10 in Link's direction; no food decrement |
| food branch of `roomrom_boomerang_update` | none | three $FF-frame states, then ResetObjState; template $03..$0A/$12/$1B/$1C sets ChaseTargetX/Y; item slot 6 tile $22 (narrow, X+4), palette 2 |
| `roomrom_food_apply_chase_target` (enemy_loop chase block) | — | NES copies Link to ChaseTarget before the weapons; Genesis copies later, so the food target is re-applied between the copy and the ChaseLongTimer flip |
| `roomrom_boomerang_throw` call | only when slot $0F idle | WieldBoomerang replaces food (state high bit) |
| `weapon_wield_potion` | cursor 7 → no B item | Potion--, World_IsFillingHearts 1, Paused 2 |
| Paused 2 frame (main.c) | — | no Link/objects/timers; UpdateHeartsAndRupees only; sprites stay; World_FillHearts clears Paused |
| `uw_person_update_grumble3` Link | Link_EndMoveAndDraw-like stub (counter pinned 6) + an OAM Link copy | Link_EndMoveAndAnimate: AnimateLinkBase while halted; Link drawn once (native) |
| `draw_boomerang` (monster) | attr + 2 + InvMagicBoomerang | attr + InvMagicBoomerang (Goriya boomerang OAM attr $00/$40) |

Candle relight (third T-057 item) was already NES: UsedCandle $513 gates the
blue candle per room and InitMode_EnterRoom clears it (`candle_fire.c`,
T-111/T-116).

## Evidence (lockstep, NES capture first)

- `t057_food_bait` (L7 room $69, blue Goriyas): food t601-1365 both consoles;
  ChaseTargetX/Y = food every tick. RAM: only the 67 standard boot-mask cells
  differ (same set as every preset). Screens t605/700/900/1100/1364/1370:
  every remaining diff pixel is in the OVERLAP count (NES sprite-order
  rotation, accepted). Before the boomerang fix: Goriya boomerangs 107 px
  wrong palette.
- `t057_food_leave`: food cleared on leaving the room on both; extra cell
  $58 VScrollAddrHi at the UW scroll (known transition internal).
- `t057_grumble` (L7 room $28): text, food, Tune1 $04, halt, 64-frame
  translucent state, food/InvFood/Grumble cleared — RAM 67 standard cells
  only (was 69: $3D0/$3E4 from t794). Screens t792/800/825/860/1000 MATCH
  (t800/825 were 47 px: Link drawn twice).
- `t057_potion`: Paused 2 t61-166 on both, hearts fill, second potion at full
  hearts; RAM 67 standard cells; screens t62/100/150/170/400 MATCH.
