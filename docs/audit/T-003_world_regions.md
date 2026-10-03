# T-003 world-region runtime acceptance — 2026-10-02

Owner: Codex. P7.2 / P5.4. Drain stance: retain existing state/serializer/room-kill implementation; no game-source repair needed for world flags. Prior T-092 empty-slot zeroing and T-100 byte-exact serializer evidence carried forward.

## Build identity

`Debug.bat` PASS on Windows; freshness 9/9. Frozen local playable `builds/playtests/Debug-T003.md`, SHA-256 `2B0094D5BD6FF7BC5217F377AB20C7FAE3C905B7A77E3C160F31C024A789E156`. Base Claude f856d3be plus his existing dirty ladder/item/atlas work, preserved without staging it. Frozen ROM, not mutable Debug.md, supplied to every paired/reopen run. Private-process payload hashes recorded by run_probe. No game ROM or extracted assets committed/distributed.

## Scenario and result

| Case | Runtime reference | Result |
|---|---|---|
| Digdogger | Q1 L5 $24, declared flute/sword/ring prerequisites, accepted staged entry; controller fight, north to $14, south back to $24 | Departure1363, return1687; $723=F0, no boss respawn; 1904/1904 GATE PASS |
| Patra | Q1 L9 blue $16, declared sword/ring prerequisites, accepted staged entry; controller fight, south to $26, north back | Departure1501, return1575; $795=F0, no boss/children respawn; 1766/1766 GATE PASS |
| OW secret | Accepted $76 bomb fixture, natural bomb reveal, normal L1 entry/exit from $37; edge-position fixtures return to $76 | Secret flag bit80 retained ($6F5=82 after incidental low room-count bits); restored plane2200 tile and sub-palette 704/704 exact. Whole-route GATE remains FAIL due raft/arrival differences at1594; no baseline blessed |

Every $067F–$07FE world byte matches NES on every tick of each route: respectively 731136, 678144, 876288 tick-bytes. No post-kill flag writes or reward/progression injections. Boss routes are staged mechanic/integration evidence, not connected L5/L9 or quest acceptance. OW uses position fixtures at room edges, not normal route acceptance.

Digdogger settled return1903 and Patra1620/1765 screens MATCH. Digdogger1750 differs by16 pixels, all covered by overlapping NES sprites (accepted OAM priority). No general screenshot PASS claimed for the OW return: its restored room plane passes, while sprites differ after the raft mismatch.

Accepted new boss ratchets retain familiar startup/OAM/platform scratch differences. Patra68 cells: existing blue66 plus VScrollAddrHi at1501 and a single transition tick1500 Link animation counter5/6, within user's one-frame tolerance; later movement and settled appearance equal. Digdogger70: existing68 plus inactive room-item X/Y $83/$97 from1687; slot19 stateFF and type0 throughout every coordinate difference, so no visible/active item differs. `boss_framework.c:CreateRoomObjects` skips already-taken items; native room initialization resets their hidden coordinates. No KEY allowances, no gameplay errors masked.

## Real SRAM close/reopen

Each route ends with controller Start, pad2 Up+A, Select, Start save tail (317 video frames), copied from accepted T-013. Entire NES $6000–$652F save image equals Genesis odd-byte SRAM: **1328/1328 bytes for all three cases**. Actual private `GEN/SaveRAM/game.SaveRAM` equals captured SRAM. New isolated process seeded from that real file; controller title/File Select Continue restores **384/384 bytes** for each case, slot A active, no RAM writes. Meaningful saved markers: DigdoggerF0, PatraF0, OW82. Reopen can detect corruption across all three banks rather than checking one marker alone.

`tools/debug/probes/t003_reopen_regions.lua` compares all saved bytes to the NES expected world image, then all live bytes; missing/invalid/empty expected image, inactive file, failed Continue or mismatches emit FAIL. Runner exit alone is not accepted: logs explicitly require VERDICT PASS.

Focused lag scan of boss routes: two completed cases, zero extra lag; worst VDP lines PatraDB and DigdoggerDE, under E0. Saving tail excluded from play-clock lag claim. General performance acceptance remains T-172.

## Remaining findings

- Longer idle in Patra neighbor $26 first diverges occupied enemy slot2 at1585, then7 at1628, without world-flag divergence. Preserve `t003_patra_revisit_codex_saved` reproduction; separate T-179. Short return case avoids needing a new fight and proves persistence.
- Raw mode2 warp cannot prove normal dungeon exit: native entry record was never established. Discarded trial did not establish a game regression; normal controller entry replaced it.
- OW $37→$47 waterfall/dock arrival first differs1594 (NES B0,9D vs GEN70,3D), then frame/RNG diverge; T-056 raft/ladder remains unfinished. No broad route acceptance or failing baseline reset.
- New `lag_gate.py` ignores nonzero run_lockstep status, so completed stale/failed cases could produce PASS from lag_scan; T-180 records repair needed.

Reports under `builds/reports/lockstep/`: `t003_digdogger_revisit_codex_saved`, `t003_patra_revisit_codex_final`, `t003_ow_secret_regions_codex_final`, and `t003_{digdogger,patra,ow}_reopen`. Small immutable evidence summary in `T-003_world_regions.json`. Presets and focused reopen probe committed; large ROM/CHR/RAM evidence stays local. Required world-region behavior accepted; connected quests, raft and neighboring enemy fixes remain open.
