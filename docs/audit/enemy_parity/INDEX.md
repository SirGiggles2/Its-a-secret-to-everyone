# Enemy Parity — Per-Type D1 Headers

Per Rule D1 (drain-first, NES-secondary). Each in-scope type has 4-line
header citing NES source, drained C, coverage, stance.

## Walker (19)

[01 BlueLynel](walker/01_blue_lynel.md) ·
[02 RedLynel](walker/02_red_lynel.md) ·
[03 BlueMoblin](walker/03_blue_moblin.md) ·
[04 RedMoblin](walker/04_red_moblin.md) ·
[05 BlueGoriya](walker/05_blue_goriya.md) ·
[06 RedGoriya](walker/06_red_goriya.md) ·
[0B BlueDarknut](walker/0B_blue_darknut.md) ·
[0C RedDarknut](walker/0C_red_darknut.md) ·
[10 RedLeever (W dispatch row)](walker/10_red_leever.md) ·
[12 Vire](walker/12_vire.md) ·
[13 Zol](walker/13_zol.md) ·
[14 RedZol](walker/14_red_zol.md) ·
[15 Gel](walker/15_gel.md) ·
[16 PolsVoice](walker/16_pols_voice.md) ·
[17 LikeLike](walker/17_like_like.md) ·
[1E Armos](walker/1E_armos.md) ·
[21 Ghini](walker/21_ghini.md) ·
[27 Wallmaster](walker/27_wallmaster.md) ·
[28 Rope](walker/28_rope.md) ·
[2A Stalfos](walker/2A_stalfos.md) ·
[2B BlueBubble](walker/2B_blue_bubble.md) ·
[2C RedBubble](walker/2C_red_bubble.md) ·
[2D BlueBubble2](walker/2D_blue_bubble2.md) ·
[30 Gibdo](walker/30_gibdo.md) ·
[3F GuardFire](walker/3F_guard_fire.md) ·
[40 StandingFire](walker/40_standing_fire.md)

## Flyer (6)

[1A Peahat](flyer/1A_peahat.md) ·
[1B BlueKeese](flyer/1B_blue_keese.md) ·
[1C RedKeese](flyer/1C_red_keese.md) ·
[1D BlackKeese](flyer/1D_black_keese.md) ·
[22 FlyingGhini](flyer/22_flying_ghini.md) ·
[46 GleeokHead](flyer/46_gleeok_head.md)

## Jumper (4)

[0F BlueLeever](jumper/0F_blue_leever.md) ·
[10 RedLeever](jumper/10_red_leever.md) ·
[11 Zora](jumper/11_zora.md) ·
[18 LittleDigdogger](jumper/18_little_digdogger.md)

## Projectile (8 entries covering ~12 types)

[1F BoulderSet](projectile/1F_boulder_set.md) ·
[20 Boulder](projectile/20_boulder.md) ·
[53-5A MonsterShot family](projectile/53_5A_monster_shot.md) ·
[55-56 Fireball](projectile/55_fireball.md) ·
[5B MonsterArrow](projectile/5B_monster_arrow.md) ·
[5C ArrowOrBoomerang](projectile/5C_boomerang.md) ·
[2E Whirlwind](projectile/2E_whirlwind.md) ·
[49/4A Trap](projectile/49_4A_trap.md)

## Boss (13 entries covering ~18 types)

[23 BlueWizzrobe](boss/23_blue_wizzrobe.md) ·
[24 RedWizzrobe](boss/24_red_wizzrobe.md) ·
[25/26 PatraChild](boss/25_26_patra_child.md) ·
[31/32 Dodongo](boss/31_32_dodongo.md) ·
[33/34 Gohma](boss/33_34_gohma.md) ·
[38/39 Digdogger](boss/38_39_digdogger.md) ·
[3A/3B Lamnola](boss/3A_3B_lamnola.md) ·
[3C Manhandla](boss/3C_manhandla.md) ·
[3D Aquamentus](boss/3D_aquamentus.md) ·
[3E Ganon](boss/3E_ganon.md) ·
[41 Moldorm](boss/41_moldorm.md) ·
[42-45 Gleeok](boss/42_45_gleeok.md) ·
[47/48 Patra](boss/47_48_patra.md)

## NPC / non-combat (6 entries covering ~14 types)

[35 RupeeStash](npc/35_rupee_stash.md) ·
[36 Grumble](npc/36_grumble.md) ·
[4B-52 UWPerson](npc/4B_52_uw_person.md) ·
[5D DeadDummy](npc/5D_dead_dummy.md) ·
[5E FluteSecret](npc/5E_flute_secret.md) ·
[60 DroppedItem](npc/60_dropped_item.md)

## Out of scope (excluded per user)

Octoroks $07/$08/$09/$0A, Tektites $0D/$0E. Baseline at
`build/probes/baseline_outofscope_gen.txt`. Octorok inline fix
landed (commit b760610d) but no per-type doc.

## Related

- [Findings overview](findings.md) — 6 bugs fixed + 35 types
- [Live verify](live_verify.md) — cross-platform byte captures
- [Probe address model](probe_address_model.md) — NES↔Gen addr table
- [Cell tiers](cell_tiers.md) — T1/T2/T3 classification
- [Spawn graph](spawn_graph.md) — parent → child relations
- [Shared primitives](shared_primitives.md) — re-probe matrix
