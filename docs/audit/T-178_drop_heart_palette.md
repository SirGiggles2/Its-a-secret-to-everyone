# T-178 — dropped item must use the NES draw index (2026-10-01)

NES reference: `reference/aldonunez/Z_07.asm:DrawItemBySlot:@WriteSprites`
loads X=$0F before `Anim_WriteStaticItemSpritesWithAttributes`.
`Z_01.asm:Anim_WriteSpritePair` reads the invincibility timer indexed by X.
Drain: `draw_dispatch.c:draw_item_by_slot` and existing item/native renderer.
Stance: EXTEND the shared draw; publication ownership remains CurObjIndex.
Coverage: Manhandla drop/pickup color plus bomb/drop and pause ring consumers;
other drop classes and connected L3 remain separate.

Frozen pre-fix ROM DDA0092E shows a real non-overlap color error at tick 1059:
NES $F3 attr 2 at x129/y143, Genesis SAT tile1065 PAL1 at x129/y136.
First wrong pixel (130,136): NES CRAM $22A, Genesis $0C8. Total 41 wrong pixels,
17 overlapping; earlier 1048 and later 1064/1072 already match. Gameplay RAM
passes 1155/1155, so RAM acceptance did not establish appearance.

The former monster slot 1 retains hit timer 4 at tick 1058 (FrameCounter31),
while NES item draw index15 has timer0. Genesis passed slot1 into the item
writer, overriding item attr2 with timer&3=0. The shared entry now passes
descriptor/flash index $0F exactly as NES; CurObjIndex still selects the
native cache owner. No timer reset, palette special-case or asset change.

Windows `Debug.bat` PASS, freshness 9/9. Frozen playable
`builds/playtests/Debug-T178.md` SHA-256:
`2ED27FFB37E315C03132ED0D51CC0C9DC0A333EBDAA1EA1954AF4231C40112B5`.

- `t171_manhandla_sword_codex_t178_fixed`: 1155/1155 GATE, unchanged baseline;
  SCREEN MATCH 1048/1059/1064/1072, including overlapping pixels at 1059.
- `t110_bomb_enemy_codex_t178_fixed`: 401/401 GATE, unchanged baseline.
- `t121_ring1_codex_t178_fixed`, `t121_ring2_codex_t178_fixed`: 192/192 GATE
  each; final visible sprites 4/4 exact each, expected menu crop dy=-7.
- Full video capture of Manhandla before/after has exactly the same six
  slower ticks 300/334/335/347/352/353 (117 NES/123 Genesis frames). These
  pre-existing staged reload/spawn/early fight stalls remain T-172; do not
  claim whole-scene performance PASS. Drop-color repair adds no stalls.

Pre-fix reports `t171_manhandla_sword_codex_t178_heart` and
`t171_manhandla_sword_codex_t178_lag_before`; unique frozen-ROM reports
protect build identity from shared output replacement. No baselines refreshed.
