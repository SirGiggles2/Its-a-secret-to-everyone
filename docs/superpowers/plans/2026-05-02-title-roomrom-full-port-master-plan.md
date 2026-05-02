# Title.md + RoomRom Full Zelda Port Master Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement each phase task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the full Sega Genesis Zelda port through a legally distributable builder that extracts assets from a user-supplied NES ROM.

**Architecture:** Keep `Title.md` and `RoomRom.md` separate until the gameplay core is verified. Promote proven RoomRom systems into shared `src/game/` modules, keep frontend under `src/frontend/`, and make all generated Nintendo-derived assets reproducible from a user-supplied NES ROM through `tools/builder/`.

**Tech Stack:** SGDK/m68k GCC, BizHawk Lua probes, Python asset extractors/generators/verifiers, PowerShell/Batch build launchers, C gameplay/runtime modules, Genesis `.md` output.

---

## Execution Rules

- [ ] Treat `$PrimeDirective` as the decision rule for every unresolved choice: best long-term outcome, maximal efficiency, best coding practices, NES accuracy first, Genesis-native implementation, and task shapes that fit Codex + Claude (Coding CLIs) strengths.
- [ ] Do not ask for option selection unless a destructive or external publishing action is required.
- [ ] Keep `RoomRom` as the fast gameplay harness and `Title.md` as the frontend/release harness until Phase 12.
- [ ] Before editing or building `RoomRom`, run `git worktree list` and use `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1` for active RoomRom work. This encodes memory rule `feedback_check_worktree_first`.
- [ ] Never hand-edit generated assets as the permanent solution.
- [ ] Never add Nintendo-derived generated data to the public release package.
- [ ] Every major phase gets its own child spec and child implementation plan before code changes.
- [ ] Execute child implementation plans with `superpowers:executing-plans`.
- [ ] Use `superpowers:subagent-driven-development` when a child plan has independent implementation slices.
- [ ] Every code phase closes with build, probe, screenshot/state evidence, `superpowers:requesting-code-review`, and an atomic commit.
- [ ] Keep 1-player NES parity protected. Redux options and 4-player mode are option-driven divergence only.
- [ ] State contract is binding: typed C structs for owned modules, NES RAM mirror layer for transpiled code only. See `docs/audit/state_contract.md`. No new `RAM()`/`OBJ()` macros in owned C.
- [ ] Tier-1 contracts gate (Phase 1.5 NES capture harness, Task 0.6 worktree merge protocol, Task 1.11 strict generated-only build, Task 2.0 state contract audit) MUST be green before any feature phase (3+) touches code.
- [ ] **Rule SGDK-1 (Adapter Boundary).** Code under `src/game/` and `src/frontend/` MUST NOT `#include <genesis.h>` (or any SGDK public header) and MUST NOT write Genesis hardware registers directly. All Genesis hardware access routes through `src/sgdk_adapter/`. Per-directory whitelist defined in `tools/check_adapter_boundary.py` and `tools/check_raw_vdp.py`. Build hard-fails on violation.
- [ ] **Rule SGDK-2 (Version Pin).** SGDK submodule SHA is pinned in `tools/sgdk_pin.json`. The reasoning lives in `docs/sgdk_audit.md`. `build.bat` hard-fails when the submodule HEAD diverges from the pin. Bumps require: (a) `--accept-sgdk-bump` flag, (b) updated `docs/sgdk_audit.md`, (c) regenerated parity oracle baselines, (d) regenerated `Final.md` checksum — all in one commit.
- [ ] **Rule SGDK-3 (Hand-Rolled VDP).** Default to SGDK API for all Genesis hardware. Raw VDP register writes outside boot/shim/adapter require: profiled hot path, ≥15% measured cycle/frame or bandwidth improvement, inline citation of the SGDK call replaced, entry in `docs/handrolled_vdp.md`, adapter unit-test coverage.
- [ ] **Rule SGDK-4 (Audio Migration Trigger).** Custom driver is the default. XGM2 migration of any audio subsystem (or whole-driver flip) requires ADR approval, triggered by ANY 2 of the following firing within a rolling 90-day window: (a) `audio_tick` >10% frame budget, (b) parity-oracle song failure surviving 1 debug cycle, (c) driver footprint >8KB, (d) ≥3 unfixable `audio-parity` issues open >30d. Documented in `docs/audio_migration_trigger.md`.
- [ ] **Rule SGDK-5 (Fork Policy).** Project owner is the sole decision-maker for forking SGDK. Qualifying conditions: security CVE (no upstream patch 14d), parity blocker (upstream rejected/stalled 30d), reproducibility break (upstream refuses fix), build-breaker (no upstream response 14d). Patch must be <200 LOC and touch no SGDK public ABI. Performance alone is not fork-worthy — hand-roll behind the adapter under Rule SGDK-3 instead. Fork lives at `vendor/sgdk-fork/` with `PATCHES/`; every release attempts clean rebase against upstream and auto-PRs un-fork on success.

## Phase Close Gate

Every implementation phase closes in this exact order:

1. Build the touched target with `REQUIRE_GENERATED_ASSETS=1` (Task 1.11 strict gate).
2. Run the focused probe set.
3. Capture screenshot/state evidence; emit a parity-oracle-schema instance per probe (Task 2.8).
4. Diff each schema instance against the matching `build/generated/nes_reference/` capture (Phase 1.5).
5. Run `tools/run_regression_matrix.py`; require green (Workstream F).
6. Run `tools/state/verify_no_alias_collisions.py --scope <subsystems>` if the phase touched `src/state/` (Workstream G). The `--scope` list names the subsystems being promoted in this phase (e.g. `vram_map,palette` for Phase 2; `enemy` for Phase 7). Out-of-scope collisions are reported as INFO and deferred to their owning phase per `docs/audit/state_contract.md` migration order. Use `--strict-all` for the Phase 12 promotion gate (then everything must be green).
7. Confirm per-subsystem `PROBE_CYCLE_LIMIT` envelope was not exceeded (Workstream F cycle gate).
8. Run `superpowers:requesting-code-review` against the diff + evidence.
9. Fix review findings or record technical deferrals in the phase report.
10. Re-run the focused probe set + regression matrix after fixes.
11. Commit the phase with the report paths in the commit message body when the phase is substantial.

The Phase 12 promotion gate is incremental (Task 12.0): each phase that introduces a new subsystem evaluates promotion immediately. Late bulk promotion is forbidden.

## Subagent Strategy

Use `superpowers:dispatching-parallel-agents` when a phase has independent workstreams with disjoint write scopes. Default dispatch shapes:

- Phase 1 extractors: one agent per asset class (`intro/fs`, `rooms`, `CHR/palette`, `enemies/items`, `audio/text`) plus one verifier/package-check agent.
- Phase 7 enemies: one agent per behavior family (`walkers`, `flyers/jumpers`, `projectiles`, `special`, `aquatic/terrain`) after the enemy framework lands.
- Phase 8 bosses: one agent per boss after the boss framework lands.
- Phase 13 multiplayer: separate agents for input adapter, render/sprite budget, player state, and combat rules after `PlayerState[4]` exists.
- Phase 17 builder release: separate agents for package checker, drag/drop UX, reproducibility gate, and docs.

