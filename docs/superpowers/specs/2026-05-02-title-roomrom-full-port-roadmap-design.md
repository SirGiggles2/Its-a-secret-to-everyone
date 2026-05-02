# Title.md + RoomRom Full Zelda Port Roadmap

**Date:** 2026-05-02
**Status:** Draft roadmap, PrimeDirective-selected
**Rule:** `$PrimeDirective` governs unanswered choices: best long-term outcome, maximal efficiency, best coding practices, NES accuracy first, Genesis-native implementation, and task shapes that fit Codex + Claude (Coding CLIs) strengths.
**Implementation index:** [Master plan](../plans/2026-05-02-title-roomrom-full-port-master-plan.md) is the executable phase checklist; this roadmap is the strategic spec.

## Goal

Finish the Sega Genesis port of *The Legend of Zelda* as a native Genesis game that matches NES Zelda behavior and presentation by default, supports selectable Redux-style options from file select, optionally supports up to 4 players as a Genesis-enhanced mode, and can be legally distributed as a builder program that extracts required assets from a user-supplied NES ROM instead of shipping Nintendo-derived assets.

## Strategic Decision

Use a two-ROM development split until the end:

- `Title.md`: renamed from `whatif.md`. This target owns the release-facing frontend: title loop, intro/story sequence, file select, name entry, options, save menus, and the Phase 12 final game handoff.
- `RoomRom`: remains the fast gameplay laboratory. It boots directly into gameplay scenes, proves rendering/state/combat/enemies/dungeons/caves without frontend friction, and stays the first place new gameplay systems land.
- Final release combines them only after RoomRom proves the full gameplay core and Title.md proves frontend/options/save flow.

This is the best long-term shape because it keeps iteration fast, keeps bugs localized, and lets Codex + Claude (Coding CLIs) work in deterministic slices with probes and screenshots instead of constantly booting through frontend state.

## Approaches Considered

### 1. Keep extending the old transpiled WHATIF path

Pros: existing probes and some behavior parity are already there.

Cons: long-term ownership stays poor, generated code and NES-shim behavior keep leaking into new work, and every feature risks becoming a compatibility patch instead of a clean Genesis-native subsystem.

Decision: reject as the main path. Use old WHATIF/transpiled code only as a reference and temporary bridge where needed.

### 2. Merge Title.md and RoomRom immediately

Pros: one ROM sooner.

Cons: slows every gameplay iteration, couples frontend bugs to gameplay work, and makes the coding CLIs less efficient because every probe has to traverse title/file-select state.

Decision: reject until the gameplay core is nearly complete.

### 3. Keep Title.md and RoomRom separate, promote verified RoomRom systems into shared game core

Pros: fastest iteration, clean subsystem ownership, easy per-system probes, and a controlled final integration point.

Cons: requires discipline to prevent RoomRom-only hacks.

Decision: chosen. RoomRom systems must be written as future shared game-core modules, with harness-only code kept thin.

## Legal / Distribution Requirement

The final public deliverable is not a ROM with bundled Nintendo-derived assets. It is a builder program:

1. User drags a valid NES Zelda ROM onto the builder.
2. Builder validates the ROM hash and region.
3. Builder extracts CHR, room, palette, text, enemy, item, audio, and table data.
4. Builder generates local asset blobs.
5. Builder links those generated assets with our Genesis-native code.
6. Builder outputs the final `.md` ROM.

Release packages must not include extracted Nintendo art, maps, text, music data, or generated C blobs derived from those assets. Development can keep private generated caches, but the public packaging path must prove a clean build from code + user ROM only.

Redux-style options are implemented as code-driven toggles for every feature we own. If exact Redux assets or patches are required, the builder must require the user to supply the relevant Redux patch/ROM input or use our own legally distributable transformation recipe. No third-party copyrighted patch payload is bundled unless its license is verified and recorded in the release manifest.

## Final Architecture

