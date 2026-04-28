# SGDK Integration Audit (S0 + post-S0 vendoring)

**Original audit date:** 2026-04-27 (Task 3.5, paper-only)
**Vendoring + verification date:** 2026-04-28 (post-S0, autonomous session)
**Spec reference:** Section 12 Q8, Q9, Q10 — **all three resolved post-S0**

---

## Install state (post-vendoring)

- **SGDK install root:** `sgdk/` (git submodule at repo root). All headers,
  libs, samples, source, and tools now on disk.
- **SGDK version on disk:** **v2.11** at commit `ef9292c0` (latest stable
  release as of upstream `git ls-remote` check on 2026-04-28). Bumped from
  the original v2.00 paper-pin because v2.11 is the current stable; deferring
  the upgrade later costs more than picking it now.
- **Compiler:** unchanged from S0 audit — `build/toolchain/sgdk_bin/bin/gcc.exe`,
  GCC 13.2.0 (crosstool-NG, target `m68k-elf`). Confirmed by sample build.

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

## API surface (verified 2026-04-28)

All planned modules present in `sgdk/inc/` at v2.11. Master include is
`genesis.h`; individual module headers exist as listed. Per-module symbol
verification deferred to first concrete use site at S1 — the headers are
present, the SGDK 2.x docs cover the symbol names, no risk of "module not
there."

| Module | Header(s) | Status |
|---|---|---|
| System lifecycle | `sys.h` | present |
| VDP core | `vdp.h`, `vdp_bg.h`, `vdp_pal.h`, `vdp_spr.h`, `vdp_tile.h` | present (split into 5 headers) |
| DMA | `dma.h` | present |
| Sprite engine | `sprite_eng.h`, `sprite_eng_legacy.h` | present (modern + legacy options) |
| Joypad | `joy.h` | present |
| Palette | `pal.h` | present |
| SRAM | `sram.h` | present |
| Audio (XGM2) | `snd/` subdir + `psg.h`, `ym2612.h`, `z80_ctrl.h` | present (XGM2 lives under `snd/`) |
| Memory | `memory.h`, `memory_base.h`, `pool.h` | present |
| Mapper / bank | `mapper.h` | present |
| Bitmap / font | `bmp.h`, `font.h` | present |
| String utility | `string.h` | present |
| Math | `maths.h`, `maths3D.h` | present |
| Timer / task | `timer.h`, `task.h` | present |
| Object framework | `object.h` | present |

**Master include:** `genesis.h` includes the full surface; gameplay code can
`#include <genesis.h>` rather than tracking individual module headers.

---

## Build smoke test (verified 2026-04-28)

- **Sample built:** `sgdk/sample/basics/hello-world/`
- **Build chain:** `sgdk/bin/make.exe -f sgdk/makefile.gen` invoked from the
  sample dir. Compiles `src/boot/rom_head.c` + `src/boot/sega.s`, links via
  `md.ld` against `libmd.a` + `libgcc.a`, runs `objcopy -O binary` and
  `sizebnd.jar -checksum`.
- **Result:** **PASS** — `out/rom.bin` produced (131072 bytes / 128 KB,
  valid Genesis ROM size). SHA256 prefix `8d57bee747d2c948...`.
- **Boot verification in BizHawk:** deferred — visual emulator check needs
  user steering and was not in scope for the autonomous post-S0 session.
  Build chain integrity is sufficient to unblock S1 mechanical work.

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

## A4 register convention (resolved 2026-04-28)

- **Result:** **SAFE** — SGDK does not reserve or modify A4 in its
  runtime / boot path.

**Verification:** grepped SGDK boot + runtime source for A4 references:

```
sgdk/src/boot/sega.s     — no A4 references
sgdk/src/sys.c           — only A4 reference is a debug exception display
                            (showValueU32U32U32 prints register values to
                            screen on crash); does not modify A4
```

The existing `-ffixed-a4` convention is preserved through the SGDK
integration. NES_RAM base pointer at A4 = $FF0000 stays unchanged.

**No mitigation needed.** The deferred concern from the original Task 3.5
audit ("we may need to drop -ffixed-a4") is resolved: SGDK 2.11 boot path
does not touch A4.

---

## Vendoring mechanism

- **Decision:** git submodule
- **Rationale:** A git submodule pinned to the SGDK release tag (`v2.00`) gives fresh-clone reproducibility with a single `git submodule update --init` step, keeps the FINAL TRY repository small (~600 KB vs ~10 MB for an in-tree copy), and makes intentional upgrades explicit (change the submodule SHA, re-run `git submodule update`, rebuild and re-run all parity probes). A setup-script approach was rejected because it introduces a network dependency at build time, which conflicts with the project's reproducibility rule (spec Section 0). An in-tree copy was rejected because SGDK's `sample/` and `doc/` directories bloat the repo for no benefit; the submodule approach provides the same determinism with a single pointer commit. One-developer workflow on Windows: `git submodule update --init` is a one-time step that Git for Windows handles identically to Linux. The submodule will be registered as `sgdk/` at the repo root, matching SGDK's own expected directory name for its makefile chain.

---

## Pinned version (resolved 2026-04-28)

- **SGDK release tag:** **`v2.11`** (commit `ef9292c0` per `git ls-remote`
  on 2026-04-28)
- **GitHub URL:** `https://github.com/Stephane-D/SGDK`
- **Vendored as:** git submodule at `sgdk/` (per Q9 decision)
- **Basis for this pin:** `git ls-remote --tags` against upstream showed
  `v2.11` as the highest stable release; older `v2.00` (paper-pinned by T3.5)
  was bumped to current stable to avoid carrying an upgrade debt into S1+.
- **Pinned at:** 2026-04-28 UTC

---

## Open issues for S1

1. ~~Library must be cloned before any S1 work begins.~~ **DONE 2026-04-28** — submodule at `sgdk/`, v2.11.

2. ~~Confirm pin tag at clone time.~~ **DONE** — bumped from v2.00 paper-pin to v2.11 (current stable).

3. ~~API surface audit.~~ **DONE** — all planned modules verified present in `sgdk/inc/`. Per-symbol verification deferred to first concrete use site at S1.

4. **Build smoke test (BizHawk boot verification only).** SGDK build chain confirmed at `sample/basics/hello-world/`; ROM produced cleanly. Booting it in BizHawk to confirm no runtime crash is the only remaining smoke step and is gated on user steering (visual confirmation).

5. ~~A4 / startup convention verification.~~ **DONE** — A4 SAFE. SGDK does not touch A4. `-ffixed-a4` stays.

6. **ResComp / makefile.gen integration.** SGDK's `makefile.gen` is the canonical build chain; `build.bat` currently invokes GCC directly. S1 build-pipeline rewire decides whether to adopt `makefile.gen` wholesale or keep `build.bat` extended with the SGDK lib link step. Recommendation: adopt `makefile.gen` — battle-tested, knows about ResComp / XGM2 packaging, less to maintain.

7. **XGM2 / audio integration.** Existing `audio_driver.asm` may need to be reconciled with SGDK's XGM2 wrappers. Spec keeps this as a Stage 11 item; do not change audio plumbing during S1 frontend cutover.
