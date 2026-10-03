# T-181 — GitHub source synchronization

- **Scope:** user requested syncing GitHub and the shared Windows checkout, with GitHub considered newest.
- **Source base:** `origin/claude/friendly-faraday-wv2kca` at `f89ef86b`, 19 commits above GitHub main `f856d3be`.
- **Local preservation:** previous main `1609ea88` remains at local branch `codex/local-before-sync-20261002`; original working files, binary diff, and generated-input overlay are saved under local `.pre-merge-backup/T181-20261002`. Two named T181 stashes also remain local. No force-push or remote branch deletion.
- **Publication:** source, tests, metadata documentation only. The six modified generated game-data inputs, emulator dumps and playable ROMs are excluded. Existing upstream history was not rewritten. Do not push the local backup branch/stashes; they contain local game-derived inputs.

## Reconciliation

GitHub owns the newer ladder/dock API and the 76-spec enemy/boss equivalence sweep. Local T-003 world/SRAM evidence, T-179 room-coverage generator and T-180 runner-failure propagation are retained in source/docs. T-179's generated 684-entry room blob stays local; the generator that reproduces its 17 departure additions is published.

Local WIP already covered the mode-5 OW room-item creation/render consumer and final Link-facing publication. Those hooks were retained without adding the old ladder API or duplicate build-list entries. Vire frame advancement, item drawing API, and ladder draw-cache ownership use the newer GitHub versions. Atlas metadata was regenerated from the actual resident pause-tile reservation; no runtime gate was bypassed.

The live cloud OW ladder fixture exposed a lost integration contract at tick347: NES destroys ladder slot9 then falls through to `MoveObject` with X=9; Genesis moved Link instead (X $80->$7F, grid0->$FF). `Z_05.asm:CheckLadder` and `Z_07.asm:Walker_Move/MoveObject/DestroyMonster` confirm it. The older local WIP preserved that behavior. The merged API now returns the movement slot, and the host moves that destroyed slot while keeping Link still. The newer cloud RAM scratch/deferred-draw behavior is retained.

## Windows verification

`Debug.bat` PASS after regenerating the stale sprite catalog; generated freshness9/9. Five focused lag-wrapper tests PASS (`python tools/lockstep/test_lag_gate.py`). No broad 86-case suite or new whole-quest claim.

| Scenario | Build | Evidence | Result / scope |
|---|---|---|---|
| Normal new game | final EE5979A0 | `builds/reports/lockstep/newgame_t181_final` | 266/266 KEY and full GATE PASS |
| Patra fight/departure/Gel/return | initial 890CCB87 | `builds/reports/lockstep/t179_gel_dungeon_turn_t181_sync` | 1856/1856 GATE; tick1630 screen MATCH. Final slot-return repair runs only while a ladder is active, so unchanged route evidence carried forward |
| OW ladder crossing/return | final EE5979A0 | `builds/reports/lockstep/t056_ladder_ow_t181_final` | 610/610 KEY; tick160 screen MATCH. Raw GATE remains FAIL solely because no ratchet baseline exists (68 differing cells). No baseline blessed |
| OW ladder timing | final EE5979A0 | same report, frame dump + `lag_scan.py ... --budget 0xE0` | FAIL:63 slower play ticks,63 NES/126 Genesis frames; worst end line $DF. T-172 follow-up |
| Raft round trip | initial 890CCB87 | `builds/reports/lockstep/t056_raft_t181_sync` | FAIL: first KEY divergence tick468, LinkY NES$7C/Genesis$78. T-056 remains REVIEW |
| UW ladder cloud fixture | initial 890CCB87 requested | `build/scratch/t181_ladder_uw.log` | NES dies/reaches mode8; no play tick for1200 frames at tick1045. Genesis never launched. Fixture failure is not runtime acceptance or a Genesis defect |

Initial payload SHA-256: `890CCB877FA05E36AA9FB1C6F58FF5D96CF190E8560100BAEC6638381EC41D70` (`builds/playtests/Debug-T181.md`).
Final payload SHA-256: `EE5979A0F351D9519B9EEB176A050B5C98FE5E04A6B15A878C3CE1998C1CDAAF` (`builds/playtests/Debug-T181-sync.md`). Both are private local files.

## Handoff

Source synchronization does not pass T-056, T-171, T-172, or connected quests. Next: diagnose raft tick468 from the source and captured state, repair the UW test route, and profile only the named ladder scene. Keep music deferred. GitHub routine-equivalence claims remain attributed to Claude's cloud run; Windows integration is limited to the rows above.

The local generated-input overlay is intentionally excluded from publication. It is retained on disk and backed up with SHA-256 manifest under `.pre-merge-backup/T181-20261002/synced-local-inputs`. A new machine must generate game-derived inputs from the user's supplied ROM; this sync does not claim the incomplete T-080 builder release is finished.