Rules:

- [ ] Each parallel agent owns a disjoint file/module set.
- [ ] Shared headers and state structs land before parallel dispatch.
- [ ] Workers do not edit RoomRom files unless they are in `FINAL TRY-roomrom-s1`.
- [ ] Each worker returns changed paths, build/probe evidence, and unresolved risks.
- [ ] Parent session integrates and runs the phase close gate.

## Probe Contract

Every BizHawk probe follows the one-launch bundle rule from memory rule `feedback_one_big_probe`:

- [ ] One probe per BizHawk launch.
- [ ] Bundle screenshot, SAT, CRAM, plane/Window dumps, relevant RAM/state bytes, and input log in the same launch.
- [ ] Record source ROM SHA-256, generated asset manifest hash, emulator name/version/core, frame number, target ROM hash, and probe script hash in every report.
- [ ] Deterministic probes expose RNG seed injection or record the exact seeded state before first gameplay frame.
- [ ] Enemy, boss, drop, recorder, gambling, and room-spawn probes must run from a deterministic seed harness.
- [ ] Reports end with `ALL PASS` or `FAIL` so runners can gate automatically.

## Cross-Workstream Dependency Graph

- Builder/data extraction feeds every generated asset and must become strict before public release.
- Graphics registry feeds rooms, caves, dungeons, Link/items, enemies, bosses, HUD, frontend promotion, and multiplayer.
- Typed state feeds caves, overworld secrets, dungeon state, Link/items, enemies, bosses, save/options, promotion, and multiplayer.
- Probe infrastructure feeds every phase close gate and must grow before each subsystem is called complete.
- Options runtime feeds file select, pause, HUD, audio, combat toggles, traversal toggles, accessibility, and multiplayer player-count selection.
- Audio adapter feeds frontend, caves, items/combat, enemies, bosses, and hardware validation.

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
  - [ ] Add a comment saying this alias exists only until all probes are migrated and is deleted in Phase 16.5.
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

### Task 0.6: Worktree Merge Protocol

**Why:** RoomRom dev lives in `FINAL TRY-roomrom-s1` (branch `roomrom-s1`); main worktree lacks RoomRom S2+ features. Without a written protocol, Phase 12 promotion will silently merge stale main-branch RoomRom code instead of the actual worktree state. Hard memory rule `feedback_check_worktree_first`.

- [ ] Create `docs/audit/worktree_merge_protocol.md`.
- [ ] Document `git worktree list` is the first command of any RoomRom edit.
- [ ] Document the canonical "RoomRom → main → src/game/" promotion sequence as a numbered command list.
- [ ] Include rebase rule: `roomrom-s1` must rebase clean on `main` before promotion.
- [ ] Include build rule: `RoomRom/build.bat` must pass in BOTH worktrees before promotion.
- [ ] Include cherry-pick fallback for hot-fix-style promotions.
- [ ] Include forbidden patterns: editing RoomRom files in main worktree, copying generated files cross-worktree without rebuild, Phase 12 promotion without rebase.
- [ ] Add `tools/verify_worktree_state.py` that prints both worktree heads, dirty file lists, and a green/red verdict for "is the RoomRom worktree current with main."
- [ ] Phase 12 cannot start until this file is committed and `verify_worktree_state.py` exists.
- [ ] Commit as `docs: add worktree merge protocol`.

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
- [ ] Document supported input ROMs:
  - [ ] PRG0 / Rev 0: `Legend of Zelda, The (USA).nes`, SHA-256 `8f72dc2e98572eb4ba7c3a902bca5f69c448fc4391837e5f8f0d4556280440ac`.
  - [ ] PRG1 / Rev A: `Legend of Zelda, The (USA) (Rev A).nes`, SHA-256 `89232edf4f9b52e3cb872094bc78973de080befca2ddea893b6e936066514d4e`.
- [ ] Record hash provenance in the builder README: PRG0 from local S0 audit; PRG1 cross-checked against TASVideos SHA-1/MD5 listing and a No-Intro-compatible SHA-256 listing.
- [ ] Document optional Redux input policy:
  - [ ] User supplies a compatible Redux-patched ROM, or supplies a base ROM plus a locally-owned Redux patch file.
  - [ ] Builder validates the post-patch Redux ROM hash against a supported Redux hash table.
  - [ ] The public package does not bundle Redux IPS payloads unless license is verified and recorded.
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
- [ ] Reject PAL ROMs with: `PAL Zelda ROMs are not supported; use a supported USA PRG0 or PRG1 ROM hash.`
- [ ] Reject ROMs with CHR ROM banks if Zelda 1 CHR-RAM expectation is violated.
- [ ] Accept PRG0 and PRG1 as separate supported inputs and route extractor offsets through a ROM-version descriptor, not ad hoc conditionals.
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
- [ ] Confirm EVERY file classified as Nintendo-derived in `docs/audit/generated_asset_inventory.md` is either present in `GENERATED_ASSET_ROOT` or recorded in `docs/audit/extractor_blockers.md` with a named missing extractor.
- [ ] Phase 1 cannot close while any Nintendo-derived file is silently served from a checked-in fallback.
- [ ] Run public package cleanliness check.
- [ ] Commit as `tools: add legal asset builder foundation`.

### Task 1.11: Strict Generated-Only Build Gate

**Why:** Soft fallback in Task 1.6 hides missing extractors until Phase 17 release packaging. A hard gate forces every Nintendo-derived dependency to be reproducible from the user ROM during development, not at release.

- [ ] Add `REQUIRE_GENERATED_ASSETS=1` environment flag handling to `build.bat` and `RoomRom/build.bat`.
- [ ] When the flag is set, the build FAILS (not warns) if any file under `data/`, `src/data/`, `src/gen/`, or `RoomRom/data/` is read without a corresponding entry in the generated manifest at `GENERATED_ASSET_ROOT`.
- [ ] Add `tools/builder/strict_build_check.py` that runs both Title.md and RoomRom.md builds with `REQUIRE_GENERATED_ASSETS=1` and reports any fallback hit.
- [ ] Add CI/manual job: "Strict Builder Gate". Required green before release packaging, recommended green per phase close.
- [ ] Add to Phases 3-9 task preambles: "Do not start phase if Task 1.11 strict gate is not green for the assets this phase consumes."
- [ ] Commit as `tools: add strict generated-only build gate`.

---

## Phase 1.5: NES Reference Capture Harness

**Goal:** Produce ONE deterministic, hash-pinned, RNG-seeded NES reference capture pipeline that every later "compare against NES" task consumes. Eliminates per-phase capture reinvention and makes "match NES" enforceable mechanically.

**Files:**
- Create: `tools/nes_capture/README.md`
- Create: `tools/nes_capture/captures.json` (canonical scenario manifest)
- Create: `tools/nes_capture/run_capture.py`
- Create: `tools/nes_capture/lua/capture_bundle.lua`
- Create: `tools/nes_capture/verify_capture.py`
- Output: `build/generated/nes_reference/<rom_hash>/<scenario_id>/{screenshot.png, ppu.bin, oam.bin, palram.bin, ciram.bin, ram.bin, frame.txt, input_log.txt, rng_seed.txt}`

