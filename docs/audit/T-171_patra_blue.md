# T-171 — blue Patra variant (2026-10-01)

NES source: `Z_04.asm:InitPatra, PatraChild_State1, PatraChild2RotationBits,
UpdatePatra, PatraChild_Draw`. Owners: existing `boss_patra.c` orchestrator,
`enemy_patra_runtime.c` and shared draw/collision paths. Drain stance: ADOPT/
EXTEND current implementation; no gameplay fix required. Coverage: staged Q1
L9 $16 blue variant spawn/orbit/maneuvers/contact/children/parent/death/drop.
Pickup, departure, re-entry/SRAM and connected L9 remain separate acceptance.

ROM-derived LevelBlockUW2Q1 AttrsC/D decode identifies $16 as type$48; no
enemy type is injected. Level entry staged at50 and normal mode-3 room reload
at300. Magic sword, red ring and full health are declared prerequisites. NES
controller-only bot starts340, kills then waits; its 1068 inputs are folded
into the committed 1408-tick preset. No correction after entry. The bot's
early loot task completes before the parent's drop appears, so this case
does **not** establish pickup; it keeps the drop visible for comparison.

Live blue parent$48 has eight type$26 children, unlike red parent$47/$25.
Blue angle decreases$60/tick (380:$1B80,381:$1B20,382:$1AC0), not red$70.
Maneuver toggles376/632/803/1059 exercise small/large circular orbits through
the ROM-adjacent rotation-bit lookup. All unmasked live angle/position/state
bytes agree between NES and Genesis for the whole route. Nine contact-damage
events include the same quarter-heart ring rule, invincibility and recovery.

Children clear505/522/565/581/708/900/1086/1183. Parent HP stays$B0 while
children remain; accepted hits1238($70) and1272($30); death1307, drop1326.
Eight SCREEN MATCH ticks350/650/1000/1183/1238/1307/1340/1407 verify appearance,
orbit/animation, death and drop. No static overlap difference at those ticks.
**1408/1408 GATE PASS**, no KEY allowance. New baseline66 cells consists only
of the familiar65 startup cells and accepted OAM rotation$342 at tick1.

Full video trace: no fight stalls. Staged reload300 costs102 NES/103 Genesis
frames, one extra load frame; recorded under T-172, not called whole-scene
performance PASS. User's one-frame tolerance applies, but the stricter
performance backlog remains visible. No baseline masks or timing workaround.

`Debug.bat` rerun after coverage-comment updates PASS, freshness9/9; game ROM
SHA unchanged from the frozen tested T-178 image:
`2ED27FFB37E315C03132ED0D51CC0C9DC0A333EBDAA1EA1954AF4231C40112B5`.
Reports: `t171_patra_blue_codex_blue_trial` (NES bot),
`t171_patra_blue_codex_blue` (paired RAM/video/screens); baseline
`tools/lockstep/baselines/t171_patra_blue.json`. Prior red Patra/fairy evidence
carried forward; no repeated full red fight or dungeon matrix.
