# Sonnet Round 2 Cross-Critique

## 1. Points from CODEX, GEMINI, OPUS I AGREE with

**Codex — RED stance severity**: Codex is right that `git status` and CI scans are poisoned by 47K tracked files. The builder role framing ("Phase 17 will fail without cleanup") is hyperbolic for the milestone sequence, but the technical symptom is real. I verified the 47,574 count. Conceded.

**Codex — `FINAL TRY.zip` in git index but physically missing**: This is a concrete anomaly I did not explicitly call out in Round 1. A missing-but-tracked file corrupts `git status` output on every invocation. Should be in the immediate `git rm` pass. Codex is correct to flag it.

**Gemini — "rename FINAL TRY path" (space in GCC path)**: The project is at `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY`. Spaces in the path can break `$(shell pwd)` and GCC include expansion in Makefiles/batch scripts that don't quote aggressively. `build.bat` uses `%ROOT%` consistently with quotes, so it's currently mitigated — but the risk is real for any new tool that naively constructs paths. Gemini is correct to name it; I understated this in Round 1.

**Opus — KEEP `.avi` files per memory rule**: Correct. `feedback_fix_this_avi` is an active memory entry. Both `.avi` files are user's live bug capture artifacts. Gemini and Codex saying DELETE is wrong. Opus and I agree: MOVE to `docs/bug_reports/`, not delete.

**Opus — `builds/Legend of Zelda, The (USA).nes` committed inside `builds/`**: Opus caught this; I missed it in Round 1. There is a second ROM that landed inside `builds/` itself, not just at the root. That means the `roms/` consolidation step must also sweep `builds/*.nes`. Valid new evidence — see Section 6.

**Gemini — DELETE `.superpowers/brainstorm/` only, not the whole `.superpowers/` root**: I said the same in Round 1 (do not delete `.superpowers/` root). Gemini agrees on the nuance. Convergence is correct here.

---

## 2. Points I DISAGREE with

**Gemini — "RESET builds/ (find -maxdepth 1 -type f -delete)"**: This is reckless. `builds/whatif.md` and `builds/whatif.lst` are actively referenced by 15+ Lua probes. A flat `find -maxdepth 1 -type f -delete` on `builds/` would silently destroy the current probe harness. Gemini's command is copy-paste dangerous. Counterevidence: `tools/bizhawk_boot_probe.lua`, `tools/bizhawk_intro_hook_probe.lua`, and at least 13 others hardcode `builds/whatif.lst`. This must not run before Phase 0 rename.

**Gemini — "rename FINAL TRY directory"**: I agree the space is a latent risk, but renaming the working directory mid-project is a higher-disruption operation than Gemini implies. Every script, every `%ROOT%` path, every `.gitmodules` reference, every worktree path at `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1` gets invalidated. The worktree rule in `CLAUDE.md` explicitly hard-codes that path. This is not a one-liner. Gemini lists it alongside `rm a.out` without flagging the blast radius. I disagree with bundling this into the cleanup commit.

**Opus — "bulk-move 250 root Lua to `tools/archive_probes/` now"**: Opus frames this as an early cleanup win. It is not. Round 1 confirmed that the 255 Lua scripts at `tools/*.lua` include the live probe fleet (bizhawk_boot_probe.lua, bizhawk_intro_hook_probe.lua, bizhawk_frontend_transition_gen_capture.lua, etc.). They are not archive candidates — they are the current test harness. Moving them breaks `build.bat`-adjacent workflows immediately. This must wait for Phase 0 rename, then a deliberate triage pass that separates live probes from deprecated ones. Opus's action ordering is wrong.

**Codex — implied "Sonic 2 binaries are the bulk of tracked fat"**: Codex's summary led with Sonic 2 as a tracked offender. I ran `git ls-files reference/` and confirmed Sonic 2 material is **untracked** submodule-checkout fat, not the 47K file problem. The real culprit is `builds/reports/` (45,608 tracked PNGs). Codex's framing misdirects remediation priority.

**Opus — "add `*.md`, `*.lst`, `*.elf`, `*.o` as global `.gitignore` patterns in builds/"**: Too broad. `builds/whatif.md` should stay tracked until Phase 0 renames it. A global `*.md` exclusion in `builds/` would silently hide `BUILDS.md` which has human-authored index content worth archiving. Pattern-level gitignore should be surgical (`builds/reports/`, `builds/obj/`, `builds/archive/`), not glob-all.

---

## 3. Single highest-impact change

**`git rm -r builds/reports builds/archive builds/obj .pre-merge-backup` in one commit.**

This is four targeted `git rm -r` calls that together recover ~4.7 GB and untrack 47,574 files. It has zero code risk (all four directories are pure output/backup, zero references in `build.bat` or `src/`). It immediately makes `git status` usable, cuts CI scan time from minutes to seconds, and is fully reversible via `git revert`. Every other cleanup action (Lua reorg, tools restructure, Phase 0 rename, doc consolidation) operates faster after this commit lands because the index is no longer saturated. Nothing else has this ratio of risk-to-impact.

---

## 4. Updated stance

**YELLOW** — The four-directory `git rm` is non-blocking-but-urgent; code is shippable without it but every git operation degrades until it runs.

---

## 5. Execution order — numbered, safest-first, single-commit ready

