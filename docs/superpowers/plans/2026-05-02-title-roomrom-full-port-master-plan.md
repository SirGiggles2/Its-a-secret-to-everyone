# Title.md + RoomRom Full Zelda Port Master Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement each phase task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the full Sega Genesis Zelda port through a legally distributable builder that extracts assets from a user-supplied NES ROM.

**Architecture:** Keep `Title.md` and `RoomRom.md` separate until the gameplay core is verified. Promote proven RoomRom systems into shared `src/game/` modules, keep frontend under `src/frontend/`, and make all generated Nintendo-derived assets reproducible from a user-supplied NES ROM through `tools/builder/`.

**Tech Stack:** SGDK/m68k GCC, BizHawk Lua probes, Python asset extractors/generators/verifiers, PowerShell/Batch build launchers, C gameplay/runtime modules, Genesis `.md` output.

---

## Execution Rules

- [ ] Treat `$PrimeDirective` as the decision rule for every unresolved choice.
- [ ] Do not ask for option selection unless a destructive or external publishing action is required.
- [ ] Keep `RoomRom` as the fast gameplay harness and `Title.md` as the frontend/release harness until Phase 12.
- [ ] Before editing or building `RoomRom`, run `git worktree list` and use `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1` for active RoomRom work.
- [ ] Never hand-edit generated assets as the permanent solution.
- [ ] Never add Nintendo-derived generated data to the public release package.
- [ ] Every major phase gets its own child spec and child implementation plan before code changes.
- [ ] Every code phase closes with build, probe, screenshot/state evidence, and an atomic commit.
- [ ] Keep 1-player NES parity protected. Redux options and 4-player mode are option-driven divergence only.

## Repository Targets

- [ ] `Title.md`: release-facing frontend target.
- [ ] `RoomRom.md`: fast gameplay harness target.
- [ ] `Final.md`: final integrated ROM target introduced in Phase 12.
- [ ] `tools/builder/`: public legal builder pipeline.
- [ ] `generated/` or `build/generated/`: local generated asset cache, gitignored.
- [ ] `docs/superpowers/specs/`: durable specs.
- [ ] `docs/superpowers/plans/`: implementation plans.
- [ ] `builds/reports/`: verification evidence.

---

## Phase 0: Target Rename And Split

**Goal:** Make the `Title.md` / `RoomRom.md` development split explicit and remove `whatif.md` as the active conceptual target name.

**Files:**
- Modify: `build.bat`
- Modify: `README.md`
- Modify: `docs/SPEC.md`
- Modify: `tools/launch_bizhawk.ps1`
- Modify: `tools/run_all_probes.bat`
- Modify: `tools/run_all_probes.ps1`
- Modify: `tools/run_all_gates.bat`
- Modify: all `tools/run_*_gen.bat` that point at `builds/whatif.md`
- Modify: Lua probes that read `builds/whatif.lst`
- Create: `docs/targets.md`

### Task 0.1: Inventory Current `whatif` References

- [ ] Run: `rg -n "whatif|WHATIF|whatif\\.md|whatif\\.lst|whatif\\.elf|whatif\\.o" README.md docs tools src build.bat`
- [ ] Save output to `builds/reports/title_rename_reference_inventory.txt`.
- [ ] Classify each reference as build output, probe input, documentation, historical note, or compatibility alias.
- [ ] Keep historical notes unchanged when they describe past builds.
- [ ] Mark active build/probe references for renaming.

### Task 0.2: Rename Build Outputs

- [ ] In `build.bat`, change `OUT_ROM` from `builds\whatif.md` to `builds\Title.md`.
- [ ] Change `OUT_LST` from `builds\whatif.lst` to `builds\Title.lst`.
- [ ] Change `ELF_OBJ` from `builds\whatif.o` to `builds\Title.o`.
- [ ] Change `ELF_OUT` from `builds\whatif.elf` to `builds\Title.elf`.
- [ ] Change link/build echo text to say `Title.elf` / `Title.md`.
- [ ] Keep temporary compatibility copy:
  - [ ] After `Title.md` is created, copy it to `whatif.md`.
  - [ ] After `Title.lst` is created, copy it to `whatif.lst`.
  - [ ] Add a comment saying this alias exists only until all probes are migrated.
- [ ] Build once to prove alias and renamed output are both produced.

### Task 0.3: Rename Probe Inputs

- [ ] Update `tools/probe_addresses.lua` to prefer `builds\Title.lst`.
- [ ] Add fallback to `builds\whatif.lst` with a warning string for old archived builds.
- [ ] Update run scripts to pass `builds\Title.md`.
- [ ] Update scripts that delete `Genesis\SaveRAM\whatif.SaveRAM` to delete `Title.SaveRAM`.
- [ ] Keep deletion of old `whatif.SaveRAM` during transition to prevent stale emulator state.
- [ ] Run the fastest boot/title probe to confirm scripts resolve the new ROM name.

### Task 0.4: Add Target Architecture Doc

- [ ] Create `docs/targets.md`.
- [ ] Define `Title.md` as frontend/release target.
- [ ] Define `RoomRom.md` as gameplay harness target.
- [ ] Define `Final.md` as final integration target introduced in Phase 12.
- [ ] Document that `RoomRom` remains direct-boot for fast tests.
- [ ] Document that `Title.md` owns title/story/file-select/options/save frontend.
- [ ] Document that gameplay modules must be promotable from RoomRom into `src/game/`.
- [ ] Link this master plan.

### Task 0.5: Verify Phase 0

- [ ] Run `cmd.exe /c ".\build.bat"` from repo root.
- [ ] Confirm `builds\Title.md` exists.
- [ ] Confirm `builds\Title.lst` exists.
- [ ] Confirm compatibility aliases still exist if any old probe needs them.
- [ ] Run one title/frontend BizHawk probe.
- [ ] Run `git worktree list`.
- [ ] In RoomRom worktree, run `cmd.exe /c ".\RoomRom\build.bat"`.
- [ ] Confirm `RoomRom\out\RoomRom.md` still builds.
- [ ] Commit docs/build/probe rename as `build: rename main frontend target to Title.md`.

---

## Phase 1: Legal Builder Foundation

**Goal:** Make the future public distribution model real early: code plus user-supplied NES ROM produces all generated assets and final ROM locally.

**Files:**
- Create: `tools/builder/README.md`
- Create: `tools/builder/build_from_rom.py`
- Create: `tools/builder/roms.py`
- Create: `tools/builder/extract_all.py`
- Create: `tools/builder/manifest.py`
- Create: `tools/builder/package_check.py`
- Create: `tools/builder/gui_drop.ps1` or equivalent drag/drop wrapper
- Create: `tools/tests/test_builder_rom_validation.py`
- Create: `tools/tests/test_builder_manifest.py`
- Modify: asset extraction scripts under `tools/`
- Modify: `.gitignore`
- Modify: build scripts to use generated cache

### Task 1.1: Define Builder Inputs And Outputs

- [ ] Create `tools/builder/README.md`.
- [ ] Document supported input ROM: `Legend of Zelda, The (USA).nes`.
- [ ] Record required SHA-256: `8f72dc2e98572eb4ba7c3a902bca5f69c448fc4391837e5f8f0d4556280440ac`.
- [ ] Document optional Redux input policy:
  - [ ] If exact Redux assets are required, user supplies a compatible Redux ROM or patch.
  - [ ] The public package does not bundle Redux IPS payloads unless license is verified.
- [ ] Define output cache path: `build/generated/<rom_hash>/`.
- [ ] Define final ROM output path: `build/output/`.
- [ ] Define output manifest path: `build/output/build_manifest.json`.

### Task 1.2: Implement ROM Validation

