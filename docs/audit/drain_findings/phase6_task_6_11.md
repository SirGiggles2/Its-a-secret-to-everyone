# Phase 6 Task 6.11 — Damage, Death, And Drops Verification

- **NES source**:
  - Damage: `reference/aldonunez/Z_01.asm:5691` Link_BeHarmed; `:5700` `LDY InvRing` damage divisor; `:5718-5754` HeartPartial / HeartValues subtraction with borrow; `:5756-5772` `@HandleDied` → mode $11
  - Invincibility: `Z_01.asm:1884,4031` `STA ObjInvincibilityTimer, X` ($10 cycles, decrements every 2 frames); `:5152-5161` invincibility flicker patch; `:5850` ObjInvincibilityMask
  - Shove: `Z_07.asm:4720` `JSR BeginShove` (called from candle/fire collision); ObjShoveDir + ObjShoveDist used per-frame
  - Death sequence: `Z_05.asm:2047` InitMode11; `:2061` `STA Paused`; `:2086-2095` DeathPaletteCycle = $60, DeathTurns = 4 starting from down; `:2098-2101` SilenceSound (Tune0Request = $80, EffectRequest = $80)
  - Heart container collect: `Z_01.asm:4492-4538` `@TakeHeartContainer` → `:4615-4630` `@FillHeartPartial`
  - Drop tables: `Z_04.asm:11068` DropItemMonsterTypes0/1/2; `:11081` DropItemSetBaseOffsets ($00,$0A,$14,$1E); `:11087` DropItemRates ($50,$98,$68,$68); `:11096` DropItemTable (40 bytes — 4 rows × 10 cols, indexed by WorldKillCycle); `:11103` SetUpDroppedItem
- **Drained C**:  N/A — RoomRom-native (NOT YET IMPLEMENTED)
- **Coverage**:   NONE (entire damage/death/drops subsystem deferred — needs HeartValues + InvRing + collision + enemy infra)
- **Stance**:     EXTEND (defer to Phase 7 enemies + Task 6.10 inventory landing first)

## NES behavior summary (for re-entry context)

### Damage flow (Link_BeHarmed)

1. Play hurt sample $08 (skip if attacker type $2E = whirlwind).
2. Damage in `[$0E:$0D]` is 16-bit (high = full hearts, low = partial fraction $00-$FF).
3. Halve damage by ring tier: blue ring = ÷2, red ring = ÷4 (`LDY InvRing` then `LSR/ROR` Y times).
4. Reset `WorldKillCount`, `HelpDropCount`, `HelpDropValue` (drop-streak state).
5. Subtract `[$0E]` from `HeartPartial`; on underflow borrow from full hearts.
6. If full hearts also underflow → `@HandleDied` → mode $11 (death).

### Death sequence (InitMode11)

- Submode 0: HideAllSprites, DrawLinkBetweenRooms, FormatStatusBarText, `Paused = 0`, `HeartPartial = 0`, `ObjInvincibilityTimer = $10`, ObjTimer = $21.
- Submode 1 wait: ObjTimer expires → DeathPaletteCycle = $60, DeathTurns = 4, ObjDir = down, IsUpdatingMode++, SilenceSound (Tune0 = $80 stops song, EffectRequest = $80 stops fx).
- Update phase: DeathTurns spins Link 4 times (down → right → up → left → down again per turn) over ~$60 = 96 frames.

### Drop table

- 4 rows × 10 cols = 40-byte `DropItemTable` (Z_04.asm:11096).
- Row chosen by enemy group: `DropItemMonsterTypes0` (6 enemies), `DropItemMonsterTypes1` (9 enemies), `DropItemMonsterTypes2` (9 enemies); else default to row 3 (boss/special).
- Column = `WorldKillCycle` (each kill increments, masks to 10).
- Drop rate = random byte < `DropItemRates[row]` ($50/$98/$68/$68 → 31% / 60% / 41% / 41%).
- Drop IDs in table: $00 = nothing, $0F = bomb, $18 = rupee (1), $21 = key, $22 = heart, $23 = clock (5-rupee).

### Heart container collect

- `@TakeHeartContainer` (Z_01.asm:4538) increments full hearts: `HeartValues = (HeartValues & $0F) | (newMax << 4) | newCur`.
- `@FillHeartPartial` (Z_01.asm:4628) fills partial via `HeartPartial = $FF` if not already, else fills full.
- `InvHeartContainers` cell tracks max container count (3 base + collectible).

### Invincibility flicker

- `ObjInvincibilityTimer` decrements every 2 frames (down to 0).
- Sprite render gated by `ObjInvincibilityMask` (frame-counter-based show/hide pattern).
- Player invincibility used for: just-hit (Z_01.asm:1884 / 4031), continue-after-death (InitMode11 sub 0 sets $10), pause-screen entry.

## Required sub-tasks (Task 6.11 ladder)

