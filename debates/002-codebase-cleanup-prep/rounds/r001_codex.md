warning: `--full-auto` is deprecated; use `--sandbox workspace-write` instead.
Reading additional input from stdin...
OpenAI Codex v0.128.0 (research preview)
--------
workdir: C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
model: gpt-5.5
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, C:\Users\Jake Diggity\.codex\memories]
reasoning effort: xhigh
reasoning summaries: none
session id: 019de9b5-4225-7833-a9b2-9317f224ea0b
--------
user
IMPORTANT: You are running as a non-interactive subagent dispatched by Claude Octopus via codex exec. Skip ALL skills. Respond directly.

You are CODEX in a four-way structured debate. Role: rigorous technical implementation perspective. Limit ~500 words.

READ FIRST:
1. C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\debates\002-codebase-cleanup-prep\context.md (full debate framing + recon)
2. C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\docs\superpowers\plans\2026-05-02-title-roomrom-full-port-master-plan.md (load-bearing references)
3. C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.gitignore

OPTIONAL but useful: ls/find through tools/, RoomRom/, src/, data/, builds/ to confirm before recommending.

QUESTION: What should we DELETE / MOVE / RENAME / KEEP in the codebase right now to set up Phase 1.5 -> 17 cleanly? AGGRESSIVE mode.

Required output sections:
1. Root leftovers verdict (.avi/.zip/.exe/.txt logs/diaries) — list each file with verdict.
2. Generated data fat verdict (what to drop once strict builder gate is on).
3. Vendor fat verdict (sgdk/, Zelda1-Redux/, midi/, reference/ extras).
4. Backup/temp verdict (.pre-merge-backup/, .codex_tmp/, __pycache__/).
5. Tools clutter verdict (255 root Lua + 122 root Python — propose canonical tree).
6. builds/ verdict (4.7 GB).
7. Owned C dead code (src/zelda_translated/, src/gen/, etc).
8. Doc consolidation (RESUME.md, CODEX_HANDOFF.md, T27_T29_FRONTEND_DIARY.md, best practices.md).
9. **TOP 10 actions ranked by impact / risk** — copy-pasteable shell commands or git rm lines.
10. Final stance: GREEN / YELLOW / RED on whether codebase as-is can carry Phase 1.5 -> 17 without major reorg.

Cite exact paths. Avoid generic advice.
codex
I’ll read the debate framing, master plan, and ignore rules first, then sample the filesystem so the verdict is grounded in the current tree.
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command "Get-Content -LiteralPath 'docs\\superpowers\\plans\\2026-05-02-title-roomrom-full-port-master-plan.md'" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command "Get-Content -LiteralPath '.gitignore'" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command "Get-Content -LiteralPath 'debates\\002-codebase-cleanup-prep\\context.md'" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
 succeeded in 851ms:
# Reference ROMs â€” never committed
*.nes
*.NES
reference/*.nes

# Python cache
__pycache__/
*.pyc
*.pyo

# Build artifacts / transient logs
.agents/
build_out.txt
build_output.log
*_run.log
builds/abi_probe/
RoomRom/build_err.txt
RoomRom/build_out.txt
RoomRom/out/

# Probe output directories (transient, not for tracking)
tools/file_select_test/out/
tools/intro_test/out/

# FS demo build artifacts
tools/file_select_demo/out/

# Local workspace scratch
.claude/scheduled_tasks.lock
.claude/worktrees/
.codex_tmp/
.superpowers/
.worktrees/
analyze_funcs.txt
src.zip
. : File C:\Users\Jake Diggity\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 cannot be loaded because 
running scripts is disabled on this system. For more information, see about_Execution_Policies at 
https:/go.microsoft.com/fwlink/?LinkID=135170.
At line:1 char:3
+ . 'C:\Users\Jake Diggity\Documents\WindowsPowerShell\Microsoft.PowerS ...
+   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : SecurityError: (:) [], PSSecurityException
    + FullyQualifiedErrorId : UnauthorizedAccess

 succeeded in 850ms:
# Debate 002: How improve codebase as-is to prep future phases? What delete/remove/reorganize?

**Date:** 2026-05-02
**Rounds:** 2 (cross-critique)
**Style:** thorough, AGGRESSIVE
**Mode:** cross-critique
**Advisors:** Codex, Gemini, Sonnet, Claude/Opus
**Word limit:** ~500 per response

## Question

Given the master plan + roadmap (already debated and improved at `debates/001-prime-directive-plan-improvement/synthesis.md`), what should be deleted, removed, renamed, restructured, or split out of the current codebase RIGHT NOW so future phases (Phase 1.5 â†’ 17) execute cleanly?

## Mode

**Aggressive.** Per user PrimeDirective default: delete anything not load-bearing, rename anything misleading, restructure freely. Surface candidates AND recommend execution.

## Scope

ALL OF:
- Owned C: `src/` and `RoomRom/src/`
- Tools/extractors/probes: `tools/`, `RoomRom/tools/`, `*.lua`, `*.bat`, `*.py`
- Generated data: `data/`, `src/data/`, `src/gen/`, `RoomRom/data/`
- Root leftovers + builds: `.avi`, `.zip`, `.bak`, `.exe`, `.txt` logs, build artifacts
- Reference + sgdk vendor dirs (decide what stays)
- Submodules / subdirectories: `Zelda1-Redux/`, `midi/`, `reports/`, `.pre-merge-backup/`, `.codex_tmp/`

## Codebase Recon (do not re-run; consume this)

Top-level dirs: `src/` 3.3M (149 .c/.h/.asm), `RoomRom/` 24M (60 source files), `data/` 1.6M (155 files), `tools/` 26M (122 .py + 255 .lua + many .bat/.ps1 = 521 total), `docs/` 2.2M, `builds/` 4.7G (artifacts), `reference/` 24M (NES disasm + Sonic 2 + sega2f), `sgdk/` 162M (vendor SGDK).

Vendor / submodule like dirs: `sgdk/` (162M, includes 50M sample, 4.2M doc, 2.9M tools), `Zelda1-Redux/` (82M unzipped Redux disasm dump), `midi/` (9M with `mid2vgm-beta5/` and `PSG mode/`), `reference/Sonic 2`, `reference/sega2f_files`, `reference/Disassembly by Trax`, `reference/Disassembly by camthesaxman`, `reference/aldonunez` (the canonical NES disasm we cite).

Backup / temp: `.pre-merge-backup/` (178K, contains builds/reference/src/tools snapshots), `.codex_tmp/` (5 tmp dirs), `.superpowers/brainstorm/`, `.claude/worktrees/`, `__pycache__/` at root, `tools/__pycache__/`, `RoomRom/__pycache__/`, `tools/out/` (53K transient).

Root junk (NOT tracked or partially tracked):
- `FIX THIS.avi` (57M) â€” bug-report video
- `SCROLL TIME.avi` (47M) â€” bug-report video
- `Zelda1-Redux.zip` (1.7M) â€” already extracted to `Zelda1-Redux/`
- `VisualStudioSetup.exe` (4.2M)
- `rustup-init.exe` (12.2M)
- `src.zip` (582K)
- `a.out` (280B)
- `Zelda - Ocarina of Time - Great Fairy's fountain.mid` (3.8K)
- `Zelda Redux.nes` (128K) â€” second ROM not in `.gitignore`?
- `Legend of Zelda, The (USA).nes` (128K) â€” primary ROM
- `analyze_funcs.txt` (1.5K)
- `bout.txt` (72K)
- `build_a3_fix.txt` x3, `build_err.txt` (31K), `build_log.txt` (47.5K), `build_f3_log.txt` (81K), `build_out.txt` (41.5K), `build_out_a3.txt` (79K), `build_out3.txt`, `build_out_new.txt`, `build_output.txt`, `build_midi_out.txt` (10+ stale build logs)
- `T27_T29_FRONTEND_DIARY.md` (129K) â€” running diary, likely scratch
- `RESUME.md`, `CODEX_HANDOFF.md`, `best practices.md` â€” multiple authority docs

Tools clutter:
- 122 Python scripts at root of `tools/` (no submodule organization)
- 255 Lua probe scripts at root of `tools/`
- 5 Lua scripts under `tools/probes/` (canonical)
- 1 Lua at repo root
- 293 total Lua scripts in top-2 levels â€” hard to know which are canonical vs deprecated
- `tools/file_select_demo/`, `tools/file_select_test/`, `tools/intro_demo/`, `tools/intro_test/`, `tools/midi_demo/`, `tools/music_test/`, `tools/gen_wrappers/` â€” multiple demo/test variants
- `tools/plans/` â€” separate from `docs/superpowers/plans/`?
- `tools/out/` â€” transient

Owned C structure:
- `src/abi/`, `src/core/`, `src/data/`, `src/frontend/`, `src/game/`, `src/gen/`, `src/sgdk_adapter/`, `src/state/`, `src/zelda_translated/` (transpiled NES code)

State headers (per debate 001 finding): all `RAM()`/`OBJ()` macro shims. State contract decided typed C structs (`docs/audit/state_contract.md`).

Build size: `builds/` is 4.7 GB. Likely contains archive snapshots.

## Constraints / Hard Rules

1. RoomRom dev lives in `FINAL TRY-roomrom-s1` worktree. Touching `RoomRom/src/` from main worktree forbidden (memory rule `feedback_check_worktree_first`).
2. Anything cited in master plan (`docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md`) or roadmap is load-bearing â€” cleanup must not break references.
3. State contract decision (typed structs + NES mirror) is binding (`docs/audit/state_contract.md`).
4. `reference/aldonunez/` is the canonical NES disasm â€” keep.
5. `sgdk/` is vendor toolchain â€” keep but check for fat we can drop (samples, docs, tools we never use).
6. `Legend of Zelda, The (USA).nes` is the user-supplied ROM (kept locally per legal builder model).

## Asks of each debater

For each candidate (file/dir/pattern):
1. **DELETE / MOVE / RENAME / KEEP** verdict.
2. **Why** â€” short reason.
3. **Risk** â€” what breaks if we do it (probe scripts, build, doc references, future phase).
4. **Phase impact** â€” how this helps Phase 1.5 â†’ 17 execution.

Group recommendations by category:
- Root leftovers (.avi/.zip/.exe/.txt logs/diaries)
- Generated data fat (after strict builder gate, what stays?)
- Vendor fat (sgdk/, Zelda1-Redux/, midi/, reference/Sonic 2, reference/sega2f_files)
- Backup/temp (.pre-merge-backup, .codex_tmp, __pycache__)
- Tools clutter (255 root Lua, 122 root Python â€” what to canonicalize)
- builds/ (4.7 GB)
- Owned C dead code (src/zelda_translated/, src/gen/, anything else)
- Doc consolidation (RESUME.md, CODEX_HANDOFF.md, T27_T29_FRONTEND_DIARY.md, best practices.md, README.md, CLAUDE.md)

End with: TOP 10 ranked actions ordered by (highest impact Ã· lowest risk).
. : File C:\Users\Jake Diggity\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 cannot be loaded because 
running scripts is disabled on this system. For more information, see about_Execution_Policies at 
https:/go.microsoft.com/fwlink/?LinkID=135170.
At line:1 char:3
+ . 'C:\Users\Jake Diggity\Documents\WindowsPowerShell\Microsoft.PowerS ...
+   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : SecurityError: (:) [], PSSecurityException
    + FullyQualifiedErrorId : UnauthorizedAccess

 succeeded in 1014ms:
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

## Phase Close Gate

Every implementation phase closes in this exact order:

1. Build the touched target with `REQUIRE_GENERATED_ASSETS=1` (Task 1.11 strict gate).
2. Run the focused probe set.
3. Capture screenshot/state evidence; emit a parity-oracle-schema instance per probe (Task 2.8).
4. Diff each schema instance against the matching `build/generated/nes_reference/` capture (Phase 1.5).
5. Run `tools/run_regression_matrix.py`; require green (Workstream F).
6. Run `tools/state/verify_no_alias_collisions.py` if the phase touched `src/state/` (Workstream G).
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
- [ ] Document the canonical "RoomRom â†’ main â†’ src/game/" promotion sequence as a numbered command list.
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

### Task 2.0: State Contract Audit (BLOCKING â€” runs before Task 2.1)

**Why:** `src/state/link_state.h`, `src/state/enemy_state.h`, `src/state/room_state.h`, `src/state/save_state.h` are pure `RAM()`/`OBJ()` macro shims today â€” not typed C structs. Phase 12 promotion gate requires "typed `src/state/` struct ownership." Gate is broken until contract is enforced. Sonnet's debate evidence: `enemy_state.h:17,21` aliases `OBJ(0x0412, slot)` under two different names â€” alias collision will fire in Phase 7 parallel enemy dispatch.

Decision is recorded at `docs/audit/state_contract.md` (typed C structs for owned modules; NES RAM mirror layer for transpiled code only).

- [ ] Read `docs/audit/state_contract.md` and confirm decision is current.
- [ ] Run `tools/state/audit_macro_shims.py` (create if missing) over every `src/state/*.h`.
- [ ] Output: `docs/audit/state_macro_inventory.md` listing every macro, its NES offset, the subsystem it belongs to, and aliases.
- [ ] Identify all alias collisions (multiple macros mapping to same offset). Resolve each by picking one canonical name and recording the rename in the inventory.
- [ ] Write `tools/state/verify_no_alias_collisions.py` and confirm green after rename plan is applied.
- [ ] Add migration order table (subsystem â†’ phase) to `docs/audit/state_contract.md`.
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
  - [ ] Frame counters: must match within Â±1 if Genesis frame timing uses NES VBlank cadence.
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

**Why:** "Expose UW collision grid from renderer" was the original wording and it is wrong. NES Zelda dungeon collision derives from room attribute bytes + metatile definition tables, not from rendered tile indices. Several rooms have tiles that look passable but are solid (and vice versa) because the attribute bits and rendering bits diverge â€” Sonnet debate evidence. Building combat on renderer-derived collision causes Link to walk through walls in 8+ rooms. Memory rule `feedback_check_dont_guess`.

- [ ] Extract UW collision from NES room attribute bytes + metatile definition tables. Source: `reference/aldonunez/*.asm` attribute decoding + NES PRG bank metatile tables documented in the disassembly.
- [ ] Generate `collision_grid[level][quest][room_id][row][col]` as a precomputed table by `tools/builder/extract_uw_collision.py`. Table lives in `build/generated/<rom_hash>/uw_collision.bin` per the strict builder gate.
- [ ] Classify each metatile: wall, water, block, door, stair, push-block, sand/floor, hazard, special.
- [ ] Add `tools/parity/verify_uw_collision.py` that compares generated grids against NES BizHawk RAM probes at the in-RAM collision range across canonical UW captures.
- [ ] Implement per-axis Link collision against the generated grid (NOT the rendered Genesis plane).
- [ ] Verify Level 1 rooms via parity oracle (Task 2.8).
- [ ] Verify all 9 dungeons Ã— 2 quests by smoke probe.
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

**Why:** The architectural shape of `LinkState` cannot be retrofitted later without rewriting Link. Phase 13 multiplayer needs `PlayerState[4]` â€” Codex says defer implementation post-Phase-17 but Gemini correctly insisted the shape must land NOW so Phase 6 sprite/render code is multiplayer-ready by construction. Opus debate synthesis: shape in Phase 6, implementation deferred.

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

**Why:** "Legal extraction" of NES song data was undefined in the original plan â€” Sonnet debate evidence. NES Zelda music (square wave sequences, DMC samples, envelope/tempo tables) is copyrighted. Without a written policy, release packaging at Task 17.1 may discover bundled binary blobs functionally identical to source data and block release.

- [ ] Create `docs/audit/audio_legal_policy.md`.
- [ ] PrimeDirective default ruling: NES sequence/pattern tables extracted from the user-supplied ROM are treated the same as CHR â€” the user owns the ROM, the user owns the extracted data, and our builder produces the extraction locally on the user's machine. Audio data follows the same legal model as CHR/room/palette data.
- [ ] Document the alternative authored-Genesis-native music path as a fallback if the ruling is challenged.
- [ ] Define which audio elements are "extracted as-is" (sequence tables, envelope tables) vs "must be transformed" (DMC samples, if any reuse triggers fair-use concerns).
- [ ] Update `tools/builder/package_check.py` to reject any audio binary file in the public release bundle that is not generated from the user ROM at build time.
- [ ] Commit as `docs: lock audio legal policy`.

### Task 10.1.2: FS Audio Routing Decision (BLOCKING for Task 10.3)

**Why:** Memory rule `project_fs_no_song_change` â€” `InitMode1` doesn't write `SongRequest`, so the title song bleeds through every FS scene. Phase 10.3 wires music events without first defining the FS-vs-title boundary; risk is title song audible during all of file select at release. Opus debate add.

- [ ] Decide: FS music is keyed off `gamemode == 0x01` (game mode), NOT off the title bitmap.
- [ ] Document decision in `docs/audit/audio_routing.md`.
- [ ] Add probe `fs_silent_or_explicit_song`: enter file select, capture `SongRequest`, assert it matches the FS song id (or silence id) â€” NOT the title id.
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
- [ ] For each of the 9 dungeons Ã— 2 quests (18 total):
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

- [ ] Create `tools/run_regression_matrix.py`.
- [ ] Discover every probe under `builds/reports/` and `tools/parity/`.
- [ ] Run each probe against current build of every active target (Title.md, RoomRom.md, Final.md when it exists).
- [ ] Diff each probe's current output against its archived report using parity oracle (Task 2.8).
- [ ] Emit `builds/reports/regression_matrix.md` with green/red per probe.
- [ ] Required green before any phase-close commit. New probes are added incrementally; existing probes never silently regress.
- [ ] Add per-subsystem `PROBE_CYCLE_LIMIT` enforcement: every probe records CPU cycles for the subsystem under test, fails close gate if cycles exceed published budget at `builds/reports/perf/genesis_budget_baseline.md`. (Gemini debate add, Codex hybrid: cycle limits enforced inline from Phase 6 onward, not deferred to Phase 15b.)
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
. : File C:\Users\Jake Diggity\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 cannot be loaded because 
running scripts is disabled on this system. For more information, see about_Execution_Policies at 
https:/go.microsoft.com/fwlink/?LinkID=135170.
At line:1 char:3
+ . 'C:\Users\Jake Diggity\Documents\WindowsPowerShell\Microsoft.PowerS ...
+   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : SecurityError: (:) [], PSSecurityException
    + FullyQualifiedErrorId : UnauthorizedAccess

codex
The master plan makes three things load-bearing for cleanup: `reference/aldonunez/`, `sgdk/` as the active toolchain, and generated assets only until `REQUIRE_GENERATED_ASSETS=1` is green. I’m checking current tracked status now so the recommendations can distinguish `git rm` from local deletion.
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'Get-ChildItem -Force -File | Sort-Object Name | Select-Object Name,Length' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command '$luaRoot=(Get-ChildItem -LiteralPath tools -File -Filter *.lua -ErrorAction SilentlyContinue | Measure-Object).Count; $pyRoot=(Get-ChildItem -LiteralPath tools -File -Filter *.py -ErrorAction SilentlyContinue | Measure-Object).Count; $luaAll=(Get-ChildItem -LiteralPath tools -Recurse -File -Filter *.lua -ErrorAction SilentlyContinue | Measure-Object).Count; $pyAll=(Get-ChildItem -LiteralPath tools -Recurse -File -Filter *.py -ErrorAction SilentlyContinue | Measure-Object).Count; "tools-root-lua`t$luaRoot"; "tools-root-py`t$pyRoot"; "tools-all-lua`t$luaAll"; "tools-all-py`t$pyAll"; Get-ChildItem -LiteralPath tools -Directory | Sort-Object Name | Select-Object Name' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command '$files=@('"'FIX THIS.avi','SCROLL TIME.avi','Zelda1-Redux.zip','VisualStudioSetup.exe','rustup-init.exe','src.zip','a.out','Zelda - Ocarina of Time - Great Fairy''s fountain.mid','Zelda Redux.nes','Legend of Zelda, The (USA).nes','analyze_funcs.txt','bout.txt','build_a3_fix.txt','build_err.txt','build_log.txt','build_f3_log.txt','build_out.txt','build_out_a3.txt','build_out3.txt','build_out_new.txt','build_output.txt','build_midi_out.txt','T27_T29_FRONTEND_DIARY.md','RESUME.md','CODEX_HANDOFF.md','best practices.md'); foreach("'$f in $files){ if(Test-Path -LiteralPath $f){ $tracked=git ls-files -- $f; $status=if($tracked){'"'TRACKED'}else{'UNTRACKED'}; "'$len=(Get-Item -LiteralPath $f).Length; "$status`t$len`t$f" } else { "MISSING`t`t$f" } }' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command '$dirs=@('"'tools','RoomRom','src','data','builds','sgdk','Zelda1-Redux','midi','reference','.pre-merge-backup','.codex_tmp'); foreach("'$d in $dirs){ if(Test-Path -LiteralPath $d){ $count=(Get-ChildItem -LiteralPath $d -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object).Count; $bytes=(Get-ChildItem -LiteralPath $d -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum; "$d`t$count`t$bytes" } else { "$d`tMISSING`t" } }' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
 succeeded in 843ms:

Name                                                   Length
----                                                   ------
.gitignore                                                595
.gitmodules                                                74
a.out                                                     280
analyze_funcs.txt                                        1581
best practices.md                                       10185
bout.txt                                                73755
build.bat                                               34771
build_a3_fix.txt                                          145
build_a3_fix2.txt                                         145
build_a3_fix3.txt                                         145
build_err.txt                                           31927
build_f3.bat                                              308
build_f3_log.txt                                        83353
build_f3_out.txt                                          100
build_log.txt                                           48633
build_midi_out.txt                                       3778
build_out.txt                                           42465
build_out_a3.txt                                        80889
build_out_new.txt                                         302
build_out3.txt                                            100
build_output.txt                                          100
build_run.tmp                                             100
capture.log                                                 0
capture2.log                                                0
CLAUDE.md                                                1829
CODEX_HANDOFF.md                                         5556
conftest.py                                               231
event                                                      35
FIX THIS.avi                                         59852288
Legend of Zelda, The (USA).nes                         131088
nes_reference.png                                      158870
probe_heart_flash.lua                                    2500
raw                                                        22
README.md                                                6428
RESUME.md                                                4480
run_build.bat                                             137
rustup-init.exe                                      12814336
scan_drain2.py                                           2053
SCROLL TIME.avi                                      49877504
src.zip                                                595929
t.out                                                    2603
T27_T29_FRONTEND_DIARY.md                              132523
test_copy.tmp                                             145
VisualStudioSetup.exe                                 4454944
Zelda - Ocarina of Time - Great Fairy's fountain.mid     3939
Zelda Redux.nes                                        131088
Zelda1-Redux.zip                                      1829953



 succeeded in 986ms:
tools-root-lua	255
tools-root-py	122
tools-all-lua	288
tools-all-py	167

Name            
----            
__pycache__     
file_select_demo
file_select_test
gen_wrappers    
intro_demo      
intro_test      
midi_demo       
music_test      
out             
plans           
probes          
tests           



 succeeded in 1945ms:
UNTRACKED	59852288	FIX THIS.avi
UNTRACKED	49877504	SCROLL TIME.avi
UNTRACKED	1829953	Zelda1-Redux.zip
TRACKED	4454944	VisualStudioSetup.exe
TRACKED	12814336	rustup-init.exe
UNTRACKED	595929	src.zip
TRACKED	280	a.out
UNTRACKED	3939	Zelda - Ocarina of Time - Great Fairy's fountain.mid
UNTRACKED	131088	Zelda Redux.nes
UNTRACKED	131088	Legend of Zelda, The (USA).nes
UNTRACKED	1581	analyze_funcs.txt
TRACKED	73755	bout.txt
TRACKED	145	build_a3_fix.txt
TRACKED	31927	build_err.txt
TRACKED	48633	build_log.txt
TRACKED	83353	build_f3_log.txt
UNTRACKED	42465	build_out.txt
TRACKED	80889	build_out_a3.txt
TRACKED	100	build_out3.txt
TRACKED	302	build_out_new.txt
TRACKED	100	build_output.txt
TRACKED	3778	build_midi_out.txt
TRACKED	132523	T27_T29_FRONTEND_DIARY.md
TRACKED	4480	RESUME.md
TRACKED	5556	CODEX_HANDOFF.md
TRACKED	10185	best practices.md

 succeeded in 5345ms:
tools	4372	16719411
RoomRom	380	23241094
src	212	2900819
data	68	1452060
builds	47586	4845655758
sgdk	4212	160255283
Zelda1-Redux	656	84374305
midi	172	9079971
reference	555	23926986
.pre-merge-backup	40	92780
.codex_tmp	0	

codex
There are tracked installers/logs at repo root, so the cleanup cannot be only `.gitignore`; it needs `git rm` for several files. I’m checking which generated/vendor/build paths are tracked so the aggressive plan does not accidentally delete the canonical inputs needed by Phase 1.5 and builder work.
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command "Get-Content -LiteralPath '.gitmodules'; git ls-files builds | Measure-Object; git ls-files data src/data src/gen RoomRom/data | Measure-Object; git ls-files sgdk Zelda1-Redux midi reference | Measure-Object" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'git ls-files builds | Select-Object -First 50; git ls-files builds | Select-Object -Last 30' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command "Get-ChildItem -LiteralPath src -Directory | Sort-Object Name | Select-Object Name; Get-ChildItem -LiteralPath src\\zelda_translated -Force -ErrorAction SilentlyContinue | Select-Object Name,Length; Get-ChildItem -LiteralPath src\\gen -Force -ErrorAction SilentlyContinue | Select-Object Name,Length" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'Get-ChildItem -LiteralPath reference -Directory | Sort-Object Name | Select-Object Name; Get-ChildItem -LiteralPath sgdk -Directory | Sort-Object Name | Select-Object Name; Get-ChildItem -LiteralPath midi -Directory | Sort-Object Name | Select-Object Name; Get-ChildItem -LiteralPath Zelda1-Redux -Directory | Sort-Object Name | Select-Object Name' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'git ls-files data src/data src/gen RoomRom/data | Select-Object -First 80; git ls-files data src/data src/gen RoomRom/data | Select-Object -Last 80' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
 succeeded in 1109ms:

Name                       
----                       
aldonunez                  
Disassembly by camthesaxman
Disassembly by Trax        
sega2f_files               
Sonic 2                    
.github                    
bin                        
doc                        
inc                        
lib                        
project                    
res                        
sample                     
src                        
tools                      
mid2vgm-beta5              
PSG mode                   
bin                        
code                       
optional                   
others                     
patches                    
rom                        
src                        



 succeeded in 1163ms:

Name                 
----                 
abi                  
core                 
data                 
frontend             
game                 
gen                  
sgdk_adapter         
state                
zelda_translated     
patches              
z_00.asm             
z_01.asm             
z_02.asm             
z_03.asm             
z_04.asm             
z_05.asm             
z_06.asm             
z_07.asm             
music_great_fairy.bin
z_01.c               
z_02.c               
z_03.c               
z_04.c               
z_05.c               
z_06.c               
z_07.c               



 succeeded in 1196ms:
RoomRom/data/atlas_master.json
RoomRom/data/item_chr_manifest.json
RoomRom/data/rom_inputs.lock
RoomRom/data/uw_level1_golden.json
RoomRom/data/uw_level1_quest1_manifest.json
RoomRom/data/uw_level1_quest1_rooms.json
RoomRom/data/uw_level1_quest2_manifest.json
RoomRom/data/uw_level1_quest2_rooms.json
RoomRom/data/uw_level2_quest1_manifest.json
RoomRom/data/uw_level2_quest1_rooms.json
RoomRom/data/uw_level2_quest2_manifest.json
RoomRom/data/uw_level2_quest2_rooms.json
RoomRom/data/uw_level3_quest1_manifest.json
RoomRom/data/uw_level3_quest1_rooms.json
RoomRom/data/uw_level3_quest2_manifest.json
RoomRom/data/uw_level3_quest2_rooms.json
RoomRom/data/uw_level4_quest1_manifest.json
RoomRom/data/uw_level4_quest1_rooms.json
RoomRom/data/uw_level4_quest2_manifest.json
RoomRom/data/uw_level4_quest2_rooms.json
RoomRom/data/uw_level5_quest1_manifest.json
RoomRom/data/uw_level5_quest1_rooms.json
RoomRom/data/uw_level5_quest2_manifest.json
RoomRom/data/uw_level5_quest2_rooms.json
RoomRom/data/uw_level6_quest1_manifest.json
RoomRom/data/uw_level6_quest1_rooms.json
RoomRom/data/uw_level6_quest2_manifest.json
RoomRom/data/uw_level6_quest2_rooms.json
RoomRom/data/uw_level7_quest1_manifest.json
RoomRom/data/uw_level7_quest1_rooms.json
RoomRom/data/uw_level7_quest2_manifest.json
RoomRom/data/uw_level7_quest2_rooms.json
RoomRom/data/uw_level8_quest1_manifest.json
RoomRom/data/uw_level8_quest1_rooms.json
RoomRom/data/uw_level8_quest2_manifest.json
RoomRom/data/uw_level8_quest2_rooms.json
RoomRom/data/uw_level9_quest1_manifest.json
RoomRom/data/uw_level9_quest1_rooms.json
RoomRom/data/uw_level9_quest2_manifest.json
RoomRom/data/uw_level9_quest2_rooms.json
data/.gitkeep
data/MANIFEST.sha256
data/audio/MANIFEST.json
data/audio/pcm_samples.c
data/audio/sfx.c
data/audio/sfx_pcm.c
data/audio/sfx_pcm.h
data/audio/song_scripts.c
data/audio/songs.c
data/chr/MANIFEST.json
data/chr/bosses.c
data/chr/common.c
data/chr/demo.c
data/chr/overworld_bg.c
data/chr/sprites.c
data/chr/underworld_bg.c
data/dmc_samples_wav/01_SFX_01.wav
data/dmc_samples_wav/02_SFX_02.wav
data/dmc_samples_wav/03_SFX_03.wav
data/dmc_samples_wav/04_SFX_04.wav
data/dmc_samples_wav/05_SFX_05.wav
data/dmc_samples_wav/06_SFX_06.wav
data/dmc_samples_wav/07_SFX_07.wav
data/enemies/MANIFEST.json
data/enemies/tables.c
data/fs/.gitkeep
data/fs/fs_asset_hashes.txt
data/fs/fs_bg_chr_full.c
data/fs/fs_border_chr.c
data/fs/fs_font_chr.c
data/fs/fs_heart_cursor_chr.c
data/fs/fs_link_sprite_chr.c
data/fs/fs_palette.c
data/fs/fs_static_attr.c
data/fs/fs_static_tilemap.c
data/intro/.gitkeep
data/intro/intro_art_chr.c
data/intro/intro_asset_hashes.txt
data/intro/intro_blink_chr.c
data/intro/intro_combined_palette.c
data/intro/intro_punct_chr.c
data/intro/intro_restore_chr.c
data/intro/intro_restore_palette.c
data/intro/intro_sprite_chr.c
data/intro/intro_story_tilemap.c
data/intro/intro_title_bg_chr.c
data/intro/intro_title_fade.c
data/intro/intro_title_glow.c
data/intro/intro_title_palette.c
data/intro/intro_title_sprite_chr.c
data/intro/intro_title_tilemap.c
data/intro/intro_treasures_tilemap.c
data/misc/MANIFEST.json
data/misc/item_tables.c
data/misc/palette_tables.c
data/misc/palettes.c
data/misc/person_text.c
data/misc/player_constants.c
data/misc/ui_layout.c
data/rooms/MANIFEST.json
data/rooms/dungeons.c
data/rooms/overworld.c
data/text/MANIFEST.json
data/text/demo_text.c
data/text/nes_frontend_credits.c
data/text/nes_frontend_demo_text.c
data/text/nes_frontend_palettes.c
data/text/nes_frontend_save.c
data/text/nes_frontend_text.c
data/text/nes_frontend_transfers.c
data/text/nes_frontend_ui.c
src/data/credits_text.inc
src/data/demo_text.inc
src/data/dmc_samples.bin
src/data/dmc_samples.inc
src/data/dmc_samples_pcm.bin
src/data/drop_tables.inc
src/data/enemy_tables.inc
src/data/frontend_palettes.inc
src/data/frontend_transfers.inc
src/data/frontend_ui.inc
src/data/item_tables.inc
src/data/level_info.inc
src/data/music_blob.dat
src/data/music_blob.inc
src/data/object_lists.inc
src/data/palette_tables.inc
src/data/palettes.inc
src/data/pcm_samples.inc
src/data/person_text.inc
src/data/player_constants.inc
src/data/room_columns.inc
src/data/room_common.inc
src/data/room_layouts.inc
src/data/room_patches.inc
src/data/rooms_overworld.inc
src/data/rooms_underworld1.inc
src/data/rooms_underworld2.inc
src/data/save_tables.inc
src/data/sfx.inc
src/data/song_scripts.inc
src/data/songs.inc
src/data/text.inc
src/data/tiles_bosses.inc
src/data/tiles_common.inc
src/data/tiles_demo.inc
src/data/tiles_overworld.inc
src/data/tiles_overworld_bg.inc
src/data/tiles_sprites.inc
src/data/tiles_underworld.inc
src/data/tiles_underworld_bg.inc
src/data/ui_layout.inc
src/gen/music_great_fairy.bin
src/gen/z_01.c
src/gen/z_02.c
src/gen/z_03.c
src/gen/z_04.c
src/gen/z_05.c
src/gen/z_06.c
src/gen/z_07.c

 succeeded in 1805ms:
[submodule "sgdk"]
	path = sgdk
	url = https://github.com/Stephane-D/SGDK


Count    : 47574
Average  : 
Sum      : 
Maximum  : 
Minimum  : 
Property : 

Count    : 164
Average  : 
Sum      : 
Maximum  : 
Minimum  : 
Property : 

Count    : 556
Average  : 
Sum      : 
Maximum  : 
Minimum  : 
Property : 




 succeeded in 1781ms:
builds/BUILDS.md
builds/EmuHawk.exe - Shortcut.lnk
builds/GENS SCREENIES.lnk
builds/NES SCREENIES.lnk
builds/Screenshots - Shortcut.lnk
builds/archive/Zelda16.1.lst
builds/archive/Zelda16.1.md
builds/archive/Zelda18.1.lst
builds/archive/Zelda18.1.md
builds/archive/Zelda19.1.lst
builds/archive/Zelda19.1.md
builds/archive/Zelda20.1.lst
builds/archive/Zelda20.1.md
builds/archive/Zelda21.1.lst
builds/archive/Zelda21.1.md
builds/archive/Zelda27.1.lst
builds/archive/Zelda27.1.md
builds/archive/Zelda27.10.lst
builds/archive/Zelda27.10.md
builds/archive/Zelda27.100.lst
builds/archive/Zelda27.100.md
builds/archive/Zelda27.101.lst
builds/archive/Zelda27.101.md
builds/archive/Zelda27.102.lst
builds/archive/Zelda27.102.md
builds/archive/Zelda27.103.lst
builds/archive/Zelda27.103.md
builds/archive/Zelda27.104.lst
builds/archive/Zelda27.104.md
builds/archive/Zelda27.105.lst
builds/archive/Zelda27.105.md
builds/archive/Zelda27.106.lst
builds/archive/Zelda27.106.md
builds/archive/Zelda27.107.lst
builds/archive/Zelda27.107.md
builds/archive/Zelda27.108.lst
builds/archive/Zelda27.108.md
builds/archive/Zelda27.109.lst
builds/archive/Zelda27.109.md
builds/archive/Zelda27.11.lst
builds/archive/Zelda27.11.md
builds/archive/Zelda27.110.lst
builds/archive/Zelda27.110.md
builds/archive/Zelda27.111.lst
builds/archive/Zelda27.111.md
builds/archive/Zelda27.112.lst
builds/archive/Zelda27.112.md
builds/archive/Zelda27.113.lst
builds/archive/Zelda27.113.md
builds/archive/Zelda27.114.lst
builds/reports/xnview_intro_continuity_compare/04_gen_1773.png
builds/reports/xnview_intro_continuity_compare/05_nes_2565.png
builds/reports/xnview_intro_continuity_compare/06_nes_2566.png
builds/reports/xnview_intro_continuity_compare/07_gen_2623.png
builds/reports/xnview_intro_continuity_compare/08_gen_2624.png
builds/reports/xnview_jump_compare/01_gen_f01468.png
builds/reports/xnview_jump_compare/02_gen_f01469.png
builds/reports/xnview_jump_compare/03_gen_f01470.png
builds/reports/xnview_jump_compare/04_gen_f01471.png
builds/reports/xnview_jump_compare/05_gen_f01468.png
builds/reports/xnview_jump_compare/06_gen_f01469.png
builds/reports/xnview_jump_compare/07_gen_f01470.png
builds/reports/xnview_jump_compare/08_gen_f01471.png
builds/reports/xnview_jump_compare/09_nes_f01411.png
builds/reports/xnview_jump_compare/10_nes_f01412.png
builds/reports/xnview_story_near_final_compare/01_nes_short_f01410.png
builds/reports/xnview_story_near_final_compare/02_gen_short_f01469.png
builds/reports/xnview_story_near_final_compare/03_nes_short_f01411.png
builds/reports/xnview_story_near_final_compare/04_gen_short_f01470.png
builds/reports/xnview_story_near_final_compare/05_nes_short_f01412.png
builds/reports/xnview_story_near_final_compare/06_gen_short_f01471.png
builds/reports/xnview_story_near_final_compare/07_nes_late_f02628.png
builds/reports/xnview_story_near_final_compare/08_gen_late_f02686.png
builds/reports/xnview_story_near_final_compare/09_nes_late_f02629.png
builds/reports/xnview_story_near_final_compare/10_gen_late_f02687.png
builds/whatif.elf
builds/whatif.lst
builds/whatif.md
builds/whatif.o
builds/whatif_prev.md

exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'git ls-files src/zelda_translated src/gen | ForEach-Object { $_ }; git ls-files src/zelda_translated src/gen | Measure-Object' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command "rg -n \"RAM\\(|OBJ\\(\" src RoomRom/src" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'git status --short --untracked-files=all | Select-Object -First 120' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'Get-ChildItem -LiteralPath tools -File -Filter *.py | Select-Object -ExpandProperty Name | Sort-Object | Select-Object -First 80; Get-ChildItem -LiteralPath tools -File -Filter *.lua | Select-Object -ExpandProperty Name | Sort-Object | Select-Object -First 80' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'Get-ChildItem -LiteralPath builds -Directory -Force | Sort-Object Name | Select-Object Name; Get-ChildItem -LiteralPath builds -File -Force | Sort-Object Name | Select-Object Name,Length' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
 succeeded in 817ms:
src\c_shims.asm:1110:; SplitRoomId — reads RAM($EB), returns D2=row (hi nibble), D3=col (lo nibble).
src\c_shims.asm:1282:; PostDebit — D0=amount. Adds to RAM($067E).
src\c_shims.asm:1291:; InitOneSimpleObject — D2=slot. Reads RAM($00/$01).
src\c_shims.asm:2227:; PlayEffect — D0=val. ORs into RAM($0603).
src\c_shims.asm:2236:; PlaySample — D0=val. ORs into RAM($0601).
src\c_shims.asm:2275:; TouchDoorWall — no args. Sets RAM($0E) = $FF.
src\abi\platform_abi.h:27:#define RAM(off) (nes_ram[(off)])
src\abi\platform_abi.h:32:#define OBJ(off, slot) (nes_ram[(off) + (slot)])
src\frontend\frontend_runtime.c:162:    if (RAM(0x042C) != 0) {
src\frontend\frontend_runtime.c:181:    RAM(0x083D) = 1;
src\frontend\frontend_runtime.c:183:    RAM(0x042B) = 1;
src\frontend\frontend_runtime.c:185:    RAM(0x00F6) = 0x10;          /* D0 was AND #$10 → BNE taken means bit4 set */
src\frontend\frontend_runtime.c:188:    RAM(0x0528) = 90;            /* delay timer */
src\frontend\frontend_runtime.c:211:        base = ((unsigned int)RAM(0x07) << 8) | RAM(0x06);
src\frontend\frontend_runtime.c:227:        base = ((unsigned int)RAM(0x0B) << 8) | RAM(0x0A);
src\frontend\frontend_runtime.c:231:        base = ((unsigned int)RAM(0x0D) << 8) | RAM(0x0C);
src\frontend\frontend_runtime.c:271:        base = ((unsigned int)RAM(0x05) << 8) | RAM(0x04);
src\frontend\frontend_runtime.c:283:    if (SUBMODE_VALUE == 0 && RAM(0x0528) == 0) {
src\frontend\frontend_runtime.c:312:    if (RAM(0x042C) != 0) {
src\frontend\frontend_runtime.c:331:    RAM(0x0300) = 35;
src\frontend\frontend_runtime.c:332:    RAM(0x0301) = 35;
src\frontend\frontend_runtime.c:334:        RAM(0x0302 + i) = kTitlePaletteTransferRecord[i];
src\frontend\frontend_runtime.c:336:    RAM(0x042E) = 0;
src\frontend\frontend_runtime.c:337:    RAM(0x042F) = 0;
src\frontend\frontend_runtime.c:339:        RAM(0x0412 + i) = 0;
src\frontend\frontend_runtime.c:340:        RAM(0x041F + i) = 0;
src\frontend\frontend_runtime.c:341:        RAM(0x0437 + i) = 0;
src\frontend\frontend_runtime.c:344:        RAM(0x00AC + i) = 0xFF;
src\frontend\frontend_runtime.c:357:    RAM(0x0300) = 35;
src\frontend\frontend_runtime.c:358:    RAM(0x0301) = 35;
src\frontend\frontend_runtime.c:360:        RAM(0x0302 + i) = kStoryPaletteTransferRecord[i];
src\frontend\frontend_runtime.c:363:        RAM(0x0412 + i) = 0;
src\frontend\frontend_runtime.c:364:        RAM(0x041F + i) = 0;
src\frontend\frontend_runtime.c:365:        RAM(0x0437 + i) = 0;
src\frontend\frontend_runtime.c:366:        RAM(0x0444 + i) = 0;
src\frontend\frontend_runtime.c:377:    unsigned char y = (unsigned char)(RAM(0x0420 + wave_idx) + 2);
src\frontend\frontend_runtime.c:379:    RAM(0x0420 + wave_idx) = y;
src\frontend\frontend_runtime.c:380:    RAM(0x0005) = y;
src\frontend\frontend_runtime.c:386:    RAM(0x0000) = tile_offset;
src\frontend\frontend_runtime.c:387:    RAM(0x0002) = (unsigned char)wave_idx;
src\frontend\frontend_runtime.c:392:        RAM(0x0201 + d3) = (unsigned char)(kWaterfallWaveTiles[d2] + tile_offset);
src\frontend\frontend_runtime.c:393:        RAM(0x0203 + d3) = kWaterfallSpriteXs[d2];
src\frontend\frontend_runtime.c:394:        RAM(0x0200 + d3) = y;
src\frontend\frontend_runtime.c:395:        RAM(0x0202 + d3) = 0x03;
src\frontend\frontend_runtime.c:401:    if (RAM(0x041F) == 0) {
src\frontend\frontend_runtime.c:402:        RAM(0x0420) = 0xB6;
src\frontend\frontend_runtime.c:403:        RAM(0x0421) = 0xC8;
src\frontend\frontend_runtime.c:404:        RAM(0x0422) = 0xD8;
src\frontend\frontend_runtime.c:405:        RAM(0x0423) = 0xC0;
src\frontend\frontend_runtime.c:406:        RAM(0x0424) = 0xD0;
src\frontend\frontend_runtime.c:407:        RAM(0x0425) = 0xDD;
src\frontend\frontend_runtime.c:408:        RAM(0x041F)++;
src\frontend\frontend_runtime.c:421:        unsigned char frame = RAM(0x0015) & 0x08;
src\frontend\frontend_runtime.c:422:        RAM(0x0201 + d3) = (unsigned char)(kWaterfallCrestTiles[d2] + frame);
src\frontend\frontend_runtime.c:423:        RAM(0x0200 + d3) = 0xA8;
src\frontend\frontend_runtime.c:424:        RAM(0x0203 + d3) = kWaterfallSpriteXs[d2];
src\frontend\frontend_runtime.c:425:        RAM(0x0202 + d3) = 0x03;
src\frontend\frontend_runtime.c:431:    RAM(0x041A)++;
src\frontend\frontend_runtime.c:432:    if (RAM(0x041A) == 0x39) {
src\frontend\frontend_runtime.c:433:        RAM(0x0011) = 0;
src\frontend\frontend_runtime.c:434:        RAM(0x041A) = 0;
src\frontend\frontend_runtime.c:435:        RAM(0x042C) = 0;
src\frontend\frontend_runtime.c:436:        RAM(0x042D) = 0;
src\core\core_runtime.c:20:    RAM(0x0028) = 0xC0;
src\core\core_runtime.c:27:    RAM(0x0605) = 0;
src\core\core_runtime.c:28:    RAM(0x0607) = 0;
src\core\core_runtime.c:33:    RAM(0x067E) = (unsigned char)(RAM(0x067E) + amount);
src\core\core_runtime.c:37:    OBJ_TYPE(slot) = RAM(0x00);
src\core\core_runtime.c:38:    RAM(0x0492 + slot) = 0;
src\core\core_runtime.c:39:    RAM(0x04BF + slot) = RAM(0x01);
src\core\core_runtime.c:45:    RAM(0x0028 + slot) = val;
src\core\core_runtime.c:48:    RAM(0x0492 + slot) = 0xFF;
src\core\core_runtime.c:71:    if (RAM(0x0029) == 0) {
src\core\core_runtime.c:77:    RAM(0x03BC + slot) = val;
src\core\core_runtime.c:79:        RAM(0x03BC + slot) >>= 1;
src\core\core_runtime.c:80:        RAM(0x0380 + slot)--;
src\core\core_runtime.c:81:        if (RAM(0x0380 + slot) == 0) {
src\core\core_runtime.c:90:    RAM(0x0485 + slot) = 0;
src\core\core_runtime.c:91:    RAM(0x04BF + slot) = 0x81;
src\core\core_runtime.c:95:    RAM(0x0071 + slot) = 72;
src\core\core_runtime.c:96:    RAM(0x0072 + slot) = 0xA8;
src\core\core_runtime.c:97:    RAM(0x0085 + slot) = y;
src\core\core_runtime.c:98:    RAM(0x0086 + slot) = y;
src\core\core_runtime.c:102:    RAM(0x0004) = (unsigned char)val;
src\core\core_runtime.c:103:    RAM(0x0005) = (unsigned char)val;
src\core\core_runtime.c:108:    RAM(0x067D) = (unsigned char)(RAM(0x067D) + val);
src\core\core_runtime.c:112:    unsigned int sum = (unsigned char)val + RAM(0x0000);
src\core\core_runtime.c:113:    RAM(0x0000) = (unsigned char)sum;
src\core\core_runtime.c:115:        RAM(0x0001)++;
src\core\core_runtime.c:121:    unsigned int sum = (unsigned char)val + RAM(0x0002);
src\core\core_runtime.c:122:    RAM(0x0002) = (unsigned char)sum;
src\core\core_runtime.c:124:        RAM(0x0003)++;
src\core\core_runtime.c:130:    unsigned int sum = (unsigned char)val + RAM(0x0004);
src\core\core_runtime.c:131:    RAM(0x0004) = (unsigned char)sum;
src\core\core_runtime.c:133:        RAM(0x0005)++;
src\core\core_runtime.c:139:    unsigned char y = RAM(0x0002);
src\core\core_runtime.c:140:    unsigned char x = RAM(0x0003);
src\core\core_runtime.c:141:    RAM(0x0000) = 0x20 | (y >> 6);
src\core\core_runtime.c:142:    RAM(0x0001) = ((y << 2) & 0xE0) | (x >> 3);
src\core\core_runtime.c:151:    RAM(0x0416) = 0;
src\core\core_runtime.c:167:    RAM(0x067D)++;
src\core\core_runtime.c:234:    RAM(0x0601) |= (unsigned char)val;
src\core\core_runtime.c:268:    RAM(0x0029) = 10;
src\core\core_runtime.c:273:    RAM(0x0002) = (unsigned char)val;
src\core\core_runtime.c:274:    RAM(0x0003) = 36;
src\core\core_runtime.c:278:    RAM(0x0341) = 0;
src\core\core_runtime.c:283:    if (RAM(0x003B) != 0) {
src\core\core_runtime.c:287:    RAM(0x003B) = 10;
src\core\core_runtime.c:291:    RAM(0x0001) = RAM(0x000A);
src\core\core_runtime.c:293:        if (corert_compare_hearts_to_containers() == RAM(0x0000)) {
src\core\core_runtime.c:303:        RAM(0x0001)--;
src\core\core_runtime.c:304:        if ((signed char)RAM(0x0001) < 0) {
src\core\core_runtime.c:316:    unsigned char lo = RAM(0x0004);
src\core\core_runtime.c:318:    RAM(0x0004) = (unsigned char)(lo - 1u);
src\core\core_runtime.c:320:        RAM(0x0005) = (unsigned char)(RAM(0x0005) - 1u);
src\core\core_runtime.c:346:    RAM(0x0028 + slot) = 0;
src\core\core_runtime.c:385:    RAM(0x04BF + slot) = 0x81;
src\core\core_runtime.c:390:    RAM(NES_ROOM_LAYOUT_SCRATCH) = 1;
src\core\core_runtime.c:391:    RAM(0x0028 + slot) = 0;
src\core\core_runtime.c:443:    if (RAM(0x0661) == 0) {
src\core\core_runtime.c:464:    RAM(0x0028 + slot) = 79;
src\game\hud\hud_runtime.c:14:    RAM(0x000D) = start_off;
src\game\hud\hud_runtime.c:15:    hearts = RAM(0x000E);
src\game\hud\hud_runtime.c:20:    RAM(0x000B) = start_off + 7;
src\game\hud\hud_runtime.c:25:            RAM(0x000B) = RAM(0x000D) + 0x12;
src\game\hud\hud_runtime.c:35:            unsigned char partial = RAM(0x000F);
src\game\hud\hud_runtime.c:45:        RAM(0x000C) = row_pos;
src\game\hud\hud_runtime.c:46:        TRANSFER_BUF_BYTE(RAM(0x000B)) = tile;
src\game\hud\hud_runtime.c:47:        RAM(0x000B)--;
src\game\hud\hud_runtime.c:48:        row_pos = (unsigned char)(RAM(0x000C) - 1);
src\game\hud\hud_runtime.c:53:    unsigned char base_off = RAM(0x0000);
src\game\hud\hud_runtime.c:54:    TRANSFER_BUF_BYTE(base_off) = RAM(0x0003);
src\game\hud\hud_runtime.c:55:    TRANSFER_BUF_BYTE(base_off - 1) = RAM(0x0002);
src\game\hud\hud_runtime.c:56:    TRANSFER_BUF_BYTE(base_off - 2) = RAM(0x0001);
src\game\hud\hud_runtime.c:62:    hundreds = RAM(0x0001);
src\game\hud\hud_runtime.c:65:    RAM(0x0001) = hundreds;
src\game\hud\hud_runtime.c:66:    if (RAM(0x0002) == 0x24)
src\game\hud\hud_runtime.c:67:        c_format_char_doublet(RAM(0x0003));
src\game\hud\hud_runtime.c:71:    RAM(0x0000) = buf_offset;
src\game\hud\hud_runtime.c:80:    RAM(0x000E) = LINK_HEARTS;
src\game\hud\hud_runtime.c:81:    RAM(0x000F) = LINK_PARTIAL_HEART;
src\game\hud\hud_runtime.c:84:    if (RAM(0x0664) != 0) {
src\game\hud\hud_runtime.c:85:        RAM(0x0000) = 33;
src\game\hud\hud_runtime.c:86:        RAM(0x0001) = 33;
src\game\hud\hud_runtime.c:90:        hudrt_format_decimal_count_byte_in_text_buf(RAM(0x066E), 33);
src\game\hud\hud_runtime.c:109:    if (RAM(0x067D) != 0) {
src\game\hud\hud_runtime.c:110:        RAM(0x067D)--;
src\game\combat\collision_runtime.c:281:            RAM(0x049E + slot) = next_tile;
src\game\cave\uw_person_runtime.c:55:    if (RAM(0x0671) != 0xFF)
src\game\cave\uw_person_runtime.c:213:        RAM(0x0083) = LifeOrMoneyItemXs[i];
src\game\cave\uw_person_runtime.c:214:        RAM(0x0097) = 0x98;
src\game\cave\uw_person_runtime.c:226:    RAM(0x065D) = 0;
src\game\cave\uw_person_runtime.c:237:            RAM(0x0083) = 120;
src\game\cave\uw_person_runtime.c:238:            RAM(0x0097) = 0x98;
src\save_menu_runtime.c:33:    unsigned char level = RAM(NES_CUR_LEVEL);
src\save_menu_runtime.c:89:    RAM(0x005D) = 127;
src\save_menu_runtime.c:112:    unsigned char level = RAM(NES_CUR_LEVEL);
src\save_menu_runtime.c:118:    unsigned char room_id = RAM(NES_CUR_ROOM_ID);
src\save_menu_runtime.c:120:    RAM(NES_TMP0) = low_x;
src\save_menu_runtime.c:134:    RAM(0x0253) = marker_x;
src\save_menu_runtime.c:137:    RAM(0x0250) = marker_y;
src\save_menu_runtime.c:139:    RAM(0x0251) = 62;
src\save_menu_runtime.c:140:    RAM(0x0252) = 0;
src\game\world\trap_runtime.c:93:        if (!RAM(0x0671)) return;
src\game\world\trap_runtime.c:94:        if (RAM(0x0671) & WORLD_TMP0) break;
src\state\world_state.h:7:#define WORLD_TMP0                     RAM(0x0000)
src\state\world_state.h:8:#define WORLD_TMP1                     RAM(0x0001)
src\state\world_state.h:9:#define WORLD_TMP2                     RAM(0x0002)
src\state\world_state.h:10:#define WORLD_TMP3                     RAM(0x0003)
src\state\world_state.h:12:#define LINK_DIR                       RAM(0x0098)
src\state\world_state.h:13:#define LINK_X                         RAM(NES_OBJ_X)
src\state\world_state.h:14:#define LINK_Y                         RAM(NES_OBJ_Y)
src\state\world_state.h:15:#define LINK_ACTION_TIMER              RAM(0x00AC)
src\state\world_state.h:16:#define CUR_ROOM_ID                    RAM(0x00EB)
src\state\world_state.h:17:#define PREV_ROOM_ID                   RAM(0x00EC)
src\state\world_state.h:19:#define WORLD_FADE_TIMER               RAM(0x0034)
src\state\world_state.h:20:#define WORLD_FADE_STEP                RAM(0x051C)
src\state\world_state.h:21:#define WORLD_MAZE_STEP                RAM(0x052F)
src\state\world_state.h:22:#define WORLD_SECRET_SFX               RAM(0x0602)
src\state\world_state.h:23:#define SFX_COMBAT                     RAM(0x0604)
src\state\world_state.h:25:#define TRANSFER_BUF_POS               RAM(0x0301)
src\state\world_state.h:26:#define TRANSFER_BUF_BYTE(off)         RAM(0x0302 + (off))
src\state\world_state.h:28:#define OBJ_DIR(slot)                  OBJ(0x0098, (slot))
src\state\world_state.h:29:#define OBJ_X(slot)                    OBJ(NES_OBJ_X, (slot))
src\state\world_state.h:30:#define OBJ_Y(slot)                    OBJ(NES_OBJ_Y, (slot))
src\state\world_state.h:31:#define OBJ_GRID_OFFSET(slot)          OBJ(NES_OBJ_GRID_OFFSET, (slot))
src\state\world_state.h:32:#define OBJ_POS_FRAC(slot)             OBJ(NES_OBJ_POS_FRAC, (slot))
src\state\world_state.h:33:#define OBJ_QSPD_FRAC(slot)            OBJ(NES_OBJ_QSPD_FRAC, (slot))
src\state\world_state.h:34:#define OBJ_STATUS_FLAGS(slot)         OBJ(0x04BF, (slot))
src\state\world_state.h:35:#define OBJ_STATE(slot)                OBJ(0x00AC, (slot))
src\state\world_state.h:36:#define OBJ_ANIM_TIMER(slot)           OBJ(0x03D0, (slot))
src\state\world_state.h:37:#define OBJ_MOVE_TIMER(slot)           OBJ(0x0028, (slot))
src\state\world_state.h:39:#define CANDLE_LIT_FLAG                RAM(0x0513)
src\game\enemies\enemy_block_runtime.c:8:#define ROOM_MONSTER_ALL_DEAD          RAM(0x034D)
src\game\enemies\enemy_block_runtime.c:9:#define ROOM_INPUT_DIR                 RAM(0x03F8)
src\game\enemies\enemy_block_runtime.c:10:#define ROOM_BLOCK_SECRET_FLAG         RAM(0x04CF)
src\game\enemies\enemy_block_runtime.c:15:#define WALLMASTER_MAJOR_MINOR_MIN     RAM(0x0001)  /* major coord minimum value  */
src\game\enemies\enemy_block_runtime.c:119:    RAM(0x00F7) = (unsigned char)(RAM(0x00F7) + 1);  /* block-push counter */
src\game\enemies\enemy_block_runtime.c:130:    unsigned char grid_off = OBJ(0x0394, slot);
src\game\enemies\enemy_block_runtime.c:141:    RAM(0x00F7) = (unsigned char)(RAM(0x00F7) + 1);  /* block-push counter */
src\game\world\sprite_runtime.c:11:    unsigned char idx = (unsigned char)(RAM(0x0341) + 1u);
src\game\world\sprite_runtime.c:15:        RAM(0x0341) = idx;
src\game\world\sprite_runtime.c:25:    RAM(0x0341) = idx;
src\game\world\sprite_runtime.c:35:    RAM(0x0342) = sprrt_cycle_sprite_index_in_a(RAM(0x0342));
src\state\trap_state.h:12:#define WHIRLWIND_ACTIVE_FLAG          RAM(0x0508)
src\state\trap_state.h:13:#define TELEPORT_ACTIVE_FLAG           RAM(0x0522)
src\state\trap_state.h:14:#define TELEPORT_LEVEL_INDEX           RAM(0x0523)
src\state\trap_state.h:15:#define WHIRLWIND_PREV_ROOM_ID         RAM(0x00EA)
src\state\trap_state.h:17:#define LINK_CELLAR_FLAG               RAM(0x005A)
src\state\trap_state.h:18:#define MODE_TIMER                     RAM(0x0011)
src\state\trap_state.h:19:#define SUBMODE_VALUE                  RAM(0x0013)
src\state\trap_state.h:21:#define OAM_HIDE_2                     RAM(0x0248)
src\state\trap_state.h:22:#define OAM_HIDE_3                     RAM(0x024C)
src\state\trap_state.h:24:#define RUPEE_STASH_FLAG               RAM(0x034E)
src\state\trap_state.h:25:#define TRAP_BASE_SLOT                 RAM(0x0340)
src\state\trap_state.h:26:#define PASSIVE_OBJ_FLAG               RAM(0x03F8)
src\state\trap_state.h:28:#define TRAP_RETURN_COORD(slot)        OBJ(0x0380, (slot))
src\game\world\progress_runtime.c:17:        RAM(0x0306 + j) = GanonColorTriples[color_index - 2 + j];
src\game\world\progress_runtime.c:89:        if (level != 9 && (RAM(0x0671) & LevelMasks[level - 1])) {
src\game\world\progress_runtime.c:109:        CUR_ROOM_FLAGS_PTR = RAM(0x007C + col_idx);
src\game\world\progress_runtime.c:127:        RAM(i) = SaveFileAAddressSets[end_idx];
src\game\world\progress_runtime.c:130:    RAM(0x000E) = 0x7F;
src\game\world\progress_runtime.c:131:    RAM(0x000F) = 0x06;
src\state\targeting_state.h:7:#define TARGET_DIR_ACCUM               RAM(0x0000)
src\state\targeting_state.h:8:#define TARGET_MIN_COORD               RAM(0x0001)
src\state\targeting_state.h:9:#define TARGET_MAX_COORD               RAM(0x0002)
src\state\targeting_state.h:10:#define TARGET_H_DIST                  RAM(0x0003)
src\state\targeting_state.h:11:#define TARGET_V_DIST                  RAM(0x0004)
src\state\targeting_state.h:12:#define TARGET_H_DIR                   RAM(0x000A)
src\state\targeting_state.h:13:#define TARGET_V_DIR                   RAM(0x000B)
src\state\item_state.h:7:#define ITEM_VALUE_SCRATCH              RAM(0x000A)
src\state\item_state.h:8:#define ITEM_LEVEL_RAW                 RAM(0x0010)
src\state\item_state.h:9:#define GAME_MODE                      RAM(0x0012)
src\state\item_state.h:11:#define ITEM_GOT_CLOCK_FLAG            RAM(0x04E5)
src\state\item_state.h:12:#define ITEM_FREEZE_FLAG               RAM(0x0506)
src\state\item_state.h:13:#define ITEM_PICKUP_ID                 RAM(0x0505)
src\state\item_state.h:15:#define ITEM_SFX_PRIMARY               RAM(0x0602)
src\state\item_state.h:16:#define ITEM_SFX_SECONDARY             RAM(0x0600)
src\state\item_state.h:18:#define LINK_RING_LEVEL                RAM(0x0662)
src\state\item_state.h:19:#define SAVE_SLOT_INDEX                RAM(0x0016)
src\state\item_state.h:20:#define LINK_BOMB_COUNT                RAM(0x0658)
src\state\item_state.h:21:#define LINK_ARROW_OR_ROD_LEVEL        RAM(0x0659)
src\state\item_state.h:22:#define LINK_CANDLE_LEVEL              RAM(0x065B)
src\state\item_state.h:23:#define LINK_MAX_HEARTS                RAM(0x067C)
src\state\item_state.h:25:#define INVENTORY_VALUE(slot)          RAM(0x0657 + (slot))
src\game\cave\cave_runtime.c:17:            RAM(i) = item & 0xC0;
src\game\cave\cave_runtime.c:98:    RAM(0x0305) = price_char;
src\game\cave\cave_runtime.c:141:        RAM(CAVE_TRANSFER_BUF_CHAR_BASE + (unsigned char)i) = TextboxCharTransferRecTemplate[(unsigned char)i];
src\game\cave\cave_runtime.c:144:        RAM(0x0303) = CAVE_TEXT_LINE_ADDR_LO;
src\game\cave\cave_runtime.c:153:    RAM(0x0305) = ch;
src\game\cave\cave_runtime.c:205:            RAM(0x0083) = CaveWareXs[i];
src\game\cave\cave_runtime.c:206:            RAM(0x0097) = 0x98;
src\game\cave\cave_runtime.c:214:        RAM(0x0083) = 48;
src\game\cave\cave_runtime.c:215:        RAM(0x0097) = 0xAB;
src\game\cave\cave_runtime.c:247:        if (RAM(0x0070) != CaveWareXs[i])
src\game\cave\cave_runtime.c:249:        dist = z01_abs((unsigned int)(unsigned char)(RAM(0x0084) - 0x98));
src\game\cave\cave_runtime.c:328:    if (!(state == 4 && (RAM(0x0015) & 1))) {
src\game\cave\cave_runtime.c:331:            if (RAM(0x0656) == 0x0F && (CAVE_LINK_INPUT_FLAGS & 0x40)) {
src\game\cave\cave_runtime.c:332:                RAM(0x0602) = 4;
src\game\cave\cave_runtime.c:334:                RAM(0x0656) = 7;
src\game\cave\cave_runtime.c:357:    if (RAM(0x03A8 + slot) >= 0xF0) {
src\game\cave\cave_runtime.c:361:        unsigned char dy = (unsigned char)(RAM(0x0084) + 3 - OBJ_Y(slot));
src\game\cave\cave_runtime.c:367:        unsigned char dx = (unsigned char)(RAM(0x0070) - OBJ_X(slot));
src\game\world\object_runtime.c:4:    if (RAM(NES_OBJ_DIR) & dir_bit)
src\game\world\object_runtime.c:5:        RAM(NES_OBJ_DIR) = 0;
src\game\world\object_runtime.c:20:    RAM(NES_POS_GRID_LIMIT) = pos_limit;
src\game\world\object_runtime.c:21:    RAM(NES_NEG_GRID_LIMIT) = neg_limit;
src\game\world\object_runtime.c:23:    dir = RAM(NES_OBJ_DIR);
src\game\world\object_runtime.c:29:            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
src\game\world\object_runtime.c:30:            frac = (unsigned char)(old_frac + OBJ(NES_OBJ_QSPD_FRAC, slot));
src\game\world\object_runtime.c:32:            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
src\game\world\object_runtime.c:33:            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
src\game\world\object_runtime.c:34:            if (grid_off == RAM(NES_POS_GRID_LIMIT) || grid_off == RAM(NES_NEG_GRID_LIMIT))
src\game\world\object_runtime.c:36:            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off + step);
src\game\world\object_runtime.c:37:            OBJ(NES_OBJ_X, slot) += step;
src\game\world\object_runtime.c:39:            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
src\game\world\object_runtime.c:40:            speed = OBJ(NES_OBJ_QSPD_FRAC, slot);
src\game\world\object_runtime.c:43:            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
src\game\world\object_runtime.c:44:            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
src\game\world\object_runtime.c:45:            if (grid_off == RAM(NES_POS_GRID_LIMIT) || grid_off == RAM(NES_NEG_GRID_LIMIT))
src\game\world\object_runtime.c:47:            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off - step);
src\game\world\object_runtime.c:48:            OBJ(NES_OBJ_X, slot) -= step;
src\game\world\object_runtime.c:50:            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
src\game\world\object_runtime.c:51:            frac = (unsigned char)(old_frac + OBJ(NES_OBJ_QSPD_FRAC, slot));
src\game\world\object_runtime.c:53:            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
src\game\world\object_runtime.c:54:            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
src\game\world\object_runtime.c:55:            if (grid_off == RAM(NES_POS_GRID_LIMIT) || grid_off == RAM(NES_NEG_GRID_LIMIT))
src\game\world\object_runtime.c:57:            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off + step);
src\game\world\object_runtime.c:58:            OBJ(NES_OBJ_Y, slot) += step;
src\game\world\object_runtime.c:60:            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
src\game\world\object_runtime.c:61:            speed = OBJ(NES_OBJ_QSPD_FRAC, slot);
src\game\world\object_runtime.c:64:            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
src\game\world\object_runtime.c:65:            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
src\game\world\object_runtime.c:66:            if (grid_off == RAM(NES_POS_GRID_LIMIT) || grid_off == RAM(NES_NEG_GRID_LIMIT))
src\game\world\object_runtime.c:68:            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off - step);
src\game\world\object_runtime.c:69:            OBJ(NES_OBJ_Y, slot) -= step;
src\game\world\object_runtime.c:75:    unsigned char x = RAM(NES_OBJ_X + slot);
src\game\world\object_runtime.c:76:    RAM(NES_TMP0) = x;
src\game\world\object_runtime.c:77:    if (slot != 0 && (slot >= 0x0D || RAM(NES_OBJ_TYPE + slot) == 0x5C))
src\game\world\object_runtime.c:78:        RAM(NES_TMP0) = (unsigned char)(x + 0x0B);
src\game\world\object_runtime.c:79:    if (RAM(NES_TMP0) < RAM(NES_BOUND_LEFT)) {
src\game\world\object_runtime.c:83:    if (slot != 0 && (slot >= 0x0D || RAM(NES_OBJ_TYPE + slot) == 0x5C))
src\game\world\object_runtime.c:84:        RAM(NES_TMP0) = (unsigned char)(RAM(NES_TMP0) - 0x17);
src\game\world\object_runtime.c:85:    if (RAM(NES_TMP0) >= RAM(NES_BOUND_RIGHT))
src\game\world\object_runtime.c:90:    unsigned char y = RAM(NES_OBJ_Y + slot);
src\game\world\object_runtime.c:91:    RAM(NES_TMP0) = y;
src\game\world\object_runtime.c:92:    if (slot != 0 && (slot >= 0x0D || RAM(NES_OBJ_TYPE + slot) == 0x5C))
src\game\world\object_runtime.c:93:        RAM(NES_TMP0) = (unsigned char)(y + 0x0F);
src\game\world\object_runtime.c:94:    if (RAM(NES_TMP0) < RAM(NES_BOUND_TOP)) {
src\game\world\object_runtime.c:98:    if (slot != 0 && (slot >= 0x0D || RAM(NES_OBJ_TYPE + slot) == 0x5C))
src\game\world\object_runtime.c:99:        RAM(NES_TMP0) = (unsigned char)(RAM(NES_TMP0) - 0x21);
src\game\world\object_runtime.c:100:    if (RAM(NES_TMP0) >= RAM(NES_BOUND_BOTTOM))
src\game\world\object_runtime.c:107:    return RAM(NES_OBJ_DIR);
src\game\world\object_runtime.c:111:    RAM(NES_OBJ_DIR) = direction;
src\game\world\object_runtime.c:116:    unsigned int result = (unsigned int)RAM(NES_OBJ_POS_FRAC + slot) + RAM(NES_OBJ_QSPD_FRAC + slot);
src\game\world\object_runtime.c:117:    RAM(NES_OBJ_POS_FRAC + slot) = (unsigned char)result;
src\game\world\object_runtime.c:119:    unsigned char grid = RAM(NES_OBJ_GRID_OFFSET + slot);
src\game\world\object_runtime.c:120:    if (grid == RAM(NES_POS_GRID_LIMIT) || grid == RAM(NES_NEG_GRID_LIMIT))
src\game\world\object_runtime.c:122:    RAM(NES_OBJ_GRID_OFFSET + slot) = (unsigned char)(grid + (unsigned char)carry);
src\game\world\object_runtime.c:127:    unsigned int frac = RAM(NES_OBJ_POS_FRAC + slot);
src\game\world\object_runtime.c:128:    unsigned int sub_val = RAM(NES_OBJ_QSPD_FRAC + slot);
src\game\world\object_runtime.c:130:    RAM(NES_OBJ_POS_FRAC + slot) = (unsigned char)(frac - sub_val);
src\game\world\object_runtime.c:131:    unsigned char grid = RAM(NES_OBJ_GRID_OFFSET + slot);
src\game\world\object_runtime.c:132:    if (grid == RAM(NES_POS_GRID_LIMIT) || grid == RAM(NES_NEG_GRID_LIMIT))
src\game\world\object_runtime.c:134:    RAM(NES_OBJ_GRID_OFFSET + slot) = (unsigned char)(grid - (unsigned char)borrow);
src\game\world\object_runtime.c:141:        RAM(NES_SHOT_COLLISION_FLAG) = 0x80;
src\game\world\object_runtime.c:144:    unsigned char saved_offset = RAM(NES_OBJ_GRID_OFFSET + slot);
src\game\world\object_runtime.c:145:    RAM(NES_OBJ_GRID_OFFSET + slot) = 0;
src\game\world\object_runtime.c:147:    unsigned char new_offset = RAM(NES_OBJ_GRID_OFFSET + slot);
src\game\world\object_runtime.c:148:    if (RAM(NES_SHOT_COLLISION_FLAG) == 0)
src\game\world\object_runtime.c:149:        RAM(NES_OBJ_GRID_OFFSET + slot) = (unsigned char)(saved_offset + new_offset);
src\game\world\object_runtime.c:151:        RAM(NES_OBJ_GRID_OFFSET + slot) = saved_offset;
src\state\combat_state.h:9:#define COMBAT_WEAPON_SLOT              RAM(0x0000)
src\state\combat_state.h:10:#define COMBAT_HITBOX_X                 RAM(0x0004)
src\state\combat_state.h:11:#define COMBAT_HITBOX_Y                 RAM(0x0005)
src\state\combat_state.h:12:#define COMBAT_COLLIDED                 RAM(0x0006)
src\state\combat_state.h:13:#define COMBAT_DAMAGE_AMOUNT            RAM(0x0007)
src\state\combat_state.h:14:#define COMBAT_SHOVE_DIR                RAM(0x0008)
src\state\combat_state.h:15:#define COMBAT_DAMAGE_TYPE              RAM(0x0009)
src\state\combat_state.h:16:#define COMBAT_ABS_DX                   RAM(0x000A)
src\state\combat_state.h:17:#define COMBAT_ABS_DY                   RAM(0x000B)
src\state\combat_state.h:18:#define COMBAT_HARM_FLAG                RAM(0x000C)
src\state\combat_state.h:19:#define COMBAT_THRESHOLD_X              RAM(0x000D)
src\state\combat_state.h:20:#define COMBAT_THRESHOLD_Y              RAM(0x000E)
src\state\combat_state.h:21:#define COMBAT_PART_INDEX               RAM(0x000F)
src\state\combat_state.h:23:#define LINK_ACTION_TIMER               RAM(0x00AC)
src\state\combat_state.h:24:#define LINK_DIR                        RAM(0x0098)
src\state\combat_state.h:25:#define LINK_DAMAGE_DISABLE_FLAG        RAM(0x0512)
src\state\combat_state.h:26:#define LINK_STUN_TIMER                 RAM(0x04F0)
src\state\combat_state.h:27:#define LINK_RING_LEVEL                 RAM(0x0662)
src\state\combat_state.h:28:#define LINK_HEARTS                     RAM(0x066F)
src\state\combat_state.h:29:#define LINK_PARTIAL_HEART              RAM(0x0670)
src\state\combat_state.h:30:#define LINK_SHIELD_BLOCK_FLAG          RAM(0x0676)
src\state\combat_state.h:32:#define ROOM_KILL_COUNT                 RAM(0x0627)
src\state\combat_state.h:33:#define ROOM_CHAIN_KILL_COUNT           RAM(0x0050)
src\state\combat_state.h:34:#define ROOM_CHAIN_KILL_BONUS           RAM(0x0051)
src\state\combat_state.h:35:#define ROOM_MONSTER_COLLISION_COUNT    RAM(0x034B)
src\state\combat_state.h:36:#define SFX_COMBAT                      RAM(0x0604)
src\state\combat_state.h:38:#define OBJ_STATE(slot)                 OBJ(0x00AC, (slot))
src\state\combat_state.h:39:#define OBJ_DIR(slot)                   OBJ(0x0098, (slot))
src\state\combat_state.h:40:#define OBJ_X(slot)                     OBJ(NES_OBJ_X, (slot))
src\state\combat_state.h:41:#define OBJ_Y(slot)                     OBJ(NES_OBJ_Y, (slot))
src\state\combat_state.h:42:#define OBJ_GRID_OFFSET(slot)           OBJ(NES_OBJ_GRID_OFFSET, (slot))
src\state\combat_state.h:43:#define OBJ_ANIM_TIMER(slot)            OBJ(0x03D0, (slot))
src\state\combat_state.h:45:#define MON_TYPE(slot)                  OBJ(NES_OBJ_TYPE, (slot))
src\state\combat_state.h:46:#define MON_STATUS_FLAGS(slot)          OBJ(0x04BF, (slot))
src\state\combat_state.h:47:#define MON_INVINCIBILITY(slot)         OBJ(0x04B2, (slot))
src\state\combat_state.h:48:#define MON_HIT_REACTION(slot)          OBJ(0x04F0, (slot))
src\state\combat_state.h:49:#define MON_METASTATE(slot)             OBJ(0x0405, (slot))
src\state\combat_state.h:50:#define MON_STUN_TIMER(slot)            OBJ(0x003D, (slot))
src\state\combat_state.h:51:#define MON_SHOVE_DIR(slot)             OBJ(0x00C0, (slot))
src\state\combat_state.h:52:#define MON_SHOVE_TIMER(slot)           OBJ(0x00D3, (slot))
src\state\combat_state.h:53:#define MON_HP(slot)                    OBJ(0x0485, (slot))
src\state\combat_state.h:54:#define MON_SUBSTATE(slot)              OBJ(0x046B, (slot))
src\state\combat_state.h:55:#define MON_BOUNCE_TURNS(slot)          OBJ(0x042C, (slot))
src\state\combat_state.h:57:#define ITEM_SWORD_LEVEL                RAM(0x0657)
src\state\combat_state.h:58:#define ITEM_ARROW_OR_ROD_LEVEL         RAM(0x0659)
src\state\sprite_state.h:10:#define OAM_BYTE(i)        RAM(NES_OAM_BASE + (unsigned short)(i))
src\state\sprite_state.h:11:#define OAM_SPRITE_Y(n)    RAM(NES_OAM_BASE + ((unsigned short)(n) * 4) + 0)
src\state\sprite_state.h:12:#define OAM_SPRITE_TILE(n) RAM(NES_OAM_BASE + ((unsigned short)(n) * 4) + 1)
src\state\sprite_state.h:13:#define OAM_SPRITE_ATTR(n) RAM(NES_OAM_BASE + ((unsigned short)(n) * 4) + 2)
src\state\sprite_state.h:14:#define OAM_SPRITE_X(n)    RAM(NES_OAM_BASE + ((unsigned short)(n) * 4) + 3)
src\state\cave_state.h:9:#define CAVE_TMP0                        RAM(0x0000)
src\state\cave_state.h:10:#define CAVE_TMP1                        RAM(0x0001)
src\state\cave_state.h:11:#define CAVE_TMP2                        RAM(0x0002)
src\state\cave_state.h:12:#define CAVE_TMP3                        RAM(0x0003)
src\state\cave_state.h:13:#define CAVE_TMP4                        RAM(0x0004)
src\state\cave_state.h:14:#define CAVE_RANDOM_A                    RAM(0x0019)
src\state\cave_state.h:15:#define CAVE_RANDOM_B                    RAM(0x001A)
src\state\cave_state.h:16:#define CAVE_DELAY_TIMER                 RAM(0x0029)
src\state\cave_state.h:17:#define CAVE_LINK_ACTION_TIMER           RAM(0x00AC)
src\state\cave_state.h:18:#define CAVE_PERSON_STATE                RAM(0x00AD)
src\state\cave_state.h:19:#define CAVE_LINK_INPUT_FLAGS            RAM(0x00F8)
src\state\cave_state.h:20:#define CAVE_ROOM_TYPE                   RAM(0x0350)
src\state\cave_state.h:21:#define CAVE_FLAGS                       RAM(0x0413)
src\state\cave_state.h:22:#define CAVE_TEXT_SELECTOR               RAM(0x0415)
src\state\cave_state.h:23:#define CAVE_TEXT_CHAR_INDEX             RAM(0x0416)
src\state\cave_state.h:24:#define CAVE_ACTIVE_WARE_INDEX           RAM(0x0421)
src\state\cave_state.h:25:#define CAVE_WARE_ITEM(idx)              RAM(0x0422 + (idx))
src\state\cave_state.h:26:#define CAVE_TRANSFER_PRICE_COUNT        RAM(0x042E)
src\state\cave_state.h:27:#define CAVE_TRANSFER_PRICE_OFFSET       RAM(0x042F)
src\state\cave_state.h:28:#define CAVE_PRICE(idx)                  RAM(0x0430 + (idx))
src\state\cave_state.h:29:#define CAVE_SELECTED_WARE_INDEX         RAM(0x0438)
src\state\cave_state.h:30:#define CAVE_PRIZE_ORDER(idx)            RAM(0x0448 + (idx))
src\state\cave_state.h:31:#define CAVE_TEXT_LINE_ADDR_LO           RAM(0x045F)
src\state\cave_state.h:32:#define CAVE_MONEY_GAME_PERM(idx)        RAM(0x046C + (idx))
src\state\cave_state.h:33:#define CAVE_MONEY_GAME_AMOUNT(idx)      RAM(0x046F + (idx))
src\state\cave_state.h:34:#define CAVE_TEXT_TICK_SFX               RAM(0x0604)
src\state\cave_state.h:35:#define LINK_RUPEES                      RAM(0x066D)
src\state\cave_state.h:36:#define CAVE_ROOM_SCRIPT_STATE           RAM(0x0666)
src\state\cave_state.h:37:#define CAVE_DOOR_REPAIR_RUPEE_DELTA     RAM(0x067E)
src\state\cave_state.h:40:#define CAVE_TRANSFER_BUF_PRICE_SIGN(off) RAM(0x0306 + (off))
src\state\cave_state.h:41:#define CAVE_TRANSFER_BUF_PRICE_HUNDREDS(off) RAM(0x0307 + (off))
src\state\cave_state.h:42:#define CAVE_TRANSFER_BUF_PRICE_TENS(off) RAM(0x0308 + (off))
src\state\cave_state.h:43:#define CAVE_TRANSFER_BUF_PRICE_UNITS(off) RAM(0x0309 + (off))
src\state\enemy_state.h:9:#define ENEMY_DIR(slot)                 OBJ(0x0098, (slot))
src\state\enemy_state.h:10:#define ENEMY_STATE_TIMER(slot)         OBJ(0x00AC, (slot))
src\state\enemy_state.h:11:#define ENEMY_LIFE(slot)                OBJ(0x00BF, (slot))
src\state\enemy_state.h:12:#define ENEMY_X(slot)                   OBJ(NES_OBJ_X, (slot))
src\state\enemy_state.h:13:#define ENEMY_Y(slot)                   OBJ(NES_OBJ_Y, (slot))
src\state\enemy_state.h:14:#define ENEMY_RNG_A(slot)               OBJ(0x0018, (slot))
src\state\enemy_state.h:15:#define ENEMY_RNG_B(slot)               OBJ(0x0019, (slot))
src\state\enemy_state.h:16:#define ENEMY_MOVE_TIMER(slot)          OBJ(0x0028, (slot))
src\state\enemy_state.h:17:#define ENEMY_STUN_TIMER(slot)          OBJ(0x003D, (slot))
src\state\enemy_state.h:18:#define ENEMY_TYPE(slot)                OBJ(NES_OBJ_TYPE, (slot))
src\state\enemy_state.h:19:#define ENEMY_METASTATE(slot)           OBJ(0x0405, (slot))
src\state\enemy_state.h:20:#define ENEMY_PUSH_TIMER(slot)          OBJ(0x0412, (slot))
src\state\enemy_state.h:21:#define ENEMY_FLYER_SPEED_FRAC(slot)    OBJ(0x0412, (slot))
src\state\enemy_state.h:22:#define ENEMY_AIR_SPEED(slot)           OBJ(0x041F, (slot))
src\state\enemy_state.h:23:#define ENEMY_TURN_TIMER(slot)          OBJ(0x042C, (slot))
src\state\enemy_state.h:24:#define ENEMY_FLAP_PHASE(slot)          OBJ(0x0437, (slot))
src\state\enemy_state.h:25:#define ENEMY_AI_STATE(slot)            OBJ(0x0444, (slot))
src\state\enemy_state.h:26:#define ENEMY_BLOATED_TIMER(slot)       OBJ(0x045E, (slot))
src\state\enemy_state.h:27:#define ENEMY_FLYER_X_FINE(slot)        OBJ(0x046B, (slot))
src\state\enemy_state.h:28:#define ENEMY_BOUNCE_FLAGS(slot)        OBJ(0x0478, (slot))
src\state\enemy_state.h:29:#define ENEMY_FLYER_Y_FINE(slot)        OBJ(0x0478, (slot))
src\state\enemy_state.h:30:#define ENEMY_CHARGE_SPEED(slot)        OBJ(0x0485, (slot))
src\state\enemy_state.h:31:#define ENEMY_COLLIDED_TILE(slot)       OBJ(0x049E, (slot))
src\state\enemy_state.h:32:#define ENEMY_INVINCIBILITY(slot)       OBJ(0x04B2, (slot))
src\state\enemy_state.h:33:#define ENEMY_MAX_AIR_SPEED             RAM(0x04D1)
src\state\enemy_state.h:34:#define ENEMY_HIT_REACTION(slot)        OBJ(0x04F0, (slot))
src\state\enemy_state.h:35:#define ENEMY_ALIVE_FLAG(slot)          OBJ(0x0492, (slot))
src\state\enemy_state.h:36:#define ENEMY_DRAW_FRAME(slot)          OBJ(0x03E4, (slot))
src\state\enemy_state.h:37:#define ENEMY_WALK_SPEED(slot)          OBJ(0x03BC, (slot))
src\state\enemy_state.h:38:#define ENEMY_ANIM_TIMER(slot)          OBJ(0x03D0, (slot))
src\state\enemy_state.h:39:#define ENEMY_PUSH_DIR_SCRATCH(slot)    OBJ(0x03F8, (slot))
src\state\enemy_state.h:40:#define ENEMY_SHOT_COUNT                RAM(0x034C)
src\state\enemy_state.h:41:#define ENEMY_ROOM_MONSTER_FLAG         RAM(0x0514)
src\state\enemy_state.h:42:#define ENEMY_OAM_HIDE_0                RAM(0x0240)
src\state\enemy_state.h:43:#define ENEMY_OAM_HIDE_1                RAM(0x0244)
src\state\enemy_state.h:44:#define ENEMY_SFX_SECRET                RAM(0x0602)
src\state\enemy_state.h:45:#define ENEMY_SFX_BOSS_CRY              RAM(0x0601)
src\state\enemy_state.h:46:#define ENEMY_SFX_BOSS_CRY_FLAGS        RAM(0x0603)
src\state\enemy_state.h:47:#define ENEMY_SFX_PARRY                 RAM(0x0604)
src\state\enemy_state.h:48:#define ENEMY_BOULDER_SET_COUNT         RAM(0x0515)
src\state\enemy_state.h:49:#define ENEMY_CANDLE_FADE_TRIGGER       RAM(0x051C)
src\state\enemy_state.h:50:#define ENEMY_CANDLE_FADE_PHASE         RAM(0x051E)
src\state\enemy_state.h:51:#define ENEMY_CANDLE_STATE              RAM(0x051F)
src\state\enemy_state.h:52:#define ENEMY_CANDLE_ROOM_ID            RAM(0x00EB)
src\state\enemy_state.h:53:#define ENEMY_PAUSE_FLAG                RAM(0x066C)
src\state\enemy_state.h:54:#define ENEMY_FREEZE_FLAG               RAM(0x0506)
src\state\enemy_state.h:55:#define ENEMY_COLLISION_FLAG            RAM(0x0006)
src\state\enemy_state.h:56:#define ENEMY_BLOCKED_FLAG              RAM(0x000E)
src\state\enemy_state.h:57:#define ENEMY_BUBBLE_EFFECT             RAM(0x004C)
src\state\enemy_state.h:58:#define ENEMY_LEEVER_TIMER              RAM(0x004D)
src\state\enemy_state.h:59:#define ENEMY_BUBBLE_STATUS             RAM(0x052E)
src\state\enemy_state.h:61:#define LINK_X                          RAM(0x0061)
src\state\enemy_state.h:64:#define LINK_Y                          RAM(0x0062)
src\state\enemy_state.h:66:#define SAVE_SLOT_INDEX                 RAM(0x0016)
src\state\enemy_state.h:67:#define SAVE_SLOT_QUEST(slot)           RAM(0x062D + (slot))
src\state\enemy_state.h:68:#define ENEMY_GLEEOK_HEAD_TIMER         RAM(0x0418)
src\state\enemy_state.h:69:#define ENEMY_GLEEOK_SEG_X(slot)        OBJ(0x0072, (slot))
src\state\enemy_state.h:70:#define ENEMY_GLEEOK_SEG_X_TARGET(slot) OBJ(0x0073, (slot))
src\state\enemy_state.h:71:#define ENEMY_GLEEOK_SEG_Y(slot)        OBJ(0x0086, (slot))
src\state\enemy_state.h:72:#define ENEMY_GLEEOK_SEG_Y_TARGET(slot) OBJ(0x0087, (slot))
src\state\enemy_state.h:73:#define ENEMY_MANHANDLA_SEGMENT_DIED_FLAG RAM(0x0383)
src\state\enemy_state.h:74:#define ENEMY_MANHANDLA_FRAME_ACCUM(slot) OBJ(0x0451, (slot))
src\state\enemy_state.h:75:#define ENEMY_MANHANDLA_FRAME_ATTR(slot)  OBJ(0x0478, (slot))
src\state\enemy_state.h:76:#define ENEMY_LAMNOLA_SPEED             RAM(0x04E6)
src\state\enemy_state.h:77:#define ENEMY_LAMNOLA_TYPE              RAM(0x04E7)
src\state\enemy_state.h:78:#define ENEMY_LAMNOLA_VIABLE_DIR_MASK   RAM(0x050F)
src\state\enemy_state.h:79:#define ENEMY_PLAYER_OBJ_X              RAM(0x0070)
src\state\enemy_state.h:80:#define ENEMY_PLAYER_OBJ_Y              RAM(0x0084)
src\state\enemy_state.h:81:#define ENEMY_VIRE_SPLIT_TYPE           RAM(0x0000)
src\state\enemy_state.h:82:#define ENEMY_STATUE_PERSON_FIREBALLS   RAM(0x04CC)
src\state\enemy_state.h:83:#define ENEMY_STATUE_FIREBALL_TIMER(idx) RAM(0x04E8 + (idx))
src\state\enemy_state.h:84:#define ENEMY_JUMPER_TARGET_Y(slot)     OBJ(0x0444, (slot))
src\state\enemy_state.h:85:#define ENEMY_JUMPER_REVERSALS(slot)    OBJ(0x0451, (slot))
src\state\enemy_state.h:86:#define ENEMY_JUMPER_VSPEED_HI(slot)    OBJ(0x0412, (slot))
src\state\enemy_state.h:87:#define ENEMY_JUMPER_VSPEED_LO(slot)    OBJ(0x041F, (slot))
src\state\enemy_state.h:88:#define ENEMY_JUMPER_SHOVE(slot)        OBJ(0x00C0, (slot))
src\state\enemy_state.h:89:#define ENEMY_JUMPER_BLOCKED_FLAG       RAM(0x000F)
src\state\enemy_state.h:91:#define ENEMY_GLEEOK_NECK_INDEX         RAM(0x04D7)
src\state\enemy_state.h:92:#define ENEMY_GLEEOK_REF_SEG_DIST       RAM(0x04D8)
src\state\enemy_state.h:93:#define ENEMY_GLEEOK_REF_LIMIT_H_3      RAM(0x04DD)
src\state\enemy_state.h:94:#define ENEMY_GLEEOK_REF_LIMIT_V_3      RAM(0x04DE)
src\state\enemy_state.h:95:#define ENEMY_GLEEOK_WRITHE_CNTR        RAM(0x04E6)
src\state\enemy_state.h:96:#define ENEMY_GLEEOK_ANIM_CNTR          RAM(0x0510)
src\state\enemy_state.h:97:#define ENEMY_GLEEOK_DEAD_NECK_MASK     RAM(0x0511)
src\state\enemy_state.h:98:#define ENEMY_GLEEOK_HEAD_X             RAM(0x0075)   /* OBJ(0x70, 5) */
src\state\enemy_state.h:99:#define ENEMY_GLEEOK_HEAD_Y             RAM(0x0089)   /* OBJ(0x84, 5) */
src\state\enemy_state.h:100:#define ENEMY_GLEEOK_BASE_X             RAM(0x0071)   /* OBJ(0x70, 1) */
src\state\enemy_state.h:101:#define ENEMY_GLEEOK_BASE_Y             RAM(0x0085)   /* OBJ(0x84, 1) */
src\state\enemy_state.h:102:#define ENEMY_OBJ_SHOVE_DIR(slot)       OBJ(0x00C0, (slot))
src\state\enemy_state.h:103:#define ENEMY_GOHMA_GO_STRAIGHT(slot)   OBJ(0x0451, (slot))
src\state\enemy_state.h:104:#define ENEMY_GOHMA_DIST_TRAVELED(slot) OBJ(0x0412, (slot))   /* aliases ENEMY_PUSH_TIMER */
src\state\enemy_state.h:105:#define ENEMY_GOHMA_OPEN_EYE_TIMER(slot)   OBJ(0x0444, (slot))   /* aliases ENEMY_AI_STATE */
src\state\enemy_state.h:106:#define ENEMY_GOHMA_NEXT_OPEN_EYE(slot)    OBJ(0x042C, (slot))   /* aliases ENEMY_TURN_TIMER */
src\state\enemy_state.h:107:#define ENEMY_GOHMA_SPRINTS(slot)          OBJ(0x045E, (slot))   /* aliases ENEMY_BLOATED_TIMER */
src\state\enemy_state.h:108:#define ENEMY_GOHMA_EYE_FRAME(slot)        OBJ(0x046B, (slot))
src\state\enemy_state.h:109:#define ENEMY_GOHMA_CLOSED_EYE_CNTR(slot)  OBJ(0x0478, (slot))   /* aliases ENEMY_BOUNCE_FLAGS */
src\state\enemy_state.h:110:#define ENEMY_GOHMA_SHOOT_TIMER(slot)      OBJ(0x0380, (slot))   /* aliases ENEMY_BOSS_HP_PHASE */
src\state\enemy_state.h:111:#define ENEMY_GOHMA_MOVE_ACCUM(slot)       OBJ(0x041F, (slot))   /* aliases ENEMY_AIR_SPEED */
src\state\enemy_state.h:113:#define ENEMY_GLEEOK_NECK_X_PTR_LO      RAM(0x0000)
src\state\enemy_state.h:114:#define ENEMY_GLEEOK_NECK_X_PTR_HI      RAM(0x0001)
src\state\enemy_state.h:115:#define ENEMY_GLEEOK_NECK_Y_PTR_LO      RAM(0x0002)
src\state\enemy_state.h:116:#define ENEMY_GLEEOK_NECK_Y_PTR_HI      RAM(0x0003)
src\state\enemy_state.h:117:#define ENEMY_GLEEOK_NECK_M_PTR_LO      RAM(0x0004)
src\state\enemy_state.h:118:#define ENEMY_GLEEOK_NECK_M_PTR_HI      RAM(0x0005)
src\state\enemy_state.h:119:#define NES_RAM_BASE                    0x0000u  /* RAM() already adds the FF0000 base */
src\state\enemy_state.h:120:#define ENEMY_MANHANDLA_SEG_DIR(slot)   OBJ(0x0099, (slot))
src\state\enemy_state.h:121:#define ENEMY_DARK_ROOM_FLAG            RAM(0x0010)
src\state\enemy_state.h:122:#define ENEMY_THROWER_SLOT              RAM(0x0340)
src\state\enemy_state.h:123:#define ENEMY_NEXT_SHOT_SLOT            RAM(0x0059)
src\state\enemy_state.h:124:#define ENEMY_SHOT_TYPE_SCRATCH         RAM(0x0000)
src\state\enemy_state.h:125:#define ENEMY_SCRATCH_X                 RAM(0x0000)
src\state\enemy_state.h:126:#define ENEMY_SCRATCH_Y                 RAM(0x0001)
src\state\enemy_state.h:127:#define ENEMY_ATTR_SCRATCH              RAM(0x0004)
src\state\enemy_state.h:128:#define ENEMY_FRAME_FLAGS               RAM(0x000F)
src\state\enemy_state.h:129:#define ENEMY_CUR_SPRITE_ATTR_ROW       RAM(0x0015)
src\state\enemy_state.h:130:#define ENEMY_DUNGEON_TILE_FLOOR        RAM(0x034A)
src\state\enemy_state.h:131:#define ENEMY_BOSS_HP_PHASE(slot)       OBJ(0x0380, (slot))
src\state\enemy_state.h:132:#define ENEMY_SECRET_KIND               RAM(0x04CD)
src\state\enemy_state.h:133:#define ENEMY_DIGDOGGER_COUNT           RAM(0x0507)
src\state\frontend_state.h:7:#define FRONTEND_CUR_VSCROLL            RAM(0x00FC)
src\state\frontend_state.h:8:#define FRONTEND_NT_SWITCH_REQ          RAM(0x005C)
src\state\frontend_state.h:9:#define FRONTEND_SPRITE_CURSOR_X        RAM(0x0207)
src\state\frontend_state.h:10:#define FRONTEND_NAME_CURSOR_X          RAM(0x0071)
src\state\frontend_state.h:11:#define FRONTEND_NAME_CURSOR_Y          RAM(0x0085)
src\state\frontend_state.h:13:#define FRONTEND_SCROLL_SCREEN_COUNT    RAM(0x0415)
src\state\frontend_state.h:14:#define FRONTEND_DEMO_LINE_ATTR_LO      RAM(0x0417)
src\state\frontend_state.h:15:#define FRONTEND_DEMO_LINE_ATTR_HI      RAM(0x0418)
src\state\frontend_state.h:16:#define FRONTEND_DEMO_TIMER             RAM(0x041A)
src\state\frontend_state.h:17:#define FRONTEND_DEMO_LINE_TILE_LO      RAM(0x041C)
src\state\frontend_state.h:18:#define FRONTEND_DEMO_LINE_TILE_HI      RAM(0x041D)
src\state\frontend_state.h:19:#define FRONTEND_CHAR_BOARD_INDEX       RAM(0x041F)
src\state\frontend_state.h:20:#define FRONTEND_NAME_FIELD_INIT        RAM(0x0420)
src\state\frontend_state.h:21:#define FRONTEND_NAME_CHAR_OFFSET       RAM(0x0421)
src\state\frontend_state.h:22:#define FRONTEND_BUTTON_HELD            RAM(0x0426)
src\state\frontend_state.h:23:#define FRONTEND_BUTTON_REPEAT_STATE    RAM(0x0428)
src\state\frontend_state.h:24:#define FRONTEND_BUTTON_REPEAT_TIMER    RAM(0x0429)
src\state\frontend_state.h:25:#define FRONTEND_DEMO_SUBPHASE          RAM(0x042D)
src\state\frontend_state.h:26:#define FRONTEND_CREDITS_TILE_OFFSET    RAM(0x050B)
src\state\frontend_state.h:28:#define FRONTEND_ADD16_LO               RAM(0x000F)
src\state\frontend_state.h:29:#define FRONTEND_ADD16_HI               RAM(0x000E)
src\state\frontend_state.h:30:#define FRONTEND_SAVE_ADD16_LO          RAM(0x00CF)
src\state\frontend_state.h:31:#define FRONTEND_SAVE_ADD16_HI          RAM(0x00CE)
src\state\object_state.h:11:#define OBJ_TILE_X(slot)        RAM(NES_OBJ_TILE_X_BASE + (slot))
src\state\object_state.h:12:#define OBJ_TILE_Y(slot)        RAM(NES_OBJ_TILE_Y_BASE + (slot))
src\state\object_state.h:13:#define OBJ_TILE_NEXT(slot)     RAM(NES_OBJ_TILE_NEXT_BASE + (slot))
src\state\object_state.h:14:#define OBJ_ALIGN_FLAG(slot)    RAM(NES_OBJ_ALIGN_FLAG_BASE + (slot))
src\state\object_state.h:17:#define OBJ_TYPE(slot)          RAM(NES_OBJ_TYPE_BASE + (slot))
src\state\object_state.h:18:#define OBJ_FLAG(slot)          RAM(NES_OBJ_FLAG_BASE + (slot))
src\state\object_state.h:19:#define OBJ_STATE(slot)         RAM(NES_OBJ_STATE_BASE + (slot))
src\state\object_state.h:20:#define OBJ_METASTATE(slot)     RAM(NES_OBJ_METASTATE_BASE + (slot))
src\state\object_state.h:23:#define OBJ_SHOVE_DIR(slot)     RAM(NES_OBJ_SHOVE_DIR_BASE + (slot))
src\state\object_state.h:24:#define OBJ_SHOVE_DIST(slot)    RAM(NES_OBJ_SHOVE_DIST_BASE + (slot))
src\state\object_state.h:27:#define OBJ_ANIM_CNTR(slot)     RAM(NES_OBJ_ANIM_CNTR_BASE + (slot))
src\state\object_state.h:28:#define OBJ_HFLIP(slot)         RAM(NES_OBJ_HFLIP_BASE + (slot))
src\state\object_state.h:31:#define OBJ_INV_TIMER(slot)     RAM(NES_OBJ_INV_TIMER_BASE + (slot))
src\state\link_state.h:9:#define LINK_MOVING_DIR       RAM(NES_LINK_MOVING_DIR)
src\state\link_state.h:10:#define LINK_ROOM_SCRATCH     RAM(NES_LINK_ROOM_SCRATCH)
src\state\link_state.h:11:#define LINK_HALT_FLAG        RAM(NES_LINK_HALT_FLAG)
src\state\link_state.h:12:#define MODE11_DEATH_TIMER    RAM(NES_MODE11_DEATH_TIMER)
src\state\link_state.h:13:#define DEATH_FRAME_COUNTER   RAM(NES_DEATH_FRAME_COUNTER)
src\state\save_state.h:16:#define CONTINUE_COUNT(slot)    RAM(NES_CONTINUE_COUNT_BASE + (slot))
src\state\progress_state.h:9:#define SAVEFILE_PTR_LO                 RAM(0x00)
src\state\progress_state.h:10:#define SAVEFILE_PTR_HI                 RAM(0x01)
src\state\progress_state.h:11:#define SAVEFILE_MASK_LO                RAM(0x08)
src\state\progress_state.h:12:#define SAVEFILE_MASK_HI                RAM(0x09)
src\state\progress_state.h:14:#define CUR_LEVEL                      RAM(0x0010)
src\state\progress_state.h:15:#define FRAME_COUNTER                  RAM(0x0015)
src\state\progress_state.h:16:#define MODE_VALUE                     RAM(0x0012)
src\state\progress_state.h:17:#define SUBMODE_VALUE                  RAM(0x0013)
src\state\progress_state.h:18:#define CUR_ROOM_FLAGS_PTR             RAM(0x00E8)
src\state\progress_state.h:19:#define MAP_FLASH_ATTR                 RAM(0x0256)
src\state\progress_state.h:21:#define ROOM_TILE_OBJ_0                RAM(0x052B)
src\state\progress_state.h:22:#define ROOM_TILE_OBJ_1                RAM(0x052C)
src\state\progress_state.h:23:#define ROOM_TILE_OBJ_2                RAM(0x052D)
src\state\progress_state.h:24:#define PLAYER_MARKER_DISABLE          RAM(0x0522)
src\state\progress_state.h:25:#define POWER_TRIFORCE_FANFARE_FLAG    RAM(0x0509)
src\state\progress_state.h:26:#define HUD_DIRTY_FLAG                 RAM(0x0672)
src\state\progress_state.h:27:#define CURTAIN_LEFT_COL               RAM(0x007C)
src\state\progress_state.h:28:#define CURTAIN_RIGHT_COL              RAM(0x007D)
src\state\progress_state.h:29:#define CURTAIN_TIMER                  RAM(0x0028)
src\state\progress_state.h:30:#define CUR_INV_TILE                   RAM(0x00FE)
src\state\progress_state.h:32:#define MAP_MARKER_Y(idx)              RAM(0x0254 + (idx))
src\state\progress_state.h:33:#define MAP_MARKER_TILE(idx)           RAM(0x0255 + (idx))
src\state\progress_state.h:34:#define MAP_MARKER_ATTR(idx)           RAM(0x0256 + (idx))
src\state\progress_state.h:35:#define MAP_MARKER_X(idx)              RAM(0x0257 + (idx))
src\state\progress_state.h:38:#define PROG_CUR_LEVEL           RAM(NES_CUR_LEVEL)
src\state\progress_state.h:39:#define PROG_ITEMS_BY_LEVEL(off) RAM(NES_ITEMS_BY_LEVEL_BASE + (unsigned short)(off))
src\game\room\room_load_runtime.c:89:    RAM(PATTERN_BLOCK_INDEX) = 0;
src\game\room\room_load_runtime.c:94:    unsigned char idx = RAM(PATTERN_BLOCK_INDEX);
src\game\room\room_load_runtime.c:96:    RAM(0x0000) = PatternBlockSrcAddrsUW[idx];
src\game\room\room_load_runtime.c:97:    RAM(0x0001) = PatternBlockSrcAddrsUW[idx + 1];
src\game\room\room_load_runtime.c:102:    unsigned char idx = RAM(PATTERN_BLOCK_INDEX);
src\game\room\room_load_runtime.c:104:    RAM(0x0000) = PatternBlockSrcAddrsOW[idx];
src\game\room\room_load_runtime.c:105:    RAM(0x0002) = PatternBlockSizesOW[idx];
src\game\room\room_load_runtime.c:106:    RAM(0x0001) = PatternBlockSrcAddrsOW[idx + 1];
src\game\room\room_load_runtime.c:107:    RAM(0x0003) = PatternBlockSizesOW[idx + 1];
src\game\room\room_load_runtime.c:112:    unsigned char idx = RAM(CUR_LEVEL);
src\game\room\room_load_runtime.c:114:    RAM(0x0000) = LevelPatternBlockSrcAddrs[idx];
src\game\room\room_load_runtime.c:115:    RAM(0x0001) = LevelPatternBlockSrcAddrs[idx + 1];
src\game\room\room_load_runtime.c:120:    unsigned char idx = RAM(CUR_LEVEL);
src\game\room\room_load_runtime.c:122:    RAM(0x0000) = BossPatternBlockSrcAddrs[idx];
src\game\room\room_load_runtime.c:123:    RAM(0x0001) = BossPatternBlockSrcAddrs[idx + 1];
src\game\room\room_load_runtime.c:127:    unsigned char idx = RAM(PATTERN_BLOCK_INDEX);
src\game\room\room_load_runtime.c:129:    RAM(0x0002) = PatternBlockSizesUW[idx];
src\game\room\room_load_runtime.c:130:    RAM(0x0003) = PatternBlockSizesUW[idx + 1];
src\game\room\room_load_runtime.c:134:    unsigned char idx = RAM(PATTERN_BLOCK_INDEX);
src\game\room\room_load_runtime.c:140:        unsigned char lo = RAM(0x0000);
src\game\room\room_load_runtime.c:141:        unsigned char hi = RAM(0x0001);
src\game\room\room_load_runtime.c:146:        lo = RAM(0x0000);
src\game\room\room_load_runtime.c:148:        RAM(0x0000) = lo;
src\game\room\room_load_runtime.c:150:            hi = RAM(0x0001);
src\game\room\room_load_runtime.c:152:            RAM(0x0001) = hi;
src\game\room\room_load_runtime.c:155:        unsigned char cnt_lo = RAM(0x0003);
src\game\room\room_load_runtime.c:156:        unsigned char cnt_hi = RAM(0x0002);
src\game\room\room_load_runtime.c:159:            RAM(0x0002) = cnt_hi;
src\game\room\room_load_runtime.c:162:        RAM(0x0003) = cnt_lo;
src\game\room\room_load_runtime.c:164:        if (RAM(0x0002) == 0 && RAM(0x0003) == 0)
src\game\room\room_load_runtime.c:167:    RAM(PATTERN_BLOCK_INDEX)++;
src\game\room\room_load_runtime.c:175:    } while (RAM(PATTERN_BLOCK_INDEX) != 2);
src\game\room\room_load_runtime.c:193:    if (RAM(CUR_LEVEL) != 0) {
src\game\room\room_load_runtime.c:201:    } while (RAM(PATTERN_BLOCK_INDEX) != 2);
src\game\room\room_load_runtime.c:208:        unsigned short dest = ((unsigned short)RAM(0x0003) << 8) | RAM(0x0002);
src\game\room\room_load_runtime.c:211:        if (RAM(0x0002) == RAM(0x0004) && RAM(0x0003) == RAM(0x0005)) {
src\game\room\room_load_runtime.c:216:        unsigned char lo = RAM(0x0002);
src\game\room\room_load_runtime.c:218:        RAM(0x0002) = lo;
src\game\room\room_load_runtime.c:220:            RAM(0x0003)++;
src\game\room\room_load_runtime.c:227:    RAM(0x0002) = 0x7E;
src\game\room\room_load_runtime.c:228:    RAM(0x0003) = 0x68;
src\game\room\room_load_runtime.c:229:    RAM(0x0004) = 0x7D;
src\game\room\room_load_runtime.c:230:    RAM(0x0005) = 0x6B;
src\game\room\room_load_runtime.c:234:    RAM(0x0002) = 0x7E;
src\game\room\room_load_runtime.c:235:    RAM(0x0003) = 0x6B;
src\game\room\room_load_runtime.c:236:    RAM(0x0004) = 0x7D;
src\game\room\room_load_runtime.c:237:    RAM(0x0005) = 0x6C;
src\game\room\room_load_runtime.c:241:    RAM(0x0002) = 0xF0;
src\game\room\room_load_runtime.c:242:    RAM(0x0003) = 0x67;
src\game\room\room_load_runtime.c:243:    RAM(0x0004) = 0x7D;
src\game\room\room_load_runtime.c:244:    RAM(0x0005) = 0x68;
src\game\room\room_load_runtime.c:314:    RAM(0x0000) = LevelInfoUWQ2ReplacementAddrs[idx - 2];
src\game\room\room_load_runtime.c:315:    RAM(0x0001) = LevelInfoUWQ2ReplacementAddrs[idx - 1];
src\game\room\room_load_runtime.c:319:        unsigned char ptr_lo = RAM(0x0000);
src\game\room\room_load_runtime.c:320:        unsigned char ptr_hi = RAM(0x0001);
src\game\room\room_mode_runtime.c:264:    RAM(0x0394) = 0;
src\game\room\room_mode_runtime.c:269:    RAM(0x0394) = 0;
src\game\room\room_mode_runtime.c:310:    RAM(0x000F) = 0;
src\game\room\room_mode_runtime.c:312:    RAM(0x00C0) = 0;
src\game\room\room_mode_runtime.c:313:    RAM(0x00D3) = 0;
src\state\room_state.h:7:#define ROOM_TOUCH_DOOR_BITS            RAM(0x000C)
src\state\room_state.h:8:#define ROOM_TOUCH_BLOCK_FLAG           RAM(0x000E)
src\state\room_state.h:9:#define ROOM_MODE_TIMER                 RAM(0x0011)
src\state\room_state.h:10:#define ROOM_TRANSFER_BUF_SELECT        RAM(0x0014)
src\state\room_state.h:11:#define ROOM_SCROLL_FRAME               RAM(0x00E6)
src\state\room_state.h:12:#define ROOM_LEVEL_INDEX                RAM(0x00E7)
src\state\room_state.h:13:#define ROOM_ROW_INDEX                  RAM(0x00E9)
src\state\room_state.h:14:#define ROOM_LAST_ROW_INDEX             RAM(0x00ED)
src\state\room_state.h:15:#define ROOM_CYCLE_DIR                  RAM(0x00EF)
src\state\room_state.h:16:#define ROOM_STATE_INDEX                RAM(0x00E1)
src\state\room_state.h:17:#define ROOM_VSCROLL_LO                 RAM(0x00E2)
src\state\room_state.h:18:#define ROOM_SPRITE0_ENABLED            RAM(0x00E3)
src\state\room_state.h:19:#define ROOM_OPEN_DOOR_TIMER            RAM(0x0054)
src\state\room_state.h:20:#define ROOM_OPEN_DOOR_ARG              RAM(0x0055)
src\state\room_state.h:21:#define ROOM_NAMETABLE_SELECT           RAM(0x005F)
src\state\room_state.h:22:#define ROOM_LINK_CELLAR_FLAG           RAM(0x005A)
src\state\room_state.h:23:#define ROOM_IN_DOORWAY_FLAG            RAM(0x0053)
src\state\room_state.h:24:#define ROOM_HEART_FILL_STATE           RAM(0x0063)
src\state\room_state.h:25:#define ROOM_INV_OBJ_ACTIVE             RAM(0x0064)
src\state\room_state.h:26:#define ROOM_DOOR_MASK_ACC             RAM(0x033F)
src\state\room_state.h:27:#define ROOM_BOUNDS(slot)              RAM(0x0346 + (slot))
src\state\room_state.h:28:#define CUR_OPENED_DOORS               RAM(0x00EE)
src\state\room_state.h:29:#define ROOM_MONSTER_ALL_DEAD          RAM(0x034D)
src\state\room_state.h:30:#define ROOM_OW_KILL_COUNT             RAM(0x034E)
src\state\room_state.h:31:#define ROOM_OW_CUR_KILL_TOTAL         RAM(0x034F)
src\state\room_state.h:32:#define ROOM_MAX_MONSTER_SLOT          RAM(0x0340)
src\state\room_state.h:33:#define ROOM_OBJ_TYPE(slot)            RAM(0x0350 + (slot))
src\state\room_state.h:34:#define ROOM_OBJ_STUN_TIMER(slot)      RAM(0x0406 + (slot))
src\state\room_state.h:35:#define ROOM_COLLIDABLE_TILE            RAM(0x049E)
src\state\room_state.h:36:#define ROOM_SCROLL_STATE               RAM(0x051F)
src\state\room_state.h:37:#define ROOM_SWORD_BLOCKED_FLAG         RAM(0x052E)
src\state\room_state.h:39:#define ROOM_SHUTTER_TRIGGERED         RAM(0x04CE)
src\state\room_state.h:40:#define ROOM_BLOCK_SECRET_FLAG         RAM(0x04CF)
src\state\room_state.h:41:#define ROOM_SHUTTER_TOUCH_MASK        RAM(0x0519)
src\state\room_state.h:42:#define ROOM_PALETTE_ATTR(slot)        RAM(0x0530 + (slot))
src\state\room_state.h:44:#define ROOM_SFX_MAIN                  RAM(0x0604)
src\state\room_state.h:45:#define ROOM_SFX_AUX                   RAM(0x0603)
src\state\room_state.h:46:#define ROOM_OAM_BYTE(off)             RAM(0x0200 + (off))
src\state\room_state.h:47:#define ROOM_LINK_BG_ATTR_A            RAM(0x024A)
src\state\room_state.h:48:#define ROOM_LINK_BG_ATTR_B            RAM(0x024E)
src\state\room_state.h:49:#define ROOM_INV_OBJ_STATE(slot)       RAM(0x00B9 + (slot))
src\state\room_state.h:50:#define ROOM_PPU_MASK_FLAGS            RAM(0x00FF)
src\state\room_state.h:51:#define ROOM_SCROLL_LOCK_FLAG          RAM(0x010C)
src\state\room_state.h:52:#define ROOM_MENU_SCROLL_TIMER         RAM(0x00E5)
src\state\room_state.h:53:#define ROOM_INPUT_DIR                 RAM(0x03F8)
src\state\room_state.h:54:#define ROOM_LINK_SPEED                RAM(0x03BC)
src\state\room_state.h:55:#define ROOM_LINK_SPEED_FRAC           RAM(0x03A8)
src\state\room_state.h:56:#define ROOM_OBJECT_SLOT_TYPE          RAM(0x035A)
src\state\room_state.h:57:#define ROOM_OBJECT_INIT_DONE          RAM(0x00B7)
src\state\room_state.h:58:#define ROOM_OBJECT_X_SCRATCH          RAM(0x007B)
src\state\room_state.h:59:#define ROOM_OBJECT_Y_SCRATCH          RAM(0x008F)
src\state\room_state.h:60:#define ROOM_PUSH_TIMER                RAM(0x0412)
src\state\room_state.h:61:#define ROOM_PARTIAL_HEART_FILL_DONE   RAM(0x00E0)
src\state\room_state.h:62:#define ROOM_MENU_SCROLL_POS           RAM(0x005E)
src\state\room_state.h:63:#define ROOM_TRIFORCE_HOLD_FLAG        RAM(0x0619)
src\state\room_state.h:64:#define ROOM_PAUSED_FLAG               RAM(0x00E0)
src\state\room_state.h:65:#define ROOM_LEVEL_NUMBER_VALUE        RAM(0x6000u + 0x0BB1)
src\state\room_state.h:68:#define ROOM_TILE_XFER_COL       RAM(NES_TILE_XFER_COL)
src\state\room_state.h:69:#define ROOM_TILE_XFER_ROW       RAM(NES_TILE_XFER_ROW)
src\state\room_state.h:70:#define ROOM_CUR_ROOM_ID         RAM(NES_CUR_ROOM_ID)
src\state\room_state.h:71:#define ROOM_PPU_MASK_SHADOW     RAM(NES_PPU_MASK_SHADOW)
src\state\room_state.h:72:#define ROOM_TILE_XFER_BUF_IDX   RAM(NES_TILE_XFER_BUF_IDX)
src\state\room_state.h:73:#define ROOM_TILE_XFER_BUF(off)  RAM(NES_TILE_XFER_BUF_BASE + (unsigned short)(off))
src\state\room_state.h:74:#define ROOM_ID_ALT              RAM(NES_ROOM_ID_ALT)
src\state\room_state.h:75:#define ROOM_HISTORY_IDX         RAM(NES_ROOM_HISTORY_IDX)
src\state\room_state.h:76:#define ROOM_HISTORY(i)          RAM(NES_ROOM_HISTORY_BASE + (unsigned char)(i))
src\game\enemies\enemy_common_runtime.c:35:#define ROOM_OBJ_COUNT RAM(0x034E)
src\game\enemies\enemy_common_runtime.c:113:    OBJ(NES_OBJ_TYPE, slot) = 20;
src\game\enemies\enemy_common_runtime.c:119:    OBJ(NES_OBJ_GRID_OFFSET, child) = OBJ(NES_OBJ_GRID_OFFSET, slot);
src\game\enemies\enemy_common_runtime.c:184:        OBJ(NES_OBJ_GRID_OFFSET, slot) = 0;
src\game\enemies\enemy_common_runtime.c:207:    if ((OBJ(NES_OBJ_GRID_OFFSET, slot) | ENEMY_MOVE_TIMER(slot)) != 0)
src\game\enemies\enemy_common_runtime.c:229:    RAM(NES_OBJ_DIR) = ENEMY_DIR(slot);
src\game\enemies\enemy_common_runtime.c:234:    if (OBJ(NES_OBJ_GRID_OFFSET, slot) == 0) {
src\game\enemies\enemy_common_runtime.c:252:    unsigned char off = OBJ(NES_OBJ_GRID_OFFSET, slot);
src\game\enemies\enemy_common_runtime.c:255:        OBJ(NES_OBJ_GRID_OFFSET, slot) = 0;
src\game\enemies\enemy_common_runtime.c:268:    RAM(NES_SCRATCH_2) = ENEMY_X(slot);
src\game\enemies\enemy_common_runtime.c:269:    RAM(NES_SCRATCH_3) = ENEMY_Y(slot);
src\game\enemies\enemy_boss_runtime.c:262:    ENEMY_Y(slot) = (unsigned char)(ENEMY_Y(slot) + enrt_vire_jump_offsets[z01_abs(OBJ(0x0394, slot))]);
src\game\enemies\enemy_dodongo_runtime.c:160:        unsigned char monster = RAM(0x0000 + axis);
src\game\enemies\enemy_dodongo_runtime.c:161:        unsigned char bomb    = RAM(0x0002 + axis);
src\game\enemies\enemy_dodongo_runtime.c:170:        RAM(0x0004 + axis) = (unsigned char)dist;
src\game\enemies\enemy_dodongo_runtime.c:229:    OBJ(0x00AC, 16) = 0;
src\game\enemies\enemy_dodongo_runtime.c:260:    ENEMY_GLEEOK_NECK_Y_PTR_LO = (unsigned char)(OBJ(NES_OBJ_X, 16) + 8);
src\game\enemies\enemy_dodongo_runtime.c:261:    ENEMY_GLEEOK_NECK_Y_PTR_HI = (unsigned char)(OBJ(NES_OBJ_Y, 16) + 8);
src\game\enemies\enemy_dodongo_runtime.c:263:    bomb_state = OBJ(0x00AC, 16);
src\game\room\room_transfer_runtime.c:14:    RAM(0x0303 + buf) = col;
src\game\room\room_transfer_runtime.c:18:    RAM(0x0304 + buf) = 0x96;
src\game\room\room_transfer_runtime.c:19:    RAM(0x031B + buf) = 0xFF;
src\game\room\room_transfer_runtime.c:23:        RAM(0x0305 + dst) = nes_ram[src + i];
src\game\room\room_transfer_runtime.c:45:    RAM(0x0303) = vram & 0xFF;
src\game\room\room_transfer_runtime.c:47:    RAM(0x0304) = 32;
src\game\room\room_transfer_runtime.c:48:    RAM(0x0325) = 0xFF;
src\game\room\room_transfer_runtime.c:52:        RAM(0x0305 + i) = nes_ram[s];
src\game\enemies\enemy_gleeok_runtime.c:56:        (unsigned int)RAM(ptr_addr) | ((unsigned int)RAM(ptr_addr + 1) << 8);
src\game\enemies\enemy_gleeok_runtime.c:64:        (unsigned int)RAM(ptr_addr) | ((unsigned int)RAM(ptr_addr + 1) << 8);
src\game\enemies\enemy_gleeok_runtime.c:75:    obj_type = OBJ(NES_OBJ_TYPE, 1);            /* ($0350,A4) = type of slot 1 */
src\game\enemies\enemy_gleeok_runtime.c:91:         * working object slots (X→OBJ(0x70,1..6), Y→OBJ(0x84,1..6), misc→
src\game\enemies\enemy_gleeok_runtime.c:95:            RAM(0x0071 + s) = gleeok_load_byte(0x0000, s);
src\game\enemies\enemy_gleeok_runtime.c:96:            RAM(0x0085 + s) = gleeok_load_byte(0x0002, s);
src\game\enemies\enemy_gleeok_runtime.c:97:            RAM(0x0413 + s) = gleeok_load_byte(0x0004, s);
src\game\enemies\enemy_gleeok_runtime.c:112:                    if (rng < 0x20 && OBJ(NES_OBJ_TYPE, 0x0B) == 0)
src\game\enemies\enemy_gleeok_runtime.c:124:            gleeok_store_byte(0x0000, s, RAM(0x0071 + s));
src\game\enemies\enemy_gleeok_runtime.c:125:            gleeok_store_byte(0x0002, s, RAM(0x0085 + s));
src\game\enemies\enemy_gleeok_runtime.c:126:            gleeok_store_byte(0x0004, s, RAM(0x0413 + s));
src\game\enemies\enemy_gleeok_runtime.c:146: *      neighbors (slots 4-3 in OBJ(0x86)).
src\game\enemies\enemy_gleeok_runtime.c:171:     * (slots 0..3 vs 1..4 mapped onto OBJ(0x71,seg) etc). When the gap
src\game\enemies\enemy_gleeok_runtime.c:174:        unsigned char prev_x = RAM(0x0071 + seg);
src\game\enemies\enemy_gleeok_runtime.c:186:        prev_y = RAM(0x0085 + seg);
src\game\enemies\enemy_gleeok_runtime.c:205:        unsigned char ref_x = ENEMY_GLEEOK_BASE_X;       /* OBJ(0x70, 1) */
src\game\enemies\enemy_gleeok_runtime.c:218:    /* Keep the Y of segments 4 and 3 (OBJ(0x87,1..2)) between their
src\game\enemies\enemy_gleeok_runtime.c:219:     * vertical neighbors. The asm walks D2=1..0 over OBJ(0x86..0x88). */
src\game\enemies\enemy_gleeok_runtime.c:223:        unsigned char below = RAM(0x0088 + (unsigned int)i);
src\game\enemies\enemy_gleeok_runtime.c:297:            ENEMY_ALIVE_FLAG(flying) = 0xFF;       /* OBJ(0x0492) */
src\game\enemies\enemy_gleeok_runtime.c:300:            OBJ(NES_OBJ_TYPE, flying) = 70;        /* type 0x46 = flying head */
src\game\enemies\enemy_gleeok_runtime.c:334:                    (unsigned char)(OBJ(NES_OBJ_TYPE, 1) - 0x41);
src\game\enemies\enemy_gleeok_runtime.c:361:            OBJ(NES_OBJ_TYPE, s) = 0;
src\game\enemies\enemy_lamnola_runtime.c:22:        RAM(0x0071u + uidx) = 64;
src\game\enemies\enemy_lamnola_runtime.c:23:        RAM(0x0085u + uidx) = 0x8D;
src\game\enemies\enemy_lamnola_runtime.c:24:        RAM(0x0099u + uidx) = 0;
src\game\enemies\enemy_lamnola_runtime.c:25:        RAM(0x0406u + uidx) = 0;
src\game\enemies\enemy_lamnola_runtime.c:26:        RAM(0x0493u + uidx) = 0;
src\game\enemies\enemy_lamnola_runtime.c:27:        RAM(0x04C0u + uidx) = RAM(0x04C0u);
src\game\enemies\enemy_lamnola_runtime.c:28:        RAM(0x0486u + uidx) = RAM(0x0486u);
src\game\enemies\enemy_lamnola_runtime.c:29:        RAM(0x0350u + uidx) = RAM(0x0350u);
src\game\enemies\enemy_lamnola_runtime.c:32:    RAM(0x009Du) = 8;
src\game\enemies\enemy_lamnola_runtime.c:33:    RAM(0x0385u) = 8;
src\game\enemies\enemy_lamnola_runtime.c:34:    RAM(0x00A2u) = 8;
src\game\enemies\enemy_lamnola_runtime.c:35:    RAM(0x038Au) = 8;
src\game\enemies\enemy_lamnola_runtime.c:37:    type = RAM(0x0350u);
src\game\enemies\enemy_lamnola_runtime.c:41:    RAM(0x034Eu) = 8;
src\game\enemies\enemy_lamnola_runtime.c:67:    RAM(0x0003u) = (unsigned char)(speed ^ 0x03u);
src\game\enemies\enemy_lamnola_runtime.c:83:    OBJ(0x0485u, slot) = 32;
src\game\enemies\enemy_lamnola_runtime.c:88:    } while (RAM(0x0350u + (unsigned char)tail) != ENEMY_LAMNOLA_TYPE);
src\game\enemies\enemy_lamnola_runtime.c:90:    RAM(0x0029u + (unsigned char)tail) = 17;
src\game\enemies\enemy_lamnola_runtime.c:92:    RAM(0x04F1u + (unsigned char)tail) = OBJ(0x04F0u, slot);
src\game\enemies\enemy_lamnola_runtime.c:93:    RAM(0x0071u + (unsigned char)tail) = ENEMY_X(slot);
src\game\enemies\enemy_lamnola_runtime.c:94:    RAM(0x0085u + (unsigned char)tail) = ENEMY_Y(slot);
src\game\enemies\enemy_lamnola_runtime.c:100:    RAM(0x0350u + (unsigned char)tail) = 93;
src\game\enemies\enemy_lamnola_runtime.c:122:        ENEMY_MANHANDLA_SEG_DIR(chain_slot) = OBJ(0x009A, chain_slot);
src\game\enemies\enemy_manhandla_runtime.c:30:        RAM(0x0099u + uidx) = RAM(0x0099u);
src\game\enemies\enemy_manhandla_runtime.c:31:        RAM(0x0350u + uidx) = 60;
src\game\enemies\enemy_manhandla_runtime.c:32:        RAM(0x04B3u + uidx) = 0xE2;
src\game\enemies\enemy_manhandla_runtime.c:33:        RAM(0x0479u + uidx) = kManhandlaBaseFrameImagesAndAttrs[uidx];
src\game\enemies\enemy_manhandla_runtime.c:34:        RAM(0x0406u + uidx) = 0;
src\game\enemies\enemy_manhandla_runtime.c:35:        RAM(0x0493u + uidx) = 0;
src\game\enemies\enemy_manhandla_runtime.c:36:        RAM(0x04C0u + uidx) = RAM(0x04C0u);
src\game\enemies\enemy_manhandla_runtime.c:37:        RAM(0x0486u + uidx) = RAM(0x0486u);
src\game\enemies\enemy_manhandla_runtime.c:38:        RAM(0x0071u + uidx) = (unsigned char)(RAM(0x0075u) + kManhandlaSegmentOffsetsX[uidx]);
src\game\enemies\enemy_manhandla_runtime.c:39:        RAM(0x0085u + uidx) = (unsigned char)(RAM(0x0089u) + kManhandlaSegmentOffsetsY[uidx]);
src\game\enemies\enemy_manhandla_runtime.c:40:        RAM(0x0420u + uidx) = 0x80;
src\game\enemies\enemy_manhandla_runtime.c:54:                unsigned int sum = (unsigned int)RAM(0x0420u + uidx) + 0x80u;
src\game\enemies\enemy_manhandla_runtime.c:55:                RAM(0x0420u + uidx) = (unsigned char)sum;
src\game\enemies\enemy_manhandla_runtime.c:56:                RAM(0x042Du + uidx) = (unsigned char)(RAM(0x042Du + uidx)
src\game\enemies\enemy_manhandla_runtime.c:62:        if (RAM(0x0385u) != 0) {
src\game\enemies\enemy_manhandla_runtime.c:63:            enrt_manhandla_set_all_segments_direction(RAM(0x0385u));
src\game\enemies\enemy_manhandla_runtime.c:75:            RAM(0x0385u) = new_dir;
src\game\enemies\enemy_manhandla_runtime.c:81:        RAM(0x0384u) = ENEMY_DIR(slot);
src\game\enemies\enemy_manhandla_runtime.c:88:        if (post_dir != RAM(0x0384u)) {
src\game\enemies\enemy_manhandla_runtime.c:89:            RAM(0x0385u) = post_dir;
src\game\enemies\enemy_manhandla_runtime.c:94:    RAM(0x0000u) = frame;
src\game\enemies\enemy_manhandla_runtime.c:103:    old_frame_attrs = OBJ(0x0437u, slot);
src\game\enemies\enemy_manhandla_runtime.c:108:    OBJ(0x0437u, slot) = new_frame_attrs;
src\game\enemies\enemy_projectile_runtime.c:172:    unsigned char bounce_dir = OBJ(0x0380, slot);
src\game\enemies\enemy_projectile_runtime.c:190:        unsigned char counter = (unsigned char)(OBJ(0x0394, slot) + 2);
src\game\enemies\enemy_projectile_runtime.c:191:        OBJ(0x0394, slot) = counter;
src\game\enemies\enemy_projectile_runtime.c:205:    OBJ(0x0394, slot) = 0;
src\game\enemies\enemy_projectile_runtime.c:211:    OBJ(0x0380, slot) = LINK_DIR;
src\game\enemies\enemy_projectile_runtime.c:273:    OBJ(0x03BC, slot) = qspeed;
src\game\enemies\enemy_projectile_runtime.c:274:    OBJ(0x03A8, slot) = pos_frac;
src\game\enemies\enemy_projectile_runtime.c:276:    return OBJ(0x03A8, slot);
src\game\enemies\enemy_projectile_runtime.c:287:        OBJ(0x0451, slot) = 0;
src\game\enemies\enemy_projectile_runtime.c:288:        OBJ(0x045E, slot) = 0;
src\game\enemies\enemy_projectile_runtime.c:294:        OBJ(0x0412, slot) = COMBAT_ABS_DY; /* horizontal direction */
src\game\enemies\enemy_projectile_runtime.c:295:        OBJ(0x0437, slot) = COMBAT_ABS_DX; /* vertical direction */
src\game\enemies\enemy_projectile_runtime.c:304:            OBJ(0x041F, slot) = enrt_fireball_qspeeds_x[idx];
src\game\enemies\enemy_projectile_runtime.c:305:            OBJ(0x0444, slot) = enrt_fireball_qspeeds_y[idx];
src\game\enemies\enemy_projectile_runtime.c:323:        ENEMY_FRAME_FLAGS = OBJ(0x0412, slot);
src\game\enemies\enemy_projectile_runtime.c:324:        OBJ(0x0451, slot) = enrt_fireball_move_one_axis(OBJ(0x041F, slot), OBJ(0x0451, slot), slot);
src\game\enemies\enemy_projectile_runtime.c:327:        ENEMY_FRAME_FLAGS = OBJ(0x0437, slot);
src\game\enemies\enemy_projectile_runtime.c:328:        OBJ(0x045E, slot) = enrt_fireball_move_one_axis(OBJ(0x0444, slot), OBJ(0x045E, slot), slot);
src\game\enemies\enemy_runtime.c:14:        if (OBJ(NES_OBJ_TYPE, (unsigned char)i) == 0) {
src\game\enemies\enemy_wallmaster_runtime.c:8:#define WALLMASTER_MINOR_MAJOR_MIN     RAM(0x0000)  /* minor init minor coord (min) */
src\game\enemies\enemy_wallmaster_runtime.c:9:#define WALLMASTER_MAJOR_MINOR_MIN     RAM(0x0001)  /* major coord minimum value  */
src\game\enemies\enemy_wallmaster_runtime.c:10:#define WALLMASTER_INSTR_AXIS          RAM(0x0002)  /* axis-decrease direction bit */
src\game\enemies\enemy_wallmaster_runtime.c:11:#define WALLMASTER_INSTR_MINOR_MIN     RAM(0x0003)  /* init minor distance (major min) */
src\game\enemies\enemy_wallmaster_runtime.c:12:#define WALLMASTER_INIT_MINOR_COORD    RAM(0x0004)  /* initial minor coord result */
src\game\enemies\enemy_wallmaster_runtime.c:15:#define ROOM_INPUT_DIR                 RAM(0x03F8)
src\game\enemies\enemy_wallmaster_runtime.c:109:        unsigned char sx = RAM(0x0203 + sprite_byte_off);
src\game\enemies\enemy_wallmaster_runtime.c:112:            unsigned char attr = RAM(0x0202 + sprite_byte_off);
src\game\enemies\enemy_wallmaster_runtime.c:113:            RAM(0x0202 + sprite_byte_off) = (unsigned char)(attr | 0x20);
src\game\enemies\enemy_walker_runtime.c:104:        if ((OBJ(NES_OBJ_GRID_OFFSET, slot) & 0x0F) == 0)
src\game\enemies\enemy_walker_runtime.c:105:            OBJ(NES_OBJ_GRID_OFFSET, slot) = 0;
src\game\enemies\enemy_walker_runtime.c:109:            if (OBJ(NES_OBJ_GRID_OFFSET, slot) == 0)
src\game\enemies\enemy_walker_runtime.c:117:    if (ENEMY_WALK_SPEED(slot) == 0x20 && OBJ(NES_OBJ_GRID_OFFSET, slot) == 0) {
src\game\enemies\enemy_walker_runtime.c:194:        unsigned char cur = OBJ(0x0451, slot);
src\game\enemies\enemy_walker_runtime.c:197:        } else if (OBJ(0x0412, slot) == 0) {
src\game\enemies\enemy_walker_runtime.c:205:    OBJ(0x0451, slot) = new_timer;
src\game\enemies\enemy_walker_runtime.c:229:    OBJ(0x0437, slot) = (unsigned char)(OBJ(0x0437, slot) - 1);
src\game\enemies\enemy_walker_runtime.c:230:    OBJ(0x0412, slot) = 0;
src\game\enemies\enemy_walker_runtime.c:245:    RAM(0x0001) = 0x20;
src\game\enemies\enemy_walker_runtime.c:250:    if (OBJ(0x0451, slot) == 0 && ENEMY_RNG_A(slot) < 0xF8)
src\game\enemies\enemy_walker_runtime.c:258:    RAM(0x000D) = frame;
src\game\enemies\enemy_walker_runtime.c:261:        RAM(0x000D) = (unsigned char)(RAM(0x000D) + 1);
src\game\enemies\enemy_walker_runtime.c:263:            RAM(0x000F) = (unsigned char)(RAM(0x000F) + 1);
src\game\enemies\enemy_walker_runtime.c:267:            RAM(0x000F) = (unsigned char)(RAM(0x000F) + 1);
src\game\enemies\enemy_walker_runtime.c:270:    c_draw_object_not_mirrored_with_frame((unsigned int)RAM(0x000D), slot);
src\game\enemies\enemy_walker_runtime.c:281:        if (OBJ(0x034F, y) == 0x22) {
src\game\enemies\enemy_walker_runtime.c:282:            OBJ(0x0405, y) = 0x11;
src\game\enemies\enemy_wanderer_runtime.c:7:#define WALLMASTER_MINOR_MAJOR_MIN     RAM(0x0000)
src\game\enemies\enemy_wanderer_runtime.c:8:#define WALLMASTER_MAJOR_MINOR_MIN     RAM(0x0001)
src\game\enemies\enemy_wanderer_runtime.c:9:#define WALLMASTER_INSTR_AXIS          RAM(0x0002)
src\game\enemies\enemy_wanderer_runtime.c:10:#define WALLMASTER_INSTR_MINOR_MIN     RAM(0x0003)
src\game\enemies\enemy_wanderer_runtime.c:46:    if (OBJ(0x00C0, slot) != 0) {
src\game\enemies\enemy_wanderer_runtime.c:75:    if (OBJ(0x00C0, slot) != 0)
src\game\enemies\enemy_wanderer_runtime.c:81:    if ((OBJ(NES_OBJ_GRID_OFFSET, slot) & 0x0F) != 0)
src\game\enemies\enemy_wanderer_runtime.c:85:    OBJ(NES_OBJ_GRID_OFFSET, slot) = 0;
src\game\enemies\enemy_wanderer_runtime.c:95:        if (RAM(0x00AC) == 0xFF)
src\game\enemies\enemy_wanderer_runtime.c:176:    if (OBJ(0x0350, slot) != 0x1E) {
src\game\enemies\enemy_wanderer_runtime.c:183:    if (OBJ(0x00C0, slot) != 0)
src\game\enemies\enemy_wanderer_runtime.c:191:    if ((OBJ(NES_OBJ_GRID_OFFSET, slot) & 0x0F) != 0) {
src\game\enemies\enemy_wanderer_runtime.c:195:    OBJ(NES_OBJ_GRID_OFFSET, slot) = 0;
src\game\enemies\enemy_wanderer_runtime.c:196:    if (RAM(0x00AC) == 0xFF) {
src\game\enemies\enemy_wanderer_runtime.c:241:        if (RAM(0x0000 + idx) < 0x51) {
src\game\enemies\enemy_wanderer_runtime.c:243:            ENEMY_DIR(slot) = RAM(0x0002 + idx);

 succeeded in 901ms:

Name                          
----                          
archive                       
obj                           
reports                       
vgmrom                        
blastem.exe - Shortcut.lnk    
build_clean.txt               
build_clean_err.txt           
build_err.txt                 
build_err_orig.txt            
build_log.txt                 
build_out.txt                 
build_out_orig.txt            
build_renamed.txt             
build_renamed_err.txt         
BUILDS.md                     
EmuHawk.exe - Shortcut.lnk    
GENS SCREENIES.lnk            
Legend of Zelda, The (USA).nes
NES SCREENIES.lnk             
Screenshots - Shortcut.lnk    
whatif.elf                    
whatif.lst                    
whatif.md                     
whatif.o                      
whatif_la.md                  
whatif_prev.md                



 succeeded in 970ms:
src/gen/music_great_fairy.bin
src/gen/z_01.c
src/gen/z_02.c
src/gen/z_03.c
src/gen/z_04.c
src/gen/z_05.c
src/gen/z_06.c
src/gen/z_07.c
src/zelda_translated/patches/README.md
src/zelda_translated/patches/z_05_patch_P38_check_tile_object.md
src/zelda_translated/patches/z_06_dyntilebuf_palette_precheck.md
src/zelda_translated/patches/z_07_patch_P37_debug_teleport.md
src/zelda_translated/patches/z_07_patch_rng.md
src/zelda_translated/z_00.asm
src/zelda_translated/z_01.asm
src/zelda_translated/z_02.asm
src/zelda_translated/z_03.asm
src/zelda_translated/z_04.asm
src/zelda_translated/z_05.asm
src/zelda_translated/z_06.asm
src/zelda_translated/z_07.asm


Count    : 21
Average  : 
Sum      : 
Maximum  : 
Minimum  : 
Property : 




 succeeded in 951ms:
_find_divergence.py
add_labels_to_map.py
add_labels_to_reference.py
analyze_buzz.py
analyze_correct_rooms_pattern.py
analyze_heap_structure.py
analyze_intro_continuity.py
analyze_intro_late_probe.py
analyze_intro_scroll_window.py
analyze_itemscroll.py
analyze_levelblock_structure.py
analyze_nes_packing.py
analyze_new_offset.py
analyze_p3_88_pattern.py
analyze_room_mapping.py
analyze_roomattrs_vs_layouts.py
analyze_row_pattern.py
analyze_starting_room.py
analyze_tile_rendering.py
archive_phase_build.py
build_data.py
calculate_correct_offsets.py
capture_intro_handoff_state.py
check_attribute_sizes.py
check_cave0_gap.py
check_column_data.py
check_layouts_indexing.py
check_levelblock_offset.py
check_missing_layouts.py
check_nes_layout_interpretation.py
check_new_extraction.py
check_overworld_full_fidelity.py
check_phase0_integrity.py
check_room_equals_layout.py
check_room_fidelity.py
check_room_id_system.py
check_roomattrs_extraction.py
check_t36_nes.py
check_unique_ids.py
compare_all_rooms.py
compare_baseline_traces.py
compare_frontend_transition.py
compare_fs_screenshots.py
compare_maps_detailed.py
compare_nes_start_room.py
compare_one_room.py
compare_overworld_visible_sweep.py
compare_overworld_visual.py
compare_perf.py
compare_playmap.py
compare_position_logs.py
compare_rom_reads.py
compare_rom_vs_extracted.py
compare_room77_parity.py
compare_t34_movement_parity.py
compare_t35_scroll_parity.py
compare_t36_cave_parity.py
compare_t37_sword_parity.py
compare_t38_enemy_parity.py
compare_vram_reference.py
cycle_profile_report.py
debug_extraction_offset.py
debug_levelblock_extraction.py
debug_overworld_system.py
debug_room_77.py
determine_correct_size.py
diagnose_overworld.py
diagnose_room_37.py
diff_intro.py
drain_finalize.py
drain_z04_block_shot.py
emit_gen_wrappers.py
examine_rom_layouts.py
extract_audio.py
extract_chr.py
extract_dat_sidecars.py
extract_demo_text.py
extract_dmc_samples.py
extract_enemies.py
extract_frontend.py
advance_and_capture_gen.lua
advance_and_capture_nes.lua
bizhawk_attr_diag_probe.lua
bizhawk_attr_exec_probe.lua
bizhawk_attribute_probe.lua
bizhawk_audio_probe.lua
bizhawk_bg_chr_probe.lua
bizhawk_blank_tile_dump.lua
bizhawk_boot_probe.lua
bizhawk_capture_frame.lua
bizhawk_capture_intro_sequence.lua
bizhawk_capture_intro_window.lua
bizhawk_capture_items_sequence.lua
bizhawk_capture_v8_regression.lua
bizhawk_capture_v8_visual.lua
bizhawk_chr_loop_count_probe.lua
bizhawk_chr_upload_probe.lua
bizhawk_cram_trace_probe.lua
bizhawk_cram_write_trace.lua
bizhawk_cram0_trace_probe.lua
bizhawk_dynbuf_probe.lua
bizhawk_frontend_rombuf_probe.lua
bizhawk_frontend_selector_probe.lua
bizhawk_frontend_transition_gen_capture.lua
bizhawk_frontend_transition_nes_capture.lua
bizhawk_fs1_diag.lua
bizhawk_fs1_dispatch_trace.lua
bizhawk_fs1_screenshot.lua
bizhawk_fs1_vram_snap.lua
bizhawk_fs2_keyboard.lua
bizhawk_fs2_probe.lua
bizhawk_gen_capture_debug_wrap.lua
bizhawk_hint_probe.lua
bizhawk_hv_counter_probe.lua
bizhawk_intro_handoff_capture.lua
bizhawk_intro_hblank_row_probe.lua
bizhawk_intro_hook_probe.lua
bizhawk_intro_jump_probe.lua
bizhawk_intro_jump_probe_early.lua
bizhawk_intro_late_probe.lua
bizhawk_intro_order_probe.lua
bizhawk_intro_prearm_handoff_probe.lua
bizhawk_intro_rowwrite_probe.lua
bizhawk_intro_state_probe.lua
bizhawk_intro_sweep.lua
bizhawk_intro_vram_dump.lua
bizhawk_intro_window_probe.lua
bizhawk_intro_window_probe_early.lua
bizhawk_list_domains.lua
bizhawk_mmc1_probe.lua
bizhawk_nametable_probe.lua
bizhawk_nes_nametable_capture.lua
bizhawk_nes_oam_probe.lua
bizhawk_nes_palette_probe.lua
bizhawk_nes_start_capture.lua
bizhawk_nes_tilea0_probe.lua
bizhawk_nes_title_capture.lua
bizhawk_nes_title_ram_capture.lua
bizhawk_nmi_duration_probe.lua
bizhawk_nmi_trace_probe.lua
bizhawk_nmi3_diag_probe.lua
bizhawk_nt_diag_probe.lua
bizhawk_nt_palette_probe.lua
bizhawk_overworld_visible_sweep_gen.lua
bizhawk_overworld_visible_sweep_nes.lua
bizhawk_palette_d0_debug_probe.lua
bizhawk_palette_d0_trace_probe.lua
bizhawk_palette_debug_probe.lua
bizhawk_palette_probe.lua
bizhawk_pause_at_intro_frame.lua
bizhawk_perf_sample.lua
bizhawk_phantom_diag_probe.lua
bizhawk_phase1_verify.lua
bizhawk_phase10_fs1_probe.lua
bizhawk_phase10_fs2_probe.lua
bizhawk_phase12_probe.lua
bizhawk_phase2_smoke.lua
bizhawk_phase3_cave_probe.lua
bizhawk_phase3_cave_room67_probe.lua
bizhawk_phase3_cave_room70_probe.lua

2026-05-02T17:22:19.470132Z ERROR codex_core::tools::router: error=Exit code: 1
Wall time: 1 seconds
Output:
 M .claude/settings.local.json
 D "FINAL TRY.zip"
 M builds/obj/audio_adapter.o
 M builds/obj/fs_main.o
 M builds/obj/intro_handoff.o
 M builds/obj/link_objs.rsp
 M builds/obj/overworld.o
 M builds/obj/ow_room_render.o
 M builds/obj/sprite_runtime.o
 M builds/whatif.elf
 M builds/whatif.o
 M data/MANIFEST.sha256
 D data/dmc_samples_wav/01_SFX_01.wav
 D data/dmc_samples_wav/02_SFX_02.wav
 D data/dmc_samples_wav/03_SFX_03.wav
 D data/dmc_samples_wav/04_SFX_04.wav
 D data/dmc_samples_wav/05_SFX_05.wav
 D data/dmc_samples_wav/06_SFX_06.wav
 D data/dmc_samples_wav/07_SFX_07.wav
 M src/audio_driver.asm
 D src/data/dmc_samples.bin
 D src/data/dmc_samples.inc
 D src/data/dmc_samples_pcm.bin
 M src/data/music_blob.dat
 M src/frontend/fs/fs_main.c
 M src/frontend/intro/intro_handoff.c
 M src/genesis_shell.asm
 M src/nes_io.asm
?? "FIX THIS.avi"
?? RoomRom/probe_nes_uw_warp_test.lua
?? "SCROLL TIME.avi"
?? "Zelda - Ocarina of Time - Great Fairy's fountain.mid"
?? Zelda1-Redux.zip
?? Zelda1-Redux/.gitignore
?? Zelda1-Redux/GenesiSF.SF2
?? Zelda1-Redux/LICENSE
?? Zelda1-Redux/ReadMe.md
?? Zelda1-Redux/RoomRomC.avi
?? Zelda1-Redux/The-Legend-of-Zelda-Redux-3.3.3.zip
?? Zelda1-Redux/Zelda1_Redux.ips
?? Zelda1-Redux/bin/asar
?? Zelda1-Redux/bin/flips
?? Zelda1-Redux/bin/flips.exe
?? Zelda1-Redux/bin/libasar.so
?? Zelda1-Redux/bin/xkas
?? Zelda1-Redux/bin/xkas.exe
?? Zelda1-Redux/code/animation/animate.asm
?? Zelda1-Redux/code/animation/automap_tiles.bin
?? Zelda1-Redux/code/animation/ow_1st_frame1.chr
?? Zelda1-Redux/code/animation/ow_1st_frame2.chr
?? Zelda1-Redux/code/animation/ow_1st_frame3.chr
?? Zelda1-Redux/code/animation/ow_2nd_frame1.chr
?? Zelda1-Redux/code/animation/ow_2nd_frame2.chr
?? Zelda1-Redux/code/animation/ow_2nd_frame3.chr
?? Zelda1-Redux/code/bugfixes/cave_room_timer.asm
?? Zelda1-Redux/code/bugfixes/dungeon_front_room.asm
?? Zelda1-Redux/code/bugfixes/magic_beam_align.asm
?? Zelda1-Redux/code/bugfixes/overworld_hud_blink.asm
?? Zelda1-Redux/code/bugfixes/overworld_leave_cave.asm
?? Zelda1-Redux/code/bugfixes/overworld_scroll_timing.asm
?? Zelda1-Redux/code/gameplay/arrows.asm
?? Zelda1-Redux/code/gameplay/automap.asm
?? Zelda1-Redux/code/gameplay/automap_tiles.bin
?? Zelda1-Redux/code/gameplay/bombs.asm
?? Zelda1-Redux/code/gameplay/dungeon_automap.asm
?? Zelda1-Redux/code/gameplay/item_toggle.asm
?? Zelda1-Redux/code/gameplay/manual_save.asm
?? Zelda1-Redux/code/gameplay/misc.asm
?? Zelda1-Redux/code/gameplay/move_maps.asm
?? Zelda1-Redux/code/gameplay/overworld_screens.asm
?? Zelda1-Redux/code/gameplay/pols_voice.asm
?? Zelda1-Redux/code/gameplay/rupee.asm
?? Zelda1-Redux/code/gameplay/sword_draw.asm
?? Zelda1-Redux/code/gameplay/sword_swing.asm
?? Zelda1-Redux/code/gameplay/visible_secrets.asm
?? Zelda1-Redux/code/gfx/DryTree.bin
?? Zelda1-Redux/code/gfx/DungeonAssets.bin
?? Zelda1-Redux/code/gfx/OverworldAssets.bin
?? Zelda1-Redux/code/gfx/data_00a.bin
?? Zelda1-Redux/code/gfx/data_00b.bin
?? Zelda1-Redux/code/gfx/data_01a.bin
?? Zelda1-Redux/code/gfx/data_01b.bin
?? Zelda1-Redux/code/gfx/data_01c.bin
?? Zelda1-Redux/code/gfx/data_02a.bin
?? Zelda1-Redux/code/gfx/data_02b.bin
?? Zelda1-Redux/code/gfx/data_03a.bin
?? Zelda1-Redux/code/gfx/data_03b.bin
?? Zelda1-Redux/code/gfx/data_03c.bin
?? Zelda1-Redux/code/gfx/data_03d.bin
?? Zelda1-Redux/code/gfx/data_03e.bin
?? Zelda1-Redux/code/gfx/data_03f.bin
?? Zelda1-Redux/code/gfx/data_03g.bin
?? Zelda1-Redux/code/gfx/data_03h.bin
?? Zelda1-Redux/code/gfx/graphics.asm
?? Zelda1-Redux/code/gfx/palettes.asm
?? Zelda1-Redux/code/gfx/title_screen.asm
?? Zelda1-Redux/code/main.asm
?? Zelda1-Redux/code/menus/caution_screen.asm
?? Zelda1-Redux/code/menus/file_select.asm
?? Zelda1-Redux/code/menus/hud_and_subscreen.asm
?? Zelda1-Redux/code/menus/menu_tweaks.asm
?? Zelda1-Redux/code/menus/save_hearts.asm
?? Zelda1-Redux/code/music/dungeon_music.asm
?? Zelda1-Redux/code/music/new_light_theme.asm
?? Zelda1-Redux/code/music/perils_darkness_theme.asm
?? Zelda1-Redux/code/music/triforce_power_theme.asm
?? Zelda1-Redux/code/music/zelda1_dungeon_theme.asm
?? Zelda1-Redux/code/optional.asm
?? Zelda1-Redux/code/optional/BluerTunic.asm
?? Zelda1-Redux/code/optional/BombUpgrades5.asm
?? Zelda1-Redux/code/optional/FDSFont.asm
?? Zelda1-Redux/code/optional/FullHealthAfterDeath.asm
?? Zelda1-Redux/code/optional/FullHealthAtStart.asm
?? Zelda1-Redux/code/optional/GreyAutomap(OriginalHUD).asm
?? Zelda1-Redux/code/optional/GreyAutomap.asm
?? Zelda1-Redux/code/optional/LinksAwakeningGFX.asm
?? Zelda1-Redux/code/optional/OriginalGFX.asm
?? Zelda1-Redux/code/optional/OriginalHUD.asm
?? Zelda1-Redux/code/optional/OriginalHiddenSecrets.asm
?? Zelda1-Redux/code/optional/OriginalOWColumns.asm
warning: unable to access 'C:\Users\Jake Diggity/.config/git/ignore': Permission denied
warning: unable to access 'C:\Users\Jake Diggity/.config/git/ignore': Permission denied
warning: unable to access 'C:\Users\Jake Diggity/.config/git/ignore': Permission denied
warning: unable to access 'C:\Users\Jake Diggity/.config/git/ignore': Permission denied
warning: could not open directory '.pytest_cache/': Permission denied
warning: could not open directory 'tools/probes/.pytest_cache/': Permission denied

 exited 1 in 1021ms:
 M .claude/settings.local.json
 D "FINAL TRY.zip"
 M builds/obj/audio_adapter.o
 M builds/obj/fs_main.o
 M builds/obj/intro_handoff.o
 M builds/obj/link_objs.rsp
 M builds/obj/overworld.o
 M builds/obj/ow_room_render.o
 M builds/obj/sprite_runtime.o
 M builds/whatif.elf
 M builds/whatif.o
 M data/MANIFEST.sha256
 D data/dmc_samples_wav/01_SFX_01.wav
 D data/dmc_samples_wav/02_SFX_02.wav
 D data/dmc_samples_wav/03_SFX_03.wav
 D data/dmc_samples_wav/04_SFX_04.wav
 D data/dmc_samples_wav/05_SFX_05.wav
 D data/dmc_samples_wav/06_SFX_06.wav
 D data/dmc_samples_wav/07_SFX_07.wav
 M src/audio_driver.asm
 D src/data/dmc_samples.bin
 D src/data/dmc_samples.inc
 D src/data/dmc_samples_pcm.bin
 M src/data/music_blob.dat
 M src/frontend/fs/fs_main.c
 M src/frontend/intro/intro_handoff.c
 M src/genesis_shell.asm
 M src/nes_io.asm
?? "FIX THIS.avi"
?? RoomRom/probe_nes_uw_warp_test.lua
?? "SCROLL TIME.avi"
?? "Zelda - Ocarina of Time - Great Fairy's fountain.mid"
?? Zelda1-Redux.zip
?? Zelda1-Redux/.gitignore
?? Zelda1-Redux/GenesiSF.SF2
?? Zelda1-Redux/LICENSE
?? Zelda1-Redux/ReadMe.md
?? Zelda1-Redux/RoomRomC.avi
?? Zelda1-Redux/The-Legend-of-Zelda-Redux-3.3.3.zip
?? Zelda1-Redux/Zelda1_Redux.ips
?? Zelda1-Redux/bin/asar
?? Zelda1-Redux/bin/flips
?? Zelda1-Redux/bin/flips.exe
?? Zelda1-Redux/bin/libasar.so
?? Zelda1-Redux/bin/xkas
?? Zelda1-Redux/bin/xkas.exe
?? Zelda1-Redux/code/animation/animate.asm
?? Zelda1-Redux/code/animation/automap_tiles.bin
?? Zelda1-Redux/code/animation/ow_1st_frame1.chr
?? Zelda1-Redux/code/animation/ow_1st_frame2.chr
?? Zelda1-Redux/code/animation/ow_1st_frame3.chr
?? Zelda1-Redux/code/animation/ow_2nd_frame1.chr
?? Zelda1-Redux/code/animation/ow_2nd_frame2.chr
?? Zelda1-Redux/code/animation/ow_2nd_frame3.chr
?? Zelda1-Redux/code/bugfixes/cave_room_timer.asm
?? Zelda1-Redux/code/bugfixes/dungeon_front_room.asm
?? Zelda1-Redux/code/bugfixes/magic_beam_align.asm
?? Zelda1-Redux/code/bugfixes/overworld_hud_blink.asm
?? Zelda1-Redux/code/bugfixes/overworld_leave_cave.asm
?? Zelda1-Redux/code/bugfixes/overworld_scroll_timing.asm
?? Zelda1-Redux/code/gameplay/arrows.asm
?? Zelda1-Redux/code/gameplay/automap.asm
?? Zelda1-Redux/code/gameplay/automap_tiles.bin
?? Zelda1-Redux/code/gameplay/bombs.asm
?? Zelda1-Redux/code/gameplay/dungeon_automap.asm
?? Zelda1-Redux/code/gameplay/item_toggle.asm
?? Zelda1-Redux/code/gameplay/manual_save.asm
?? Zelda1-Redux/code/gameplay/misc.asm
?? Zelda1-Redux/code/gameplay/move_maps.asm
?? Zelda1-Redux/code/gameplay/overworld_screens.asm
?? Zelda1-Redux/code/gameplay/pols_voice.asm
?? Zelda1-Redux/code/gameplay/rupee.asm
?? Zelda1-Redux/code/gameplay/sword_draw.asm
?? Zelda1-Redux/code/gameplay/sword_swing.asm
?? Zelda1-Redux/code/gameplay/visible_secrets.asm
?? Zelda1-Redux/code/gfx/DryTree.bin
?? Zelda1-Redux/code/gfx/DungeonAssets.bin
?? Zelda1-Redux/code/gfx/OverworldAssets.bin
?? Zelda1-Redux/code/gfx/data_00a.bin
?? Zelda1-Redux/code/gfx/data_00b.bin
?? Zelda1-Redux/code/gfx/data_01a.bin
?? Zelda1-Redux/code/gfx/data_01b.bin
?? Zelda1-Redux/code/gfx/data_01c.bin
?? Zelda1-Redux/code/gfx/data_02a.bin
?? Zelda1-Redux/code/gfx/data_02b.bin
?? Zelda1-Redux/code/gfx/data_03a.bin
?? Zelda1-Redux/code/gfx/data_03b.bin
?? Zelda1-Redux/code/gfx/data_03c.bin
?? Zelda1-Redux/code/gfx/data_03d.bin
?? Zelda1-Redux/code/gfx/data_03e.bin
?? Zelda1-Redux/code/gfx/data_03f.bin
?? Zelda1-Redux/code/gfx/data_03g.bin
?? Zelda1-Redux/code/gfx/data_03h.bin
?? Zelda1-Redux/code/gfx/graphics.asm
?? Zelda1-Redux/code/gfx/palettes.asm
?? Zelda1-Redux/code/gfx/title_screen.asm
?? Zelda1-Redux/code/main.asm
?? Zelda1-Redux/code/menus/caution_screen.asm
?? Zelda1-Redux/code/menus/file_select.asm
?? Zelda1-Redux/code/menus/hud_and_subscreen.asm
?? Zelda1-Redux/code/menus/menu_tweaks.asm
?? Zelda1-Redux/code/menus/save_hearts.asm
?? Zelda1-Redux/code/music/dungeon_music.asm
?? Zelda1-Redux/code/music/new_light_theme.asm
?? Zelda1-Redux/code/music/perils_darkness_theme.asm
?? Zelda1-Redux/code/music/triforce_power_theme.asm
?? Zelda1-Redux/code/music/zelda1_dungeon_theme.asm
?? Zelda1-Redux/code/optional.asm
?? Zelda1-Redux/code/optional/BluerTunic.asm
?? Zelda1-Redux/code/optional/BombUpgrades5.asm
?? Zelda1-Redux/code/optional/FDSFont.asm
?? Zelda1-Redux/code/optional/FullHealthAfterDeath.asm
?? Zelda1-Redux/code/optional/FullHealthAtStart.asm
?? Zelda1-Redux/code/optional/GreyAutomap(OriginalHUD).asm
?? Zelda1-Redux/code/optional/GreyAutomap.asm
?? Zelda1-Redux/code/optional/LinksAwakeningGFX.asm
?? Zelda1-Redux/code/optional/OriginalGFX.asm
?? Zelda1-Redux/code/optional/OriginalHUD.asm
?? Zelda1-Redux/code/optional/OriginalHiddenSecrets.asm
?? Zelda1-Redux/code/optional/OriginalOWColumns.asm
warning: unable to access 'C:\Users\Jake Diggity/.config/git/ignore': Permission denied
warning: unable to access 'C:\Users\Jake Diggity/.config/git/ignore': Permission denied
warning: unable to access 'C:\Users\Jake Diggity/.config/git/ignore': Permission denied
warning: unable to access 'C:\Users\Jake Diggity/.config/git/ignore': Permission denied
warning: could not open directory '.pytest_cache/': Permission denied
warning: could not open directory 'tools/probes/.pytest_cache/': Permission denied

exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command "rg -n \"src/gen|z_0[1-7]\\.c|music_great_fairy|zelda_translated|z_0[0-7]\\.asm\" build.bat src tools RoomRom docs README.md" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command "rg -n \"VisualStudioSetup|rustup-init|a\\.out|bout\\.txt|build_a3_fix|build_err\\.txt|build_log\\.txt|build_f3_log|build_out_a3|build_out3|build_out_new|build_output\\.txt|build_midi_out|T27_T29_FRONTEND_DIARY|RESUME\\.md|CODEX_HANDOFF|best practices|FIX THIS|SCROLL TIME|Zelda1-Redux.zip\" . --glob '"'!builds/**'"' --glob '"'!Zelda1-Redux/**'"' --glob '"'!sgdk/**'"' --glob '"'!RoomRom/out/**'"'" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'git ls-files reference sgdk midi Zelda1-Redux | Select-Object -First 120; git ls-files reference sgdk midi Zelda1-Redux | Select-Object -Last 80' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command "rg -n \"reference/(aldonunez|Sonic 2|sega2f_files|Disassembly by Trax|Disassembly by camthesaxman)|Zelda1-Redux|midi/|mid2vgm|sgdk/sample|sgdk/doc\" docs README.md tools src build.bat RoomRom -g '"'!RoomRom/out/**'"'" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'Get-ChildItem -LiteralPath . -Force -Directory -Recurse -Filter __pycache__ -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
 succeeded in 1171ms:
README.md:32:│   └── zelda_translated/               ← GENERATED — do not hand-edit (see SPEC.md § Hand-Edit Tracking)
README.md:33:│       ├── z_00.asm through z_07.asm
build.bat:59:rem [1] Transpiler — generate src\zelda_translated\*.asm from aldonunez source.
docs\mathproblem.md:18:Counts are across `src/zelda_translated/z_00..z_07.asm` (excluding the
docs\mathproblem.md:104:transpiled block in z_07.asm via `_patch_z07`'s `P48_WALKER` flag
docs\mathproblem.md:115:labels in z_01.asm are untouched — other callers still use the
docs\superpowers\work\2026-04-23-ram-inventory.md:3:Purpose: enumerate every magic offset currently surfaced in `src/gen/*.c` so
docs\SPEC.md:58:src/zelda_translated/z_00–z_07.asm   (generated — do not hand-edit)
docs\SPEC.md:61:  + src/genesis_shell.asm            (Genesis boot, VDP init, VBlank ISR)
docs\SPEC.md:252:Generated files in `src/zelda_translated/` must not be hand-edited without documentation.
docs\SPEC.md:260:2. Create `src/zelda_translated/patches/z_XX_patch_NNN.md` with:
docs\SPEC.md:265:See `src/zelda_translated/patches/README.md` for patch file format.
docs\SPEC.md:608:- Before and after any edit to `src/genesis_shell.asm` or `src/nes_io.asm`
docs\SPEC.md:609:- After any transpiler change that regenerates `src/zelda_translated/`
docs\superpowers\specs\2026-04-22-c-first-promotion-pipeline-design.md:7:- generated bank-shaped C in `src/gen/z_01.c` ... `z_07.c`
docs\superpowers\specs\2026-04-22-c-first-promotion-pipeline-design.md:17:- `src/gen/z_*.c` remains **staging/reference code**, not final architecture
docs\superpowers\specs\2026-04-22-c-first-promotion-pipeline-design.md:55:- `src/gen/z_*.c`
docs\superpowers\specs\2026-04-22-c-first-promotion-pipeline-design.md:113:Choose one subsystem already partly converted and valuable for optimization. Promote it out of `src/gen/z_*.c` into owned C files with clear headers and call boundaries.
docs\superpowers\specs\2026-04-22-c-first-promotion-pipeline-design.md:136:| `src/gen/z_01.c` ... `z_07.c` | Keep as staging/reference; reduce ownership burden |
docs\superpowers\specs\2026-04-21-carry-flag-return-pattern-design.md:83:| `src/gen/z_01.c` | Port carry-flag utility functions |
docs\superpowers\specs\2026-04-23-plan-b-z05-drain-spec.md:3:**Goal:** Promote every non-forwarder function body in `src/gen/z_05.c` into
docs\superpowers\specs\2026-04-23-plan-b-z05-drain-spec.md:4:its long-term owning `room_*_runtime` module. After Plan B, `src/gen/z_05.c`
docs\superpowers\specs\2026-04-23-plan-b-z05-drain-spec.md:19:## Current `src/gen/z_05.c` inventory (497 lines, HEAD 2689e5a8)
docs\superpowers\specs\2026-04-23-plan-b-z05-drain-spec.md:121:4. Delete the old body from `src/gen/z_05.c`.
docs\superpowers\specs\2026-04-23-plan-b-z05-drain-spec.md:174:- `src/gen/z_05.c` is 100% forwarders inside the auto-wrappers marker
docs\superpowers\specs\2026-04-23-plan-b-z05-drain-spec.md:176:- Insert marker comments into `src/gen/z_05.c` per Task 9 of Plan W.
docs\superpowers\specs\2026-04-23-plan-b-z05-drain-spec.md:195:- Touching `src/zelda_translated/z_05.asm`. Plan B is C-side only.
docs\superpowers\templates\promotion-checklist.md:4:trailer) that promotes code out of `src/gen/` into an owned runtime module,
src\zelda_translated\z_07.asm:18:; z_07.asm — auto-generated by transpile_6502.py
src\save_menu_runtime.c:19: * Original NES asm: src/zelda_translated/z_05.asm lines 180-398.
src\zelda_translated\z_06.asm:2:; z_06.asm — auto-generated by transpile_6502.py
src\zelda_translated\z_06.asm:18:; (fixed equates omitted — provided by z_07.asm in --all build)
src\zelda_translated\z_06.asm:23:; (var equates omitted — provided by z_07.asm in --all build)
src\zelda_translated\z_06.asm:43:; Stage 3a: data-only mode (code ported to src/gen/z_06.c)
src\nes_io.asm:4:; Included by genesis_shell.asm BEFORE z_07.asm (and all other bank files).
src\nes_io.asm:1908:; The transpiler incorrectly placed it as a code label inside z_01.asm, which
src\nes_io.asm:2479:; Zelda's SelectDMC routine (transpiled at z_00.asm:_L_z00_DriveSample_*)
src\nes_io.asm:2540:; SampleAddrs / SampleRates in src/zelda_translated/z_00.asm. Inlined
src\genesis_shell.asm:474:; IsrNmi is defined in zelda_translated/z_07.asm (included below).
src\genesis_shell.asm:646:;   5. Jumps to translated LoopForever (z_07.asm:1461). VBlank fires
src\genesis_shell.asm:710:; z_07.asm is the NES fixed bank ($E000-$FFFF): IsrReset, IsrNmi, RunGame,
src\genesis_shell.asm:725:    include "zelda_translated/z_00.asm"
src\genesis_shell.asm:726:    include "zelda_translated/z_01.asm"
src\genesis_shell.asm:727:    include "zelda_translated/z_02.asm"
src\genesis_shell.asm:728:    include "zelda_translated/z_03.asm"
src\genesis_shell.asm:729:    include "zelda_translated/z_04.asm"
src\genesis_shell.asm:730:    include "zelda_translated/z_05.asm"
src\genesis_shell.asm:731:    include "zelda_translated/z_06.asm"
src\genesis_shell.asm:732:    include "zelda_translated/z_07.asm"
src\genesis_shell.asm:928:; Placed at end-of-file (after all zelda_translated includes) so its byte
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:11:- `src/zelda_translated/z_02.asm` — Translated bank 2 (Genesis M68K)
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:12:- `src/zelda_translated/z_07.asm` — Translated fixed bank (Genesis M68K)
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:14:- `src/genesis_shell.asm` — Boot entry, VBlankISR, register contract
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:57:- `src/zelda_translated/z_07.asm:50` — `GameMode equ $0012  ; NES RAM offset`
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:58:- `src/zelda_translated/z_07.asm:2484` — `move.b ($0012,A4),D0` in `InitMode` dispatch
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:59:- `src/zelda_translated/z_07.asm:1564` — `move.b ($0012,A4),D0` in `IsrNmi_CheckScroll`
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:68:`src/zelda_translated/z_02.asm` and `src/frontend_runtime.c`.
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:75:| `$042B` | `$00FF042B` | `FrontendStartReleaseGate` | `$01` | `frontend_runtime.c:178` — set when Start pressed in Mode0; Mode1_Sub0 waits for Start release before accepting new press (z_02.asm:3284) |
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:78:| `$083D` | `$00FF083D` | `VRamForceBlankGate` | `$01` | **Set to 1.** `frontend_runtime.c:176` sets it when Start is pressed. `_ppu_write_1` masks BG/sprite-enable bits while gate is held, protecting Mode1's VRAM streaming. Gate is released to 0 at end of InitMode1_Sub6 by `z_02.asm:3262` (`clr.b ($00FF083D).l`). The design spec erroneously listed `$00`; the correct value is `$01`. |
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:92:- `src/zelda_translated/z_07.asm:49-51` — EQU definitions for offsets $0011/$0012/$0013
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:93:- `src/zelda_translated/z_02.asm:3283-3291` — `UpdateMode1Menu_Sub0` PATCH P12 logic
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:96:- `src/zelda_translated/z_02.asm:3261-3262` — `addq.b #1,($0011,A4)` +
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:105:**Location:** `src/zelda_translated/z_07.asm:1461`
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:120:`IsrNmi` dispatch chain (`src/zelda_translated/z_07.asm:1653-1656`):
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:144:| First action | Spins until VBlank interrupts | `z_07.asm:1462` — `jmp LoopForever` |
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:145:| Loop semantics | NMI-driven; `IsrNmi` returns via `rts` each frame | `z_07.asm:1669` — `rts; RTI→RTS` |
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:252:PPUCTRL at `z_07.asm:1457-1458`:
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:367:| `LoopForever` | in `z_07.asm` text segment | label ref |
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:388:These are bank-switching routines in `z_07.asm` — they use their own scratch
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:390:`src/zelda_translated/z_07.asm` around the `CopyCommonCodeToRam` label.
src\gen\z_07.c:1:/* z_07.c — Auto-generated forwarders for promoted z_07 bank symbols.
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:55:src/gen/intro_story_tilemap.c       # extracted from NES ROM at build time
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:56:src/gen/intro_showcase_tilemap.c
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:57:src/gen/intro_font_chr.bin
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:58:src/gen/intro_art_chr.bin
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:59:src/gen/intro_palette.c
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:91:- **`intro_common`** owns intro-stage VDP access. It is a **thin C wrapper around the existing VDP primitives in `genesis_shell.asm`** (`VDP_CTRL = $00C00004`, `VDP_DATA = $00C00000`, plus the register-write sequence at [genesis_shell.asm:220](src/genesis_shell.asm:220)). It does **not** establish a parallel VDP path and does **not** duplicate VDP ownership. The wrapper exposes typed C entry points (`vdp_set_mode_v32`, `vdp_dma_to_vram`, `vdp_write_nametable_row`, `vdp_set_vscroll`, `vdp_load_cram`) that are implemented either as direct writes to the shared `VDP_CTRL`/`VDP_DATA` constants or as calls into the existing asm helpers. Stages call `intro_common` exclusively — no raw VDP port writes in stage code. During the intro takeover window, nothing else writes the VDP; legacy writers (`frontend_runtime.c` phase-1 subphases) are short-circuited per the Integration Hook section.
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:94:- **Asset files in `src/gen/`** are build-tool outputs. Passive data, never edited by hand.
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:128:`tools/extract_intro_assets.py` runs at build time before the C compile stage. Reads the reference data files listed above and emits Genesis-formatted assets into `src/gen/intro_*`.
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:161:3. **Register generated C asset file.** Append `intro_story_tilemap intro_showcase_tilemap intro_palette` to `C_GEN_SOURCES` at [build.bat:105](build.bat:105). The extract tool emits each as a `.c` file in `src/gen/` compatible with the existing `C_GEN_SOURCES` loop.
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:169:5. **Asset validation gate.** After extraction, optionally add `tools/extract_intro_assets.py --verify` as a second call to re-check SHA hashes of emitted assets against committed reference SHAs (`src/gen/intro_asset_hashes.txt`). Fails build if assets drift.
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:239:4. Bake the captured values into `src/gen/intro_handoff_state.c` as a named const struct, e.g.:
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:256:2. DMA the file-select restore CHR (`intro_restore_chr`) to VRAM. This blob is captured once during implementation by snapshotting VRAM state at the point the legacy flow reaches file select (with Start-skip workaround). Baked into `src/gen/intro_restore_chr.c` at build time.
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:353:Build tool emits SHA of each extracted asset (`src/gen/intro_asset_hashes.txt`). SHAs committed to repo. Rebuild diffs SHAs to detect accidental asset regression (e.g., offset drift in the extractor or a corrupted `reference/aldonunez/dat/` file).
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:366:- `AnimateDemoPhase1Subphase2`, `AnimateDemoPhase1Subphase3`, `AnimateDemoPhase1Subphase4` (in `z_02.asm` and the C forwarders in `src/gen/z_02.c`)
src\gen\z_06.c:1:/* z_06.c — Auto-generated forwarders for promoted z_06 bank symbols.
src\gen\z_05.c:1:/* z_05.c — Auto-generated forwarders for promoted z_05 bank symbols.
src\gen\z_04.c:1:/* z_04.c — C port of z_04 leaf functions.
src\gen\z_04.c:2: * Data tables and remaining code stay in z_04.asm.
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:58:Retire the NES emulation layer (PPU/NMI/OAM/APU/CTRL/MMC1 shim) and the transpiled M68K banks (`z_00.asm`..`z_07.asm`). Replace with an owned, native-Genesis C codebase whose only assembly is boot/IO/audio and (optionally) a small hot-path render kernel.
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:446:│   (no src/platform/, src/render/, or src/zelda_translated/ —
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:652:- After **S10**: `nes_io.asm`, `c_shims.asm`, `src/zelda_translated/`, `src/gen/z_*.c` deleted in a single commit after final caller audit. ROM byte-size must drop by the expected amount; unexpected size means a missed dependency.
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:717:- `src/zelda_translated/` (entire)
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:718:- `src/gen/z_*.c` (all transpile adapters)
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:719:- `src/nes_io.asm`, `src/c_shims.asm`, `src/genesis_shell.asm`
src\gen\z_03.c:1:/* z_03.c — Auto-generated forwarders for promoted z_03 bank symbols.
docs\superpowers\specs\2026-04-27-native-file-select-design.md:113:| `src/gen/fs_*.c` | Generated assets via `tools/extract_fs_assets.py`: tilemap for static UI, palettes (Link bright/dim, border, font), font CHR, Link sprite frames CHR, heart cursor sprite CHR. | NEW |
docs\superpowers\specs\2026-04-27-native-file-select-design.md:114:| `src/genesis_shell.asm` | (v6) Add `fs_to_transpiled_trampoline` ASM. Add `fs_native_active` `.bss` symbol. | MODIFIED |
docs\superpowers\specs\2026-04-27-native-file-select-design.md:363:- New `tools/extract_fs_assets.py` — extract NES FS tilemap, palettes, font CHR, Link sprite CHR, heart cursor CHR. Emit `src/gen/fs_*.c`.
docs\superpowers\specs\2026-04-27-native-file-select-design.md:494:| FS song bitmap | `$00` (silent) | `src/genesis_shell.asm:681` clears SongRequest to 0 in `intro_to_file_select_trampoline` before Mode 1; matches NES-Redux silent FS behavior |
src\gen\z_02.c:1:/* z_02.c — C port of z_02 leaf functions.
src\gen\z_02.c:2: * Data tables and remaining code stay in z_02.asm.
src\zelda_translated\z_05.asm:2:; z_05.asm — auto-generated by transpile_6502.py
src\zelda_translated\z_05.asm:18:; (fixed equates omitted — provided by z_07.asm in --all build)
src\zelda_translated\z_05.asm:23:; (var equates omitted — provided by z_07.asm in --all build)
docs\audit\audio_split_plan.md:14:- `src/genesis_shell.asm` VBlank handler calls `music_tick` each frame.
docs\audit\build_chain_decision.md:27:- **Auto-discovery would catch unwanted files.** `$(wildcard $(SRC)/*/*.c $(SRC)/*/*/*.c)` would pick up `src/zelda_translated/*.asm` and any future stray .c — link-order unpredictable. Hash-stability requires deterministic file ordering, which the wildcard expansion gives in practice (sorted by `make`) but couples ROM bytes to filesystem layout.
src\gen\z_01.c:1:/* z_01.c — Auto-generated forwarders for promoted z_01 bank symbols.
docs\superpowers\specs\2026-04-26-native-intro-main-rom-design.md:103:| `src/gen/intro_*.c` | Generated assets via `tools/extract_intro_assets.py`. Existing, kept. |
docs\superpowers\specs\2026-04-26-native-intro-main-rom-design.md:104:| `src/genesis_shell.asm` | Edits: `vblank_mode` seed before IPL, `jsr intro_main` swap, VBlankISR dispatcher, trampoline definition. |
docs\superpowers\specs\2026-04-26-native-intro-main-rom-design.md:213:- Transpiled attract-mode bodies (`UpdateMode0Demo`, `InitDemo_RunTasks`, `InitMode1`, `UpdateMode1Menu`, `TitleScreen`, `StoryScroll`, etc.) become unreachable at runtime under native intro. **Symbols stay linkable.** Dispatch tables in `z_07.asm:2487`, `z_07.asm:2874` still reference them. Physical removal would create link errors; that is a separate drain-queue concern handled in a future spec.
docs\superpowers\specs\2026-04-26-native-intro-main-rom-design.md:223:| Story scroll cadence | 0.5 px/frame (advance only when `FrameCounter & 1`) | `z_02.asm:703,731` |
docs\superpowers\specs\2026-04-26-native-intro-main-rom-design.md:224:| Item flash cadence | sprite-palette toggle on `FrameCounter & $08` | `z_07.asm:2023` |
docs\superpowers\specs\2026-04-23-infra-first-promotion-scaffold-design.md:12:`--check` mode, a CI drift gate that locks `src/gen/*.c` to pure passive status,
docs\superpowers\specs\2026-04-23-infra-first-promotion-scaffold-design.md:20:The project is mid-campaign. `src/gen/z_01`, `z_02`, `z_03`, `z_04`, `z_06`
docs\superpowers\specs\2026-04-23-infra-first-promotion-scaffold-design.md:61:  appearing in `src/gen/*.c` logic bodies, or crossing the gen boundary via
docs\superpowers\specs\2026-04-23-infra-first-promotion-scaffold-design.md:95:- **Plan B:** drain `src/gen/z_05.c` real-logic fns into `room_transfer_runtime`,
docs\superpowers\specs\2026-04-23-infra-first-promotion-scaffold-design.md:101:- **Plan C:** drain `src/gen/z_07.c` across sprite / room / player / object
docs\superpowers\specs\2026-04-23-infra-first-promotion-scaffold-design.md:179:   affected `src/gen/z_0x.c`.
docs\superpowers\specs\2026-04-23-infra-first-promotion-scaffold-design.md:233:- Every `src/gen/*.c` forwarder currently present is represented in its
docs\audit\frontend_deps.md:216:## `src/gen/fs_bg_chr_full.c`
docs\audit\frontend_deps.md:227:## `src/gen/fs_border_chr.c`
docs\audit\frontend_deps.md:238:## `src/gen/fs_font_chr.c`
docs\audit\frontend_deps.md:249:## `src/gen/fs_heart_cursor_chr.c`
docs\audit\frontend_deps.md:260:## `src/gen/fs_link_sprite_chr.c`
docs\audit\frontend_deps.md:271:## `src/gen/fs_palette.c`
docs\audit\frontend_deps.md:282:## `src/gen/fs_static_attr.c`
docs\audit\frontend_deps.md:293:## `src/gen/fs_static_tilemap.c`
docs\audit\frontend_deps.md:304:## `src/gen/intro_art_chr.c`
docs\audit\frontend_deps.md:315:## `src/gen/intro_blink_chr.c`
docs\audit\frontend_deps.md:326:## `src/gen/intro_combined_palette.c`
docs\audit\frontend_deps.md:337:## `src/gen/intro_common_bg_chr.c`
docs\audit\frontend_deps.md:348:## `src/gen/intro_font_chr.c`
docs\audit\frontend_deps.md:359:## `src/gen/intro_misc_chr.c`
docs\audit\frontend_deps.md:370:## `src/gen/intro_palette.c`
docs\audit\frontend_deps.md:381:## `src/gen/intro_punct_chr.c`
docs\audit\frontend_deps.md:392:## `src/gen/intro_restore_chr.c`
docs\audit\frontend_deps.md:403:## `src/gen/intro_restore_palette.c`
docs\audit\frontend_deps.md:414:## `src/gen/intro_sprite_chr.c`
docs\audit\frontend_deps.md:425:## `src/gen/intro_story_tilemap.c`
docs\audit\frontend_deps.md:436:## `src/gen/intro_title_bg_chr.c`
docs\audit\frontend_deps.md:447:## `src/gen/intro_title_fade.c`
docs\audit\frontend_deps.md:458:## `src/gen/intro_title_glow.c`
docs\audit\frontend_deps.md:469:## `src/gen/intro_title_palette.c`
docs\audit\frontend_deps.md:480:## `src/gen/intro_title_sprite_chr.c`
docs\audit\frontend_deps.md:491:## `src/gen/intro_title_tilemap.c`
docs\audit\frontend_deps.md:502:## `src/gen/intro_treasures_tilemap.c`
docs\audit\capture_geometry.md:16:VDP mode confirmed by inspecting `src/genesis_shell.asm`:
docs\superpowers\specs\2026-04-23-plan-c-z07-drain-spec.md:3:**Goal:** Promote every non-forwarder function body in `src/gen/z_07.c`
docs\superpowers\specs\2026-04-23-plan-c-z07-drain-spec.md:4:into its long-term owning runtime module. After Plan C, `src/gen/z_07.c`
docs\superpowers\specs\2026-04-23-plan-c-z07-drain-spec.md:21:## Current `src/gen/z_07.c` inventory (390 lines, HEAD b3c7fe17)
docs\superpowers\specs\2026-04-23-plan-c-z07-drain-spec.md:104:4. Replace the old body in `src/gen/z_07.c` with a single-call
docs\superpowers\specs\2026-04-23-plan-c-z07-drain-spec.md:165:    Insert Plan W marker comments into `src/gen/z_07.c` (per Task 9
docs\superpowers\specs\2026-04-23-plan-c-z07-drain-spec.md:190:- `src/gen/z_07.c` is 100% forwarders inside the auto-wrappers marker
docs\superpowers\specs\2026-04-23-plan-c-z07-drain-spec.md:200:Plan C touches `src/gen/z_07.c` + the listed `*_runtime.c` modules.
docs\superpowers\specs\2026-04-23-plan-c-z07-drain-spec.md:221:- Touching `src/zelda_translated/z_07.asm`. Plan C is C-side only.
docs\superpowers\specs\2026-04-30-roomrom-s7-sword-design.md:16:## NES reference (from z_05.asm WieldSword + Z1 sprite docs)
docs\superpowers\specs\2026-04-30-roomrom-s7-sword-design.md:25:slot = 13. (z_05.asm:WieldSword).
docs\superpowers\specs\2026-04-30-roomrom-s7-sword-design.md:103:- **NES-accurate timing.** State 1 = 5 frames matches z_05.asm:WieldSword.
docs\audit\file_classification.md:78:- `src/gen/fs_bg_chr_full.c`
docs\audit\file_classification.md:79:- `src/gen/fs_border_chr.c`
docs\audit\file_classification.md:80:- `src/gen/fs_font_chr.c`
docs\audit\file_classification.md:81:- `src/gen/fs_heart_cursor_chr.c`
docs\audit\file_classification.md:82:- `src/gen/fs_link_sprite_chr.c`
docs\audit\file_classification.md:83:- `src/gen/fs_palette.c`
docs\audit\file_classification.md:84:- `src/gen/fs_static_attr.c`
docs\audit\file_classification.md:85:- `src/gen/fs_static_tilemap.c`
docs\audit\file_classification.md:86:- `src/gen/intro_art_chr.c`
docs\audit\file_classification.md:87:- `src/gen/intro_blink_chr.c`
docs\audit\file_classification.md:88:- `src/gen/intro_combined_palette.c`
docs\audit\file_classification.md:89:- `src/gen/intro_common_bg_chr.c`
docs\audit\file_classification.md:90:- `src/gen/intro_font_chr.c`
docs\audit\file_classification.md:91:- `src/gen/intro_misc_chr.c`
docs\audit\file_classification.md:92:- `src/gen/intro_palette.c`
docs\audit\file_classification.md:93:- `src/gen/intro_punct_chr.c`
docs\audit\file_classification.md:94:- `src/gen/intro_restore_chr.c`
docs\audit\file_classification.md:95:- `src/gen/intro_restore_palette.c`
docs\audit\file_classification.md:96:- `src/gen/intro_sprite_chr.c`
docs\audit\file_classification.md:97:- `src/gen/intro_story_tilemap.c`
docs\audit\file_classification.md:98:- `src/gen/intro_title_bg_chr.c`
docs\audit\file_classification.md:99:- `src/gen/intro_title_fade.c`
docs\audit\file_classification.md:100:- `src/gen/intro_title_glow.c`
docs\audit\file_classification.md:101:- `src/gen/intro_title_palette.c`
docs\audit\file_classification.md:102:- `src/gen/intro_title_sprite_chr.c`
docs\audit\file_classification.md:103:- `src/gen/intro_title_tilemap.c`
docs\audit\file_classification.md:104:- `src/gen/intro_treasures_tilemap.c`
docs\audit\file_classification.md:105:- `src/gen/music_great_fairy.bin`
docs\audit\file_classification.md:153:- `src/gen/fs_asset_hashes.txt`
docs\audit\file_classification.md:154:- `src/gen/intro_asset_hashes.txt`
docs\audit\file_classification.md:158:- `src/gen/z_01.c`
docs\audit\file_classification.md:159:- `src/gen/z_02.c`
docs\audit\file_classification.md:160:- `src/gen/z_03.c`
docs\audit\file_classification.md:161:- `src/gen/z_04.c`
docs\audit\file_classification.md:162:- `src/gen/z_05.c`
docs\audit\file_classification.md:163:- `src/gen/z_06.c`
docs\audit\file_classification.md:164:- `src/gen/z_07.c`
docs\audit\file_classification.md:168:- `src/zelda_translated/patches/README.md`
docs\audit\file_classification.md:169:- `src/zelda_translated/patches/z_05_patch_P38_check_tile_object.md`
docs\audit\file_classification.md:170:- `src/zelda_translated/patches/z_06_dyntilebuf_palette_precheck.md`
docs\audit\file_classification.md:171:- `src/zelda_translated/patches/z_07_patch_P37_debug_teleport.md`
docs\audit\file_classification.md:172:- `src/zelda_translated/patches/z_07_patch_rng.md`
docs\audit\file_classification.md:173:- `src/zelda_translated/z_00.asm`
docs\audit\file_classification.md:174:- `src/zelda_translated/z_01.asm`
docs\audit\file_classification.md:175:- `src/zelda_translated/z_02.asm`
docs\audit\file_classification.md:176:- `src/zelda_translated/z_03.asm`
docs\audit\file_classification.md:177:- `src/zelda_translated/z_04.asm`
docs\audit\file_classification.md:178:- `src/zelda_translated/z_05.asm`
docs\audit\file_classification.md:179:- `src/zelda_translated/z_06.asm`
docs\audit\file_classification.md:180:- `src/zelda_translated/z_07.asm`
docs\audit\file_classification.md:190:- `src/genesis_shell.asm`
docs\audit\file_classification.md:266:- `src/genesis_shell.asm.bak`
docs\audit\file_classification.md:268:- `src/zelda_translated/z_07 - Copy.txt`
docs\superpowers\specs\2026-04-30-uw-door-priority-design.md:110:- `src/zelda_translated/z_07.asm:3381`, `z_04.asm:3572`: untouched call sites.
docs\audit\repo_tree.txt:101:src/gen/fs_asset_hashes.txt
docs\audit\repo_tree.txt:102:src/gen/fs_bg_chr_full.c
docs\audit\repo_tree.txt:103:src/gen/fs_border_chr.c
docs\audit\repo_tree.txt:104:src/gen/fs_font_chr.c
docs\audit\repo_tree.txt:105:src/gen/fs_heart_cursor_chr.c
docs\audit\repo_tree.txt:106:src/gen/fs_link_sprite_chr.c
docs\audit\repo_tree.txt:107:src/gen/fs_palette.c
docs\audit\repo_tree.txt:108:src/gen/fs_static_attr.c
docs\audit\repo_tree.txt:109:src/gen/fs_static_tilemap.c
docs\audit\repo_tree.txt:110:src/gen/intro_art_chr.c
docs\audit\repo_tree.txt:111:src/gen/intro_asset_hashes.txt
docs\audit\repo_tree.txt:112:src/gen/intro_blink_chr.c
docs\audit\repo_tree.txt:113:src/gen/intro_combined_palette.c
docs\audit\repo_tree.txt:114:src/gen/intro_common_bg_chr.c
docs\audit\repo_tree.txt:115:src/gen/intro_font_chr.c
docs\audit\repo_tree.txt:116:src/gen/intro_misc_chr.c
docs\audit\repo_tree.txt:117:src/gen/intro_palette.c
docs\audit\repo_tree.txt:118:src/gen/intro_punct_chr.c
docs\audit\repo_tree.txt:119:src/gen/intro_restore_chr.c
docs\audit\repo_tree.txt:120:src/gen/intro_restore_palette.c
docs\audit\repo_tree.txt:121:src/gen/intro_sprite_chr.c
docs\audit\repo_tree.txt:122:src/gen/intro_story_tilemap.c
docs\audit\repo_tree.txt:123:src/gen/intro_title_bg_chr.c
docs\audit\repo_tree.txt:124:src/gen/intro_title_fade.c
docs\audit\repo_tree.txt:125:src/gen/intro_title_glow.c
docs\audit\repo_tree.txt:126:src/gen/intro_title_palette.c
docs\audit\repo_tree.txt:127:src/gen/intro_title_sprite_chr.c
docs\audit\repo_tree.txt:128:src/gen/intro_title_tilemap.c
docs\audit\repo_tree.txt:129:src/gen/intro_treasures_tilemap.c
docs\audit\repo_tree.txt:130:src/gen/z_01.c
docs\audit\repo_tree.txt:131:src/gen/z_02.c
docs\audit\repo_tree.txt:132:src/gen/z_03.c
docs\audit\repo_tree.txt:133:src/gen/z_04.c
docs\audit\repo_tree.txt:134:src/gen/z_05.c
docs\audit\repo_tree.txt:135:src/gen/z_06.c
docs\audit\repo_tree.txt:136:src/gen/z_07.c
docs\audit\repo_tree.txt:137:src/genesis_shell.asm
docs\audit\repo_tree.txt:138:src/genesis_shell.asm.bak
docs\audit\repo_tree.txt:203:src/zelda_translated/patches/README.md
docs\audit\repo_tree.txt:204:src/zelda_translated/patches/z_05_patch_P38_check_tile_object.md
docs\audit\repo_tree.txt:205:src/zelda_translated/patches/z_06_dyntilebuf_palette_precheck.md
docs\audit\repo_tree.txt:206:src/zelda_translated/patches/z_07_patch_P37_debug_teleport.md
docs\audit\repo_tree.txt:207:src/zelda_translated/patches/z_07_patch_rng.md
docs\audit\repo_tree.txt:208:src/zelda_translated/z_00.asm
docs\audit\repo_tree.txt:209:src/zelda_translated/z_01.asm
docs\audit\repo_tree.txt:210:src/zelda_translated/z_02.asm
docs\audit\repo_tree.txt:211:src/zelda_translated/z_03.asm
docs\audit\repo_tree.txt:212:src/zelda_translated/z_04.asm
docs\audit\repo_tree.txt:213:src/zelda_translated/z_05.asm
docs\audit\repo_tree.txt:214:src/zelda_translated/z_06.asm
docs\audit\repo_tree.txt:215:src/zelda_translated/z_07 - Copy.txt
docs\audit\repo_tree.txt:216:src/zelda_translated/z_07.asm
docs\superpowers\specs\2026-04-30-roomrom-uw-door-priority-design.md:37:in z_05.asm). Empirical probe showed the door_tiles set overlaps the dungeon
docs\audit\redux_touchpoints.md:48:| `src/gen/fs_palette.c` | 6 | Redux | `*   pal 3 = faded Link   (empty save slot � Redux dark tint)` |
docs\audit\redux_touchpoints.md:49:| `src/gen/fs_palette.c` | 8 | Redux | `*         Zelda1-Redux/src/code/menus/file_select.asm:75-78,` |
docs\audit\redux_touchpoints.md:50:| `src/gen/fs_palette.c` | 9 | Redux | `*         Zelda1-Redux/src/code/menus/menu_tweaks.asm:397-404 */` |
docs\superpowers\plans\2026-05-02-title-roomrom-full-port-master-plan.md:249:- [ ] Run: `rg --files data src/data src/gen RoomRom/data RoomRom/src | rg "\.(c|h|inc|bin|json|dat)$"`
docs\superpowers\plans\2026-05-02-title-roomrom-full-port-master-plan.md:286:- [ ] Reject files under public package matching generated asset extensions in `data/`, `src/data/`, `src/gen/`, `RoomRom/data/`, `RoomRom/src/roomrom_*_chr.c`, and other generated blobs.
docs\superpowers\plans\2026-05-02-title-roomrom-full-port-master-plan.md:329:- [ ] When the flag is set, the build FAILS (not warns) if any file under `data/`, `src/data/`, `src/gen/`, or `RoomRom/data/` is read without a corresponding entry in the generated manifest at `GENERATED_ASSET_ROOT`.
docs\superpowers\plans\2026-04-28-s2-data-extraction.md:21:| `extract_enemies.py` | unwired | likely emits to old `src/gen/` |
docs\superpowers\plans\2026-04-28-s1-reorg-sgdk-integration.md:24:- `data/` — new dir; receives `src/gen/intro_*` and `src/gen/fs_*` extracted-data files
docs\superpowers\plans\2026-04-28-s1-reorg-sgdk-integration.md:69:**Background:** The original S0 classifier (T12) used a catch-all rule that put any `.txt` file under `src/` into `cruft`, plus any `.inc` outside `src/zelda_translated/` and `src/gen/`. That misclassified:
docs\superpowers\plans\2026-04-28-s1-reorg-sgdk-integration.md:72:- 2 live asset-hash manifests under `src/gen/` (emitted by `tools/extract_fs_assets.py` and `tools/extract_intro_assets.py` to fingerprint extraction outputs)
docs\superpowers\plans\2026-04-28-s1-reorg-sgdk-integration.md:77:- `src/genesis_shell.asm.bak`
docs\superpowers\plans\2026-04-28-s1-reorg-sgdk-integration.md:79:- `src/zelda_translated/z_07 - Copy.txt`
docs\superpowers\plans\2026-04-28-s1-reorg-sgdk-integration.md:83:- [ ] **Step 3:** `git rm "src/genesis_shell.asm.bak" "src/nes_io - Copy.txt" "src/zelda_translated/z_07 - Copy.txt"`.
docs\superpowers\plans\2026-04-28-s1-reorg-sgdk-integration.md:156:- [ ] **Step 1: List frontend files.** `git ls-files 'src/intro_*' 'src/fs_*' 'src/frontend_*' | grep -v '^src/gen'`.
docs\superpowers\plans\2026-04-28-s1-reorg-sgdk-integration.md:194:**Files moved:** every file in `src/gen/` matching `intro_*` or `fs_*` (extracted bytes, classifier "generated_data").
docs\superpowers\plans\2026-04-28-s1-reorg-sgdk-integration.md:196:- [ ] **Step 1: List.** `git ls-files src/gen/intro_* src/gen/fs_*`.
docs\superpowers\plans\2026-04-28-s1-reorg-sgdk-integration.md:205:**Files unchanged:** `src/gen/z_01.c`..`src/gen/z_07.c` and `src/zelda_translated/` stay where they are. They define the `z01_*`/`z07_*` symbols still called by drained-but-not-yet-replaced runtime functions (372 callers per S0). Spec Section 8 deletion checkpoint is "after S10."
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:717:Run: `grep -n "h40\|H40\|h32\|H32\|\$8C" src/genesis_shell.asm` to find the relevant register write.
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:968:    "src/zelda_translated",        # transpiled bank source
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:969:    "src/gen/z_",                  # transpile adapters
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:972:    "src/genesis_shell.asm",       # boot/IO definitions
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1318:    ("src/gen/intro_title_bg_chr.c",       "generated_data"),
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1319:    ("src/gen/fs_palette.c",               "generated_data"),
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1320:    ("src/gen/z_07.c",                     "transpile_adapter"),
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1321:    ("src/zelda_translated/z_07.asm",      "transpiled_asm"),
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1324:    ("src/genesis_shell.asm",              "platform_asm"),
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1328:    ("src/genesis_shell.asm.bak",          "cruft"),
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1370:PLATFORM_ASM_NAMES = {"src/genesis_shell.asm", "src/audio_driver.asm"}
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1383:    if rel_norm.startswith("src/zelda_translated/"):
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1385:    if rel_norm.startswith("src/gen/"):
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1698:def test_zelda_translated_dir_is_exempt() -> None:
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1700:        "src/zelda_translated/z_07.asm",
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1722:  - src/zelda_translated/     (legacy bank source — these define the symbols)
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1723:  - src/gen/z_*.c             (transpile adapters)
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1724:  - src/nes_io.asm, src/c_shims.asm, src/genesis_shell.asm (definitions)
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1747:    "src/zelda_translated/",
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1748:    "src/gen/",
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1754:    "src/genesis_shell.asm",
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1877:- VBlank handler in `src/genesis_shell.asm` calls `music_tick`.
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:28:- `src/gen/intro_font_chr.c` — NES font tiles converted to Genesis 4bpp
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:29:- `src/gen/intro_art_chr.c` — story/showcase art tiles
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:30:- `src/gen/intro_palette.c` — CRAM table (NES palette → Genesis 9-bit)
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:31:- `src/gen/intro_story_tilemap.c` — story scroll nametable strip
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:32:- `src/gen/intro_showcase_tilemap.c` — showcase nametable strip
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:33:- `src/gen/intro_restore_chr.c` — CHR blob to restore for file-select handoff
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:34:- `src/gen/intro_restore_palette.c` — CRAM snapshot for file-select handoff
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:35:- `src/gen/intro_handoff_state.c` — captured RAM state constants
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:36:- `src/gen/intro_asset_hashes.txt` — SHA registry for regression detection
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:39:- `tools/extract_intro_assets.py` — reads `reference/aldonunez/dat/`, emits all `src/gen/intro_*` files
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:64:2. **Phase 1 — Extract tool** produces all `src/gen/intro_*` assets (blocker for Phases 2–4).
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:118:src/gen/intro_handoff_state.c.
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:318:Reads reference/aldonunez/dat/ and emits src/gen/intro_*.c files containing
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:320:blobs, and a handoff-state struct. Also emits src/gen/intro_asset_hashes.txt
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:591:- Generated (by running tool): `src/gen/intro_font_chr.c`, `src/gen/intro_art_chr.c`
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:678:ls -la src/gen/intro_font_chr.c src/gen/intro_art_chr.c src/gen/intro_asset_hashes.txt
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:685:        src/gen/intro_font_chr.c src/gen/intro_art_chr.c src/gen/intro_asset_hashes.txt
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:696:- Generated: `src/gen/intro_palette.c`
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:786:        src/gen/intro_palette.c src/gen/intro_asset_hashes.txt
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:797:- Generated: `src/gen/intro_story_tilemap.c`
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:909:        src/gen/intro_story_tilemap.c src/gen/intro_asset_hashes.txt
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:920:- Generated: `src/gen/intro_showcase_tilemap.c`
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:950:        src/gen/intro_showcase_tilemap.c src/gen/intro_asset_hashes.txt
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:960:- Generated: `src/gen/intro_restore_chr.c`, `src/gen/intro_restore_palette.c`, `src/gen/intro_handoff_state.c`
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:1008:head src/gen/intro_restore_chr.c src/gen/intro_restore_palette.c src/gen/intro_handoff_state.c
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:1016:git add tools/extract_intro_assets.py src/gen/intro_restore_chr.c \
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:1017:        src/gen/intro_restore_palette.c src/gen/intro_handoff_state.c \
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:1018:        src/gen/intro_asset_hashes.txt
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:1234:    /* VDP Reg 16 = $9001 (H64 × V32). See src/genesis_shell.asm:236. */
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:1427:        src/gen/intro_font_chr.c src/gen/intro_art_chr.c src/gen/intro_asset_hashes.txt
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:1796:Expected: extractor runs, regenerates `src/gen/intro_*.c`, build continues. At this point C modules are not registered yet, so new .c files are emitted but unused — build still succeeds.
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:2080:**Files:** many (remove unreachable symbols from `z_02.asm`, `src/gen/z_02.c`, `c_shims.asm`, `frontend_runtime.c`, `frontend_runtime.h`, `tools/gen_wrappers/z_02_manifest.json` as applicable)
docs\superpowers\plans\2026-04-27-native-file-select.md:19:- `build.bat` — invoke asset extractor, compile each `src/fs_*.c` + `src/gen/fs_*.c` + `boot.asm`, link, objcopy, fix_checksum.
docs\superpowers\plans\2026-04-27-native-file-select.md:32:- `src/gen/fs_*.c` — generated assets via `tools/extract_fs_assets.py`. Static UI tilemap, Link sprite CHR (bright + dim variants), heart cursor sprite, font CHR, palettes.
docs\superpowers\plans\2026-04-27-native-file-select.md:34:### `src/genesis_shell.asm` (v6 only)
docs\superpowers\plans\2026-04-27-native-file-select.md:42:- Mirror `tools/extract_intro_assets.py`. Reads NES ROM (`Zelda1-Redux/Zelda Redux.nes`), extracts FS tilemap, Link sprite CHR, heart sprite CHR, font CHR, FS palettes (Link bright `$0F,$29,$27,$17` + dim variants), border decoration. Emits `src/gen/fs_*.c` plus `src/gen/fs_asset_hashes.txt`.
docs\superpowers\plans\2026-04-27-native-file-select.md:81:- Read: `src/audio_driver.asm`, `src/z_07.asm` (or wherever `Mode_FileSelect` lives in transpiled tree)
docs\superpowers\plans\2026-04-27-native-file-select.md:184:- Test: build runs without error and emits `src/gen/fs_*.c` files
docs\superpowers\plans\2026-04-27-native-file-select.md:193:Emits src/gen/fs_static_tilemap.c, fs_palette.c, fs_font_chr.c,
docs\superpowers\plans\2026-04-27-native-file-select.md:195:Writes src/gen/fs_asset_hashes.txt with SHA256 of every output.
docs\superpowers\plans\2026-04-27-native-file-select.md:212:    """Emit src/gen/fs_palette.c with Link bright + dim + border palettes.
docs\superpowers\plans\2026-04-27-native-file-select.md:236:    """Emit src/gen/fs_static_tilemap.c from fs_nt.bin dump."""
docs\superpowers\plans\2026-04-27-native-file-select.md:277:Expected: `src/gen/fs_palette.c`, `src/gen/fs_static_tilemap.c`, `src/gen/fs_asset_hashes.txt` exist.
docs\superpowers\plans\2026-04-27-native-file-select.md:282:git add tools/extract_fs_assets.py src/gen/fs_palette.c src/gen/fs_static_tilemap.c src/gen/fs_asset_hashes.txt
docs\superpowers\plans\2026-04-27-native-file-select.md:337:Expected: `src/gen/fs_link_sprite_chr.c`, `fs_heart_cursor_chr.c`, `fs_font_chr.c`, `fs_border_chr.c` exist; hash file updated.
docs\superpowers\plans\2026-04-27-native-file-select.md:342:git add tools/extract_fs_assets.py src/gen/fs_*.c src/gen/fs_asset_hashes.txt
docs\superpowers\plans\2026-04-27-native-file-select.md:1311:- Read: `src/genesis_shell.asm` (find `_sram_load_save_slots`)
docs\superpowers\plans\2026-04-27-native-file-select.md:1317:grep -n "_sram_load_save_slots\|sram\|SRAM_SLOT\|SaveSlot" src/genesis_shell.asm | head -30
docs\superpowers\plans\2026-04-27-native-file-select.md:1322:Edit spec NES-truth table. Add row: `Save slot offsets | $NNNN, $NNNN, $NNNN | src/genesis_shell.asm:LINE`.
docs\superpowers\plans\2026-04-27-native-file-select.md:2529:- Modify: `src/genesis_shell.asm`
docs\superpowers\plans\2026-04-27-native-file-select.md:2583:git add src/genesis_shell.asm
docs\superpowers\plans\2026-04-27-native-file-select.md:2907:- Read: `src/genesis_shell.asm`, all `src/z_*.asm`, `src/*.c`
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:7:**Architecture:** Names-first, tool-second, gate-third. New `*_state.h` headers declare subsystem-owned RAM cells. Shared ABI cells live in `src/nes_abi.h`. A 180-line Python tool reads per-bank JSON manifests describing forwarder signatures and regenerates the marker-bounded forwarder region of each `src/gen/z_0x.c`. A `--check` mode wired into `build.bat` locks gen/ passive the moment this plan ships. ROM must byte-compare identical to baseline after every step.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:27:- `tools/gen_wrappers/z_01_manifest.json` — forwarder inventory for `src/gen/z_01.c`.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:28:- `tools/gen_wrappers/z_02_manifest.json` — forwarder inventory for `src/gen/z_02.c`.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:29:- `tools/gen_wrappers/z_03_manifest.json` — forwarder inventory for `src/gen/z_03.c`.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:30:- `tools/gen_wrappers/z_04_manifest.json` — forwarder inventory for `src/gen/z_04.c`.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:31:- `tools/gen_wrappers/z_05_manifest.json` — forwarder inventory for `src/gen/z_05.c`.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:32:- `tools/gen_wrappers/z_06_manifest.json` — forwarder inventory for `src/gen/z_06.c`.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:33:- `tools/gen_wrappers/z_07_manifest.json` — forwarder inventory for `src/gen/z_07.c`.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:45:- `src/gen/z_01.c` — insert marker-region comments around existing forwarder block. No logic change.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:46:- `src/gen/z_02.c` — same.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:47:- `src/gen/z_03.c` — same.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:48:- `src/gen/z_04.c` — same.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:49:- `src/gen/z_05.c` — same.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:50:- `src/gen/z_06.c` — same.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:51:- `src/gen/z_07.c` — same.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:181:Expected: file contains one line per `RAM(0xNNNN...)` usage found in `src/gen/*.c`.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:200:Purpose: enumerate every magic offset currently surfaced in `src/gen/*.c` so
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:729:`src/gen/z_0x.c` files are declared passive: they forward to owned runtime
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:735:A build fails if the forwarder region of any `src/gen/z_0x.c` drifts from
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:764:- `bank` — stem of the target file (`z_05` → `src/gen/z_05.c`).
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:769:- `symbols[].old` — declared name in `src/gen/z_0x.c`.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:826:"""One-shot helper that scans a src/gen/z_0x.c file and prints a JSON
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:915:python tools\gen_wrappers\_scan_forwarders.py src\gen\z_01.c > tools\gen_wrappers\z_01_manifest.json
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:916:python tools\gen_wrappers\_scan_forwarders.py src\gen\z_02.c > tools\gen_wrappers\z_02_manifest.json
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:917:python tools\gen_wrappers\_scan_forwarders.py src\gen\z_03.c > tools\gen_wrappers\z_03_manifest.json
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:918:python tools\gen_wrappers\_scan_forwarders.py src\gen\z_04.c > tools\gen_wrappers\z_04_manifest.json
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:919:python tools\gen_wrappers\_scan_forwarders.py src\gen\z_05.c > tools\gen_wrappers\z_05_manifest.json
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:920:python tools\gen_wrappers\_scan_forwarders.py src\gen\z_06.c > tools\gen_wrappers\z_06_manifest.json
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:921:python tools\gen_wrappers\_scan_forwarders.py src\gen\z_07.c > tools\gen_wrappers\z_07_manifest.json
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:934:  matching prefix, the scanner skipped it silently; inspect `src/gen/z_0x.c`
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:938:Not every function in `src/gen/z_0x.c` becomes a forwarder manifest entry:
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1096:            src = Path(d) / "z_05.c"
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1097:            src.write_text("/* z_05.c */\n#include \"../nes_abi.h\"\n")
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1118:            src = Path(d) / "z_05.c"
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1119:            src.write_text("/* z_05.c */\n")
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1133:            src = Path(d) / "z_05.c"
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1134:            src.write_text("/* z_05.c */\n")
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1179:region of each src/gen/z_0x.c from its JSON manifest.
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1396:### Task 9: Insert marker regions into `src/gen/z_01.c` through `z_07.c`
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1403:- Modify: `src/gen/z_01.c` through `src/gen/z_07.c`
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1409:Open `src/gen/z_0N.c`. Identify the first forwarder (first `void z0N_...` or
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1463:git add src/gen/z_0N.c
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1531:powershell -Command "(Get-Content src\gen\z_05.c) -replace 'roomxf_copy_column_to_tilebuf\(\);', 'roomxf_copy_column_to_tilebuf(); /* TAMPER */' | Set-Content src\gen\z_05.c"
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1542:git checkout -- src\gen\z_05.c
docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1578:trailer) that promotes code out of `src/gen/` into an owned runtime module,
docs\superpowers\plans\2026-04-30-roomrom-s7-sword-fix.md:900: * NES Zelda 1 reference (z_05.asm WieldSword + z_07.asm UpdateSwordOrRod):
docs\superpowers\plans\2026-04-30-roomrom-s7-sword-fix.md:916: * NES Zelda 1 reference (z_05.asm WieldSword + z_07.asm UpdateSwordOrRod):
docs\superpowers\plans\2026-04-22-c-first-promotion-pipeline-phase1.md:24:  - Owns the current `c_move_object` behavior plus the helper cluster currently living in `src/gen/z_01.c`
docs\superpowers\plans\2026-04-22-c-first-promotion-pipeline-phase1.md:35:- `src/gen/z_01.c`
docs\superpowers\plans\2026-04-22-c-first-promotion-pipeline-phase1.md:348:- Modify: `src/gen/z_01.c`
docs\superpowers\plans\2026-04-22-c-first-promotion-pipeline-phase1.md:443:- [ ] **Step 2: Add the new include in `src/gen/z_01.c`**
docs\superpowers\plans\2026-04-22-c-first-promotion-pipeline-phase1.md:498:git add src/object_runtime.c src/gen/z_01.c
docs\superpowers\plans\2026-04-22-c-first-promotion-pipeline-phase1.md:580:git add src/nes_abi.h src/object_runtime.h src/object_runtime.c src/c_move_object.c src/gen/z_01.c build.bat builds/reports/perf_baseline.json
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:19:| `src/genesis_shell.asm` | Modify | Reset path: seed `vblank_mode=0`, jump to `intro_main`. VBlankISR: dispatch on `vblank_mode`. ASM trampoline `intro_to_file_select_trampoline`. New `vblank_mode` `.bss` symbol. |
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:40:Asset files in `src/gen/intro_*.c` already exist via `tools/extract_intro_assets.py` and need no changes. The intro_demo's local copies of bg/sprite CHR (`tools/intro_demo/intro_*_chr.c` and similar generated-locally files) need to be gathered into `src/gen/` so both ROMs link against one source. That gathering happens in Task 4.
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:47:- Modify: `src/genesis_shell.asm:445-498` (VBlankISR body)
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:48:- Modify: `src/genesis_shell.asm:118-180` (RAM map block — add `vblank_mode` reservation)
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:54:Run: `grep -n "LAST_GAMEMODE\|VRamForceBlankGate\|_current_window_bank" src/genesis_shell.asm`
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:76:Run: `grep -n "FF0FFC\|FF0FFD\|FF0FFE\|FF0FFF" src/genesis_shell.asm src/audio_driver.asm src/nes_io.asm`
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:82:Existing body at `src/genesis_shell.asm:452-498`:
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:143:Run: `grep -n "FF0FF8\|FF0FF9\|FF0FFA\|FF0FFB" src/genesis_shell.asm src/audio_driver.asm src/nes_io.asm`
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:149:In `src/genesis_shell.asm` between the `_sram_load_save_slots` jsr and the IPL lowering at line 425, add:
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:182:git add src/genesis_shell.asm
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:203:- Modify: `src/genesis_shell.asm:436` (replace `jsr IsrReset` with `jsr intro_main`)
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:204:- Modify: `src/genesis_shell.asm` (change `vblank_mode` seed from 1 to 0)
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:214: * Boot entry from src/genesis_shell.asm. Owns the main loop while the
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:277:Find `jsr IsrReset` at `src/genesis_shell.asm:436`. Change to:
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:323:git add src/intro_main.c src/intro_main.h src/genesis_shell.asm build.bat
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:483:## Task 4: Lift title runtime; gather title assets to `src/gen/`
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:489:- Modify: `tools/extract_intro_assets.py` (extend to emit title CHR + title palette + title fade + title glow + title tilemap, all to `src/gen/`)
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:512:- [ ] **Step 2: Extend `tools/extract_intro_assets.py` to emit these into `src/gen/`**
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:517:2. Writes the C array to `src/gen/intro_title_<asset>.c` using the same `_emit_chr_array` / `_emit_palette` / `_emit_tilemap` helper.
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:632:Expected: build step `[2a.0/4] Extracting intro assets from reference data...` produces the new `src/gen/intro_title_*.c` files. Subsequent C compile steps succeed. No unresolved-symbol errors.
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:650:git add tools/extract_intro_assets.py src/gen/intro_title_*.c \
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:657:tools/extract_intro_assets.py into src/gen/. intro_phase wires
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:673:- Modify: `tools/extract_intro_assets.py` (extend to emit common_bg_chr, font_chr, sprite_chr, misc_chr, punct_chr, blink_chr, combined_palette, treasures_tilemap, treasures_palette to `src/gen/`)
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:685:- `intro_font_chr[]` + size  *(already in src/gen)*
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:691:- `intro_story_tilemap_rows`, `intro_story_tilemap[]`  *(already in src/gen as `intro_story_tilemap.c` — verify shape)*
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:694:Run: `ls src/gen/intro_*` and cross-reference. Identify which assets are missing from `src/gen/` and need new emit steps.
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:718:Also replace the existing `intro_story_tilemap.c` emission to ensure it matches the GameCube-version composition that `tools/intro_demo/compose_story_tilemap.py` does (the existing src/gen one may be a different layout).
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:720:Run: `git diff src/gen/intro_story_tilemap.c` after the extraction step to confirm the layout matches what story_runtime.c expects.
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:827:git add tools/extract_intro_assets.py src/gen/intro_*.c \
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:925:If not found in `reference/aldonunez/asm/`, check `src/zelda_translated/z_07.asm` and `src/zelda_translated/z_02.asm`:
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:927:Run: `grep -n "GameMode\|game_mode\|cmpi.b #\$0[0-9],.*GAMEMODE" src/zelda_translated/z_02.asm`
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:952:Read `src/zelda_translated/z_07.asm` around line 1448 (RunGame body) and find the post-init main loop label. Candidates: `_LoopForever`, `_main_loop`, or the label immediately after the `RunGame` `MMC1` setup.
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:956:Run: `grep -n "_LoopForever\|_RunGame\|UpdateMode\|cmpi.b.*GAMEMODE" src/zelda_translated/z_07.asm`
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:962:Run: `grep -n "Song\|song\|music_play\|m_song_req" src/audio_driver.asm src/zelda_translated/z_02.asm | head -30`
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:998:Source: `src/zelda_translated/z_07.asm:<line>`
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:1168:In `src/genesis_shell.asm`, before the include of `audio_driver.asm`, add:
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:1203:git add src/intro_main.c src/intro_handoff.c src/intro_handoff.h src/genesis_shell.asm
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:1223:- Modify: `src/genesis_shell.asm` (replace stub trampoline with real body)
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:1314:git add src/genesis_shell.asm
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:60:- Modify: `src/gen/z_05.c`
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:64:- [ ] **Step 1: Write C function in z_05.c**
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:66:Add at the end of `src/gen/z_05.c`:
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:128:git add src/gen/z_05.c src/c_shims.asm tools/transpile_6502.py
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:154:- Modify: `src/gen/z_05.c`
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:160:Add to `src/gen/z_05.c`:
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:208:git add src/gen/z_05.c src/c_shims.asm tools/transpile_6502.py
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:243:- Modify: `src/gen/z_04.c`
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:249:Add to `src/gen/z_04.c`:
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:299:git add src/gen/z_04.c src/c_shims.asm tools/transpile_6502.py
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:314:- Modify: `src/gen/z_05.c`
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:320:Add to `src/gen/z_05.c`:
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:376:git add src/gen/z_05.c src/c_shims.asm tools/transpile_6502.py
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:425:- Modify: `src/gen/z_05.c`
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:426:- Modify: `src/gen/z_01.c`
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:434:Add to `src/gen/z_01.c`:
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:450:Add to `src/gen/z_01.c`:
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:493:git add src/gen/z_01.c src/c_shims.asm tools/transpile_6502.py
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:527:- Modify: `src/gen/z_01.c`, `src/gen/z_02.c`, `src/gen/z_04.c`, `src/gen/z_05.c`, `src/gen/z_07.c`
docs\superpowers\plans\2026-04-21-carry-flag-return-pattern.md:557:git add src/gen/*.c src/c_shims.asm tools/transpile_6502.py
RoomRom\tools\uw_reachability.py:55:ASM_FILE = REPO_ROOT / "src" / "zelda_translated" / "z_06.asm"
RoomRom\tools\uw_reachability.py:124:    """Read LevelInfoUWQ2Replacements{level} bytes from z_06.asm."""
RoomRom\tools\uw_reachability.py:163:    """Read LevelInfoUWQ2ReplacementSizes (9 bytes) from z_06.asm."""
RoomRom\tools\uw_manifest.py:14:    rooms uses tiles $74-$77 plus $F1, per cellar layout in z_05.asm).
RoomRom\src\uw_room_render_roomrom.c:180: * The NES dungeon room render path (z_05.asm LayoutUWFloor + WriteSquareUW
src\abi\platform_abi.h:4: * The boot shell (src/genesis_shell.asm near line 354) loads
src\abi\legacy_bridge.h:5:// src/zelda_translated/ and src/gen/z_*.c.
src\audio_driver.asm:631:    ; path (UpdateMode0Demo_Sub0 → SilenceAllSound in z_01.asm:4118)
src\audio_driver.asm:1273:; in zelda_translated/z_00.asm, whose in-memory layout may have `even`
src\c_shims.asm:1036:; z_07.asm calls `jsr TransferLevelPatternBlocks`. When BANK_MODE_03="c",
src\c_shims.asm:1714:; Demo_AnimateObjects — void→void (z_02.asm).
src\c_shims.asm:4536:; Import shims — z_04.asm sub-functions callable from C (D2=slot, void).
src\c_shims.asm:4884:; in src/frontend_runtime.c. Each subphase callee remains in z_02.asm.
src\c_shims.asm:4963:; src/save_menu_runtime.c. Each callee remains in z_05.asm or z_07.asm.
src\c_shims.asm:5199:; --- Batch 92: Dodongo family (drained from z_04.asm) ---
src\c_shims.asm:5201:; z_04.asm can be reduced to `jmp c_dodongo_*` stubs that reach the owned
src\c_shims.asm:5275:; --- Batch 93: Manhandla family (drained from z_04.asm) ---
src\c_shims.asm:5383:; --- Batch 94: Lamnola family (drained from z_04.asm) ---
src\c_shims.asm:5433:; --- Batch 95: Vire family (drained from z_04.asm) ---
src\c_shims.asm:5479:; --- Batch 96: Statue family (drained from z_04.asm) ---
src\c_shims.asm:5491:; --- Batch 97: Tektite / Boulder family (drained from z_04.asm) ---
src\c_shims.asm:5574:; --- Batch 101: z_04 Stalfos (drained from z_04.asm) ---
src\c_shims.asm:5589:; --- Batch 102: z_04 Ghini (drained from z_04.asm) ---
src\c_shims.asm:5614:; --- Batch 108: z_07 mode dispatch (drained from z_07.asm) ---
src\zelda_translated\z_04.asm:18:; z_04.asm — auto-generated by transpile_6502.py
src\zelda_translated\z_04.asm:34:; (fixed equates omitted — provided by z_07.asm in --all build)
src\zelda_translated\z_04.asm:39:; (var equates omitted — provided by z_07.asm in --all build)
src\game\enemies\enemy_boss_runtime.c:535: * UpdateGohma  (drained from z_04.asm:9160)
src\game\enemies\enemy_dodongo_runtime.c:38: * Dodongo family (drained from z_04.asm:6001+). The Dodongo boss
src\game\enemies\enemy_dodongo_runtime.c:84: * Dodongo_CheckCollisionsStandardSize (drained from z_04.asm:6052)
src\game\enemies\enemy_dodongo_runtime.c:103: * Dodongo_CheckCollisions (drained from z_04.asm:6001)
src\game\enemies\enemy_dodongo_runtime.c:138: * Dodongo_IsBombInRange (drained from z_04.asm:6270)
src\game\enemies\enemy_dodongo_runtime.c:179: * Dodongo_TryEatBomb (drained from z_04.asm:6168)
src\game\enemies\enemy_dodongo_runtime.c:234: * Dodongo_CheckBombHit (drained from z_04.asm:6092)
src\game\enemies\enemy_dodongo_runtime.c:282: * Dodongo_Draw (drained from z_04.asm:6354)
src\game\enemies\enemy_wallmaster_runtime.c:19: * the sprite-patching path. See z_04.asm for the original comments.
src\game\enemies\enemy_gleeok_runtime.c:132: * L_Gleeok_StoreRefSegDistance  (drained from z_04.asm:9834)
src\game\enemies\enemy_gleeok_runtime.c:238: * Gleeok_CheckCollisions  (drained from z_04.asm:10285)
src\game\enemies\enemy_runtime.h:142:/* Wanderer / Goriya family (drained from z_04.asm / z_07.asm). */
src\game\enemies\enemy_runtime.h:156:/* Dodongo family (drained from z_04.asm). */
src\zelda_translated\z_00.asm:2:; z_00.asm — auto-generated by transpile_6502.py
src\zelda_translated\z_00.asm:18:; (fixed equates omitted — provided by z_07.asm in --all build)
src\zelda_translated\z_00.asm:23:; (var equates omitted — provided by z_07.asm in --all build)
src\zelda_translated\z_02.asm:5:; z_02.asm — auto-generated by transpile_6502.py
src\zelda_translated\z_02.asm:21:; (fixed equates omitted — provided by z_07.asm in --all build)
src\zelda_translated\z_02.asm:26:; (var equates omitted — provided by z_07.asm in --all build)
src\zelda_translated\z_01.asm:72:; z_01.asm — auto-generated by transpile_6502.py
src\zelda_translated\z_01.asm:88:; (fixed equates omitted — provided by z_07.asm in --all build)
src\zelda_translated\z_01.asm:93:; (var equates omitted — provided by z_07.asm in --all build)
src\zelda_translated\z_03.asm:2:; z_03.asm — auto-generated by transpile_6502.py
src\zelda_translated\z_03.asm:18:; (fixed equates omitted — provided by z_07.asm in --all build)
src\zelda_translated\z_03.asm:23:; (var equates omitted — provided by z_07.asm in --all build)
src\zelda_translated\z_03.asm:41:; Stage 2d: data-only mode (code ported to src/gen/z_03.c)
src\zelda_translated\patches\z_07_patch_rng.md:3:**File:** `src/zelda_translated/z_07.asm`
src\zelda_translated\patches\z_07_patch_rng.md:65:2. Open `src/zelda_translated/z_07.asm`, locate label
src\zelda_translated\patches\z_07_patch_P37_debug_teleport.md:5:At the top of `_L_z07_UpdateMode5Play_NotInMenu` (around z_07.asm:3254)
src\zelda_translated\patches\z_07_patch_P37_debug_teleport.md:61:   `src/genesis_shell.asm`; the routine body lives at the bottom of the
src\zelda_translated\patches\z_07_patch_P37_debug_teleport.md:62:   same file (after all `zelda_translated/z_*.asm` includes).
src\zelda_translated\patches\z_06_dyntilebuf_palette_precheck.md:1:# Patch: DynTileBuf Palette Pre-Check (z_06.asm)
src\zelda_translated\patches\z_06_dyntilebuf_palette_precheck.md:7:`src/zelda_translated/z_06.asm`, TransferCurTileBuf (line 814)
src\zelda_translated\patches\z_06_dyntilebuf_palette_precheck.md:12:(z_02.asm) is consumed by the next NMI before TileBufSelector changes. On
src\zelda_translated\patches\z_05_patch_P38_check_tile_object.md:5:Around `_L_z05_LayoutRoomOrCaveOW_SkipSecret:` (z_05.asm:7525) the raw
src\zelda_translated\patches\z_05_patch_P38_check_tile_object.md:65:3. If the warning fires, grep the fresh z_05.asm for
src\zelda_translated\patches\README.md:3:This directory tracks deliberate hand-edits to generated code in `src/zelda_translated/`.
src\zelda_translated\patches\README.md:23:**File:** src/zelda_translated/z_XX.asm
tools\bizhawk_chr_upload_probe.lua:201:    -- DEBUG stores from z_02.asm (not cleared by ClearRam — range $F0-$F2 safe)
tools\bizhawk_phase10_fs1_probe.lua:145:-- (5) Mode1CursorSpriteYs (known ROM constants, per z_02.asm:3759)
src\frontend\intro\intro_main.h:3: * Boot entry from src/genesis_shell.asm. Owns the main loop while the
src\frontend\frontend_runtime.c:138: * Demo / intro mode dispatcher family — ported from z_02.asm
src\frontend\frontend_runtime.c:143: * subphase callees remain in z_02.asm and are reached through IMPORT shims.
src\frontend\fs\fs_main.c:20:/* Generated assets — defined in src/gen/. */
src\frontend\fs\fs_render.c:15:/* CRAM palette indices (matches src/gen/fs_palette.c layout).
tools\bizhawk_sram_roundtrip.lua:151:-- END is at cursor position $03 (checked at z_02.asm:2150-2152)
tools\cycle_profile_buckets.json:39:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:57:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:93:          "caller_src": "zelda_translated\\z_05.asm",
tools\cycle_profile_buckets.json:100:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:118:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:136:          "caller_src": "zelda_translated\\z_01.asm",
tools\cycle_profile_buckets.json:143:          "caller_src": "zelda_translated\\z_01.asm",
tools\cycle_profile_buckets.json:150:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:157:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:164:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:171:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:178:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:185:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:192:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:199:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:206:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:213:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:220:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:227:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:234:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:241:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:248:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:255:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:262:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:269:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:276:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:283:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:290:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:297:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:304:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:311:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:318:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:325:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:343:          "caller_src": "zelda_translated\\z_01.asm",
tools\cycle_profile_buckets.json:350:          "caller_src": "zelda_translated\\z_01.asm",
tools\cycle_profile_buckets.json:357:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:364:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:371:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:378:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:385:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:392:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:399:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:406:          "caller_src": "zelda_translated\\z_05.asm",
tools\cycle_profile_buckets.json:413:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:420:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:427:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:434:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:441:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:459:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:466:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:473:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:480:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:498:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:526:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:544:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.json:592:          "caller_src": "zelda_translated\\z_04.asm",
tools\cycle_profile_buckets.json:664:          "caller_src": "zelda_translated\\z_07.asm",
tools\cycle_profile_buckets.lua:29:      { call_addr = 0x0004B2F2, return_addr = 0x0004B2F6, caller_src = "zelda_translated\\z_07.asm", caller_line = 1644, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:38:      { call_addr = 0x0004B1C2, return_addr = 0x0004B1C6, caller_src = "zelda_translated\\z_07.asm", caller_line = 1517, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:56:      { call_addr = 0x00045280, return_addr = 0x00045284, caller_src = "zelda_translated\\z_05.asm", caller_line = 8633, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:57:      { call_addr = 0x0004BF92, return_addr = 0x0004BF96, caller_src = "zelda_translated\\z_07.asm", caller_line = 3294, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:66:      { call_addr = 0x0004C032, return_addr = 0x0004C036, caller_src = "zelda_translated\\z_07.asm", caller_line = 3374, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:75:      { call_addr = 0x0002DDC2, return_addr = 0x0002DDC6, caller_src = "zelda_translated\\z_01.asm", caller_line = 1556, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:76:      { call_addr = 0x00031410, return_addr = 0x00031412, caller_src = "zelda_translated\\z_01.asm", caller_line = 6908, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:77:      { call_addr = 0x00039EE2, return_addr = 0x00039EE8, caller_src = "zelda_translated\\z_04.asm", caller_line = 1516, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:78:      { call_addr = 0x0003ABC0, return_addr = 0x0003ABC6, caller_src = "zelda_translated\\z_04.asm", caller_line = 3385, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:79:      { call_addr = 0x0003AEF0, return_addr = 0x0003AEF6, caller_src = "zelda_translated\\z_04.asm", caller_line = 3821, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:80:      { call_addr = 0x0003B0F8, return_addr = 0x0003B0FE, caller_src = "zelda_translated\\z_04.asm", caller_line = 4156, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:81:      { call_addr = 0x0003B95C, return_addr = 0x0003B962, caller_src = "zelda_translated\\z_04.asm", caller_line = 5337, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:82:      { call_addr = 0x0003BCEC, return_addr = 0x0003BCF2, caller_src = "zelda_translated\\z_04.asm", caller_line = 5768, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:83:      { call_addr = 0x0003BF48, return_addr = 0x0003BF4E, caller_src = "zelda_translated\\z_04.asm", caller_line = 6076, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:84:      { call_addr = 0x0003C1EE, return_addr = 0x0003C1F4, caller_src = "zelda_translated\\z_04.asm", caller_line = 6526, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:85:      { call_addr = 0x0003C258, return_addr = 0x0003C25E, caller_src = "zelda_translated\\z_04.asm", caller_line = 6574, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:86:      { call_addr = 0x0003C594, return_addr = 0x0003C59A, caller_src = "zelda_translated\\z_04.asm", caller_line = 6951, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:87:      { call_addr = 0x0003C9A2, return_addr = 0x0003C9A8, caller_src = "zelda_translated\\z_04.asm", caller_line = 7526, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:88:      { call_addr = 0x0003CCCC, return_addr = 0x0003CCD2, caller_src = "zelda_translated\\z_04.asm", caller_line = 8028, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:89:      { call_addr = 0x0003CCF0, return_addr = 0x0003CCF6, caller_src = "zelda_translated\\z_04.asm", caller_line = 8039, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:90:      { call_addr = 0x0003CECE, return_addr = 0x0003CED4, caller_src = "zelda_translated\\z_04.asm", caller_line = 8284, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:91:      { call_addr = 0x0003D0BC, return_addr = 0x0003D0C2, caller_src = "zelda_translated\\z_04.asm", caller_line = 8513, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:92:      { call_addr = 0x0003D16E, return_addr = 0x0003D174, caller_src = "zelda_translated\\z_04.asm", caller_line = 8594, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:93:      { call_addr = 0x0003D252, return_addr = 0x0003D258, caller_src = "zelda_translated\\z_04.asm", caller_line = 8707, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:94:      { call_addr = 0x0003DBA4, return_addr = 0x0003DBAA, caller_src = "zelda_translated\\z_04.asm", caller_line = 9967, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:95:      { call_addr = 0x0003E01C, return_addr = 0x0003E022, caller_src = "zelda_translated\\z_04.asm", caller_line = 10577, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:96:      { call_addr = 0x0003E0E0, return_addr = 0x0003E0E6, caller_src = "zelda_translated\\z_04.asm", caller_line = 10669, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:97:      { call_addr = 0x0003E6A0, return_addr = 0x0003E6A6, caller_src = "zelda_translated\\z_04.asm", caller_line = 11461, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:98:      { call_addr = 0x0003EBDC, return_addr = 0x0003EBE2, caller_src = "zelda_translated\\z_04.asm", caller_line = 12140, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:99:      { call_addr = 0x0003EC6A, return_addr = 0x0003EC70, caller_src = "zelda_translated\\z_04.asm", caller_line = 12214, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:100:      { call_addr = 0x0003EF8A, return_addr = 0x0003EF90, caller_src = "zelda_translated\\z_04.asm", caller_line = 12660, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:101:      { call_addr = 0x0003F16E, return_addr = 0x0003F174, caller_src = "zelda_translated\\z_04.asm", caller_line = 12924, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:102:      { call_addr = 0x0004C06E, return_addr = 0x0004C074, caller_src = "zelda_translated\\z_07.asm", caller_line = 3401, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:111:      { call_addr = 0x0002FB50, return_addr = 0x0002FB56, caller_src = "zelda_translated\\z_01.asm", caller_line = 3405, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:112:      { call_addr = 0x000303BC, return_addr = 0x000303C2, caller_src = "zelda_translated\\z_01.asm", caller_line = 4710, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:113:      { call_addr = 0x00039A56, return_addr = 0x00039A5C, caller_src = "zelda_translated\\z_04.asm", caller_line = 920, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:114:      { call_addr = 0x00039B78, return_addr = 0x00039B7E, caller_src = "zelda_translated\\z_04.asm", caller_line = 1081, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:115:      { call_addr = 0x00039DC8, return_addr = 0x00039DCE, caller_src = "zelda_translated\\z_04.asm", caller_line = 1374, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:116:      { call_addr = 0x0003A1D4, return_addr = 0x0003A1DA, caller_src = "zelda_translated\\z_04.asm", caller_line = 1937, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:117:      { call_addr = 0x0003AD7E, return_addr = 0x0003AD84, caller_src = "zelda_translated\\z_04.asm", caller_line = 3627, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:118:      { call_addr = 0x0003B344, return_addr = 0x0003B34A, caller_src = "zelda_translated\\z_04.asm", caller_line = 4503, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:119:      { call_addr = 0x0003B8C2, return_addr = 0x0003B8C8, caller_src = "zelda_translated\\z_04.asm", caller_line = 5264, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:120:      { call_addr = 0x00045204, return_addr = 0x00045208, caller_src = "zelda_translated\\z_05.asm", caller_line = 8569, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:121:      { call_addr = 0x0004BE74, return_addr = 0x0004BE78, caller_src = "zelda_translated\\z_07.asm", caller_line = 3138, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:122:      { call_addr = 0x0004D232, return_addr = 0x0004D236, caller_src = "zelda_translated\\z_07.asm", caller_line = 6106, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:123:      { call_addr = 0x0004D314, return_addr = 0x0004D318, caller_src = "zelda_translated\\z_07.asm", caller_line = 6242, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:124:      { call_addr = 0x0004D33E, return_addr = 0x0004D342, caller_src = "zelda_translated\\z_07.asm", caller_line = 6255, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:125:      { call_addr = 0x0004D742, return_addr = 0x0004D746, caller_src = "zelda_translated\\z_07.asm", caller_line = 6799, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:134:      { call_addr = 0x00039624, return_addr = 0x0003962A, caller_src = "zelda_translated\\z_04.asm", caller_line = 368, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:135:      { call_addr = 0x0003975A, return_addr = 0x00039760, caller_src = "zelda_translated\\z_04.asm", caller_line = 531, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:136:      { call_addr = 0x0003BB86, return_addr = 0x0003BB8C, caller_src = "zelda_translated\\z_04.asm", caller_line = 5620, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:137:      { call_addr = 0x0004C180, return_addr = 0x0004C184, caller_src = "zelda_translated\\z_07.asm", caller_line = 3537, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:146:      { call_addr = 0x0004C6E6, return_addr = 0x0004C6EA, caller_src = "zelda_translated\\z_07.asm", caller_line = 4348, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:163:      { call_addr = 0x0003A644, return_addr = 0x0003A64A, caller_src = "zelda_translated\\z_04.asm", caller_line = 2646, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:172:      { call_addr = 0x0004C062, return_addr = 0x0004C068, caller_src = "zelda_translated\\z_07.asm", caller_line = 3395, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:205:      { call_addr = 0x0003D01E, return_addr = 0x0003D024, caller_src = "zelda_translated\\z_04.asm", caller_line = 8444, mnemonic = "jsr" },
tools\cycle_profile_buckets.lua:241:      { call_addr = 0x0004B2DC, return_addr = 0x0004B2E2, caller_src = "zelda_translated\\z_07.asm", caller_line = 1635, mnemonic = "jsr" },
tools\drain_prompt_template.md:10:bodies from `src/zelda_translated/{{BANK}}.asm` to C in the target runtime
tools\drain_prompt_template.md:18:Source asm functions in `src/zelda_translated/{{BANK}}.asm`:
tools\drain_prompt_template.md:50:- `src/gen/{{BANK}}.c` (forwarders — controller regenerates)
tools\drain_prompt_template.md:53:- `src/zelda_translated/{{BANK}}.asm` (controller replaces bodies with
tools\drain_prompt_template.md:66:z_04.c forwarders — controller handles that after).
tools\drain_prompt_template.md:79:- `TURBO_LINK equ 1` in `src/genesis_shell.asm:44` enables Link no-clip
tools\drain_z04_block_shot.py:7:PATH = Path("src/zelda_translated/z_04.asm")
tools\drain_finalize.py:7:  2. Regenerates src/gen/<bank>.c via emit_gen_wrappers.py
tools\drain_finalize.py:9:  4. Rewrites src/zelda_translated/<bank>.asm, replacing drained bodies
tools\drain_finalize.py:53:ASM_DIR = ROOT / "src" / "zelda_translated"
tools\emit_gen_wrappers.py:2:region of each src/gen/z_0x.c from its JSON manifest.
tools\extract_dmc_samples.py:17:Sample-table source is `src/zelda_translated/z_00.asm`:
tools\extract_fs_assets.py:3:Emits src/gen/fs_static_tilemap.c, fs_palette.c, fs_font_chr.c,
tools\extract_fs_assets.py:5:Writes src/gen/fs_asset_hashes.txt with SHA256 of every output.
tools\extract_fs_assets.py:107:    """Emit src/gen/fs_palette.c — 4 Genesis CRAM palettes for FS render.
tools\extract_fs_assets.py:170:    """Emit src/gen/fs_static_attr.c — 64-byte NES attribute table.
tools\extract_fs_assets.py:203:    """Emit src/gen/fs_static_tilemap.c from the 1024-byte nametable dump.
tools\extract_fs_assets.py:282:    """Convert list of 16-byte NES tiles to Genesis 4bpp and write to src/gen/{symbol}.c."""
tools\extract_fs_assets.py:297:    """Emit src/gen/fs_link_sprite_chr.c from 4 sprite CHR tiles (NES OAM evidence).
tools\extract_fs_assets.py:311:    """Emit src/gen/fs_heart_cursor_chr.c — top half of NES 8x16 cursor sprite.
tools\extract_fs_assets.py:326:    """Emit src/gen/fs_font_chr.c — BG tiles 0x00-0x63 (digits, letters, glyphs).
tools\extract_fs_assets.py:340:    """Emit src/gen/fs_border_chr.c — BG border/frame decoration tiles.
tools\extract_fs_assets.py:352:    """Emit src/gen/fs_bg_chr_full.c — full BG CHR block covering all 256 NES BG tiles.
tools\extract_fs_assets.py:403:    """Write src/gen/fs_asset_hashes.txt — SHA256 of every fs_*.c output."""
tools\extract_intro_assets.py:3:Reads reference/aldonunez/dat/ and emits src/gen/intro_*.c files containing
tools\extract_intro_assets.py:5:blobs, and a handoff-state struct. Also emits src/gen/intro_asset_hashes.txt
tools\extract_intro_assets.py:526:    """Copy the hand-written intro_punct_chr.c verbatim into src/gen/.
tools\extract_intro_assets.py:533:    # If the generated copy already exists in src/gen/ use it as the source;
tools\extract_intro_assets.py:537:    gen_copy = out_path  # out_path IS src/gen/intro_punct_chr.c
tools\extract_intro_assets.py:548:            "git show HEAD:tools/intro_demo/intro_punct_chr.c > src/gen/intro_punct_chr.c"
tools\file_select_demo\build.bat:40:echo [fs_demo] Generating src/gen/ assets via extract_fs_assets.py
tools\gen_objlist_probe.lua:22:-- From z_05.asm line 2205: _L_z05_InitMode_EnterRoom_PlaceList
tools\gen_wrappers\README.md:5:`src/gen/z_0x.c` files are declared passive: they forward to owned runtime
tools\gen_wrappers\README.md:11:A build fails if the forwarder region of any `src/gen/z_0x.c` drifts from
tools\gen_wrappers\README.md:40:- `bank` — stem of the target file (`z_05` → `src/gen/z_05.c`).
tools\gen_wrappers\README.md:45:- `symbols[].old` — declared name in `src/gen/z_0x.c`.
tools\gen_wrappers\README.md:67:Banks whose `src/gen/z_0N.c` do not yet contain the auto-wrappers marker
tools\gen_wrappers\test_emit_gen_wrappers.py:130:            src = Path(d) / "z_05.c"
tools\gen_wrappers\test_emit_gen_wrappers.py:131:            src.write_text("/* z_05.c */\n#include \"platform_abi.h\"\n")
tools\gen_wrappers\test_emit_gen_wrappers.py:152:            src = Path(d) / "z_05.c"
tools\gen_wrappers\test_emit_gen_wrappers.py:153:            src.write_text("/* z_05.c */\n")
tools\gen_wrappers\test_emit_gen_wrappers.py:167:            src = Path(d) / "z_05.c"
tools\gen_wrappers\test_emit_gen_wrappers.py:168:            src.write_text("/* z_05.c */\n")
tools\gen_wrappers\_scan_forwarders.py:1:"""One-shot helper that scans a src/gen/z_0x.c file and prints a JSON
tools\intro_demo\build.bat:41:echo [demo] Generating src/gen/ assets via central extractor
tools\intro_demo\extract_combined_palette.py:12:  Story BG palettes: src/gen/intro_palette.c (already extracted, 4-color
tools\midi_demo\out\music_player.lst:581:                            	   468: ; Path "gen/music_great_fairy.bin" is relative to src/ because vasm is
tools\midi_demo\out\music_player.lst:588:00:00000342 4D494449000004EF	   475:     incbin  "gen/music_great_fairy.bin"
tools\probes\classify_files.py:29:PLATFORM_ASM_NAMES = {"src/genesis_shell.asm", "src/audio_driver.asm"}
tools\probes\classify_files.py:57:    if rel_norm.startswith("src/zelda_translated/"):
tools\probes\classify_files.py:59:    # src/gen/*_asset_hashes.txt are live build manifests emitted by
tools\probes\classify_files.py:61:    if rel_norm.startswith("src/gen/") and rel_norm.endswith("_asset_hashes.txt"):
tools\probes\classify_files.py:63:    if rel_norm.startswith("src/gen/"):
tools\probes\lint_legacy_symbols.py:36:  - src/zelda_translated/           (legacy bank source -- these DEFINE the symbols)
tools\probes\lint_legacy_symbols.py:37:  - src/gen/z_*.c                   (transpile adapters)
tools\probes\lint_legacy_symbols.py:40:  - src/genesis_shell.asm           (boot path; sets a few VDP regs at init)
tools\probes\lint_legacy_symbols.py:83:    "src/zelda_translated/",
tools\probes\lint_legacy_symbols.py:84:    "src/gen/",
tools\probes\lint_legacy_symbols.py:90:    "src/genesis_shell.asm",
tools\probes\scan_legacy_callers.py:39:    "src/zelda_translated",        # transpiled bank source
tools\probes\scan_legacy_callers.py:40:    "src/gen/z_",                  # transpile adapters
tools\probes\scan_legacy_callers.py:43:    "src/genesis_shell.asm",       # boot/IO definitions
tools\probes\test_lint_legacy_symbols.py:40:def test_zelda_translated_dir_is_exempt() -> None:
tools\probes\test_lint_legacy_symbols.py:42:        "src/zelda_translated/z_07.asm",
tools\probes\test_classify_files.py:17:    ("src/gen/intro_title_bg_chr.c",       "generated_data"),
tools\probes\test_classify_files.py:18:    ("src/gen/fs_palette.c",               "generated_data"),
tools\probes\test_classify_files.py:19:    ("src/gen/z_07.c",                     "transpile_adapter"),
tools\probes\test_classify_files.py:20:    ("src/zelda_translated/z_07.asm",      "transpiled_asm"),
tools\probes\test_classify_files.py:23:    ("src/genesis_shell.asm",              "platform_asm"),
tools\probes\test_classify_files.py:27:    ("src/genesis_shell.asm.bak",          "cruft"),
tools\probes\test_classify_files.py:29:    ("src/zelda_translated/z_07 - Copy.txt", "cruft"),
tools\probes\test_classify_files.py:39:    ("src/gen/intro_asset_hashes.txt",     "asset_manifest"),
tools\probes\test_classify_files.py:40:    ("src/gen/fs_asset_hashes.txt",        "asset_manifest"),
tools\transpile_6502.py:5:Reads reference/aldonunez/Z_XX.asm and writes src/zelda_translated/z_XX.asm.
tools\transpile_6502.py:24:OUT_DIR = os.path.join(ROOT, "src", "zelda_translated")
tools\transpile_6502.py:1802:            os.path.join(OUT_DIR, 'z_03.asm'),
tools\transpile_6502.py:1807:            os.path.join(OUT_DIR, 'z_03.asm'),
tools\transpile_6502.py:1812:            os.path.join(OUT_DIR, 'z_03.asm'),
tools\transpile_6502.py:1817:            os.path.join(OUT_DIR, 'z_03.asm'),
tools\transpile_6502.py:1822:            os.path.join(OUT_DIR, 'z_05.asm'),
tools\transpile_6502.py:1827:            os.path.join(OUT_DIR, 'z_05.asm'),
tools\transpile_6502.py:1832:            os.path.join(OUT_DIR, 'z_05.asm'),
tools\transpile_6502.py:1837:            os.path.join(OUT_DIR, 'z_05.asm'),
tools\transpile_6502.py:1842:            os.path.join(OUT_DIR, 'z_06.asm'),
tools\transpile_6502.py:1919:    z07 = os.path.join(OUT_DIR, 'z_07.asm')
tools\transpile_6502.py:1992:        (z_07.asm provides all equates; others would cause vasm duplicate-symbol errors).
tools\transpile_6502.py:2059:        fixed_equs = '; (fixed equates omitted — provided by z_07.asm in --all build)'
tools\transpile_6502.py:2060:        var_equs   = '; (var equates omitted — provided by z_07.asm in --all build)'
tools\transpile_6502.py:2304:    """Post-process patches for z_00.asm.
tools\transpile_6502.py:2350:    """Post-process patches for z_01.asm — TransferDemoPatterns / TransferPatternBlock_Bank1.
tools\transpile_6502.py:2461:    # code label in z_01.asm (ROM on Genesis).  Writes to ROM silently fail on
tools\transpile_6502.py:2830:    """Post-process patches for z_02.asm — TransferCommonPatterns / TransferPatternBlock_Bank2.
tools\transpile_6502.py:3510:    # UpdateModeDSave_Sub2 (the "save → return to title" funnel at z_02.asm
tools\transpile_6502.py:3557:    # — unused anywhere else in z_02.asm per grep — so the descriptor
tools\transpile_6502.py:3632:    # The Mode 1 cursor writer at z_02.asm:3822-3823 seeds the Link ladder
tools\transpile_6502.py:3642:    # `moveq #88,D0` elsewhere in z_02.asm.
tools\transpile_6502.py:3667:    # InitModeEandF_Full's tail (`_anon_z02_5` at z_02.asm:2133-2139) seeds
tools\transpile_6502.py:3706:    # _L_z02_ModeE_HandleAOrB_CheckAB (z_02.asm:2681) dispatches:
tools\transpile_6502.py:3951:    """Stage 2d: strip code functions from z_03.asm, keep only data labels.
tools\transpile_6502.py:4005:    out.append('\n; Stage 2d: data-only mode (code ported to src/gen/z_03.c)\n')
tools\transpile_6502.py:4051:    print(f"  _patch_z03: C-mode data-only emit (code -> src/gen/z_03.c)")
tools\transpile_6502.py:4123:    """Post-process patches for z_04.asm — C function stubs."""
tools\transpile_6502.py:5712:    """Post-process patches for z_06.asm -- replace TransferTileBuf/ContinueTransferTileBuf.
tools\transpile_6502.py:6179:    Reads the already-patched z_06.asm (with 32-bit table, DynTileBuf pre-check)
tools\transpile_6502.py:6264:    out.append('\n; Stage 3a: data-only mode (code ported to src/gen/z_06.c)\n')
tools\transpile_6502.py:6298:    print(f"  _patch_z06: C-mode data-only emit (code -> src/gen/z_06.c)")
tools\transpile_6502.py:6304:    """Post-process patches for z_07.asm — ClearNameTable fast path.
tools\transpile_6502.py:6345:    # in z_01.asm use PHP/PLP (software stack `-(A5)`/`(A5)+`) to serialize
tools\transpile_6502.py:6355:    # in z_01.asm stay intact — other callers still use the transpiled
tools\transpile_6502.py:6392:        assert mo_start is not None, "P48: MoveObject label not found in z_07.asm"
tools\transpile_6502.py:6399:            # (jsr MoveObject at z_07.asm:3137-3138 and elsewhere) still
tools\transpile_6502.py:6679:    # See src/zelda_translated/patches/z_07_patch_P37_debug_teleport.md.

 succeeded in 1318ms:
src\zelda_translated\z_07.asm:19:; Source: reference/aldonunez/Z_07.asm
src\zelda_translated\z_06.asm:3:; Source: reference/aldonunez/Z_06.asm
src\nes_io.asm:1693:    incbin "../reference/aldonunez/dat/nes_bank_00.bin"
src\nes_io.asm:1695:    incbin "../reference/aldonunez/dat/nes_bank_01.bin"
src\nes_io.asm:1697:    incbin "../reference/aldonunez/dat/nes_bank_02.bin"
src\nes_io.asm:1699:    incbin "../reference/aldonunez/dat/nes_bank_03.bin"
src\nes_io.asm:1701:    incbin "../reference/aldonunez/dat/nes_bank_04.bin"
src\nes_io.asm:1703:    incbin "../reference/aldonunez/dat/nes_bank_05.bin"
src\nes_io.asm:1705:    incbin "../reference/aldonunez/dat/nes_bank_06.bin"
src\zelda_translated\z_00.asm:3:; Source: reference/aldonunez/Z_00.asm
RoomRom\tools\walk_z1_disasm.py:4:Phase 1a (items): Parses reference/aldonunez/Z_01.asm Anim_ItemFrameOffsets +
RoomRom\tools\walk_z1_disasm.py:270:        "source": "reference/aldonunez/Z_01.asm",
RoomRom\tools\walk_z1_disasm.py:640:        "source": ["reference/aldonunez/Z_07.asm", "reference/aldonunez/Z_01.asm"],
RoomRom\tools\walk_z1_disasm.py:665:        "source": ["reference/aldonunez/Z_07.asm", "reference/aldonunez/Z_01.asm"],
RoomRom\tools\walk_z1_disasm.py:884:        "source": ["reference/aldonunez/Z_01.asm", "reference/aldonunez/Z_06.asm",
RoomRom\tools\walk_z1_disasm.py:885:                   "reference/aldonunez/Z_02.asm"],
RoomRom\tools\walk_z1_disasm.py:1076:        "source": "reference/aldonunez/Z_02.asm",
RoomRom\tools\walk_z1_disasm.py:1100:        "source": "reference/aldonunez/Z_02.asm",
RoomRom\tools\walk_z1_disasm.py:1189:        "source": ["reference/aldonunez/Z_07.asm", "reference/aldonunez/Z_01.asm",
RoomRom\tools\walk_z1_disasm.py:1190:                   "reference/aldonunez/Z_02.asm"],
RoomRom\tools\walk_z1_disasm.py:1460:            "reference/aldonunez/Z_01.asm", "reference/aldonunez/Z_02.asm",
RoomRom\tools\walk_z1_disasm.py:1461:            "reference/aldonunez/Z_03.asm", "reference/aldonunez/Z_05.asm",
RoomRom\tools\walk_z1_disasm.py:1462:            "reference/aldonunez/Z_06.asm",
src\zelda_translated\z_03.asm:3:; Source: reference/aldonunez/Z_03.asm
src\zelda_translated\z_05.asm:3:; Source: reference/aldonunez/Z_05.asm
docs\superpowers\specs\2026-05-01-roomrom-z1-full-atlas-design.md:107:|   reference/aldonunez/Z_00..Z_07.asm                      |
docs\superpowers\specs\2026-05-01-roomrom-z1-full-atlas-design.md:121:Reads `reference/aldonunez/Z_00..Z_07.asm`. Walks every sprite-emitting code path AND every pattern-data block. Emits a JSON intermediate.
src\zelda_translated\z_02.asm:6:; Source: reference/aldonunez/Z_02.asm
src\zelda_translated\z_04.asm:19:; Source: reference/aldonunez/Z_04.asm
RoomRom\tools\verify_item_chr_manifest.py:40:# Derived from Anim_WriteSpecificItemSprites at reference/aldonunez/Z_01.asm:5279
src\zelda_translated\patches\z_07_patch_rng.md:4:**Routine:** `_L_z07_IsrNmi_LoopRandom` (transpiled from `@LoopRandom` in `reference/aldonunez/Z_07.asm:511`)
src\zelda_translated\patches\z_05_patch_P38_check_tile_object.md:20:NES source (reference/aldonunez/Z_05.asm:5861-5862):
src\zelda_translated\z_01.asm:73:; Source: reference/aldonunez/Z_01.asm
RoomRom\tools\uw_reachability.py:5:Parses NES Z1 underworld level data from `reference/aldonunez/dat/` and
RoomRom\tools\uw_reachability.py:41:    from reference/aldonunez/Z_06.asm:263-266).
RoomRom\tools\uw_manifest.py:10:    (reference/aldonunez/Z_05.asm:5621). Same for all UW levels.
RoomRom\tools\run_uw_level.py:39:        REPO_ROOT / "Zelda1-Redux" / "Legend of Zelda, The (USA).nes",
RoomRom\tools\run_uw_level.py:44:        REPO_ROOT / "Zelda1-Redux" / "Zelda Redux.nes",
RoomRom\tools\run_uw_level.py:96:    env["CODEX_UW_MAP_NAME"] = "Zelda1" if rom_id == "orig" else "Zelda1-Redux"
RoomRom\tools\phase0_prg_smoke.py:29:# files in reference/aldonunez/dat/ are derived from the orig ROM's
docs\superpowers\specs\2026-04-29-roomrom-dungeon-viewer-design.md:145:  (`Zelda1-Redux/code/optional/RecolouredDungeons.asm`) and dungeon CHR
docs\superpowers\specs\2026-04-29-roomrom-dungeon-viewer-design.md:146:  (`Zelda1-Redux/code/gfx/DungeonAssets.bin`). Same room layouts as
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:16:- **NES ROM SHA256:** `8f72dc2e98572eb4ba7c3a902bca5f69c448fc4391837e5f8f0d4556280440ac` (Legend of Zelda, The (USA).nes — locked at S0 from the local copy under `Zelda1-Redux/`)
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:101:- **aldonunez NES disassembly** (`reference/aldonunez/`) — semantic reference for game-logic behavior.
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:525:- Reference NES disasm checked into `reference/aldonunez/`
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:527:  1. **Raw extraction parity:** the intermediate raw-byte output of each extractor (CHR, palette, room layouts, enemy tables, etc., before Genesis conversion) byte-matches NES ROM source data, verified by SHA hash against `reference/aldonunez/` cross-references where applicable.
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:722:- `*.bak`, `*- Copy*`, top-level `Zelda1-Redux/`, stray zips/midis/build_out logs
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:781:- **SGDK** — `https://github.com/Stephane-D/SGDK`, pinned at **v2.11** (commit `ef9292c0`), vendored as a git submodule at `sgdk/`. Adopted as the platform/render layer. Build chain confirmed end-to-end via `sgdk/sample/basics/hello-world`. See `docs/audit/sgdk_integration.md`.
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:784:- `reference/aldonunez/` — NES disassembly, semantic reference (checked in at S0 or S2)
RoomRom\tools\gen_redux_roomrom.py:9:REDUX_OW = ROOT / "Zelda1-Redux" / "code" / "gameplay" / "overworld_screens.asm"
RoomRom\tools\gen_redux_roomrom.py:10:REDUX_OW_CHR = ROOT / "Zelda1-Redux" / "code" / "gfx" / "data_02b.bin"
RoomRom\tools\gen_redux_roomrom.py:11:REDUX_SECRET_CHR = ROOT / "Zelda1-Redux" / "code" / "gfx" / "OverworldAssets.bin"
RoomRom\tools\gen_redux_roomrom.py:12:REDUX_AUTOMAP_CHR = ROOT / "Zelda1-Redux" / "code" / "gameplay" / "automap_tiles.bin"
RoomRom\tools\gen_redux_roomrom.py:154:    # Overworld palette attribute changes from Zelda1-Redux/code/gameplay/overworld_screens.asm.
docs\superpowers\specs\2026-04-27-native-file-select-design.md:29:| Q11 | Cursor = single heart sprite, sits on selected row (slot rows AND action rows). Link brightness palette = preserve Redux byte-exact (`$0F,$29,$27,$17` saved / dim variants empty per `Zelda1-Redux/src/code/menus/file_select.asm:75`). |
docs\superpowers\specs\2026-04-27-native-file-select-design.md:489:| Link bright palette (saved slot) | `$0F,$29,$27,$17` | `Zelda1-Redux/src/code/menus/file_select.asm:75-78` |
docs\superpowers\specs\2026-04-27-native-file-select-design.md:491:| NAME header tile shift | one tile left | `Zelda1-Redux/src/code/menus/file_select.asm:7` |
docs\superpowers\specs\2026-04-27-native-file-select-design.md:492:| Heart row flip | `adc.b #$12` / `adc.b #$07` swap | `Zelda1-Redux/src/code/menus/file_select.asm:13-16` |
docs\superpowers\specs\2026-04-27-native-file-select-design.md:493:| Dash tile reuse | `$2F` (was `$62`) | `Zelda1-Redux/src/code/menus/file_select.asm:25-66` |
docs\superpowers\specs\2026-04-27-native-file-select-design.md:495:| Heart cursor tile index | `$F3` (OAM: tile=`$F3`, attr=`$03` palette3, X=`$28`; Y-pos table: slot0=`$5C`, slot1=`$74`, slot2=`$8C`, copy=`$A7`, erase=`$B7`) | `tools/file_select_test/dump_fs_oam.lua` + NES ROM `$A589` (file offset `0xA599`) via `Zelda1-Redux/src/code/menus/menu_tweaks.asm:.draw_cursor` |
RoomRom\tools\extract_z1_prg_chr.py:5:reference/aldonunez/Z_*.asm, loads the corresponding .dat file, searches
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:8:- `reference/aldonunez/Z_02.asm` — NES bank 2 (file-select, demo, menus)
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:9:- `reference/aldonunez/Z_07.asm` — NES fixed bank (RunGame, InitMode, UpdateMode)
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:10:- `reference/aldonunez/Variables.inc` — NES RAM symbol → address table
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:33:`reference/aldonunez/Z_07.asm:1613-1629` — `UpdateMode_JumpTable` (0-indexed):
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:48:`reference/aldonunez/Z_02.asm:317-320` — `UpdateMode0Demo_Sub2` end:
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:67:`reference/aldonunez/Z_02.asm:197-320` and patches documented in
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:169:`reference/aldonunez/Z_02.asm:213-221` — `UpdateMode0Demo_Sub0` (Start pressed in demo):
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:182:(`reference/aldonunez/Z_02.asm:2422-2586`).
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:184:(`reference/aldonunez/Z_02.asm:2601-2780`) also contain no SongRequest write.
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:191:`reference/Disassembly by camthesaxman/bank0.asm:759-760`:
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:402:`reference/aldonunez/Z_02.asm:200`. Mode1 and its submodes have no reference
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:408:by `UpdateMode0Demo_Sub2` (`reference/aldonunez/Z_02.asm:310-316`) which copies
docs\superpowers\specs\2026-04-26-native-intro-handoff-tbds.md:419:2. `InitMode1_Sub6` at `reference/aldonunez/Z_02.asm:2575-2582` finds the
docs\SPEC.md:54:reference/aldonunez/Z_00–Z_07.asm
docs\superpowers\specs\2026-04-25-intro-title-screen-design.md:43:* `reference/aldonunez/dat/GameTitleTransferBuf.dat` — NES title nametable as transfer-record stream (1121 bytes).
docs\NES_DESIGN_MAP.md:3:**Role:** Reference document. This maps the NES Zelda 1 behavior, frame flow, and scene responsibilities as extracted from the Aldonunez disassembly under `reference/aldonunez`. Used during implementation to ensure the Genesis engine faithfully reproduces NES game behavior.
docs\NES_DESIGN_MAP.md:9:Core frame ownership in the NES game lives primarily in `reference/aldonunez/Z_07.asm`.
docs\NES_DESIGN_MAP.md:44:- `InitializeGameOrMode` in `reference/aldonunez/Z_07.asm`
docs\NES_DESIGN_MAP.md:47:- `BeginUpdateMode` in `reference/aldonunez/Z_01.asm`
docs\NES_DESIGN_MAP.md:51:- `GoToNextMode` and `EndGameMode` in `reference/aldonunez/Z_07.asm`
docs\NES_DESIGN_MAP.md:64:`UpdateMode` in `reference/aldonunez/Z_07.asm` is the clearest top-level behavior map in the original game.
docs\NES_DESIGN_MAP.md:97:Frontend ownership is mostly in `reference/aldonunez/Z_02.asm`.
docs\NES_DESIGN_MAP.md:154:Controller ownership lives in `reference/aldonunez/Z_07.asm`.
docs\NES_DESIGN_MAP.md:179:`UpdateMode5Play` in `reference/aldonunez/Z_07.asm` is the central gameplay coordinator.
docs\NES_DESIGN_MAP.md:213:`UpdatePlayer` in `reference/aldonunez/Z_07.asm` owns the player-centric slice of the play loop.
docs\NES_DESIGN_MAP.md:312:Audio driver ownership starts in `reference/aldonunez/Z_00.asm`.
docs\NES_DESIGN_MAP.md:336:- `reference/aldonunez/Z_00.asm`
docs\NES_DESIGN_MAP.md:338:- `reference/aldonunez/Z_01.asm`
docs\NES_DESIGN_MAP.md:342:- `reference/aldonunez/Z_02.asm`
docs\NES_DESIGN_MAP.md:344:- `reference/aldonunez/Z_03.asm`
docs\NES_DESIGN_MAP.md:346:- `reference/aldonunez/Z_04.asm`
docs\NES_DESIGN_MAP.md:348:- `reference/aldonunez/Z_05.asm`
docs\NES_DESIGN_MAP.md:350:- `reference/aldonunez/Z_06.asm`
docs\NES_DESIGN_MAP.md:352:- `reference/aldonunez/Z_07.asm`
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:115:**Source of truth is the existing committed disassembly reference data in `reference/aldonunez/dat/`, not an external NES ROM.** This matches the repo's current pattern (e.g., `src/nes_io.asm` and `tools/transpile_6502.py` consume this same reference tree). Relevant files for intro:
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:117:- `reference/aldonunez/dat/DemoBackgroundPatterns.dat` — background CHR for story screen
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:118:- `reference/aldonunez/dat/DemoSpritePatterns.dat` — sprite CHR for intro
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:119:- `reference/aldonunez/dat/DemoTextFields.dat` — story text strings
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:120:- `reference/aldonunez/dat/DemoLineTextAddrs.inc` — text field address table
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:121:- `reference/aldonunez/dat/StoryTileAttrTransferBuf.dat` — palette-attribute strip
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:122:- `reference/aldonunez/dat/GameTitleTransferBuf.dat` — title-related buffer (inspect for showcase relevance)
docs\superpowers\specs\2026-04-24-intro-native-rewrite-design.md:353:Build tool emits SHA of each extracted asset (`src/gen/intro_asset_hashes.txt`). SHAs committed to repo. Rebuild diffs SHAs to detect accidental asset regression (e.g., offset drift in the extractor or a corrupted `reference/aldonunez/dat/` file).
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:538:(c) Implement `_read_title_bg_chr()`, `_read_title_sprite_chr()`, `_read_title_palette()`, `_read_title_tilemap_cells()`, `_read_title_tilemap_rows()`, `_read_title_fade()`, `_read_title_glow()` by lifting the parse logic from the matching `tools/intro_demo/extract_title_*.py` scripts. These scripts read from `reference/aldonunez/dat/`.
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:921:Run: `grep -rn "Mode_FileSelect\|MODE_FILE_SELECT\|MODE_REGISTER\|file_select" reference/aldonunez/asm/`
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:925:If not found in `reference/aldonunez/asm/`, check `src/zelda_translated/z_07.asm` and `src/zelda_translated/z_02.asm`:
docs\superpowers\plans\2026-04-26-native-intro-main-rom.md:991:Source: `reference/aldonunez/asm/<file>.asm:<line>`
docs\superpowers\plans\2026-04-26-intro-title-screen.md:29:- Run BizHawk against NES Zelda ROM (path TBD by user; common location `reference/aldonunez/zelda.nes` or similar)
docs\superpowers\plans\2026-04-26-intro-title-screen.md:37:ls reference/aldonunez/ 2>/dev/null | grep -i nes | head -5
docs\superpowers\plans\2026-04-26-intro-title-screen.md:284:"""Parse reference/aldonunez/dat/GameTitleTransferBuf.dat into a 32x30
docs\superpowers\plans\2026-04-26-intro-title-screen.md:1129:sed -n '342,360p' reference/aldonunez/Z_02.asm
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:7:**Architecture:** Three new C modules (`intro_common`, `intro_story`, `intro_showcase`) replace phase-1 subphase dispatchers in `frontend_runtime.c` via a takeover flag. VDP Reg 16 flips V64 → V32 during fade-out, V32 → V64 during handoff. Assets extracted from committed `reference/aldonunez/dat/` files at build time — no external NES ROM dependency.
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:39:- `tools/extract_intro_assets.py` — reads `reference/aldonunez/dat/`, emits all `src/gen/intro_*` files
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:318:Reads reference/aldonunez/dat/ and emits src/gen/intro_*.c files containing
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:802:- `reference/aldonunez/dat/DemoTextFields.dat` (story text field definitions)
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:803:- `reference/aldonunez/dat/DemoLineTextAddrs.inc` (text field address table)
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:804:- `reference/aldonunez/dat/StoryTileAttrTransferBuf.dat` (palette attribute strip)
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:922:Follows the same pattern as Task 8. Source files for the item showcase: inspect `reference/aldonunez/dat/GameTitleTransferBuf.dat` and any other `Demo*` or `Story*` file that contains the item-parade row data. Implementation steps identical to Task 8 with `intro_showcase_tilemap` symbol.
docs\superpowers\plans\2026-04-24-intro-native-rewrite.md:926:Run: `od -An -v -t x1 reference/aldonunez/dat/GameTitleTransferBuf.dat | head`
docs\audit\parity_schema_check.md:15:   title-screen-idle frame from both NES (`Zelda1-Redux/Legend of Zelda, The
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1555:- [ ] **Step 3: Inspect `Zelda1-Redux/` to enumerate available Redux features**
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1557:The repo includes a top-level `Zelda1-Redux/` directory containing `optional/` patches and `src/code/menus/` source. Walk these once to extract the feature list that exists in upstream Redux but isn't yet implemented in FINAL TRY. Goal: confirm Section 4.6's flag table covers everything the user might want.
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1559:Run: `ls Zelda1-Redux/optional/ Zelda1-Redux/src/code/ 2>/dev/null`
docs\superpowers\plans\2026-04-27-s0-inventory-guardrails.md:1580:| <feature from Zelda1-Redux/optional/> | <status> | <flag if any> | <notes> |
docs\audit\redux_touchpoints.md:49:| `src/gen/fs_palette.c` | 8 | Redux | `*         Zelda1-Redux/src/code/menus/file_select.asm:75-78,` |
docs\audit\redux_touchpoints.md:50:| `src/gen/fs_palette.c` | 9 | Redux | `*         Zelda1-Redux/src/code/menus/menu_tweaks.asm:397-404 */` |
docs\superpowers\plans\2026-04-27-native-file-select.md:42:- Mirror `tools/extract_intro_assets.py`. Reads NES ROM (`Zelda1-Redux/Zelda Redux.nes`), extracts FS tilemap, Link sprite CHR, heart sprite CHR, font CHR, FS palettes (Link bright `$0F,$29,$27,$17` + dim variants), border decoration. Emits `src/gen/fs_*.c` plus `src/gen/fs_asset_hashes.txt`.
docs\superpowers\plans\2026-04-27-native-file-select.md:129:"%BIZHAWK_DIR%\EmuHawk.exe" --lua=dump_fs_oam.lua "Zelda1-Redux/Zelda Redux.nes"
docs\superpowers\plans\2026-04-27-native-file-select.md:168:"%BIZHAWK_DIR%\EmuHawk.exe" --lua=dump_fs_nametable.lua "Zelda1-Redux/Zelda Redux.nes"
docs\superpowers\plans\2026-04-27-native-file-select.md:203:ROM = REPO / "Zelda1-Redux" / "Zelda Redux.nes"
docs\superpowers\plans\2026-04-27-native-file-select.md:214:    Source: Zelda1-Redux/src/code/menus/file_select.asm:75-78
docs\audit\s0_close.md:19:- **Build chain verified** end-to-end via `sgdk/sample/basics/hello-world`
docs\audit\s0_close.md:70:4. **Open:** Build `sgdk/sample/basics/hello-world/out/rom.bin` in BizHawk to confirm SGDK runtime boots cleanly (visual confirmation, needs user steering).
docs\superpowers\plans\2026-04-28-s3-overworld-room-render.md:98:2. **Room metadata encoding.** S2 extracted column-encoded layout + attribute bytes. Verify that the decode logic to convert that into `bg_tile[col, row]` is documented somewhere (probably in `reference/aldonunez/` disasm). Replicate faithfully.
docs\superpowers\plans\2026-05-02-title-roomrom-full-port-master-plan.md:897:- [ ] Extract UW collision from NES room attribute bytes + metatile definition tables. Source: `reference/aldonunez/*.asm` attribute decoding + NES PRG bank metatile tables documented in the disassembly.
docs\audit\s2_close.md:63:`extract_dat_sidecars.py` writes `reference/aldonunez/dat/` for the transpiler
docs\audit\sgdk_integration.md:69:- **Sample built:** `sgdk/sample/basics/hello-world/`
RoomRom\src\ow_room_render_roomrom.c:82: *   reference/aldonunez/Z_07.asm WalkableTiles ($8D,$91,$9C,$AC,$AD,$CC,$D2,$D5,$DF)
RoomRom\src\main.c:21: *              Source: reference/aldonunez/Z_05.asm Link_HandleInput +
RoomRom\src\roomrom_combat.h:6: * NES Z1 reference (reference/aldonunez/Z_05.asm WieldSword + Z_07.asm
RoomRom\src\roomrom_combat.c:8: * NES Z1 model (reference/aldonunez/Z_05.asm WieldSword + Z_07.asm
RoomRom\src\roomrom_combat.c:144: * Redux (Zelda1-Redux/code/gameplay/sword_draw.asm:104): OW does not
RoomRom\src\roomrom_combat.c:167: * Source: Zelda1-Redux/code/gameplay/sword_draw.asm wide_sword_xpos/ypos/
RoomRom\src\roomrom_boomerang.h:6: * NES Z1 reference (reference/aldonunez/Z_05.asm WieldBoomerang +
RoomRom\src\roomrom_sprites.h:19: * NES Z1 source: reference/aldonunez/Z_01.asm Anim_ItemFrameTiles +
tools\build_data.py:49:    # reference/aldonunez/dat/ for the transpiler, not the data/ tree.
tools\compare_vram_reference.py:6:  reference/aldonunez/dat/CommonBackgroundPatterns.dat
tools\compare_vram_reference.py:7:  reference/aldonunez/dat/CommonSpritePatterns.dat
tools\extract_audio.py:30:  music_blob.dat, music_blob.inc  (and reference/aldonunez/dat/*.dat)
tools\extract_dat_sidecars.py:4:from the NES ROM into reference/aldonunez/dat/.
tools\extract_frontend.py:31:  reference/aldonunez/dat/StoryTileAttrTransferBuf.dat
tools\extract_frontend.py:32:  reference/aldonunez/dat/GameTitleTransferBuf.dat
tools\extract_frontend.py:789:            ".dat binaries to reference/aldonunez/dat/ for transitional callers"
tools\extract_intro_assets.py:3:Reads reference/aldonunez/dat/ and emits src/gen/intro_*.c files containing
tools\extract_fs_assets.py:20:with Zelda1-Redux/Zelda Redux.nes, copy C:\\tmp\\fs_chr.bin here.
tools\extract_fs_assets.py:119:            Zelda1-Redux/src/code/menus/file_select.asm:75-78 (Link palette overrides).
tools\extract_fs_assets.py:138:        # very-dark-red. Source: Zelda1-Redux/menu_tweaks.asm:397-404
tools\extract_fs_assets.py:152:    out.append(" *         Zelda1-Redux/src/code/menus/file_select.asm:75-78,")
tools\extract_fs_assets.py:153:    out.append(" *         Zelda1-Redux/src/code/menus/menu_tweaks.asm:397-404 */")
tools\intro_demo\compose_treasures_tilemap.py:91:# reference/aldonunez/Z_02.asm:391-399 (one row per scroll position).
tools\intro_demo\extract_title_tilemap.py:2:"""Parse reference/aldonunez/dat/GameTitleTransferBuf.dat into a 32x30
tools\t37_input_scenario.lua:6:-- Pickup mechanic (reference/aldonunez/Z_01.asm:718-729):
tools\transpile_6502.py:5:Reads reference/aldonunez/Z_XX.asm and writes src/zelda_translated/z_XX.asm.
tools\transpile_6502.py:1946:; Source: reference/aldonunez/{srcname}
tools\transpile_6502.py:2308:    reference/aldonunez/dat/, so the transpiler can inline the real data and
tools\transpile_6502.py:5285:    # reference/aldonunez/dat/ObjListAddrs.inc was extracted from NES bank

 succeeded in 1327ms:
reference/Disassembly by Trax/_downloaded from.txt
reference/Disassembly by Trax/zelda1bank0.txt
reference/Disassembly by Trax/zelda1bank1.txt
reference/Disassembly by Trax/zelda1bank2.txt
reference/Disassembly by Trax/zelda1bank3.txt
reference/Disassembly by Trax/zelda1bank4.txt
reference/Disassembly by Trax/zelda1bank5.txt
reference/Disassembly by Trax/zelda1bank6.txt
reference/Disassembly by Trax/zelda1bank7.txt
reference/Disassembly by Trax/zelda1rammap.txt
reference/Disassembly by camthesaxman/_downloaded from.txt
reference/Disassembly by camthesaxman/audio.inc
reference/Disassembly by camthesaxman/bank0.asm
reference/Disassembly by camthesaxman/bank1.asm
reference/Disassembly by camthesaxman/bank2.asm
reference/Disassembly by camthesaxman/bank3.asm
reference/Disassembly by camthesaxman/bank4.asm
reference/Disassembly by camthesaxman/bank5.asm
reference/Disassembly by camthesaxman/bank6.asm
reference/Disassembly by camthesaxman/bank7.asm
reference/Disassembly by camthesaxman/nes.inc
reference/Disassembly by camthesaxman/notes.inc
reference/Disassembly by camthesaxman/songs.asm
reference/Disassembly by camthesaxman/songs.inc
reference/Disassembly by camthesaxman/zelda.asm
reference/SONIC2_W.68K
reference/Sonic 2/s2.lst
reference/Sonic 2/s2built.bin
reference/Sonic 2/sound/DAC/generated/Bongo.dpcm
reference/Sonic 2/sound/DAC/generated/Bongo.inc
reference/Sonic 2/sound/DAC/generated/Clap.dpcm
reference/Sonic 2/sound/DAC/generated/Clap.inc
reference/Sonic 2/sound/DAC/generated/Kick.dpcm
reference/Sonic 2/sound/DAC/generated/Kick.inc
reference/Sonic 2/sound/DAC/generated/Scratch.dpcm
reference/Sonic 2/sound/DAC/generated/Scratch.inc
reference/Sonic 2/sound/DAC/generated/Snare.dpcm
reference/Sonic 2/sound/DAC/generated/Snare.inc
reference/Sonic 2/sound/DAC/generated/Timpani.dpcm
reference/Sonic 2/sound/DAC/generated/Timpani.inc
reference/Sonic 2/sound/DAC/generated/Tom.dpcm
reference/Sonic 2/sound/DAC/generated/Tom.inc
reference/Sonic 2/sound/DAC/generated/hashes.lua
reference/Sonic 2/sound/PCM/generated/SEGA.inc
reference/Sonic 2/sound/PCM/generated/SEGA.pcm
reference/Sonic 2/sound/PCM/generated/hashes.lua
reference/Sonic 2/sound/music/generated/81 - 2 Player Menu.inc
reference/Sonic 2/sound/music/generated/81 - 2 Player Menu.sax
reference/Sonic 2/sound/music/generated/82 - EHZ.inc
reference/Sonic 2/sound/music/generated/82 - EHZ.sax
reference/Sonic 2/sound/music/generated/83 - MCZ 2P.inc
reference/Sonic 2/sound/music/generated/83 - MCZ 2P.sax
reference/Sonic 2/sound/music/generated/84 - OOZ.inc
reference/Sonic 2/sound/music/generated/84 - OOZ.sax
reference/Sonic 2/sound/music/generated/85 - MTZ.inc
reference/Sonic 2/sound/music/generated/85 - MTZ.sax
reference/Sonic 2/sound/music/generated/86 - HTZ.inc
reference/Sonic 2/sound/music/generated/86 - HTZ.sax
reference/Sonic 2/sound/music/generated/87 - ARZ.inc
reference/Sonic 2/sound/music/generated/87 - ARZ.sax
reference/Sonic 2/sound/music/generated/88 - CNZ 2P.inc
reference/Sonic 2/sound/music/generated/88 - CNZ 2P.sax
reference/Sonic 2/sound/music/generated/89 - CNZ.inc
reference/Sonic 2/sound/music/generated/89 - CNZ.sax
reference/Sonic 2/sound/music/generated/8A - DEZ.inc
reference/Sonic 2/sound/music/generated/8A - DEZ.sax
reference/Sonic 2/sound/music/generated/8B - MCZ.inc
reference/Sonic 2/sound/music/generated/8B - MCZ.sax
reference/Sonic 2/sound/music/generated/8C - EHZ 2P.inc
reference/Sonic 2/sound/music/generated/8C - EHZ 2P.sax
reference/Sonic 2/sound/music/generated/8D - SCZ.inc
reference/Sonic 2/sound/music/generated/8D - SCZ.sax
reference/Sonic 2/sound/music/generated/8E - CPZ.inc
reference/Sonic 2/sound/music/generated/8E - CPZ.sax
reference/Sonic 2/sound/music/generated/8F - WFZ.inc
reference/Sonic 2/sound/music/generated/8F - WFZ.sax
reference/Sonic 2/sound/music/generated/90 - HPZ.inc
reference/Sonic 2/sound/music/generated/90 - HPZ.sax
reference/Sonic 2/sound/music/generated/91 - Options.inc
reference/Sonic 2/sound/music/generated/91 - Options.sax
reference/Sonic 2/sound/music/generated/92 - Special Stage.inc
reference/Sonic 2/sound/music/generated/92 - Special Stage.sax
reference/Sonic 2/sound/music/generated/93 - Boss.inc
reference/Sonic 2/sound/music/generated/93 - Boss.sax
reference/Sonic 2/sound/music/generated/94 - Final Boss.inc
reference/Sonic 2/sound/music/generated/94 - Final Boss.sax
reference/Sonic 2/sound/music/generated/95 - Ending.inc
reference/Sonic 2/sound/music/generated/95 - Ending.sax
reference/Sonic 2/sound/music/generated/96 - Super Sonic.inc
reference/Sonic 2/sound/music/generated/96 - Super Sonic.sax
reference/Sonic 2/sound/music/generated/97 - Invincible.inc
reference/Sonic 2/sound/music/generated/97 - Invincible.sax
reference/Sonic 2/sound/music/generated/98 - Extra Life.inc
reference/Sonic 2/sound/music/generated/99 - Title Screen.inc
reference/Sonic 2/sound/music/generated/99 - Title Screen.sax
reference/Sonic 2/sound/music/generated/9A - End of Act.inc
reference/Sonic 2/sound/music/generated/9A - End of Act.sax
reference/Sonic 2/sound/music/generated/9B - Game Over.inc
reference/Sonic 2/sound/music/generated/9C - Continue.inc
reference/Sonic 2/sound/music/generated/9C - Continue.sax
reference/Sonic 2/sound/music/generated/9D - Got Emerald.inc
reference/Sonic 2/sound/music/generated/9E - Credits.inc
reference/Sonic 2/sound/music/generated/9F - Drowning.inc
reference/Sonic 2/sound/music/generated/9F - Drowning.sax
reference/Sonic 2/sound/music/generated/hashes.lua
reference/Sonic The Hedgehog 2 (World) (Rev B).md
reference/aldonunez/BeginEndVars.inc
reference/aldonunez/CaveVars.inc
reference/aldonunez/CommonVars.inc
reference/aldonunez/ObjVars.inc
reference/aldonunez/Variables.inc
reference/aldonunez/Z_00.asm
reference/aldonunez/Z_01.asm
reference/aldonunez/Z_02.asm
reference/aldonunez/Z_03.asm
reference/aldonunez/Z_04.asm
reference/aldonunez/Z_05.asm
reference/aldonunez/Z_06.asm
reference/aldonunez/Z_07.asm
reference/aldonunez/_downloaded from.txt
reference/sega2f_files/image292.wmz
reference/sega2f_files/image293.gif
reference/sega2f_files/image294.wmz
reference/sega2f_files/image295.gif
reference/sega2f_files/image296.wmz
reference/sega2f_files/image297.gif
reference/sega2f_files/image298.wmz
reference/sega2f_files/image299.gif
reference/sega2f_files/image300.wmz
reference/sega2f_files/image301.gif
reference/sega2f_files/image302.wmz
reference/sega2f_files/image303.gif
reference/sega2f_files/image304.wmz
reference/sega2f_files/image305.gif
reference/sega2f_files/image306.wmz
reference/sega2f_files/image307.gif
reference/sega2f_files/image308.wmz
reference/sega2f_files/image309.gif
reference/sega2f_files/image310.wmz
reference/sega2f_files/image311.gif
reference/sega2f_files/image312.wmz
reference/sega2f_files/image313.gif
reference/sega2f_files/image314.wmz
reference/sega2f_files/image315.gif
reference/sega2f_files/image316.wmz
reference/sega2f_files/image317.gif
reference/sega2f_files/image318.wmz
reference/sega2f_files/image319.gif
reference/sega2f_files/image320.wmz
reference/sega2f_files/image321.gif
reference/sega2f_files/image322.wmz
reference/sega2f_files/image323.gif
reference/sega2f_files/image324.wmz
reference/sega2f_files/image325.gif
reference/sega2f_files/image326.wmz
reference/sega2f_files/image327.gif
reference/sega2f_files/image328.wmz
reference/sega2f_files/image329.gif
reference/sega2f_files/image330.wmz
reference/sega2f_files/image331.gif
reference/sega2f_files/image332.wmz
reference/sega2f_files/image333.gif
reference/sega2f_files/image334.wmz
reference/sega2f_files/image335.gif
reference/sega2f_files/image336.wmz
reference/sega2f_files/image337.gif
reference/sega2f_files/image338.wmz
reference/sega2f_files/image339.gif
reference/sega2f_files/image340.wmz
reference/sega2f_files/image341.gif
reference/sega2f_files/image342.wmz
reference/sega2f_files/image343.gif
reference/sega2f_files/image344.wmz
reference/sega2f_files/image345.gif
reference/sega2f_files/image346.wmz
reference/sega2f_files/image347.gif
reference/sega2f_files/image348.wmz
reference/sega2f_files/image349.gif
reference/sega2f_files/image350.wmz
reference/sega2f_files/image351.gif
reference/sega2f_files/image352.wmz
reference/sega2f_files/image353.gif
reference/sega2f_files/image354.wmz
reference/sega2f_files/image355.gif
reference/sega2f_files/image356.wmz
reference/sega2f_files/image357.gif
reference/sega2f_files/image358.wmz
reference/sega2f_files/image359.gif
reference/sega2f_files/image360.wmz
reference/sega2f_files/image361.gif
reference/sega2f_files/image362.wmz
reference/sega2f_files/image363.gif
reference/sega2f_files/image364.wmz
reference/sega2f_files/image365.gif
reference/sega2f_files/image366.wmz
reference/sega2f_files/image367.gif
reference/sega2f_files/image368.wmz
reference/sega2f_files/image369.gif
reference/sega2f_files/oledata.mso
sgdk

 succeeded in 2113ms:
.\build_f3.bat:3:call "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\build.bat" > "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\build_f3_log.txt" 2>&1
.\build_f3.bat:4:echo BUILD_EXIT=%ERRORLEVEL% >> "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\build_f3_log.txt"
.\CODEX_HANDOFF.md:48:$err = "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\RoomRom\build_err.txt"
.\debates\002-codebase-cleanup-prep\context.md:37:- `FIX THIS.avi` (57M) — bug-report video
.\debates\002-codebase-cleanup-prep\context.md:38:- `SCROLL TIME.avi` (47M) — bug-report video
.\debates\002-codebase-cleanup-prep\context.md:39:- `Zelda1-Redux.zip` (1.7M) — already extracted to `Zelda1-Redux/`
.\debates\002-codebase-cleanup-prep\context.md:40:- `VisualStudioSetup.exe` (4.2M)
.\debates\002-codebase-cleanup-prep\context.md:41:- `rustup-init.exe` (12.2M)
.\debates\002-codebase-cleanup-prep\context.md:43:- `a.out` (280B)
.\debates\002-codebase-cleanup-prep\context.md:48:- `bout.txt` (72K)
.\debates\002-codebase-cleanup-prep\context.md:49:- `build_a3_fix.txt` x3, `build_err.txt` (31K), `build_log.txt` (47.5K), `build_f3_log.txt` (81K), `build_out.txt` (41.5K), `build_out_a3.txt` (79K), `build_out3.txt`, `build_out_new.txt`, `build_output.txt`, `build_midi_out.txt` (10+ stale build logs)
.\debates\002-codebase-cleanup-prep\context.md:50:- `T27_T29_FRONTEND_DIARY.md` (129K) — running diary, likely scratch
.\debates\002-codebase-cleanup-prep\context.md:51:- `RESUME.md`, `CODEX_HANDOFF.md`, `best practices.md` — multiple authority docs
.\debates\002-codebase-cleanup-prep\context.md:95:- Doc consolidation (RESUME.md, CODEX_HANDOFF.md, T27_T29_FRONTEND_DIARY.md, best practices.md, README.md, CLAUDE.md)
.\docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:36:- `docs/superpowers/templates/promotion-checklist.md` — checklist template derived from `best practices.md`.
.\docs\superpowers\plans\2026-04-23-infra-first-promotion-scaffold.md:1581:Source: `best practices.md` §Promotion Checklist, §Design Checklist for
.\run_build.bat:3:call build.bat >build_output.txt 2>&1
.\docs\superpowers\specs\2026-04-30-roomrom-s7-sword-design.md:98:## Why this is best practices long-term
.\docs\superpowers\specs\2026-04-30-roomrom-s6-transition-design.md:44:## Why this is best practices long-term
.\docs\superpowers\specs\2026-04-30-roomrom-s6-5-real-scroll-design.md:33:## Why this is best practices long-term
.\docs\superpowers\specs\2026-04-30-roomrom-s5-collision-design.md:35:## Why this is best practices long-term
.\docs\superpowers\specs\2026-04-30-roomrom-s4-edge-load-design.md:39:## Why this is "best practices long-term"
.\docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:780:- `best practices.md` — north star (owned C, gen/ passive, ASM only boot/IO/hot — SGDK satisfies the IO/hot half)
.\docs\superpowers\templates\promotion-checklist.md:7:Source: `best practices.md` §Promotion Checklist, §Design Checklist for
.\docs\superpowers\specs\2026-04-23-infra-first-promotion-scaffold-design.md:10:`best practices.md` doc declares as highest leverage: complete symbolic RAM
.\docs\superpowers\specs\2026-04-23-infra-first-promotion-scaffold-design.md:26:`best practices.md` §Highest-Leverage Workflow opens with:
.\docs\superpowers\specs\2026-04-23-infra-first-promotion-scaffold-design.md:79:  `best practices.md` §Promotion Checklist. Future batch notes link to it.
.\docs\superpowers\specs\2026-04-23-infra-first-promotion-scaffold-design.md:241:  to keep batch shape small, per `best practices.md` §Refactoring Safely
.\debates\002-codebase-cleanup-prep\rounds\r001_gemini.md:11:3.  **Vendor/Reference Fat:** **TRIM.** `sgdk/` (162MB) is bloated; nuke `sample/` and `doc/`. `Zelda1-Redux.zip` is redundant. `reference/Sonic 2` and other non-Zelda assets are "distraction debt"—move to `reference/external/`.
.\debates\002-codebase-cleanup-prep\rounds\r001_gemini.md:16:8.  **Docs:** **CONSOLIDATE.** `RESUME.md`, `CODEX_HANDOFF.md`, and `DIARY.md` are history, not architecture. Move to `docs/archive/`.
.\debates\002-codebase-cleanup-prep\rounds\r001_gemini.md:30:mkdir -p docs/archive && mv *_DIARY.md CODEX_HANDOFF.md RESUME.md docs/archive/
.\debates\002-codebase-cleanup-prep\rounds\r001_gemini.md:43:The codebase is functionally viable but operationally "loud." The noise-to-signal ratio is too high for complex state-machine migration. We can carry Phase 1.5, but Phase 17 will fail when a developer (or agent) mistakes a `build_out_a3.txt` for current reality or hits a path-parsing bug. **Clean the room before starting the surgery.**
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:36:8. Doc consolidation (RESUME.md, CODEX_HANDOFF.md, T27_T29_FRONTEND_DIARY.md, best practices.md).
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:66:RoomRom/build_err.txt
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:131:- `FIX THIS.avi` (57M) â€” bug-report video
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:132:- `SCROLL TIME.avi` (47M) â€” bug-report video
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:133:- `Zelda1-Redux.zip` (1.7M) â€” already extracted to `Zelda1-Redux/`
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:134:- `VisualStudioSetup.exe` (4.2M)
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:135:- `rustup-init.exe` (12.2M)
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:137:- `a.out` (280B)
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:142:- `bout.txt` (72K)
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:143:- `build_a3_fix.txt` x3, `build_err.txt` (31K), `build_log.txt` (47.5K), `build_f3_log.txt` (81K), `build_out.txt` (41.5K), `build_out_a3.txt` (79K), `build_out3.txt`, `build_out_new.txt`, `build_output.txt`, `build_midi_out.txt` (10+ stale build logs)
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:144:- `T27_T29_FRONTEND_DIARY.md` (129K) â€” running diary, likely scratch
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:145:- `RESUME.md`, `CODEX_HANDOFF.md`, `best practices.md` â€” multiple authority docs
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:189:- Doc consolidation (RESUME.md, CODEX_HANDOFF.md, T27_T29_FRONTEND_DIARY.md, best practices.md, README.md, CLAUDE.md)
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2343:"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command '$files=@('"'FIX THIS.avi','SCROLL TIME.avi','Zelda1-Redux.zip','VisualStudioSetup.exe','rustup-init.exe','src.zip','a.out','Zelda - Ocarina of Time - Great Fairy''s fountain.mid','Zelda Redux.nes','Legend of Zelda, The (USA).nes','analyze_funcs.txt','bout.txt','build_a3_fix.txt','build_err.txt','build_log.txt','build_f3_log.txt','build_out.txt','build_out_a3.txt','build_out3.txt','build_out_new.txt','build_output.txt','build_midi_out.txt','T27_T29_FRONTEND_DIARY.md','RESUME.md','CODEX_HANDOFF.md','best practices.md'); foreach("'$f in $files){ if(Test-Path -LiteralPath $f){ $tracked=git ls-files -- $f; $status=if($tracked){'"'TRACKED'}else{'UNTRACKED'}; "'$len=(Get-Item -LiteralPath $f).Length; "$status`t$len`t$f" } else { "MISSING`t`t$f" } }' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2352:a.out                                                     280
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2354:best practices.md                                       10185
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2355:bout.txt                                                73755
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2357:build_a3_fix.txt                                          145
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2358:build_a3_fix2.txt                                         145
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2359:build_a3_fix3.txt                                         145
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2360:build_err.txt                                           31927
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2362:build_f3_log.txt                                        83353
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2364:build_log.txt                                           48633
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2365:build_midi_out.txt                                       3778
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2367:build_out_a3.txt                                        80889
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2368:build_out_new.txt                                         302
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2369:build_out3.txt                                            100
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2370:build_output.txt                                          100
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2375:CODEX_HANDOFF.md                                         5556
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2378:FIX THIS.avi                                         59852288
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2384:RESUME.md                                                4480
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2386:rustup-init.exe                                      12814336
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2388:SCROLL TIME.avi                                      49877504
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2391:T27_T29_FRONTEND_DIARY.md                              132523
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2393:VisualStudioSetup.exe                                 4454944
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2396:Zelda1-Redux.zip                                      1829953
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2424:UNTRACKED	59852288	FIX THIS.avi
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2425:UNTRACKED	49877504	SCROLL TIME.avi
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2426:UNTRACKED	1829953	Zelda1-Redux.zip
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2427:TRACKED	4454944	VisualStudioSetup.exe
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2428:TRACKED	12814336	rustup-init.exe
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2430:TRACKED	280	a.out
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2435:TRACKED	73755	bout.txt
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2436:TRACKED	145	build_a3_fix.txt
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2437:TRACKED	31927	build_err.txt
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2438:TRACKED	48633	build_log.txt
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2439:TRACKED	83353	build_f3_log.txt
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2441:TRACKED	80889	build_out_a3.txt
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2442:TRACKED	100	build_out3.txt
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2443:TRACKED	302	build_out_new.txt
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2444:TRACKED	100	build_output.txt
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2445:TRACKED	3778	build_midi_out.txt
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2446:TRACKED	132523	T27_T29_FRONTEND_DIARY.md
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2447:TRACKED	4480	RESUME.md
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2448:TRACKED	5556	CODEX_HANDOFF.md
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:2449:TRACKED	10185	best practices.md
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:3723:build_err.txt                 
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:3725:build_log.txt                 
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:3972:?? "FIX THIS.avi"
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:3974:?? "SCROLL TIME.avi"
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:3976:?? Zelda1-Redux.zip
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:4100:?? "FIX THIS.avi"
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:4102:?? "SCROLL TIME.avi"
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:4104:?? Zelda1-Redux.zip
.\debates\002-codebase-cleanup-prep\rounds\r001_codex.md:4202:"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command "rg -n \"VisualStudioSetup|rustup-init|a\\.out|bout\\.txt|build_a3_fix|build_err\\.txt|build_log\\.txt|build_f3_log|build_out_a3|build_out3|build_out_new|build_output\\.txt|build_midi_out|T27_T29_FRONTEND_DIARY|RESUME\\.md|CODEX_HANDOFF|best practices|FIX THIS|SCROLL TIME|Zelda1-Redux.zip\" . --glob '"'!builds/**'"' --glob '"'!Zelda1-Redux/**'"' --glob '"'!sgdk/**'"' --glob '"'!RoomRom/out/**'"'" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
.\tools\run_build_temp.bat:3:call build.bat > "builds\build_log.txt" 2>&1

2026-05-02T17:22:35.514002Z ERROR codex_core::tools::router: error=Exit code: 1
Wall time: 2.6 seconds
Output:
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.claude\worktrees\native-file-select\tools\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.claude\worktrees\native-file-select\tools\intro_demo\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\RoomRom\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\gen_wrappers\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\intro_demo\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\probes\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\tests\__pycache__

 exited 1 in 2563ms:
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.claude\worktrees\native-file-select\tools\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.claude\worktrees\native-file-select\tools\intro_demo\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\RoomRom\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\gen_wrappers\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\intro_demo\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\probes\__pycache__
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\tests\__pycache__

exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'git ls-files midi | Select-Object -First 80; git ls-files midi | Measure-Object' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command "git ls-files Zelda1-Redux | Measure-Object; git ls-files reference/Sonic\\ 2 reference/sega2f_files 'reference/Disassembly by Trax' 'reference/Disassembly by camthesaxman' | Measure-Object" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'rg -n "midi|mid2vgm|PSG mode|Great Fairy|music_great_fairy" README.md docs tools src RoomRom build.bat' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
 succeeded in 874ms:


Count    : 0
Average  : 
Sum      : 
Maximum  : 
Minimum  : 
Property : 




 succeeded in 850ms:
docs\audit\s1_close.md:42:Bonus: `cbcdc1b1 audio: native intro path requests title song ($80) at boot` — single `move.b #$80,($0600,A4)` in `genesis_shell.asm` after `vblank_mode=0` init. Title song now plays end-to-end. Memory `project_midi_substrate_works.md` recorded the fix; `project_midi_fs_integration.md` "substrate rotting" diagnosis turned out to be wrong about the rot.
docs\audit\file_classification.md:105:- `src/gen/music_great_fairy.bin`
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:722:- `*.bak`, `*- Copy*`, top-level `Zelda1-Redux/`, stray zips/midis/build_out logs
docs\superpowers\specs\2026-04-27-native-genesis-rewrite-design.md:738:- `project_midi_fs_integration.md` — resolved (FS runs on SGDK + adapter; audio integrated cleanly)
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:1:# MIDI Demo ROM — Great Fairy's Fountain
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:9:`Zelda - Ocarina of Time - Great Fairy's fountain.mid` looping forever
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:24:tools/midi_demo/compile_midi.py
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:30:tools/midi_demo/midi_data.bin  (binary event blob + note table)
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:33:midi_player.asm
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:47:             ym_init_simple, midi_init, display ON, vblank loop
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:52:- 6 FM voices, all loaded with EHZ Voice $00 (bell pad — fits Great Fairy
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:87:tools/midi_demo/
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:88:    compile_midi.py     # SMF -> midi_data.bin
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:93:    midi_player.asm     # event-blob driven YM2612 writer
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:94:    midi_demo.ld        # link script (rom 0x000000-0x07FFFF, ram 0xFFC000+)
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:96:docs/superpowers/specs/2026-04-27-midi-demo-rom-design.md
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:99:Source MIDI stays at repo root: `Zelda - Ocarina of Time - Great Fairy's fountain.mid`
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:101:Output ROM: `tools/midi_demo/out/midi_demo.md`
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:105:1. `tools/midi_demo/build.bat` → produces `out/midi_demo.md`
docs\superpowers\specs\2026-04-27-midi-demo-rom-design.md:120:  for atmospheric Great Fairy theme. Note-off forces RR via $28 key-off.
src\frontend\intro\intro_handoff.c:40:     * tools/midi_to_zelda_song.py). Jingle is single-phrase: sq1 terminates with
tools\midi_to_zelda_song.py:3:midi_to_zelda_song.py
tools\midi_to_zelda_song.py:71:def freq_to_midi(freq: float) -> float:
tools\midi_to_zelda_song.py:79:    """Return list of (nes_note_byte, period, freq, midi). nes_note_byte is even, 2..0x70."""
tools\midi_to_zelda_song.py:86:        midi = freq_to_midi(freq)
tools\midi_to_zelda_song.py:87:        out.append((idx * 2, period, freq, midi))
tools\midi_to_zelda_song.py:91:def map_midi_to_nes(midi_note: int, table) -> int:
tools\midi_to_zelda_song.py:97:    for nes_byte, period, freq, midi in table:
tools\midi_to_zelda_song.py:100:        err = abs(midi - midi_note)
tools\midi_to_zelda_song.py:174:def parse_midi(path: Path):
tools\midi_to_zelda_song.py:221:def midi_channel_to_events(midi, ch, m_len_base):
tools\midi_to_zelda_song.py:224:    notes = sorted(midi['channels'][ch])
tools\midi_to_zelda_song.py:227:    ppqn = midi['ppqn']
tools\midi_to_zelda_song.py:229:    us_per_tick = midi['tempo_us'] / ppqn
tools\midi_to_zelda_song.py:233:    for i, (start, _dur, midi_note) in enumerate(notes):
tools\midi_to_zelda_song.py:238:        nes_byte = map_midi_to_nes(midi_note, table)
tools\midi_to_zelda_song.py:279:        nb = map_midi_to_nes(m, table)
tools\midi_to_zelda_song.py:282:                _, period, freq, midi = entry
tools\midi_to_zelda_song.py:283:                print(f"  MIDI {m:3d} -> NES ${nb:02X} (period ${period:04X}, {freq:.1f} Hz, ~MIDI {midi:.2f})")
tools\midi_to_zelda_song.py:291:def show_conversion(midi_path, m_len_base):
tools\midi_to_zelda_song.py:292:    midi = parse_midi(midi_path)
tools\midi_to_zelda_song.py:293:    print(f"MIDI: ppqn={midi['ppqn']} tempo_us={midi['tempo_us']} channels={sorted(midi['channels'])}")
tools\midi_to_zelda_song.py:295:        if ch not in midi['channels']:
tools\midi_to_zelda_song.py:297:        evs = midi_channel_to_events(midi, ch, m_len_base)
tools\midi_to_zelda_song.py:321:    nes_bytes = [map_midi_to_nes(n, table) for n in notes]
tools\midi_to_zelda_song.py:332:def patch_blob(midi_path: Path, dry_run=False):
tools\midi_to_zelda_song.py:336:    midi_path is unused (LA reduction is hand-curated to fit), kept for CLI
tools\music_test\probe_fs_midi_lifecycle.lua:1:-- probe_fs_midi_lifecycle.lua
tools\music_test\probe_fs_midi_lifecycle.lua:6:local FLAG       = 0xFFE120  -- s_music_midi_active
tools\music_test\probe_fs_midi_lifecycle.lua:11:local out_path = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/music_test/out/fs_midi_lifecycle.txt"
tools\music_test\probe_fs_midi_lifecycle.lua:17:f:write("phase, frame, gamemode, midi_active, ms_play_ptr, ms_time_next\n")
tools\music_test\probe_fs_full_dump.lua:6:--   * Memory state: gamemode, m_song, m_song_req, midi flag, MIDI_STATE block
tools\music_test\probe_fs_full_dump.lua:13:local FLAG       = 0xFFE120  -- s_music_midi_active
tools\music_test\probe_fs_full_dump.lua:45:    log(string.format("  midi_active($FFE120)= 0x%02X", memory.readbyte(FLAG,    "M68K BUS")))
tools\midi_demo\build.bat:7:set "DEMO_DIR=%ROOT%\tools\midi_demo"
tools\midi_demo\build.bat:9:set "MIDI_SRC=%ROOT%\Zelda - Ocarina of Time - Great Fairy's fountain.mid"
tools\midi_demo\build.bat:43:echo [midi_demo] Compiling MIDI -> event blob
tools\midi_demo\build.bat:44:"%PYTHON%" "%DEMO_DIR%\compile_midi.py" "%MIDI_SRC%" "%OUT_DIR%\midi_data.bin"
tools\midi_demo\build.bat:47:echo [midi_demo] Compiling main.c
tools\midi_demo\build.bat:51:echo [midi_demo] Compiling link_sprite.c
tools\midi_demo\build.bat:55:echo [midi_demo] Compiling link_palette.c
tools\midi_demo\build.bat:59:echo [midi_demo] Assembling boot.asm
tools\midi_demo\build.bat:63:echo [midi_demo] Assembling midi_player.asm
tools\midi_demo\build.bat:65:"%VASM%" -Felf -m68000 -L "%OUT_DIR%\midi_player.lst" -o "%OUT_DIR%\midi_player.o" "%DEMO_DIR%\midi_player.asm"
tools\midi_demo\build.bat:69:echo [midi_demo] Linking
tools\midi_demo\build.bat:70:"%M68K_LD%" -T "%DEMO_DIR%\midi_demo.ld" -o "%OUT_DIR%\midi_demo.elf" ^
tools\midi_demo\build.bat:75:    "%OUT_DIR%\midi_player.o"
tools\midi_demo\build.bat:78:echo [midi_demo] objcopy -^> raw bin
tools\midi_demo\build.bat:79:"%M68K_OBJCOPY%" -O binary "%OUT_DIR%\midi_demo.elf" "%OUT_DIR%\midi_demo.bin"
tools\midi_demo\build.bat:82:echo [midi_demo] fix checksum + pad
tools\midi_demo\build.bat:83:"%PYTHON%" "%ROOT%\tools\fix_checksum.py" "%OUT_DIR%\midi_demo.bin" "%OUT_DIR%\midi_demo.md"
tools\midi_demo\build.bat:86:echo [midi_demo] DONE: %OUT_DIR%\midi_demo.md
tools\midi_demo\compile_midi.py:2:"""compile_midi.py - Compile a Standard MIDI File into a compact event blob
tools\midi_demo\compile_midi.py:3:for the midi_demo ROM.
tools\midi_demo\compile_midi.py:24:Usage: compile_midi.py input.mid output.bin
tools\midi_demo\compile_midi.py:39:def midi_to_ym(note: int) -> tuple[int, int]:
tools\midi_demo\compile_midi.py:137:def compile_song(midi_path: Path) -> bytes:
tools\midi_demo\compile_midi.py:138:    div, tracks = parse_smf(midi_path)
tools\midi_demo\compile_midi.py:154:    # Each FM voice holds the (midi_ch, note) that owns it plus a serial
tools\midi_demo\compile_midi.py:166:    def voice_alloc(midi_ch: int, note: int) -> int:
tools\midi_demo\compile_midi.py:172:                voice_owner[i] = (midi_ch, note)
tools\midi_demo\compile_midi.py:176:        voice_owner[i] = (midi_ch, note)
tools\midi_demo\compile_midi.py:180:    def voice_release(midi_ch: int, note: int) -> int | None:
tools\midi_demo\compile_midi.py:182:            if voice_owner[i] == (midi_ch, note):
tools\midi_demo\compile_midi.py:217:                block, fnum = midi_to_ym(shifted)
tools\midi_demo\compile_midi.py:223:            block, fnum = midi_to_ym(played)
tools\midi_demo\compile_midi.py:234:            block, fnum = midi_to_ym(played)
tools\midi_demo\compile_midi.py:264:        print('Usage: compile_midi.py input.mid output.bin', file=sys.stderr)
tools\midi_demo\compile_midi.py:270:    print(f'compile_midi: wrote {len(blob)} bytes -> {dst}')
tools\midi_demo\midi_demo.ld:1:/* midi_demo.ld — minimal Genesis link script for the standalone MIDI demo. */
tools\midi_demo\boot.asm:2:; midi_demo/boot.asm — standalone Genesis ROM boot.
tools\midi_demo\main.c:1:/* main.c — midi_demo entry: upload Link sprite, start music, idle in vblank loop. */
tools\midi_demo\main.c:11:extern void midi_init(void);
tools\midi_demo\main.c:12:extern void midi_tick(void);
tools\midi_demo\main.c:84:    midi_init();
tools\midi_demo\main.c:90:        midi_tick();
tools\midi_demo\run_probe.bat:6:set "ROM=%ROOT%\tools\midi_demo\out\midi_demo.md"
tools\midi_demo\run_probe.bat:7:set "LUA=%ROOT%\tools\midi_demo\probe.lua"
tools\midi_demo\run_probe.bat:8:set "MIDI_DEMO_OUT=%ROOT%\tools\midi_demo\out"
tools\midi_demo\midi_player.asm:2:; midi_player.asm — Compact event-driven YM2612 MIDI player.
tools\midi_demo\midi_player.asm:6:;       midi_init      — point play state at compiled blob, prime time_to_next
tools\midi_demo\midi_player.asm:7:;       midi_tick      — call once per VBlank; dispatches due events
tools\midi_demo\midi_player.asm:9:; Compiled blob is incbin'd at label `midi_blob`.  Layout (big-endian):
tools\midi_demo\midi_player.asm:190:; midi_init — initialize player state from the compiled blob.
tools\midi_demo\midi_player.asm:192:    xdef    midi_init
tools\midi_demo\midi_player.asm:193:midi_init:
tools\midi_demo\midi_player.asm:195:    lea     midi_blob(PC),A0
tools\midi_demo\midi_player.asm:236:; midi_tick — called once per VBlank.
tools\midi_demo\midi_player.asm:238:    xdef    midi_tick
tools\midi_demo\midi_player.asm:239:midi_tick:
tools\midi_demo\midi_player.asm:452:; midi_blob — compiled MIDI event blob (incbin'd from out/midi_data.bin)
tools\midi_demo\midi_player.asm:454:    xdef    midi_blob
tools\midi_demo\midi_player.asm:456:midi_blob:
tools\midi_demo\midi_player.asm:457:    incbin  "out/midi_data.bin"
tools\midi_demo\run.bat:6:set "ROM=%ROOT%\tools\midi_demo\out\midi_demo.md"
tools\midi_demo\probe.lua:1:-- midi_demo/probe.lua — boot ROM, screenshot, dump CRAM/VRAM/SAT.
tools\music_test\out\full_dump.txt:3:  midi_active($FFE120)= 0x00
tools\music_test\out\full_dump.txt:41:  midi_active($FFE120)= 0x01
tools\music_test\out\full_dump.txt:67:  midi_active($FFE120)= 0x01
tools\midi_demo\out\boot.lst:7:Source: "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\midi_demo\boot.asm"
tools\midi_demo\out\boot.lst:9:                            	     2: ; midi_demo/boot.asm — standalone Genesis ROM boot.
tools\midi_demo\out\midi_player.lst:6:Source: "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\midi_demo\midi_player.asm"
tools\midi_demo\out\midi_player.lst:8:                            	     2: ; midi_player.asm — Compact event-driven YM2612 MIDI player.
tools\midi_demo\out\midi_player.lst:12:                            	     6: ;       midi_init      — point play state at compiled blob, prime time_to_next
tools\midi_demo\out\midi_player.lst:13:                            	     7: ;       midi_tick      — call once per VBlank; dispatches due events
tools\midi_demo\out\midi_player.lst:15:                            	     9: ; Compiled blob is incbin'd at label `midi_blob`.  Layout (big-endian):
tools\midi_demo\out\midi_player.lst:196:                            	   190: ; midi_init — initialize player state from the compiled blob.
tools\midi_demo\out\midi_player.lst:198:                            	   192:     xdef    midi_init
tools\midi_demo\out\midi_player.lst:199:                            	   193: midi_init:
tools\midi_demo\out\midi_player.lst:201:00:00000144 41FA009C        	   195:     lea     midi_blob(PC),A0
tools\midi_demo\out\midi_player.lst:242:                            	   236: ; midi_tick — called once per VBlank.
tools\midi_demo\out\midi_player.lst:244:                            	   238:     xdef    midi_tick
tools\midi_demo\out\midi_player.lst:245:                            	   239: midi_tick:
tools\midi_demo\out\midi_player.lst:566:                            	   452: ; midi_blob — compiled MIDI event blob (incbin'd from out/midi_data.bin)
tools\midi_demo\out\midi_player.lst:568:                            	   454:     xdef    midi_blob
tools\midi_demo\out\midi_player.lst:570:                            	   456: midi_blob:
tools\midi_demo\out\midi_player.lst:571:01:0000009C 4D494449000004EF	   457:     incbin  "out/midi_data.bin"
tools\midi_demo\out\midi_player.lst:1545:midi_blob                       01:0000009C EXP
tools\midi_demo\out\midi_player.lst:1546:midi_init                       00:00000140 EXP
tools\midi_demo\out\midi_player.lst:1547:midi_tick                       00:000001A2 EXP
tools\midi_demo\out\midi_player.lst:1563:0000009C midi_blob
tools\midi_demo\out\midi_player.lst:1564:00000140 midi_init
tools\midi_demo\out\midi_player.lst:1565:000001A2 midi_tick
tools\midi_demo\out\music_player.lst:28:                            	    23: ; The standalone midi_demo build links music_player.o alone — no conflicts either.
tools\midi_demo\out\music_player.lst:581:                            	   468: ; Path "gen/music_great_fairy.bin" is relative to src/ because vasm is
tools\midi_demo\out\music_player.lst:583:                            	   470: ; tools/compile_midi.py during the main build.
tools\midi_demo\out\music_player.lst:588:00:00000342 4D494449000004EF	   475:     incbin  "gen/music_great_fairy.bin"

 succeeded in 858ms:


Count    : 0
Average  : 
Sum      : 
Maximum  : 
Minimum  : 
Property : 

Count    : 397
Average  : 
Sum      : 
Maximum  : 
Minimum  : 
Property : 




exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command "git ls-files .pre-merge-backup .codex_tmp '**/__pycache__' | ForEach-Object { "'$_ }; git ls-files .pre-merge-backup .codex_tmp '"'**/__pycache__' | Measure-Object" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command "git ls-files 'tools/*.py' | Measure-Object; git ls-files 'tools/*.lua' | Measure-Object; git ls-files 'tools/probes/*' | Select-Object -First 40; git ls-files 'tools/tests/*' | Select-Object -First 40" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command 'Get-ChildItem -LiteralPath .pre-merge-backup -Recurse -Force -File -ErrorAction SilentlyContinue | Select-Object FullName,Length; Get-ChildItem -LiteralPath .codex_tmp -Recurse -Force -File -ErrorAction SilentlyContinue | Select-Object FullName,Length' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
2026-05-02T17:23:18.645824Z ERROR codex_core::tools::router: error=Exit code: 1
Wall time: 0.8 seconds
Output:

FullName                                                                                                               
--------                                                                                                               
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\builds\reports\bizhawk_t30_room_load_probe.txt      
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelBlockOW.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelBlockUW1Q1.dat         
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelBlockUW1Q2.dat         
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelBlockUW2Q1.dat         
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelBlockUW2Q2.dat         
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoOW.dat             
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW1.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW2.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW3.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW4.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW5.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW6.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW7.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW8.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW9.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\ObjLists.dat                
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockOWBG.dat        
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockOWSP.dat        
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWBG.dat        
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSP.dat        
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSP127.dat     
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSP358.dat     
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSP469.dat     
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSPBoss1257.dat
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSPBoss3468.dat
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSPBoss9.dat   
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PersonText.dat              
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\RoomLayoutsOW.dat           
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\RoomLayoutsUW.dat           
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\level_info.inc                             
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\rooms_overworld.inc                        
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\rooms_underworld1.inc                      
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\rooms_underworld2.inc                      
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\room_columns.inc                           
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\room_common.inc                            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\room_layouts.inc                           
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\room_patches.inc                           
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\tools\bizhawk_t30_room_load_probe.lua               
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\tools\probe_root.lua                                



 exited 1 in 754ms:

FullName                                                                                                               
--------                                                                                                               
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\builds\reports\bizhawk_t30_room_load_probe.txt      
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelBlockOW.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelBlockUW1Q1.dat         
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelBlockUW1Q2.dat         
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelBlockUW2Q1.dat         
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelBlockUW2Q2.dat         
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoOW.dat             
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW1.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW2.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW3.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW4.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW5.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW6.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW7.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW8.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\LevelInfoUW9.dat            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\ObjLists.dat                
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockOWBG.dat        
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockOWSP.dat        
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWBG.dat        
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSP.dat        
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSP127.dat     
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSP358.dat     
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSP469.dat     
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSPBoss1257.dat
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSPBoss3468.dat
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PatternBlockUWSPBoss9.dat   
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\PersonText.dat              
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\RoomLayoutsOW.dat           
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\reference\aldonunez\dat\RoomLayoutsUW.dat           
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\level_info.inc                             
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\rooms_overworld.inc                        
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\rooms_underworld1.inc                      
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\rooms_underworld2.inc                      
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\room_columns.inc                           
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\room_common.inc                            
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\room_layouts.inc                           
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\src\data\room_patches.inc                           
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\tools\bizhawk_t30_room_load_probe.lua               
C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.pre-merge-backup\tools\probe_root.lua                                



 succeeded in 836ms:
.pre-merge-backup/builds/reports/bizhawk_t30_room_load_probe.txt
.pre-merge-backup/reference/aldonunez/dat/LevelBlockOW.dat
.pre-merge-backup/reference/aldonunez/dat/LevelBlockUW1Q1.dat
.pre-merge-backup/reference/aldonunez/dat/LevelBlockUW1Q2.dat
.pre-merge-backup/reference/aldonunez/dat/LevelBlockUW2Q1.dat
.pre-merge-backup/reference/aldonunez/dat/LevelBlockUW2Q2.dat
.pre-merge-backup/reference/aldonunez/dat/LevelInfoOW.dat
.pre-merge-backup/reference/aldonunez/dat/LevelInfoUW1.dat
.pre-merge-backup/reference/aldonunez/dat/LevelInfoUW2.dat
.pre-merge-backup/reference/aldonunez/dat/LevelInfoUW3.dat
.pre-merge-backup/reference/aldonunez/dat/LevelInfoUW4.dat
.pre-merge-backup/reference/aldonunez/dat/LevelInfoUW5.dat
.pre-merge-backup/reference/aldonunez/dat/LevelInfoUW6.dat
.pre-merge-backup/reference/aldonunez/dat/LevelInfoUW7.dat
.pre-merge-backup/reference/aldonunez/dat/LevelInfoUW8.dat
.pre-merge-backup/reference/aldonunez/dat/LevelInfoUW9.dat
.pre-merge-backup/reference/aldonunez/dat/ObjLists.dat
.pre-merge-backup/reference/aldonunez/dat/PatternBlockOWBG.dat
.pre-merge-backup/reference/aldonunez/dat/PatternBlockOWSP.dat
.pre-merge-backup/reference/aldonunez/dat/PatternBlockUWBG.dat
.pre-merge-backup/reference/aldonunez/dat/PatternBlockUWSP.dat
.pre-merge-backup/reference/aldonunez/dat/PatternBlockUWSP127.dat
.pre-merge-backup/reference/aldonunez/dat/PatternBlockUWSP358.dat
.pre-merge-backup/reference/aldonunez/dat/PatternBlockUWSP469.dat
.pre-merge-backup/reference/aldonunez/dat/PatternBlockUWSPBoss1257.dat
.pre-merge-backup/reference/aldonunez/dat/PatternBlockUWSPBoss3468.dat
.pre-merge-backup/reference/aldonunez/dat/PatternBlockUWSPBoss9.dat
.pre-merge-backup/reference/aldonunez/dat/PersonText.dat
.pre-merge-backup/reference/aldonunez/dat/RoomLayoutsOW.dat
.pre-merge-backup/reference/aldonunez/dat/RoomLayoutsUW.dat
.pre-merge-backup/src/data/level_info.inc
.pre-merge-backup/src/data/room_columns.inc
.pre-merge-backup/src/data/room_common.inc
.pre-merge-backup/src/data/room_layouts.inc
.pre-merge-backup/src/data/room_patches.inc
.pre-merge-backup/src/data/rooms_overworld.inc
.pre-merge-backup/src/data/rooms_underworld1.inc
.pre-merge-backup/src/data/rooms_underworld2.inc
.pre-merge-backup/tools/bizhawk_t30_room_load_probe.lua
.pre-merge-backup/tools/probe_root.lua


Count    : 40
Average  : 
Sum      : 
Maximum  : 
Minimum  : 
Property : 




 succeeded in 871ms:


Count    : 166
Average  : 
Sum      : 
Maximum  : 
Minimum  : 
Property : 

Count    : 287
Average  : 
Sum      : 
Maximum  : 
Minimum  : 
Property : 

tools/probes/__init__.py
tools/probes/_common.py
tools/probes/abi_probe.build.bat
tools/probes/abi_probe.c
tools/probes/baselines/fs_cursor_wrap.bin
tools/probes/baselines/fs_file_delete_cancel.bin
tools/probes/baselines/fs_fresh_cursor.bin
tools/probes/baselines/fs_name_entry_backspace.bin
tools/probes/baselines/fs_name_entry_create.bin
tools/probes/baselines/intro_story_p1.bin
tools/probes/baselines/title_idle.bin
tools/probes/baselines/title_to_fs.bin
tools/probes/bizhawk_capture_gen.lua
tools/probes/bizhawk_capture_nes.lua
tools/probes/capture_canonical.lua
tools/probes/check_data_manifest.py
tools/probes/classify_files.py
tools/probes/diff_capture.py
tools/probes/diff_normalized.py
tools/probes/gen_room_reference.py
tools/probes/lint_legacy_symbols.py
tools/probes/locate_reference_rom.py
tools/probes/movies/.gitkeep
tools/probes/nes_ow_room_capture.lua
tools/probes/normalize_gen.py
tools/probes/normalize_nes.py
tools/probes/probe_room_render.py
tools/probes/run_sram_test.lua
tools/probes/scan_build_order.py
tools/probes/scan_frontend_deps.py
tools/probes/scan_legacy_callers.py
tools/probes/scan_redux_touchpoints.py
tools/probes/snapshot_repo_tree.py
tools/probes/sram_layout_test.c
tools/probes/test_classify_files.py
tools/probes/test_lint_legacy_symbols.py
tools/probes/test_locate_reference_rom.py
tools/tests/test_extract_intro_assets.py



exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command '$files=@('"'build_a3_fix2.txt','build_a3_fix3.txt','build_f3_out.txt','build_run.tmp','capture.log','capture2.log','event','nes_reference.png','probe_heart_flash.lua','raw','scan_drain2.py','t.out','test_copy.tmp','build_f3.bat','run_build.bat','FINAL TRY.zip'); foreach("'$f in $files){ if(Test-Path -LiteralPath $f){ $tracked=git ls-files -- $f; $status=if($tracked){'"'TRACKED'}else{'UNTRACKED'}; "'$len=(Get-Item -LiteralPath $f).Length; "$status`t$len`t$f" } else { "MISSING`t`t$f" } }' in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
 succeeded in 1353ms:
TRACKED	145	build_a3_fix2.txt
TRACKED	145	build_a3_fix3.txt
TRACKED	100	build_f3_out.txt
TRACKED	100	build_run.tmp
TRACKED	0	capture.log
TRACKED	0	capture2.log
TRACKED	35	event
TRACKED	158870	nes_reference.png
TRACKED	2500	probe_heart_flash.lua
TRACKED	22	raw
TRACKED	2053	scan_drain2.py
TRACKED	2603	t.out
TRACKED	145	test_copy.tmp
TRACKED	308	build_f3.bat
TRACKED	137	run_build.bat
MISSING		FINAL TRY.zip

exec
"C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -Command "git ls-files -- 'FINAL TRY.zip'" in C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY
 succeeded in 625ms:
FINAL TRY.zip

codex
1. Root leftovers verdict:
DELETE: `FIX THIS.avi`, `SCROLL TIME.avi`, `Zelda1-Redux.zip`, `src.zip`, `VisualStudioSetup.exe`, `rustup-init.exe`, `a.out`, `analyze_funcs.txt`, `bout.txt`, `build_a3_fix.txt`, `build_a3_fix2.txt`, `build_a3_fix3.txt`, `build_err.txt`, `build_f3_log.txt`, `build_f3_out.txt`, `build_log.txt`, `build_midi_out.txt`, `build_out.txt`, `build_out_a3.txt`, `build_out3.txt`, `build_out_new.txt`, `build_output.txt`, `build_run.tmp`, `capture.log`, `capture2.log`, `event`, `raw`, `t.out`, `test_copy.tmp`, `FINAL TRY.zip`, `build_f3.bat`, `run_build.bat`.
MOVE local-only: `Legend of Zelda, The (USA).nes`, `Zelda Redux.nes` -> `local/roms/`.
DELETE or move local-only: `Zelda - Ocarina of Time - Great Fairy's fountain.mid`.
MOVE: `probe_heart_flash.lua` -> `tools/probes/`; `scan_drain2.py` -> `tools/debug/`; `nes_reference.png` -> `builds/reports/legacy/` if still useful.
MOVE docs: `T27_T29_FRONTEND_DIARY.md`, `RESUME.md`, `CODEX_HANDOFF.md`; rename `best practices.md` -> `docs/engineering/best_practices.md`.

2. Generated data fat verdict:
KEEP only until `REQUIRE_GENERATED_ASSETS=1` is green. Then drop checked-in generated blobs under `data/`, `src/data/`, `RoomRom/data/`, and `src/gen/music_great_fairy.bin`. KEEP `src/gen/z_01.c`..`z_07.c` for now: transpile adapters still referenced by plans/builds.

3. Vendor fat verdict:
KEEP `sgdk/` as pinned submodule; do not commit-trim internals. DELETE tracked non-Zelda refs: `reference/Sonic 2/`, `reference/SONIC2_W.68K`, `reference/Sonic The Hedgehog 2 (World) (Rev B).md`, `reference/sega2f_files/`. MOVE secondary Zelda refs to `reference/secondary/` or delete after citation sweep: `reference/Disassembly by Trax/`, `reference/Disassembly by camthesaxman/`. DELETE/MOVE out untracked `Zelda1-Redux/`; future code should use `REDUX_ROOT` or builder-supplied input. DELETE untracked `midi/` unless demo work is deliberately archived.

4. Backup/temp verdict:
DELETE tracked `.pre-merge-backup/`. DELETE ignored `.codex_tmp/`, all `__pycache__/`, `tools/out/`, demo `out/` dirs.

5. Tools clutter verdict:
Canonical tree: `tools/builder/`, `tools/extractors/`, `tools/probes/lua/`, `tools/probes/py/`, `tools/state/`, `tools/verifiers/`, `tools/demos/{intro,file_select,midi,music}/`, `tools/debug/`, `tools/archive/`. Root `tools/*.lua` and `tools/*.py` should go to zero except orchestration entrypoints like `run_regression_matrix.py`.

6. builds/ verdict:
4.7 GB and 47,574 tracked files is unacceptable. Make `builds/` local output. Track only `builds/BUILDS.md` and curated text/json reports if truly needed.

7. Owned C dead code:
KEEP `src/zelda_translated/` now; `src/genesis_shell.asm` includes it. KEEP `src/gen/z_*.c` now. DELETE only after Phase 12/16.5 caller audit. Do not touch `RoomRom/src/` from this worktree.

8. Doc consolidation:
Authority should be `README.md`, `CLAUDE.md`, master plan, `docs/audit/*`. Archive handoffs/diaries. Move best-practices content under `docs/engineering/` and update citations.

9. Top 10 actions ranked:
```powershell
git rm -- 'VisualStudioSetup.exe' 'rustup-init.exe' 'a.out' 'bout.txt' 'build_a3_fix.txt' 'build_a3_fix2.txt' 'build_a3_fix3.txt' 'build_err.txt' 'build_f3_log.txt' 'build_f3_out.txt' 'build_log.txt' 'build_midi_out.txt' 'build_out_a3.txt' 'build_out3.txt' 'build_out_new.txt' 'build_output.txt' 'build_run.tmp' 'capture.log' 'capture2.log' 'event' 'raw' 't.out' 'test_copy.tmp' 'FINAL TRY.zip' 'build_f3.bat' 'run_build.bat'
Remove-Item -LiteralPath 'FIX THIS.avi','SCROLL TIME.avi','Zelda1-Redux.zip','src.zip','analyze_funcs.txt','build_out.txt' -Force
New-Item -ItemType Directory -Force 'local\roms'; Move-Item -LiteralPath 'Legend of Zelda, The (USA).nes','Zelda Redux.nes' -Destination 'local\roms'
git rm -r --cached builds
git rm -r -- '.pre-merge-backup'
Remove-Item -Recurse -Force '.codex_tmp','__pycache__','tools\__pycache__','RoomRom\__pycache__','tools\out'
git rm -r -- 'reference/Sonic 2' 'reference/sega2f_files' 'reference/SONIC2_W.68K' 'reference/Sonic The Hedgehog 2 (World) (Rev B).md'
git mv 'T27_T29_FRONTEND_DIARY.md' 'docs/archive/T27_T29_FRONTEND_DIARY.md'; git mv 'RESUME.md' 'docs/archive/RESUME.md'; git mv 'CODEX_HANDOFF.md' 'docs/archive/CODEX_HANDOFF.md'
git mv 'best practices.md' 'docs/engineering/best_practices.md'
git mv 'probe_heart_flash.lua' 'tools/probes/probe_heart_flash.lua'; git mv 'scan_drain2.py' 'tools/debug/scan_drain2.py'
```

10. Final stance:
RED as-is for Phase 1.5 -> 17. The code can limp into Phase 1.5, but Phase 17 legal builder/public package will fail without this cleanup.
tokens used
94,303
1. Root leftovers verdict:
DELETE: `FIX THIS.avi`, `SCROLL TIME.avi`, `Zelda1-Redux.zip`, `src.zip`, `VisualStudioSetup.exe`, `rustup-init.exe`, `a.out`, `analyze_funcs.txt`, `bout.txt`, `build_a3_fix.txt`, `build_a3_fix2.txt`, `build_a3_fix3.txt`, `build_err.txt`, `build_f3_log.txt`, `build_f3_out.txt`, `build_log.txt`, `build_midi_out.txt`, `build_out.txt`, `build_out_a3.txt`, `build_out3.txt`, `build_out_new.txt`, `build_output.txt`, `build_run.tmp`, `capture.log`, `capture2.log`, `event`, `raw`, `t.out`, `test_copy.tmp`, `FINAL TRY.zip`, `build_f3.bat`, `run_build.bat`.
MOVE local-only: `Legend of Zelda, The (USA).nes`, `Zelda Redux.nes` -> `local/roms/`.
DELETE or move local-only: `Zelda - Ocarina of Time - Great Fairy's fountain.mid`.
MOVE: `probe_heart_flash.lua` -> `tools/probes/`; `scan_drain2.py` -> `tools/debug/`; `nes_reference.png` -> `builds/reports/legacy/` if still useful.
MOVE docs: `T27_T29_FRONTEND_DIARY.md`, `RESUME.md`, `CODEX_HANDOFF.md`; rename `best practices.md` -> `docs/engineering/best_practices.md`.

2. Generated data fat verdict:
KEEP only until `REQUIRE_GENERATED_ASSETS=1` is green. Then drop checked-in generated blobs under `data/`, `src/data/`, `RoomRom/data/`, and `src/gen/music_great_fairy.bin`. KEEP `src/gen/z_01.c`..`z_07.c` for now: transpile adapters still referenced by plans/builds.

3. Vendor fat verdict:
KEEP `sgdk/` as pinned submodule; do not commit-trim internals. DELETE tracked non-Zelda refs: `reference/Sonic 2/`, `reference/SONIC2_W.68K`, `reference/Sonic The Hedgehog 2 (World) (Rev B).md`, `reference/sega2f_files/`. MOVE secondary Zelda refs to `reference/secondary/` or delete after citation sweep: `reference/Disassembly by Trax/`, `reference/Disassembly by camthesaxman/`. DELETE/MOVE out untracked `Zelda1-Redux/`; future code should use `REDUX_ROOT` or builder-supplied input. DELETE untracked `midi/` unless demo work is deliberately archived.

4. Backup/temp verdict:
DELETE tracked `.pre-merge-backup/`. DELETE ignored `.codex_tmp/`, all `__pycache__/`, `tools/out/`, demo `out/` dirs.

5. Tools clutter verdict:
Canonical tree: `tools/builder/`, `tools/extractors/`, `tools/probes/lua/`, `tools/probes/py/`, `tools/state/`, `tools/verifiers/`, `tools/demos/{intro,file_select,midi,music}/`, `tools/debug/`, `tools/archive/`. Root `tools/*.lua` and `tools/*.py` should go to zero except orchestration entrypoints like `run_regression_matrix.py`.

6. builds/ verdict:
4.7 GB and 47,574 tracked files is unacceptable. Make `builds/` local output. Track only `builds/BUILDS.md` and curated text/json reports if truly needed.

7. Owned C dead code:
KEEP `src/zelda_translated/` now; `src/genesis_shell.asm` includes it. KEEP `src/gen/z_*.c` now. DELETE only after Phase 12/16.5 caller audit. Do not touch `RoomRom/src/` from this worktree.

8. Doc consolidation:
Authority should be `README.md`, `CLAUDE.md`, master plan, `docs/audit/*`. Archive handoffs/diaries. Move best-practices content under `docs/engineering/` and update citations.

9. Top 10 actions ranked:
```powershell
git rm -- 'VisualStudioSetup.exe' 'rustup-init.exe' 'a.out' 'bout.txt' 'build_a3_fix.txt' 'build_a3_fix2.txt' 'build_a3_fix3.txt' 'build_err.txt' 'build_f3_log.txt' 'build_f3_out.txt' 'build_log.txt' 'build_midi_out.txt' 'build_out_a3.txt' 'build_out3.txt' 'build_out_new.txt' 'build_output.txt' 'build_run.tmp' 'capture.log' 'capture2.log' 'event' 'raw' 't.out' 'test_copy.tmp' 'FINAL TRY.zip' 'build_f3.bat' 'run_build.bat'
Remove-Item -LiteralPath 'FIX THIS.avi','SCROLL TIME.avi','Zelda1-Redux.zip','src.zip','analyze_funcs.txt','build_out.txt' -Force
New-Item -ItemType Directory -Force 'local\roms'; Move-Item -LiteralPath 'Legend of Zelda, The (USA).nes','Zelda Redux.nes' -Destination 'local\roms'
git rm -r --cached builds
git rm -r -- '.pre-merge-backup'
Remove-Item -Recurse -Force '.codex_tmp','__pycache__','tools\__pycache__','RoomRom\__pycache__','tools\out'
git rm -r -- 'reference/Sonic 2' 'reference/sega2f_files' 'reference/SONIC2_W.68K' 'reference/Sonic The Hedgehog 2 (World) (Rev B).md'
git mv 'T27_T29_FRONTEND_DIARY.md' 'docs/archive/T27_T29_FRONTEND_DIARY.md'; git mv 'RESUME.md' 'docs/archive/RESUME.md'; git mv 'CODEX_HANDOFF.md' 'docs/archive/CODEX_HANDOFF.md'
git mv 'best practices.md' 'docs/engineering/best_practices.md'
git mv 'probe_heart_flash.lua' 'tools/probes/probe_heart_flash.lua'; git mv 'scan_drain2.py' 'tools/debug/scan_drain2.py'
```

10. Final stance:
RED as-is for Phase 1.5 -> 17. The code can limp into Phase 1.5, but Phase 17 legal builder/public package will fail without this cleanup.