- [ ] Create `tools/builder/roms.py`.
- [ ] Add `SUPPORTED_ROMS` table with name, size, SHA-256, mapper expectation, PRG size, CHR size.
- [ ] Implement `hash_file(path)`.
- [ ] Implement `identify_rom(path)`.
- [ ] Implement validation for iNES header.
- [ ] Reject missing file.
- [ ] Reject unsupported hash with a clear error.
- [ ] Reject ROMs with CHR ROM banks if Zelda 1 CHR-RAM expectation is violated.
- [ ] Add tests for valid hash, invalid hash, missing file, and invalid iNES header.

### Task 1.3: Define Generated Asset Manifest

- [ ] Create `tools/builder/manifest.py`.
- [ ] Define JSON schema fields:
  - [ ] `builder_version`
  - [ ] `source_rom_name`
  - [ ] `source_rom_sha256`
  - [ ] `extractor_versions`
  - [ ] `generated_files`
  - [ ] `generated_file_sha256`
  - [ ] `final_rom_path`
  - [ ] `final_rom_sha256`
- [ ] Implement manifest write.
- [ ] Implement manifest validation.
- [ ] Add tests for manifest round-trip and missing required fields.

### Task 1.4: Inventory All Existing Generated Assets

- [ ] Run: `rg --files data src/data src/gen RoomRom/data RoomRom/src | rg "\.(c|h|inc|bin|json|dat)$"`
- [ ] Classify files as:
  - [ ] extracted from NES;
  - [ ] extracted from Redux;
  - [ ] authored code/data;
  - [ ] build artifact;
  - [ ] private capture output.
- [ ] Save classification to `docs/audit/generated_asset_inventory.md`.
- [ ] Mark every Nintendo-derived generated file that public package must omit.

### Task 1.5: Wrap Existing Extractors

- [ ] Create `tools/builder/extract_all.py`.
- [ ] Call intro extractor.
- [ ] Call file-select extractor.
- [ ] Call room extractor.
- [ ] Call CHR extractor.
- [ ] Call palette extractor.
- [ ] Call enemy table extractor.
- [ ] Call item/audio/text extractors as they exist.
- [ ] For missing extractors, create stub commands that fail with an explicit named missing extractor error.
- [ ] Do not silently copy checked-in generated assets.
- [ ] Emit all generated files into `build/generated/<rom_hash>/`.
- [ ] Write output manifest.

### Task 1.6: Point Builds At Generated Cache

- [ ] Add `GENERATED_ASSET_ROOT` environment variable support.
- [ ] Update `build.bat` to use generated files when `GENERATED_ASSET_ROOT` is set.
- [ ] Update `RoomRom/build.bat` to use generated files when `GENERATED_ASSET_ROOT` is set.
- [ ] Keep current checked-in generated data path for development until each extractor is complete.
- [ ] Add warning when falling back to checked-in generated data.
- [ ] Add CI/manual gate that sets `GENERATED_ASSET_ROOT` and forbids fallback.

### Task 1.7: Add Package Cleanliness Check

- [ ] Create `tools/builder/package_check.py`.
- [ ] Reject files under public package matching generated asset extensions in `data/`, `src/data/`, `src/gen/`, `RoomRom/data/`, `RoomRom/src/roomrom_*_chr.c`, and other generated blobs.
- [ ] Allow source extractors, schemas, tests, docs, and authored code.
- [ ] Reject `.nes`, `.ips`, generated `.bin`, generated `.inc`, generated `.c` asset blobs.
- [ ] Add allowlist for authored C source modules.
- [ ] Add report listing every rejected file and why.

### Task 1.8: Add Drag-And-Drop Wrapper

- [ ] Create `tools/builder/gui_drop.ps1`.
- [ ] Accept one dropped ROM path.
- [ ] Run `python tools/builder/build_from_rom.py <rom>`.
- [ ] Print final `.md` output path.
- [ ] Keep console open on failure with error summary.
- [ ] Do not require users to edit environment variables manually.

### Task 1.9: Implement `build_from_rom.py`

- [ ] Validate ROM.
- [ ] Create generated cache directory.
- [ ] Run `extract_all.py`.
- [ ] Set `GENERATED_ASSET_ROOT`.
- [ ] Build `Title.md`.
- [ ] Build `RoomRom.md` when `--include-roomrom` is passed.
- [ ] Build `Final.md` after Phase 12 introduces the integrated target.
- [ ] Hash output ROM.
- [ ] Write final manifest.
- [ ] Exit non-zero on any failure.

### Task 1.10: Verify Phase 1

- [ ] Run unit tests for builder modules.
- [ ] Run builder with valid local NES ROM.
- [ ] Confirm generated manifest exists.
- [ ] Confirm at least one generated asset is built from cache.
- [ ] Run public package cleanliness check.
- [ ] Commit as `tools: add legal asset builder foundation`.

---

## Phase 2: RoomRom Graphics Registry And No-Clobber Foundation

**Goal:** Finish the current RoomRom graphics/atlas/palette/VRAM work so future gameplay systems never clobber sprites, palettes, HUD, or BG tiles.

**Worktree:** `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c`
- Modify: `RoomRom/src/roomrom_sprites.h`
- Modify: `RoomRom/src/roomrom_combat.c`
- Modify: `RoomRom/src/roomrom_hud.c`
- Modify: `RoomRom/src/ow_room_render_roomrom.c`
- Modify: `RoomRom/src/uw_room_render_roomrom.c`
- Create/modify: `RoomRom/src/roomrom_vram_map.h`
- Create/modify: `RoomRom/src/roomrom_bg_palette.c`
- Create/modify: `RoomRom/src/roomrom_bg_palette.h`
- Create/modify: `RoomRom/src/roomrom_item_chr.c`
- Create/modify: `RoomRom/src/roomrom_item_chr.h`
- Create/modify: `RoomRom/tools/*atlas*`, `RoomRom/tools/*chr*`, `RoomRom/tools/verify_*`

### Task 2.1: Reconcile Current Dirty Sprite Work

- [ ] Run `git worktree list`.
- [ ] In RoomRom worktree, run `git status --short`.
- [ ] Inspect dirty files:
  - [ ] `RoomRom/src/roomrom_sprites.c`
  - [ ] `RoomRom/src/roomrom_sprites.h`
  - [ ] `RoomRom/build.log`
- [ ] Determine Claude's current endpoint from code, not assumptions.
- [ ] Do not revert dirty edits.
- [ ] If edits are coherent and buildable, keep working on top.
- [ ] If edits are incomplete, document current compile error and continue the planned graphics phase.

### Task 2.2: Finish Item Atlas Art Correctness

- [ ] Verify live NES item CHR dump exists for original.
- [ ] Verify live NES item CHR dump exists for Redux.
- [ ] Generate item atlas C/H.
- [ ] Replace sword tile literals with atlas offsets.
- [ ] Replace sword beam tile literals with atlas offsets.
- [ ] Replace boomerang tile literals with atlas offsets.
- [ ] Replace arrow tile literals with atlas offsets.
- [ ] Replace bomb tile literals with atlas offsets.
- [ ] Replace explosion tile literals with atlas offsets.
- [ ] Replace pickup tile literals with atlas offsets.
- [ ] Add a manifest entry for every visible item.
- [ ] Add a strict verifier banning guessed item CHR.
- [ ] Build RoomRom.
- [ ] Run item probes: sword, beam, boomerang, arrow, bomb, explosion.
- [ ] Commit as `roomrom: source items from live NES atlas`.

### Task 2.3: Centralize VRAM Map