| Sub-task | NES anchor | Re-entry trigger |
| --- | --- | --- |
| 6.11.1 — HeartValues + HeartPartial cells in inventory | Variables.inc | Task 6.10 (inventory struct) — fold here |
| 6.11.2 — `Link_BeHarmed` core (damage subtract + die check) | `Z_01.asm:5691-5774` | Phase 7 (enemy → Link collision) — needs enemy slot |
| 6.11.3 — `ObjInvincibilityTimer` count-down at 2-frame rate | `Z_01.asm:5152-5161` | This task |
| 6.11.4 — Sprite invincibility flicker mask | `Z_01.asm:5850` ObjInvincibilityMask | Task 6.1 (Link state) extension |
| 6.11.5 — Ring damage divisor | `Z_01.asm:5700-5706` | Task 6.10 (Inventory has InvRing) |
| 6.11.6 — Death sequence (mode $11 = InitMode11) | `Z_05.asm:2047-2103` | Task 6.11-followup — needs death palette cycle + GameMode dispatch |
| 6.11.7 — DeathTurns rotation animation | `Z_05.asm:2094-2095` | 6.11.6 |
| 6.11.8 — Drop table tables (`DropItemTable`, `DropItemRates`, `DropItemMonsterTypes0/1/2`, `DropItemSetBaseOffsets`) | `Z_04.asm:11068-11101` | Phase 7 (Enemies) — drops triggered on enemy kill |
| 6.11.9 — `WorldKillCycle` advance + drop-streak (`HelpDropCount`, `HelpDropValue`) | `Z_01.asm:5710-5713` | Phase 7 |
| 6.11.10 — `SetUpDroppedItem` allocator | `Z_04.asm:11103` | Phase 7 — dropped item objects need slot |
| 6.11.11 — Heart container collect (`@TakeHeartContainer`, `@FillHeartPartial`) | `Z_01.asm:4538,4628` | Task 6.11 — pickup mechanic |
| 6.11.12 — Hurt SFX `LDA #$08 / JSR PlaySample` | `Z_01.asm:5695` | Audio scaffold (Phase 9-ish) |
| 6.11.13 — `BeginShove` impulse on collision | `Z_07.asm:4720` | Task 6.11 — needs ObjShoveDir + ObjShoveDist per-slot |

## Deferred (Task 6.11-followup)

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Continue / save-on-death prompt | InitMode11 → mode 8 transition | Status mode UI absent | Task 6.10.7 (Mode8 inventory grid) |
| Link death palette cycle ($60) | `Z_05.asm:2086` FadeCycle = $60 | Palette-cycle subsystem absent | This task — needs FadeCycle support |
| Game-over song / sound silence | `Z_05.asm:2099-2101` SilenceSound | Audio scaffold absent | Audio scaffold task |
| `World_IsFillingHearts` potion-pause | `Z_05.asm:3022` (already in 6.10) | Inventory pause not yet wired | Task 6.10 |
| Bait drop (food obj at Link's pos for Goriya) | NES bait handler | Bait subsystem absent (already noted in 6.9) | Phase 7 Goriya |
| Boss death drop suppression | NoDropMonsterTypes table | Boss infra absent | Phase 8 (Bosses) |

## Probe / contract

- Static contract goal: `tools/debug/test_damage_contract.py` —
  HeartValues / HeartPartial cells exist + match NES layout,
  Link_BeHarmed shape (subtract → borrow → die),
  invincibility timer counts at 2-frame rate, ring divisor,
  drop table byte-for-byte match (40 bytes),
  drop rates match $50/$98/$68/$68.
- Visual probe (post-impl): `tools/debug/probes/probe_death_visual.lua`
  — capture DeathTurns rotation cadence vs NES frame counts.

## Gate

- 4-line task header: filled.
- Gate 1: not applicable (no impl yet).
- Gate 2: deferred — Task 6.11 will not close until at minimum
  HeartValues / HeartPartial / InvincibilityTimer / Link_BeHarmed
  shell land. Drop table is Phase 7 territory.
- Gate 3: deferred to milestone tag (full Link death + revive cycle).

## Action items added to deferral ledger

1. Declare `HeartValues` (high nibble = max, low nibble = current) +
   `HeartPartial` cells in `inventory_t` (per Task 6.10 struct).
2. Implement `link_be_harmed(damage_hi, damage_lo)` shell matching
   NES Link_BeHarmed signature (`[$0E:$0D]`).
3. Wire `s_invincibility_timer` global + 2-frame countdown.
4. Sprite flicker mask on Link slot when invincible.
5. Ring damage divisor (`InvRing` >> Y times shift).
6. Death-mode entry stub (mode $11) — palette cycle $60 placeholder.
7. Heart container collect path (`take_heart_container()` matching NES).
8. Extract drop tables (`DropItemTable`, `DropItemRates`,
   `DropItemMonsterTypes0/1/2`, `DropItemSetBaseOffsets`) into
   `data/drop_tables.h`.
9. `BeginShove` per-slot ObjShoveDir + ObjShoveDist scaffold.
10. Fold hurt SFX + death silence into audio scaffold task.