```text
User NES ROM
    |
    v
Asset Extractor / Builder
    |
    +--> generated local data cache (gitignored, not distributed)
    |
    v
Genesis-native codebase
    |
    +--> frontend core from Title.md
    +--> gameplay core promoted from RoomRom
    +--> options/save/audio/adapters
    |
    v
Final Zelda Genesis .md
```

Primary source ownership:

- `src/frontend/`: title, story, file select, name entry, options menu, save menus.
- `src/game/`: promoted RoomRom gameplay systems.
- `src/state/`: typed game, save, options, player, enemy, room, inventory state.
- `src/sgdk_adapter/`: thin Genesis/SGDK helpers only.
- `RoomRom/src/`: gameplay harness plus shared modules before promotion.
- `tools/`: deterministic extraction, generation, validation, BizHawk capture, and final builder tooling.

## Development Rules

1. NES behavior is the spec unless an option explicitly changes it.
2. Genesis-native implementation is preferred over NES-hardware emulation.
3. RoomRom is a harness, not a fork. Gameplay code written there must be promotable.
4. Every subsystem closes with a build, emulator probe, screenshot or state diff, and committed evidence.
5. Generated assets must be reproducible from the user-supplied ROM.
6. Public release must build from a clean tree with no private asset files present.
7. Optional 4-player mode is a separate enhanced mode. It must not destabilize 1-player NES parity.
8. Child implementation plans run under `superpowers:executing-plans`.
9. Independent implementation slices use `superpowers:subagent-driven-development` and `superpowers:dispatching-parallel-agents`.

## Immediate Roadmap From Current State

Current known state:

- Title/file-select work is mostly done but should be formalized under `Title.md`.
- RoomRom has strong overworld/UW rendering, movement, sprites/items work, and active sprite atlas/CHR/palette work.
- Claude is adding the full sprite set to RoomRom so graphics stop clobbering.
- Map rendering is close to perfect.
- Next gameplay target is Overworld Caves.

After Overworld Caves, the correct next step is not enemies first and not final integration. The next step is to finish the full room/state skeleton that downstream systems depend on:

1. Cave entry/exit and cave interiors.
2. Shops, old men, item grants, and cave text.
3. Overworld secrets and overworld item interactions.
4. Dungeon transitions, doors, stairs, dark rooms, and locked room state.
5. Then Link combat/items.
6. Then enemies and bosses.

That order is dependency-correct: caves and overworld secrets define world transitions and persistent flags; dungeon core defines doors, stairs, collision, and room-clear state; Link/items/combat need those room rules; enemies need combat and room-clear rules; bosses need the enemy/combat/render pipeline plus dungeon reward state. This prevents enemy/combat work from being written against a half-real world model.

## Phase 0 - Rename And Split Targets

Goal: make the target split explicit.

Steps:

1. Rename build output `builds/whatif.md` to `builds/Title.md`.
2. Rename listing/object outputs consistently: `Title.lst`, `Title.elf`, `Title.o`, with compatibility aliases only where old probes require them.
3. Update build scripts, probe scripts, README references, and launcher defaults.
4. Keep `RoomRom/out/RoomRom.md` unchanged.
5. Add a short architecture doc explaining that `Title.md` is frontend-first and `RoomRom.md` is gameplay-test-first.
6. Verification: `Title.md` builds and boots title/file-select; `RoomRom.md` builds and boots direct gameplay.

## Phase 1 - Asset Builder And Legal Foundation

Goal: make the future legal release path real early, not as an afterthought.

Steps:

1. Define `tools/builder/` as the final asset/build pipeline home.
2. Add ROM hash validation for USA PRG0 and USA PRG1; reject PAL and unsupported hashes with clear messages.
3. Add a Redux input recipe: user supplies either a supported Redux-patched ROM or a locally-owned patch plus a supported base ROM.
4. Generate all current `data/` and `RoomRom/data/` assets from the NES ROM into a gitignored cache.
5. Add manifest files recording source ROM hash, extractor version, output file hashes, and generation timestamp.
6. Change build scripts to prefer generated local assets and fail clearly when missing.
7. Add a clean-build test: delete generated cache, drag/pass ROM to builder, rebuild assets, build `Title.md` and `RoomRom.md`.
8. Add release-packaging check that rejects Nintendo-derived generated assets in the public bundle.

