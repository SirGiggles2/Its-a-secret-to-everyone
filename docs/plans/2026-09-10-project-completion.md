# Zelda Genesis completion plan: implementation and focused BizHawk testing

> **2026-09-24:** The live work board moved to `docs/TRACKER.md`. This file keeps task definitions (P#.# IDs), evidence rules and the execution history below. Do not update the "Live work board" section here.


Updated 2026-09-10 to reflect the user's explicit direction: Genesis hardware support is already established; finish the game without repeating broad tests that stall implementation.

**Shipped product:** a drag-and-drop program. The user supplies their own supported NES Zelda ROM; the program validates it, extracts/converts the required assets locally, builds the completed Genesis port, and saves the Genesis ROM on that user's computer. The download contains the builder and distributable implementation/dependencies, not a NES ROM, a prebuilt Genesis game ROM, or extracted source-game assets. Do not download replacement game assets or ROMs to complete the build.

**Goal:** finish that program and the complete native Genesis game it produces, including both quests and required presentation/audio. Local development ROMs are build/test artifacts, not release deliverables. Preserve working implementation, captures and tools. Replace individual systems only when a demonstrated problem requires it.

**User flow:** launch builder -> drop NES ROM -> validate supported revision -> show extraction/build progress -> write Genesis ROM -> show output location. Provide a file-picker alternative and a useful error for unsupported input. Preserve the supplied NES file. The user must not need this repository, developer-only caches, manual Python commands, or BizHawk installed just to generate the ROM. Bundle or explicitly handle required distributable runtime/toolchain dependencies in the program's installer/package.

**Current target:** Debug.bat -> tools/debug/build_debug.py -> builds/Debug.md. The master plan's sole-target amendment supersedes obsolete target names elsewhere. Approved custom title/file-select behavior stays approved. Four-player mode remains optional and outside the base-game completion path.

This replaces the earlier recovery outline at this path. The existing master plan remains the feature inventory; this document defines the recovery work order and test cadence. Writing this plan closes no phase. No BizHawk runs were performed during this planning pass.

## Approved recovery amendment — 2026-09-12

This amendment supersedes conflicting execution order below while preserving task IDs and historical evidence. First release is Original gameplay, both quests, with the Windows user-ROM builder. Preserve approved custom title/file-select presentation. Redux is subsequent milestone P11; four-player gameplay is outside this release. Neither expands Original acceptance.

Keep TODO, ACTIVE, PASS, FAIL, BLOCKED. Record behavior/owner/dependencies, NES source, Drained C, Coverage, Stance, scenario/build/result and applicable evidence scope (data, behavior, presentation, integration, persistence). Parent PASS requires its required children. Carry forward valid unchanged evidence. Do not restore multi-model debate rounds or blanket per-fix matrices.

### Foundation additions1

| ID | State | Work and acceptance |
|---|---|---|
| P0.10 | PASS | Read LevelInfo/common data through ROM pointers, preserve 256-byte LevelInfo copies, correct nine linked regions and compensating offsets; verify source fields and affected reward behavior. |
| P0.11 | TODO | Map linked ownership, duplicate paths, active stubs and debug overrides for every required system. |
| P0.12 | ACTIVE | Reconcile player, inventory, progress, options and save owners; define mirror synchronization. |
| P0.13 | TODO | Shared room-entry state and transient cleanup across scroll, direct entry, caves, dungeons and continue. |
| P0.14 | TODO | Carry repaired assets through user-ROM extraction using the existing 42-input inventory. |
| P0.15 | TODO | Record actual graphics ownership, residency and VDP-mode-specific tile/sprite budgets. |
| P0.16 | TODO | Fill missing representative system evidence; record failures promptly rather than expanding probes. |
| P0.17 | TODO | Before legacy launcher reuse, remove global emulator termination; missing/empty/timed-out execution cannot pass. |

Execution: preserve evidence and record known failures -> P0.10 -> targeted ownership/data review -> missing baseline coverage. P0.1-P0.9/P0.3a retain their narrow accepted scope.

### Execution order across existing Parts

1. P2 movement / P4 inventory prerequisites: Original controls, alignment, speed, collision, corners, doorways, animation, knockback/recovery, input locks; item IDs, ownership, upgrades, health/resources and selection.
2. P7 HUD/pause / P5 maps: health/counters/equipment, display updates, freeze/resume/input consumption; Original OW locator, UW layout/current/visited rooms/map reveal/compass and state changes across slots/quests.
3. P2 normal opening / P4 caves: boot/file creation -> sword cave -> award -> exit -> combat/pause/save; text, shops/gifts/hints/money games, rejected purchases and one-time flags.
4. P3/P4 combat/items/enemies: sword tiers/beams/shields, damage/invulnerability/stun/death/drops; all inventory actions and restrictions; walkers/flyers/jumpers/aquatic/projectile/burrower/trap and special behaviors (splitting, children, directional defense, grabbing, transport, theft, bubbles, terrain). Verify visible projectiles and cleanup as well as damage.
5. P4 world: adjacency/scrolling, secrets/bomb walls/bushes/blocks, recorder/transport, raft/ladder/shortcuts, Lost Woods/Hills, entrances and both quests' locations.
6. P5 dungeons: open/key/master-key/shutter/bomb/false-wall doors with matching art/collision/persistence; blocks/stairs/cellars/passages/darkness/traps/people/keys/maps/compasses/rewards/Triforce.
7. P1/P6 bosses: Aquamentus integrated entry/fight/reward/exit/reentry, then Dodongo, Manhandla, Gleeok, Digdogger, Gohma, Patra, Moldorm/Lanmola, Ganon and distinct variants. Each row includes visible attacks, vulnerability, transformations, death/cleanup and scene budget.
8. P7 lifecycle/presentation: save/load/copy/erase/slot independence/version compatibility; death/continue/resources/progress; options/frontend/music/SFX/fanfares/low-health/pause/text/endings. Audio event fixes precede driver redesign; SGDK-4 applies.
9. P8/P9 connected quests: separate L1-L9 rows for entrance/prerequisites, items/locks/passages, boss/reward/departure and persistence; normal connected routes through Ganon/rescue/endings, Q2 entry/differences and off-route content. No injected progression between segments.
10. P10 release: busy-scene/boss/transition performance; existing CLI beneath Windows drop/file picker app, validation/progress/errors/output/dependencies; clean staging, input unchanged, spaces, invalid input, one reproducibility repeat, generated-ROM launch. No bundled ROMs/extracted assets or remote game-data dependencies.
11. P11 subsequent Redux: preserve work, reconcile catalog/conflicting options before later implementation. Original isolation checks selected configuration/assets/rules/options, not absence of symbol names.

### Baseline gaps and test rules

Inspect missing normal boot, movement, cave, HUD/inventory, maps, doors/passages, sprites/projectiles, boss, death/save and Q2 evidence. Existing launcher and hardware proof is not system acceptance. Known backlog: user HUD/invisible attacks; reported door/wall appearance pending NES comparison; LevelInfo flags pointer; room-only item persistence; native item metadata discrepancy; death-spark placeholder; L7 missing BG; L2 invisible Dodongo; movement stop-position difference. Preserve accepted projectile kill-count repair; Link wrong-art suspicion remains unsubstantiated.

One focused reproduction and passing verification per repair, plus named affected consumers. Screenshots for static visuals; clips for motion/audio. Staged setups disclose writes and do not pass connected routes. Missing reports/timeouts/zero cases are errors. Refresh incompatible checkpoints. Resolve emulator ownership dynamically and leave the user's frozen play build alone. No complete-system claim while required behavior remains broken or unverified.

## Live work board — read this first when resuming

This plan is the single recovery checklist and progress record. Do not create a competing completion spreadsheet, JSON tracker, or status document. Existing machine-generated phase labels remain historical/scope-tooling information; they cannot mark these tasks complete. Keep the applicable safeguards, and reconcile conflicting active-action pointers when execution reaches them.

**Last update:** 2026-09-12, approved recovery ordering installed; P0.10 extraction/installed-data/reward-reveal passed. Controller pickup and complete-game acceptance remain open.

**Accepted baseline:** Genesis hardware operation is established by the user. Preserve existing valid behavior/reference evidence. TODO below means remaining acceptance/repair work for the package, not that every subsystem must be rebuilt or retested.

**Active task:** P0.11/P0.12 — state ownership; P1.7 same-session entry/fight/reward/exit/reentry now passes, real save persistence remains open.
**Next task:** reconcile item/progress/save owners and missing normal-save wiring; inspect user HUD/projectile/scenery concerns. Preserve user emulator ownership dynamically.
**Next sequence:** ownership/data baseline -> movement/inventory -> HUD/maps -> normal opening -> combat/world/dungeons/bosses -> lifecycle -> connected quests -> builder release.
**Current implementation blocker:** none for the prepared fix. User removed the unavailable-reviewer requirement from the skill and authorized continued implementation.

**Last accepted recovery run:** L1Q1-0787aaa30686, ENTRY_ONLY, BizHawk 2.11/GPGX, ROM a37715a371e1337bb3cefda370a3a57aba5511116cedc2a4c36ed71b044cfb5b. Debug chord and synthetic warp only; no boss victory or normal traversal claimed.

| Part | Status | Result / next checkpoint |
|---|---|---|
| P0 Baseline and selected runner | ACTIVE | Fresh build, scoped live entry, current-address check, four contract tests |
| P1 Aquamentus | ACTIVE | Green boss, scoped death/reward, projectile lifecycle and fireball harm verified; normal route, remaining contact/presentation and persistence open |
| P2 Opening through Level 1 | TODO | Connected normal-input route |
| P3 Combat and enemy families | TODO | Required distinct behaviors covered |
| P4 Items, overworld and secrets | TODO | Required interactions covered |
| P5 Dungeon mechanics/data | TODO | Unique mechanics and affected data accepted |
| P6 Remaining bosses | TODO | Distinct boss mechanics and variants accepted |
| P7 Saves, pause, frontend, audio | TODO | Pause-menu appearance disputed by user; P7.1a FAIL pending NES comparison and repair. Normal lifecycle and presentation remain open |
| P8 Quest 1 | TODO | Connected completion and content gaps closed |
| P9 Quest 2 | TODO | Connected completion and quest differences covered |
| P10 Release | TODO | Drag-and-drop builder package; generated game stays local |

### Task updates

Every checkbox below has a stable ID. Keep IDs stable if tasks are inserted; use a suffix such as P1.3a rather than renumbering. Use TODO, ACTIVE, PASS, FAIL or BLOCKED. Mark a checkbox [x] only when its stated result is satisfied by implementation plus the selected relevant evidence, or explicitly carried-forward evidence that still covers it.

Update this board after each completed task, a failure/blocker, or before ending a working session. During a long task, record the exact intermediate checkpoint if stopping. Do not tick tasks merely because code was written or an old phase was closed.

Keep one result row per worked task; update the row rather than duplicating every run:

| Task ID | State | What changed / accepted | Evidence or reason | Build identity |
|---|---|---|---|---|
| P0.1 | PASS | Changes, plan, original untracked completion directory, ROM and ELF preserved; copied artifact hashes checked | Private sibling folder FINAL-TRY-recovery-20260911-074018/snapshot.json; git ref codex/recovery-baseline-20260911-074018 | f513b997; original ROM SHA256 7eaab9daa0d9fc39ac3d6826c8e20118d35e47744ad3e2a2c1ab93171d4c4301 |
| P0.2 | PASS | Fresh Debug build and live entry; restored matching aggregate input and removed an unreferenced missing build source | [Build/provenance record](../../builds/reports/recovery/baseline-accepted.json), [entry result](../../builds/reports/dungeon_harness/L1Q1-0787aaa30686/result.json) | f513b997 + recorded source hashes; ROM a37715a371e1337bb3cefda370a3a57aba5511116cedc2a4c36ed71b044cfb5b |
| P0.3 | PASS | Current debug mirrors/control contract read and exercised | roomrom_debug_runtime.h plus live entry result | Same accepted ROM |
| P0.3a | PASS | Inventoried 42 linked asset/generated inputs; public dispatcher only calls extract_audio.py | [Input inventory](../../builds/reports/recovery/generated-input-inventory.json); CHR/rooms and cache reconstruction assigned to P10.2 | Current linked source list |
| P0.4 | PASS | Selected-row launcher executes BizHawk; legacy completion remains refused | run_all.py; accepted entry result | Same accepted ROM |
| P0.5 | PASS | Unique identity, ROM hash, entry/completion scopes and error handling | Four focused tests passed; missing-state dry-run returned ERROR | Current runner |
| P0.6 | PASS | Hidden owned process, short paths, isolated profile/SRAM and timeout | Accepted launch.json; failed default-profile attempt retained separately | BizHawk 2.11 |
| P0.7 | PASS | Actual GPGX domains enumerated with pairs; current RAM mirror verifies level/quest/room/frame progression | Accepted entry result | Same accepted ROM |
| P0.8 | PASS | Current ELF resolves slist_addr and regValues; entry state agrees on SAT $F400 and reg5=$7A | [VDP read](../../builds/reports/recovery/vdp-state.txt); no gameplay rerun | Same accepted ROM/ELF |
| P0.9 | PASS | Captured scoped L1 entry state, not normal-doorway checkpoint | L1Q1-0787aaa30686/entry.State; SHA256 8227071a486c6ba5e7b5e4efeae3600ae5b859b1040d61e6753608232a172678 | Same accepted ROM |
| P1.1 | ACTIVE | Staged adjacent room $45 with position and one key; subsequent input-only north entry initializes $35/$3D, HP $60, moves/fires for 120 frames. Full naturally reached predoorway provenance remains open | [Doorway trace](../../builds/reports/recovery/p1-nes/doorway-key.txt), boss-60.png, OAM/PALRAM/VRAM dumps; explicit staged setup | NES SHA256 8f72dc2e98572eb4ba7c3a902bca5f69c448fc4391837e5f8f0d4556280440ac |
| P1.2 | ACTIVE | Genesis live direct warp to $35 spawns $2A, HP $20; room block is byte-identical to incorrect linked data. Normal entry/fight not passed | [Genesis trace](../../builds/reports/recovery/p1-gen/boss.txt), ram-60.bin, boss-60.png | Accepted ROM a37715a3... |
| P1.3 | ACTIVE | First divergence proven at generated room blocks; boss dispatch receives wrong type. Continue downstream after correction | Candidate verification.json: current ROM pointers $8D00/$9000 used for both quests; NES Q1 uses $8700/$8A00 | Existing generated data |
| P1.3a | PASS | Q1/Q2 source-table diagnosis: whole 768-byte live Q1 block matches ROM's Q1 pointer target; current Genesis block matches ROM's Q2 target | [Byte comparison](../../builds/reports/recovery/p1-candidate/verification.json) | NES and Genesis hashes in report |
| P1.4 | PASS | ROM-derived Q1/Q2 blocks restored; dependent collision mappings regenerated. L1/$35 and L7/$2A both spawn $3D, HP $60 | [Data-fix result](../../builds/reports/recovery/p1-room-data-result.json), p1-build.log | Run-specific ROM hashes in result |
| P1.5 | ACTIVE | Boss multipart/palette/residency and heart art repaired; empty-slot sprites and stale frame entries fixed. Death spark still placeholder | [Projectile diagnosis](../../builds/reports/recovery/p1-projectile-diagnosis.md), final reward screenshot | ROM8720693b... |
| P1.6 | ACTIVE | Dynamic shots initialize with E3 attributes; no projectile kills, boss death gives one kill. Fireball harm is half-heart/inv24 on NES and GEN. Normal doorway/body contact and full timing remain open | [Scoped result](../../builds/reports/recovery/p1-projectile-result.json); p1-contact and p1-nes-contact | ROM8720693b... |
| P1.7 | ACTIVE | Foes-for-item activation and heart collection77->88 verified; ordinary key consumer0->1. Transition/save/reload and room-flag data still open | [Diagnosis](../../builds/reports/recovery/p1-reward-diagnosis.md); p1-key-consumer/result.txt | Same final reward ROM |


For a game change, evidence is a short scenario/result and a relative link to its existing report or capture, tied to commit plus dirty-change identifier when needed and ROM hash. For documentation/preservation work, use the relevant file or snapshot; no emulator evidence required. For carried-forward evidence, identify its source and why the task's dependencies remain covered.

A failed test records the actual failed condition and the next action in the same row. A blocker names the missing input/state/tool and the smallest unblocking action. An unrelated blocker does not hide other independent work.

When changes affect a previously accepted task, reopen only that task and identified consumers. Preserve prior evidence; do not reset the entire part. No percent-complete calculation: task sizes differ. User updates report the completed task/result, current task and next task.

At a fresh session: read this board, check current git/build identity, inspect the active or next task and its evidence, then continue. A build change does not automatically require a full test rerun.

## Ground rules

- Accept the user's established Genesis hardware results. Do not reopen general compatibility or create a new mandatory hardware campaign. Investigate a specific hardware regression only if one appears.
- Carry forward valid evidence for unchanged systems. A historical passing room-background comparison proves that scope; it does not prove boss combat. Do not reset all work to unverified.
- One integration owner and one coherent repair at a time. No wholesale rewrite, mass renaming, or broad architecture migration.
- Start at the known boss/capture defect after a short current-build sanity check. Repair opening-route blockers when encountered; do not repeat the whole foundation before reaching the known issue.
- The user's reduced-testing direction governs routine work over older blanket requirements for a full matrix or eleven-step phase closure after each fix. Retain applicable source ownership, reference and build safeguards. Use project-wide acceptance at the final candidate, not after every local change.
- Passing the selected relevant test ends verification unless there is a named unresolved concern or affected dependency.
- Report implementation changed, scenario/result, remaining blocker and next task. No percentages inferred from old phase numbers.

## Evidence from the planning inspection

Source inspected: main at f513b997.

| Existing artifact | Actual scope / implication |
|---|---|
| docs/parity/dungeon_status.md | Historical 171/171 Q1 BG passes; preserve them where dependencies are unchanged. Last boss investigation needs clean live NES evidence. |
| tools/dungeon_harness/run_all.py | Live path currently skips BizHawk launch. Dry-run can exit zero despite skipped rows. Repair selected-row execution before treating it as completion testing. |
| tools/dungeon_harness/probes/dungeon_1_q1.lua | Load-only GREEN checks room and level. It does not fight a boss or collect a reward. |
| tools/dungeon_harness/manifest.json | Inspected state/reference hashes are null. Populate the first useful row, then others as needed. |
| tools/debug/probes/probe_boss_matrix.lua | Injects object types and checks frame advancement. Useful dispatch smoke only. |
| tools/parity/cave_golden/probe_gen_boss_live.lua | Hardcoded SAT address and mirrored-RAM assumptions require validation against the current build. |
| tools/run_regression_matrix.py | Can report GREEN with no discovered probes. Read executed coverage and artifact freshness, not just the summary. |
| Boss atlas and Ganon bridge stubs | Present in source. Confirm actual linked callers before replacing anything; unused legacy code is not automatically release work. |

These are reasons for a small repair to the verification path, not a new testing platform.

## Test budget and stopping rules

| Change | Default test | Stop when |
|---|---|---|
| Documentation only | Review content/links | Correct; no build/emulator run |
| Local gameplay behavior | One build and one affected BizHawk scenario | Visible behavior and relevant state pass |
| Shared combat/input/state/rendering | Affected scenario plus 1–2 named consumers | Changed path and consumers pass |
| Dungeon or boss completion | Short entry/fight/reward/exit route | Required events observed once |
| Generator/global renderer | Affected room samples, then the relevant existing sweep once after stabilization | Changed data scope covered |
| Quest completion | One connected route, resumable across sessions | Normal progression reaches ending |
| Final package | Remaining gaps, short performance sample, clean builder checks | Required release rows accepted |

Runtime targets, excluding builds: local scenario approximately 30–120 seconds of emulated action; small regression selection approximately 3–5 minutes. Real fights/routes may take longer. These are planning targets, not arbitrary failure thresholds. Give probes scenario-specific frame limits and launch wall-clock timeouts.

Default evidence is one short event log, the relevant before/after state, and 1–3 screenshots for visible changes. Use a short clip for motion/audio. Dump RAM/OAM/SAT/VRAM/CRAM only to answer a concrete discrepancy.

Reuse NES captures. Capture new live reference evidence for unknown or disputed behavior. Align on events such as entry, attack, hit, death and reward, not boot-frame numbers. Compare relevant fields, respecting established platform differences. Do not demand unrelated RAM or raw cross-platform sprite equality.

One passing deterministic run is enough. Repeat only for a changed build affecting that case, intermittent failure, ambiguous result, or new coverage gap. Never rerun all 18 dungeons after a local sprite fix.

## Part 0 — Recoverable baseline and one honest BizHawk test

**Deliverable:** one real selected L1Q1 test execution, not an entire new harness.

- [x] **P0.1** Preserve current changes, untracked work, ROM and useful references. Record the starting commit/output hash. Leave existing tools/audit/completion/ content intact.
- [x] **P0.2** Build once through Debug.bat and launch that exact output. Confirm boot and the established gameplay entry; this establishes artifact identity, not hardware compatibility.
- [x] **P0.3** Read the active link sources, state definitions and exports needed for the first scenario. Avoid an inventory of every repository symbol.
- [x] **P0.3a** Identify required game-derived build inputs that still depend on checked-in blobs or developer caches; record their existing extractor or the missing extraction step under P10.2. Carry each repaired/generated asset through the user-ROM extraction path as implementation proceeds. Do not leave all extraction gaps until release.
- [x] **P0.4** Extend tools/dungeon_harness/run_all.py in place to launch one selected row, wait with timeout, and consume a fresh report. Keep its existing --level / --quest selection.
- [x] **P0.5** Bind report to scenario, ROM hash and a unique run directory/ID. Missing report, missing state/domain, launch failure or timeout is ERROR. Old JSON cannot satisfy a new run. Entry-only checks remain explicitly ENTRY_ONLY.
- [x] **P0.6** Resolve absolute output/state paths. Use full 8.3 argument paths where available, or verified space-safe staging. Launch automated probes hidden and stop only the owned process; preserve the user's other emulator sessions.
- [x] **P0.7** Verify available domains. Genesis GPGX uses 68K RAM, VRAM, CRAM and VSRAM. Resolve the current nes_ram/native-state location from linked definitions. Some current probes add 0x8000; old direct-offset reads must not be copied blindly. NES uses its own verified RAM/OAM/palette domains.
- [x] **P0.8** Derive SAT/table addresses from current VDP configuration or authoritative exports; do not assume old $F400. Explicitly release Lua joypad buttons between segments.
- [x] **P0.9** Pin a useful starting state with ROM/core identity. Old Genesis states may embed old code/RAM assumptions: regenerate after incompatible build changes using boot/SRAM plus a short setup route. Do not silently reuse them across builds.

**Test:** one selected scenario produces a fresh report; one deliberately missing-state run reports ERROR. Add a small runner check for stale/missing reports if needed, not an exhaustive launcher suite.

**Stop:** selected-row execution is trustworthy. Populate remaining states only when their tasks need them.

## Part 1 — Resolve Aquamentus end to end

**Inspect:** src/game/enemies/obj_lists.c, enemy_loop.c, enemy_boss_bridge.c; RoomRom/src/atlas/; src/game/world/sprite_dispatch.c; src/game/world/render/sprite_render.c; corresponding src/oracle/enemies/ and NES routines.

- [ ] **P1.1** Obtain a clean live NES entry into the actual boss room, preferably from an existing valid pre-doorway state. Record room/level, object type, initialized state and actual sprite composition. Forced game-mode changes or halted actors cannot establish this reference.
- [ ] **P1.2** Capture equivalent Genesis entry/events. Debug warp can isolate rendering but cannot pass normal entry.
- [ ] **P1.3** Trace room data -> template expansion -> dispatch -> boss init -> update -> sprite construction -> SAT upload. Resolve the reported $3C/$3D discrepancy at the first real divergence; do not blindly shift an index.
- [x] **P1.3a** Identify the first table-source divergence against ROM pointer tables and the full live NES room block. Q2 blocks were installed for Q1.
- [x] **P1.4** Correct the responsible data transformation, generator, initialization or renderer. Fix generated assets at their generator.
- [ ] **P1.5** Finish multipart layout, flips, palette, animation and projectiles. Inspect CHR/SAT only when the visual result needs explanation.
- [ ] **P1.6** Finish appropriate weapon damage, boss damage to Link, invulnerability/contact handling, death and projectile cleanup.
- [ ] **P1.7** Finish applicable reward spawning/collection, transition and persistent completion.

**Test:** one controller-driven fight from a pre-doorway state: entered -> initialized -> attacked -> damaged -> killed -> reward collected. Do not write HP/alive/clear flags after the start checkpoint. Keep one boss screenshot and death/reward evidence. If shared upload changes, additionally check one ordinary enemy and one item effect.

**Stop:** correct live fight and reward. Retain this short scenario as the representative boss regression.

## Part 2 — Connect normal start through Level 1

**Inspect:** src/frontend/, RoomRom/src/main.c, src/game/cave/cave_entrance.c, src/game/world/transition.c, scene_load.c, level_info_install.c, active sword/inventory/door hooks.

- [ ] **P2.1** Normal boot -> file select -> new game -> overworld. Accept existing working behavior without redesign.
- [ ] **P2.2** Sword cave entry, one-time sword award, inventory/HUD update and correct exit position.
- [ ] **P2.3** Representative room crossings, wall collision, enemy attack/damage and recovery.
- [ ] **P2.4** Walk into Level 1: correct level data, palette/CHR handoff, Link placement, enemies and resumed input.
- [ ] **P2.5** Required L1 rooms, locks/items/clear conditions, Part 1 boss, reward and exit/progression.
- [ ] **P2.6** Pause/resume and save/reload once along the route. Fix a blocker immediately; otherwise assign it to Part 7.

**Test:** one opening-to-L1 controller route divided into resumable segments. Retry failing segments during repair, then verify their connected seam once. Synthetic round-trip output is supplementary.

**Stop:** first integrated playable route. Reuse its checkpoints in later packages.

## Part 3 — Shared combat and ordinary enemy families

**Inspect:** src/game/combat/, src/game/enemies/enemy_loop.c, enemy_*_bridge.c, enemy_render.c and src/state/ combat/link/enemy definitions.

- [ ] **P3.1** Follow movement -> animation -> attack -> collision -> damage -> invulnerability/knockback -> death/drop. Correct the owning function instead of adding room-specific exceptions.
- [ ] **P3.2** Finish sword directions/reach, relevant projectile/shield behavior, enemy/Link HP and attack lifetimes.
- [ ] **P3.3** Work family by family: walkers, flyers/jumpers, projectile users, special enemies, terrain/aquatic enemies.
- [ ] **P3.4** Enumerate required types from current tables/reference data. Complete spawn, art, animation, movement, attacks, vulnerability and death for each distinct behavior.
- [x] **P3.4a** Keep the enemy audit inventory aligned with the expanded whole-game scope; previous exclusions remain historical only. Octorok and Tektite results stay partial by family.
- [ ] **P3.5** Verify room-clear decisions, drops, stale projectiles and room re-entry cleanup.

**Test:** one encounter per behavior family; add cases only for unique branches such as splitting, immunity, shield or terrain behavior. Reuse walker/combat probes after checking their actual verdict. Shared damage changes additionally run Aquamentus's damage segment.

**Stop:** every required enemy type maps to an accepted family case or an explicit unique case. No every-enemy-in-every-room matrix.

## Part 4 — Items, overworld and secrets

**Inspect:** src/game/items/, src/game/world/, src/game/cave/, src/state/inventory.*, weapon state and linked RoomRom item modules.

| Work unit | Details | Focused test |
|---|---|---|
| Sword/shield upgrades | Acquisition, equipment effects, applicable beams/blocking | Acquire/equip, attack/block |
| Boomerang | Facing, flight, return, stun/pickup, catch | One throw/target/return |
| Bombs | Resource use, fuse/blast, enemy and wall interaction | Enemy blast plus secret/door |
| Bow/arrows | Ownership, resource cost, projectile/special targets | Valid shot and insufficient-resource rejection |
| Candle | Use restriction, moving/standing flame, damage/secret | Flame effect, restriction, one burnable secret |
| Recorder | World event/warp and boss dispatch | One world effect; boss effect in its fight |
| Raft/ladder | Activation, collision support, traversal cleanup | Crossing and return |
| Wand/book | Projectile, impact and secondary effect | One complete effect sequence |
| Bait/letter/potion | Person response, inventory/consumption, healing | One distinct use each |
| Rings/bracelets/keys/passive items | Ownership, rule changes, persistence | Action demonstrating changed rule |
| Shops/gifts/hints/money/secrets | Text/items, affordability, one-time flags, return | Purchase, rejected purchase, gift and each distinct secret mechanism |

- [ ] **P4.1** Reconcile the table with the full NES-derived item list so uncommon items are covered.
- [ ] **P4.2** Route awards through the real inventory/save path; eliminate cosmetic-only state.
- [ ] **P4.3** Test repeated secrets by generator/data coverage and one example per unique mechanism.

**Test:** group related interactions into short sessions. Inspect resources/ownership and repaired visible effects. Do not rerun dungeon BG sweeps for an item-use change.

**Stop:** required interactions work; location-specific progression is covered by quest routes.

## Part 5 — Dungeon mechanics and data

**Inspect:** src/game/dungeon/uw_render.c, src/game/world/level_info_install.c, room/transition/door/collision paths, RoomRom/data/ manifests and tools/parity/cave_golden/regen_dungeon_blob_from_sram.py.

- [ ] **P5.1** Resolve erroneous room tags/data at the generator. A manifest label is not proof of actual room contents.
- [ ] **P5.2** Keep collision publication synchronized with rendering, incoming doors, Link placement, scroll completion and spawning.
- [ ] **P5.3** Finish ordinary/key/master-key doors, shutters, bomb walls, push blocks, stairs/passages, lighting, traps and dungeon-person interactions where applicable.
- [ ] **P5.4** Finish maps/compass, dungeon items, keys, heart/reward collection and persistent room/door/secret flags.
- [ ] **P5.5** Distinguish quest-specific routing/content from genuinely shared data; avoid blanket assumptions.

**Test:** a compact room chain covers the representative mechanisms, with only distinct variants added. A generator change gets affected-room samples first and one relevant level sweep after stabilization.

Existing selection: python tools/parity/cave_golden/run_dungeon_sweep.py 1 1 --rooms 73,63. Before reuse, adapt its launcher/ROM copying as needed: inspected code contains global emulator termination and a cp subprocess. Preserve other emulator sessions. Historical 171-room BG coverage is not rerun for combat-only work.

**Stop:** all distinct dungeon mechanics accepted and no remaining data defect blocks routes.

## Part 6 — Remaining bosses

Reuse Part 1's real entry/fight/reward structure. Work in src/game/enemies/bosses/, active bridges, combat and atlas generators. Enumerate variants from real object tables and quest placements; this is a behavior checklist, not an authority for numeric IDs or placements.

| Group | Implementation focus | Minimum result |
|---|---|---|
| Dodongo variants | Bomb states, vulnerability, death | Valid damage/kill and one inappropriate attack rejected |
| Manhandla | Multipart body, hit routing, speed/state changes | Parts and complete defeat behave correctly |
| Gleeok variants | Head counts, attachment/detachment, projectiles/lifetimes | Variant differences plus one complete multipart fight |
| Digdogger variants | Recorder response, transformation/children, clear condition | Transformation and final defeat |
| Gohma variants | Eye window, arrows, variant damage | Correct-window hit, wrong-window rejection, defeat |
| Patra variants | Orbiting members, center vulnerability, rendering | Children/center progression and defeat |
| Moldorm/Lanmola | Segments, movement, damage and cleanup | Segment behavior and final clear |
| Ganon | Visibility/state cycle, attacks, sword damage, silver-arrow finish | Actual combat kill leading to rescue events |

- [ ] **P6.1** Replace active Ganon stubs through existing state/dispatch contracts; ignore unused wrappers unless they affect output.
- [ ] **P6.2** Verify each encounter's applicable death/reward behavior, not a universal drop assumption.
- [ ] **P6.3** One invalid attack/state case per special vulnerability is enough; no full weapon-by-boss Cartesian matrix.
- [ ] **P6.4** Shared variants receive initialization/difference checks rather than repeated identical long fights.

**Test:** one successful kill per distinct mechanic, plus variant differences. Use short clips/event frames for animation. Shared boss rendering/combat changes run the current boss, Aquamentus and one structurally different case.

**Stop:** all required encounters covered. Dispatch survival does not count as victory.

## Part 7 — Pause, saves, death, frontend and audio

Handle route blockers earlier; otherwise finish here.

- [ ] **P7.1** Pause: toggle, item selection, map/compass, input consumption, freeze/resume and no extra attack. Inspect src/state/pause_state.*, src/game/inventory/ and linked pause hooks. Use tools/parity/pause_golden/ only for unresolved layout discrepancies.
- [ ] **P7.1a — FAIL (user-reported)** Pause-menu visual parity. Compare the current Original pause menu against the corresponding live NES reference, identify each wrong element and its owning renderer/asset/palette/scroll path, repair it, and verify one representative OW and UW pause screen plus any distinct affected case. The accepted marker-coordinate and item-ownership probes remain valid only for those narrow behaviors; they do not pass the full menu appearance.
- [ ] **P7.2** Saves: inventory, quest/progress, room flags, intended health/continue behavior and options. Inspect src/state/save_serializer.* and src/sgdk_adapter/sram_*. Verify restart through SRAM, not emulator savestate restoration.
- [ ] **P7.3** Death/continue: temporary attack cleanup, correct spawn/resources and retained progression. Inspect mode_death.c, mode_continue_question.c and scene handoff.
- [ ] **P7.4** Frontend: actual file creation/selection/management, options, title/story and return paths. Reuse the accepted opening sequence and preserve approved visuals.
- [ ] **P7.5** Audio: relevant overworld/cave/dungeon/boss/death/ending transitions, SFX, low-health and options. Inspect src/game/audio/audio_dispatch.c and src/sgdk_adapter/audio_adapter.c. Fix missing event calls before redesigning the driver.

**Test:** pause/select/resume; save/close/reopen/continue plus alternate-slot/quest check; one short music/SFX montage. Listen when assessing sound—register writes alone are insufficient. Do not rerecord already-correct songs.

**Stop:** normal play survives pause, death and restart; menus/audio follow the game.

## Part 8 — Quest 1 completion

- [ ] **P8.1** Populate L1–L9 rows incrementally using actual playable entry checkpoints. Record item/progression, boss/reward and exit facts.
- [ ] **P8.2** Per dungeon cover entry, critical item/locks/passages, boss, reward and next transition. Reuse mechanic tests from prior packages.
- [ ] **P8.3** Verify Level 9 access, Ganon, Zelda rescue, ending and subsequent progression using actual state definitions.
- [ ] **P8.4** Complete one connected quest route. Resume across sessions from checkpoints produced by that route; do not inject missing inventory or completed dungeons between segments.
- [ ] **P8.5** Reconcile required content outside the critical path against existing evidence. Cover remaining unique rooms/items/interactions; do not manually traverse unchanged data already adequately covered.

**Test:** after Part 0 makes the runner live, use python tools/dungeon_harness/run_all.py --level N --quest 1 for the current dungeon. --quest 1 is a checkpoint run, not a per-edit command. Local staged states prove only their stated segment. A connected route must preserve state continuity.

**Stop:** Quest 1 ending through normal progression and explicit coverage of required off-route content.

## Part 9 — Quest 2 completion

- [ ] **P9.1** Verify normal unlock/selection and initial/save state.
- [ ] **P9.2** Establish actual quest differences in entrances, caves/secrets, layouts, item placement and progression from reference data. Shared generator arrays alone do not prove equivalence.
- [ ] **P9.3** Populate Q2 rows as needed; exercise each route's distinct requirements, reusing shared combat/item/boss evidence.
- [ ] **P9.4** Complete the connected Q2 route through final dungeon, rescue and ending.
- [ ] **P9.5** Verify Q2 restart and independence from a Q1 save slot.

**Test:** selected Q2 dungeon while repairing it; one connected Q2 completion after integration. New NES captures only for unique discrepancies or missing references.

**Stop:** both quests complete and their differences accounted for.

## Part 10 — Performance and release builder

- [ ] **P10.1** Sample a busy gameplay scene, multipart boss and transition in BizHawk. Use existing frame/DMA/VRAM/sprite instrumentation where meaningful. Optimize demonstrated problems; no speculative assembly rewrite.
- [ ] **P10.2** Finish tools/builder/build.py and required extraction/package handling. Inspect strict_build_check.py, from_scratch_gate.py, package_check.py and release_gate.py for actual execution before accepting summaries.
- [ ] **P10.2a** Implement the actual drag-and-drop application around the builder: file picker/drop target, supported-ROM validation, progress, actionable failure, output selection/location, and successful result. Preserve input bytes and handle filenames with spaces. Resolve dependencies without requiring developer tools to be operated manually.
- [ ] **P10.2b** Ensure every required source-game asset is derived locally from the supplied ROM. Package checks reject included NES/Genesis game ROMs and extracted game assets, including embedded copies. Verify the builder does not silently fall back to developer caches or fetch game data remotely.
- [ ] **P10.3** Build in a clean staging copy from the user's NES ROM. Never clean the active working tree for this check.
- [ ] **P10.4** Verify invalid-ROM failure, successful full build and gameplay entry of the resulting artifact. Reuse accepted gameplay evidence when output identity matches; investigate a changed output.
- [ ] **P10.4a** Exercise the packaged application in a clean environment without the repository/generated cache: drop a supported NES ROM with spaces in its path, observe successful generation, and launch that generated Genesis ROM in BizHawk for a short gameplay check. Confirm input hash unchanged. Exercise unsupported input once. This is package acceptance, not another full quest playthrough.
- [ ] **P10.5** Repeat the identical clean build once for output-hash reproducibility. This is a specific release test, not a routine duplicate.
- [ ] **P10.6** Finish usable instructions, remove required local absolute paths from shipped scripts and meet the project's generated-asset package requirements.
- [ ] **P10.7** Close remaining required-content rows from accumulated evidence. Publishing/tagging is a separate final action after the local package is ready.

**Stop:** the drag-and-drop builder package works from the user's NES ROM and produces the complete accepted game locally. Only the builder package is prepared for distribution. Established Genesis hardware support is carried forward; no new general hardware gate.

## First three implementation assignments

1. Preserve baseline, build once, make one selected dungeon runner path genuinely execute BizHawk with correct current addresses and fresh results. Stop expanding infrastructure.
2. Obtain clean live Aquamentus reference, fix the first actual divergence, and verify fight/death/reward. Only run named dependent cases if shared code changed.
3. Connect ordinary new-game/sword/Level 1 entry through that fight and reward. Fix broken seams, then continue through the packages.

## Compact execution record

Each task needs only: ID; concrete defect/missing behavior; owning files/function; NES reference and existing drained/native implementation; correction; chosen scenario and stop condition; result/artifact; next task. Use TODO, ACTIVE, PASS, FAIL or BLOCKED. Preserve evidence with its artifact identity and invalidate only affected dependencies.

No new design document, full movie, complete memory dump, broad audit, or whole-game sweep is required for each local repair. Once the feature works and its relevant check passes, continue implementing.

### P1 resume detail (2026-09-11)

The old $36/$3C boss diagnosis targeted the Triforce room. Live NES input-only north crossing from staged room $45 reaches boss $35 and creates ObjType $3D with HP $60. The staging itself was synthetic and is not connected-route proof; P1.1/P1.2 remain open at that stronger scope.

The existing SRAM postprocessor wrongly asserts Q1/Q2 dungeon blocks are identical. The current four linked blocks match NES ROM addresses $8D00,$9000,$8D00,$9000; actual bank-6 pointer tables specify $8700,$8A00,$8D00,$9000. The prepared replacement reads those pointers from the user's exact supported ROM and preserves other generated regions. This replacement is now applied and verified at P1.4; the user removed the unavailable reviewer requirement.

After applying: one Debug build, L1 boss capture, and L7 boss capture for the second affected Q1 block. Do not repeat general hardware proof or a full matrix. Continue targeted fight/render differences from the resulting captures.

Separate extraction issue for P5/P10: bank-6 LevelInfo source pointers are 252 bytes apart; extract_rooms.py assumes 256. Investigate before changing its consumers. This candidate deliberately preserves LevelInfo and other data. All captures and candidate game data remain private local build artifacts; release goal remains the drag-and-drop program.

### P1 presentation checkpoint

- NES source: Z_04.asm:Aquamentus_Draw/WriteBossSprite and Z_03.asm:FetchPatternBlockUWBoss. Drained C: enemy_boss_runtime.c:enrt_update_aquamentus; existing native renderer/CHR manager extended. Coverage PARTIAL; stance EXTEND.
- P1.4 is accepted at correct table generation + L1/L7 spawning. Full game acceptance remains open. L7 blank background and L2 invisible Dodongo were observed and belong to P5/P6; correct object RAM/CHR bytes do not pass those visuals.
- OAM sweep failed to publish its SAT upload length (13 slots vs needed 19). Fixed; six boss parts now visible.
- Enemy/boss uploads interleaved their overlapping halves. Serialized uploads, invalidated stale residency on enemy requests, restored enemy bank on same-level exit. L1 boss -> normal room -> boss capture has complete correct boss bank on reentry.
- Aquamentus draw used the weapon-immunity mask for flashing. It now reads the NES hit-flash timer. Immunity mask is unchanged.
- Palette-3 handling is implemented and verified: a generated boss-bank copy uses pixel values 13..15 in existing PAL1[13..15], with transparent zero preserved. Reserved 64 VRAM tiles after the item bank; budget now leaves 452 tiles before VDP tables. Other palettes use the original bank.
- Earlier missing-reviewer references below/in staged artifacts are historical: the user removed the requirement from the skill and authorized continued work.


### P1 reward resume detail (2026-09-12)

Scoped reward check passes on ROM40a508893ff776161e57aff144e2558323de6ea59461c5e1c06e639e12ab0e47. See p1-reward-result.json for exact source hashes, setup limitations and results. Stop rerunning the passed six-hit/reward sequence unless a subsequent change affects it.

Next defect evidence: final reward screenshot still shows Link/projectile rendering artifacts; projectile destruction increments RoomKillCount before the boss dies (final count4 instead of NES1). Native slot19 coordinates are88,152 while the independent room manifest correctly renders192,144. Key consumer room33 awards its manifest key but native RoomItemId was1A at the sampled entry; reconcile native setup/LevelInfo before trusting those cells. Preserve the successful wrapper pickup result without interpreting it as full native item-slot parity.

The debug fixture inherits LinkState40 and seeds sword1/hearts77 before action. It proves weapon hits, boss death and controller reward pickup; it does not prove boss harm to Link or a naturally reached doorway. Save/reload remains open because s_item_taken is room-only. No complete P1 acceptance or whole-project completion is claimed.

### P1 projectile/contact resume detail (2026-09-12)

The previously recorded projectile kill and stale-sprite defects are fixed. Current ROM8720693ba5db645ba8daecfd2ad9257269a69a2f273bbee9ee2b745ac5ac113d. Report p1-projectile-result.json binds the code and evidence. Do not rerun accepted lifecycle/reward checks unless the next change affects them.

Dynamic spawn lifecycle now respects FF/uninitialized before metastate, using existing per-type init/attribute/HP setup and the native live marker1. Empty type0 slots are skipped even when the NES destroy helper leaves uninitializedFF. Frame reset clears both caches plus enemy OAM Y cells. This fixes ghosts and prevents fireballs accepting sword damage or advancing kill counts.

Vulnerable-Link setup explicitly clears ObjState40 before input. Fireball damage matches live NES half-heart/24-timer, and Genesis knockback is observed. The previous Link wrong-art suspicion was not substantiated by tile/pose/SAT/pixel checks; no Link graphics changed. Stalfos room63 consumer renders three active2A slots; this is not a movement or visual-parity pass. Empty room73 only confirms empty-slot handling.

Next: trace the inherited cave halt (cave_dispatch.c:init writes ObjState40) across the normal cave exit/dungeon entry handoff, then do a normal doorway fight/contact/exit. Full P1 still needs death-spark artwork, remaining contact/timing and persistent completion. Native LevelInfo coordinates vs room manifest and room-only s_item_taken remain open as previously recorded. Package goal remains the local ROM-to-Genesis builder; no ROM distribution.

### P1 cave/doorway checkpoint (2026-09-12)

- **NES source:** Z_01.asm:UnhaltLink/TryTakeRoomItem; Z_05.asm:CheckCaveEdge/InitMode_EnterRoom; Z_06.asm:LevelInfoAddrs/FetchLevelInfoDestInfo.
- **Drained C:** cave_dispatch.c:cave_exit; core_dispatch.c:core_unhalt_link; enemy_loop.c:enemy_loop_room_init; main.c:roomrom_main_apply_warp_outcome.
- **Coverage:** PARTIAL (cave handoff and staged doorway fight; connected opening, reward persistence and complete timing open).
- **Stance:** EXTEND.

Cave exit now releases Link through core_unhalt_link and the shared warp handoff. Removed destructive unconditional cave smoke from gameplay boot. Normal south cave boundary now exits via cave fade. Controller-only opening-cave route (debug bootstrap, no postboot position/state writes) passes boot77/state00 -> cave/state40 -> OW77/state00 at64,94. Evidence p1-cave-handoff/route.txt on ROMa6e9afe5...; full emerge timing/new-game sword pickup not claimed.

Scroll entry now refreshes room properties and item metadata through refresh_room_metadata shared with load_room. Latest Debug build passes; ROM5eadb02366599ccbedcd961629a433ff0dd3e1810cc8878e89ca8595a9032a33. p1-doorway-fight/route.txt: staged room45, sword1/heartsBB setup, then controller-only gap traversal -> room35 boss3D HP60 -> six hits -> boss death/kill1. No Link halt, enemy HP, kill or reward writes. Failed straight path was a test-route issue: live NES also blocks the floor blocks (NES Y117 vs GEN112 remains movement-parity follow-up). Boss-room wedge walls also require routing around after knockback.

Reward-after-doorway FAIL is now diagnosed: native AllDead advances, LBA_F35=07, itemstate remainsFF because installed LevelInfo_WorldFlagsAddr isFFFF. Actual ROM LevelInfoUW1 at93FC has06FF. Existing extractor walks256-byte starts while ROM pointers are252 apart. It must still copy256 bytes FROM EACH POINTER (NES FetchLevelInfoDestInfo copies6B7E..6C7D). Update tools/extract_rooms.py LevelInfo/common pointer reads; replace existing linked nine LevelInfo regions; update data/rooms/dungeons_offsets.c FoeCounts offsets from decreasing20..00 to fixed24, matching tools/uw_item_rooms_gen.py. Pointer/common extraction change was researched but NOT YET EDITED when user requested play. Do not bypass flags in gameplay to hide this error. Private evidence p1-doorway-fight/blocked-ram.bin and blocked.State. Older direct-room reward passes retain their narrower scope.

User playtest: builds/reports/recovery/aquamentus-play/Aquamentus.md is a frozen copy of current ROM, owned visible BizHawk PID5492, Ready.State and save slot1 created at controller-entered boss doorway. Seven full hearts, wooden sword, ring/shield0; debug bootstrap otherwise grants inventory. Space toggles pause, arrows move, Z sword, F1 retry. Leave emulator and frozen ROM alone while user plays. Build changes can continue against builds/Debug.md separately. No game data distributed.

### P0.10 implementation checkpoint — 2026-09-12

- **NES source:** reference/aldonunez/Z_06.asm:LevelInfoAddrs, FetchLevelInfoDestInfo, FetchDestAddrForCommonDataBlock.
- **Drained C:** src/game/world/level_info_install.c:level_info_install_uw/ow (existing consumers); tools/extract_rooms.py existing extraction path.
- **Coverage:** PARTIAL (pointer-derived Q1/base LevelInfo, common data and affected fields; Q2 patch application and complete gameplay acceptance remain separate).
- **Stance:** EXTEND.

PASS P0.10 at extraction/installed-data/reward-activation scope. Public extractor follows bank6 pointer entries8014..8026 and common8028, retaining256-byte copies. Nine records byte-match ROM; FoeCounts fixed24 and item generator consumer updated. Native L1 item coordinates now192,144 and flags pointer06FF; L7 pointer077F and boss3D/HP60 verified. Fresh Debug ROM fa6634c78bf7a76335101b33fd9c9989d68f42f0f172ef98daa265dc4147ff66 builds. Evidence [result](../../builds/reports/recovery/p0-levelinfo/result.json).

Controller doorway fight now reveals heart after six hits/kill1. Pickup still FAIL: scripted approach stops short at170,136, then178,149; capacity remains11. Do not mark P1.7 passed. Continue movement/grid ownership diagnosis rather than writing pickup flags or repeating full fights. Post-fight checkpoints retained.

P0.17 safety subset implemented: sweep launcher owns Popen handle, isolated profile, hidden launch, short paths, owned timeout kill; removed tasklist/global taskkill and cp; empty selection/failed launch/stale capture/nonzero diff cannot pass. Mocked timeout/success/zero-room checks passed; broader harness integrity remains TODO. No dungeon sweep run.

P0.14 limitation discovered: full Redux generator cannot run because its source tree is absent. Generator copies Original prefix before Redux-specific layout/CHR changes, so only shared OW LevelInfo/common bytes were refreshed using ROM repair helper; Redux art preserved. Collision and sparse BG generators ran; sparse BG output unchanged. Refreshed freshness hashes bind present inputs/outputs but do not establish missing-source regeneration. Retain this explicit release extraction gap.

The earlier LevelInfo-next-action notes above are historical; this checkpoint and live pointers supersede them. Latest user playtest PID was22520 after restart, not5492; always resolve current ownership rather than assuming either remains live.

### P2/P1.7 collision and room-history checkpoint — 2026-09-13

- **NES source:** Z_07.asm:GetCollidableTile ($40 HUD subtraction, $DD downward cutoff); Z_05.asm:SaveKillCountUW, ModifyObjCountByHistoryUW, InitMode_EnterRoom.
- **Drained C:** walk_model.c:uw_walk_collidable_probe; room_dispatch.c:room_get_room_flags/room_save_kill_count_ow; obj_lists.c:modify_count_by_history_uw. UW save counterpart existed only in translated z_05.asm.
- **Coverage:** PARTIAL (collision sampling + same-session doorway/fight/reward/reentry; full movement, recurring-foe variants and real saves remain open).
- **Stance:** EXTEND.

Fixed walk-model origin38->40 and downward cutoffD5->DD, separating NES gameplay coordinates from display crop. Debug UW warp128->133 matches normal warp grid. Fresh boot now stops at room45 Y117 (matches prior NES sample) and routes through north doorway. Original block mismatch was not missing wall collision; its Y origin was wrong.

Added native SaveKillCountUW counterpart and called it before dungeon scrolling. Incoming RoomId now publishes before enemy history lookup; per-visit RoomKillCount resets on room init. Controller-only sequence after staged setup passes room45 -> room35 -> six-hit boss death -> heart pickup (capacity11->12) -> exit45 -> reentry35 with boss absent and reward still taken. This supersedes earlier pickup/reentry failures at this scope only. [Current evidence](../../builds/reports/recovery/p2-room-progress/result.json). No real save/reload or whole-P1 pass claimed.

### P0.11/P0.12 ownership findings — first subset

| System | Actual owner / competing path | Result / remaining work |
|---|---|---|
| Link movement | main.c player coordinates + private grid/fraction/dir; NES RAM mirror copied for native combat/shove | Collision origin/debug grid fixed; normal scroll arrival/crop and shove synchronization still need baseline coverage. |
| Dungeon enemy history | obj_lists.c reads native flags/LevelKillCounts; native departure previously omitted UW save | Same-session boss history now wired and verified; recurring history variants remain unverified. |
| Room item ownership | item_room_meta.c now uses installed native UW room flags | Cache removed; staged L1 map/compass and L9 compass/key awards pass. Cart persistence and slot/quest initialization remain open. |
| Save serialization | save_serializer.c stores43 bytes: magic +40 inventory +XOR; visible callers are serializer probes | Does not serialize room progress; normal save UI integration requires inspection. Do not call this complete persistence. |
| Walk-model legacy test | RoomRom/tools/test_uw_walk_model.py references removed RoomRom headers/sources and old constants | Historical source-regex test cannot certify current code. P0.17 coverage gap; focused BizHawk evidence used here. |

User's frozen Aquamentus playtest ROM was not replaced. Latest Debug is recorded by SHA in the current result. No full matrix run.

### P0.12 / P4 native reward ownership � 2026-09-13

- **NES source:** Z_01.asm:ItemIdToSlot, TryTakeItem, TakeClass0Complex, GetRoomFlagUWItemState.
- **Drained C:** item_dispatch.c:item_take_item; progress_dispatch.c native room-flag semantics.
- **Coverage:** PARTIAL (award/state integration; presentation, normal progression and cart persistence unverified).
- **Stance:** EXTEND.

Removed the room-only item cache. The bridge reads/writes bit $10 in the installed native UW flags table and rejects repeat awards. All awards use native item dispatch; wrapper constants had confused item IDs $10/$11 (wand/ladder) with inventory slots $10/$11 (compass/map). Corrected generated header and generator to item IDs $16/$17 and Triforce inventory slot $1A. Level 9 pickups are allowed and its map/compass debug reads use the L9 inventory cells.

Focused BizHawk staged room cases passed L1 map, L1 compass, L9 compass and L9 key: expected inventory cell=1, native room flag=$10, published taken=1. Build identity and exact script: builds/reports/recovery/p4-native-rewards/launch.json; result.txt records all four executed cases. These are state/integration checks, not presentation or connected progression. Wand/ladder use the native dispatch now but their full acquisition routes remain TODO.

Save ownership review: active Debug title entry calls debug_unlock_all_items and bypasses the custom file-select path. save_serializer callers are probes; its 43-byte format carries only inventory. sram_adapter.c is a legacy unlinked adapter with old $FF6000 mirror assumptions. The active build links options SRAM IO, not that save adapter. Normal boot/file creation, cart save/load, progress payload, slot/quest isolation and migration remain TODO; do not describe probe round trips as a working save feature.

### P1 / P0.12 / P0.15 � visible boss projectiles, 2026-09-13

- **NES source:** Z_01.asm:Anim_WriteSprite; Z_04.asm:WriteBossSprite/DrawShot; live p1-nes/boss-120-VRAM.bin.
- **Drained C:** enemy_render_native_sweep, draw_write_boss_sprite, enemy_projectile_runtime.c.
- **Coverage:** PARTIAL (Aquamentus mixed boss/projectile presentation; other bosses and complete combat acceptance remain TODO).
- **Stance:** EXTEND.

Confirmed active fireballs in the native cache absent from boss-room OAM submission. Both disjoint producers now feed one bounded SAT chain via shared emit_native_entries; ordinary-room submission uses the same helper. Fireball tiles $44/$45 also hit the overwritten SPR scene overlay. Their extracted common_chr bytes match live NES CHR; upload them to protected tiles1306..1307 instead. No new extracted input or embedded ROM payload was introduced. VRAM budget now checks cloud1300..1305 and fireball1306..1307 against all named banks; contiguous tail headroom is228 tiles (the separate1084..1299 gap remains free).

Removed renderer heartbeat writes to NES $07FE: that address is a native UW room flag. Focused before/after captures, native sprite-cache trace, SAT entries, byte-equal fireball VRAM, a one-second silent motion clip and60-frame unchanged room-flag assertion pass. Builds/reports/recovery/p1-visible-attacks-after/result.json binds ROM/source identity; before evidence is p1-visible-attacks-before. Projectile damage/kill-count evidence is carried forward; no extra full fight matrix. Door/wall, HUD and remaining boss presentation remain open.

### P7 HUD investigation interrupted for user play � 2026-09-14

Native HUD state/heart formatting discrepancy confirmed. Experimental shared heart formatter passed five staged cell-value cases, but static Window presentation remained corrupt after warp. Interrupt masking did not resolve it. This HUD experiment is NOT accepted and is excluded from the user's playable build; the four touched files were restored to their pre-experiment contents. Work-in-progress sources and exact scope are preserved in builds/reports/recovery/p7-native-hud/wip/status.json. Resume source-backed HUD diagnosis; do not claim PASS from result.txt cell checks alone. Native reward and visible-fireball fixes remain in source.


### P7 focused HUD repair and private play handoff - 2026-09-14

Supersedes the interrupted HUD experiment outcome, preserving its failed evidence. Native hearts/counters now read authoritative NES inventory cells; shared heart tile selection follows FormatHeartsInTextBuf. The actual window corruption was asynchronous CHR blank-fill DMA retaining the VDP data port, repaired by waiting for both normal and boss scene fills. Original skips the private heart-animation override.

Focused evidence: `builds/reports/recovery/p7-hud-fixed/` checks five staged health states including half-heart threshold and sixteen-to-three clearing, native counters, and window invariants. `p7-boss-bank-consumer/` checks the affected boss fill consumer with visible fireball SAT entries and intact HUD. Build SHA256 `e816d99bc76d56a09dd472c4481dce670658e2f53d227000f44559ca78efde8c`. PASS at these behavior/presentation scopes only; P7 parent remains unverified for maps, equipment display, lifecycle and connected gameplay. Atlas sentinel refreshed for manually maintained level_chr_swap.c included by its overly broad glob; no game assets re-extracted.

User requested an all-features play ROM with music: frozen private copy under `builds/play/All-Features-20260914/`, existing all-items debug entry and separate emulator config/save paths. Six-second live speaker-loopback capture has nonzero game audio while the Genesis window is focused (peak 11598, RMS 1088.91); background pause explains silence when focus is elsewhere. This verifies playback only, not every song/event. No release distribution or whole-game completion claimed.


### P0.12 / P4 currency ownership repair - 2026-09-19

- **NES source:** Z_01.asm:World_ChangeRupees; Z_05.asm:WieldArrow.
- **Drained C:** hud_dispatch.c:hud_world_change_rupees; arrow.c:roomrom_arrow_fire.
- **Coverage:** PARTIAL (currency state/integration and static HUD count; connected purchases, saves and complete item presentation remain TODO).
- **Stance:** EXTEND.

Reproduction: staged native credit queue stayed at three and count at two after twelve frames while the private inventory remained 255. Shared `hud_tick_native_rupees` now owns the existing drained mutation logic; the legacy transfer-buffer wrapper retains its display gates and formatting. The native renderer calls state-only mutation through inventory_rupee_tick, then synchronizes the legacy currency mirror. Queue APIs target native cells. Arrow eligibility reads native bow/arrow/rupees. Original uses the NES 255 limit; the 16-bit serialization field remains unchanged. Later Redux wider economy requires its P11 specification, not an independent live currency counter.

PASS focused eight GEN cases: credit, debit, cap, floor, simultaneous queues, paid arrow, zero-funds rejection and no-bow rejection. Five live NES currency cases agree. Static screenshot shows the final native count of two. Exact ROM/script hashes in `builds/reports/recovery/p4-currency-after/result.json`; before and NES siblings hold reproduction/reference. This does not establish full projectile motion/collision, audible currency sound or save persistence. P0.12/P4 parents remain ACTIVE/TODO by child scope.

### P0.13 room-entry identity repair - 2026-09-19

- **NES source:** Z_05.asm:InitMode_EnterRoom (room objects initialized for incoming world data).
- **Drained C:** enemy_loop.c:enemy_loop_room_init.
- **Coverage:** PARTIAL (direct-entry level/quest identity; normal continue and same-identity re-entry remain open).
- **Stance:** EXTEND.

Before: L1 -> L2 at identical room45 retained staged RoomKillCount A5. The duplicate-init guard keyed only room and scene. It now also keys level and quest supplied by each of the five existing main.c callers. This preserves the existing repeated-call guard while preventing different levels/quests from sharing initialization. Focused evidence under `p0-room-identity-before` and `p0-room-identity-after`.

Separate FAIL: existing controller Z+Start quest shortcut receives raw/edge input0180 but leaves quest2 and RoomKillCount unchanged in the staged L1Q2 room45 check. Captured in `p0-room-identity-after/controller-failure/`; do not claim controller quest switching or connected Quest2 acceptance. An attempted additional init call on that shortcut was removed because it did not address the failing dispatch. No broad dungeon matrix or changes to the user's frozen play bundle.

Final P0.13 verification: three direct-entry identity cases PASS on ROM SHA256 b5bde9d50d7c63c42ba30dca6990f9dda226a9f5324bfed70827c66a381de69c. `result.json` records exact scope; controller-failure evidence remains FAIL.


### P0.12/P0.13 quest handoff and P4 bomb ownership - 2026-09-19

Quest diagnosis correction: the controller shortcut did change the renderer quest immediately. Earlier twelve-frame probes observed the multi-frame loader before completion, so their claim that dispatch never changed quest was too broad. Actual structural defect: renderer-only reload omitted level table installation, master quest identity and enemy initialization. The shortcut now invokes the existing full warp handoff; that handoff also synchronizes master quest from normalized renderer quest. Source: Z_05.asm InitMode2Load/InitMode_EnterRoom; drained owner roomrom_main_apply_warp_outcome; coverage PARTIAL entry integration; stance EXTEND. `p0-quest-handoff/result.json` PASS: controller Q2->Q1->Q2, master identity, 1536 compared installed bytes and reset room kill state, settled90 frames. This supersedes the shortcut FAIL at this scope only. No Quest2 route or persistence pass claimed.

Bomb spending diagnosis: native count2 remained2 while private16 became15. bomb.c now checks/decrements native InvBombs and mirrors the accepted result. Source Z_01.asm WieldBomb; drained roomrom_bomb_place; coverage PARTIAL eligibility/count; stance EXTEND. `p4-bomb-count-after/result.json` PASS placement2->1, no extra spend while slot occupied, zero-native-count rejection despite stale positive private inventory. Existing one-slot limit/fuse/collision/door behavior remain outside this repair.


### User ordering change - music last, 2026-09-19

Music work is deferred until other game systems are complete, per user instruction. P7 audio remains FAIL/TODO: isolated BizHawk WAV capture in p7-audio-output has silent dungeon and resumed-dungeon segments. Active boot does not call legacy audio_init; this is an unverified diagnosis to resume later. No initialization changes were made. Retain the earlier native-audio RAM addressing fix because it prevents unrelated C-state corruption and restores the pause HUD; it does not establish working music.

P0.12 inventory readback and P7 blank tile: p4-inventory-readback and p7-audio-ram record staged native clear/acquire, 23 compatibility fields, derived item mask, valid all-items sword/recorder/wand and pause-entry refresh. Pause blank tile now uses ROOMROM_BLANK_TILE instead of sprite tile1000 (p7-pause-before / p7-pause-blank). Bottom HUD flag/window header survives after native audio writes stop aliasing C BSS (p7-audio-ram). These are bounded state/static presentation checks; full pause/maps and persistence remain TODO.


### P5/P7 current-dungeon map/compass display - 2026-09-19

- **NES source:** Z_05.asm:HasCompass, HasMap, MovePositionMarkers.
- **Drained C:** room_dispatch.c:room_has_compass, room_has_map; inventory_render.c:slot_owned/draw_item_sprites.
- **Coverage:** PARTIAL (rendered ownership/target visibility; dynamic layout, marker accuracy, connected awards and persistence remain TODO).
- **Stance:** EXTEND.

Before: in L1 with only L2/L9 ownership, pause emitted two compass sprites, one map sprite and a compass target. The private renderer treated any dungeon ownership as sufficient and emitted the target unconditionally. It now calls the existing native per-level checks for the icons and gates the target on HasCompass. Focused BizHawk verification passed four rendered SAT cases: L1 holding other levels, L1 compass-only, L9 holding only L1-8 bits, L9 map-only. Screenshot inspected for compass-only state. Evidence and exact build identity: builds/reports/recovery/p7-map-ownership-after/result.json; reproduction in p7-map-ownership-before.

Next P5/P7 gap: pause still paints captured L1 map tiles; uw_map_builder is excluded from build_debug.py and uses stale blob-relative configuration despite repaired installed LevelInfo. Reconcile current installed data against NES before enabling it. The existing gold map background alone is not a confirmed defect (live NES reference also has it). Music remains deferred by user instruction.


### P5/P7 live dungeon pause map - 2026-09-19

- **NES source:** Z_05.asm:Submenu_WriteSheetMapRowTransferRecord, Submenu_WriteScanningMapRoomMark, CalcOpenDoorwayMask; Z_07.asm:MarkRoomVisited.
- **Drained C:** uw_map_builder.c:uw_map_build; room_dispatch.c:room_mark_room_visited; inventory_render.c.
- **Coverage:** PARTIAL (L1 live map data/render integration and one controller doorway; other layouts, full presentation and persistence remain TODO).
- **Stance:** EXTEND.

Fresh NES capture p5-map-nes disproves the old map-builder extraction blocker for the checked L1 state: all768 installed LevelBlock bytes agree; LevelInfo differs only at mutable last-entry room6BAD. Enabled the existing builder in the active Debug target, switched configuration to installed LevelInfo (current level/quest), and replaced the captured map sheet cells at NT rows21..28/cols12..27 with live glyphs. Marker rotation and target room use that same installed configuration. Shared dungeon entry calls the existing visit recorder after incoming RoomId is installed; this was previously only called through the inactive translated mode path. No duplicate map state authority introduced.

Before fixture: captured map had one cell disagreement against the selected live NES reference. After: p5-map-after/result.json passes128 NES glyph comparisons and128 displayed tile attributes with matching staged visit flags; reopening after clearing visit flags produces128 blank glyphs. p5-map-route/result.json passes controller-only room45->35 after initial setup, both native visit bits retained, both map glyphs present. No player position or progress corrections during that crossing. Route harness first failed Lua parsing (duplicate wrapper), timed out safely, and executed zero cases; its syntax-failure log is preserved and is not acceptance. Corrected harness completed. Screenshot inspected for map reference case. Build cf4809789e836cc07d2d762462540e2953ab79ebfce07a5abb21835d10ebc43c.

P5/P7 parent remains ACTIVE: HUD minimap ownership/layout, broader map/quest display correctness, remaining pause frame artifacts and real save/reload still need work. Music remains deferred until last. No broad dungeon matrix and no replacement of the frozen user play ROM.


### P5/P7 Original HUD dungeon outline - 2026-09-19

- **NES source:** Z_05.asm:InitMode3_Sub6/Sub7; Z_06.asm:LevelNumberTransferBuf; installed LevelInfo_StatusBarMapTransferBuf6BCD.
- **Drained C:** room_init_mode3_sub6/room_has_map; hud_runtime.c:apply_transfer_macro.
- **Coverage:** PARTIAL (Original L1 outline ownership/rendering, level label; markers, other layouts and persistence TODO).
- **Stance:** EXTEND.

Confirmed HUD used the OW gray block even in UW, with an incorrect coarse OW marker. Original UW now clears that block, renders the installed native outline only with the current dungeon map, and prints LEVEL-X from installed LevelInfo. Native map bytes668/66A join dirty tracking so acquisition/loss updates immediately. Suppressed the incorrect OW marker in UW; proper player/compass markers are still TODO, not accepted by this outline repair. NES HUD outline is map-owned, unlike pause-sheet visited-room glyphs.

Sparse atlas lacked Original map glyphsFB..FF. Generator now includes their existing extracted common CHR at subpalette0; regenerated four existing variants and advanced BG bank632->637, sprite start633->638, with dependent bases derived normally. Sprite catalog/layout records and corresponding freshness sentinels regenerated. VRAM budget passes: BG1..637, SPR638..924, ITEM925..1024, boss PAL3 through1088, protected fireballs1306..1307. No new source-game input or asset distribution.

Live NES references p7-minimap-nes (unowned) and p7-minimap-owned-nes (staged native map+transfer request). p7-minimap-after/result.json PASS three40-cell cases: other-level map rejected, current-level map rendered, removal clears. A first exact-word comparison rejected tile0 versus NES blank tile; corrected comparison permits only equal rendered tile pixels for different words. p7-minimap-boss-consumer/result.json PASS named consumer after bank shift: visible Aquamentus, at least two fireball SAT entries, HUD intact. Both resulting screenshots inspected. No full fight or dungeon matrix repeated.

Next: NES-accurate HUD player/compass marker composition, then remaining item/pause display gaps. Music remains deferred until last.


### User-required enemy recovery audit - before music, 2026-09-19

P3.3/P3.4/P3.5 remain ACTIVE/TODO. User reports broad concern that enemy behavior is wrong; treat this as a mandatory audit and repair requirement before any resumed music work, not proof that every enemy is broken. Existing evidence remains valid only for its documented unchanged scope; historical parent completion does not establish enemy correctness. Audit actual linked ownership and debug overrides, then appearance/animation, spawn/count/placement, movement/terrain, attacks/projectiles, hitboxes/damage/defenses, stun/clock/knockback, death/drops, room-clear and revisit cleanup. One representative encounter per shared behavior, additional cases for actual differences; stop at reproducible failures and repair before expanding coverage. Boss distinct behaviors remain under P1/P6. No broad matrix after local repairs. HUD markers remain queued; enemy inspection is the current priority.


### P3.3/P3.4 shared spawn defaults and clock lifetime - 2026-09-20

- **NES source:** Z_05.asm:InitMode_EnterRoom per-slot defaults (ObjQSpeedFrac20, ObjAnimCounter1, ObjMetastate1); Z_07.asm:ResetPlayerState and Walker_Move:CheckStunned.
- **Drained C:** enemy_loop.c:clear_slot_scratch; enemy_walker_bridge.c:c_walker_move; enemy_wanderer_runtime.c:enrt_update_common_wanderer.
- **Coverage:** PARTIAL (natural room-spawn Stalfos motion and staged clock lifetime; family parity and actual pickup/contact-immunity still TODO).
- **Stance:** EXTEND.

Two confirmed shared failures. enemy_loop_tick erased InvClock every frame to compensate for debug_unlock_all_items wrongly granting a transient clock as equipment. Removed the per-frame erase, set debug clock to0, and clear the native clock on new room initialization. Initial verification correctly refused acceptance because all three naturally spawned L1 room63 Stalfos were stationary even with clock0:120-frame trace showed speed0. Common defaults already existed in clear_slot_scratch but normal room loading omitted them (debug-spawn path used them). Normal room clear now invokes that shared initializer before type placement/init, preserving type-specific overrides and resetting stale slot state.

Evidence: p3-clock-before/result.json FAIL clock erased in one tick; p3-clock-after/result.json FAIL stationary Stalfos/speed0; p3-clock-fixed/result.json PASS natural Stalfos motion at speed20hex, all three positions unchanged for60 frames with clock retained, clock cleared on next direct room entry. No enemy/player position corrections during measured movement. p3-spawn-boss-consumer/result.json PASS named shared-init consumer: Aquamentus and visible fireballs. Exact ROM/script hashes in each result. No full boss fight repeated.

P3.3/P3.4/P3.5 remain ACTIVE/TODO. Do not upgrade any whole-enemy completion claim from this repair. Continue family-specific movement/animation/attack inspection; verify special initialization differences and dynamic children. Enemy fixes must precede music, which remains last.


### P3.4 dungeon enemy sprite bank address - 2026-09-20

- **NES source:** Z_03.asm:PatternBlockPpuAddrs ($08E0 OW), PatternBlockPpuAddrsExtra ($09E0 specialized UW); live L1 CHR.
- **Drained C:** enemy_render.c:translate_tile; level_chr_swap.c enemy upload.
- **Coverage:** PARTIAL (L1 bank pixels and Stalfos tile addressing; palette, animation, other families and common UW range remain TODO).
- **Stance:** EXTEND.

Investigation ruled out extraction/conversion/upload for this bank. Stalfos emitted NES tilesA8/AA correctly; VRAM contained the generated atlas correctly. Renderer subtracted8E in UW, selecting bank indices26/28 instead of10/12. Select bank origin9E for native UW, retaining8E in OW and the existing bossC0 branch. Fresh p3-stalfos-nes is a staged Stalfos appearance reference in the live L1 bank, not connected gameplay acceptance. p3-stalfos-before preserves wrong output.

PASS p3-stalfos-after/result.json: four Stalfos tiles match live NES pixels byte-for-byte; six SAT entries use the corrected pair for three naturally spawned Stalfos; all34 resident UWSP tiles match converted live NES CHR and its raw source block is found in the supplied ROM. Screenshot inspected: Stalfos body art restored. No game assets re-extracted or distributed. Remaining distinct risks: shared UW tiles8E..9D are a separate bank and need residency inspection; color/animation and other families remain unverified. Enemy audit remains ACTIVE before music.


### User playtest findings - 2026-09-20, latest private build

Latest private play ROM SHA2568d13ec43448f0e2037513800b8074ff319ea6035a568d839d94c28437454b42b. New user reports must be reproduced and resolved; preserve narrower unchanged accepted evidence.

- P2/P0.13 TODO: room transitions look wrong. Inspect scroll geometry, room handoff, graphics residency and collision timing; no exact cause established yet.
- P3.4/P7 TODO: some sprites remain wrong. Stalfos bank-offset evidence does not establish all sprite artwork, palettes or animation.
- P3.5/P4 TODO: enemy item drops look wrong. Inspect selected item ID, tile/atlas mapping, palette, animation, pickup and cleanup against NES.
- P2 TODO: Link sometimes walks through incorrect blocks. Reproduce the specific tile/collision disagreement; earlier collision-origin fix does not establish every room or transition.

User directs continuing enemies now. Enemy audit and these game defects precede music. Preserve current user emulator session; use isolated owned probes and never reuse historical PID assumptions.


P3.5 natural counter flow follow-up - 2026-09-23: A controller-driven Octorok trace confirms the NES world/help counters work: one natural kill advances both to 1; Link damage resets both to 0; the next kill advances both to 1. NES sources are `Z_01.asm:HandleMonsterDied` and `Link_BeHarmed/@ResetHelp`. Existing C aliases map `$0627` to WorldKillCount and `$0050/$0051` to HelpDropCount/HelpDropValue; no counter fix is needed. The full trace is `builds/reports/recovery/natural-kill-counters-20260923/result.json`. A natural 16-kill route without taking damage remains TODO; staged fairy threshold/flight/pickup remain separate accepted scopes. A later natural Tektite room ($76) trace confirms partial-heart damage also resets WorldKillCount/HelpDropCount: at frame 226 `$670` changed `$DF->$BF` while `$66F` stayed `$87`, and both counters reset `$01->$00`; the next observed increment returned them to `$01`. Its first logger incorrectly called object-slot-zero `$034F` roomkills; the corrected report reads `$0627` directly. Evidence: `builds/reports/recovery/tektite-combat-20260923/result.json`. A no-seed route remains open. A focused controller search in OW $76 tried grounded attacks with airborne retreat: the closer policy reached two WorldKillCount increments before fractional damage at frame 436 reset progress; widening retreat caused damage earlier at frame 121. No route acceptance. Preserve the closer policy as the next starting point; evidence: `builds/reports/recovery/tektite-safe-route-20260923/result.json`.

### P3.5 enemy drop graphics - 2026-09-20

- **NES source:** Z_04.asm:DropItemTable/SetUpDroppedItem; Z_01.asm:ItemIdToSlot/Anim_ItemFrameTiles/Anim_WriteSpecificItemSprites; live NES 8x16 OAM and CHR.
- **Drained C:** NONE for enemy_render.c sprite translation; item_object.c:item_object_update and enemy_walker_bridge.c:update_meta_object are the active native path.
- **Coverage:** PARTIAL (six drop types' staged presentation, plus one staged death-metastate to five-rupee conversion; normal drop-rate coverage, fairy pickup/healing and timeout cleanup, and other atlas rows remain TODO).
- **Stance:** EXTEND.

The item atlas lookup was stale. Heart $F3 incorrectly selected fairy art and must read NES pattern-table-1 $F2/$F3 from CommonMiscPatterns in 8x16 mode; rupee $32, fairy $50, and clock $66 also selected unrelated atlas tiles or defaulted to the sword tile. Fresh live NES probe builds/reports/recovery/drop-art-20260920/nes_drop_probe.lua records all six drop item IDs, OAM tile/attributes and CHR bytes in L1. Its $F3/$66 pixels match the ROM-derived CommonMisc/CommonSprite blocks. Added four item-atlas tiles for the heart/clock, replaced the earlier DemoSpritePatterns fairy aliases with the live CommonSpritePatterns bytes, and routed the observed drop tiles through generated atlas constants. Five rupees share rupee art and use their own NES palette. Regenerated atlas and freshness sentinels; strict item-manifest and VRAM-budget checks pass, with ITEM tiles925..1028 and no table overlap.

PASS in isolated BizHawk drop-art-20260920/gen_drop_probe.lua: six staged drop IDs remain live and emit the expected Genesis SAT tile counts/indices; screenshots inspected against six live NES frames. A seventh scenario starts with a dying enemy metastate, selects the NES help-drop five-rupee item, and renders it after its documented early-life blink. Built ROM builds/Debug.md SHA256 d40603cae78453b50b447b6b5ac746ac0931e7b90a1880c127d610ad4001ad4f; exact probe and emulator hashes in drop-art-20260920/launch.json. An initial integrated attempt was randomly canceled as allowed by the NES drop rate; a subsequent two-frame check landed during the valid early-life blink. Neither was counted as acceptance. This repair does not pass P3.5 overall. Next: audit other item-atlas rows and enemy-family animation, and reproduce normal combat drops/pickup before closure. Music remains last.


P3.5 drop-table follow-up - 2026-09-23: A source-to-drain comparison confirms all seven arrays in `native_set_up_dropped_item` match NES `Z_04.asm`: no-drop types, all three monster row lists, row offsets, four cancellation rates, and all 40 cycle items. A focused Genesis BizHawk fixture then exercised normal meta-death conversion: row0 `$07` selected `$18`; row1 `$0D` selected `$18`; row2 `$09` selected `$00` (bomb); row1 at pre-cycle 3 selected `$0F` and advanced to 4; no-drop `$5D` cleared without advancing cycle. The row3 fallback required a few live RNG samples: three `$80` samples canceled; the fourth `$00` sample selected `$22` and advanced cycle to 1. The row2 bomb `$00` also passed a focused connected pickup: a type `$09` death selected the bomb at Link’s existing position, idle Link collected it at frame 32, bomb count rose `$00` to `$04`, and the slot cleared. Probe and trace are in the same report. Evidence and identities: `builds/reports/recovery/drop-table-audit-20260923/result.json`. P3.5 remains partial. The guaranteed help-drop branch now passes for both `$0F` five rupees and `$00` bomb, with both counters cleared and kill cycle advanced. Existing fairy evidence also verifies the `$10` WorldKillCount override selects `$23`, initializes flight, and resets the counters; it remains staged, not a natural 16-kill route. The row0 drop-rate boundary also passes with the exact post-NMI random value: `$4F` (< `$50`) yields `$18`; `$50` (>= `$50`) cancels. Probe, NMI-seeded fixture, and trace are in the same report. A follow-up connected test seeded only WorldKillCount=$0F, then killed a naturally spawned Octorok with controller sword input: the real death advanced to $10, normal conversion selected fairy $23 at frame 59, and idle Link collected it at frame 152. This proves the natural final-kill handoff from seeded progress, not a full 16-kill route. Evidence: `builds/reports/recovery/natural-fairy-final-kill-20260923/result.json`. The remaining rate edges also pass with exact post-NMI values: row1 `$97/$98` at rate `$98` selected/canceled; row2 and row3 `$67/$68` at rate `$68` selected/canceled. All four rates now have tested `< rate` and `>= rate` boundaries. Evidence is in the same drop-table report. A guaranteed help-drop `$0F` also passed pickup by idle Link at frame 41: rupees changed `$00->$05` and the slot cleared. A separate staged type-`$07` row0 death conversion selected item `$18`; its one-rupee sprite was captured and idle Link collected it at frame 33, changing rupees `$00->$01` after the grace period. The row3 live-RNG fallback selected heart item `$22`; idle Link collected it at frame 32, changing packed heart values `$31->$32`. A row1 cycle fixture selected item `$21`; slot `$15` changed `$00->$01` on idle pickup at frame 32. Together with the bomb `$00`, five-rupee `$0F`, one-rupee `$18`, heart `$22`, and fairy `$23` cases, each unique item ID in the 40-entry enemy drop cycle has focused conversion and pickup/consumer evidence. Traces, probes and captures are in the same report. Still TODO: no-seed natural route through 16 kills without Link damage and broader enemy-family drops. Do not close P3.5 from these focused samples.

### P0.13/P3.3/P3.4 shared flyer movement and dungeon bounds - 2026-09-20

- **NES source:** Z_04.asm:MoveFlyer @End/BoundFlyer/ReverseObjDir8/DeferBounce; Z_05.asm:SetupObjRoomBounds.
- **Drained C:** enemy_flyer_runtime.c:enrt_move_flyer/enrt_bound_flyer/enrt_defer_bounce; room_load_runtime.c:roomld_setup_obj_room_bounds.
- **Coverage:** PARTIAL (staged L1 Keese and Peahat motion, initial edge reversal, bounds/data; later AI path, other flyers, bosses, full combat and persistence remain TODO).
- **Stance:** EXTEND.

Live NES Keese at x70 advanced Flyer_ObjDistTraveled $0437 from 0 to 5 in five frames; same Genesis fixture moved five pixels but left $0437 at zero. The drained MoveFlyer omitted its NES @End: increment distance and call BoundFlyer after a fractional carry. Restored both. At the right edge, NES used dungeon bounds 21,D0,5E,BD and reversed direction on the first moved frame; Genesis still had overworld bounds 11,E0,4E,CD because SetupObjRoomBounds ran only at boot, before a direct dungeon warp changed CurLevel. Moved bounds setup into the shared full load_room path so direct warps and scene toggles install it after level identity. The linked ReverseObjDir8 branch now invokes the existing drained Moldorm deferred-bounce primitive for head slots 5/10, as NES requires when the restored BoundFlyer reaches that type.

Focused BizHawk evidence: builds/reports/recovery/flyer-motion-20260920/nes.txt and gen-before.txt preserve the before counter failure; nes-edge.txt, gen-edge-before-bounds.txt and gen-edge.txt preserve the bounds/edge failure and after result. In the current build, Keese's recorded edge frames 1 and 5 agree on bounds, position, distance counter and reversed direction. A staged Peahat also advances its distance/animation counter. Build builds/Debug.md SHA256 269bfeb7056a46784b851f27270f38fb42aacc2cb9eb9f7918ba98cf121f0e5e; exact ROM, script and emulator hashes are in flyer-motion-20260920/hashes.json. Later 10-20 frame paths still differ from NES, likely in existing speed/AI inputs; no full Keese/Peahat or Moldorm fight pass is claimed. Full room transitions and Link block collision remain separate user-reported TODOs. Enemy work precedes music.

### P3.4 enemy death-spark artwork - 2026-09-21

- **Behavior:** The enemy meta-object death animation must use the NES item-slot $24 spark frames ($62/$64), including their 8x16 pairs and seven-pixel mirrored-side spacing.
- **Owning implementation:** `src/game/enemies/enemy_render.c:enemy_render_publish_meta`; stable FX allocation in `RoomRom/src/roomrom_vram_map.h`; dependency: ROM-derived `common_chr` and sprite sub-palette routing.
- **NES source:** `Z_07.asm:AnimateAndDrawMetaObject/@AnimateSpark` and `Z_01.asm:Anim_ItemFrameOffsets/Anim_ItemFrameTiles/Anim_WriteSpecificItemSprites`. **Drained C:** native meta publisher. **Coverage:** PARTIAL, death-spark presentation only. **Stance:** REPLACE placeholder art with source-backed frames.
- **Result:** PASS at stated scope. The previous renderer reused cloud frame $74 for every death-spark state. It now copies ROM-derived CommonSpritePatterns $62..$65 into stable VRAM tiles 1308..1311, alternates the two NES frames from metastate low bit, routes NES sub-pal 1, preserves mirrored pairing and uses the NES slim-item seven-pixel separation. `verify_vram_budget.py` passes with 224 contiguous tail tiles remaining. `builds/Debug.md` SHA256 `80cfc031d3dd75af54cb0f49bb559131cbf68beced56b3f21d02edf21fb40bb3`. Focused NES/Genesis screenshots, scripts, hashes and result are in `builds/reports/recovery/spark-art-20260920/`. P3.4 and P3.5 remain ACTIVE/TODO: connected combat death/drop/pickup, overlap priority and other enemy art/behavior are not accepted by this local repair. Music remains deferred.

### P0.13/P3.3 overworld table ownership and edge enemy placement - 2026-09-21

- **Behavior:** Boot diagnostics must return the active OW/UW data owners unchanged; OW rooms with LevelBlockAttrsF bit 3 spawn their ordinary enemies from walkable perimeter cells without ordinary interior spawn clouds.
- **Owning implementation:** `src/game/world/probes/dungeon_roundtrip_probe.c` restores installed tables, renderer identity and master quest after its synthetic sweep; `src/game/enemies/obj_lists.c:enemy_edge_spawn_next` owns perimeter selection; `enemy_loop.c:enemy_loop_room_init` caches active AttrsF and suppresses clouds for edge entrants.
- **NES source:** `Z_06.asm:LoadLevelInfo`, `Z_05.asm:AssignObjSpawnPositions/FindNextEdgeSpawnCell`, `Z_07.asm:InitMonsterFromEdge`. **Drained C:** existing `level_info_install_ow/uw`; new native edge walker. **Coverage:** PARTIAL (table integrity and initial placement). **Stance:** EXTEND.
- **Result:** PASS at stated scope. Root cause was the unconditional dungeon round-trip boot probe leaving L9Q2 SRAM tables installed after normal OW boot; this contradicted the correct extracted OW blob and made enemy, secret and room consumers read unrelated data. Current Genesis `$687E..$6C7D` is byte-identical to a live NES OW dump (0/1024 differences). A direct normal entry to OW room `$73` now has installed and cached AttrsF `$08`, four natural type-$03 enemies at perimeter coordinates `$00,$5D`; `$00,$BD`; `$F0,$9C`; `$F0,$8D`, and metastate zero. Build `builds/Debug.md` SHA256 `b928a03f8a6623abeb2ed6415de618ec2bc3403bb265ec08d23cf37e3f04b00e`; exact scripts, dumps, hashes and result are in `builds/reports/recovery/edge-spawn-20260921/`. NES per-enemy 20-50-frame stagger timing remains TODO, so P3.3/P3.4 stay ACTIVE. This shared restoration also reopens any OW evidence captured while the boot probe left dungeon tables installed unless that evidence independently reinstalled OW data.

### P3.3 edge-spawn cadence follow-up - 2026-09-21

Room $73 now releases its four type-$03 enemies one at a time through MonstersFromEdgesLongTimer ($004B) rather than exposing all four at room load. Focused trace builds/reports/recovery/edge-spawn-20260921/gen-stagger.txt records releases at measured frames 1, 25, 45 and 75 (24/20/30-frame intervals, within the NES 20-50-frame rule), with pending slots held at $00,$00, no spawn-cloud metastate, and movement beginning only after release. Current Debug ROM SHA256 bf5242506897644c959412eaf6fa523ec7dd734f50bd7f3f453d608dad839467. This extends the preceding partial pass; other edge rooms and revisit behavior remain TODO.

### P3.3/P3.4 Octorok movement-facing synchronization - 2026-09-21

- **Behavior:** Octorok position, cardinal facing, SAT horizontal flip and six-frame walk-pose alternation must describe the same motion.
- **Owning implementation:** src/game/enemies/enemy_walker_bridge.c:enrt_update_octorock produces direction/frame state; src/game/world/draw_dispatch.c:draw_object_not_mirrored preserves the NES $0F caller-owned flip flag.
- **NES source:** Z_04.asm:UpdateOctorock and Z_01.asm:DrawObjectNotMirrored/Anim_WriteHorizontallyFlippableSpritePair. **Drained C:** native Octorok composition plus native draw dispatch. **Coverage:** PARTIAL (horizontal movement/facing and two walk poses). **Stance:** REPAIR shared draw contract.
- **Result:** PASS at stated scope. The shared not-mirrored draw function cleared $0F, even though NES preserves it and UpdateOctorock sets it for right-facing art. That made right-moving Octoroks retain left-facing pixels. The reset was removed from the shared function. Isolated BizHawk evidence in builds/reports/recovery/octorok-facing-20260921 records a stable right segment moving +4 pixels with SAT hflip 1 and a stable left segment moving -8 pixels with SAT hflip 0; both alternate ObjAnimFrame 0/3. Current Debug ROM SHA256 48507ba271aaaae2d68e54b61145afe60476dff9096dcf39e9bb47c8153eff05. Natural projectile/combat/death/drop/pickup and other enemy families remain TODO; P3.3/P3.4 stay ACTIVE.

### P0.13/P3.3/P3.5 connected Octorok encounter and revisit - 2026-09-21

- **Behavior:** A naturally loaded Octorok encounter must move and attack visibly, accept a controller sword hit, complete death/drop/pickup, and preserve the surviving enemy count across an immediate controller room round trip.
- **Owning implementation:** `enemy_loop_room_init` performs shared object creation then records the NES six-room history; `edge_load_or_clamp` saves the departing OW kill count; `modify_count_by_history_ow` consumes both on re-entry. Combat/drop owners remain `enemy_walker_bridge.c`, `combat_dispatch.c`, and `item_object.c`.
- **NES source:** `Z_07.asm:RunCrossRoomTasksAndBeginUpdateMode/@LoopHistory`, `Z_05.asm:SaveKillCountOW/ModifyObjCountByHistoryOW`, and existing Octorok/drop routines. **Drained C:** `room_runtime.c:roomrt_save_kill_count_ow`; native room history extension. **Coverage:** PARTIAL (one natural red-Octorok room and immediate revisit). **Stance:** EXTEND.
- **Result:** PASS at stated scope. The old room `$76` harness was rejected after its live trace identified type `$0E` Tektites; current extracted room `$67` naturally loads four type `$07` Octoroks and produces visible type `$53` rocks. A controller-only fight activates the wooden sword, deals `$10` damage, renders the death spark, naturally selects drop `$22`, collects it, and changes two authoritative inventory cells. Before repair, killing two enemies and returning respawned all four. The native edge path never called the existing OW kill saver, native room entry never populated `RoomHistory`, and the shared history-index constant incorrectly named `$0529` instead of NES `$0620`. The departure now saves before `$034F` is cleared; shared object creation records the room afterward. Re-entry contains exactly the two surviving Octoroks. Focused evidence and exact hashes are in `builds/reports/recovery/octorok-combat-20260921/result.json`. Regression matrix is GREEN 12/12. Current Debug ROM SHA256 `43e6b55afeb06f65fdd817596767632adb767622d64510be41fe13d7b3397e47`.

P3.3/P3.5 remain ACTIVE: this does not cover other enemy families, full room-clear variants, broader drop presentation, or persistence beyond the immediate history window. The captured transition frame remains evidence for the separate user-reported room-transition presentation defect. Music remains deferred.
### P3.3/P3.4 Tektite jump animation - 2026-09-22

- **NES source:** reference/aldonunez/Z_04.asm:UpdateTektiteOrBoulder and Jumper_AnimateAndCheckCollisions.
- **Drained C:** src/oracle/enemies/enemy_boss_runtime.c:enrt_update_tektite_or_boulder and enrt_jumper_animate_and_check_collisions.
- **Coverage:** PARTIAL (natural Genesis room behavior and visual check; aligned NES frame comparison remains TODO).
- **Stance:** EXTEND.
- **Behavior:** Naturally loaded room $76 Tektites jump, move, land, and select the correct airborne sprite frame.
- **Result:** PASS at stated scope. Four natural type $0D/$0E Tektites each moved, completed repeated state-0/state-1 cycles and landings, alternated animation, and stayed within room bounds. Corrected the probe to read NES-compatible jumper velocity cells $0412/$041F; traces show ascent, apex, and descent. Root cause: NES carries ObjState through the airborne draw branch and draws frame 1, while the C routine forced frame 0 for every Tektite. The routine now starts from ENEMY_STATE_TIMER before its wait/airborne draw branch; normal idle animation still overrides it. Build succeeds; focused BizHawk probe passes; regression matrix GREEN=12 RED=0 SKIP=0. Hashes, trace, screenshots, and run metadata: builds/reports/recovery/tektite-jump-20260921/result.json.
- P3.3/P3.4 remain ACTIVE. NES-aligned presentation, Quest 2 behavior, corner reversals, and other enemy families remain TODO. Music remains deferred.
### P3.3/P3.4 Goriya boomerang animation and rendering - 2026-09-22

- **Behavior:** An enemy boomerang remains visible and animates through flight, spark, slow/fast return, and catch; spark lifetime uses NES ObjAnimCounter.
- **Owning implementation:** src/oracle/enemies/enemy_projectile_runtime.c:enrt_update_arrow_or_boomerang; src/game/world/draw_dispatch.c:draw_boomerang via enemy_projectile_bridge.c.
- **NES source:** reference/aldonunez/Z_07.asm:UpdateArrowOrBoomerang, AnimateBoomerangAndCheckCollision, CalcBoomerangFrame, BoomerangFrameCycle, BoomerangBaseSpriteAttrCycle.
- **Drained C:** PARTIAL: src/oracle/enemies/enemy_projectile_runtime.c:enrt_update_arrow_or_boomerang; boomerang animation/render consumer not yet present.
- **Coverage:** PARTIAL (current source inspection identifies missing state-phase rendering and wrong spark counter cell; focused BizHawk capture pending).
- **Stance:** EXTEND.
- **Historical checkpoint:** ACTIVE at initial source inspection; probe was pending at that time. Superseded at focused scope by the connected BizHawk evidence in the 2026-09-22 result below; full NES/Genesis parity remains partial.

### P3.3/P3.4 Goriya boomerang spark and return rendering — 2026-09-22

- **Behavior:** Enemy boomerang spark countdown, fast-return spin phase, movement and sprite palette/tile submission.
- **Owning implementation:** `src/oracle/enemies/enemy_projectile_runtime.c:enrt_update_arrow_or_boomerang`; `src/game/world/draw_dispatch.c:draw_boomerang`; `src/game/enemies/enemy_projectile_bridge.c:c_draw_boomerang`.
- **NES source:** `reference/aldonunez/Z_07.asm:CheckState20`, `AnimateBoomerangAndCheckCollision`, `CalcBoomerangFrame`, `BoomerangFrameCycle`, `BoomerangBaseSpriteAttrCycle`.
- **Drained C:** `src/oracle/enemies/enemy_projectile_runtime.c:enrt_update_arrow_or_boomerang` and `src/game/world/draw_dispatch.c:draw_boomerang` — EXTEND.
- **Coverage:** PARTIAL (staged state-machine and presentation probe; connected throw/catch parity not covered).
- **Stance:** EXTEND.
- **Result:** BizHawk staged probe and connected Blue Goriya scenario PASS. The live Goriya spawned its own projectile; outbound `$10` reached `$30` through accumulated grid offset, slow return advanced `$40`–`$47`, and catch cleared the projectile and reset the thrower. A later live throw reached collision spark `$20/$28` and fast return `$50`–`$57`. Also verified two-frame animation cadence, visible draw captures, `$03E4` sentinel preservation, NES MoveShot behavior, and no grid-offset reset during animation. Debug build exit 0; regression matrix 12 GREEN / 0 RED / 0 SKIP. Evidence: `builds/reports/recovery/boomerang-return-20260922/result.json`, `trace.txt`, `connected.txt`, and captures.
- **Remaining:** Full NES/Genesis paired oracle for exact direction, distance, timing, wall response and palette; Red Goriya RNG variants; complete second throw/catch. Enemy subsystem remains incomplete; music remains deferred.

### P3.3/P3.4 Goriya boomerang return scratch initialization - 2026-09-23

- **NES source:** `reference/aldonunez/Z_07.asm:3813-3823, 4101-4120` (`UpdateArrowOrBoomerang`).
- **Drained C:** `src/oracle/enemies/enemy_projectile_runtime.c:enrt_update_arrow_or_boomerang`; shared target counter in `src/game/combat/targeting_dispatch.c:targeting_get_directions_and_distances_to_target`.
- **Coverage:** PARTIAL (caller scratch invariant repaired; no deliberate stale-scratch emulator reproduction or paired frame oracle).
- **Stance:** EXTEND.
- **Result:** NES clears zero-page `$00` before dispatch. The target-distance helper increments `$00` for each axis within eight pixels; the boomerang catch branch tests for exactly two. The C caller previously entered the helper with stale scratch possible. It now clears `$00` immediately after the inactive-state return, matching the NES caller precondition. Root `Debug.bat` build completed; focused BizHawk staged/connected Blue Goriya replay passed on ROM SHA256 `d84b98ec0aab8e45779b7b4d228357a7786530662da8d48bebb334f19a4212a0`; regression matrix GREEN 12/12. Evidence: `builds/reports/recovery/boomerang-scratch-fixed-20260923/result.json`. The separate attempted forced-stale fixture had incorrect Lua setup/indexing and is explicitly rejected, not acceptance evidence.
- **Remaining:** Directly reproduce the stale-scratch edge with a valid focused fixture; compare return distance/timing/wall response against NES; verify Red Goriya variation and a second complete throw/catch. This repair does not complete the enemy subsystem. Music remains last.


### P3.3/P3.4 monster-arrow spark timeout - 2026-09-23

- **NES source:** `reference/aldonunez/Z_04.asm:UpdateMonsterArrow` and `reference/aldonunez/Z_07.asm:UpdateArrowOrBoomerang/@Deactivate`.
- **Drained C:** `src/oracle/enemies/enemy_projectile_runtime.c:enrt_update_monster_arrow` and `enrt_update_arrow_or_boomerang`.
- **Coverage:** PARTIAL (staged state/timer/count behavior; sprite visibility and natural shield-hit entry remain unverified).
- **Stance:** EXTEND.
- **Result:** PASS at focused behavior scope. NES state `$20` routes through the base arrow updater, decrements ObjAnimCounter for three updates, then resets state and destroys the counted arrow. Genesis previously sent every non-`$10` arrow state through `enrt_bounce_shot`, skipping this spark lifecycle. State `$20` now uses the NES-derived updater; other arrow states retain their existing path. BizHawk assertion passed: `$20->$28`, counter `3->2->1`, then type/state cleared and `ENEMY_SHOT_COUNT` `$01->$00` on update 3. Root `Debug.bat` build completed; regression matrix GREEN 12/12. A named post-change Blue Goriya boomerang staged/connected consumer replay also passes on the same ROM. Screenshot captured but did not establish arrow spark visibility. Evidence: `builds/reports/recovery/monster-arrow-spark-20260923/result.json` and `builds/reports/recovery/boomerang-verify-latest-20260923/result.json`.
- **Remaining:** Verify natural shield-hit entry and visible spark against NES, plus full arrow-flight parity. P3 remains incomplete; music remains last.

### P3.4a enemy audit scope reconciled - 2026-09-23

- **Behavior:** The parity inventory must include all user-required enemy families and distinguish family-scoped evidence from full acceptance.
- **Owning records:** `docs/audit/enemy_parity/INDEX.md`, `findings.md`, and `spawn_graph.md`.
- **NES source:** Existing family references remain in each parity record. **Drained C:** Existing runtime functions listed in the new Octorok/Tektite records. **Coverage:** PARTIAL per family. **Stance:** EXTEND.
- **Result:** PASS for documentation inventory. Octoroks `$07-$0A` and Tektites `$0D-$0E` are no longer labeled out of scope. Added focused records linking Octorok natural combat/drop/pickup/revisit and Tektite jump/presentation evidence. Historical audit exclusions remain described as historical. P3.3/P3.4/P3.5 remain incomplete.
- **Next:** Continue P3 movement/presentation work with the Tektite corner-reversal and boundary cases, then cover remaining drop variants and enemy families. Keep music deferred.


### P3.5 fairy enemy-drop flight and first-tick parity - 2026-09-23

- **Behavior:** A fairy selected by the enemy drop table initializes and flies using the NES fairy state machine while retaining the ordinary dropped-item pickup/lifetime path.
- **Owning implementation:** `src/game/enemies/enemy_walker_bridge.c:native_set_up_dropped_item`; `src/game/enemies/enemy_flyer_bridge.c:c_control_fairy_flight`; `src/game/items/item_object.c:item_object_update`.
- **NES source:** `Z_04.asm:SetUpFairyObject`, `UpdateFairyObject`, `ControlFairyFlight`, `MoveFlyer`; `Z_07.asm:UpdateItem`. **Drained C:** `enemy_flyer_runtime.c:enrt_set_up_fairy_object/enrt_flyer_speed_up/enrt_flyer_fairy_decide_state/enrt_move_flyer`. **Coverage:** PARTIAL, staged threshold setup and 60-frame flight only. **Stance:** EXTEND.
- **Root cause:** The native drop selector assigned item `$23` but skipped `SetUpFairyObject`; item update used only the generic stationary item path.
- **Result:** PASS at focused scope. Before: after the `$23` conversion, position stayed `$60,$90` for 60 frames and direction/speed/state remained zero. After: setup set initial direction `$08`, speed `$7F`, and shared controller reached wander state `$03`; after 60 frames the fairy moved to `$56,$75`, remained a live `$60/$23` item, and the probe assertions passed. Debug ROM SHA256 `2cd82c001665aaed500fb72b846b5b06aa7f387845246378a367575ea716aaba`; regression matrix GREEN 12/12. Probe, captures, baseline and exact results: `builds/reports/recovery/fairy-drop-20260923/`.
- **Result:** A second BizHawk fixture let the idle player intersect the moving fairy after its grace period. The drop was collected and its slot cleared at frame 38; health moved from `$01` to `$04`, matching item descriptor `$12` and NES `TakeHeartsNoSound`'s three increments. Evidence: `pickup.txt`, `pickup.png`, and `fairy-pickup.lua` in the recovery report. An initial direct-position fixture was rejected because native player update overwrote that write.
- **Timeout follow-up:** A staged `$01` lifetime cleared the fairy slot after three ordinary frames (`timeout.txt`, `timeout.png`). Follow-up used normal death-to-drop conversion, left lifetime at `$FF`, prevented pickup, and observed the complete grace/countdown path: the fairy slot cleared at frame 595 with lifetime `$00` (`timeout-full.txt`, `timeout-full.png`). Debug ROM SHA256 `0f93902193abd560fe0fb684dc58ebc874c1ffc451cc16c5dbb75ac7e8ed1c40` in the same recovery report.
- **Drop-init repair:** NES marks a converted $60 drop uninitialized, consuming one InitObject-only tick before UpdateItem. Genesis now uses the occupied-slot $FF sentinel for that pass. In BizHawk, conversion produced $60/$23 with flag $FF and speed $7F; tick 1 only cleared the sentinel and tick 2 advanced speed to $80. Buffered NES/Genesis traces matched deterministic setup and the first 35 flight frames. The later random wander directions diverged after RNG streams diverged, so full wander parity remains open. Current Debug ROM SHA256 0f93902193abd560fe0fb684dc58ebc874c1ffc451cc16c5dbb75ac7e8ed1c40; trace and exact probe hashes are in `builds/reports/recovery/fairy-drop-20260923/`.
- **Remaining:** Natural play to the 16-kill fairy trigger and RNG-aligned random-wander art/cadence remain unverified. This does not pass P3.5 or the enemy parent. Music remains deferred.


### P3.3/P3.4 monster-arrow live wall response and spark art - 2026-09-23

- **Behavior:** `$5B` monster arrow active flight, blocked transition, spark lifetime, sprite frame and counted cleanup.
- **Owning implementation:** `src/oracle/enemies/enemy_projectile_runtime.c:enrt_update_monster_arrow/enrt_update_arrow_or_boomerang`; `src/game/world/draw_dispatch.c:draw_arrow`.
- **NES reference:** `reference/aldonunez/Z_04.asm:UpdateMonsterArrow/CheckShotLinkCollision`; `reference/aldonunez/Z_07.asm:UpdateArrowOrBoomerang/HandleArrowOrBoomerangBlocked/DrawArrowOrBoomerangAndCheckCollisions`.
- **Coverage:** PARTIAL. **Stance:** EXTEND.
- **Result:** Focused live BizHawk pass. An active `$10` arrow blocked at the room edge entered `$20` with counter 3; subsequent updates reached `$28` with counters 2 and 1; final update cleared type/state and decremented shot count `$01->$00`. Source comparison found the Genesis renderer retained the directional frame during spark; it now selects NES frame `$02` plus the spark palette. A centered staged timer/count fixture and named Blue Goriya throw/return/catch consumer replay passed on the same build. `Debug.bat` succeeded; regression matrix GREEN 12, RED 0, SKIP 0. Build SHA256 `3e6e9c4313e2aa1aee91d687c609a63b13f5c9d4b853d49755aa9572946d54e4`.
- **Evidence:** `builds/reports/recovery/monster-arrow-wall-live-20260923/result.json`; focused trace and screenshot in that directory; `builds/reports/recovery/monster-arrow-spark-frame-20260923/trace.txt`; boomerang consumer replay in `builds/reports/recovery/boomerang-verify-latest-20260923/result.json`; `builds/reports/regression_matrix.md`.
- **Additional behavior check:** A staged live arrow/Link overlap with shield flag and facing set for a frontal hit entered state `$30`; shot count remained active. Evidence: `builds/reports/recovery/monster-arrow-shield-hit-20260923/trace.txt`. This verifies the collision callback path, not natural monster aim/fire or the full harmful-hit route.
- **Presentation check:** Matched Genesis BizHawk captures at the same room/state/frame with and without a centered `$5B` spark differ in exactly 28 pixels within an 8×8 box. The spark is visibly submitted on frame 2; the earlier frame-1 screenshot preceded the rendered update. Evidence: `builds/reports/recovery/monster-arrow-spark-frame-20260923/result.json`. This passes static Genesis visibility only.
- **Natural shooter check:** Normal room `$4D` loaded four type `$03` Moblins. Without enemy/projectile staging, the first type `$5B` arrow appeared at frame 37, moved across consecutive frames, and its tracked slot cleared at frame 128 while another shot remained counted. The midflight screenshot shows its sprite. Evidence: `builds/reports/recovery/moblin-natural-arrow-20260923/result.json`. The older Moblin audit rows marked FULL from narrow timer evidence are now PARTIAL.
- **Harmful-hit check:** A staged `$5B` arrow approaching from behind ran through the live collision callback. At contact, collision/harm flags became `$01`, Link's partial health fell `$FF->$DF`, and the arrow plus counted shot cleared. Evidence: `builds/reports/recovery/monster-arrow-harm-hit-20260923/result.json`. This is a focused outcome check; natural Moblin aim and hit frequency remain open.
- **Paired presentation check:** NES OAM for the `$5B` spark uses tile `$3C`, palette `$01`; Genesis `draw_arrow` now selects frame `$02`, palette `$01`, and clears horizontal flip as NES `@PrepareArrow` does. With matched arrow/no-arrow captures, right and left facing each produced the same 28-pixel, 8×8 silhouette in NES and Genesis after aligning the display crop. RGB white differs by hardware palette; absolute screenshot Y differs by seven display lines. Evidence: `builds/reports/recovery/monster-arrow-paired-20260923/result.json`. Build SHA256 `17936050b9dcb3b8aaecf0e90e13bb07a635cb4c865c76a6b3e9b49d8d02c55e`; `Debug.bat` succeeded and regression matrix GREEN 12, RED 0, SKIP 0.
- **Red Moblin follow-up:** Normal room `$4B` loaded six type `$04` Moblins without enemy/projectile staging. The first `$5B` arrow appeared at frame 364, moved on consecutive updates, cleared at frame 427, and a second shot appeared at frame 434. The earlier 240-frame no-shot probe was too short to judge the red variant's firing. Evidence: `builds/reports/recovery/red-moblin-natural-arrow-20260923/result.json`. The red Moblin row stays PARTIAL pending NES-aligned probability, movement and combat comparison.
- **Remaining:** Verify shooter aim/cadence, vertical-facing spark and paired flight/edge/timing behavior; broader shooters and enemy acceptance remain open. P3 is incomplete; music remains last.

### P3.5/P4 dropped-item weapon pickup - 2026-09-23

- **Behavior:** A dropped item can be taken by an active arrow, sword, boomerang, or Link, in NES priority order; inactive weapons cannot take it.
- **Owning implementation/dependencies:** `src/game/items/item_object.c:item_object_update` reads shared object slots; `src/game/items/arrow.c` and `boomerang.c` publish their live positions/states; the existing `nes_ram_sync_sword` publishes the sword. This depends on the existing dropped-item lifetime and `item_take_item` consumer.
- **NES reference:** `reference/aldonunez/Z_04.asm:UpdateItem/ItemTakerObjSlots`; `Z_01.asm:TryTakeItem/Abs`. **Drained C:** the shared object-slot and item dispatcher paths. **Coverage:** PARTIAL (focused controller-fired weapon pickups, inactive rejection and grace-period rejection). **Stance:** EXTEND.
- **Reproduction:** The old `item_object_update` called only its Link pickup helper; native arrow/boomerang did not publish NES weapon object slots. A first hand-seeded arrow fixture failed because the native weapon update correctly cleared the fake active state before item collision. The test was replaced with real B/A controller weapons and separately staged `$60` drops outside Link's 9-pixel reach.
- **Result:** PASS at stated scope. In isolated Genesis BizHawk, boomerang slot `$0F` took a one-rupee drop, arrow slot `$12` took a five-rupee drop (after its one-rupee firing cost), and sword slot `$0D` took a one-rupee drop. All three destroyed the corresponding item object. With sword idle, a second drop at the same sword-reach location remained after eight frames. Diff review caught an idle-slot overwrite risk for cave people in slot `$0F`; idle weapon updates no longer clear their shared object slots. Rebuilt and reran the focused probe. `Debug.bat` succeeded; `builds/Debug.md` SHA256 `d641fe83c5e87febae3e2bc3d617aab8edf668c77cb0cea87ed1e0f669b8cda2`; regression matrix GREEN 12, RED 0, SKIP 0. Evidence: `builds/reports/recovery/weapon-drop-pickup-20260923/probe.lua`, `trace.txt`, `emuhawk.log`.
- **Grace-period follow-up:** With a live state-`$02` sword overlapping the staged drop, lifetime `$F0` left type `$60` and rupees `$20` unchanged; the drop cannot be taken until the NES lifetime threshold passes. Same focused probe and ROM identity.
- **Remaining:** Check halted Link and negative weapon-state rejection against NES; verify further natural combat-drop weapon cases and scene transitions. P3.5/P4 and the whole-game goal remain open. Music remains last.

### P3.5/P4 connected enemy-drop weapon pickup - 2026-09-23

- **Behavior:** A controller weapon can collect an item selected by the normal enemy death/drop path, with Link outside the item collision box.
- **Owning implementation/dependencies:** Octorok death/drop in `src/game/enemies/enemy_walker_bridge.c`, item update in `src/game/items/item_object.c`, native boomerang object publication in `src/game/items/boomerang.c`, and the item consumer in `src/game/items/item_dispatch.c`.
- **NES reference:** `Z_04.asm:UpdateItem/ItemTakerObjSlots/SetUpDroppedItem`, `Z_01.asm:TryTakeItem`. **Drained C:** existing enemy and item paths. **Coverage:** PARTIAL (one room, one naturally selected item ID, one weapon). **Stance:** EXTEND.
- **Scenario/result:** PASS. Isolated BizHawk direct entry to overworld `$67` seeded only wooden sword and survivable health. Controller combat killed a natural Octorok; death spark appeared at frame 39, the unforced drop table selected item `$22` in slot 2 at frame 113, and a B-fired boomerang took it after lifetime reached `$EF`. On the pickup frame, Link was `(72,117)`, item `(64,130)` (outside Link's 9-pixel box), and active boomerang slot `$0F` was `(72,120)` (inside its box); the item slot cleared. No position, enemy, drop, RNG, weapon-state or inventory edits occurred during the tested route. Exact ROM/probe/emulator identities and captures: `builds/reports/recovery/connected-weapon-drop-20260923/result.json`.
- **Remaining:** Other naturally selected drop IDs, sword/arrow natural-drop pickup, scene transitions and broader enemy/drop coverage remain TODO. This does not pass P3.5/P4 or the whole-game goal. Music remains last.

### P5.4/P7.1 map-marker diagnosis - 2026-09-23

- **Behavior:** The Original gameplay HUD must locate Link at the actual room and show the dungeon compass target when owned; map-sheet markers and HUD markers must follow the selected level/quest without stale state.
- **Owning implementation/dependencies:** `src/game/hud/hud_runtime.c:roomrom_hud_refresh_marker`, `src/game/inventory/inventory_render.c:draw_item_sprites`, `src/game/world/render/sprite_slots.h`, and `src/game/enemies/enemy_render.c` SAT budget.
- **NES reference:** `reference/aldonunez/Z_01.asm:UpdatePlayerPositionMarker/UpdatePositionMarker` uses sprite tile `$3E`, a 4-pixel OW/8-pixel UW horizontal step, 4-pixel vertical step, current room, level map X offset and compass-target flashing. **Drained C:** the inventory renderer owns the pause-sheet marker pair; gameplay HUD now owns two persistent SAT entries and a bounded copy of the required compass art. **Coverage:** PARTIAL, focused presentation plus a named boss consumer. **Stance:** EXTEND.
- **Repair:** Gameplay Original OW formerly reduced room coordinates by two in both axes to one 8×8 BG tile, so adjacent rooms in a 2×2 group looked identical; UW returned before drawing player/compass markers. The HUD now composes both pixel-positioned markers from the installed room and LevelInfo target/offset. SAT slots 12/13 precede enemies starting at 14; the H32 scene budget and reserved tile 1280..1295 pass the VRAM verifier. The unused coarse BG marker is no longer drawn.
- **Scenario/build/result:** PASS for this scope. `builds/reports/recovery/original-hud-markers-20260923/result.json` records exact build, Lua and emulator identities. In isolated BizHawk, Original overworld rooms `$76->$77` moved the player marker exactly four pixels, both with tile 700/palette 1; direct L1 room `$45` showed the player and an owned compass target at the NES-derived coordinates, alternating tile 700/palette 3 and biased tile 1294/palette 0 across the 32-frame cycle. Unowned L1 compass hid; after the Triforce bit was set, the target stayed dim at the would-be bright phase. Level 9's owned target also flashed; NES `Z_01.asm` explicitly bypasses the L1-L8 piece mask for level 9, and the implementation was corrected after that review. Named Aquamentus room `$35` still produced three fireball SAT entries, the HUD player marker, and a coherent slot 12->13 chain. Screenshots `ow76.png`, `ow77.png`, `uw-compass.png`, `l9-compass.png`, `boss.png` were inspected. The direct-room fixtures verify display/ownership boundaries, not connected acquisition or navigation.
- **Remaining:** Connected overworld navigation, map/compass acquisition and removal, pause-sheet sync, quest/slot reload, and additional boss/scene pressure remain TODO. P5.4/P7.1 and their parents stay open; music remains last.

### P5.4/P7.1 native room award to display - 2026-09-23

- **Behavior/owner/dependencies:** Native L1 room map/compass awards in `src/game/dungeon/item_room_meta.c` and `src/game/items/item_object.c` must reach level-owned inventory, the gameplay HUD in `src/game/hud/hud_runtime.c`, and pause icons in `src/game/inventory/inventory_render.c`.
- **NES reference:** `Z_01.asm:UpdatePositionMarker`, `Z_05.asm:UpdateMenuCommon1`, and native item-room flags. **Drained C:** room award, inventory ownership, HUD and pause renderers. **Coverage:** PARTIAL integration/presentation; **stance:** EXTEND.
- **Scenario/build/result:** PASS at direct-room scope. After clearing only each relevant inventory bit, isolated BizHawk entry into L1 `$46` awarded map `$0668=1` and published taken=1. Entry into L1 `$62` awarded compass `$0667=1`, published taken=1, and changed the gameplay target from hidden SAT Y=96 to visible Y=156. Pausing showed one map icon, two compass icon tiles and one target marker, all from the awarded state. Exact ROM/Lua/emulator identities, trace and screenshots: `builds/reports/recovery/connected-map-compass-20260923/result.json`.
- **Remaining:** This staged entry auto-awards the room item at the spawn position; it is not controller traversal, save/reload or full progression evidence. A right-only attempt from L1 `$45` was blocked by the center obstacle; a short route around it reached `(208,93)` but did not enter `$46`. Preserve `route-attempt.txt` and frames as an unresolved route inspection, not a confirmed door defect. P5.4/P7.1 remain open.

### P7.1 pause status-marker LevelInfo offset - 2026-09-23

- **Behavior/owner/dependencies:** `src/game/inventory/inventory_render.c:draw_item_sprites` must place both paused status-bar markers using the installed `LevelInfo_StatusBarMapXOffset`; `src/game/hud/hud_runtime.c` already does so during gameplay.
- **NES reference:** `Z_05.asm:UpdateMenuCommon1` calls `Z_01.asm:UpdatePlayerPositionMarker`, which adds `$6BAC` to the player and target status-marker X positions before scrolling them with the menu. **Drained C:** pause sprite renderer. **Coverage:** focused L2 presentation; **stance:** EXTEND.
- **Reproduction/repair/result:** L2 `$7D` installs offset `-80`. Before repair the paused player marker was SAT X=250; NES-derived X=170 (`before.txt`). The renderer now applies the signed installed offset to OW/UW player status markers and the UW compass target, leaving the separate dungeon-map-sheet marker unchanged. After repair, isolated BizHawk measured player and owned compass target both at X=170; screenshot inspected. Exact current build/probe/emulator identities and trace: `builds/reports/recovery/pause-status-offset-20260923/result.json`. Debug build and the named L1 award-to-pause consumer pass.
- **Remaining:** Other pause-map layouts, actual scrolling motion, normal-route ownership and persistence remain TODO. P7.1 stays open; music remains last.

### P7.1a user-reported pause-menu appearance defects - 2026-09-23

- **Behavior/owner/dependencies:** Original pause-menu layout, graphics, palettes, map sheet, status strip, icons and scrolling must match the corresponding NES state. Owning paths to inspect include `src/game/inventory/inventory_render.c`, its CHR/palette inputs, `src/state/pause_state.*`, and the menu handoff in `RoomRom/src/main.c`.
- **NES reference/drain/coverage/stance:** Use `reference/aldonunez/Z_05.asm` and live NES pause captures for the exact room, level, quest and inventory state. Current Genesis captures are `builds/reports/recovery/connected-map-compass-20260923/pause-owned.png` and `builds/reports/recovery/pause-status-offset-20260923/pause.png`. Drained renderer is active. **Coverage:** static screenshots and narrow SAT ownership/coordinate probes only; full visual parity unverified. **Stance:** EXTEND after source-backed comparison.
- **Result:** **FAIL (user-reported appearance)**. The user sees definite mistakes in the pause menu shown after the latest repair. Specific wrong elements have not yet been isolated, so do not label any individual tile, icon, color or scroll position as confirmed. The prior L2 marker X=170 and L1 owned icon-count results remain accepted at their stated scope only.
- **Next/acceptance:** Reproduce the same pause state in NES and Genesis, annotate concrete visual differences, fix their owning paths, then capture one matching OW and UW screen and a short scroll/resume check only if motion is affected. Preserve this backlog item until the user-visible discrepancies are resolved. Music remains deferred.

### P7.1a matched pause-layout and icon repair - 2026-09-23

- **Behavior/owner/dependencies:** The Original pause sheet, its sprite icons, and the bottom HUD must align with the NES visible frame. `src/game/inventory/inventory_render.c` owns the tile-row origin, active VScroll, SAT Y conversion and item-slot tile lookup; `src/game/hud/hud_runtime.c` owns the pause bottom-window placement. The extracted item atlas and VDP mode are dependencies.
- **NES reference/drain/coverage/stance:** Live NES BizHawk savestate in L1 room `$45`, with the same all-items native inventory fields as the Genesis debug build; NES `VRAM` is this BizHawk core's 8 KiB CHR-RAM domain and OAM/PALRAM were dumped separately. Matched Genesis L1 `$45` direct entry and pause. Sources: `Z_05.asm` submenu positioning and `Z_01.asm:Anim_ItemFrameTiles`. **Coverage:** one matched UW pause frame, raw tile data and pause exit; **stance:** EXTEND. This is a presentation fixture, not an item-acquisition route.
- **Reproduction:** The older NES pause capture had mostly empty inventory, so it could not prove the user's all-items screenshot wrong. Fresh matched frames established a real geometry mismatch: Genesis pause BG was nine pixels below NES, while the bottom HUD's first heart row was seven pixels above. Several inventory icons also drew the wrong shape. `builds/reports/recovery/p7-pause-allitems-gen-20260923/before.png` and `builds/reports/recovery/p7-pause-allitems-nes-20260923/pause.png` preserve the comparison.
- **Repair/result:** The pause tile-row origin advances one NES row, the settled VSRAM pixel phase is `+1`, and pause SAT Y subtracts the NES top-eight-line crop. The bottom window moves down one tile row without changing gameplay HUD placement. Matched-image analysis now measures pause BG shift `9 -> 0` and the first heart red row NES/Genesis `191/192` (before Genesis `184`). Live NES CHR pairs and current Genesis VRAM show the atlas bytes were correct but nine pause-icon lookup entries were stale by two tiles: bow, food, potion, wand, book, ring, magic key, bracelet and letter. The corrected lookup yields exact 128-pixel indexed matches for all 18 examined item/compass/map pairs; `before-icons.txt` and `after-icons.txt` retain per-item differences. An isolated pause/resume returns to L1 `$45` with the top HUD restored. Exact ROM/probe/emulator identities and images: `builds/reports/recovery/p7-pause-allitems-gen-20260923/result.json`; local archived build `builds/play/P7.1a-pause-layout-icons.md` (SHA256 `07235575eb12bf6d10e2b1cad3c3024ac87529357c80635045504b9b48cfe375`). Named L1 map/compass award-to-pause and L2 marker-offset consumers pass on this build.
- **Remaining/status:** P7.1a remains **FAIL** for full pause-menu acceptance. The NES dungeon status-map transfer must run after staging `InvMap`; once requested, its blue minimap appears in both matched frames. The extracted pause PALRAM equals the live NES PALRAM byte for byte. The palette-conversion section below resolves the RGB lookup mismatch; the OW map-field investigation below rules out a code defect. Any remaining discrepancies and motion-specific behavior still need their own evidence. Do not reclassify item/layout corrections as whole-menu parity. Music remains last.

### P7.1a overworld pause map reference correction - 2026-09-23

- **Behavior/owner/dependencies:** Original overworld gameplay and pause HUD map field must follow the NES status-bar state. `src/game/hud/hud_runtime.c` owns the static map field; a NES transfer-record request can overwrite that field in a staged probe.
- **NES reference/drain/coverage/stance:** Live NES `z1_ow.State`, room `$77`, staged with the same native all-items fields as the Genesis debug build; compare gameplay-before-pause and settled pause **without** a dungeon-map transfer request. Genesis direct room `$77` with the same inventory, then resume. **Coverage:** one matched OW static pause and resume; **stance:** KEEP. Staged inventory is presentation evidence only.
- **Reproduction/result:** The first OW NES probe accidentally requested dungeon status-map transfer `$44`, which blanked the gray overworld map during pause. Without that inappropriate request, the NES retains the gray rectangle and green room locator, matching the existing Genesis OW HUD behavior. The attempted Genesis map-blanking change was reverted. `builds/reports/recovery/p7-pause-ow-gen-20260923/result.json` identifies the corrected capture. Allowing room `$77` entry to settle for 240 frames before Start yields a complete menu after 100 pause frames; the earlier incomplete sheet came from starting during room entry, not a demonstrated pause-scroll defect.
- **Remaining/status:** **PASS for ruling out this reported map-field mismatch; no HUD source fix.** Full P7.1a remains **FAIL** pending any further user-visible discrepancies. The later palette-conversion section resolves the known RGB lookup mismatch. Music remains deferred.

### P7.1a NES-reference palette conversion - 2026-09-23

- **Behavior/owner/dependencies:** All game-derived NES palette indices must map to the closest Genesis CRAM colors for the locked visual reference. `tools/extract_misc.py` owns the conversion, `data/misc/palettes.c` is generated output, and `src/game/world/bg_palette.c` consumes the lookup. This is shared by pause, OW, UW and sprites; the frozen reference RGB table is non-game metadata, so the builder still needs only the user's ROM.
- **NES reference/drain/coverage/stance:** The active BizHawk 2.11 config selects NesHawk and contains 64 RGB entries matching live NES pause screenshots. Previous extraction used an unrelated hardcoded palette and gamma lift. Genesis Genplus-gx displays each channel as `0,34,...,238`; conversion now chooses the closest channel level. **Coverage:** 64-entry LUT analysis, matched OW/UW pause, resumed OW/UW rooms and an Aquamentus-room consumer; **stance:** EXTEND. This does not assert all art and scene palettes are correct.
- **Reproduction/result:** The previous LUT mapped NES red `$16` RGB `181,50,32` to Genesis `238,68,0`; now it maps to `170,34,34`. Across all 64 entries, mean absolute RGB channel error against the active NES reference fell from `20.51` to `6.85` (Genesis gamut limits prevent exact RGB). OW and L1 pause colors are visibly closer, their indexed tile/layout evidence remains valid, and the OW/L1 resumed scenes and Aquamentus room rendered without a palette handoff failure. `builds/reports/recovery/p7-palette-consumers-20260923/color-analysis.json` and matched captures retain the evidence. The generated palette freshness sentinel was updated; `Debug.bat`, generated-freshness check and regression matrix pass (12 green, 0 red). Final build SHA256 `895db3e8346800db475873b04956d2f1276de0232ecd2566cd5768287f511f19`. This is **PASS for the lookup correction** only.
- **Remaining/status:** P7.1a stays **FAIL** as a parent pending any remaining user-visible pause discrepancies and a motion check if a real pause-scroll defect is reproduced. Other sprite palette routing and presentation tasks keep their separate statuses. Music remains deferred.

### P7.1a matched pixel residual - 2026-09-23

- **Behavior/owner/dependencies:** NES and Genesis pause frames should align after mapping NES RGB to the nearest Genesis channel level. `src/game/inventory/inventory_render.c` owns the pause sheet; `src/game/hud/hud_runtime.c` owns the bottom WINDOW plane. VDP WINDOW vertical placement is tile-row based.
- **NES reference/drain/coverage/stance:** The corrected room `$77` OW and L1 `$45` UW all-items captures above, each matched to the same native inventory. `builds/reports/recovery/p7-palette-consumers-20260923/analyze_pause_pixels.py` compares the original 256x240 NES frame's top 224 rows to the 256x224 Genesis frame. **Coverage:** settled static frames only; **stance:** KEEP the now-matched sheet and track HUD offset separately.
- **Result:** After Genesis RGB quantization, the upper 172-row sheet differs in just 20 of 44,032 pixels for OW and 42 for UW (animated/phase pixels included). In the common 160x38 bottom HUD region, 684 pixels differ at the same Y in each case, and **zero** differ when Genesis is sampled one pixel lower. This isolates a one-pixel bottom-WINDOW offset; it is not an icon, tile, or palette defect. `pixel-alignment.json` retains counts. Avoid a broad renderer rewrite for this one-pixel hardware-granularity residual while higher-impact gameplay defects remain.
- **Remaining/status:** P7.1a remains **FAIL** at exact-pixel parity, but the corrected static OW/UW sheet is narrowly verified. Revisit the HUD pixel phase only with a feasible WINDOW rendering approach; do not disturb the accepted menu alignment or original gameplay HUD. Music remains deferred.

### P3.3/P3.4 wanderer equal-axis turn - 2026-09-23

- **Behavior/owner/dependencies:** A walker targeting Link when target Y equals enemy Y and horizontal distance is below nine pixels must take the NES vertical-turn path. `src/oracle/enemies/enemy_wanderer_runtime.c:enrt_wanderer_target_player` owns the shared AI branch used by Octoroks and other wanderers; it depends on the walker move/grid state and chase-target update.
- **NES reference/drain/coverage/stance:** `reference/aldonunez/Z_04.asm:Wanderer_TargetPlayer/@TurnVertically` uses `CMP ObjY` / `BCC` for UP only when target Y is lower, then loads `$04` and branches to `@SetDirTowardTarget` for both greater and equal Y. The drained C previously treated equality as a fallthrough to the horizontal branch. **Coverage:** source branch and compilation; live equal-axis behavior remains unverified. **Stance:** REPAIR source translation and continue focused live verification.
- **Repair/result:** Changed the drained branch to select DOWN on equality. `Debug.bat` passes on build SHA256 `1d1d8fecec422d2063226d473f9be0006b7c3012ce7413c23a41dbc587f377bd`; regression matrix remains 12 green, 0 red. Initial staged NES/Genesis room `$77` Octorok probes did **not** isolate this branch: both entered shooting/turn behavior on the first frame. Their traces and exact identities are retained in `builds/reports/recovery/wanderer-equal-y-gen-20260923/result.json`, marked PARTIAL rather than accepted parity.
- **Remaining/status:** **ACTIVE**. Reproduce the equal-axis branch in a settled live encounter, then verify facing/motion in NES and Genesis. The Octorok family and enemy system remain incomplete; music remains deferred.

### P3.3/P3.4/P6.1 Ganon shared Wizzrobe movement - 2026-09-23

- **Behavior/owner/dependencies:** Ganon's blue-phase movement and burst rays use Blue Wizzrobe movement. `src/oracle/enemies/enemy_wizzrobe_runtime.c` owns the shared NES movement, direction turn, tile query and collision response; `enemy_ganon_runtime.c` owns the Ganon scene. The enemy update dispatch already links both owners.
- **NES source/drain/coverage/stance:** `reference/aldonunez/Z_04.asm:Ganon_MoveAndShoot` calls `BlueWizzrobe_TurnSometimesAndMoveAndCheckTile`, whose tile branch reverses direction at walls or starts teleporting through block/water. Drained C had the full routine for regular Blue Wizzrobes, but Ganon used a second copy that stopped after moving. **Coverage:** dispatch census, source comparison and linked build; live Ganon movement remains unverified. **Stance:** EXTEND the existing drained routine and remove the incomplete duplicate.
- **Repair/result:** Exposed the existing shared movement and turn/check routine for Ganon and his burst rays. The NES update dispatch census found no missing walker/boss rows; the remaining unwired non-no-op rows are Pond Fairy `$2F`, Zelda `$37`, Flute Secret `$5E`, and overworld objects `$61-$68`, tracked separately from enemy-family completion. `Debug.bat` passed, generated-freshness passed, and the regression matrix is GREEN=12 RED=0. Build SHA256 `131a68676c05c71ba737e471ba9572d0fcad62676fb77d1a607aa0da07c67d7f`. Build log: `builds/reports/recovery/ganon-shared-wizzrobe-20260923/build.log`. This is **PASS for shared source routing**, not a Ganon encounter acceptance.
- **Remaining/status:** P3.3/P3.4 and P6.1 stay **ACTIVE**. Compare a live Ganon movement/attack/vulnerability/death/reward route against NES, then Zelda and ending separately. The unwired dispatch rows remain TODO. Music remains deferred.

### P6.1 Ganon state alias and live entry - 2026-09-23

- **Behavior/owner/dependencies:** L9Q1 Ganon must spawn in room `$42`, finish his timed entrance, enter combat, move and launch visible fireballs. `enemy_ganon_runtime.c` owns scene phases and boss object state; `enemy_state.h` defines their distinct NES RAM offsets. The current ROM-derived dungeon data installs AttrsC `$3E` and BossRoomId `$42`.
- **NES source/drain/coverage/stance:** `reference/aldonunez/Z_04.asm:Ganon_ScenePhase2`, `Ganon_UpdateBrownState` and `Ganon_CheckCollisions` all access `ObjState,X` at `$00AC+slot`. The drained C instead accessed `ENEMY_AI_STATE(slot)` at `$0444+slot`; slot 1 aliases the global `Ganon_ScenePhase` byte `$0445`. The brown-state silver-arrow check likewise used the wrong slot-18 state. **Coverage:** source and focused L9Q1 debug-entry behavior. **Stance:** REPAIR the state mapping in the existing drain.
- **Reproduction/fix/result:** Before correction, an isolated BizHawk warp into `$42` spawned type `$3E` in slot 1 but phase alternated 1/2 every frame after the entrance; Ganon stayed at X=`$30`, Y=`$6D` and did not enter sustained combat. Replacing those reads/writes with `ENEMY_STATE_TIMER` gives 147 consecutive phase-2 frames in the same focused probe, movement to Y=`$AB`, and a spawned `$56` fireball. The probe and full trace are `builds/reports/recovery/ganon-room-entry-20260923/`; it uses a private BizHawk config and terminates only its owned process. `Debug.bat` and regression matrix passed (GREEN=12 RED=0). The state-alias build `Debug.md` SHA256 was `73a33c1fe472866f0c977750341ecb3fe41f77f26ba54a86677c3f0caa226eba`; the collision-bridge build below also reran this case. This is **PASS for local spawn/entrance/movement/attack**, not for the full fight or connected route.
- **Remaining/status:** P6.1 remains **ACTIVE** for NES-matched visibility, sword-to-brown state, silver-arrow finish, death effect/reward, Zelda rescue and ending. P3 enemy completion remains open across other families. Music remains deferred.

### P6.1 Ganon collision bridge - 2026-09-23

- **Behavior/owner/dependencies:** Ganon must reject swords while visible and accept them in his blue invisible window, then enter brown state. `src/oracle/enemies/enemy_ganon_runtime.c` owns the boss rule; `src/game/enemies/enemy_ganon_bridge.c` connects it to already-linked combat, Link-contact and sprite dispatchers.
- **NES source/drain/coverage/stance:** `reference/aldonunez/Z_04.asm:Ganon_CheckCollisions` calls the sword and arrow/rod collision routines and Link-contact check. The drained Ganon scene called these names, but the linked bridge supplied four no-op stubs, so no weapon could advance the fight. **Coverage:** linked-path inspection plus a focused Genesis BizHawk sword accepted/rejected interaction; arrow, contact and burst presentation are not yet accepted. **Stance:** EXTEND the existing native dispatchers with forwarding functions.
- **Reproduction/fix/result:** Before the repair, a controller A-button wooden-sword swing overlapping invisible Ganon left him blue at state `$00`, HP `$10`. The bridge now forwards sword, arrow/rod, Link-contact and sprite-position calls to the linked dispatchers. After the repair, a visible-window swing still left state `$00`, HP `$10`; the same live weapon in the invisible window produced brown state `$FE` after the `$FF` countdown began, with HP restored to `$F0`. A controller-fired ordinary arrow left the death phase at `$00`; a silver arrow advanced it to `$01`, then the death sequence passed `$A0`, cleared room-item life `$FF->$00`, and incremented the kill count `$00->$01` once. The fixtures stage Ganon's position and timer to isolate collision; nearby staged Link immediately took metadata item `$0E`, so reward appearance is not accepted. `builds/reports/recovery/ganon-room-entry-20260923/combat.lua`, `arrow.lua`, their traces, screenshots, runners and `bridge-result.json` retain the executable cases. `Debug.bat` passed; the local entry probe still passed; regression matrix GREEN=12 RED=0. Build `Debug.md` SHA256 `3ecc4f4581b0e2b3bcc9d56645cb22acedd85498bf759fd358c274b9ee1c32c4`. **PASS for staged local sword/arrow gates and room-item activation only.**
- **Remaining/status:** P6.1 remains **ACTIVE** for rendered death effects, Triforce pickup/departure, Zelda/ending, NES-aligned appearance/animation, Link contact and a connected unassisted fight. The full enemy system remains open. Music remains deferred.

### P0.14/P6.1 Ganon chamber, body and reward - 2026-09-24

- **Behavior/owner/dependencies:** L9Q1 room `$42` must reveal the NES chamber after Ganon's opening fade; his 32x32 body, attacks and Power Triforce must render over it. `RoomRom/tools/uw_reachability.py` and `gen_uw_blob.py` own captured room data; `RoomRom/src/main.c` owns dark-room reveal; `src/game/world/draw_dispatch.c` owns Ganon's OAM submission; `src/game/dungeon/item_room_meta.c` owns native pickup routing.
- **NES source:** `reference/aldonunez/Z_04.asm:Ganon_ScenePhase0`, `Ganon_DrawBody`, `Ganon_Dying`, `Ganon_ActivateRoomItem`; `Z_01.asm:TryTakeRoomItem`.
- **Drained C:** `src/oracle/enemies/enemy_ganon_runtime.c:ganon_scene_phase0/ganon_draw_body/ganon_dying`; `src/game/cave/cave_dispatch.c:cave_try_take_room_item`.
- **Coverage:** PARTIAL (live NES/GPGX static scene and staged controller combat/reward; connected L9 fight, departure/reentry and Zelda route remain).
- **Stance:** EXTEND the existing capture, OAM, fade and item paths.
- **Reproduction/result:** NES BizHawk room `$42` contains the full gray chamber and eight-sprite Ganon. Genesis previously showed a black field: the doorway-only capture list omitted `$42`, and the dark-room renderer erased Plane A without restoring it after the drained candle fade. The reachability capture set now includes its LevelInfo boss room, a live NES CIRAM/PALRAM capture adds it to the original blob, and the native fade completion redraws the current room while preserving door state and the running encounter. The body was also absent because its four pairs went only to the four-entry native cache while the boss sweep read OAM; its existing draw path now writes the eight NES OAM sprites. Focused Genesis frames `builds/reports/recovery/ganon-room-entry-20260923/phase1.png` and `phase2-start.png` show the chamber and full body; NES comparison is `builds/reports/recovery/ganon-reference-20260923/body.png`. The room probe still observes sustained phase 2, movement and a `$56` fireball. The staged sword/arrow/reward probe rejects a visible sword and ordinary arrow, accepts an invisible-window sword and silver arrow, increments the kill count once, and renders item `$0E` at native slot-19 `(75,8E)` before controller pickup. Pickup sets the room-taken flag and fanfare, then clears its timer/action lock. `reward.png`, `reward.txt` and `reward-pickup.txt` are in the Ganon report directory. Build SHA256 `8ee2865a9831ec4d0a021558ddb805521efd8b411c18a6415a3b0146b1cd06db`. Generated freshness passes; regression matrix GREEN=12 RED=0. The existing map/compass named-consumer probe passed after the earlier native item-pickup change.
- **Remaining/status:** P6.1 stays **ACTIVE**. These are staged local fight fixtures, not a connected unassisted fight. Compare Ganon's live appearance, attack and death animation against NES through motion; verify room departure/reentry and the rescue handoff. P8.3 retains Zelda/ending acceptance. Music remains deferred.

### P0.14/P6.1/P8.3 Ganon departure and Zelda rescue handoff - 2026-09-24

- **Behavior/owner/dependencies:** Power Triforce pickup must release Ganon room `$42`'s north shutter, scroll into Zelda room `$32`, spawn Zelda and four guard fires, and start ending mode when Link reaches Zelda. `src/game/world/progress_dispatch.c`, `src/game/enemies/enemy_loop.c`, `enemy_walker_bridge.c`, `enemy_render.c`, and `RoomRom/src/main.c` own the state, doors, room script, sprites and typed Link position. Captured L9Q1 room data and boss CHR are dependencies.
- **NES source:** Live NES BizHawk `ganon-reference-20260923/probe.lua` and `reference/aldonunez/Z_04.asm:InitZelda/UpdateZelda`, `Z_07.asm:Walker_Move`. **Drained C:** `progress_check_power_triforce_fanfare`, `room_check_secret_trigger_last_boss`, `uw_door_state_trigger_shutters`, `sprite_anim_fetch_obj_pos`, `draw_object_mirrored`, and the existing timer loop. **Coverage:** PARTIAL behavior/presentation/integration; staging still sets Ganon's fight position/timer. **Stance:** EXTEND dispatch and room-render data; REPAIR Link movement's extra invincibility lock.
- **Reproduction/repair:** The NES reference opened Ganon's north/south shutters after reward, entered `$32`, spawned Zelda `$37` at `(78,88)` plus four fires `$3F`, moved Link to `(88,88)` on contact at Link Y=`$95`, then entered Mode `$13` after Zelda's `$80` timer. Genesis initially kept the shutters shut and had no Zelda handler or flames. The room-secret trigger now preserves the carry bit before opening native shutters; ROM pointer-derived room extraction now includes both `$42` and `$32`; Zelda's dispatch initializes slots 1–5, draws her from the boss CHR bank, and performs the rescue state handoff. A second failure held Link immobile throughout the `$04F0` invincibility timer after guard-fire knockback; NES `Walker_Move` blocks only during shove, so that extra lock was removed.
- **Scenario/build/result:** PASS for this staged Ganon-to-ending-mode route. Isolated BizHawk `reward.lua` drives controller sword/arrow attacks, picks up item `$0E`, walks Up through the opened shutter (`opened=$0C`), enters `$32`, and reaches Zelda with Up input at approach frame 88. It records Zelda state `$01`, Link `(88,88)`, timer `$80`, and Mode `$13` once the timer drains (wait frame 160). `zelda-room.png`, `zelda-rescue.png`, `ending-handoff.png` and `zelda-room.txt` are in `builds/reports/recovery/ganon-room-entry-20260923/`; NES comparison frames/traces are in `ganon-reference-20260923/`. Genesis `Debug.md` SHA256 `cfea713e6b99fb7a4cd9a6644017231c008710c1407b176ac4bd17f361926f15`; probe Lua SHA256 `3817bdd688d9c71a6fd9e0a6e596e088528147025f333e56d4b1f999cb5af5ef`; NES source-ROM SHA256 `8f72dc2e98572eb4ba7c3a902bca5f69c448fc4391837e5f8f0d4556280440ac` (local reference only, not distributed). `verify_uw_level.py 9 1 orig` 12/12, generated freshness 8/8, and regression matrix GREEN=12 RED=0.
- **Remaining/status:** P6.1 and P8.3 remain **ACTIVE**. The fight uses staged Ganon position/timer and is not a connected unassisted L9 route. Re-entry, full attack/death motion and actual Mode-13 ending presentation remain unaccepted. The ending renderer still has active sprite/credits/finalize stubs. `RoomRom/out` captures are ignored build inputs; a fresh builder run from the user's NES ROM must reproduce both newly captured rooms before P0.14 passes. Music remains deferred.
