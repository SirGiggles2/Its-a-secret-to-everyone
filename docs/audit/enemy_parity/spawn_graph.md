# Cross-Family Spawn Graph

Enemies that spawn other enemies on death / init / shoot. When auditing
a parent, the child must also be verified (or already verified). Order
the audit so parent comes after child where possible; for cycles,
verify together.

| Parent (family) | Child (family)         | Trigger              | NES asm                              |
|---              |---                     |---                   |---                                   |
| $12 Vire (W)    | $1B Keese × 2 (F)      | Death                | `Z_04.asm:6918` UpdateVire           |
| $3C Manhandla (B) | $5D DeadDummy (NPC)  | Segment death        | `Z_04.asm:7842` UpdateManhandla      |
| $3C Manhandla (B) | $56 fireball (P)       | Shoot gate           | `Z_04.asm` Manhandla_Shoot           |
| $33/$34 Gohma (B) | $56 fireball (P)      | Shoot rollover       | `Z_04.asm:8207` UpdateGohma          |
| $38/$39 Digdogger (B) | $18 LittleDigdogger × 3 (W/J) | Flute split | `Z_04.asm:5265` UpdateDigdogger      |
| $47/$48 Patra (B) | $25/$26 PatraChild × 8 (B) | INIT (slots 2..9) | `Z_04.asm:9552` InitPatra            |
| $41 Moldorm (B) | $5D DeadDummy (NPC)    | Tail segment death   | `Z_04.asm:4907` UpdateMoldorm        |
| $1E Armos (W)   | $5D DeadDummy (NPC)    | Death                | `Z_04.asm:3302` UpdateArmos          |
| $07-$0A Octorok | $53/$54 MonsterShot (P) | Shoot timer         | `Z_04.asm:1992` UpdateOctorock (OUT OF SCOPE) |
| $0D/$0E Tektite | none                   | —                    | (OUT OF SCOPE)                       |
| $20 Boulder (P) | none (kill-on-touch)   | —                    | `Z_04.asm:2168`                      |
| $1F BoulderSet (P) | $20 Boulder × N (P) | Cycle                | `Z_04.asm:2168` UpdateBoulderSet     |
| $0F BlueLeever (J) | none                | —                    | `Z_04.asm:2599`                      |
| $10 RedLeever (J) | $10 itself (re-spawn) | State 0 spawn-near-Link | `Z_04.asm:2737`                  |
| $11 Zora (J)    | $55 fireball (P)       | Shoot gate           | `Z_04.asm:1920` UpdateZora           |
| $42-$45 Gleeok (B) | $46 GleeokHead × N (F) | INIT + detach     | `Z_04.asm:7649` InitGleeok           |
| $46 GleeokHead (F) | $56 fireball (P)     | Shoot                | `Z_04.asm:8527` UpdateGleeokHead     |
| $23/$24 Wizzrobe (B) | $58 magic shot (P) | Shoot                | `enemy_wizzrobe_runtime.c`           |
| $27 Wallmaster (W) | (no spawn)          | Captures Link        | `Z_04.asm:4121`                      |
| $35 LikeLike (W) | (no spawn)            | Captures + eats shield | `Z_04.asm:6818` UpdateLikeLike    |
| $13/$14 Zol (W) | $15 Gel × 2 (W)        | Hit by sword         | `Z_04.asm:1235` UpdateZol            |
| any              | $5D DeadDummy (NPC)    | Final death frame    | universal — death cloud handler      |
| any (drops)      | $60 DroppedItem (NPC)  | SetUpDroppedItem     | `Z_04.asm:11236`                     |

Family letters: W=walker, F=flyer, J=jumper, P=projectile, B=boss,
NPC=non-combat.

## Cycles / mutual deps

- Patra ↔ PatraChild: Patra INIT seeds children; PatraChild draws from
  parent state. Must verify together.
- BoulderSet ↔ Boulder: spawner cycles boulder slots. Verify together.
- Zol → Gel: split on hit. Verify Zol first (parent), then Gel (child).

## Audit ordering implications

Per-family loop must include cross-family children. For each family:

1. **Walker** — also verify $1B Keese spawned by $12 Vire, $5D
   DeadDummy spawned by $1E Armos / any walker death, $56 fireball
   spawned by $0B/$0C Darknut shot gate, $15 Gel spawned by Zol.
2. **Flyer** — verify $1B Keese behavior matches NES across spawn-on-Vire,
   spawn-on-Gleeok-detach paths.
3. **Jumper** — $55 fireball from $11 Zora.
4. **Projectile** — Boulder/BoulderSet cycle, MonsterShot family
   (already audited in walker passes when octorok shoots).
5. **Boss** — Patra/PatraChild together, Gleeok/GleeokHead together,
   Digdogger/LittleDigdogger together.
6. **NPC** — $5D DeadDummy is universal; verify it ticks correctly
   across all parent deaths.

## Out-of-scope spawn risk

Octoroks ($07-$0A) spawn $53/$54 MonsterShot. If Phase B5 (projectile)
fixes MonsterShot behavior, octorok shoot output changes. The change
is *intended* (octorok shots become NES-correct). Verify
out-of-scope baseline (A3) catches this expected shift — it is a
"behavior more like NES" change, accepted per user direction.

Tektites ($0D/$0E) share `enrt_update_tektite_or_boulder` with $20
Boulder. Phase B5 Boulder fixes will touch this fn. Same logic — shift
is intended, document in commit, accept.