## Phase 2 - Finish RoomRom Graphics Registry

Goal: eliminate sprite/tile/palette clobber permanently.

Worktree rule: active RoomRom implementation for this phase happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`, not the main worktree.

Steps:

1. Finish current full sprite atlas work.
2. Finish item atlas wiring for sword, beam, boomerang, arrow, bomb, explosion, pickups, NPCs, enemies, and bosses.
3. Finish BG palette + full PALRAM capture pipeline.
4. Finish CHR expansion so NES sub-palettes become tile-index selection, not Genesis palette-slot collisions.
5. Centralize VRAM allocation in `roomrom_vram_map.h`.
6. Add slot-map verifier: no renderer can use `(pal & 0x03) << 13` after cutover.
7. Add per-scene VRAM budget verifier.
8. Verification: orig/Redux, OW/UW, all toggles, no stale CHR, no palette clobber, sprite atlas strict mode green.

## Phase 3 - Overworld Caves

Goal: make every overworld cave entrance behave like NES Zelda.

Worktree rule: active RoomRom implementation for this phase happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`, not the main worktree.

Steps:

1. Extract cave room templates, cave palettes, cave text, cave NPC data, shop inventories, and item-grant metadata.
2. Add RoomRom cave scene mode.
3. Enter cave from overworld cave/stair tile using real overworld room metadata.
4. Render cave interior with HUD intact.
5. Render old man/shop/NPC/item sprites and text box.
6. Implement item grant: sword, hearts, letter, potion/shop items, money-making game rewards.
7. Implement purchase rules: rupees, inventory full checks, denied purchase behavior.
8. Implement cave exit back to correct overworld room and Link position.
9. Add probes for every cave type.
10. Verification: all overworld cave types render and function against NES captures.

## Phase 4 - Overworld Secrets And Traversal

Goal: make the overworld stateful, not just rendered.

Worktree rule: active RoomRom implementation for this phase happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`, not the main worktree.

Steps:

1. Bombable walls and burnable bushes.
2. Stair reveal and cave reveal state.
3. Recorder/whirlwind/warp triggers.
4. Raft docks and raft motion.
5. Ladder water traversal.
6. Lost Woods / Lost Hills routing.
7. Heart container pickups and overworld item pickups.
8. Automap and visible secret options.
9. Save-state persistence for revealed secrets and collected items.
10. Verification: canonical NES input movies for each traversal/secret type.

## Phase 5 - Dungeon Core

Goal: make underworld rooms physically and statefully correct before adding full enemy pressure.

Worktree rule: active RoomRom implementation for this phase happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`, not the main worktree.

Steps:

1. Dungeon collision grid from rendered room data.
2. Door types: open, shutter, locked, bombable, boss, walk-through.
3. Door open/close state and room-clear state.
4. Stairs, passages, item cellars, and room warps.
5. Dark room masking and candle/light behavior.
6. Push blocks.
7. Traps, blade traps, bubbles, fire bars, and environmental hazards.
8. Keys, map, compass, triforce room state.
9. Level 1 end-to-end navigation.
10. All 9 dungeons x 2 quests static render/state smoke.

## Phase 6 - Link, Inventory, And Combat

Goal: complete the player system against NES behavior.

Worktree rule: active RoomRom implementation for this phase happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`, not the main worktree.

Steps:

1. Link movement parity: overworld, cave, dungeon, stairs, doors, scroll transitions.
2. Link animation and facing state.
3. Sword stab, sword beam, optional Redux sword arc/diagonal sword toggles.
4. Damage, knockback, invincibility, death.
5. Item use: boomerang, bombs, bow/arrows, candle, recorder, bait, potion, wand, book, raft, ladder.
6. Inventory model and B-button selection.
7. Pause/item subscreen.
8. Heart containers, max hearts, rings/tunic state, shield state.
9. Pickups and rupee/bomb/key counters.
10. Verification: per-item canonical movie against NES.

## Phase 7 - Enemies

Goal: implement enemies by behavior family, not random sprite type.

Worktree rule: active RoomRom implementation for this phase happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`, not the main worktree.

