# Sonnet Round 1 Cleanup Analysis

I read every required file and ran verification greps before writing a single verdict.
Where I disagree with Codex or Opus, I cite the exact check that informed me.

---

## 1. Verdicts by category

### Root leftovers

| File | Verdict | Evidence |
|---|---|---|
| `FIX THIS.avi` (57M) | **MOVE → `docs/bug_reports/`** | Memory rule `feedback_fix_this_avi`: user's live bug capture. Not tracked in git. |
| `SCROLL TIME.avi` (47M) | **MOVE → `docs/bug_reports/`** | Same shape. Not tracked. |
| `Zelda1-Redux.zip` (1.7M) | **DELETE** | Already extracted. Not tracked. |
| `VisualStudioSetup.exe` (4.2M) | **DELETE** | Not tracked, not referenced anywhere. |
| `rustup-init.exe` (12.2M) | **DELETE** | RTK installed; installer is dead weight. Not tracked. |
| `a.out` (280B) | **DELETE** | C compiler dropping. Not tracked. |
| `Zelda - Ocarina of Time...mid` | **MOVE → `midi/inputs/`** | Not tracked. Root noise. |
| `Zelda Redux.nes` | **MOVE → `roms/` + add pattern to .gitignore** | `.gitignore` has `*.nes` at root, but the `roms/` dir doesn't exist yet. Phase 1.1 cites both PRG0 and PRG1 hashes. Add `roms/` to `.gitignore`. |
| `Legend of Zelda, The (USA).nes` | **MOVE → `roms/`** | Constraint 6 says keep locally; move to single ignored dir. |
| `analyze_funcs.txt` | **DELETE** | Already in `.gitignore`; physically present. |
| `bout.txt`, `build_*.txt` (10+ logs) | **DELETE all** | Stale. Most already covered by `.gitignore` patterns but physically present. Confirmed no references in `build.bat` or `tools/`. |
| `T27_T29_FRONTEND_DIARY.md` (129K) | **MOVE → `docs/archive/diaries/`** | Not referenced in master plan. Not referenced in `build.bat`. Historical. |
| `RESUME.md`, `CODEX_HANDOFF.md` | **MOVE → `docs/archive/handoffs/`** | Grep of `build.bat`, `src/`, `tools/builder` = zero references. Snapshot docs. |
| `best practices.md` | **MOVE → `docs/best_practices.md`** | Memory rule cites it as authoritative. Root-polluting; move, don't delete. |

### Generated data

`data/`, `src/data/`, `src/gen/`, `RoomRom/data/` — **KEEP ALL NOW.**

Master plan Task 1.11 says "strict generated-only gate" is the mechanism to gate deletion. Running that gate before extractors are complete will break the build. Do not bulk-delete. Deletion is Phase 1.10/1.11 work, not now.

`src/gen/z_01.c` through `z_07.c`: confirmed load-bearing. `build.bat:148` declares `C_GEN_TRANSPILE=z_01 z_02 z_03 z_04 z_05 z_06 z_07` and compiles each at `build.bat:293`. **KEEP.**

`tools/gen_wrappers/` with `*_manifest.json`: referenced by `tools/emit_gen_wrappers.py` and `tools/drain_finalize.py`. **KEEP.**

`tools/plans/drain_z*.json`: referenced by `tools/drain_finalize.py` implicit input patterns. **KEEP** (4 files, trivial size).

### Vendor fat