- [ ] Create or finalize `RoomRom/src/roomrom_vram_map.h`.
- [ ] Define blank tile 0.
- [ ] Define BG tile base.
- [ ] Define BG per-subpalette tile count.
- [ ] Define sprite tile base derived from BG base and BG count.
- [ ] Define sprite per-subpalette tile count.
- [ ] Define helper macros for BG tile base by subpalette.
- [ ] Define helper macros for HUD tile base by subpalette.
- [ ] Define helper macros for sprite tile base by subpalette.
- [ ] Replace hand-picked sprite bases in `roomrom_sprites.c`.
- [ ] Replace hand-picked item bases in combat/item modules.
- [ ] Replace HUD tile base literals.
- [ ] Replace BG base literals.
- [ ] Add `verify_vram_budget.py`.
- [ ] Build and run smoke.
- [ ] Commit as `roomrom: centralize vram map`.

### Task 2.4: Capture Full NES PALRAM

- [ ] Write or finish NES PALRAM capture probe for original overworld rooms.
- [ ] Write or finish NES PALRAM capture probe for Redux overworld rooms.
- [ ] Reuse existing underworld aggregate PALRAM where valid.
- [ ] Verify each PALRAM entry is 32 bytes.
- [ ] Verify universal backdrop byte is expected for sampled rooms.
- [ ] Generate `roomrom_ow_palette.c/h`.
- [ ] Generate `roomrom_uw_palette.c/h` when the existing UW aggregate is not already emitted as RoomRom-linkable C/H.
- [ ] Add central NES-to-Genesis CRAM converter.
- [ ] Add `roomrom_bg_palette_load_palram_full`.
- [ ] Add `roomrom_bg_palette_load_bg_only`.
- [ ] Build without renderer cutover.
- [ ] Commit as `roomrom: add live palram palette source`.

### Task 2.5: Expand CHR By NES Subpalette

- [ ] Implement BG CHR expander.
- [ ] Implement sprite CHR expander.
- [ ] Pixel rule: pixel 0 remains 0.
- [ ] Pixel rule: nonzero pixel becomes `subpal * 4 + pixel`.
- [ ] Generate expanded overworld BG.
- [ ] Generate expanded underworld BG.
- [ ] Generate expanded Redux overworld BG.
- [ ] Generate expanded Redux underworld BG.
- [ ] Generate expanded HUD/common BG tiles.
- [ ] Generate expanded item/sprite tiles.
- [ ] Keep outputs under RoomRom-local generated paths.
- [ ] Add generator manifest.
- [ ] Verify tile counts against VRAM budget.
- [ ] Commit as `roomrom: generate subpalette-expanded chr`.

### Task 2.6: Cut Renderers To Tile-Index Subpalette Selection

- [ ] In OW renderer, replace Gen palette-slot bits with BG tile base by subpalette.
- [ ] In UW renderer, replace Gen palette-slot bits with BG tile base by subpalette.
- [ ] In HUD renderer, use BG/HUD tile base by subpalette and Gen PAL0.
- [ ] In sprite renderers, use sprite tile base by subpalette and Gen PAL1.
- [ ] Delete old sprite palette PAL3 reload path.
- [ ] Ensure BG loader writes PAL0 full 16-color packed BG subpalettes.
- [ ] Ensure sprite loader writes PAL1 full 16-color packed sprite subpalettes.
- [ ] Reserve PAL2/PAL3 for non-NES overlays only.
- [ ] Add `verify_slot_map.py`.
- [ ] Run verifier and build.
- [ ] Run OW/UW/orig/Redux smoke.
- [ ] Commit as `roomrom: cut over palette-safe tile indexing`.

### Task 2.7: Verify Graphics No-Clobber

- [ ] Probe OW room `0x77` original.
- [ ] Probe OW room `0x77` Redux.
- [ ] Probe OW room `0x00` original.
- [ ] Probe UW Level 1 room 0 original.
- [ ] Probe UW Level 1 room 0 Redux.
- [ ] Probe a room using BG subpalette 3.
- [ ] Probe Link, sword, beam, arrow, boomerang, bomb, and explosion in a combined stress scene; if the scene cannot display every object at once without exceeding hardware limits, split into `combat_projectiles` and `combat_explosives` stress probes.
- [ ] Dump CRAM and SAT for each probe.
- [ ] Confirm no renderer uses old palette-bit pattern.
- [ ] Confirm no stale CHR on scene toggles.
- [ ] Commit as `roomrom: close graphics registry foundation`.

---

## Phase 3: Overworld Caves

**Goal:** Implement every overworld cave entrance, cave interior, NPC/shop/item/text behavior, and exit path in RoomRom.

**Files:**
- Create: `RoomRom/src/roomrom_cave.c`
- Create: `RoomRom/src/roomrom_cave.h`
- Create: `RoomRom/src/roomrom_textbox.c`
- Create: `RoomRom/src/roomrom_textbox.h`
- Create: `RoomRom/src/roomrom_shop.c`
- Create: `RoomRom/src/roomrom_shop.h`
- Modify: `RoomRom/src/main.c`
- Modify: `RoomRom/src/ow_room_render_roomrom.c`
- Modify: `RoomRom/src/roomrom_sprites.c`
- Create: `RoomRom/tools/gen_cave_data.py`
- Create: `RoomRom/probe_nes_cave_manifest.lua`
- Create: `RoomRom/probe_roomrom_caves.lua`

### Task 3.1: Build Cave Source Data Manifest

- [ ] Locate NES disassembly cave metadata tables.
- [ ] Locate Redux cave modifications.
- [ ] Extract overworld room to cave mapping.
- [ ] Extract cave type per entrance.
- [ ] Extract NPC/person type.
- [ ] Extract cave text id.
- [ ] Extract cave item/shop inventory.
- [ ] Extract prices.
- [ ] Extract item grant rules.
- [ ] Extract cave palette.
- [ ] Extract cave tilemap/template data.
- [ ] Generate `RoomRom/data/caves.json`.
- [ ] Generate C blobs for cave metadata.
- [ ] Add manifest hash.
- [ ] Verify generated data against NES ROM and Redux input.

### Task 3.2: Add Cave Scene State

- [ ] Add scene enum value for cave.
- [ ] Add `s_previous_scene`.
- [ ] Add `s_cave_return_room_id`.
- [ ] Add `s_cave_return_x`.
- [ ] Add `s_cave_return_y`.
- [ ] Add `s_cave_id`.
- [ ] Add cave enter function.
- [ ] Add cave exit function.
- [ ] Ensure B/C/A/Start debug toggles cannot corrupt cave state.
- [ ] Build RoomRom.

### Task 3.3: Detect Cave Entrances

- [ ] Classify overworld cave/stair tiles from rendered room data.
- [ ] Add collision/hotspot check for cave entry tile.
- [ ] Trigger entry when Link moves into the entrance coordinate.
- [ ] Store return room and coordinates.
- [ ] Disable normal edge transition during cave entry.
- [ ] Add transition blank/fade compatible with existing transition state.
- [ ] Verify one known cave entrance enters cave scene.

### Task 3.4: Render Cave Interior

- [ ] Upload cave/interior CHR.
- [ ] Load cave PALRAM.
- [ ] Render cave background.
- [ ] Keep HUD visible and correct.
- [ ] Render black borders/background outside cave view.
- [ ] Render text box area.
- [ ] Render NPC/item/shop sprites.
- [ ] Render Link at NES cave entry coordinate.
- [ ] Build and capture screenshot.
- [ ] Compare against NES cave screenshot.

### Task 3.5: Implement Cave Text Box

- [ ] Extract cave text strings.
- [ ] Generate text tile mapping.
- [ ] Add text box renderer.
- [ ] Add multi-line layout.
- [ ] Add NES text speed timing.
- [ ] Add option hook for faster text, wired to the Phase 9 options runtime when that runtime lands.
- [ ] Add line wrapping exactly as source.
- [ ] Add text clear on exit.
- [ ] Probe "IT'S DANGEROUS TO GO ALONE".
- [ ] Probe shop text.
- [ ] Probe generic old man hint text.

