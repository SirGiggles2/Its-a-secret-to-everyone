# SGDK Integration Audit (locked at S0)

**Audit date:** 2026-04-27
**Auditor:** Task 3.5 (s0-inventory)
**Spec reference:** Section 12 Q8, Q9, Q10

---

## Install state

- **SGDK install root:** `build/toolchain/sgdk_bin/` — **compiler + tools only; SGDK library missing**
- **SGDK version detected on disk:** `n/a` — no library headers (`inc/`, `libmd.a`, `makefile.gen`, `sample/`) present anywhere on disk. The compiler distribution contains ResComp 3.95 (March 2025) and XGM2 tools, which correlates with SGDK 2.x but the version cannot be read from `sgdk/inc/genesis.h` because that file does not exist.
- **Compiler comes from this SGDK distribution:** Yes — `build/toolchain/sgdk_bin/bin/gcc.exe` is GCC 13.2.0 (crosstool-NG, target `m68k-elf`), the same compiler bundled with SGDK 2.x. File date: 2024-05-21. `build/toolchain/sgdk_bin/bin/` also contains `rescomp.jar`, `xgm2tool.jar`, `lz4w.jar`, `make.exe`, and `bintos.exe`, which are all SGDK 2.x build-tool artifacts.

### Confirmed present in sgdk_bin/bin/

| Tool | Version string |
|---|---|
| `gcc.exe` | GCC 13.2.0 (crosstool-NG UNKNOWN), target m68k-elf |
| `rescomp.jar` | ResComp 3.95 (March 2025) |
| `xgm2tool.jar` | XGM2 Driver (no discrete version in banner) |
| `lz4w.jar` | LZ4W packer 1.43 |
| `as.exe`, `ld.exe`, `ar.exe`, `objcopy.exe`, `objdump.exe` | GNU Binutils 2.40 |

### What is absent

`inc/genesis.h`, `lib/libmd.a`, `res/`, `sample/`, `makefile.gen`, `boot/`, `src/` (SGDK C runtime source). The library/runtime half of SGDK has not been downloaded or committed. The project currently uses only the compiler from this distribution and links its own hand-written runtime.

---

## API surface

SGDK library headers are not on disk. Each row is marked **deferred — verify against pinned upstream commit during S1 vendoring** per plan Step 2 instructions. The pinned commit to verify against is given in the "Pinned version" section below.

| Module | Header | Critical functions we depend on | Status |
|---|---|---|---|
| System lifecycle | `sys.h` | `SYS_doVBlankProcess`, `SYS_setVIntCallback`, `SYS_disableInts`, `SYS_enableInts` | deferred — verify at S1 vendoring |
| VDP | `vdp.h`, `vdp_tile.h`, `vdp_pal.h`, `vdp_bg.h` | `VDP_init`, `VDP_setEnable`, `VDP_setReg`, `VDP_setHorizontalScroll`, `VDP_setVerticalScroll`, `VDP_setTileMapXY`, `VDP_setTileMapDataRect`, `VDP_loadTileData` | deferred — verify at S1 vendoring |
| DMA | `dma.h` | `DMA_doDma`, `DMA_queue`, `DMA_flushQueue` | deferred — verify at S1 vendoring |
| Sprites | `sprite_eng.h` | `SPR_init`, `SPR_addSprite`, `SPR_setPosition`, `SPR_setFrame`, `SPR_releaseSprite`, `SPR_update` | deferred — verify at S1 vendoring |
| Joypad | `joy.h` | `JOY_init`, `JOY_readJoypad`, `JOY_setEventHandler` | deferred — verify at S1 vendoring |
| Palette | `pal.h` | `PAL_setColor`, `PAL_setColors`, `PAL_setPalette`, `PAL_fadeTo` | deferred — verify at S1 vendoring |
| SRAM | `sram.h` | `SRAM_enable`, `SRAM_disable`, `SRAM_readByte`, `SRAM_writeByte` | deferred — verify at S1 vendoring |
| Audio (XGM2) | `xgm2.h` | `XGM2_play`, `XGM2_stop`, `XGM2_playPCMEx`, `XGM2_isPlaying` | deferred — verify at S1 vendoring |

