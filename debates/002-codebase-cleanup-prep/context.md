# Debate 002: How improve codebase as-is to prep future phases? What delete/remove/reorganize?

**Date:** 2026-05-02
**Rounds:** 2 (cross-critique)
**Style:** thorough, AGGRESSIVE
**Mode:** cross-critique
**Advisors:** Codex, Gemini, Sonnet, Claude/Opus
**Word limit:** ~500 per response

## Question

Given the master plan + roadmap (already debated and improved at `debates/001-prime-directive-plan-improvement/synthesis.md`), what should be deleted, removed, renamed, restructured, or split out of the current codebase RIGHT NOW so future phases (Phase 1.5 → 17) execute cleanly?

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
- `FIX THIS.avi` (57M) — bug-report video
- `SCROLL TIME.avi` (47M) — bug-report video
- `Zelda1-Redux.zip` (1.7M) — already extracted to `Zelda1-Redux/`
- `VisualStudioSetup.exe` (4.2M)
- `rustup-init.exe` (12.2M)
- `src.zip` (582K)
- `a.out` (280B)
- `Zelda - Ocarina of Time - Great Fairy's fountain.mid` (3.8K)
- `Zelda Redux.nes` (128K) — second ROM not in `.gitignore`?
- `Legend of Zelda, The (USA).nes` (128K) — primary ROM
- `analyze_funcs.txt` (1.5K)
- `bout.txt` (72K)
- `build_a3_fix.txt` x3, `build_err.txt` (31K), `build_log.txt` (47.5K), `build_f3_log.txt` (81K), `build_out.txt` (41.5K), `build_out_a3.txt` (79K), `build_out3.txt`, `build_out_new.txt`, `build_output.txt`, `build_midi_out.txt` (10+ stale build logs)
- `T27_T29_FRONTEND_DIARY.md` (129K) — running diary, likely scratch
- `RESUME.md`, `CODEX_HANDOFF.md`, `best practices.md` — multiple authority docs

Tools clutter:
- 122 Python scripts at root of `tools/` (no submodule organization)
- 255 Lua probe scripts at root of `tools/`
- 5 Lua scripts under `tools/probes/` (canonical)
- 1 Lua at repo root
- 293 total Lua scripts in top-2 levels — hard to know which are canonical vs deprecated
- `tools/file_select_demo/`, `tools/file_select_test/`, `tools/intro_demo/`, `tools/intro_test/`, `tools/midi_demo/`, `tools/music_test/`, `tools/gen_wrappers/` — multiple demo/test variants
- `tools/plans/` — separate from `docs/superpowers/plans/`?
- `tools/out/` — transient

Owned C structure:
- `src/abi/`, `src/core/`, `src/data/`, `src/frontend/`, `src/game/`, `src/gen/`, `src/sgdk_adapter/`, `src/state/`, `src/zelda_translated/` (transpiled NES code)

State headers (per debate 001 finding): all `RAM()`/`OBJ()` macro shims. State contract decided typed C structs (`docs/audit/state_contract.md`).

Build size: `builds/` is 4.7 GB. Likely contains archive snapshots.

## Constraints / Hard Rules

1. RoomRom dev lives in `FINAL TRY-roomrom-s1` worktree. Touching `RoomRom/src/` from main worktree forbidden (memory rule `feedback_check_worktree_first`).
2. Anything cited in master plan (`docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md`) or roadmap is load-bearing — cleanup must not break references.
3. State contract decision (typed structs + NES mirror) is binding (`docs/audit/state_contract.md`).
4. `reference/aldonunez/` is the canonical NES disasm — keep.
5. `sgdk/` is vendor toolchain — keep but check for fat we can drop (samples, docs, tools we never use).
6. `Legend of Zelda, The (USA).nes` is the user-supplied ROM (kept locally per legal builder model).

## Asks of each debater

For each candidate (file/dir/pattern):
1. **DELETE / MOVE / RENAME / KEEP** verdict.
2. **Why** — short reason.
3. **Risk** — what breaks if we do it (probe scripts, build, doc references, future phase).
4. **Phase impact** — how this helps Phase 1.5 → 17 execution.

Group recommendations by category:
- Root leftovers (.avi/.zip/.exe/.txt logs/diaries)
- Generated data fat (after strict builder gate, what stays?)
- Vendor fat (sgdk/, Zelda1-Redux/, midi/, reference/Sonic 2, reference/sega2f_files)
- Backup/temp (.pre-merge-backup, .codex_tmp, __pycache__)
- Tools clutter (255 root Lua, 122 root Python — what to canonicalize)
- builds/ (4.7 GB)
- Owned C dead code (src/zelda_translated/, src/gen/, anything else)
- Doc consolidation (RESUME.md, CODEX_HANDOFF.md, T27_T29_FRONTEND_DIARY.md, best practices.md, README.md, CLAUDE.md)

End with: TOP 10 ranked actions ordered by (highest impact ÷ lowest risk).