### Task 3.6: Implement Item Grant Caves

- [ ] Identify sword cave.
- [ ] Identify heart container caves.
- [ ] Identify white sword/magical sword requirement caves.
- [ ] Identify letter/other item grant caves.
- [ ] Add item pickup state.
- [ ] Add inventory mutation.
- [ ] Add item pickup sound trigger.
- [ ] Add item disappears after collection.
- [ ] Add save flag for collected cave item.
- [ ] Verify sword pickup.
- [ ] Verify heart pickup.
- [ ] Verify requirement denied behavior.

### Task 3.7: Implement Shop Caves

- [ ] Render three shop items.
- [ ] Render prices.
- [ ] Move cursor/selection across items.
- [ ] Detect purchase with A.
- [ ] Check rupee count.
- [ ] Deny purchase if insufficient rupees.
- [ ] Mutate inventory on purchase.
- [ ] Deduct rupees.
- [ ] Handle one-time vs repeatable items.
- [ ] Play purchase/deny sounds.
- [ ] Verify all shop types.

### Task 3.8: Implement Gambling / Money-Making Game

- [ ] Extract reward table.
- [ ] Render choices.
- [ ] Select choice.
- [ ] Apply RNG result consistent with NES.
- [ ] Mutate rupees.
- [ ] Render result text if NES does.
- [ ] Verify deterministic seeded case.

### Task 3.9: Implement Cave Exit

- [ ] Detect Link walking down/out.
- [ ] Trigger cave exit transition.
- [ ] Restore overworld scene CHR and palette.
- [ ] Restore previous room.
- [ ] Place Link at NES exit coordinate.
- [ ] Preserve inventory mutations.
- [ ] Preserve cave collected flags.
- [ ] Verify re-enter collected cave shows item gone.

### Task 3.10: Cave Matrix Verification

- [ ] Generate cave list from manifest.
- [ ] For each cave type, capture NES reference.
- [ ] For each cave type, capture RoomRom output.
- [ ] Compare tile layout.
- [ ] Compare palette.
- [ ] Compare NPC/item sprites.
- [ ] Compare text.
- [ ] Compare item/shop state mutation.
- [ ] Save report `builds/reports/roomrom_caves_matrix.md`.
- [ ] Commit as `roomrom: implement overworld caves`.

---

## Phase 4: Overworld Secrets, Traversal, And State

**Goal:** Make the overworld stateful and traversable beyond basic walking.

### Task 4.1: Create World State Module

- [ ] Add `src/state/world_state.h`.
- [ ] Add RoomRom-local world state if shared state is not promoted yet.
- [ ] Track current quest.
- [ ] Track current overworld room.
- [ ] Track revealed secrets.
- [ ] Track collected overworld items.
- [ ] Track opened overworld caves.
- [ ] Track recorder warp state.
- [ ] Track raft state.
- [ ] Track room visit/automap state.
- [ ] Add reset/new-file defaults.
- [ ] Add save/load serialization hooks.

### Task 4.2: Bombable Walls

- [ ] Extract bombable wall metadata.
- [ ] Add bomb explosion collision with secret wall tile.
- [ ] Reveal cave/stairs.
- [ ] Persist reveal flag.
- [ ] Play reveal sound.
- [ ] Prevent repeated reveal mutation.
- [ ] Verify each bombable wall class.

### Task 4.3: Burnable Bushes

- [ ] Extract burnable bush metadata.
- [ ] Add candle flame entity.
- [ ] Add flame collision with bush tile.
- [ ] Reveal stairs.
- [ ] Persist reveal flag.
- [ ] Enforce blue candle once-per-room behavior.
- [ ] Verify each burnable bush.

### Task 4.4: Recorder / Whirlwind / Warp

- [ ] Extract recorder-trigger room rules.
- [ ] Add recorder item use.
- [ ] Add tune/audio trigger.
- [ ] Add room-specific entrance reveal where applicable.
- [ ] Add whirlwind spawn.
- [ ] Add warp route order.
- [ ] Add Link pickup by whirlwind.
- [ ] Add destination placement.
- [ ] Verify dungeon 7 reveal.
- [ ] Verify warp cycle.

### Task 4.5: Raft

- [ ] Extract raft dock metadata.
- [ ] Detect raft dock trigger.
- [ ] Check raft inventory.
- [ ] Lock player control during raft movement.
- [ ] Move Link along NES route.
- [ ] Transition room if route crosses edge.
- [ ] End movement at destination.
- [ ] Verify all raft routes.

### Task 4.6: Ladder

- [ ] Extract water tile classifications.
- [ ] Check ladder inventory.
- [ ] Permit crossing one-tile water gaps.
- [ ] Render ladder sprite/tile if NES does.
- [ ] Prevent invalid water traversal.
- [ ] Verify overworld ladder crossings.
- [ ] Verify dungeon ladder crossings in Phase 5 Task 5.2 after UW collision is active.

### Task 4.7: Lost Woods / Lost Hills

- [ ] Extract routing rules.
- [ ] Detect wrong exit sequence.
- [ ] Redirect to NES room.
- [ ] Detect correct sequence.
- [ ] Allow progression.
- [ ] Add Redux option hook for "Not Lost".
- [ ] Verify NES mode.
- [ ] Verify option mode.

### Task 4.8: Overworld Pickups

- [ ] Implement heart container pickup.
- [ ] Implement rupee pickup.
- [ ] Implement potion/letter-dependent cave pickup rules.
- [ ] Implement item disappearance after collection.
- [ ] Persist collected flags.
- [ ] Verify state across room transitions.
- [ ] Verify state across save/load after Phase 9.

### Task 4.9: Overworld Full Matrix

- [ ] Generate list of all 128 overworld rooms.
- [ ] For each room, assert render parity still holds.
- [ ] For each room, assert collision map exists.
- [ ] For each secret room, assert reveal action works.
- [ ] For each traversal room, assert item-specific traversal works.
- [ ] Archive screenshots/diffs.
- [ ] Commit as `roomrom: implement overworld secrets and traversal`.

---

## Phase 5: Dungeon Core

**Goal:** Make dungeons fully navigable and stateful before enemy/boss completion.

### Task 5.1: Dungeon State Model

- [ ] Add `src/state/room_state.h` fields for dungeon.
- [ ] Track current level.
- [ ] Track current quest.
- [ ] Track current room id.
- [ ] Track door state per dungeon room.
- [ ] Track room-clear state.
- [ ] Track push-block state.
- [ ] Track key doors opened.
- [ ] Track map/compass/triforce item state.
- [ ] Track dark-room lit state.
- [ ] Add RoomRom bridge state until promotion.

### Task 5.2: Dungeon Collision

- [ ] Expose UW collision grid from renderer.
- [ ] Classify walls.
- [ ] Classify water.
- [ ] Classify blocks.
- [ ] Classify doors.
- [ ] Classify stairs.
- [ ] Classify sand/normal floor.
- [ ] Add per-axis Link collision.
- [ ] Verify Level 1 rooms.
- [ ] Verify all levels smoke.

### Task 5.3: Door System

- [ ] Extract door metadata from UW JSON/manifests.
- [ ] Implement open doors.
- [ ] Implement shutter doors.
- [ ] Implement locked doors.
- [ ] Implement bombable doors.
- [ ] Implement boss doors.
- [ ] Implement walk-through walls where applicable.
- [ ] Render door state.
- [ ] Change collision by door state.
- [ ] Persist opened locked/bombed doors.
- [ ] Verify each door type.

### Task 5.4: Dungeon Room Transitions