**Note for S1:** SGDK 2.x is known to have renamed or reorganized some APIs relative to 1.x. The audit notes two likely surface changes that must be confirmed when the library is on disk:

- DMA: SGDK 2.x exposes a queue-based DMA API (`DMA_queue` / `DMA_flushQueue`). Confirm actual symbol names against `inc/dma.h` — the queue variant may be spelled differently.
- VDP tilemap: `VDP_setTileMapDataRect` may not exist under that exact name in all 2.x releases; confirm against `inc/vdp_bg.h`.

---

## Build smoke test

- **Sample built:** none
- **Result:** deferred to S1 vendoring — SGDK library (`libmd.a`, `inc/`, `makefile.gen`) not present on disk. Cannot build an SGDK sample without the library. Once the submodule is initialized at S1 start, the first action is to build `sample/sprite/` using the existing `make.exe` and confirm the produced `.bin` boots in BizHawk 2.11 Genesis core.

---

## Sprite engine pressure

**Paper analysis (S0):** SGDK 2.x `sprite_eng` allocates up to 80 hardware sprite slots per frame (the Genesis hardware maximum is 80 sprites in H40, 64 in H32). The engine packs multi-tile sprite definitions into contiguous hardware slots at update time via `SPR_update()`, which is called once per VBlank.

**Zelda worst-case estimate:**

| Enemy / entity | Hardware sprites consumed (8x16 each) |
|---|---|
| Aquamentus head (3x3 tiles) | up to 6 hardware sprites |
| Aquamentus body segments x3 | up to 9 hardware sprites |
| Aquamentus fireballs x3 | up to 3 hardware sprites |
| Link (2x3 tiles) | up to 4 hardware sprites |
| Link sword | 1–2 hardware sprites |
| Other room enemies x3 | up to 9 hardware sprites |
| HUD overlay sprites (hearts, etc.) | up to 6 hardware sprites |
| **Total peak estimate** | **~40 hardware sprites** |

Gleeok (4-headed variant) is potentially higher: 4 necks + 4 heads + body + projectiles can push past 50 hardware sprites under worst conditions.

**Assessment:** 50–55 hardware sprites peak is well within SGDK's 80-slot ceiling. No structural pressure risk. The sprite engine's per-frame 68000 cost (`SPR_update`) is the real concern at Stage 6 (live test), not the slot count.

**Red flags / open items for S6:**
1. SGDK's sprite engine sorts by priority and packs slots; verify that the existing NES priority rules (behind-BG sprites for Aquamentus underside) map cleanly to SGDK's `SPRITE_ATTR` priority bit.
2. Confirm SGDK's 8x16 sprite mode is compatible with the Genesis sprite hardware in H32 mode (the project currently renders in H32).
3. A live timing test of `SPR_update` with 50+ active sprites is a Stage 6 deliverable, not S0.

---

## A4 register convention

- **Result:** deferred — needs SGDK library source on disk to verify `boot/sega.s` (or equivalent SGDK startup assembly).

**Evidence gathered at S0:**

- `build.bat` compiles all C files with `-ffixed-a4`. This flag tells GCC that A4 is **completely off-limits** — the compiler will not touch it, not even as a callee-saved register. It is stronger than `-fcall-saved-a4`.
- The existing hand-written runtime (`genesis_shell.asm`, `frontend_runtime.c`) uses A4 as the NES_RAM base pointer per the ABI contract.
- SGDK's conventional A-register reservation is **A5 = VDP base address** (`$00C00000`), set once in startup and never disturbed. SGDK does **not** conventionally reserve A4 for its own use; A4 is available to user code in the standard SGDK calling convention.
- The above is consistent with SGDK 1.x and 2.x public documentation and source history as of the knowledge cutoff. However this must be confirmed against `boot/sega.s` in the pinned SGDK release before S1 integration, because a silent change in startup code would break the NES_RAM base pointer convention silently.