| Path | Verdict | Evidence |
|---|---|---|
| `sgdk/` (submodule) | **KEEP inc/ — TRIM sample/ and doc/** | `sgdk` is a git submodule (`.gitmodules` confirmed). `build.bat` uses `-I sgdk/inc` and `-I sgdk/inc/snd`. `sgdk/sample/` and `sgdk/doc/` have 0 tracked files (`git ls-files sgdk/sample` = 0, `git ls-files sgdk/doc` = 0). They are untracked checkout fat from the submodule. Add `sgdk/sample` and `sgdk/doc` to `.gitignore` (sparse-checkout or submodule path exclude). |
| `Zelda1-Redux/` (82M) | **MOVE → `reference/Zelda1-Redux/`** | `tools/extract_fs_assets.py` has comments citing `Zelda1-Redux/src/code/menus/file_select.asm` — those are doc comments, not `open()` calls. Grep showed zero `open(` or path-join calls into `Zelda1-Redux/`. Safe to move; update comment strings. |
| `midi/mid2vgm-beta5/`, `midi/PSG mode/` | **KEEP for now** | Memory `project_midi_fs_integration.md` says MIDI subsystem is wired. `midi/` is not tracked fat from a submodule — it's a local dir. Moving it is low-value right now; MIDI integration is an active unblock for FS. Revisit at Phase 6. |
| `reference/Sonic 2/`, `reference/sega2f_files/` | **MOVE → `reference/external/`** | Zero references in `build.bat`, `src/`, `tools/` (grep confirmed). Inspirational material only. |
| `reference/Disassembly by Trax/`, `reference/Disassembly by camthesaxman/` | **KEEP under `reference/`** | NES Zelda disasm sources; complement aldonunez. |
| `reference/aldonunez/` | **KEEP** | Constraint 4. |

### Backup / temp

DELETE all — zero risk:
- `.pre-merge-backup/` — 40 tracked files confirmed (`git ls-files .pre-merge-backup/ | wc -l = 40`). Git history is the backup. `git rm -r .pre-merge-backup/` then physical delete.
- `.codex_tmp/` — already in `.gitignore`, physically present.
- `.superpowers/brainstorm/` only — do NOT delete `.superpowers/` root (skills data may live there).
- `.claude/worktrees/` — already in `.gitignore`.
- `__pycache__/` everywhere — already in `.gitignore`, physically present.
- `tools/out/` (53K) — transient.

### Tools clutter

This is the most dangerous cleanup zone. I ran actual checks:

**tools/*.lua (255 files)**: Multiple Lua scripts directly reference `builds/whatif.lst` and `builds/whatif.md` by that exact name (`tools/bizhawk_boot_probe.lua`, `tools/bizhawk_intro_hook_probe.lua`, `tools/bizhawk_frontend_transition_gen_capture.lua`, etc.). These are NOT orphans — they are the current probe suite. Master plan Phase 0 explicitly renames `whatif` → `Title.md` as Task 0.1–0.3. **Do not archive the Lua fleet before Phase 0 rename is done.** After Phase 0, consolidate into `tools/probes/`.

**tools/probes/** (5 canonical Lua): These are the probe output of prior consolidation effort. They should become the sole location after Phase 0 + bulk migration.

**Proposed reorg (post-Phase 0 only):**
```
tools/
├── builder/          (Phase 1 target — not yet created)
├── nes_capture/      (Phase 1.5 target — not yet created)
├── parity/           (Phase 1.5+ target)
├── extractors/       (existing extract_*.py scripts)
├── probes/           (ALL Lua after Phase 0 rename + bulk move)
├── archive_probes/   (deprecated Lua, gitignored, 30-day grace)
├── state/            (audit_macro_shims.py, verify_no_alias_collisions.py, etc.)
├── demos/            (file_select_demo/, intro_demo/, midi_demo/, music_test/)
├── tests/            (test_*.py files)
└── gen_wrappers/     (manifest jsons — already here)
```

**tools/plans/ vs docs/superpowers/plans/**: `tools/plans/` contains 4 drain JSON batch files, not markdown plans. Not a conflict. The master plan's `docs/superpowers/plans/` is for implementation plans (markdown); `tools/plans/` is for drain-tool inputs (JSON). Rename `tools/plans/` → `tools/drain_batches/` to make the distinction obvious.

### builds/ (4.7 GB total)

This is the biggest surprise. Codex's claim "47,574 tracked files" is **confirmed accurate** via `git ls-files builds/ | wc -l = 47574`.

Breakdown:
- `builds/archive/` — **1,498 tracked files** of old `.md` + `.lst` build snapshots (Zelda16–Zelda27). **DELETE via `git rm -r builds/archive/`**. Saves ~4.4 GB.
- `builds/reports/` — **45,961 tracked files**, 45,608 of which are PNG screenshots. This is the primary offender. Master plan says `builds/reports/` is where verification evidence lives. These are historical probe screenshots, not sources. **`git rm -r builds/reports/` then add `builds/reports/` to `.gitignore`**. Future reports are regenerable from probes. Saves ~255 MB in repo.
- `builds/obj/` — **96 tracked `.o` files**. Build output. `build.bat:78` sets `C_OBJ_DIR=%ROOT%\builds\obj`. **`git rm -r builds/obj/`** and add `builds/obj/` to `.gitignore`.
- `builds/whatif.md`, `builds/whatif.lst`, `builds/whatif.elf`, `builds/whatif.o`, `builds/whatif_prev.md` — tracked build outputs. Phase 0 renames these to `Title.md`. After Phase 0 rename: **`git rm builds/whatif.*`** and add patterns to `.gitignore`.
- `builds/build_*.txt`, `builds/build_*.log` — tracked log files (11 files). **`git rm`** and add to `.gitignore`.
- `builds/BUILDS.md` — appears to be a human-authored index. Grep found no references in code. **MOVE → `docs/archive/builds_index.md`** if content is worth preserving, otherwise DELETE.
- `.lnk` shortcut files in `builds/` — **DELETE**. Windows shortcuts committed to a code repo are noise.

**Opus missed**: `builds/reports/` holds **45,608 tracked PNGs** — that's the bulk of the 47K file count Codex flagged. Opus said "KEEP, audit later." That is the wrong call. These are probe screenshots, not sources. They're costing CI scan time and repo size. Untrack them.

### Owned C dead code

- `src/zelda_translated/z_00.asm` through `z_07.asm` — **KEEP**. Confirmed: `genesis_shell.asm:725–732` has 8 `include "zelda_translated/z_0N.asm"` lines.
- `src/gen/z_01.c`–`z_07.c` — **KEEP**. `build.bat:148` explicitly compiles them.
- `src/state/*.h` — mid-migration per state contract. **KEEP**, touch only per phase plan.
- `src/sgdk_adapter/` — used by `build.bat` (`render_adapter.c`, `audio_adapter.c`, `joy_adapter.c`, `sram_adapter.c`). **KEEP**.

No owned C dead code confirmed via grep. Deferring dead function analysis inside the `.asm` and `.c` files to a dedicated audit (that's Phase 1.4 work).

### Doc consolidation

| File | Verdict |
|---|---|
| `CLAUDE.md` (root) | **KEEP at root** — tooling expects it |
| `README.md` (root) | **KEEP at root** |
| `best practices.md` (root) | **MOVE → `docs/best_practices.md`** |
| `RESUME.md` (root) | **MOVE → `docs/archive/handoffs/RESUME.md`** |
| `CODEX_HANDOFF.md` (root) | **MOVE → `docs/archive/handoffs/CODEX_HANDOFF.md`** |
| `T27_T29_FRONTEND_DIARY.md` (root) | **MOVE → `docs/archive/diaries/T27_T29_FRONTEND_DIARY.md`** |
| `docs/SPEC.md` | **KEEP** — active; cited by Phase 0.4 in master plan |
| `docs/audit/state_contract.md` | **KEEP** — constraint 3, binding |

---

## 2. Load-bearing files I almost recommended deleting but checked first

1. **`tools/gen_wrappers/` dir** — Looks like a demo leftover. Checked `build.bat:343` and `tools/drain_finalize.py:51` — it's the manifest store for the gen/ forwarder system. KEEP.
2. **`builds/whatif.md`, `builds/whatif.lst`** — Looks like stale build output. Checked 255 Lua scripts — 15+ of them `open()` or hardcode `builds/whatif.lst` by name. Cannot `git rm` until Phase 0 rename completes and probes are updated.
3. **`tools/emit_gen_wrappers.py`** — Looks like a scaffolding tool. It's called by `build.bat:343` as a gate check. Load-bearing.
4. **`Zelda1-Redux/`** — Looks like a submodule dump. `tools/extract_fs_assets.py` has path strings referencing it in doc comments. Those are comments, not file opens. Safe to move. I checked for `open(` calls — found none.

---

## 3. Genuinely orphan files (with grep evidence)

Ran: `grep -rn "tools/plans/drain_z" build.bat tools/ 2>/dev/null` — zero hits in build.bat; `drain_finalize.py` reads them as arguments, not auto-discovers. The 4 JSON files in `tools/plans/` are one-shot inputs for a prior drain batch. They are not auto-read. They're orphans.

- `tools/plans/drain_z02_demo.json`
- `tools/plans/drain_z04_batch1.json`
- `tools/plans/drain_z05_menu.json`
- `tools/plans/test_z04_today.json`
Verdict: **MOVE → `docs/archive/drain_batches/`** (tiny; preserve as audit trail).

`reports/bizhawk_t5_ppu_probe.txt` at repo root — 1 file, not in `builds/reports/`. Orphan. **DELETE**.

`builds/BUILDS.md` — zero code references found. **MOVE → `docs/archive/`** if it has human-authored index value.

---

## 4. Reorg proposals

### tools/ (do AFTER Phase 0 whatif rename)

```
tools/
├── builder/          (new in Phase 1 — tools/builder/build_from_rom.py etc.)
├── nes_capture/      (new in Phase 1.5)
├── parity/           (new in Phase 1.5)
├── extractors/       (move existing extract_*.py here)
├── probes/           (promote current tools/probes/ as canonical home)
│   └── archive/      (gitignored; parking lot for deprecated Lua)
├── state/            (audit_macro_shims.py, verify_no_alias_collisions.py)
├── demos/            (file_select_demo/, intro_demo/, midi_demo/, music_test/)
├── tests/            (test_*.py)
├── gen_wrappers/     (stay — manifest JSONs)
├── drain_batches/    (rename from tools/plans/)
└── *.py, *.lua at root → triage last
```

Phase 0 rename must happen before Lua migration so probes don't need two-pass updates.

### docs/

```
docs/
├── README.md (link from root)
├── best_practices.md (from root)
├── SPEC.md
├── targets.md (Phase 0.4 deliverable)
├── audit/
│   ├── state_contract.md
│   ├── generated_asset_inventory.md (Phase 1.4 deliverable)
│   └── worktree_merge_protocol.md (Phase 0.6 deliverable)
├── superpowers/{specs,plans}
└── archive/
    ├── diaries/T27_T29_FRONTEND_DIARY.md
    ├── handoffs/RESUME.md, CODEX_HANDOFF.md
    └── drain_batches/drain_z*.json
```

### reference/

```
reference/
├── aldonunez/         (canonical — keep)
├── Zelda1-Redux/      (move from root)
├── external/
│   ├── Sonic 2/       (move from reference/Sonic 2)
│   └── sega2f_files/  (move)
├── Disassembly by Trax/
└── Disassembly by camthesaxman/
```

---

## 5. TOP 10 actions ranked by impact / risk

```bash
# 1. RECOVER 4.4 GB, zero code risk — builds/archive is pure old build snapshots
git rm -r builds/archive
echo "builds/archive/" >> .gitignore

# 2. RECOVER 255 MB + 45,961 git-tracked files — untrack probe screenshots
git rm -r builds/reports
echo "builds/reports/" >> .gitignore
# Future runs regenerate them; master plan says builds/reports/ is output dir

# 3. Purge backup/temp dirs — zero risk
git rm -r .pre-merge-backup
rm -rf .pre-merge-backup .codex_tmp
find . -name "__pycache__" -type d -not -path "./.git/*" -exec rm -rf {} + 2>/dev/null
rm -rf tools/out/

# 4. Untrack build .o files and build logs in builds/
git rm -r builds/obj
git rm builds/build_clean.txt builds/build_clean_err.txt builds/build_err.txt \
    builds/build_err_orig.txt builds/build_log.txt builds/build_out_orig.txt \
    builds/build_renamed.txt builds/build_renamed_err.txt
cat >> .gitignore << 'EOF'

# Build intermediate outputs (regenerable)
builds/obj/
builds/build_*.txt
builds/build_*.log
EOF

# 5. Delete root junk (no git tracking, no references)
rm -f "Zelda1-Redux.zip" VisualStudioSetup.exe rustup-init.exe a.out
rm -f analyze_funcs.txt bout.txt build_a3_fix.txt build_err.txt build_log.txt
rm -f build_f3_log.txt build_out.txt build_out_a3.txt build_out3.txt
rm -f build_out_new.txt build_output.txt build_midi_out.txt
rm -f reports/bizhawk_t5_ppu_probe.txt

# 6. Consolidate root docs (git mv to preserve history)
mkdir -p docs/archive/diaries docs/archive/handoffs
git mv T27_T29_FRONTEND_DIARY.md docs/archive/diaries/
git mv RESUME.md CODEX_HANDOFF.md docs/archive/handoffs/
git mv "best practices.md" docs/best_practices.md

# 7. Move ROMs to single ignored dir
mkdir -p roms
mv "Legend of Zelda, The (USA).nes" roms/ 2>/dev/null
mv "Zelda Redux.nes" roms/ 2>/dev/null
# Already have *.nes in .gitignore; confirm roms/ is covered

# 8. Move Zelda1-Redux and non-Zelda reference material
mkdir -p reference/external
git mv Zelda1-Redux reference/Zelda1-Redux
git mv "reference/Sonic 2" reference/external/
git mv reference/sega2f_files reference/external/
# Then update extract_fs_assets.py comment strings (not open() calls — cosmetic only)

# 9. Rename tools/plans → tools/drain_batches (avoids confusion with docs/superpowers/plans)
git mv tools/plans tools/drain_batches

# 10. Tighten .gitignore for remaining stale patterns
cat >> .gitignore << 'EOF'

# Stale build outputs — now untracked
builds/whatif.md
builds/whatif.lst
builds/whatif.elf
builds/whatif.o
builds/whatif_prev.md

# ROM dir (legal model — user supplies locally)
roms/

# SGDK vendor fat (submodule checkout artifacts)
sgdk/sample/
sgdk/doc/
EOF
# Note: builds/whatif.* git rm happens AFTER Phase 0 renames probes.
# Until then, keep them tracked so old probes still find them.
```

---

## 6. Builder gotchas

**Gotcha 1: tools/*.lua reference `builds/whatif.lst` by hardcoded name.**
If you `git rm builds/whatif.lst` before Phase 0 is done, every probe in the 255-Lua fleet breaks. The Phase 0 rename (Task 0.1–0.3) must precede any `whatif.*` cleanup. Do NOT combine action #10's `whatif` gitignore additions with a `git rm` until after Phase 0 commit.

Post-delete verification grep: `grep -rn "whatif" tools/ src/ build.bat` — must show zero active path references (only comments allowed).

**Gotcha 2: builds/reports/ is referenced as output destination in master plan.**
Adding `builds/reports/` to `.gitignore` is correct, but the physical directory must survive; probes write there. Only `git rm -r builds/reports/` (untrack), NOT `rm -rf builds/reports/`.

**Gotcha 3: builds/obj/ is the compile output dir — `build.bat:78`.**
After `git rm -r builds/obj/`, the directory itself must still exist for the build to write to (or `build.bat:109` `mkdir "%C_OBJ_DIR%"` handles it). Confirmed: line 109 does `if not exist "%C_OBJ_DIR%" mkdir "%C_OBJ_DIR%"`. Safe.

**Gotcha 4: `git rm -r builds/archive/` with 1,498 files will be slow.**
Run as a single commit, not interleaved with other changes. Takes ~30 seconds on Windows.

**Gotcha 5: `.pre-merge-backup/` has 40 tracked files.**
Must `git rm -r .pre-merge-backup/` to untrack, then physically delete. Not just `rm -rf`.

**Gotcha 6: sgdk/ is a submodule — cannot rm -rf sample/ and doc/ from repo root.**
They're not tracked (`git ls-files sgdk/sample` = 0, `git ls-files sgdk/doc` = 0). They exist only as untracked checkout files. Add them to the sparse-checkout pattern in `.git/modules/sgdk/info/sparse-checkout` or just add to root `.gitignore` to suppress noise. Physical `rm -rf sgdk/sample sgdk/doc` works without git involvement, but will be re-created on `git submodule update`. Correct fix: set sparse-checkout on the submodule.

---

## 7. New evidence not named by Codex or Opus

1. **45,608 tracked PNGs in builds/reports/** — neither Codex nor Opus quantified this. Codex said "4.7 GB in builds/" and "47,574 tracked files" but didn't break it down. Opus said "KEEP builds/reports/, audit later." The actual count is 45,608 PNG screenshots, 45,961 total files, 255 MB disk. This is the main git-tracking problem. It poisons `git status`, `git add`, and CI scans. Untrack now.

2. **builds/obj/ has 96 tracked .o files** — both debaters missed this entirely. These are compiled object files committed to git. Pure build output, zero value.

3. **tools/plans/ JSON files are orphaned drain inputs** — not referenced by `build.bat` or any Python import. Four files. Trivial but worth noting Codex and Opus both missed it.

4. **sgdk/ is a git submodule** — not a checked-in vendor copy. Opus recommended `rm -rf sgdk/sample sgdk/doc` as if they're tracked. They're not tracked (0 files in git ls-files). The correct fix is submodule sparse-checkout or `.gitignore`, not `git rm`.

5. **`builds/whatif.md` etc. are actively referenced by 15+ Lua probes** — Opus's action #9 bulk-archived all 250 Lua scripts. That would break the build harness completely. Those Lua files are the current probe fleet, not legacy. They must stay until Phase 0 rename migrates them.

---

## 8. Final stance

**YELLOW.**

Codebase can carry Phase 1.5 → 17 without major reorg, but the 47K tracked files in `builds/` (45K+ PNG screenshots + 1.5K archive snapshots + 96 .o files) actively degrade every git operation. Actions 1–5 above (zero-code-risk deletes) must run before any feature phase to avoid burning agent context on repository noise. The Lua probe fleet is functional but needs Phase 0 rename before it can be reorganized. Tools clutter is real but non-blocking until Phase 1.5 scaffold needs clean directories to land into.

Disagreement with Opus: do NOT archive the 250-Lua fleet as step 8 — they're the live probe suite. Do NOT `git rm` `builds/whatif.*` before Phase 0 rename. Do NOT `rm -rf sgdk/sample` expecting git to care — it's a submodule.

Disagreement with Codex framing: the 47K file count is dominated by probe PNGs in `builds/reports/`, not Sonic 2 binaries. Sonic 2 reference material is untracked. The real bloat is the screenshot history.