- [ ] Replace all-open S4 edge logic in UW with door-aware transition rules.
- [ ] Block walls.
- [ ] Allow open door exits.
- [ ] Consume key on locked door.
- [ ] Open shutter doors after room clear.
- [ ] Place Link at NES entry coordinate.
- [ ] Render scroll/blank transition.
- [ ] Verify Level 1 route.

### Task 5.5: Stairs And Passages

- [ ] Extract stair metadata.
- [ ] Detect stair tile.
- [ ] Trigger stair entry.
- [ ] Render passage/cellar.
- [ ] Move Link through passage.
- [ ] Exit to paired room.
- [ ] Handle item cellar.
- [ ] Verify each stair/passage type.

### Task 5.6: Push Blocks

- [ ] Extract push-block rooms.
- [ ] Detect push direction.
- [ ] Require correct side/direction.
- [ ] Animate block movement.
- [ ] Update collision/render state.
- [ ] Trigger stairs/door if applicable.
- [ ] Persist room state.
- [ ] Verify all push-block cases.

### Task 5.7: Dark Rooms

- [ ] Extract dark room flags.
- [ ] Render dark mask.
- [ ] Check candle/lit state.
- [ ] Add option hook for dark-room light.
- [ ] Reveal room on candle use.
- [ ] Persist lit state as NES does.
- [ ] Verify dark rooms in NES mode and option mode.

### Task 5.8: Keys, Map, Compass, Triforce

- [ ] Implement key pickup.
- [ ] Implement key counter.
- [ ] Implement locked-door key consumption.
- [ ] Implement map item pickup.
- [ ] Implement compass pickup.
- [ ] Implement dungeon map display effects.
- [ ] Implement triforce pickup transition.
- [ ] Verify Level 1 completion flow.

### Task 5.9: Dungeon Matrix Verification

- [ ] Render every room in all 9 dungeons, both quests.
- [ ] Verify tile layout.
- [ ] Verify palette.
- [ ] Verify doors.
- [ ] Verify collision.
- [ ] Verify stairs/passages.
- [ ] Verify stateful room mutations.
- [ ] Commit as `roomrom: implement dungeon core`.

---

## Phase 6: Link, Inventory, Items, And Combat

**Goal:** Complete player behavior and all usable item mechanics.

### Task 6.1: Promote Link State Names

- [ ] Finalize `src/state/link_state.h`.
- [ ] Add position fields.
- [ ] Add subpixel/step fields.
- [ ] Add direction/facing.
- [ ] Add action state.
- [ ] Add animation frame/timer.
- [ ] Add invincibility timer.
- [ ] Add damage/knockback state.
- [ ] Add item-use state.
- [ ] Add death state.
- [ ] Replace raw RoomRom globals with state struct access.

### Task 6.2: NES-Faithful Movement

- [ ] Verify walking speed.
- [ ] Verify axis priority.
- [ ] Verify grid alignment.
- [ ] Verify room-edge transitions.
- [ ] Verify cave/dungeon/stair movement.
- [ ] Verify knockback movement.
- [ ] Add canonical movement probes.
- [ ] Keep ALTTP/free movement as option mode only.

### Task 6.3: Sword

- [ ] Implement stab state.
- [ ] Implement sword hitbox.
- [ ] Implement animation timing.
- [ ] Implement sword beam at full health.
- [ ] Implement beam collision.
- [ ] Implement beam despawn.
- [ ] Implement Redux sword arc option.
- [ ] Implement diagonal sword option only if selected.
- [ ] Verify NES sword behavior.
- [ ] Verify Redux option behavior separately.

### Task 6.4: Boomerang

- [ ] Implement wooden boomerang range.
- [ ] Implement magic boomerang range.
- [ ] Implement outbound movement.
- [ ] Implement return movement.
- [ ] Implement pickup/catch.
- [ ] Implement stun behavior.
- [ ] Implement item pickup interaction if NES supports.
- [ ] Verify against NES capture.

### Task 6.5: Bombs

- [ ] Implement bomb placement.
- [ ] Implement bomb timer.
- [ ] Implement explosion animation.
- [ ] Implement enemy damage.
- [ ] Implement wall reveal collision.
- [ ] Implement bomb count decrement.
- [ ] Implement bomb upgrade option.
- [ ] Verify overworld and dungeon use.

### Task 6.6: Bow And Arrows

- [ ] Implement bow requirement.
- [ ] Implement arrow item requirement.
- [ ] Implement rupee cost if NES mode.
- [ ] Implement projectile movement.
- [ ] Implement enemy damage.
- [ ] Implement silver arrow state.
- [ ] Verify Gohma interaction in Phase 8 Task 8.7.

### Task 6.7: Candle

- [ ] Implement blue candle use limit.
- [ ] Implement red candle unlimited use.
- [ ] Implement flame projectile/entity.
- [ ] Implement bush burn.
- [ ] Implement enemy damage.
- [ ] Implement dark-room light.
- [ ] Verify overworld and dungeon cases.

### Task 6.8: Recorder

- [ ] Implement recorder use state.
- [ ] Implement audio trigger.
- [ ] Implement whirlwind/warp.
- [ ] Implement Digdogger split in Phase 8 Task 8.6.
- [ ] Implement Pols Voice option behavior in Phase 7 Task 7.5.
- [ ] Verify overworld trigger.

### Task 6.9: Wand, Book, Bait, Potion, Letter, Rings, Shields

- [ ] Implement wand projectile.
- [ ] Implement book flame spawn.
- [ ] Implement bait placement and consumption.
- [ ] Implement potion heal and consumption.
- [ ] Implement letter shop unlock.
- [ ] Implement ring damage reduction.
- [ ] Implement magic shield projectile block.
- [ ] Implement Like Like shield/rupee behavior hook.
- [ ] Verify each item with a canonical probe.

### Task 6.10: Inventory And Pause

- [ ] Implement inventory state.
- [ ] Implement item acquisition.
- [ ] Implement B-item selection.
- [ ] Implement pause subscreen render.
- [ ] Implement cursor movement.
- [ ] Implement map view.
- [ ] Implement manual save as an option-controlled pause/subscreen command.
- [ ] Verify pause screen parity.

### Task 6.11: Damage, Death, And Drops

- [ ] Implement Link-enemy collision.
- [ ] Implement enemy-projectile collision.
- [ ] Implement damage values.
- [ ] Implement invincibility frames.
- [ ] Implement knockback.
- [ ] Implement heart decrement.
- [ ] Implement death animation.
- [ ] Implement drop spawn and pickup.
- [ ] Implement auto-collect option.
- [ ] Verify combat smoke.
- [ ] Commit as `gameplay: complete link inventory and item combat`.

---

## Phase 7: Enemies By Behavior Family

**Goal:** Implement all non-boss enemies with family-level probes and shared behavior modules.

### Task 7.1: Enemy Framework

- [ ] Finalize `src/state/enemy_state.h`.
- [ ] Define enemy slots.
- [ ] Define enemy type enum.
- [ ] Define enemy action states.
- [ ] Define spawn metadata.
- [ ] Define RNG interface.
- [ ] Define movement helpers.
- [ ] Define collision helpers.
- [ ] Define render helper interface.
- [ ] Define death/drop hook.
- [ ] Add room enemy loader.
- [ ] Add per-room spawn rules.
- [ ] Add enemy clear tracking.

### Task 7.2: Walker Family

- [ ] Implement octorok.
- [ ] Implement moblin.
- [ ] Implement stalfos.
- [ ] Implement goriya walking.
- [ ] Implement darknut base walking if non-boss.
- [ ] Add projectile hook where needed.
- [ ] Probe movement and collision.
- [ ] Probe damage/death/drop.
- [ ] Commit family.

### Task 7.3: Flyer / Jumper Family