Order:

1. Simple walkers: octorok, moblin, stalfos, goriyas.
2. Flyers/jumpers: keese, peahat, vire, gels/zols.
3. Projectile users: rocks, arrows, swords, fireballs.
4. Contact/special enemies: like-like, bubble, wallmaster, pols voice.
5. Aquatic/terrain constrained enemies.
6. Spawn rules, room enemy tables, RNG, drop tables.
7. Damage/death/drop pipeline.
8. Verification: one probe per family plus full-room smoke tests.

## Phase 8 - Bosses

Goal: complete every boss as a separate verified behavior package.

Order:

1. Aquamentus.
2. Dodongo.
3. Manhandla.
4. Gleeok variants.
5. Digdogger.
6. Gohma.
7. Patra.
8. Moldorm/Lanmola.
9. Ganon.
10. Triforce/Zelda ending sequence hooks.

Each boss gets sprite atlas coverage, AI state, hit logic, room-clear behavior, audio triggers, and a deterministic probe.

## Phase 9 - HUD, Pause, Options, Save

Goal: make the full user-facing game state coherent.

Steps:

1. Native HUD: hearts, rupees, bombs, keys, map, compass, item boxes, dungeon map.
2. Native pause/subscreen.
3. File-select OPTIONS submenu fully wired.
4. Options state stored in reserved SRAM range.
5. Wire Redux-style options:
   - graphics: HUD, font, tunic/ring colors, dungeon colors, automap, visible secrets;
   - audio: low-health warning, dungeon music preference where supported;
   - combat: sword style and like-like behavior;
   - gameplay: start hearts, bomb upgrades, lost woods behavior, flashing reduction, dark-room light, A/B swap, auto-collect.
6. Native copy/erase/save flows.
7. Death, continue, save-and-quit.
8. Name entry and second quest trigger.
9. Verification: SRAM survives power cycle, old save slots are not corrupted, options migrate by version.

## Phase 10 - Audio Finalization

Goal: all songs and SFX play correctly through the Genesis audio path.

Steps:

1. Keep the current custom driver behind the audio adapter as the default; revisit SGDK XGM/XGM2 only if Phase 15 measurements show a budget, maintainability, or fidelity reason.
2. Extract or transform NES song/SFX data through builder pipeline.
3. Map overworld, dungeon, title, cave, item, death, boss, and ending music.
4. Map SFX: sword, beam, item, rupee, heart, door, bomb, enemy hit/death, boss, low-health.
5. Wire option-controlled low-health warning.
6. Add audio event probes for discrete SFX and transition events, plus a manual/hardware listen checklist for full music-track quality.
7. Verification: no audio subsystem breaks VBlank/DMA budget.

## Phase 11 - Title.md Frontend Gap-Fill + Regression Lock

Goal: treat the mostly-built title/file-select work as an existing frontend, fill remaining gaps, and lock it with regression probes before final gameplay merge.

Steps:

1. Complete title loop, intro fade, story scroll, item showcase.
2. Complete file select with 3 slots, cursor, copy, erase, name entry.
3. Complete PLAYERS row and OPTIONS submenu.
4. Complete save/load handoff contract.
5. Add final title/FS assets to builder extraction flow.
6. Add frontend regression probes: title idle, story loop, Start to FS, options persistence, copy/erase, saved-slot start, empty-slot name entry.
7. Verification: Title.md frontend can be built from extracted assets and passes all frontend probes.

## Phase 12 - Promote RoomRom Core Into Final Game

Goal: combine the proven gameplay core with Title.md without losing RoomRom speed.

Promotion gate: a RoomRom module moves only after two green RoomRom probe runs, no RoomRom-only globals, typed `src/state/` ownership, a public `src/game/<subsystem>/` header, and recorded NES reference provenance.

