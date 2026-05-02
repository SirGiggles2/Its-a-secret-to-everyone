# Round 1 Condensed Summary (for Round 2 cross-critique)

## 🔴 Codex — RED
"47,574 tracked files in builds/" + ".pre-merge-backup/ tracked" + "Sonic 2 binaries tracked" + many tracked stale stragglers (`event`, `raw`, `t.out`, `capture.log`, `nes_reference.png`, `probe_heart_flash.lua` at root, `scan_drain2.py` at root, `FINAL TRY.zip` in index but missing). Top adds: `git rm -r builds`, `git rm -r .pre-merge-backup`, `git rm reference/SONIC2_W.68K reference/Sonic\ 2 reference/sega2f_files reference/Sonic\ The\ Hedgehog\ 2\ \(World\)\ \(Rev\ B\).md`. Move ROMs to `local/roms/`. Tools tree: `tools/{builder,extractors,probes/{lua,py},state,verifiers,demos/{intro,file_select,midi,music},debug,archive}`. KEEP `src/zelda_translated/` and `src/gen/z_*.c` — load-bearing. Stance RED because legal builder/Phase 17 will fail without cleanup.

## 🟡 Gemini — YELLOW
"Digital landfill." NUKE root .avi/.exe/.zip/stale logs. PURGE .pre-merge-backup/.codex_tmp/.superpowers. TRIM sgdk/sample + sgdk/doc. RESET builds/ (find -maxdepth 1 -type f -delete). REORG tools/ to `pipeline/research/test`. Move non-Zelda reference to `reference/external/`. Move ROMs out of root. Rename "FINAL TRY" path (space breaks GCC).

## 🟠 Sonnet — YELLOW (file-grounded, decisive evidence)
**Critical new evidence:**
1. **45,608 tracked PNGs in `builds/reports/`** = primary git tracking problem. Codex said "47K tracked" but didn't break down; Opus said "keep, audit later" — wrong call. `git rm -r builds/reports` + `.gitignore` saves 255 MB and 45,961 git entries.
2. **`builds/obj/` has 96 tracked `.o` files.** Both Codex+Opus missed. Pure compile output committed.
3. **`builds/archive/` = 1,498 tracked files of Zelda16-27 .lst snapshots.** ~4.4 GB, instant `git rm -r`.
4. **`sgdk/` is a submodule.** `git ls-files sgdk/sample` = 0, `git ls-files sgdk/doc` = 0. They're submodule-checkout fat, not tracked. `rm -rf sgdk/sample` (Gemini/Opus) is a no-op for git; correct fix is sparse-checkout or root `.gitignore`.
5. **`builds/whatif.*` actively referenced by 15+ Lua probes** (`tools/bizhawk_boot_probe.lua` etc. hardcode the path). `git rm builds/whatif.*` BEFORE Phase 0 rename breaks the harness.
6. **`tools/plans/` = 4 orphan drain JSON files**, not the same as `docs/superpowers/plans/`. Rename `tools/plans/` → `tools/drain_batches/` to disambiguate.
7. **`Zelda1-Redux/` only referenced in doc comments** of `tools/extract_fs_assets.py` (zero `open(` calls). Safe to move under `reference/Zelda1-Redux/`.
8. **`src/genesis_shell.asm:725-732`** has 8 `include "zelda_translated/z_0N.asm"` lines — confirms `src/zelda_translated/` LOAD-BEARING. Codex/Opus also said keep, but the citation is firm.

Stance YELLOW: cleanup recovers ~5 GB and 47K tracked files but is not strictly blocking.

## 🐙 Opus — YELLOW
Direct evidence: `builds/archive/` has Zelda16.1-Zelda21.1 stale .lst (4.2M each). `builds/Legend of Zelda, The (USA).nes` 132K — ROM committed to builds. KEEP `.avi` files (memory rule `feedback_fix_this_avi`), move to `docs/bug_reports/`. KEEP `src/zelda_translated/` (build.bat:59 + Sonnet's confirm). Tools archive: bulk-move 250 root Lua to `tools/archive_probes/`. Doc consolidation: `docs/{archive/{diaries,handoffs},bug_reports,best_practices.md}`. Builds gitignore: `*.md`, `*.lst`, `*.elf`, `*.o`, `obj/`, `archive/`, `reports/`, `vgmrom/`. Disagrees Gemini's blanket nuke of .avi and .superpowers.

## Convergence (3+ advisors)
- `git rm -r builds/archive` (4.4 GB recovered, 1,498 files).
- `git rm -r builds/reports` + add to .gitignore (255 MB, 45,608 PNGs).
- `git rm -r builds/obj` (Sonnet caught; 96 .o files).
- `git rm -r .pre-merge-backup` (40 tracked files; tracked confirmed).
- DELETE root: stale build_*.txt logs, .exe installers, .zip leftovers, a.out, analyze_funcs.txt, bout.txt, FINAL TRY.zip (in git index).
- MOVE ROMs to single ignored dir (`roms/` or `local/roms/`).
- MOVE non-Zelda reference (Sonic 2, sega2f_files, SONIC2_W.68K, Sonic 2 .md) to `reference/external/` OR `git rm` if tracked.
- MOVE doc archive: T27_T29_FRONTEND_DIARY.md, RESUME.md, CODEX_HANDOFF.md → `docs/archive/`.
- MOVE best practices.md → `docs/best_practices.md`.
- MOVE Zelda1-Redux/ → `reference/Zelda1-Redux/`.
- KEEP `src/zelda_translated/` and `src/gen/z_*.c` (load-bearing).
- DELETE __pycache__/ everywhere.
- Reorg `tools/` post-Phase 0 (consensus on direction; Sonnet warns against pre-Phase-0 Lua move).

## Divergence
1. **`.avi` files**: Opus + Sonnet KEEP/MOVE per memory rule; Gemini + Codex DELETE. Resolution: KEEP/MOVE — memory rule is authoritative.
2. **Bulk Lua archive**: Opus moves 250 Lua now; Sonnet blocks until Phase 0 rename done. Resolution: Sonnet correct — Phase 0 first.
3. **sgdk/sample + sgdk/doc**: Gemini + Opus said `rm -rf`; Sonnet showed they're untracked submodule fat. Resolution: `.gitignore` + sparse-checkout, not `rm`.
4. **Stance**: Codex RED, others YELLOW. Resolution: cleanup is high-impact-low-risk but not blocking; YELLOW with execution priority.
5. **47K-file root cause**: Codex implied Sonic 2 binaries; Sonnet proved 45,608 PNGs in `builds/reports/`. Resolution: Sonnet correct, target reports/ first.
6. **`Zelda1-Redux/` location**: Move to `reference/` (Opus + Sonnet) vs delete entirely (Codex). Resolution: Move.
7. **MIDI/midi-tools dir**: Codex DELETE; Sonnet KEEP (MIDI integration active per memory `project_midi_fs_integration`). Resolution: KEEP for now, revisit Phase 6/10.

## Strongest single recommendation across all four
`git rm -r builds/reports builds/archive builds/obj .pre-merge-backup` + `.gitignore` updates. Recovers ~4.7 GB, untracks 47K files, zero code risk. Run as one commit before any other action.