- [ ] Implement keese.
- [ ] Implement peahat.
- [ ] Implement vire.
- [ ] Implement gel.
- [ ] Implement zol split.
- [ ] Implement rope rush if grouped here.
- [ ] Probe each behavior.
- [ ] Commit family.

### Task 7.4: Projectile Enemy Family

- [ ] Implement rock spawns.
- [ ] Implement moblin arrows.
- [ ] Implement octorok rocks.
- [ ] Implement wizzrobe beams.
- [ ] Implement zora fireballs.
- [ ] Implement statue fireballs.
- [ ] Implement projectile collision with shield/Link.
- [ ] Probe each projectile class.
- [ ] Commit family.

### Task 7.5: Special Enemy Family

- [ ] Implement like-like.
- [ ] Implement bubble.
- [ ] Implement wallmaster.
- [ ] Implement pols voice.
- [ ] Implement gibdo if not walker.
- [ ] Implement vire split behavior.
- [ ] Implement shield consumption or rupee option.
- [ ] Probe each special behavior.
- [ ] Commit family.

### Task 7.6: Aquatic / Terrain Family

- [ ] Implement zora.
- [ ] Implement tektite.
- [ ] Implement leevers.
- [ ] Implement water/terrain constraints.
- [ ] Probe each terrain behavior.
- [ ] Commit family.

### Task 7.7: Enemy Room Matrix

- [ ] Load enemy tables for all overworld rooms.
- [ ] Load enemy tables for all dungeon rooms.
- [ ] Verify enemy count per room.
- [ ] Verify spawn positions.
- [ ] Verify no enemy stuck at invalid coordinates.
- [ ] Verify room clear opens shutter doors.
- [ ] Verify drops.
- [ ] Commit as `gameplay: complete enemy families`.

---

## Phase 8: Bosses

**Goal:** Implement every boss with independent AI, render, damage, and room-clear probes.

### Task 8.1: Boss Framework

- [ ] Define boss state extension.
- [ ] Define boss room metadata.
- [ ] Define multi-sprite render support.
- [ ] Define boss damage routing.
- [ ] Define boss death animation.
- [ ] Define boss room clear event.
- [ ] Define heart container/triforce spawn.

### Task 8.2: Aquamentus

- [ ] Implement movement.
- [ ] Implement fireball pattern.
- [ ] Implement hitbox.
- [ ] Implement death.
- [ ] Probe Level 1 boss.
- [ ] Commit.

### Task 8.3: Dodongo

- [ ] Implement movement.
- [ ] Implement bomb swallow/stun rules.
- [ ] Implement damage/death.
- [ ] Probe.
- [ ] Commit.

### Task 8.4: Manhandla

- [ ] Implement body/heads.
- [ ] Implement movement speed changes.
- [ ] Implement bomb/sword damage.
- [ ] Probe.
- [ ] Commit.

### Task 8.5: Gleeok

- [ ] Implement 2/3/4 head variants.
- [ ] Implement detached head behavior.
- [ ] Implement fireballs.
- [ ] Probe.
- [ ] Commit.

### Task 8.6: Digdogger

- [ ] Implement main behavior.
- [ ] Implement recorder split/shrink.
- [ ] Implement child behavior.
- [ ] Probe.
- [ ] Commit.

### Task 8.7: Gohma

- [ ] Implement eye state.
- [ ] Implement projectile behavior.
- [ ] Implement arrow-only damage.
- [ ] Probe.
- [ ] Commit.

### Task 8.8: Patra

- [ ] Implement orbiting children.
- [ ] Implement core vulnerability.
- [ ] Implement movement.
- [ ] Probe.
- [ ] Commit.

### Task 8.9: Moldorm / Lanmola

- [ ] Implement segmented body.
- [ ] Implement movement.
- [ ] Implement segment damage.
- [ ] Probe.
- [ ] Commit.

### Task 8.10: Ganon

- [ ] Implement invisibility.
- [ ] Implement movement/teleport.
- [ ] Implement hit rules.
- [ ] Implement silver arrow final state.
- [ ] Implement triforce/Zelda rescue transition.
- [ ] Probe.
- [ ] Commit.

### Task 8.11: Boss Matrix

- [ ] Verify every boss room can load.
- [ ] Verify every boss can be killed.
- [ ] Verify room clear state.
- [ ] Verify rewards.
- [ ] Verify no sprite overflow failure.
- [ ] Commit as `gameplay: complete bosses`.

---

## Phase 9: HUD, Options, Save, Menus

**Goal:** Complete user-facing state, persistence, pause/menu systems, and Redux options.

### Task 9.1: Options Runtime

- [ ] Create `src/game/options/options_state.h`.
- [ ] Create `src/game/options/options_runtime.c/h`.
- [ ] Define option ids.
- [ ] Define default values.
- [ ] Define getters.
- [ ] Define setters.
- [ ] Define enum/radio value validation.
- [ ] Define version.
- [ ] Define migration behavior.
- [ ] Add tests for defaults and migration.

### Task 9.2: SRAM Persistence

- [ ] Use locked SRAM range `0x800-0x81F` for OptionsState unless existing implementation has moved under a documented migration.
- [ ] Preserve save slots `0x000-0x7FF`.
- [ ] Add checksum.
- [ ] Detect invalid zero/all-FF options.
- [ ] Load defaults without corrupting save slots.
- [ ] Commit options independently.
- [ ] Add power-cycle probe.

### Task 9.3: File Select Options Menu

- [ ] Render OPTIONS submenu.
- [ ] Add categories.
- [ ] Add cursor with header skip.
- [ ] Add toggles.
- [ ] Add radio rows.
- [ ] Add SAVE row.
- [ ] Add B commit.
- [ ] Persist options.
- [ ] Verify all rows.

### Task 9.4: Wire Option Consumers

- [ ] Wire low health warning.
- [ ] Wire automap.
- [ ] Wire dungeon colors.
- [ ] Wire visible secrets.
- [ ] Wire sword style.
- [ ] Wire diagonal sword.
- [ ] Wire like-like behavior.
- [ ] Wire bomb upgrade amount.
- [ ] Wire start hearts.
- [ ] Wire lost woods behavior.
- [ ] Wire no/reduced flashing.
- [ ] Wire dark-room light.
- [ ] Wire A/B swap.
- [ ] Wire auto-collect drops.
- [ ] For every option, add a probe or screenshot gate.

### Task 9.5: Native HUD

- [ ] Render hearts.
- [ ] Render rupees.
- [ ] Render bombs.
- [ ] Render keys.
- [ ] Render selected B item.
- [ ] Render A item/sword.
- [ ] Render overworld map indicator.
- [ ] Render dungeon map/compass effects.
- [ ] Render triforce pieces.
- [ ] Add HUD style option.
- [ ] Verify static and animated HUD states.

### Task 9.6: Pause And Subscreen

- [ ] Render inventory subscreen.
- [ ] Render item cursor.
- [ ] Implement item selection.
- [ ] Implement map display.
- [ ] Implement manual save.
- [ ] Implement options access from pause.
- [ ] Verify parity.

### Task 9.7: Save / Death / Continue

- [ ] Implement save slot serialization.
- [ ] Implement save checksum if NES uses it.
- [ ] Implement death sequence.
- [ ] Implement continue prompt.
- [ ] Implement save-and-quit.
- [ ] Implement game over to file select.
- [ ] Verify save/load.
- [ ] Verify old saves remain loadable.
- [ ] Commit as `frontend: complete options save and hud systems`.

---

## Phase 10: Audio Finalization

**Goal:** Make all music and SFX correct, option-aware, and VBlank-safe.

### Task 10.1: Lock Driver

