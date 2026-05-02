# Round 1 Condensed Summary (for Round 2 cross-critique)

## 🔴 Codex — Stance: YELLOW
**Gaps:** Task 1.10 too weak — Phase 1 only requires "at least one generated asset" so legal builder gate is soft; Task 12.2/12.3 late bulk promotion is integration risk; Task 7.x/8.x probes are coarse — "Probe" undefined for frame timing/RNG/spawn rules/hitboxes/RAM diff.
**Risks:** Legal release blocker — fallback to checked-in derived data hides missing extractors until Phase 17; NES parity drift — enemies/bosses look right in screenshots while mechanics wrong; Phase 12 integration blowup because save/options/audio/state contracts not exercised continuously.
**Adds:** Task 1.10 rewrite (no silent fallback), Task 1.11 strict generated-only gate, Task 2.8 parity oracle schema (frame/input/RNG/room id/Link state/enemy slots/RAM bytes/CRAM/SAT/plane/screenshot hash), Task 7.1 enemy parity matrix before family dispatch, Task 12.0 incremental promotion gate.
**Poor fit:** Phase 13 4-player — push to a separate enhancement branch after Phase 17, start with feasibility spike only.

## 🟡 Gemini — Stance: YELLOW
**Gaps:** Title.md / RoomRom memory schism — no shared `include/state.h` and `include/memory_map.h` so Phase 12 will fail from divergent SRAM layouts; SRAM/state delay to Phase 9 is wrong because NES Zelda is state-driven; passive VRAM no-clobber registry too weak — Genesis 64KB VRAM with 4-player needs hard VRAM Budget Manifest before Phase 7.
**Risks:** "Clean room trap" — implementing by visual reference instead of 1:1 logic port of 6502 → C will produce subtle hitbox/timing drift; integration hell at Phase 12 if both targets don't share `genesis_shell.asm`/IRQ handlers by Phase 3; 4-player performance wall if Phase 6 ignores Genesis sprite limit (80/line, 20/scanline).
**Adds:** Phase 2 `include/vram_map.h` mandatory for parallel agents; move SRAM/save core from Phase 9 to Phase 3; new Phase 0.5 6502-to-C behavior map at `docs/logic/`; Phase 7/8 close gate adds `clobber_check` for VRAM/CRAM budget; move Phase 15a inline optimization into Phase 6 with per-subsystem cycle budgets.
**Poor fit:** Phase 15b post-quest holistic profiling — LLMs struggle. Better: per-subsystem `PROBE_CYCLE_LIMIT` enforced as part of phase close gate.

## 🟠 Sonnet — Stance: YELLOW (grounded in actual file reads)
**Gaps:** `src/state/link_state.h` lines 9-13 every "field" is `#define LINK_MOVING_DIR RAM(NES_LINK_MOVING_DIR)` — raw NES address macros, NOT typed C structs. `src/state/save_state.h` line 8 `SAVE_BYTE(off)` is raw NES SRAM offset accessor. Phase 12 promotion gate requires "typed src/state/ struct" — it is broken from day 1. Phase 3-5 reach for builder data without hard-gating Phase 1 green. Phase 7/8 has no committed RNG header — five parallel family agents will produce incompatible seed harnesses.
**Risks:** Task 5.2 "expose UW collision grid from renderer" is wrong — NES collision derives from room attribute byte + metatile definition tables, not rendered tile indices; if implemented by tile-reading the Genesis plane Link will walk through walls in 8+ rooms. Phase 12 worktree hand-off has no merge protocol between `roomrom-s1` and `main` — one wrong promotion sequence breaks RoomRom build silently. Phase 10 audio "legal extraction" undefined for NES song data — could block release at Task 17.1.
**Adds:** Task 2.0 audit `src/state/*.h`, classify shim vs typed, commit migration plan to `docs/audit/state_contract.md` BEFORE Task 2.1; Task 1.10 add `REQUIRE_GENERATED_ASSETS=1` build-gate flag (fail not warn); Task 7.1 commit `RoomRom/src/roomrom_rng.h` before family dispatch; replace Task 5.2 first bullet with "extract collision from NES room attribute byte + metatile tables, NOT rendered tiles"; Task 10.1 add `docs/audit/audio_legal_policy.md` defining extracted-as-is vs transformed audio.
**Poor fit:** Phase 14 "input/movie segments or manual checklist per dungeon" — unexecutable for CLIs. Replace with per-dungeon save-state injection harness at `tools/dungeon_harness/`.
**Builder gotcha:** Task 9.2 "unless existing implementation has moved under a documented migration" parenthetical hides undocumented SRAM migrations — committed `docs/audit/sram_map.md` required before Phase 9.

## 🐙 Claude (Opus) — Stance: YELLOW
**Gaps:** No deterministic NES golden-master capture pipeline — every "compare against NES" task reinvents; state struct migration implicit, no per-phase incremental gate so Task 12.3 hits hundreds of call sites; no regression matrix between phases — phase N silently breaks phase M.
**Risks:** FS song bleeds (memory `project_fs_no_song_change`) because Phase 10 wires music without first defining FS-vs-title boundary; CHR expansion in Phase 2.6 strips Z_07 sprite-pal frame-cadence toggles used for intro item flash etc.; promotion reads main worktree but RoomRom dev lives in `FINAL TRY-roomrom-s1` — merge protocol missing.
**Adds:** New Phase 1.5 NES Reference Capture Harness `tools/nes_capture/` producing `build/generated/nes_reference/<rom_hash>/`; Task 0.6 worktree merge protocol; Task 2.6.5 preserve NES frame-cadence palette toggles list + `intro_item_flash_8frame_cycle` probe; Task 9.0 FS audio routing decision (`gamemode == 0x01`) before 10.3; new Workstream F regression matrix `tools/run_regression_matrix.py` required green before phase close.
**Poor fit:** Phase 14 sequential play-through — replace with 18 parallel per-dungeon canonical movie agents.

## Strong convergence (3+ advisors agreed)
- **Phase 12 promotion + state contract is broken NOW** (Sonnet read files, Gemini predicted, Codex/Opus implied).
- **Parity verification is too vague** ("Probe each behavior" / "compare against NES capture") — needs schema (Codex Task 2.8), capture harness (Opus Phase 1.5), audit matrix (Codex Task 7.1).
- **Phase 14 manual playthrough won't work for CLIs** (Sonnet + Opus) — needs save-state harness or per-dungeon parallel agents.
- **Builder gate too soft** (Codex + Sonnet) — `REQUIRE_GENERATED_ASSETS=1` / strict no-fallback build.

## Strong divergence
- **Phase 13 4-player timing**: Codex says push AFTER Phase 17; Gemini says address sprite limits NOW in Phase 6; Opus/Sonnet neutral.
- **Phase 15a inline opts**: Gemini wants moved into Phase 6 with cycle budgets per close gate; others accept current 15a/15b split.
- **Two-ROM split**: Gemini calls it "dangerous bifurcation"; Codex/Sonnet/Opus accept it.
- **6502→C behavior map**: Gemini proposes Phase 0.5 dedicated mapping doc; others assume disasm reading is enough.