**Mitigation if conflict is found at S1:** Drop `-ffixed-a4`, move the NES_RAM base pointer to A3 or keep it as a normal global (`uint8_t *NES_RAM`), and update `genesis_shell.asm` and all inline-asm stubs accordingly. This is a mechanical change with no semantic effect on the game logic; it should be done before any C↔SGDK calls are introduced if A4 is in conflict.

---

## Vendoring mechanism

- **Decision:** git submodule
- **Rationale:** A git submodule pinned to the SGDK release tag (`v2.00`) gives fresh-clone reproducibility with a single `git submodule update --init` step, keeps the FINAL TRY repository small (~600 KB vs ~10 MB for an in-tree copy), and makes intentional upgrades explicit (change the submodule SHA, re-run `git submodule update`, rebuild and re-run all parity probes). A setup-script approach was rejected because it introduces a network dependency at build time, which conflicts with the project's reproducibility rule (spec Section 0). An in-tree copy was rejected because SGDK's `sample/` and `doc/` directories bloat the repo for no benefit; the submodule approach provides the same determinism with a single pointer commit. One-developer workflow on Windows: `git submodule update --init` is a one-time step that Git for Windows handles identically to Linux. The submodule will be registered as `sgdk/` at the repo root, matching SGDK's own expected directory name for its makefile chain.

---

## Pinned version

- **SGDK release tag:** `v2.00`
- **GitHub URL:** `https://github.com/Stephane-D/SGDK`
- **Basis for this pin:** ResComp 3.95 (March 2025) bundled in `sgdk_bin/bin/` corresponds to the SGDK 2.x compiler distribution extracted from the v2.00 release. Training-time knowledge confirms v2.00 is the latest stable release tag as of early 2026. This pin is **to-be-confirmed at S1 vendoring**: run `git tag -l 'v*' | sort -V | tail -5` against the cloned SGDK repo and adopt the highest stable tag if a newer one exists.
- **Pinned at:** 2026-04-27 UTC

---

## Open issues for S1

1. **Library must be cloned before any S1 work begins.** Run: `git submodule add -b v2.00 https://github.com/Stephane-D/SGDK sgdk` from the repo root, then `git submodule update --init`. Without this, neither the API surface audit nor the build smoke test can proceed.

2. **Confirm pin tag at clone time.** The `v2.00` pin is based on training-time knowledge. Confirm it is the highest stable tag and bump if warranted. Record the confirmed tag SHA in this document and in the spec Section 0 reference block.

3. **API surface audit.** Walk the table in the "API surface" section above against the cloned `sgdk/inc/` and record `present` / `present-with-different-name` / `missing` per row. Pay particular attention to DMA queue API and VDP tilemap rect API name differences noted above.

4. **Build smoke test.** Build `sgdk/sample/sprite/` using `sgdk/bin/make.exe` with the existing `m68k-elf-gcc 13.2.0` and confirm the produced `.bin` boots in BizHawk 2.11. Record any `-ffixed-a4` incompatibility that appears during SGDK library compilation.

5. **A4 / startup convention verification.** Read `sgdk/boot/sega.s` (or equivalent) and confirm A4 is not written during startup. Record `safe` or `conflict` and apply mitigation if needed before any C↔SGDK boundary is introduced.

6. **ResComp / makefile.gen integration.** The existing `build.bat` invokes GCC directly. SGDK normally uses `makefile.gen` (GNU make). A decision on whether to adopt `makefile.gen` or continue with `build.bat` + manual GCC flags is a Stage 1 build-pipeline item, not an S0 item. However the submodule adds `make.exe` to PATH via `sgdk_bin/bin/`, so this is already available.

7. **XGM2 / audio integration.** The existing audio subsystem (native XGM2 driver calls, `audio_driver` shim) may need to be reconciled with SGDK's `XGM2_play` / `XGM2_stop` wrappers. This is a Stage 11 item per the spec. Do not change audio plumbing during S1 frontend cutover.