- [ ] Compare current custom driver vs SGDK XGM/XGM2.
- [ ] Pick the path with best long-term maintainability and fidelity.
- [ ] Keep C-facing audio adapter stable.
- [ ] Document driver decision.

### Task 10.2: Builder Audio Extraction

- [ ] Ensure title music data comes from legal extraction or authored transformation.
- [ ] Ensure overworld music.
- [ ] Ensure dungeon music.
- [ ] Ensure cave/item/ending music.
- [ ] Ensure SFX data.
- [ ] Add generated audio manifest.
- [ ] Add package check for generated audio.

### Task 10.3: Wire Music Events

- [ ] Title.
- [ ] Story/intro.
- [ ] File select silent/default.
- [ ] Overworld.
- [ ] Dungeon.
- [ ] Cave.
- [ ] Boss.
- [ ] Death.
- [ ] Ending.
- [ ] Option-controlled dungeon music variant.

### Task 10.4: Wire SFX Events

- [ ] Sword.
- [ ] Sword beam.
- [ ] Boomerang.
- [ ] Bomb place.
- [ ] Explosion.
- [ ] Enemy hit.
- [ ] Enemy death.
- [ ] Item pickup.
- [ ] Rupee.
- [ ] Heart.
- [ ] Door unlock.
- [ ] Secret reveal.
- [ ] Low health warning.
- [ ] Boss sounds.

### Task 10.5: Verify Audio

- [ ] Run audio event log probes for every discrete SFX and music transition event.
- [ ] Run VBlank budget probe with dense audio.
- [ ] Run manual listening checklist.
- [ ] Test low health option values.
- [ ] Commit as `audio: finalize music and sfx integration`.

---

## Phase 11: Title.md Frontend Completion

**Goal:** Finish the release-facing frontend target before final gameplay merge.

### Task 11.1: Title Loop

- [ ] Verify title render.
- [ ] Verify title sprites.
- [ ] Verify palette glow.
- [ ] Verify waterfall/animation.
- [ ] Verify Start input.
- [ ] Verify no frame stalls.

### Task 11.2: Intro Story

- [ ] Verify title fade.
- [ ] Verify story scroll.
- [ ] Verify item showcase.
- [ ] Verify loop back to title.
- [ ] Verify Start exits from every phase.
- [ ] Verify assets generated by builder.

### Task 11.3: File Select

- [ ] Complete static render.
- [ ] Complete cursor navigation.
- [ ] Complete occupied/empty slot rendering.
- [ ] Complete PLAYERS row.
- [ ] Complete OPTIONS row.
- [ ] Complete copy flow.
- [ ] Complete erase flow.
- [ ] Complete saved slot start.
- [ ] Complete empty slot name entry.
- [ ] Complete register-name handoff.

### Task 11.4: Frontend Probes

- [ ] `title_idle`.
- [ ] `title_to_file_select`.
- [ ] `intro_story_page_1`.
- [ ] `intro_story_loop`.
- [ ] `fs_fresh_cursor`.
- [ ] `fs_cursor_wrap`.
- [ ] `fs_players_cycle`.
- [ ] `fs_options_persist`.
- [ ] `fs_copy_cancel`.
- [ ] `fs_copy_confirm`.
- [ ] `fs_erase_cancel`.
- [ ] `fs_erase_confirm`.
- [ ] `fs_name_entry_create`.
- [ ] `fs_registered_file_start`.
- [ ] Commit as `frontend: close Title.md frontend`.

---

## Phase 12: Promote RoomRom Core And Integrate Final ROM

**Goal:** Combine proven gameplay core with Title.md while keeping RoomRom as a harness.

### Task 12.1: Module Ownership Audit

- [ ] List every `RoomRom/src/*.c`.
- [ ] Mark harness-only files.
- [ ] Mark shared gameplay files.
- [ ] Mark generated asset files.
- [ ] Mark obsolete debug files.
- [ ] Save audit to `docs/audit/roomrom_promotion_audit.md`.

### Task 12.2: Move Shared Gameplay Modules

- [ ] Create `src/game/room/`.
- [ ] Create `src/game/link/`.
- [ ] Create `src/game/cave/`.
- [ ] Create `src/game/dungeon/`.
- [ ] Create `src/game/items/`.
- [ ] Create `src/game/combat/`.
- [ ] Create `src/game/enemies/`.
- [ ] Create `src/game/bosses/`.
- [ ] Create `src/game/hud/`.
- [ ] Move shared modules one family at a time.
- [ ] Leave wrapper headers in RoomRom for modules that remain included by the RoomRom harness after promotion.
- [ ] Build RoomRom after each family move.
- [ ] Build Title.md after each family move when linked.

### Task 12.3: Shared State Conversion

- [ ] Replace RoomRom globals with `src/state` structs.
- [ ] Add initialization from save slot.
- [ ] Add options pointer/context.
- [ ] Add player count.
- [ ] Add current mode.
- [ ] Add scene transition state.
- [ ] Verify RoomRom still direct-boots with synthetic state.

### Task 12.4: Introduce Final Target

- [ ] Add `Final.md` build output.
- [ ] Link Title frontend.
- [ ] Link shared gameplay core.
- [ ] Link save/options/audio adapters.
- [ ] Add mode dispatcher.
- [ ] Add file-select to gameplay handoff.
- [ ] Add gameplay to file-select/game-over handoff.
- [ ] Add final ROM probes.

### Task 12.5: Cross-Target Verification

- [ ] Run RoomRom gameplay probes.
- [ ] Run Title.md frontend probes.
- [ ] Run Final.md boot-to-gameplay probe.
- [ ] Run Final.md cave probe.
- [ ] Run Final.md dungeon Level 1 probe.
- [ ] Run Final.md save/load probe.
- [ ] Commit as `build: integrate final rom target`.

---

## Phase 13: Optional 4-Player Genesis Mode

**Goal:** Add 2-4 player support as an optional Genesis-enhanced mode isolated from NES-faithful 1-player.

### Task 13.1: Generalize Player State

- [ ] Change `LinkState` to `PlayerState`.
- [ ] Add `PlayerState players[4]`.
- [ ] Preserve 1-player behavior through accessors and probes even though `players[0]` becomes part of a four-player array.
- [ ] Add active player count.
- [ ] Add player spawn positions.
- [ ] Add per-player input state.
- [ ] Verify 1-player probes unchanged.

### Task 13.2: Input Adapter

- [ ] Detect controller 1.
- [ ] Detect controller 2.
- [ ] Add support for multitap/teamplayer if target hardware support is retained.
- [ ] Map inputs per player.
- [ ] Add A/B swap option per player or global.
- [ ] Verify no 1-player input regression.

### Task 13.3: Render Extra Players

- [ ] Allocate sprite tiles/palettes for P2-P4.
- [ ] Pick tunic colors within Genesis palette limits.
- [ ] Render P2.
- [ ] Render P3.
- [ ] Render P4.
- [ ] Add sprite budget verifier.
- [ ] Verify no enemy/boss sprite starvation in 1-player.

### Task 13.4: Multiplayer Rules

- [ ] Shared inventory model.
- [ ] Shared rupees/bombs/keys.
- [ ] Per-player hearts or shared hearts decision under PrimeDirective: per-player hearts for playability, shared progression for simplicity.
- [ ] Same-room constraint.
- [ ] Screen transition when lead player exits.
- [ ] Pull trailing players to valid entry positions.
- [ ] Disable friendly collision by default.
- [ ] Define revive/death behavior.
- [ ] Add multiplayer-specific probes.

### Task 13.5: Multiplayer Combat

- [ ] Multiple swords.
- [ ] Multiple item uses with cooldown/resource rules.
- [ ] Enemy targeting update.
- [ ] Boss targeting update.
- [ ] Drop pickup rules.
- [ ] Verify VBlank and sprite budget.
- [ ] Commit as `gameplay: add optional multiplayer mode`.

