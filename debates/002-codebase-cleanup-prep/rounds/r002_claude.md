# Claude (Opus) Round 2 Cross-Critique

## 1. Points from CODEX, GEMINI, SONNET I AGREE with

**Sonnet's `builds/reports/` finding (45,608 tracked PNGs) is the single most important contribution of this debate.** I had said "KEEP, audit later" — wrong. Probe screenshots are regenerable outputs, not source. Untracking saves 255 MB AND 45,961 git index entries — the index size matters more than disk size for daily agent operations (every `git status`, every `git add`, every CI git scan touches the index). My round 1 missed this.

**Sonnet's submodule finding for `sgdk/`** corrects me and Gemini both. We both wrote `rm -rf sgdk/sample sgdk/doc` as if it were tracked vendor code. `git ls-files sgdk/sample = 0` — these are submodule-checkout artifacts. Correct fix: `.gitignore` entries plus `.git/modules/sgdk/info/sparse-checkout`.

**Codex's Top-10 PowerShell list** captured tracked stragglers I missed: `event`, `raw`, `t.out`, `test_copy.tmp`, `capture.log`, `capture2.log`, `nes_reference.png`, `probe_heart_flash.lua` at root, `scan_drain2.py` at root, `FINAL TRY.zip` (in git index but file gone). These are "hard-to-see" because they have no extension or look like reasonable scratch — easy to miss without `git ls-files | grep -E "^[a-z]"`.

**Sonnet's `builds/whatif.*` warning is correct.** 15+ live Lua probes hardcode the path. My Round 1 step 8 ("git mv tools/*.lua tools/archive_probes/") would break the live harness. Phase 0 rename must happen first.

**Gemini's blunt "digital landfill" framing** is the right energy even where she's wrong on specifics. The signal-to-noise ratio is the real cost.

## 2. Points I DISAGREE with

**Gemini's blanket `.avi` nuke.** Memory rule `feedback_fix_this_avi` says `FIX THIS.avi` is the user's live bug-capture pipeline. Sonnet sided with me. Resolution: MOVE to `docs/bug_reports/`, do not delete.

**Codex's RED stance.** Codex says cleanup is shipping-blocking. The release cleanup IS blocking for Phase 17 specifically, but Phase 1.5 → 16 can run on the messy tree. YELLOW with execution priority is the honest read. The cleanup is high-impact-low-risk, not high-blocking.

**Codex's "rename FINAL TRY directory" item (via Gemini).** Path-with-space is real GCC pain — but the rename has its own blast radius (every script's hardcoded path, every probe Lua, every memory rule referencing the absolute path). Defer until a quiet release prep window.

**Codex's "DELETE/MOVE midi/ unless deliberately archived."** Memory `project_midi_fs_integration.md` says MIDI subsystem is wired and is an active unblock for FS audio. Sonnet said keep. Codex was wrong; midi/ is live.

**Codex's "MOVE secondary Zelda refs (Disassembly by Trax / camthesaxman) to reference/secondary/ or delete after citation sweep."** These are NES disasm sources complementing aldonunez. Cite-checking before any delete: master plan and source comments need the audit. Defer with neither move nor delete until citation sweep runs.

## 3. Single highest-impact change

**Run a single `git rm -r` commit against `builds/{archive,reports,obj}` plus `.pre-merge-backup` plus the tracked stale stragglers.** Every other action is moves and `.gitignore` tightening that can be batched after. This commit alone:
- Recovers ~4.7 GB on disk.
- Drops ~47,200 git index entries.
- Eliminates the Sonic 2 / sega2f / pre-merge-backup tracked-but-stale waste.
- Adds the corresponding `.gitignore` lines so they never come back.

That's the cleanup commit. Everything else is post-cleanup polish.

## 4. Updated stance

**YELLOW.** Cleanup is not strictly blocking for Phase 1.5–16 but is high-impact-low-risk for every agent operation that touches `git status`, `git add`, or CI scans. Execute the highest-value `git rm` commit immediately, then layer moves and `.gitignore` updates as separate commits.

## 5. Execution order — numbered, safest-first, single-commit ready

