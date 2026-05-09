# Phase 6 Task 6.9 — Wand, Book, Bait, Potion, Letter, Rings, Shields Verification

- **NES source**:
  - Wand (Rod): `reference/aldonunez/Z_05.asm:3028` WieldRod; `Z_07.asm:4322` UpdateRodOrArrow / `:4351` UpdateSwordOrRod / `:4516-4539` `LDX #$0E` MakeMagicShot at state 3; `Z_07.asm:3408` UpdateSwordShotOrMagicShot / `:3437` DrawSwordShotOrMagicShot
  - Book of Magic: NES Items table bit — upgrades wand to 4-way spread shot (no dedicated routine; drives magic-shot count in MakeMagicShot path)
  - Bait (Food): `Z_05.asm:2994` WieldFood — slot $0F, state $80, $FF-frame duration
  - Potion: `Z_05.asm:3011` WieldPotion — DEC Potion + `World_IsFillingHearts = 1` + `Paused = 2`
  - Letter: `Z_01.asm:319,349` InvLetter — used at old woman ($1024 in Z_07 also gates potion-shop letter)
  - Rings: `Z_01.asm:4672` `LDY InvRing` (damage divisor table), `:5700` second damage path
  - Shields: `Z_01.asm:5652` InvMagicShield; `Z_07.asm:3348-3385` LinkHeadMagicShieldTiles (Link sprite changes when magic shield); `Z_04.asm:6894` shield-eater Like-Like steals InvMagicShield
- **Drained C**:
  - Magic-shot projectile (rod's state-3 spawn): `RoomRom/src/roomrom_magic_shot.c` (already wired Phase 6 Task 6.4-prep)
  - All other items: NOT YET IMPLEMENTED
- **Coverage**:   PARTIAL (rod-cast → magic-shot spawn lifecycle landed; book upgrade, bait, potion, letter, rings, shields all NONE)
- **Stance**:     ADOPT for magic-shot (already lifted from NES); EXTEND for rest (defer to Task 6.10 Inventory + per-system tasks)

## Verified parity — Wand (Rod) magic-shot

| NES behavior | NES anchor | RoomRom impl | Status |
| --- | --- | --- | --- |
| Rod cast in state $31..$35 (state 3 = spawn shot) | `Z_07.asm:4516-4525` `CPX #$12` rod slot, state 3 → make shot | `B_ITEM_ROD` dispatch in main.c → `roomrom_magic_shot_fire(face)` | ✅ |
| Magic-shot tune $04 on activation | `Z_07.asm:4531-4532` `Tune0Request = $04` | (deferred — audio scaffold) | ⏳ |
| Shot speed (q-speed via WieldWeapon path → 3 px/f) | `Z_05.asm:2978` `LDA #$C0` ObjQSpeedFrac | `MAGIC_SHOT_SPEED_PX 3` | ✅ |
| Shot tile $7A vertical / $7C horizontal mirrored | `Z_07.asm:3437` DrawSwordShotOrMagicShot + atlas idx | `roomrom_sprites_set_magic_shot` SPRITE_SIZE(2,2) (verified HEAD `be530b34` mid-flight idle SAT slot 9 = sz=2x2 tile=55A pal=1) | ✅ |
| Sub-pal cycles per FrameCounter & 3 (flash) | `Z_07.asm` magic-shot draw — see commit `daac4670` notes | `s_flash` toggle in roomrom_magic_shot.c | ✅ |
| Re-cast lock while active | NES slot $0E occupancy | `s_state != IDLE` | ✅ |
| Despawn off-screen X < $14 / >= $EC | `Z_07.asm:4540-4549` ResetObjState | bounds-rect despawn | ✅ |

## Deferred — full table

### Wand-related

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Book of Magic 4-way spread shot | NES Items table bit drives magic-shot count | Single-shot only in v6 | Task 6.9-followup once Items inventory bits exist (Task 6.10) |
| Magic-shot enemy collision | `Z_01.asm:5993` CheckMonsterSwordShotOrMagicShotCollision | Enemy infra absent | Phase 7 (Enemies) |
| Magic-shot tile-block reflect | NES wall-collision per-tile | No collision grid in RoomRom | Task 6.7 + Phase 8 (UW + OW collision) |

### Bait (Food)

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Drop bait at Link, slot $0F state $80, $FF-frame duration | `Z_05.asm:2994-3009` | RoomRom has no bait spawn | Task 6.9-followup (post-Inv) |
| Goriya freeze interaction | NES Goriya AI checks bait obj near | Enemies absent | Phase 7 Goriya |
| Bait sprite (food tile) | NES item sprite slot | Atlas does NOT include bait tile yet | Atlas refresh task — extract bait tile from PRG |

### Potion

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| `DEC Potion` + heart-fill | `Z_05.asm:3018-3024` | No heart subsystem | Task 6.10 (Inventory) + Task 6.11 (Damage/Death/Drops — heart counts) |
| `World_IsFillingHearts = 1` + `Paused = 2` | `Z_05.asm:3022-3024` | Game pause subsystem absent | Task 6.10 (Pause) |
| Letter-substitute path | `Z_07.asm:1024` "no potion → check letter" | InvLetter absent | Task 6.10 |

### Letter

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Old-woman shop dialog | `Z_01.asm:319,349` `INC InvLetter` after read | Shop NPC absent | Phase 8 (Cellars/Shops) |
| Substitute-for-potion fallback | `Z_07.asm:1024` | InvLetter + InvPotion absent | Task 6.10 |

### Rings

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Damage divisor (blue=2, red=4) | `Z_01.asm:4672` `LDY InvRing` damage table | Damage-take subsystem absent | Task 6.11 (Damage) |
| Link palette swap (blue/red tunic) | NES palette routine on InvRing | Link palette is fixed in RoomRom | Task 6.10 (Inventory) — pal swap on equip |

### Shields

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Wood vs magic shield projectile-block list | `Z_01.asm:5652` InvMagicShield | Projectile-block subsystem absent | Phase 7 (Enemies — projectile types) |
| Link head-tile swap (LinkHeadMagicShieldTiles) | `Z_07.asm:3125,3348-3385` | Link rendering uses fixed pose tiles | Task 6.1 follow-up (Link state) — atlas needs head-pose variants |
| Like-Like shield-eat | `Z_04.asm:6894` `STA InvMagicShield` after digest | Like-Like enemy absent | Phase 7 |

## Probe / contract

- Magic-shot probe goal: extend `tools/debug/probes/probe_magic_shot.lua`
  to wait for `s_b_item == B_ITEM_ROD` via state-mirror $FF7200 (currently
  doesn't expose s_b_item — extension needed; see Task 6.10 prep).
- Static contract goal: `tools/debug/test_wand_contract.py` — magic-shot
  speed = 3, sub-pal flash on FrameCounter & 3, re-cast lock, sole-shot
  v6 (no spread until Book wired).

## Gate

- 4-line task header: filled.
- Gate 1: not applicable (RoomRom-native magic_shot; rest unimpl).
- Gate 2: deferred — magic-shot already verified via SAT idle slot 9.
- Gate 3: deferred to milestone tag (Phase 8 UW/OW + Phase 7 enemies).