### Task 1.5.1: Define Scenario Manifest

- [ ] Create `tools/nes_capture/captures.json` schema.
- [ ] Required fields per scenario: id, title, source_rom_hash, starting_save_state, input_movie, target_frame, rng_seed, expected_room_id, capture_artifacts list.
- [ ] Add canonical scenarios:
  - [ ] `title_idle`, `title_to_fs`, `intro_story_pages`, `intro_item_showcase`, `intro_item_flash_cycle`.
  - [ ] `ow_room_00`, `ow_room_77`, `ow_lost_woods_correct`, `ow_lost_hills_correct`.
  - [ ] One capture per cave type (`cave_sword`, `cave_heart`, `cave_shop_three_item`, `cave_old_man_letter`, `cave_money_game`, etc.).
  - [ ] `uw_l1_room_0_through_5`, plus one capture per dungeon (`uw_l2_entry`, ... `uw_l9_entry`).
  - [ ] `boss_aquamentus`, `boss_dodongo`, `boss_manhandla`, `boss_gleeok_2head`, `boss_gleeok_3head`, `boss_gleeok_4head`, `boss_digdogger`, `boss_gohma_blue`, `boss_gohma_red`, `boss_patra`, `boss_moldorm`, `boss_lanmola`, `boss_ganon`.
  - [ ] One capture per enemy family stress room.
  - [ ] Save/load round-trip captures.

### Task 1.5.2: Implement Capture Driver

- [ ] Implement `tools/nes_capture/run_capture.py`.
- [ ] Validate input ROM hash against builder's supported list before running.
- [ ] Drive BizHawk in headless mode using `EmuHawk.exe --lua=tools/nes_capture/lua/capture_bundle.lua` per memory rule `skill_bizhawk_script`.
- [ ] Inject RNG seed pre-first-frame.
- [ ] Inject input movie deterministically.
- [ ] Run to target frame.
- [ ] Bundle screenshot + PPU + OAM + PALRAM + CIRAM + RAM + frame counter + input log + seed in a SINGLE BizHawk launch (memory rule `feedback_one_big_probe`).
- [ ] Write bundle into `build/generated/nes_reference/<rom_hash>/<scenario_id>/`.
- [ ] Hash every artifact and write `manifest.json` per scenario with: source_rom_hash, capture_tool_version, emulator_core_version, scenario_id, frame, rng_seed, artifact_sha256.

### Task 1.5.3: Implement Verifier

- [ ] Implement `tools/nes_capture/verify_capture.py`.
- [ ] Re-run a scenario and assert artifact SHA-256 matches manifest.
- [ ] Fail if any artifact differs.
- [ ] Wire verifier into the strict build gate (Task 1.11) so a missing or stale capture fails the build.

### Task 1.5.4: Verify Phase 1.5

- [ ] Run `run_capture.py` against all canonical scenarios for the supported ROM.
- [ ] Confirm `build/generated/nes_reference/<rom_hash>/` is fully populated.
- [ ] Run `verify_capture.py` and confirm all manifests reproduce.
- [ ] Confirm captures are gitignored (`build/` already is).
- [ ] Commit as `tools: add nes reference capture harness`.

---

## Phase 2: RoomRom Graphics Registry And No-Clobber Foundation

**Goal:** Finish the current RoomRom graphics/atlas/palette/VRAM work so future gameplay systems never clobber sprites, palettes, HUD, or BG tiles.