Steps:

1. Identify which RoomRom modules are shared game core and move them under `src/game/`.
2. Keep `RoomRom/src/main.c` as harness-only.
3. Replace RoomRom-only global state with typed `src/state/` structures.
4. Connect file select save slot to game-state initialization.
5. Connect options state to gameplay systems.
6. Connect room/dungeon/cave mode dispatcher.
7. Keep RoomRom building against the shared game core.
8. Build final integrated ROM target from Title.md frontend + shared game core.
9. Verification: same gameplay probes pass in RoomRom and final integrated ROM where applicable.

## Phase 13 - Optional 4-Player Genesis Mode

Goal: add a Genesis-enhanced mode without compromising NES-faithful 1-player.

Rules:

1. Default mode remains 1-player NES-faithful.
2. 2-4 player mode is selected from file select.
3. Multiplayer code uses the same Link/player component generalized to `PlayerState[4]`.
4. Shared world progression, shared inventory, and per-player hearts are the first implementation.
5. Camera/room transitions stay room-based: players must remain in the same room; transition triggers when the lead player exits and other players are pulled to valid entry positions.
6. Friendly collision is disabled by default for efficiency and playability.
7. Extra players use Genesis sprite capacity carefully; enemies/bosses retain priority over cosmetic extras.
8. Support Genesis multi-controller adapters through an input adapter layer, not scattered controller reads.
9. Multiplayer mode has separate balance options and does not affect 1-player probes.
10. NES save slot bytes remain unchanged; multiplayer-only state lives in a separate versioned SRAM region that 1-player NES-faithful saves ignore.

Implementation order:

1. Refactor Link into a reusable player component.
2. Add input routing for players 1-4.
3. Add P2-P4 spawn/render/movement.
4. Add shared combat and damage.
5. Add multiplayer item-use policy.
6. Add transition/camera policy.
7. Add revive/death rules.
8. Add performance probes for sprite count and VBlank budget.

## Phase 14 - Full Quest Completion

Goal: complete the game, not just systems.

Steps:

1. First Quest complete from new file to ending.
2. Second Quest complete from new file to ending.
3. All caves visited.
4. All dungeons cleared.
5. All items collected.
6. All bosses defeated.
7. All save/load/death/continue paths verified.
8. NES-mode probes green or documented with explicit option-driven divergence.
9. Genesis-enhanced modes smoke-tested separately.

## Phase 15 - Genesis-Specific Optimization

Goal: use the Genesis hardware deliberately after correctness is proven, without turning optimization into guesswork or breaking NES parity.

Timing model: Phase 15a happens inline during Phases 2-6 for structural Genesis-native wins that are already part of the work, including VRAM map ownership, Window-plane HUD, DMA chunking, CRAM ownership, and sprite atlas layout. Phase 15b is the post-quest measured re-pass where broader rewrites require perf evidence.

Rules:

1. Optimize from measurements, not instinct.
2. Preserve NES-faithful behavior and timing unless an option explicitly changes it.
3. Prefer Genesis-native strengths: VDP planes, Window plane HUD, DMA, sprite hardware, CRAM organization, YM2612/PSG audio, flat ROM access, and 68K-friendly data layouts.
4. Keep optimizations behind narrow subsystem interfaces so RoomRom and Final.md share the same fast path.
5. Keep C as the default; use assembly only for measured hot paths, hard ABI glue, or hardware timing.

Steps:

