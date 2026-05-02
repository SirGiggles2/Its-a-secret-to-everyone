# Native File Select Rewrite — Resume Prompt

Paste below into fresh session.

---

Resume native File Select rewrite. Caveman mode full. Drive autonomously per long-term-best rule (memory `feedback_long_term_fix.md` + `feedback_work_autonomously.md`). No per-section approval gates beyond standard subagent review.

**Worktree:** `.claude/worktrees/native-file-select` on branch `feat/native-file-select`. **Do all work there**, NOT main repo. Use `cd` only if needed; absolute paths preferred.

**Spec:** `docs/superpowers/specs/2026-04-27-native-file-select-design.md` (commit `1e66f4a1`).
**Plan:** `docs/superpowers/plans/2026-04-27-native-file-select.md` (commit `d29e9cca`, ~50 tasks v1-v6).

## Status

**v1 — Static FS render** = MOSTLY done but visual gate failed initially (rendered ZELDA logo). Root cause: extractor pulled CHR from Mode 0 demo .dat files instead of FS-mode CHR-RAM. Fix landed: live CHR-RAM dump via BizHawk at FS frame 60, used as canonical CHR source.

**Last visual capture** at `tools/file_select_test/cmp/v1_frame_60.png` shows correct FS LAYOUT (border, NAME/LIFE headers, COPY/ERASE rows in right positions) but WRONG COLORS (single-palette-0 render).

**Ground-truth references** committed at `tools/file_select_test/ref/`:
- `real_redux_fs.png` — target render from NES Redux at FS frame
- `fs_chr.bin` — 8KB CHR-RAM (BG at $1000+, sprites at $0000+)
- `fs_nt.bin` — 1KB nametable + attribute table
- `fs_palram.bin` — 32 bytes (open-bus $24 fill — BizHawk doesn't expose palette RAM; use `Zelda1-Redux/src/code/menus/file_select.asm:75-78` hardcoded values)
- `fs_oam.bin` — 256 bytes sprite OAM

## Next: v1.fix2 — Multi-palette BG attribute mapping

**Problem:** `fs_nt.bin` attribute table (last 64 bytes) shows palette-1 cells at certain offsets (e.g. `$3D8` area = COPY/ERASE row). Current `fs_render_static_layout` writes all cells with palette 0. Result: text looks wrong-colored.

**Fix:**
1. Update `tools/extract_fs_assets.py` to ALSO emit `src/gen/fs_static_attr.c` — 64-byte attribute table from `fs_nt.bin[960:1024]`.
2. Update `src/fs_render.c:fs_render_static_layout` — for each cell, compute palette from attr table (NES attr byte covers 4×4 cells; 2 bits per 2×2 quadrant), encode in Genesis cell word as `palette<<13`.
3. Verify Link sprite palette uploads to CRAM slots 1-3 don't conflict with multi-palette BG using slots 0-3.
4. Rebuild proof ROM, recapture, compare to `real_redux_fs.png`.

**Gate:** new `cmp/v1_frame_60.png` matches `ref/real_redux_fs.png` in structure (border + headers + row labels) AND palette/colors approximately match (NES→Genesis 9-bit RGB quantization will differ from byte-exact).

## After v1.fix2

Continue plan tasks v2 → v6. **Bundle aggressively** to save tokens (e.g. v2 6 tasks → 2-3 implementer dispatches; v3 5 tasks → 2 dispatches). For each batched dispatch: implementer → combined spec+code review.

**Standing rules:**
- Long-term-best for any A/B/C tradeoff (memory `feedback_long_term_fix.md`)
- Work autonomously through batches (memory `feedback_work_autonomously.md`)
- Spec/plan reviews skip section-gating
- BizHawk Lua paths use `\\` Windows backslash escapes (memory `feedback_bizhawk_lua_paths.md`)
- BizHawk launch: copy lua + ROM (rename to remove spaces) into BizHawk dir, PowerShell `Start-Process -Wait` with `-WorkingDirectory '.'`
- Hardcode `REPO_ROOT` fallback in Lua probes — `$env:CODEX_BIZHAWK_ROOT` doesn't propagate via PowerShell Start-Process
- Commit each task atomically per `feedback_commit_first.md`

**BizHawk path:** `C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe`
**ROM (NES):** `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\Zelda1-Redux\Zelda Redux.nes` (rename to `ZeldaRedux.nes` when copying to BizHawk dir to avoid space-arg-parse error)

## Tools/build cheatsheet

```bash
# Extract assets
python3 tools/extract_fs_assets.py

# Build proof ROM
tools/file_select_demo/build.bat

# Capture proof ROM frame 60
# (see tools/file_select_test/capture_v1_baseline.lua — output goes to C:\tmp\v1_frame_60.png)

# Re-dump live FS data from NES Redux
# (see tools/file_select_test/dump_fs_full.lua — outputs all 5 ref files)
```

Start: read `tools/extract_fs_assets.py` `tools/file_select_test/ref/fs_nt.bin` (last 64 bytes = attr) and `src/fs_render.c`. Then implement v1.fix2.