```bash
# PRE-FLIGHT: confirm worktree state (CLAUDE.md hard rule)
git worktree list

# --- COMMIT 1: Untrack output/backup bloat (zero code risk) ---

# 1a. 45,961 tracked files in builds/reports (45,608 PNGs)
git rm -r builds/reports
echo "builds/reports/" >> .gitignore
# Verify: git ls-files builds/reports | wc -l  → must be 0

# 1b. 1,498 tracked files in builds/archive (4.4 GB of Zelda16-27 snapshots)
git rm -r builds/archive
echo "builds/archive/" >> .gitignore
# Verify: git ls-files builds/archive | wc -l  → must be 0

# 1c. 96 tracked .o files in builds/obj
git rm -r builds/obj
echo "builds/obj/" >> .gitignore
# Verify: git ls-files builds/obj | wc -l  → must be 0

# 1d. 40 tracked files in .pre-merge-backup
git rm -r .pre-merge-backup
rm -rf .pre-merge-backup
# Verify: git ls-files .pre-merge-backup | wc -l  → must be 0

# 1e. Missing-but-tracked FINAL TRY.zip (corrupts git status)
git rm --cached "FINAL TRY.zip" 2>/dev/null || true
# Verify: git status | grep "FINAL TRY.zip"  → must be empty

# 1f. Tracked build logs in builds/ root
git rm -f builds/build_clean.txt builds/build_clean_err.txt builds/build_err.txt \
    builds/build_err_orig.txt builds/build_log.txt builds/build_out_orig.txt \
    builds/build_renamed.txt builds/build_renamed_err.txt 2>/dev/null || true
printf "\nbuilds/build_*.txt\nbuilds/build_*.log\n" >> .gitignore

# 1g. Tracked ROM inside builds/ (Opus catch)
git rm -f "builds/Legend of Zelda, The (USA).nes" 2>/dev/null || true
# .gitignore already has *.nes; verify: git ls-files "*.nes"  → must be 0

# COMMIT 1 — single atomic commit
git add .gitignore
git commit -m "cleanup: untrack 47K output files (builds/reports, archive, obj, .pre-merge-backup)"

# --- COMMIT 2: Root junk (untracked, no git rm needed) ---

# 2a. Untracked binary installers / orphan files
rm -f "Zelda1-Redux.zip" VisualStudioSetup.exe rustup-init.exe a.out
rm -f analyze_funcs.txt bout.txt build_a3_fix.txt build_err.txt build_log.txt \
      build_f3_log.txt build_out.txt build_out_a3.txt build_out3.txt \
      build_out_new.txt build_output.txt build_midi_out.txt
rm -f reports/bizhawk_t5_ppu_probe.txt
rm -rf .codex_tmp tools/out/
find . -name "__pycache__" -type d -not -path "./.git/*" -exec rm -rf {} + 2>/dev/null || true

# 2b. Consolidate root docs (git mv preserves history)
mkdir -p docs/archive/diaries docs/archive/handoffs
git mv T27_T29_FRONTEND_DIARY.md docs/archive/diaries/
git mv RESUME.md CODEX_HANDOFF.md docs/archive/handoffs/
git mv "best practices.md" docs/best_practices.md

# 2c. Move ROMs to single ignored dir (include builds/ stray caught by Opus)
mkdir -p roms
mv "Legend of Zelda, The (USA).nes" roms/ 2>/dev/null || true
mv "Zelda Redux.nes" roms/ 2>/dev/null || true
printf "\nroms/\n" >> .gitignore
# Verify: git ls-files roms/ | wc -l  → must be 0

# 2d. Move Zelda1-Redux under reference/
git mv Zelda1-Redux reference/Zelda1-Redux

# 2e. Consolidate non-Zelda reference material
mkdir -p reference/external
git mv "reference/Sonic 2" reference/external/ 2>/dev/null || true
git mv reference/sega2f_files reference/external/ 2>/dev/null || true

# 2f. Rename tools/plans → tools/drain_batches (4 orphan JSON files)
git mv tools/plans tools/drain_batches

# 2g. Add sgdk vendor fat to .gitignore (submodule checkout artifacts, NOT tracked)
printf "\nsgdk/sample/\nsgdk/doc/\n" >> .gitignore
# Physical remove optional; will re-appear on submodule update unless sparse-checkout is set

git add -A
git commit -m "cleanup: root junk, doc archive, ROM consolidation, reference reorg"
```

Post-commit verification:
```bash
git ls-files | wc -l          # should drop from ~47K+ to ~2K range
git status                    # should be clean or near-clean
grep -rn "whatif" tools/ src/ build.bat | grep -v "#"  # should show active references (confirms whatif.* not prematurely removed)
```

---

## 6. New evidence (if any)

**Opus caught `builds/Legend of Zelda, The (USA).nes`** — a ROM committed inside `builds/` itself, not just at the repo root. I missed this in Round 1. The `roms/` consolidation step in the execution commands above now covers this case explicitly with `git rm -f "builds/Legend of Zelda, The (USA).nes"` in Commit 1 and the physical `mv` in Commit 2.

**`FINAL TRY.zip` is in the git index but physically absent** (Codex). This means `git status` reports it as "deleted" on every invocation — silent noise that I understated by categorizing it under root junk. The correct fix is `git rm --cached "FINAL TRY.zip"` rather than physical delete, since the file is already gone. Added to Commit 1 above.

**Gemini's "rename the directory" concern is more load-bearing than it appears**: after reading Gemini's full position, the concern is that `FINAL TRY-roomrom-s1` (the worktree) inherits the parent's space-containing path. The `CLAUDE.md` hard-codes `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1` as the canonical worktree path. A rename cascades into that hard-coded memory entry. This makes the rename even more dangerous, not less. It should be explicitly out-of-scope for this cleanup pass.
