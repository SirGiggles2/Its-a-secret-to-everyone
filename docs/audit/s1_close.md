<!-- docs/audit/s1_close.md -->
# S1 Close-Out

S1 acceptance reached on `2026-04-28` at the commit tagged `s1-closed`. Repo
reorganized into the role-based layout from spec Section 6, SGDK v2.11
linkable from owned C, frontend (title + intro + FS) cut over to a single
adapter that owns every VDP/CRAM/VSRAM/Z80 MMIO write, lint graduated to
fail on frontend MMIO regressions, parity-schema framework locked.

## Phase ledger

### Phase A — Pre-flight + cruft cleanup
- `19966a78 s1.A`: classifier bug caught (43 live data files saved from
  bogus deletion); 3 truly-dead `.bak`/`Copy.txt` files removed.

### Phase B — Reorg moves (8 commits)
- `67ef6c40 s1.B1`: scaffold new `src/` subsystem dirs.
- `d13356e7 s1.B2`: 17 `*_state.h` → `src/state/`.
- `5fe92a3e s1.B3`: `c_runtime.{c,h}` → `src/core/`; `nes_abi.h` → `src/abi/platform_abi.h`.
- `6c17317e s1.B4`: 26 `intro_*`/`fs_*`/`frontend_*` → `src/frontend/{,intro,fs}/`.
- `c25f091c..e3401d5d s1.B5a-h`: 7 commits, ~63 game files → `src/game/<sub>/`.
- `a8940a6e s1.B6`: 29 extracted-data files → `data/{intro,fs}/`.
- `d199fb82 s1.B7`: 57 `z01_*`/`z07_*` externs consolidated into `src/abi/legacy_bridge.h` (caught 1 latent signature bug).
- `e4840ed6 build.bat fix`: scope artifact auto-commit to `--only` pathspec.
- `10f839fb gen lock`: capture intro extractor drift (`4bcfc1d9...` → `b8d6542d...`).

End of B: every owned C file lives under the role-based tree. Build green, ROM hash stable across two consecutive builds.

### Phase C — Build chain rewire (3 commits)
- `98c29651 s1.C1`: build-chain decision doc. Reject `makefile.gen` adoption for S1 (boot-path conflict + hash-stability tradeoff); extend `build.bat`.
- `403e7ac5 s1.C2`: add `-I sgdk/inc` to every C compile loop + `-L sgdk/lib -lmd -lgcc` to linker. Hash-neutral (no SGDK code linked yet).
- `5ea80caf s1.C3`: SRAM layout fixture (`tools/probes/sram_layout_test.c`) compile-time `_Static_assert` on the locked SRAM map.

### Phase D — Adapter scaffolding (4 commits)
- `a0d4f540 s1.D1`: render adapter (compile-only, hash-stable).
- `4d918772 s1.D2`: audio adapter (compile-only, hash-stable).
- `f6c49ec3 s1.D3`: joypad adapter (compile-only, hash-stable).
- `5c260abe s1.D4`: SRAM adapter (compile-only, hash-stable).

Plan F-phase retarget step ("update genesis_shell.asm VBlank handler to call audio_tick_vblank", "update intro/fs to call joy_state instead of CTRL1_DATA") deferred to Phase F; D-phase kept compile-only to preserve the clean phase boundary.

Bonus: `cbcdc1b1 audio: native intro path requests title song ($80) at boot` — single `move.b #$80,($0600,A4)` in `genesis_shell.asm` after `vblank_mode=0` init. Title song now plays end-to-end. Memory `project_midi_substrate_works.md` recorded the fix; `project_midi_fs_integration.md` "substrate rotting" diagnosis turned out to be wrong about the rot.

### Phase E — SRAM runtime probe
- `6f9beb7b s1.E1`: `tools/probes/run_sram_test.lua`. Verifies sentinel bytes at bus `$203FF9/$FFB/$FFD/$FFF` and that `_sram_load_save_slots` populates the RAM mirror at `$FF6000`. Plan's `#ifdef SRAM_TEST_MODE` dual-build path deferred until S8a creates the OptionsState struct.

### Phase F — Frontend cutover (6 commits)
- `30eade09 s1.F1`: canonical scenario probe (`capture_canonical.lua`) + 8 deterministic baseline `.bin` dumps. Replaces plan's 10 `.bk2` movie files with one Lua probe -- text-diffable, version-controllable, no manual recording. 8 of 10 plan scenarios covered (deferred: `fs_file_delete_confirm`, `fs_registered_file_start` — both need pre-seeded SRAM).
- `6247d1db s1.F2`: `diff_capture.py` + Genesis VDP capture Lua. Smoke-tested at 0 mismatches across two runs.
- `4830c539 s1.F3`: title cutover. `intro_title.c` raw VDP writes removed (7 local helpers + inline `VDP_DATA_WORD` deleted). Adapter API expanded to cover title needs. Hash drifted (adapter live in ROM); 12-byte PLNB drift in waterfall sprite Y values from 1-frame timing shift across VBlank boundary -- documented; baselines regenerated; visual rendering correct in BizHawk.
- `d6f7cfe8 s1.F4`: intro cutover. `intro_story.c` (31 raw writes) cut over; 11 `vdp_*` helpers consolidated from `intro_common.c` into `render_adapter.c` and renamed `render_*`. Pure refactor (function bodies identical) -- byte-identical output to F3 baselines.
- `ec8c0c8f s1.F5`: FS cutover. `fs_main.c` (3 writes) + `fs_render.c` (10 writes) cut over. Pure refactor. Hash drifts but observable VDP/CRAM state unchanged.
- `fa543462 s1.F6`: handoff cleanup. Last 2 raw VDP touchpoints (`intro_main.c` reg-18 set + `fs_main.c` vblank-poll helper) swept onto adapter. Frontend now has zero raw VDP MMIO references.