---

## Phase 14: Full Quest Completion

**Goal:** Prove the game is complete end-to-end.

### Task 14.1: First Quest Route

- [ ] Define canonical first quest route.
- [ ] Create input/movie segments or manual checklist per dungeon.
- [ ] Start new file.
- [ ] Get sword.
- [ ] Clear dungeons 1-8.
- [ ] Obtain required items.
- [ ] Enter dungeon 9.
- [ ] Defeat Ganon.
- [ ] Rescue Zelda.
- [ ] Reach ending.
- [ ] Save reports.

### Task 14.2: Second Quest Route

- [ ] Trigger second quest.
- [ ] Define route.
- [ ] Verify changed overworld entrances.
- [ ] Verify changed dungeons.
- [ ] Clear all required dungeons.
- [ ] Defeat Ganon.
- [ ] Reach ending.
- [ ] Save reports.

### Task 14.3: Completion Matrix

- [ ] Visit every overworld room.
- [ ] Visit every cave.
- [ ] Visit every dungeon room.
- [ ] Collect every item.
- [ ] Defeat every enemy family.
- [ ] Defeat every boss.
- [ ] Exercise every save/load/death path.
- [ ] Exercise every option at least once.
- [ ] Smoke 4-player mode.
- [ ] Commit as `release: complete quest verification`.

---

## Phase 15: Hardware, Performance, And Polish

**Goal:** Make the final ROM reliable on hardware and comfortable to play.

### Task 15.1: Performance Gates

- [ ] Add per-frame CPU budget measurement.
- [ ] Add VBlank DMA budget measurement.
- [ ] Add sprite count measurement.
- [ ] Add audio tick measurement.
- [ ] Add worst-case enemy/boss room tests.
- [ ] Optimize only measured hot spots.

### Task 15.2: Hardware Tests

- [ ] Test on real Genesis/Mega Drive.
- [ ] Test with flash cart.
- [ ] Test SRAM persistence.
- [ ] Test reset behavior.
- [ ] Test controller combinations.
- [ ] Record hardware notes.

### Task 15.3: Emulator Matrix

- [ ] BizHawk/GPGX.
- [ ] BlastEm.
- [ ] Genesis Plus GX standalone.
- [ ] Flash cart runtime used for final hardware smoke.
- [ ] Record differences.

### Task 15.4: Accessibility And Safety

- [ ] No/reduced flashing option verified.
- [ ] Low health warning options verified.
- [ ] Control swap verified.
- [ ] Text speed option verified if implemented.
- [ ] Document photosensitivity option.

### Task 15.5: Polish Pass

- [ ] Audit naming.
- [ ] Remove dead debug code from release build.
- [ ] Keep debug build diagnostics.
- [ ] Remove obsolete aliases if all probes migrated.
- [ ] Ensure `RoomRom` still builds.
- [ ] Ensure `Title.md` still builds.
- [ ] Ensure `Final.md` builds.
- [ ] Commit as `release: hardware and polish pass`.

---

## Phase 16: Public Builder Release

**Goal:** Ship the project as a legal builder, not a copyrighted-asset ROM package.

### Task 16.1: Clean Public Package

- [ ] Define release package contents.
- [ ] Include source code.
- [ ] Include extraction scripts.
- [ ] Include build scripts.
- [ ] Include docs.
- [ ] Include tests that do not require bundled ROM assets.
- [ ] Exclude generated Nintendo-derived assets.
- [ ] Exclude `.nes` files.
- [ ] Exclude `.ips` files unless license permits.
- [ ] Exclude private screenshots/videos if they contain copyrighted frames and are not needed.
- [ ] Run package checker.

### Task 16.2: Builder UX

- [ ] Drag NES ROM onto builder.
- [ ] Validate ROM.
- [ ] Extract assets.
- [ ] Build final ROM.
- [ ] Show output path.
- [ ] Write manifest.
- [ ] Show unsupported ROM error clearly.
- [ ] Show missing dependency error clearly.
- [ ] Keep logs for troubleshooting.

### Task 16.3: From-Scratch Build Gate

- [ ] Clone clean public package.
- [ ] Confirm no generated asset cache.
- [ ] Run builder with valid NES ROM.
- [ ] Confirm generated cache appears locally.
- [ ] Confirm final `.md` appears.
- [ ] Confirm final ROM hash recorded.
- [ ] Run smoke probe.
- [ ] Delete cache.
- [ ] Repeat to prove reproducibility.

### Task 16.4: Release Documentation

- [ ] User build instructions.
- [ ] Supported ROM hash.
- [ ] Optional Redux input instructions.
- [ ] Troubleshooting.
- [ ] Legal note: user must supply their own ROM.
- [ ] Contributor guide: do not commit generated copyrighted assets.
- [ ] Verification guide.

### Task 16.5: Final Release Gate

- [ ] Run package checker.
- [ ] Run from-scratch builder gate.
- [ ] Run full quest smoke.
- [ ] Run hardware smoke.
- [ ] Tag release.
- [ ] Archive final build manifest.
- [ ] Commit as `release: package legal builder`.

---

## Cross-Cutting Workstreams

### Workstream A: Probe Infrastructure

- [ ] Normalize NES captures into a common schema.
- [ ] Normalize Genesis captures into the same schema.
- [ ] Keep screenshot comparison for visual gates.
- [ ] Keep state diff for behavior gates.
- [ ] Keep CRAM/SAT/plane dumps for graphics gates.
- [ ] Every new subsystem gets a probe before it is called complete.

### Workstream B: Data Extraction

- [ ] Every table used by gameplay has a deterministic extractor.
- [ ] Every extractor writes manifest hashes.
- [ ] Every extractor cites NES disassembly or ROM offsets.
- [ ] Every generated file can be rebuilt from user ROM.
- [ ] Public package excludes generated outputs.

### Workstream C: State Naming

- [ ] Expand `src/state/link_state.h`.
- [ ] Expand `src/state/room_state.h`.
- [ ] Expand `src/state/cave_state.h`.
- [ ] Expand `src/state/enemy_state.h`.
- [ ] Expand `src/state/item_state.h`.
- [ ] Expand `src/state/save_state.h`.
- [ ] Expand `src/state/world_state.h`.
- [ ] Eliminate raw magic offsets from owned code.

### Workstream D: Option Wiring

- [ ] Every option has a storage byte/bit.
- [ ] Every option has a UI row if user-facing.
- [ ] Every option has a consumer.
- [ ] Every option has a default.
- [ ] Every option has a migration behavior.
- [ ] Every option has a verification gate.

### Workstream E: Release Hygiene

- [ ] No generated copyrighted data in public package.
- [ ] No hardcoded local absolute paths in release scripts.
- [ ] No stale `whatif` references in active docs after Phase 0.
- [ ] No RoomRom-only gameplay fork after Phase 12.
- [ ] No old generated-bank dependencies after final integration.

---

## Current Next Action

- [ ] Finish Phase 2 graphics registry work already in progress in the RoomRom worktree.
- [ ] Then implement Phase 3 Overworld Caves.
- [ ] Keep this master plan updated only when phase order changes; do not turn it into a scratch log.

## Self-Review

- [x] Covers target split.
- [x] Covers legal builder path.
- [x] Covers graphics no-clobber foundation before caves.
- [x] Covers caves immediately after current work.
- [x] Covers overworld, dungeon, Link/items/combat, enemies, bosses, HUD/options/save, audio, frontend, integration, multiplayer, completion, hardware, and release.
- [x] Leaves no phase without verification.
- [x] Keeps 4-player mode isolated from NES parity.
- [x] Requires child plans before code-level implementation.
