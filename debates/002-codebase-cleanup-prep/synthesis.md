# Final Synthesis: Codebase cleanup prep for Phase 1.5 → 17

**Date:** 2026-05-02
**Rounds:** 2 (cross-critique)
**Participants:** 🔴 Codex, 🟡 Gemini, 🟠 Sonnet, 🐙 Claude/Opus
**Final stances:** All four YELLOW after round 2 (Codex moved RED → YELLOW after Sonnet's evidence).

---

## Convergent verdict

Cleanup is **non-blocking-but-urgent**. Code ships without it. Every git operation degrades until it runs.

**Single highest-impact change** (all four agree):
```
git rm -r builds/reports builds/archive builds/obj .pre-merge-backup
```
4.7 GB recovered. ~47,200 git index entries dropped. Zero code risk.

## What changed from debate 001 framing

Sonnet's `git ls-files` evidence shifted everything:

| Claim (debate 001 / r1) | Reality (Sonnet r1) |
|---|---|
| "47K tracked files = Sonic 2 binaries" (Codex r1) | 45,608 tracked PNGs in `builds/reports/` |
| "sgdk/sample needs `rm -rf`" (Gemini + Opus r1) | Submodule checkout fat; `git ls-files = 0`; fix is `.gitignore` / sparse-checkout |
| "Bulk-archive 250 root Lua now" (Opus r1) | Live probe fleet hardcodes `builds/whatif.*`; must wait for Phase 0 rename |
| "Delete `.avi` files" (Gemini + Codex r1) | Memory rule `feedback_fix_this_avi`: KEEP, MOVE to `docs/bug_reports/` |
| "`builds/archive/` keep, audit later" (Opus r1) | 1,498 tracked stale Zelda16-27 .lst snapshots, `git rm -r` instantly |
| Tracked stragglers unnamed | `FINAL TRY.zip` in index but missing; `event`, `raw`, `t.out`, `capture.log`, etc. (Codex) |
| `builds/Legend of Zelda, The (USA).nes` not flagged | ROM committed INSIDE `builds/` itself (Opus catch) |

## Areas of agreement after round 2

1. **Atomic untrack commit first.** `git rm -r` against `builds/{reports,archive,obj}` + `.pre-merge-backup` + `FINAL TRY.zip` (cached) + `builds/build_*.txt` + `builds/Legend of Zelda, The (USA).nes`. Plus matching `.gitignore` lines.
2. **Doc consolidation second.** `T27_T29_FRONTEND_DIARY.md` → `docs/archive/diaries/`; `RESUME.md` + `CODEX_HANDOFF.md` → `docs/archive/handoffs/`; `best practices.md` → `docs/best_practices.md`.
3. **Root junk physical delete.** Untracked installers, .zip, .out, stale build logs.
4. **Reference reorg.** `Zelda1-Redux/` → `reference/Zelda1-Redux/`; `reference/Sonic 2/` + `reference/sega2f_files/` → `reference/external/`.
5. **ROM consolidation.** All `*.nes` → `roms/` (gitignored).
6. **`.avi` files MOVE not delete.** → `docs/bug_reports/`.
7. **`tools/plans/` → `tools/drain_batches/`** (4 orphan JSON; disambiguate from `docs/superpowers/plans/`).
8. **KEEP `src/zelda_translated/`, `src/gen/z_*.c`** — load-bearing per `genesis_shell.asm:725-732`.
9. **sgdk submodule fat** — `.gitignore` `sgdk/sample/` + `sgdk/doc/`, NOT `rm -rf`.
10. **DEFERRED until Phase 0:** Lua bulk move, `builds/whatif.*` removal, `tools/` directory restructure.

## Areas of disagreement (resolved)

1. **`.avi` keep vs delete:** Memory rule wins → KEEP/MOVE.
2. **Lua bulk-archive timing:** Sonnet's hardcoded-path evidence wins → defer until Phase 0.
3. **sgdk strategy:** Sonnet's submodule evidence wins → `.gitignore` not `rm`.
4. **Stance severity:** Codex moved RED → YELLOW after Sonnet's evidence. All four YELLOW.
5. **Path rename ("FINAL TRY" with space):** Gemini wanted bundled now; Sonnet/Opus showed `CLAUDE.md` hardcodes the path AND the worktree (`FINAL TRY-roomrom-s1`) inherits the same space — out-of-scope for this cleanup, dedicated future task.

## Execution Plan

**COMMIT 1 — Atomic untrack (zero code risk):**
- `git rm -r builds/reports builds/archive builds/obj .pre-merge-backup`
- `git rm --cached "FINAL TRY.zip"`
- `git rm builds/build_*.txt builds/build_*.log`
- `git rm "builds/Legend of Zelda, The (USA).nes"`
- `git rm` on tracked stragglers: `event`, `raw`, `t.out`, `test_copy.tmp`, `capture.log`, `capture2.log`, `nes_reference.png`, `build_a3_fix*.txt`, `build_f3_out.txt`, `build_run.tmp`, `build_f3.bat`, `run_build.bat`, `probe_heart_flash.lua` (will move next), `scan_drain2.py` (will move next)
- Append to `.gitignore`: `builds/reports/`, `builds/archive/`, `builds/obj/`, `builds/build_*.txt`, `builds/build_*.log`, `builds/*.elf`, `builds/*.o`, `roms/`, `local/`, `sgdk/sample/`, `sgdk/doc/`, `*.tmp`, `*.log` (root)

**COMMIT 2 — Untracked physical delete:**
- `rm -f Zelda1-Redux.zip VisualStudioSetup.exe rustup-init.exe a.out src.zip`
- `rm -f analyze_funcs.txt bout.txt build_*.txt`
- `rm -f reports/bizhawk_t5_ppu_probe.txt`
- `rm -rf .codex_tmp tools/out/ .superpowers/brainstorm`
- `find . -name __pycache__ -type d -prune -exec rm -rf {} +`

**COMMIT 3 — Doc + reference + bug-report + ROM consolidation:**
- `mkdir -p docs/archive/{diaries,handoffs} docs/bug_reports reference/external roms midi/inputs`
- `git mv T27_T29_FRONTEND_DIARY.md docs/archive/diaries/`
- `git mv RESUME.md CODEX_HANDOFF.md docs/archive/handoffs/`
- `git mv 'best practices.md' docs/best_practices.md`
- `git mv 'reference/Sonic 2' reference/external/`
- `git mv reference/sega2f_files reference/external/`
- `git mv Zelda1-Redux reference/Zelda1-Redux`
- `mv 'FIX THIS.avi' 'SCROLL TIME.avi' docs/bug_reports/`
- `mv 'Legend of Zelda, The (USA).nes' 'Zelda Redux.nes' roms/`
- `mv "Zelda - Ocarina of Time - Great Fairy's fountain.mid" midi/inputs/`

**COMMIT 4 — Tools renames + script reloc:**
- `git mv tools/plans tools/drain_batches`
- `mkdir -p tools/debug`
- `git mv probe_heart_flash.lua tools/probes/probe_heart_flash.lua`  (or wherever its references live)
- `git mv scan_drain2.py tools/debug/scan_drain2.py`

**Verification after every commit:**
- `git ls-files | wc -l` — drop from ~47K to ~2K-3K after commit 1.
- `git status` — clean.
- `du -sh .` — drop ~4.7 GB after commit 1 + 2.
- `find . -name __pycache__ -type d | wc -l` — 0 after commit 2.
- `grep -rn "whatif" tools/ src/ build.bat` — must still show active references (proves we did NOT prematurely remove `builds/whatif.*`).

## Final stance

**YELLOW.** Plan is concrete, evidence-backed, non-blocking-but-urgent. Execute commit 1 immediately for the largest impact-to-risk ratio in the project today. Commits 2-4 layer in safely after.

**Out of scope this pass:** rename "FINAL TRY" path; Lua bulk archive; tools/ directory full restructure; `builds/whatif.*` removal — all wait for Phase 0 rename to land.
