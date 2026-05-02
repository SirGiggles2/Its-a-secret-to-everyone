# Claude (Opus) Round 1 Cleanup Analysis

I have direct repo evidence. Where I disagree with Gemini's framing, I cite the file or grep that informs me.

## 1. Root leftovers

| File | Verdict | Reason |
|---|---|---|
| `FIX THIS.avi` (57M) | **MOVE → `docs/bug_reports/`** | Memory rule `feedback_fix_this_avi` says it's the user's live bug capture. KEEP, don't NUKE. Not in git anyway. |
| `SCROLL TIME.avi` (47M) | **MOVE → `docs/bug_reports/`** | Same shape. |
| `Zelda1-Redux.zip` (1.7M) | **DELETE** | Already extracted to `Zelda1-Redux/`. |
| `VisualStudioSetup.exe` (4.2M) | **DELETE** | Installer artifact, not project asset. |
| `rustup-init.exe` (12.2M) | **DELETE** | RTK was installed; installer not needed. |
| `src.zip` (582K) | **DELETE** | Already in `.gitignore`; physically delete. |
| `a.out` (280B) | **DELETE** | C compile dropping. |
| `Zelda - Ocarina of Time - Great Fairy's fountain.mid` | **MOVE → `midi/inputs/`** | MIDI input, not root noise. |
| `Zelda Redux.nes` (128K) | **MOVE → `roms/`** + add to `.gitignore` | NES ROM at root violates legal model. |
| `Legend of Zelda, The (USA).nes` | **MOVE → `roms/`** | Same. ROMs belong in a single ignored dir. |
| `analyze_funcs.txt` | **DELETE** | In `.gitignore` already. |
| `bout.txt`, `build_*.txt` (10+ logs) | **DELETE** all | Stale build logs, gravestones. |
| `T27_T29_FRONTEND_DIARY.md` (129K) | **MOVE → `docs/archive/diaries/`** | Historical, not current architecture. |
| `RESUME.md`, `CODEX_HANDOFF.md` | **MOVE → `docs/archive/handoffs/`** | Snapshot docs, not current. |
| `best practices.md` | **MOVE → `docs/best_practices.md`** | Real authority doc, just root-polluting. |

## 2. Generated data

`data/`, `src/data/`, `RoomRom/data/` — KEEP for now; once strict generated-only build gate (Task 1.11) is on AND extractors green, delete tree per category as Phase 1.10 audit confirms reproducible from ROM. Don't bulk-delete now — half the build will break.

`src/gen/` contains `z_01.c` through `z_07.c` (transpiler outputs). KEEP — actively cited by build. `music_great_fairy.bin` in `src/gen/` is suspicious — likely belongs in `data/audio/` or `midi/out/`.

## 3. Vendor fat

| Path | Verdict | Reason |
|---|---|---|
| `sgdk/sample/` (50M) | **DELETE** | Vendor samples never compiled by build. |
| `sgdk/doc/` (4.2M) | **DELETE** | Online HTML docs available; remove from repo. |
| `sgdk/tools/` (2.9M) | **AUDIT** then trim | Some tools (e.g. `bintos`, `sjasm`) are used by build; check before delete. |
| `Zelda1-Redux/` (82M) | **MOVE → `reference/Zelda1-Redux/`** | Reference material; not root-level. |
| `midi/mid2vgm-beta5/`, `midi/PSG mode/` | **AUDIT** then likely delete | Vendor music tooling; check if MIDI pipeline still uses. |
| `reference/Sonic 2/`, `reference/sega2f_files/` | **MOVE → `reference/external/`** (Gemini agrees) | Inspirational, not authoritative. |
| `reference/Disassembly by Trax/`, `reference/Disassembly by camthesaxman/` | **KEEP under `reference/`** | NES Zelda disasm sources, complement aldonunez. |

## 4. Backup / temp

DELETE all:
- `.pre-merge-backup/` (178K) — git history is the backup.
- `.codex_tmp/` (5 dirs) — Codex CLI scratch.
- `.superpowers/brainstorm/` — superpowers scratch.
- `.claude/worktrees/` — empty / stale.
- `__pycache__/` at every level (root + tools/ + RoomRom/) — `.gitignore` already; physically delete.
- `tools/out/` (53K) — transient.
- `.pytest_cache/` — already ignored.

## 5. Tools clutter

521 scripts at near-root. Hard to know which are canonical vs deprecated probes. Aggressive reorg:

```
tools/
├── builder/        (legal builder pipeline — Task 1 home)
├── nes_capture/    (Phase 1.5 capture harness — new)
├── parity/         (parity oracle schema + diff)
├── extractors/     (CHR, rooms, palettes, items, audio, text, enemies)
├── probes/         (canonical probes only — keep current 5; archive rest)
├── archive_probes/ (deprecated 250+ Lua scripts; rename then delete in 30 days)
├── demos/          (file_select_demo, intro_demo, midi_demo, music_test — keep but co-located)
├── state/          (audit_macro_shims, verify_no_alias_collisions, lint_no_new_macro_state)
├── dungeon_harness/ (Phase 14 harness)
├── tests/          (existing tests)
└── _scratch/       (gitignored; for one-shots)
```

For the 250+ Lua at `tools/*.lua`: bulk move into `tools/archive_probes/` immediately, then triage week-by-week. The ones still referenced by master plan / current probes get promoted back. Net win: `tools/` directory listings stop being unreadable.

## 6. builds/ (4.7G)