**Worktree:** Active RoomRom implementation for this phase happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`; do not edit RoomRom phase files from the main worktree.

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

### Task 2.0: State Contract Audit (BLOCKING — runs before Task 2.1)

**Why:** `src/state/link_state.h`, `src/state/enemy_state.h`, `src/state/room_state.h`, `src/state/save_state.h` are pure `RAM()`/`OBJ()` macro shims today — not typed C structs. Phase 12 promotion gate requires "typed `src/state/` struct ownership." Gate is broken until contract is enforced. Sonnet's debate evidence: `enemy_state.h:17,21` aliases `OBJ(0x0412, slot)` under two different names — alias collision will fire in Phase 7 parallel enemy dispatch.

Decision is recorded at `docs/audit/state_contract.md` (typed C structs for owned modules; NES RAM mirror layer for transpiled code only).

- [ ] Read `docs/audit/state_contract.md` and confirm decision is current.
- [ ] Run `tools/state/audit_macro_shims.py` (create if missing) over every `src/state/*.h`.
- [ ] Output: `docs/audit/state_macro_inventory.md` listing every macro, its NES offset, the subsystem it belongs to, and aliases.
- [ ] Identify all alias collisions (multiple macros mapping to same offset). Resolve each by picking one canonical name and recording the rename in the inventory.
- [ ] Write `tools/state/verify_no_alias_collisions.py` and confirm green after rename plan is applied.
- [ ] Add migration order table (subsystem → phase) to `docs/audit/state_contract.md`.
- [ ] Add `src/abi/nes_ram_mirror.h` skeleton: typed accessors that map struct field reads/writes to existing `nes_ram[]` offsets where parity requires the same byte location.
- [ ] Add lint rule `tools/state/lint_no_new_macro_state.py`: fails if any new commit adds a `RAM(`/`OBJ(` callsite outside the mirror layer header.
- [ ] No Task 2.1+ work begins until this audit and the verifier are green.
- [ ] Commit as `state: audit macro shim inventory and lock contract`.

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

### Task 2.6.5: Preserve NES Frame-Cadence Palette Toggles

**Why:** Phase 2.6 cuts to tile-index subpalette selection, but several NES sequences animate via per-frame palette toggles (Z_07 sprite-pal flip every 8 frames). If the new path strips these, intro item flash, low-health flash, boss palette flash, and hit-invuln flash all die. Memory rules: `project_intro_item_flash`, `project_chr_expansion`.

- [ ] Inventory every NES frame-cadence palette toggle:
  - [ ] Intro item flash (Z_07, FrameCounter bit 3, 8-frame cadence).
  - [ ] Low-health hearts flash.
  - [ ] Boss palette flash (Aquamentus, Dodongo, Manhandla, etc.).
  - [ ] Link hit-invuln flash.
  - [ ] Heart container final-blink on pickup.
  - [ ] Triforce flash on dungeon clear.
- [ ] Document NES source: which routine performs the toggle, which palette slot, which cadence (frame counter bit), source file/offset in the NES disassembly.
- [ ] Decide owner runtime per toggle. Default: own a typed `palette_toggle_t` in `src/state/palette_state.h` and run from a single `palette_tick(frame)` in the per-frame update.
- [ ] Implement each toggle natively against the new tile-index world without resurrecting the old `pal & 0x03 << 13` path.
- [ ] Add probes:
  - [ ] `intro_item_flash_8frame_cycle` (capture 16+ frames, assert palette index toggles every 8 frames).
  - [ ] `link_hit_invuln_flash` (force hit, capture 60 frames, assert flash cadence matches NES capture).
  - [ ] `low_health_flash` (set 1 heart, capture, assert hearts-pal flash matches NES).
  - [ ] `boss_aquamentus_palette_flash` (load boss room, capture, assert).
- [ ] Diff against `build/generated/nes_reference/` captures.
- [ ] Commit as `roomrom: preserve nes frame-cadence palette toggles`.

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

### Task 2.8: Parity Oracle Schema (BLOCKING for Phases 3+)

**Why:** Every later "compare against NES" task currently reinvents the comparison. A single committed schema makes every diff mechanical and deterministic. Codex debate-driven add. Consumes Phase 1.5 capture artifacts.

- [ ] Create `tools/parity/schema.json` defining the canonical diff schema:
  - [ ] `frame` (int)
  - [ ] `input_bitmask` (u8)
  - [ ] `rng_seed` (u16)
  - [ ] `rng_current` (u16)
  - [ ] `room_id` (u8)
  - [ ] `quest` (u8)
  - [ ] `link` { x, y, dir, action, anim_frame, hp, invuln_timer, b_item }
  - [ ] `enemies[16]` { type, x, y, dir, action, hp, anim_frame, projectile_id }
  - [ ] `items[8]` { type, x, y, state }
  - [ ] `ram_bytes` (named address-bucketed RAM excerpt)
  - [ ] `cram[64]` (raw CRAM dump)
  - [ ] `sat[80]` (Genesis SAT entries) / `oam[64]` (NES OAM entries)
  - [ ] `plane_a_excerpt`, `plane_b_excerpt`, `nametable_excerpt` (cropped to active scene area)
  - [ ] `screenshot_sha256` (hex)
- [ ] Implement `tools/parity/diff.py` that loads two schema instances (NES capture vs Genesis probe) and emits structured diff with field paths and tolerances per field.
- [ ] Define tolerances:
  - [ ] CRAM: byte-exact after Genesis CRAM conversion of NES PALRAM.
  - [ ] SAT vs OAM: equivalent under Genesis sprite-collapse rules (preserve visual identity, not byte identity).
  - [ ] Screenshot: byte-exact for static scenes, per-pixel L1 distance under threshold for animated.
  - [ ] Frame counters: must match within ±1 if Genesis frame timing uses NES VBlank cadence.
- [ ] Implement `tools/parity/genesis_probe.lua` that emits a schema instance from a Genesis BizHawk run.
- [ ] Implement `tools/parity/nes_to_schema.py` that converts an NES capture bundle (Phase 1.5 output) into a schema instance.
- [ ] Define `tools/parity/expected_failures.yaml` for known intentional divergences (Title.md customization, Redux toggles, multiplayer mode).
- [ ] Add to phase close gate: every parity claim cites `parity/diff.py` output.
- [ ] Commit as `tools: add parity oracle schema`.

---

## Phase 3: Overworld Caves

**Goal:** Implement every overworld cave entrance, cave interior, NPC/shop/item/text behavior, and exit path in RoomRom.

**Worktree:** Active RoomRom implementation for this phase happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`; do not edit RoomRom phase files from the main worktree.

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

**Worktree:** Active RoomRom implementation for this phase happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`; do not edit RoomRom phase files from the main worktree.

### Task 4.0: SRAM Map Foundation (moved up from Phase 9)

**Why:** NES Zelda is entirely state-driven. Every overworld secret, cave flag, dungeon flag, and inventory bit lives in SRAM. Building Phases 4-8 on an undocumented SRAM layout is the integration-hell scenario debate identified. Gemini + Sonnet agreed; debate Tier 2 item.

- [ ] Create `docs/audit/sram_map.md` with the canonical SRAM layout for all three targets (Title.md, RoomRom.md, Final.md):
  - [ ] Save slots (3) at `0x000-0x7FF`.
  - [ ] OptionsState at `0x800-0x81F`.
  - [ ] Multiplayer-only state at a separate versioned region (1-player saves ignore).
  - [ ] Reserved bytes for future expansion.
  - [ ] Per-byte legend mapping save fields to NES SRAM offsets where parity matters.
- [ ] Add `tools/state/verify_sram_map.py` that parses the doc and checks each target's link map for collisions.
- [ ] Add `src/state/save_state.h` typed struct (replaces existing `SAVE_BYTE(off)` macro shim per state contract).
- [ ] Add `src/state/options_state.h` typed struct.
- [ ] Add SRAM checksum field and verifier.
- [ ] Add power-cycle round-trip probe `sram_round_trip_probe`.
- [ ] No Phase 4-9 code may add a new SRAM byte without updating `docs/audit/sram_map.md`.
- [ ] Commit as `state: lock sram map foundation`.

### Task 4.1: Create World State Module

- [ ] Add `src/state/world_state.h` as a typed struct per the state contract.
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
- [ ] Add save/load serialization hooks pointing at `docs/audit/sram_map.md` byte ranges.

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

**Worktree:** Active RoomRom implementation for this phase happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`; do not edit RoomRom phase files from the main worktree.

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

### Task 5.2: Dungeon Collision (NES-source-of-truth)

**Why:** "Expose UW collision grid from renderer" was the original wording and it is wrong. NES Zelda dungeon collision derives from room attribute bytes + metatile definition tables, not from rendered tile indices. Several rooms have tiles that look passable but are solid (and vice versa) because the attribute bits and rendering bits diverge — Sonnet debate evidence. Building combat on renderer-derived collision causes Link to walk through walls in 8+ rooms. Memory rule `feedback_check_dont_guess`.

- [ ] Extract UW collision from NES room attribute bytes + metatile definition tables. Source: `reference/aldonunez/*.asm` attribute decoding + NES PRG bank metatile tables documented in the disassembly.
- [ ] Generate `collision_grid[level][quest][room_id][row][col]` as a precomputed table by `tools/builder/extract_uw_collision.py`. Table lives in `build/generated/<rom_hash>/uw_collision.bin` per the strict builder gate.
- [ ] Classify each metatile: wall, water, block, door, stair, push-block, sand/floor, hazard, special.
- [ ] Add `tools/parity/verify_uw_collision.py` that compares generated grids against NES BizHawk RAM probes at the in-RAM collision range across canonical UW captures.
- [ ] Implement per-axis Link collision against the generated grid (NOT the rendered Genesis plane).
- [ ] Verify Level 1 rooms via parity oracle (Task 2.8).
- [ ] Verify all 9 dungeons × 2 quests by smoke probe.
- [ ] Add probe `uw_collision_no_walk_through_walls` covering at least 8 known special-case rooms.
- [ ] Commit as `gameplay: derive uw collision from nes attributes`.

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

**Worktree:** Active RoomRom implementation for this phase happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`; do not edit RoomRom phase files from the main worktree.

### Task 6.1: Promote Link State Names + Define PlayerState[4] Shape

**Why:** The architectural shape of `LinkState` cannot be retrofitted later without rewriting Link. Phase 13 multiplayer needs `PlayerState[4]` — Codex says defer implementation post-Phase-17 but Gemini correctly insisted the shape must land NOW so Phase 6 sprite/render code is multiplayer-ready by construction. Opus debate synthesis: shape in Phase 6, implementation deferred.

- [ ] Migrate `src/state/link_state.h` from `RAM(addr)` macro shims to typed C struct per state contract.
- [ ] Add position fields (x, y, subpixel x/y).
- [ ] Add direction/facing.
- [ ] Add action state.
- [ ] Add animation frame/timer.
- [ ] Add invincibility timer.
- [ ] Add damage/knockback state.
- [ ] Add item-use state.
- [ ] Add death state.
- [ ] **Define `typedef LinkState PlayerState`** so Phase 13 only adds the array, not rewrites the struct.
- [ ] **Define `PlayerState players[4]` in `src/state/player_state.h` with `g_player_count` (default 1).** Phase 6 reads `players[0]` for 1-player; Phase 13 fills 1..3.
- [ ] **Add Genesis sprite-per-line budget envelope to `src/state/render_budget.h`:** max 80 sprites, max 20 per scanline, per-player sprite reservation, per-enemy sprite reservation, per-projectile reservation.
- [ ] Phase 6 render code MUST consume the budget envelope so Phase 13 cannot violate it.
- [ ] Add probe `player_state_size_invariant` asserting `sizeof(PlayerState) * 4 + headroom < SRAM region for multiplayer`.
- [ ] Replace raw RoomRom globals with `players[0].*` access.
- [ ] Run `verify_no_alias_collisions.py` for `link_state.h`.
- [ ] Commit as `state: link state typed + playerstate shape defined`.

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

**Worktree:** Active RoomRom implementation for this phase happens in `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`; do not edit RoomRom phase files from the main worktree.

### Task 7.1: Enemy Framework (BLOCKING for parallel family fan-out)

**Why:** Five parallel family agents (walkers, flyers, projectile, special, aquatic) cannot fan out until shared interfaces are committed. Without committed RNG header, each agent invents a local seed function and probes will desync. Without committed parity matrix, "probe each behavior" is unenforceable. Sonnet + Codex debate Tier 2.

- [ ] Migrate `src/state/enemy_state.h` to typed C struct per state contract. Resolve the `OBJ(0x0412, slot)` alias collision (Sonnet evidence: `ENEMY_FLYER_SPEED_FRAC` and `ENEMY_PUSH_TIMER` both map to it).
- [ ] Run `verify_no_alias_collisions.py` and confirm green.
- [ ] Define enemy slots, type enum, action states, spawn metadata.
- [ ] **Commit `RoomRom/src/roomrom_rng.h`** before any family agent dispatches. Required exports:
  - [ ] `void rng_seed(uint16_t seed)`
  - [ ] `uint16_t rng_next(void)`
  - [ ] `uint16_t rng_peek(void)`
  - [ ] `#define PROBE_RNG_SEED ((volatile uint16_t*)0x...)` accessible from BizHawk Lua.
  - [ ] All five family agents MUST include this header. No agent may commit a local seed variable.
- [ ] **Commit `docs/audit/enemy_parity_matrix.md`** before family dispatch. Per enemy: source room(s), spawn rule, RNG seed positions, movement timer cadence, hitbox dimensions, damage value, drop table, required probe id from Phase 1.5 captures.
- [ ] Define movement helpers, collision helpers (consume Task 5.2 collision grid), render helper interface, death/drop hook.
- [ ] Add room enemy loader (consumes generated enemy tables from builder Phase 1).
- [ ] Add per-room spawn rules.
- [ ] Add enemy clear tracking and shutter-door event.
- [ ] Add `tools/parity/enemy_diff.py` consuming Task 2.8 schema.
- [ ] Commit as `enemy: framework + rng header + parity matrix`. No Task 7.2 begins until this commit lands.

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

### Task 10.1: Lock Driver Policy

- [ ] Keep the current custom driver as the default because the project already has working native intro/audio substrate.
- [ ] Do not block audio data extraction on an SGDK XGM/XGM2 migration.
- [ ] Keep the C-facing audio adapter stable so the driver can change later without touching gameplay.
- [ ] Revisit SGDK XGM/XGM2 only if Phase 15 measurements show the custom driver over budget, unmaintainable, or fidelity-blocking.
- [ ] Document the decision in `docs/audit/audio_driver_decision.md`.

### Task 10.1.1: Audio Legal Policy (BLOCKING for Task 10.2)

**Why:** "Legal extraction" of NES song data was undefined in the original plan — Sonnet debate evidence. NES Zelda music (square wave sequences, DMC samples, envelope/tempo tables) is copyrighted. Without a written policy, release packaging at Task 17.1 may discover bundled binary blobs functionally identical to source data and block release.

- [ ] Create `docs/audit/audio_legal_policy.md`.
- [ ] PrimeDirective default ruling: NES sequence/pattern tables extracted from the user-supplied ROM are treated the same as CHR — the user owns the ROM, the user owns the extracted data, and our builder produces the extraction locally on the user's machine. Audio data follows the same legal model as CHR/room/palette data.
- [ ] Document the alternative authored-Genesis-native music path as a fallback if the ruling is challenged.
- [ ] Define which audio elements are "extracted as-is" (sequence tables, envelope tables) vs "must be transformed" (DMC samples, if any reuse triggers fair-use concerns).
- [ ] Update `tools/builder/package_check.py` to reject any audio binary file in the public release bundle that is not generated from the user ROM at build time.
- [ ] Commit as `docs: lock audio legal policy`.

### Task 10.1.2: FS Audio Routing Decision (BLOCKING for Task 10.3)

**Why:** Memory rule `project_fs_no_song_change` — `InitMode1` doesn't write `SongRequest`, so the title song bleeds through every FS scene. Phase 10.3 wires music events without first defining the FS-vs-title boundary; risk is title song audible during all of file select at release. Opus debate add.

- [ ] Decide: FS music is keyed off `gamemode == 0x01` (game mode), NOT off the title bitmap.
- [ ] Document decision in `docs/audit/audio_routing.md`.
- [ ] Add probe `fs_silent_or_explicit_song`: enter file select, capture `SongRequest`, assert it matches the FS song id (or silence id) — NOT the title id.
- [ ] If the FS plays silence on NES, default Genesis behavior matches.
- [ ] If a Redux toggle changes FS music, route through option consumer (Phase 9 Task 9.4).
- [ ] Commit as `audio: lock fs routing decision`.

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

## Phase 11: Title.md Frontend Gap-Fill + Regression Lock

**Goal:** Treat the mostly-built title/file-select work as an existing frontend and close remaining gaps with regression probes before final gameplay merge.

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

**Promotion gate:** A module is eligible to move from RoomRom into `src/game/` only when:

- [ ] It has two consecutive green RoomRom probe runs from a clean build.
- [ ] It has no RoomRom-only global state outside harness configuration.
- [ ] Its persistent state lives in a typed `src/state/` struct (per state contract `docs/audit/state_contract.md`).
- [ ] Its public header lives under `src/game/<subsystem>/`.
- [ ] Its harness adapter is thin enough that Final.md can call the same core module.
- [ ] Its NES reference provenance is recorded in the phase report (Phase 1.5 capture id + parity oracle diff result).
- [ ] `verify_no_alias_collisions.py` is green for the touched state header.
- [ ] Worktree merge protocol (`docs/audit/worktree_merge_protocol.md`) was followed.

### Task 12.0: Incremental Promotion Gate (no late bulk move)

**Why:** The original Phase 12 schedule deferred all promotion to Task 12.2. Codex + Opus debate evidence: 11 phases of accumulated RoomRom assumptions create a single high-risk merge event at Phase 12. Incremental promotion forces each subsystem's contract to be exercised continuously across Title.md / RoomRom.md, eliminating Phase 12 as an integration cliff.

- [ ] After EACH of Phases 3, 4, 5, 6, 7, 8, 9, evaluate that phase's primary subsystem against the promotion gate above.
- [ ] If gate is satisfied: promote immediately (move headers to `src/game/<subsystem>/`, update both Title.md and RoomRom.md to consume promoted module).
- [ ] If gate is not satisfied: record the blocker in `docs/audit/roomrom_promotion_audit.md` with explicit reason and remediation owner.
- [ ] Phase 12 audit (Task 12.1) becomes verification that incremental promotions happened on schedule, not the first ownership pass.
- [ ] Add `tools/audit/check_incremental_promotion.py` that lists every shared module in `RoomRom/src/` not yet promoted with its phase deferral count.
- [ ] Phase 12 cannot close while any deferral count exceeds 1 phase without a documented blocker.

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

**Save rule:** NES save-slot bytes remain unchanged. Multiplayer-only state uses a separate versioned SRAM range so 1-player NES-faithful saves remain byte-compatible and never read multiplayer state by accident.

### Task 13.1: Generalize Player State

- [ ] Change `LinkState` to `PlayerState`.
- [ ] Add `PlayerState players[4]`.
- [ ] Preserve 1-player behavior through accessors and probes even though `players[0]` becomes part of a four-player array.
- [ ] Add active player count.
- [ ] Add player spawn positions.
- [ ] Add per-player input state.
- [ ] Add multiplayer SRAM version flag and separate multiplayer state range.
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

**Approach change (debate-driven):** The original plan said "input/movie segments or manual checklist per dungeon." Sonnet + Opus + Gemini agreed this is unexecutable for CLIs. Movies desync without seeded preconditions and manual checklists require a human to play. Replace with deterministic per-dungeon save-state injection harness; movies become consumers later.

### Task 14.0: Dungeon Harness (BLOCKING for 14.1/14.2)

- [ ] Create `tools/dungeon_harness/` directory.
- [ ] For each of the 9 dungeons × 2 quests (18 total):
  - [ ] Capture a BizHawk save state at dungeon entry with correct inventory + flag preconditions.
  - [ ] Write a Lua probe script `dungeon_<level>_q<n>.lua` that loads the save state, injects the minimal critical-path input sequence (enter boss room, deliver required hits, capture room-clear flag, capture reward), and emits a parity-oracle schema instance.
  - [ ] Pin the save state hash and seeded RNG in `tools/dungeon_harness/manifest.json`.
- [ ] Add `tools/dungeon_harness/run_all.py` that runs all 18 harnesses and reports green/red per dungeon.
- [ ] Verify Final.md (or RoomRom direct-boot pre-Phase-12) passes the harness for at least one dungeon before Phase 14.1 begins.
- [ ] Each harness consumes Phase 1.5 NES reference captures + Task 2.8 parity oracle schema for diff.
- [ ] Commit as `tools: add per-dungeon save-state harness`.

### Task 14.1: First Quest Route

- [ ] Run `tools/dungeon_harness/run_all.py --quest 1`.
- [ ] Confirm dungeons 1-8 pass.
- [ ] Run dungeon 9 / Ganon harness; confirm boss-clear flag, triforce pickup, ending trigger.
- [ ] Add a `first_quest_full_route.lua` movie that consumes harness save states sequentially; not required for green, used only for end-to-end smoke recording.
- [ ] Save reports under `builds/reports/quest1/`.

### Task 14.2: Second Quest Route

- [ ] Run `tools/dungeon_harness/run_all.py --quest 2`.
- [ ] Confirm second-quest dungeons pass with quest-specific entrance/dungeon variants.
- [ ] Run dungeon 9 / Ganon harness for quest 2.
- [ ] Save reports under `builds/reports/quest2/`.

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

## Phase 15: Genesis-Specific Optimization

**Goal:** Use Genesis hardware strengths deliberately after correctness is proven, with measurements and parity gates protecting NES-faithful mode.

**Timing model:** Phase 15a is inline optimization that happens during Phases 2-6 when the optimization is structurally required or trivially local: VRAM map ownership, Window-plane HUD, DMA chunking for large scene loads, CRAM ownership, and sprite atlas layout. Phase 15b is this measured re-pass after Phase 14, where broad rewrites are allowed only when probes show a real budget or hardware risk.

### Task 15.1: Instrument The Frame

- [ ] Add per-frame CPU tick measurement.
- [ ] Add VBlank duration measurement.
- [ ] Add DMA queue byte/word count measurement.
- [ ] Add DMA queue overflow counter.
- [ ] Add SAT upload count measurement.
- [ ] Add active sprite count measurement.
- [ ] Add VRAM upload byte count measurement.
- [ ] Add CRAM write count measurement.
- [ ] Add audio tick duration measurement.
- [ ] Add worst-frame report output under `builds/reports/perf/`.
- [ ] Add RoomRom perf overlay for current scene, room, sprite count, DMA words, and worst frame.
- [ ] Add Final.md perf capture probe after Phase 12 exists.

### Task 15.2: Establish Baseline Budgets

- [ ] Measure title idle.
- [ ] Measure story scroll.
- [ ] Measure file select.
- [ ] Measure overworld idle room.
- [ ] Measure overworld enemy-heavy room.
- [ ] Measure cave with NPC/text.
- [ ] Measure dungeon normal room.
- [ ] Measure dungeon enemy-heavy room.
- [ ] Measure boss room.
- [ ] Measure 4-player stress room.
- [ ] Record CPU, VBlank, DMA, sprite, and audio maxima.
- [ ] Save baseline to `builds/reports/perf/genesis_budget_baseline.md`.
- [ ] Fail the phase if any baseline already exceeds VBlank/DMA safety margins.

### Task 15.3: VDP Plane Strategy

- [ ] Keep Window plane as the stable HUD/menu band.
- [ ] Keep Plane A as the active playfield by default.
- [ ] Use Plane B as transition/staging/backdrop where it reduces redraw cost.
- [ ] Verify no HUD rows are redrawn as playfield tiles during gameplay.
- [ ] Verify title/file-select static bands use bulk plane writes.
- [ ] Add a verifier that catches direct playfield writes into the Window plane outside HUD/menu owners.
- [ ] Add a verifier that catches large per-tile loops where a bulk plane transfer exists.

### Task 15.4: DMA Transfer Optimization

- [ ] Inventory every VRAM/CRAM/SAT transfer site.
- [ ] Classify transfers as scene-load, room-load, per-frame, or rare event.
- [ ] Convert scene-load CHR uploads to bulk DMA when source alignment permits.
- [ ] Convert room tilemap fills to row/rect DMA where data is contiguous.
- [ ] Keep tiny one-off writes as CPU writes when DMA setup costs more.
- [ ] Split large uploads across display-off frames or multiple VBlanks.
- [ ] Ensure SAT DMA remains ordered after sprite list updates.
- [ ] Add regression probe comparing post-DMA plane/CRAM/SAT dumps to pre-DMA dumps.

### Task 15.5: VRAM Residency Optimization

- [ ] List always-resident tiles: blank, HUD, font, Link, core items.
- [ ] List scene-resident tiles: overworld BG, dungeon BG, cave BG, title, file select.
- [ ] List room/actor-resident tiles: bosses, rare enemies, special effects.
- [ ] Generate per-scene VRAM residency tables.
- [ ] Ensure common gameplay tiles do not stream every room.
- [ ] Stream rare enemy/boss tiles on room/scene entry only.
- [ ] Keep tile base contracts generated from `roomrom_vram_map.h`.
- [ ] Add no-overlap verifier for every scene residency table.
- [ ] Add stale-CHR probe for scene transitions.

### Task 15.6: Sprite Hardware Optimization

- [ ] Inventory every NES multi-OAM object.
- [ ] Collapse objects into larger Genesis sprites when the visual result is identical.
- [ ] Preserve NES-like priority where it affects gameplay visuals.
- [ ] Use SAT link ordering intentionally for Link, weapons, enemies, drops, and boss pieces.
- [ ] Define sprite priority classes.
- [ ] Define overflow policy for optional multiplayer mode.
- [ ] Guarantee 1-player NES mode keeps gameplay-critical sprites over cosmetic extras.
- [ ] Add stress probe for enemy-heavy rooms.
- [ ] Add stress probe for boss + projectiles.
- [ ] Add stress probe for 4-player + enemies.

### Task 15.7: CRAM And Palette Optimization

- [ ] Keep PAL0 for packed NES BG subpalettes.
- [ ] Keep PAL1 for packed NES sprite subpalettes.
- [ ] Reserve PAL2/PAL3 for non-NES overlays and transition effects.
- [ ] Batch CRAM updates by palette range.
- [ ] Avoid rewriting unchanged palettes on every frame.
- [ ] Add palette dirty flags.
- [ ] Add palette transition/fade routines that do not corrupt NES palette ownership.
- [ ] Probe no-flashing/reduced-flashing palette paths.
- [ ] Compare CRAM dumps before and after optimization.

### Task 15.8: 68K-Friendly Data Layout

- [ ] Precompute room metatile decode tables from NES data.
- [ ] Precompute collision grids from room render data.
- [ ] Precompute enemy spawn tables in 68K-friendly order.
- [ ] Precompute animation frame descriptors.
- [ ] Align frequently-read tables to word boundaries.
- [ ] Avoid bytewise decoding in per-frame hot paths when a generated table can do it once.
- [ ] Preserve original NES source data in builder cache for verification.
- [ ] Generate optimized Genesis tables under `build/generated/tables/` from source data deterministically.
- [ ] Add hash checks proving optimized tables derive from the same NES inputs.

### Task 15.9: Hot Path C/ASM Policy

- [ ] Profile room render.
- [ ] Profile collision.
- [ ] Profile sprite list assembly.
- [ ] Profile enemy update.
- [ ] Profile boss update.
- [ ] Profile audio tick.
- [ ] Keep C for any path inside budget.
- [ ] Use inline/static C helpers before assembly.
- [ ] Introduce assembly only for measured over-budget hot paths.
- [ ] Document every assembly optimization with hotspot, measurement, and fallback C behavior.
- [ ] Add ABI tests for every C/ASM boundary.

### Task 15.10: Audio Hardware Optimization

- [ ] Ensure music tick never blocks rendering transfers.
- [ ] Batch SFX requests.
- [ ] Prioritize gameplay SFX over cosmetic SFX when channels are exhausted.
- [ ] Keep low-health warning option cheap.
- [ ] Measure dense combat audio.
- [ ] Measure boss audio.
- [ ] Measure title/story music.
- [ ] Verify Z80/audio driver state survives scene transitions.

### Task 15.11: Input And Multiplayer Hardware Optimization

- [ ] Poll controllers once per frame through input adapter.
- [ ] Cache decoded button state per player.
- [ ] Keep 6-button and multitap/teamplayer logic inside the adapter.
- [ ] Ensure 1-player path is not slowed by 4-player decoding when player count is 1.
- [ ] Add controller stress probe for four active players.
- [ ] Add input latency check against frame counter.

### Task 15.12: Optimization Regression Gate

- [ ] For each optimized subsystem, capture pre-optimization reference dumps.
- [ ] Capture post-optimization dumps.
- [ ] Diff state schema.
- [ ] Diff plane/SAT/CRAM where applicable.
- [ ] Diff screenshots for visual systems.
- [ ] Run full RoomRom smoke.
- [ ] Run Final.md smoke after Phase 12 exists.
- [ ] Run hardware smoke after Phase 16 starts.
- [ ] Commit as `perf: add genesis-specific optimization pass`.

---

## Phase 16: Hardware, Performance, And Polish

**Goal:** Make the final ROM reliable on hardware and comfortable to play.

### Task 16.1: Performance Gates

- [ ] Add per-frame CPU budget measurement.
- [ ] Add VBlank DMA budget measurement.
- [ ] Add sprite count measurement.
- [ ] Add audio tick measurement.
- [ ] Add worst-case enemy/boss room tests.
- [ ] Optimize only measured hot spots.

### Task 16.2: Hardware Tests

- [ ] Test on real Genesis/Mega Drive.
- [ ] Test with flash cart.
- [ ] Test SRAM persistence.
- [ ] Test reset behavior.
- [ ] Test controller combinations.
- [ ] Record hardware notes.

### Task 16.3: Emulator Matrix

- [ ] BizHawk/GPGX.
- [ ] BlastEm.
- [ ] Genesis Plus GX standalone.
- [ ] Flash cart runtime used for final hardware smoke.
- [ ] Record differences.

### Task 16.4: Accessibility And Safety

- [ ] No/reduced flashing option verified.
- [ ] Low health warning options verified.
- [ ] Control swap verified.
- [ ] Text speed option verified if implemented.
- [ ] Document photosensitivity option.

### Task 16.5: Polish Pass

- [ ] Audit naming.
- [ ] Remove dead debug code from release build.
- [ ] Keep debug build diagnostics.
- [ ] Remove obsolete aliases if all probes migrated.
- [ ] Delete `whatif.md`, `whatif.lst`, `whatif.elf`, and `whatif.o` compatibility aliases after every active probe and launcher uses `Title.*` or `Final.*`.
- [ ] Add a one-release migration note for old local SaveRAM names, then stop regenerating `whatif.SaveRAM` aliases.
- [ ] Ensure `RoomRom` still builds.
- [ ] Ensure `Title.md` still builds.
- [ ] Ensure `Final.md` builds.
- [ ] Commit as `release: hardware and polish pass`.

---

## Phase 17: Public Builder Release

**Goal:** Ship the project as a legal builder, not a copyrighted-asset ROM package.

### Task 17.1: Clean Public Package

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

### Task 17.2: Builder UX

- [ ] Drag NES ROM onto builder.
- [ ] Validate ROM.
- [ ] Extract assets.
- [ ] Build final ROM.
- [ ] Show output path.
- [ ] Write manifest.
- [ ] Show unsupported ROM error clearly.
- [ ] Show missing dependency error clearly.
- [ ] Keep logs for troubleshooting.

### Task 17.3: From-Scratch Build Gate

- [ ] Clone clean public package.
- [ ] Confirm no generated asset cache.
- [ ] Run builder with valid NES ROM.
- [ ] Confirm generated cache appears locally.
- [ ] Confirm final `.md` appears.
- [ ] Confirm final ROM hash recorded.
- [ ] Run smoke probe.
- [ ] Delete cache.
- [ ] Repeat to prove reproducibility.
- [ ] Re-run builder with the same NES ROM, same generated extractor versions, and same git SHA.
- [ ] Byte-compare rebuilt `Final.md` against the previous `Final.md`; require diff=0.
- [ ] Fail release if manifest inputs match but ROM bytes differ.

### Task 17.4: Release Documentation

- [ ] User build instructions.
- [ ] Supported ROM hash.
- [ ] Optional Redux input instructions.
- [ ] Troubleshooting.
- [ ] Legal note: user must supply their own ROM.
- [ ] Contributor guide: do not commit generated copyrighted assets.
- [ ] Verification guide.

### Task 17.5: Final Release Gate

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
- [ ] Enforce one BizHawk launch per probe report with bundled screenshot, SAT, CRAM, plane/Window dumps, RAM/state bytes, and input log.
- [ ] Accept and record a deterministic RNG seed for enemy, boss, drop, gambling, and timing-sensitive probes.
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

### Workstream F: Regression Matrix (debate-driven)

**Why:** Per-phase gates close phases independently, but Phase N can silently break Phase M's probe. Without a global regression matrix, drift is invisible until release.

- [x] Create `tools/run_regression_matrix.py`. **Implemented 2026-05-02.**
- [x] Discover every probe under `builds/reports/` and `tools/parity/`. **Implemented: discovers parity-oracle pairs (`build/generated/parity/*_nes.json` + `*_gen.json`), archived report pairs (`builds/reports/**/*_gen.json`), binary baselines (`tools/probes/baselines/*.bin`), and screenshot baselines (`tools/probes/baselines/*.png`).**
- [x] Run each probe against current build of every active target (Title.md, RoomRom.md, Final.md when it exists). **Implemented: infers target from scenario_id prefix; skips with `SKIP: ROM missing` when the target ROM has not been built.**
- [x] Diff each probe's current output against its archived report using parity oracle (Task 2.8). **Implemented: dispatches to `tools/parity/diff.py` for parity-oracle probes, byte-exact diff for binary baselines, SHA-256 / pixel-L1 for screenshot baselines.**
- [x] Emit `builds/reports/regression_matrix.md` with green/red per probe. **Implemented: also emits `regression_matrix.json` companion for CI. See `tools/regression_matrix_README.md` for output format and CI job spec.**
- [x] Required green before any phase-close commit. New probes are added incrementally; existing probes never silently regress. **Enforced: exit code 1 on any unexpected red; expected failures require explicit `expected_failures.yaml` entries with `owner_phase`.**
- [x] Add per-subsystem `PROBE_CYCLE_LIMIT` enforcement: every probe records CPU cycles for the subsystem under test, fails close gate if cycles exceed published budget at `builds/reports/perf/genesis_budget_baseline.md`. (Gemini debate add, Codex hybrid: cycle limits enforced inline from Phase 6 onward, not deferred to Phase 15b.) **Implemented: `tools/per_subsystem_cycle_check.py` reads `docs/audit/genesis_budget_baseline.md` (skeleton checked in; `builds/reports/perf/genesis_budget_baseline.md` as fallback) and compares against `builds/reports/perf/<phase>_<scene>.json` measurements. Budget values are TBD until Phase 15.2.**
- [ ] Phase 16.5 polish pass removes any probes the matrix marks chronically flaky; do not delete probes silently.

### Workstream G: State Contract Enforcement (debate-driven)

- [ ] `tools/state/audit_macro_shims.py` runs in CI.
- [ ] `tools/state/verify_no_alias_collisions.py` runs in close gate of every phase that touches `src/state/`.
- [ ] `tools/state/lint_no_new_macro_state.py` runs as a pre-commit hook.
- [ ] Every promoted module's typed struct cites NES offsets via comments or `_Static_assert` against `offsetof`.
- [ ] Phase 12 close requires `RAM(`/`OBJ(` greps to return zero hits in owned C source.

---

## Current Next Action

Order is fixed: Tier-1 contracts gate first, then graphics registry resumes, then caves.

- [ ] Tier-1 gate, in order:
  - [ ] Task 0.6 Worktree Merge Protocol committed.
  - [ ] Phase 1.5 NES Reference Capture Harness produces deterministic captures for at least the canonical title/FS/OW/UW/cave/boss scenarios.
  - [ ] Task 1.11 Strict Generated-Only Build Gate green for current asset set.
  - [ ] Task 2.0 State Contract Audit committed; alias collision verifier green.
- [ ] Then resume Phase 2 graphics registry (Task 2.1+) in the RoomRom worktree.
- [ ] Then Phase 3 Overworld Caves with Task 2.8 parity oracle in the close gate.
- [ ] Keep this master plan updated only when phase order changes; do not turn it into a scratch log.

## Self-Review

- [x] Covers target split.
- [x] Covers legal builder path with strict gate (Task 1.11) and reproducibility check (Task 17.3).
- [x] Covers NES reference capture harness as a single source of truth (Phase 1.5).
- [x] Covers state contract decision (typed structs + NES mirror, `docs/audit/state_contract.md`) before any new state field lands.
- [x] Covers graphics no-clobber foundation + frame-cadence palette toggle preservation before caves.
- [x] Covers caves immediately after current work.
- [x] Covers overworld, dungeon, Link/items/combat, enemies (RNG header gated, parity matrix gated), bosses, HUD/options/save, audio (legal policy + FS routing locked), frontend, integration (incremental promotion gate, no late bulk), multiplayer (shape in Phase 6, implementation post-Phase-17), completion (per-dungeon save-state harness), Genesis-specific optimization (15a inline + 15b regression-matrix-driven), hardware, and release.
- [x] Leaves no phase without verification.
- [x] Keeps 1-player NES parity protected and uses a parity oracle schema mechanically rather than per-task improvisation.
- [x] Keeps 4-player mode isolated from NES parity.
- [x] Requires child plans before code-level implementation.
- [x] Encodes Workstream F regression matrix and Workstream G state contract enforcement as cross-cutting gates.