1. Add per-frame CPU, VBlank, DMA, SAT, sprite-count, VRAM-upload, and audio-tick instrumentation.
2. Convert room/HUD/static UI transfers to bulk DMA where it is measurably faster and VBlank-safe.
3. Use Window plane for stable HUD/menu bands and Plane A/B for playfield/transition staging.
4. Use horizontal/vertical scroll hardware for room transitions instead of redrawing when scrolling is cheaper.
5. Keep scene-specific VRAM residency tables so common gameplay tiles stay resident and rare tiles stream only on scene load.
6. Use Genesis sprite sizes and link fields to collapse NES multi-OAM objects into fewer SAT entries when visual parity is preserved.
7. Precompute 68K-friendly room, collision, enemy, and animation tables under `build/generated/tables/` from extracted NES data.
8. Pack palettes and expanded CHR around Genesis CRAM/VRAM realities, not NES PPU register habits.
9. Keep audio events asynchronous and VBlank-safe so dense music/SFX never starve rendering.
10. Verify optimized paths against pre-optimization captures and keep unoptimized reference probes for regression diagnosis.

## Phase 16 - Hardware, Performance, And Accessibility

Goal: make it reliable on real hardware and safe for players.

Steps:

1. Test on real Genesis/Mega Drive hardware and flash cart.
2. Test common emulators: BizHawk/GPGX, BlastEm, and Genesis Plus GX.
3. Enforce VBlank/DMA budget.
4. Enforce sprite count/overflow policy.
5. Add no-flashing/reduced-flashing option.
6. Add deterministic crash/exception diagnostics for debug builds.
7. Add release build profile with diagnostics disabled or minimized.

## Phase 17 - Public Builder Release

Goal: distribute legally and reproducibly.

Steps:

1. Package builder executable or script with our code and extraction recipes only.
2. Drag-and-drop UX: user drops NES ROM; builder emits `.md`.
3. Validate ROM hash and show clear unsupported-ROM errors.
4. Optional advanced input: user supplies Redux patch/ROM if exact Redux-derived assets are required.
5. Generate all asset blobs locally.
6. Build final ROM locally.
7. Write output manifest with:
   - input ROM hash;
   - builder version;
   - generated asset manifest hash;
   - final `.md` hash.
8. Add "clean legal package" CI job: public release zip must contain no generated Nintendo-derived data.
9. Add "from scratch" CI/manual gate: fresh checkout + builder + user ROM produces final ROM.
10. Enforce reproducibility: the same NES ROM, builder version, and git SHA must produce byte-identical final `.md` output.
11. Add documentation for users and contributors.

## Verification Strategy

Every phase closes with:

- clean build;
- focused RoomRom or Title.md probe;
- NES-vs-Genesis screenshot or normalized state diff where applicable;
- one BizHawk launch per probe report per `feedback_one_big_probe`, with screenshot, SAT, CRAM, plane/Window dumps, RAM/state bytes, and input log captured together;
- report provenance: source ROM SHA, generated asset manifest hash, emulator/core/version, frame number, target ROM hash, and probe script hash;
- regression run for previously green gates;
- `superpowers:requesting-code-review` checkpoint for non-trivial implementation phases;
- archived report under `builds/reports/`;
- commit with a clear phase label.

Probe priority:

1. State diffs for behavior.
2. Plane/SAT/CRAM dumps for rendering.
3. Screenshots for final visual verification.
4. Hardware/emulator smoke for release confidence.

## Completion Definition

The project is finished when:

1. Final integrated Genesis ROM builds from code + user-supplied NES ROM.
2. First Quest and Second Quest are completable.
3. NES-faithful 1-player mode matches NES behavior except documented, option-controlled divergences.
4. Redux-style options are selectable from file select and persist in SRAM.
5. Optional 4-player mode is present and isolated from NES-faithful mode.
6. Title.md frontend and RoomRom harness still build.
7. Public builder package contains no Nintendo-derived generated assets.
8. Real hardware smoke passes.

## Spec Self-Review

- No open decisions require user questions; `$PrimeDirective` resolves ordering and architecture.
- The roadmap keeps RoomRom fast while preventing RoomRom-only forks.
- Legal builder requirement is integrated from Phase 1 through release, not bolted on at the end.
- Overworld Caves are placed correctly before overworld secrets, dungeons, enemies, and final integration.
- Genesis-specific optimization has a dedicated phase after quest completion and before hardware release validation.
- 4-player mode is explicitly optional and isolated so NES parity remains protected.
- Each phase has concrete acceptance gates.
