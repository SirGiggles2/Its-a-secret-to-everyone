# T-171 — Digdogger flute, child fight, reward and departure (2026-10-01)

- **NES source:** `reference/aldonunez/Z_04.asm:L_Digdogger_AfterFlute, @MakeChildren, Digdogger_Draw, L_Digdogger_DrawAsLittle`; `Z_03.asm:FetchPatternBlockUWBoss`.
- **Drained C:** `src/oracle/enemies/enemy_boss_runtime.c:enrt_update_digdogger, enrt_digdogger_make_children, enrt_digdogger_draw_as_little`; active native draw submissions in `src/game/enemies/enemy_render.c`.
- **Coverage:** PARTIAL: Q1 L5 one-child variant, visible split, child damage/death, heart-container pickup and adjacent-room departure. Three-child variant, rejected actions, Triforce collection/revisit/SRAM and connected entry remain open.
- **Stance:** EXTEND current renderer and existing boss drain; no boss logic replacement.

## Reproduction and structural fixes

The staged reference is `tools/lockstep/presets/t171_digdogger_flute.json`: file creation with white sword, flute, red ring, full 16-heart capacity; level warp at 50, mode-3 boss-room $24 reload at 300, flute selection at 620. Controller input walks Link out of the doorway (NES blocks weapon use inside it), swings once, plays flute, fights the child, picks up room reward, and exits north. NES-only bot chooses buttons, then `bot_merge.py` folds them into a deterministic script replayed on Genesis. No state correction after 620. Initial aborted doorway trial was a fixture error, not a gameplay defect.

On pre-fix ROM `DBC24AAAE0D07A2124EA78DD3D60AFF3110231FCD73CC381C9706E0F17769ADD`, state matches but child graphics fail: t1000 180 pixels, t1150 160 pixels. Live NES OAM uses $DA/$D8 while Genesis SAT points to $300/$483 instead of the resident boss bank. Renderer inferred bank residency from living boss types; Digdogger clears parent $38 and produces ordinary child type $18. Both sweep paths now use `level_chr_boss_is_ready()`, whose state is cleared when the enemy bank replaces it. The frozen host's existing render call-site also uses that loader boundary; this is required glue only.

A second defect at split t840 (174 pixels) discarded the parent's final small-form draw because its type had already cleared. NES @MakeChildren deliberately clears ObjType before falling through to DrawAsLittle. Native cache entries are reset with OAM every frame: a submitted draw remains valid even after type clears. Removed the later alive-type filter; the bounded submission count remains authoritative. This restores the last form without retaining stale frames.

## Verification

Windows `Debug.bat` PASS, checksum `$6BE3`, ROM SHA-256 `6506C7DF0C29A912C231C8597755878314634243342887AFCEBCA9577B8AA34B`. Existing Claude flute/whirlwind WIP is present in this build and preserved separately; only the isolated renderer selection hunk is staged from `RoomRom/src/main.c`.

- **Digdogger 1454/1454 GATE PASS.** Flute starts t687, child appears t839, child HP $80/$60/$40/$20/$00 at 840/946/988/1065/1167, death ends and room reward appears t1186, reward collected t1326, north departure to $14 at t1363. Starts with maximum heart capacity, so this does not establish below-capacity heart-container growth.
- SCREEN MATCH at 840, 1000, 1150, 1287, 1326, 1453. Earlier 650/720/839 differ by 20 pixels each, all within overlapping NES sprite boxes: existing accepted stable Genesis order versus rotating NES OAM order, not missing art.
- Named mixed boss/death consumers: `t171_aquamentus_sword` **1300/1300**, final t1299 SCREEN MATCH; `t171_gleeok_sword` **1474/1474**, final t1473 SCREEN MATCH. Existing baselines unchanged.
- New baseline 68 cells: 66 entry/setup cells shared with bomb-equipped Dodongo fixture; FirstSpriteIndex from t1 (accepted NES OAM rotation); VScrollAddrHi from t1363 (NES PPU address scratch on room transition, already accepted in fairy/route baselines). No gameplay KEY mismatch or other new runtime divergence was blessed.
- Reports: `builds/reports/lockstep/t171_digdogger_flute/`, `t171_aquamentus_sword/`, `t171_gleeok_sword/`.

This is a staged mechanics/adjacent-room acceptance slice. It does not close T-040, T-171, or connected L5/quest acceptance. Next: L6 Gohma arrow vulnerability and fight, then remaining distinct bosses/variants.