```bash
# COMMIT 1: zero-code-risk untrack massive output dirs + tracked stale stragglers + backup tree
git rm -r builds/archive builds/reports builds/obj .pre-merge-backup
git rm -r 'reference/Sonic 2' reference/sega2f_files reference/SONIC2_W.68K 'reference/Sonic The Hedgehog 2 (World) (Rev B).md' 2>/dev/null || true
git rm builds/build_*.txt builds/build_*.log 2>/dev/null || true
git rm 'FINAL TRY.zip' build_a3_fix.txt build_a3_fix2.txt build_a3_fix3.txt build_f3_out.txt build_run.tmp capture.log capture2.log event raw t.out test_copy.tmp build_f3.bat run_build.bat 2>/dev/null || true
cat >> .gitignore <<'EOF'

# Build outputs (regenerable)
builds/archive/
builds/reports/
builds/obj/
builds/build_*.txt
builds/build_*.log
builds/*.elf
builds/*.o

# SGDK submodule checkout fat
sgdk/sample/
sgdk/doc/

# ROM dir (legal model — user supplies locally)
roms/
local/
EOF
git add .gitignore
git commit -m "cleanup: untrack build outputs, backup tree, stale tracked files (~4.7 GB, 47K index entries)"

# COMMIT 2: physical delete of untracked root junk
rm -f Zelda1-Redux.zip VisualStudioSetup.exe rustup-init.exe a.out src.zip
rm -f analyze_funcs.txt bout.txt build_err.txt build_log.txt build_f3_log.txt
rm -f build_out.txt build_out_a3.txt build_out3.txt build_out_new.txt
rm -f build_output.txt build_midi_out.txt
rm -rf .codex_tmp .superpowers/brainstorm tools/out
find . -name "__pycache__" -type d -not -path "./.git/*" -prune -exec rm -rf {} + 2>/dev/null

# COMMIT 3: doc + reference + bug-report consolidation (git mv, preserves history)
mkdir -p docs/archive/diaries docs/archive/handoffs docs/bug_reports reference/external roms
git mv T27_T29_FRONTEND_DIARY.md docs/archive/diaries/
git mv RESUME.md docs/archive/handoffs/
git mv CODEX_HANDOFF.md docs/archive/handoffs/
git mv 'best practices.md' docs/best_practices.md
git mv 'reference/Sonic 2' reference/external/ 2>/dev/null || true
git mv reference/sega2f_files reference/external/ 2>/dev/null || true
[ -d Zelda1-Redux ] && git mv Zelda1-Redux reference/Zelda1-Redux
mv 'FIX THIS.avi' docs/bug_reports/ 2>/dev/null || true
mv 'SCROLL TIME.avi' docs/bug_reports/ 2>/dev/null || true
mv 'Legend of Zelda, The (USA).nes' roms/ 2>/dev/null || true
mv 'Zelda Redux.nes' roms/ 2>/dev/null || true
mv 'Zelda - Ocarina of Time - Great Fairy''s fountain.mid' midi/inputs/ 2>/dev/null || true
git commit -am "cleanup: consolidate docs, reference, bug-reports, roms into canonical dirs"

# COMMIT 4: tools/plans rename
git mv tools/plans tools/drain_batches
git commit -m "cleanup: rename tools/plans -> tools/drain_batches (disambiguate from docs/superpowers/plans)"

# COMMIT 5: orphan tracked scripts at root
git mv probe_heart_flash.lua tools/probes/probe_heart_flash.lua 2>/dev/null
git mv scan_drain2.py tools/debug/scan_drain2.py 2>/dev/null
mkdir -p tools/debug 2>/dev/null
git mv nes_reference.png builds/reports/legacy/nes_reference.png 2>/dev/null
git commit -am "cleanup: relocate tracked scripts to canonical tools subdirs"

# DEFERRED until Phase 0 rename completes (do NOT run now):
# git rm builds/whatif.md builds/whatif.lst builds/whatif.elf builds/whatif.o builds/whatif_prev.md
# git mv tools/*.lua tools/probes/lua/
```

Post-commit verification greps:
- `grep -rn "whatif" tools/ src/ build.bat | wc -l` — establishes baseline before Phase 0 rename.
- `git ls-files | wc -l` — should drop by ~47,200 after commit 1.
- `du -sh .` — should drop by ~4.7 GB.
- `find . -name "__pycache__" -type d | wc -l` — should be 0 after commit 2.

## 6. Final note

Sonnet's file-grounded reading made this debate concrete. Every other advisor (including me) was operating partly on framing prose. Sonnet's `git ls-files` counts are the actual numbers; align everything to those.