Direct evidence:
- `builds/archive/` (4.4G) — contains `Zelda16.1.lst`, `Zelda17.1.lst`, ... `Zelda21.1.lst` — 4.2M `.lst` files for old build snapshots. **DELETE entire `builds/archive/`**. 4.4G recovered.
- `builds/reports/` (255M) — useful but bloated. KEEP, audit later.
- `builds/whatif.md` (16M) — current build output, regenerable. Acceptable.
- `builds/whatif_la.md` (512K) — leftover from `whatif_la` experiment? Check.
- `builds/whatif.lst` (5.1M) — current list, fine.
- `builds/Legend of Zelda, The (USA).nes` (132K) — ROM in builds/?! **DELETE**.

Add `builds/archive/`, `builds/reports/`, `builds/*.elf`, `builds/*.lst`, `builds/*.md` to `.gitignore`. Builds are pure outputs.

## 7. Owned C dead code

- `src/zelda_translated/` — `z_00.asm` 57K, `z_01.asm` 96K, `z_02.asm` 169K, `z_03.asm` 67K. Comment in `build.bat:59` says "Transpiler — generate src\zelda_translated\*.asm". **KEEP** — this is the transpiled NES core, load-bearing. State contract calls these "transpiled code" that still uses `nes_ram[]`.
- `src/gen/` — `z_01.c`...`z_07.c` are generated by transpiler. KEEP.
- `src/state/*.h` — all macro shims today (Sonnet's debate-001 evidence). State contract decides typed structs replace these per phase. NOT dead, but mid-migration.
- `src/sgdk_adapter/` — thin Genesis helpers. KEEP.

Honest dead-code suspects need grep audit (deferred to Sonnet's file-grounded round).

## 8. Doc consolidation

```
docs/
├── README.md (currently at root → MOVE here as authority entry point)
├── best_practices.md (currently root)
├── targets.md (Phase 0.4)
├── audit/ (state_contract.md, generated_asset_inventory.md, sram_map.md, etc.)
├── superpowers/{specs,plans} (master plan + roadmap)
├── archive/
│   ├── diaries/ (T27_T29_FRONTEND_DIARY.md)
│   ├── handoffs/ (RESUME.md, CODEX_HANDOFF.md)
│   └── snapshots/ (other historical)
├── bug_reports/ (FIX THIS.avi, SCROLL TIME.avi)
└── assets/
```

Keep `CLAUDE.md` and `README.md` at root (tooling expects them).

## 9. TOP 10 actions ranked impact ÷ risk

```bash
# 1. RECOVER 4.4 GB instantly — zero risk
rm -rf builds/archive

# 2. Purge backup/temp — zero risk
rm -rf .pre-merge-backup .codex_tmp .superpowers/brainstorm .pytest_cache
find . -name "__pycache__" -type d -prune -exec rm -rf {} +

# 3. Drop SGDK vendor fat — zero risk (sample/doc never built)
rm -rf sgdk/sample sgdk/doc

# 4. Nuke stale build logs at root — zero risk
rm -f bout.txt build_*.txt build_*.bat.bak analyze_funcs.txt a.out src.zip Zelda1-Redux.zip VisualStudioSetup.exe rustup-init.exe

# 5. Consolidate docs (move, not delete)
mkdir -p docs/archive/{diaries,handoffs} docs/bug_reports
git mv T27_T29_FRONTEND_DIARY.md docs/archive/diaries/
git mv RESUME.md CODEX_HANDOFF.md docs/archive/handoffs/
git mv "best practices.md" docs/best_practices.md
mv "FIX THIS.avi" "SCROLL TIME.avi" docs/bug_reports/

# 6. Move ROMs into single ignored dir
mkdir -p roms && echo "roms/" >> .gitignore
mv "Legend of Zelda, The (USA).nes" "Zelda Redux.nes" roms/
mv "builds/Legend of Zelda, The (USA).nes" roms/ 2>/dev/null

# 7. Move Zelda1-Redux + non-Zelda reference under reference/
mkdir -p reference/external
git mv Zelda1-Redux reference/Zelda1-Redux
git mv "reference/Sonic 2" reference/external/
git mv reference/sega2f_files reference/external/

# 8. Tools archive sweep — move 250+ root Lua to archive (review later)
mkdir -p tools/archive_probes
git mv tools/*.lua tools/archive_probes/ 2>/dev/null
# Then re-promote canonical ones referenced by current probes back to tools/probes/

# 9. Tighten .gitignore for build outputs
cat >> .gitignore <<'EOF'

# Builds — pure outputs, regenerable
builds/*.md
builds/*.lst
builds/*.elf
builds/*.o
builds/obj/
builds/archive/
builds/reports/
builds/vgmrom/

# Tools transient
tools/out/
tools/archive_probes/
EOF
git rm --cached -r builds/ 2>/dev/null

# 10. Move root MIDI input + clean leftover gen artifact
mkdir -p midi/inputs
mv "Zelda - Ocarina of Time - Great Fairy's fountain.mid" midi/inputs/
mv src/gen/music_great_fairy.bin data/audio/ 2>/dev/null || rm src/gen/music_great_fairy.bin
```

## 10. Final stance

**YELLOW.** Codebase IS shippable to Phase 1.5+ but the noise floor will burn agent context every session. Items 1–4 (zero-risk deletes) recover ~5 GB and should run today. Items 5–8 (moves with `git mv`) need a single sweep + grep verification. Item 9 (`.gitignore` tightening) prevents recurrence. Items 6–7 + tools archive (item 8) are the ones that need cross-target test — RoomRom worktree must rebuild after.

Disagreement with Gemini: do NOT delete `.avi` files (memory rule). Do NOT delete `src/zelda_translated/` (load-bearing). Do NOT `rm -rf .superpowers` whole — only `brainstorm/` subdir is scratch.