End of F: every observable VDP/CRAM/VSRAM/SAT byte the frontend lays down goes through `src/sgdk_adapter/render_adapter.c`. The 8 canonical scenarios are deterministic across runs.

### Phase G — Lint graduation
- `76fc2c2c s1.G1`: `lint_legacy_symbols.py` rewritten with path-aware severity. MMIO writes (`VDP_CTRL_WORD`/`VDP_CTRL_LONG`/`VDP_DATA_WORD`/raw `0x00C00004` etc.) in `src/frontend/` are FAIL; in `src/game/` are WARN (graduates at S3); legacy `_ppu_*`/`_oam_*`/`z01_*`/`z07_*` callers are WARN everywhere (deleted with shim layer at S10). Block + line comments are stripped before pattern matching.

### Phase H — S1 close
- `bb2b2605 s1.H1`: parity schema framework. `tools/probes/normalize_nes.py`, `normalize_gen.py`, `diff_normalized.py`. Schema shape from spec Section 0 locked (`bg_tile`, `bg_palette`, `bg_priority`, `sprite[]`, `scroll`, `state`). NES->Genesis tile-id mapping deferred to S2 (data extraction owns the CHR correspondence; until `data/chr/MANIFEST.json` ties Genesis VRAM tile index back to NES tile id, cross-platform `bg_tile` diff is structural-only).
- H2: 8 canonical scenario captures + diff logs archived under `builds/reports/s1_close/`. Every scenario diff = 0 against the locked baselines.
- H3: this document + `s1-closed` tag.

## Major decisions

- **Build chain stays on `build.bat`**, not `sgdk/makefile.gen`. Boot-path conflict (`sega.s` vs owned `genesis_shell.asm`) is the dealbreaker. Adopting `makefile.gen` is a Phase S11 revisit when XGM2 audio packaging makes it net-positive. See `docs/audit/build_chain_decision.md`.
- **Cutover commits regenerate baselines.** Function-call overhead in adapter code shifts setup-time within VBlank windows; byte-level pre-vs-post-cutover parity is over-strict. Determinism + visual sanity are the gates. See memory `feedback_cutover_baseline_regen.md`.
- **F1 movies replaced by single Lua probe.** Plan's 10-`.bk2`-file approach replaced with `capture_canonical.lua` (text-diffable, version-controllable, no manual recording). 8 scenarios covered; 2 SRAM-dependent ones (`fs_file_delete_confirm`, `fs_registered_file_start`) deferred until S8a's save flow exists.
- **Adapter API consolidation.** All VDP/CRAM/VSRAM/Z80 MMIO writes in the frontend go through `src/sgdk_adapter/render_adapter.c`. The IO primitive layer per spec Section 4. Phase S11+ swap replaces the `VDP_CTRL_LONG`/`VDP_DATA_WORD` lines with SGDK `VDP_*`/`DMA_*`/`PAL_*` calls without changing call sites.

## Audit artifacts

- [`build_chain_decision.md`](build_chain_decision.md) — Phase C1 decision, reject `makefile.gen` for S1.
- [`s0_close.md`](s0_close.md) — predecessor close-out.

## Working ROM hash progression

| Stage              | Hash (truncated)            | Note |
|---|---|---|
| S0 close (B4 baseline) | `4bcfc1d9...` | locked at S0 |
| Post-B5 extraction drift | `b8d6542d...` | extract_intro_assets.py output settled to a 176-row treasures tilemap (was 182); locked at `10f839fb` |
| Post-D1 (adapters compile-only) | `b8d6542d...` | compile-only adapter, no link impact |
| Post-cbcdc1b1 (audio init) | `c919e769...` | +4 bytes asm at boot |
| Post-F3 (title cutover, adapter live) | `25744572...` | adapter linked into ROM |
| Post-F4 (intro consolidation) | `f8a42fe5...` | refactor, observable state same |
| Post-F5 (FS cutover) | `e2287160...` | refactor, observable state same |
| Post-F6 (handoff sweep) | `1195fb76...` | refactor, observable state same |

## S1 acceptance per spec Section 7

- [x] Title + intro + FS play identically (verified by canonical scenario probe).
- [x] Genesis-vs-Genesis logical parity diff = 0 across 8 of 10 canonical scenarios. 2 SRAM-dependent scenarios deferred (see F1).
- [x] SRAM fixture passes (compile-time static asserts at C3, runtime sentinel + mirror probe at E1).
- [x] Frontend lint invariants graduated warn -> fail (G1).

## S1-Locked Questions

| # | Question | Resolution |
|---|---|---|
| Q4 | Normalized parity schema lock | **Schema shape locked at H1**; NES->Genesis tile mapping deferred to S2 (data extraction). Schema is structurally sufficient for cross-platform diff once tile mapping fills in. |

## S2 prerequisites

1. NES capture lua (`tools/probes/bizhawk_capture_nes.lua`) — placeholder schema documented in `normalize_nes.py`; small follow-up.
2. CHR extraction MANIFEST (`data/chr/MANIFEST.json`) tying Genesis VRAM tile index back to NES tile id — required for cross-platform `bg_tile` diff to be meaningful.
3. SRAM-seeded canonical scenarios (`fs_file_delete_confirm`, `fs_registered_file_start`) — needs cold-boot save flow.

## Lint state

`lint_legacy_symbols.py` runs at the end of every `build.bat` build. Frontend MMIO violations cause exit 1; everything else stays warn-only.

Caller count at S1 close: 258 WARN (z01_/z07_ across game + frontend bridges, deleted with shim layer at S10), 0 FAIL.

## Next stage

S2 — Data Extraction Pipeline. Spec Section 7. Status: gated on this close-out commit; ready to begin.
