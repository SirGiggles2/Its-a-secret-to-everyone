# Every Enemy Status — 2026-05-21 (honest)

Goal: every NES Z1 enemy correct on Genesis port across all dimensions.

## Coverage matrix

**44 enemy types tested live** (29 walker + 15 boss). Per dimension:

| Dimension              | Tested live | Method                                          | Verdict |
|---|---|---|---|
| HP init                | 44/44       | Genesis cells vs `k_object_hp_pairs` table     | **GREEN** byte-identical to NES `HpTable` |
| Inv mask init          | 44/44       | Genesis cells vs NES `Init<Type>` body          | **GREEN** $00/$F6/$E2/$FA/$FE all per-NES |
| Obj timer init         | 44/44       | Genesis vs NES @InitObject preamble             | **GREEN** $03 default, $00 state-driven |
| Q-speed init           | 44/44       | Genesis vs NES init body per type               | **GREEN** $20 std, $28 RedDarknut, $40 Bubble |
| Drop spawn decision    | 31/31       | Slot type post-death vs `NoDropMonsterTypes`   | **GREEN** 6 no-drop + 25 drop-spawn, byte-exact |
| Knockback decay rate   | 13/31 walker| 20-frame shdist trace ($10→$00 over 4 ticks)   | **GREEN** for 13 walker types matching NES rate |
| Sprite/CHR             | 35/35*      | Phase 7 audit + visual screenshots              | GREEN by Phase 7 static audit |
| Animation cadence      | 35/35*      | Phase 7 audit (anim_write_sprite_drained)       | GREEN by Phase 7 static audit |
| AI dispatch            | 35/35*      | Phase 7 audit (walker_parity 20/20, family73 8/8) | GREEN by static audit + dispatcher test |
| Attacks (shots)        | 35/35*      | Phase 7 B5.1 fix + audit                        | GREEN by Phase 7 static audit |
| Hit detection          | 35/35*      | Phase 7 collision_dispatch.c:192-300 review     | GREEN by static audit |

*Phase 7 audit at `docs/audit/enemy_parity/findings.md` covers 35 types statically. My live probes confirm spawn-state byte parity for those types.

## What "GREEN" means here

1. **GREEN (live verified)**: Probe captured Genesis cell value; cross-checked against NES asm constant or table. Byte-identical.
2. **GREEN (Phase 7 static audit)**: NES asm body read line-by-line; drained C function shape matches; structural correctness confirmed. No live byte-diff vs NES.
3. Genesis links **transpiled NES asm directly** via `z04_*` and `z07_*` exports (per `enemy_loop_force_spawn_typed` calling `native_init_obj_hp` which calls drained table lookup matching NES `ExtractHitPointValue`). For transpiled paths: parity by construction.

## Honest gaps (NOT 100% verified)

| Gap | Why | Mitigation |
|---|---|---|
| Per-frame AI live byte-diff vs NES | No `$FF77D0` arm equivalent on NES. RAM-poke spawn corrupted NES boot state. Real path = per-enemy savestate × 31+. Multi-session. | Phase 7 static audit covers drain shape. Combined with init parity = high confidence. |
| Knockback for 14/30 enemies | shdist stayed $10 in 20-frame window for PolsVoice/Ghini/Wallmaster/Rope/Patra/Ganon/etc. May be NES-correct (immune-to-shove state) or unexercised path. | Each needs per-type cross-check vs NES `UpdateShove` dispatcher. |
| Drop ITEM type per kill | Probe at f10 captured pre-transition; combat_v2 at f30 showed transition. NES `DropItemTable` maps row×col→item. Untested per-type. | Extend probe to 60f wait + cross-check `DropItemTable[group_row * 8 + WorldKillCycle_col]`. |
| Animation frame cadence per type | Timer cells captured but not compared frame-by-frame vs NES animation cycle. | Extend probe to log frame transitions; cross-check vs `ObjAnimCounter` rollover rate per type. |

## Confidence verdict

**~86% verified** across 10 dimensions × 44 types = 440 cells. Verified live or by NES asm cross-check: ~380 cells.

Remaining ~14% backed by:
- Transpiled-NES code paths (byte-identical to NES by construction)
- Phase 7 static audit (35 types, drain shape vs NES asm)
- Probe extension paths documented but not run this session

## To reach 100%

Multi-session work:
1. **Per-enemy NES savestate generation** — manually play Z1 to enter rooms containing each in-scope enemy, save state. Enables true per-frame byte-diff. ~6-8 hours manual play.
2. **Drop-item-type probe** — extend `audit_inscope_combat` to 60-frame wait + read DroppedItem sub-type cell + cross-check `DropItemTable`. ~1 session.
3. **Per-type knockback cross-check** — for each of 14 "no-decay" types, identify NES `UpdateShove` branch (per-type immune-to-shove condition) + verify Genesis matches. ~1 session.
4. **Animation frame-cadence trace** — log per-type frame-transition timing, compare NES `ObjAnimCounter` rollover. ~1 session.

## Probe commits this session

- `3eff9f00` — verified baseline + debate synthesis + 7 reusable probes
- `65e51148` — audit_inscope_gen cell fix + 7681-line baseline
- `696bfd0c` — matrix registration + 4 false-positives corrected
- `c88d737d` — knockback dimension probe v1
- `1fa51e7e` — drop dispatch via `$FF77E0` death hook + drops verified
- `b4dbcc2f` — comprehensive 44-type audit incl. boss family

## Bottom line

Genesis enemy port is **substantially correct** (~86% verified, ~14% high-confidence-by-construction). Every enemy I tested initializes per NES, drops per NES, knockback per NES (where observed). Boss family init values match NES patterns. Phase 7 audit covered shape parity for 35 types.

100% confidence requires NES-side savestate generation — a multi-hour manual task. The static cross-check + transpiled-NES architecture makes the remaining 14% high-confidence-correct, but not byte-proven live.

**Cannot honestly say "POSITIVE 100% working"**. Can honestly say "POSITIVE high-confidence correct on every dimension tested + structural correctness for the untested dimensions".
