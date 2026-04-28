# Native Genesis Rewrite — Design Spec

**Date:** 2026-04-27
**Status:** Approved for S0; S1 gated on S0 close
**Path:** E (revised 2026-04-27) — **build on SGDK** (Sega Genesis Development Kit) as the platform/render layer; own all gameplay in C in FINAL TRY tree; WHAT IF is a read-only reference for NES-data extraction only
**Quality bar:** Pixel-perfect to NES, matching the title + file-select fidelity standard

---

## 0. Reference Contract

The "golden reference" against which every parity check runs. All values are filled at S0 close and frozen for the project lifespan; bumps require explicit spec amendment.

**Fixed inputs:**

- **NES ROM SHA256:** `8f72dc2e98572eb4ba7c3a902bca5f69c448fc4391837e5f8f0d4556280440ac` (Legend of Zelda, The (USA).nes — locked at S0 from the local copy under `Zelda1-Redux/`)
- **Current Genesis ROM SHA256 (baseline):** `4bcfc1d916f44f31f36ee5bc0862b6b696313a264ffcc8373abde87d318befb4` (`builds/whatif.md`, locked from on-disk artifact at commit `7f0173d1` on 2026-04-28; build reproducibility verified at S1)
- **NES emulator + version:** BizHawk 2.11.0 (NES core: `quickerNES`)
- **Genesis emulator + version:** BizHawk 2.11.0 (Genesis core: `Genplus-gx` / GPGX)
- **NES screen palette (RGB):** `quickerNES` built-in palette (192-byte RGB triplet table from `BizHawk-2.11-win-x64/config.ini`; see `docs/audit/emulators.md`)
- **Canonical input movies:** stored under `tools/probes/movies/` per stage (`s3_start_room.bk2`, `s4_link_walk.bk2`, etc.). Each movie file declares its **initial SRAM image** as a sibling `.sram` blob (or explicit empty-SRAM marker). Probes start the emulator from that SRAM state. Without this, file-delete and registered-file-start probes are non-deterministic.
- **RNG / frame-state sync rules:** Genesis run is started at frame 0 from cold reset, with deterministic input movie. NES run uses same input timing relative to mode entry. RNG state diff is logged per frame; non-zero diff outside expected divergence windows fails the stage.

**Pixel-parity definition:**

Two distinct levels apply per stage; the spec specifies which:

- **Logical parity:**
  - **Genesis-vs-Genesis (regression check, e.g. S1 frontend cutover):** byte-identical contents in plane A/B tilemap, SAT, CRAM, VSRAM scroll registers after canonical input movie. Diff tool: `tools/probes/diff_capture.py` over raw byte streams.
  - **NES-vs-Genesis:** raw byte-identical comparison is **not meaningful** (different tilemap word layouts, different attribute encoding, different SAT layout, different palette indexing, different sprite priority/link semantics). Both captures are converted into a **normalized scene schema** before diff:
    - `bg_tile[col,row]` — canonical NES tile id (after BG pattern table mapping)
    - `bg_palette[col,row]` — canonical NES palette index (0–3)
    - `bg_priority[col,row]` — logical priority layer
    - `sprite[i]` — `{x, y, canonical_tile_id, palette, flip_x, flip_y, priority}`
    - `scroll` — `{x, y}` per plane in canonical pixel units
    - `state` — selected gameplay fields per probe (RNG, frame counter, mode, link state)
  - Tooling: `tools/probes/normalize_nes.py` and `tools/probes/normalize_gen.py` produce the schema; `tools/probes/diff_normalized.py` diffs two schemas.
- **RGB screenshot parity (final-frame visual stages):** PNG-vs-PNG diff after color normalization. Capture geometry is locked at S0 (see `docs/audit/capture_geometry.md`):
  - Genesis display mode: **H32** (256×224 visible)
  - RGB viewport size: **256×224 px**
  - Crop origin (Genesis): `(0, 0)` — full H32 frame
  - Crop origin (NES): `(0, 8)` — skip NES top blanking to align with H32's 224 lines
  - Overscan policy: ignored (both captures cropped to 256×224 visible playfield)
  - Backdrop / transparent color: NES `$3F00` → Genesis CRAM byte 0 (palette 0, index 0)
  - Screenshot scaling: none, 1:1 pixel comparison only
  - NES capture is converted to Genesis-CRAM equivalent via the locked palette-mapping table at `data/palettes/nes_to_genesis.c`; Genesis capture is output at native VDP RGB. Threshold is exact match on tile-aligned regions; diff reports per-tile mismatches.

Stages that touch tilemap/CHR/palette content default to **logical parity (normalized for NES-vs-Genesis)**. Stages that touch end-to-end render output default to **RGB parity** with the locked palette table. Both can apply to a single stage.

**Reproducibility rule:**

- Every probe must run end-to-end from a clean repo + ROM hash + emulator hash + input movie, producing the same diff output across machines. CI artifact is the diff log + screenshot pair.

---

## 1. Goal

Retire the NES emulation layer (PPU/NMI/OAM/APU/CTRL/MMC1 shim) and the transpiled M68K banks (`z_00.asm`..`z_07.asm`). Replace with an owned, native-Genesis C codebase whose only assembly is boot/IO/audio and (optionally) a small hot-path render kernel.

The result is a single coherent Genesis project, not an NES-on-Genesis emulation hybrid.

## 2. Non-Goals

- Not an emulator. No PPU semantics preserved.
- Not a rewrite of the NES game design. Behavior remains faithful (frame-accurate where probe-verifiable).
- Not a port to other platforms. Genesis target only.
- Not a save-format break. SRAM layout preserved across cutover.

## 3. Approach (Path E, revised)

**Platform layer = SGDK.** The Sega Genesis Development Kit
([github.com/Stephane-D/SGDK](https://github.com/Stephane-D/SGDK)) provides
the VDP, DMA, sprite engine, scroll, joypad, audio (XGM2/PCM), system
boot/vectors/IRQ, and standard libc/runtime built on `m68k-elf-gcc`. We adopt
SGDK as the platform/render layer rather than rolling our own.

Why SGDK:

- The `m68k-elf-gcc 13.2.0` already in `build/toolchain/sgdk_bin/bin/` is
  literally the SGDK 2.x bundled compiler. We are already using SGDK's
  toolchain; we just have not been linking SGDK's library.
- SGDK's API is what our prior Section 4.1 sketch (`vdp_*`, `dma_q_*`,
  `tm_*`, `spr_*`, `scr_*`, `pal_*`) would have evolved into. Battle-tested
  in shipped homebrew games. Saves ~3000 lines of render-layer code.
- SGDK's sprite engine handles frames/animation/movement and 80-slot
  pressure that Zelda bosses (Aquamentus, Gleeok) require.
- SGDK ships an XGM2 audio driver — replaces our `audio_driver.asm` with a
  maintained driver and frees the rewrite from inheriting transpile-era
  audio glue.
- North-star compatible: best-practices.md says "ASM stays only for
  boot/reset/interrupt entry, hardware/IO primitives, and truly hot code."
  SGDK = exactly that hardware-IO layer. Our owned C = game logic on top.

**Owned game logic = C in FINAL TRY tree.** All gameplay (mode dispatcher,
Link, enemies, combat, rooms, dungeon, cave, items, hud, options) is owned
C, written by us, calling SGDK primitives.

**Reference materials (read-only):**

- **WHAT IF** (`C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF`) — borrow Python extractors and extracted data tables (CHR, palettes, rooms, enemies, items, text, audio). Do **not** lift WHAT IF asm; SGDK replaces the render layer WHAT IF was building.
- **aldonunez NES disassembly** (`reference/aldonunez/`) — semantic reference for game-logic behavior.

The active development tree is FINAL TRY. The repo is reorganized into a
clean role-based layout (Section 6); existing owned C survives (relocated,
not rewritten) and is retargeted onto SGDK primitives in S1.

## 4. Architecture

Three layers, top-down:

```
GAMEPLAY (C, owned)        — frontend, game/{mode,world,room,link,combat,
                              enemies,items,hud,cave,options}, state, core
        │ calls SGDK primitives directly + thin owned adapters where useful
        ▼
SGDK (third-party C/asm)   — VDP, DMA queue, sprite engine, scroll, joypad,
                              audio (XGM2/PCM), boot, vectors, IRQ, libc
        │ raw VDP / 68K
        ▼
HARDWARE                   — Genesis VDP, M68K, Z80 audio
```

**Two layers, not three.** SGDK collapses what was previously the "platform"
and "render" layers into one well-tested third-party library. Gameplay calls
SGDK directly for primitives, with a tiny owned adapter (`src/sgdk_adapter/`)
where we need NES-shaped helpers (e.g. NES-CHR-tile id → SGDK tile id, NES
4bpp palette pack → SGDK CRAM, NES-style sprite slot tagging on top of
SGDK's sprite engine).

No game logic in asm. No NES emulation anywhere. No custom render-floor
rewrite — SGDK is the floor.

### 4.1 SGDK Surface Used + Owned Adapter

We use the standard SGDK public API. The exact surface we depend on (locked
at S0 by the SGDK-integration audit, Task 3.5):

- **Lifecycle / system:** `SYS_*` for boot, VBlank-process callback, frame
  pacing, halt
- **VDP:** `VDP_*` for init, mode set, plane writes, scroll, palette CRAM
  writes, tile uploads, CHR loading
- **DMA:** `DMA_*` queue submit/flush; SGDK already handles SAT DMA last,
  word/byte unit conventions, queue overflow accounting
- **Sprite engine:** `SPR_*` add/remove/update with frames, animation,
  position; built on top of the 80-slot SAT
- **Joypad:** `JOY_*` with the standard event-callback or polled API
- **Audio:** `XGM2_*` for music + sfx playback (or `SND_PCM_*` if we need
  raw PCM)
- **Memory:** SGDK's `MEM_alloc/MEM_free` for any dynamic allocation we need
  (we minimize this — game state is static)

**Owned adapter (`src/sgdk_adapter/`):**

```
src/sgdk_adapter/
├── render_adapter.c/.h     NES tile id → SGDK tile id, NES palette pack
│                           → SGDK CRAM, NES-attribute → SGDK tile-attr
├── audio_adapter.c/.h      audio_music_play(u8 song_id) → XGM2_*,
│                           audio_sfx_play(u8 sfx_id) → XGM2_* / SND_PCM_*
├── joy_adapter.c/.h        joy_read / joy_state in NES-button shape on top
│                           of SGDK's JOY_*
└── sram_adapter.c/.h       OptionsState + save-slot persistence helpers
                            (Section 4.6) using SGDK's SRAM bank-swap
```

The adapter is thin — its job is to expose game-friendly identifiers (NES
tile ids, NES palette indices, Genesis SRAM byte ranges) on top of SGDK's
generic ones. It does **not** wrap SGDK behind our own redundant facade;
gameplay calls SGDK directly when SGDK's API already fits.

**Forbidden:**

- No code under `src/game/` or `src/frontend/` writes VDP / CRAM / VSRAM /
  joypad / Z80 ports directly. All hardware access goes through SGDK.
- No `src/render/` or `src/platform/` layer of our own — SGDK is the
  platform/render layer.
- No `vdp_init` / `tm_plane_a_write_word` / `dma_q_submit` /
  `spr_alloc` / `pal_load` etc. — those names belong to the prior
  pre-SGDK draft of this spec and are deleted. Use SGDK's API names.

### 4.2 Frame Loop (SGDK pattern)

SGDK provides the standard frame loop scaffolding. Our `main_loop` follows
SGDK's idiomatic pattern: per-frame game tick, then yield to SGDK for VBlank
processing, which drains the DMA queue, performs the SAT DMA, applies
scroll, and ticks the audio driver. Pseudocode:

```c
int main(void) {
    sgdk_adapter_init();         // installs joypad callback, audio init,
                                 // palette setup, frontend handoff
    while (1) {
        game_tick();             // owned: mode_runtime dispatches active mode,
                                 // submits CHR / tilemap / palette work via
                                 // SGDK's DMA queue and updates sprite engine
                                 // state via SPR_*
        SYS_doVBlankProcess();   // SGDK: waits for VBlank, drains DMA queue
                                 // (SAT DMA last), updates sprite engine,
                                 // ticks audio driver, polls joypad
    }
}
```

Game logic stays out of interrupt context. SGDK's VBlank-process callback
hook is where `audio_tick_vblank()` (our adapter wrapper around SGDK's
audio-tick or our own driver entry, see Section 4.6 audio split) plugs in.

**SAT (sprite attribute table) upload contract:** delegated to SGDK's
sprite engine. SGDK guarantees SAT DMA completes each VBlank; our gameplay
calls `SPR_addSprite` / `SPR_setPosition` / `SPR_setFrame` etc. before the
VBlank-process boundary.

**Queue overflow:** SGDK's DMA queue exposes overflow counters and
remaining-budget queries. The owned adapter wraps these as
`render_dma_overflow_count()` / `render_dma_words_remaining()` for game
code that needs to check before bulk transfers (e.g. CHR uploads on room
load).

### 4.3 Shim → SGDK Mapping

| Legacy shim primitive | SGDK replacement |
|---|---|
| `_ppu_write_2006` (addr) | `VDP_setVRamWriteAddr` (or implicit in `VDP_setTileMap*` / `VDP_loadTileData`) |
| `_ppu_write_2007` (data) | `VDP_setTileMapXY` / `VDP_setTileMapDataRect` / `VDP_loadTileData` (queued via `DMA_queue*`) |
| `_ppu_write_2005` (scroll) | `VDP_setHorizontalScroll` / `VDP_setVerticalScroll` |
| `_ppu_write_2001` (mask) | `VDP_setEnable` |
| `_oam_dma(page)` | sprite engine: `SPR_addSprite` / `SPR_setPosition` / `SPR_update` |
| `_ppu_write_3F00..3F1F` | `PAL_setColor` / `PAL_setColors` / `PAL_setPalette` |
| NES NMI handler | nothing — `SYS_doVBlankProcess` owns frame timing |
| `_apu_*` | `XGM2_*` for music; `XGM2_playPCMEx` or `SND_PCM_startPlay` for sfx |
| `_ctrl_*` | `JOY_readJoypad` (or SGDK's joypad callback) |
| `_mmc1_*` | nothing — Genesis flat ROM |

### 4.4 RAM Convention

Work RAM stays at `$FF0000`. The base address is arbitrary; only the convention is preserved. State headers migrate field-by-field from NES_-prefixed accessors to typed Genesis-shaped structs over the project lifespan. Deprecated names alias new ones during transition.

### 4.5 ABI Contract

Locked at S0 and held constant through S13.

**Toolchain:**

- **C compiler:** `m68k-elf-gcc.exe`, version `gcc (crosstool-NG UNKNOWN) 13.2.0`. Optimization level fixed per build profile.
- **Assembler:** vasm Motorola syntax (`vasmm68k_mot.exe`), version `vasm 2.0e; M68k cpu backend 2.8; motorola syntax module 3.19d`.
- **Linker:** `m68k-elf-ld.exe`, version `GNU ld (crosstool-NG UNKNOWN) 2.40`. Single linker script under `src/platform/`.

**Calling convention (C ↔ asm):**

- Standard System V m68k ABI as emitted by the chosen C compiler. All cross-language calls go through C-declared prototypes in `src/abi/*.h`; no implicit ABI assumptions.
- **Caller-saved (clobberable by callee):** D0, D1, A0, A1.
- **Callee-saved (must preserve):** D2–D7, A2–A6.
- A7 is the M68K stack pointer; never touched outside platform code.
- Return values: **D0 for all ≤32-bit values and pointers.** Both `u32` and `void *` returns land in D0 (not A0). Confirmed by `tools/probes/abi_probe.c` listing (`builds/abi_probe/abi_probe.s`); full details in `docs/audit/abi_probe.md`.
- Arguments are passed on the stack in left-to-right order. For `u32 abi_arg_mix(u16 a, u32 b, void *p)`: `a` (u16, zero-extended) at sp+6, `b` (u32) at sp+8, `p` (void *) at sp+12. No register argument passing observed at -O1 with these flags.
- Callee-saved registers per System V m68k ABI: D2–D7, A2–A6. GCC emits MOVEM to preserve these only when actually used; the contractual set is confirmed by ABI spec and enforced by `-ffixed-a4` pinning A4 outside the allocatable set entirely.
- **No C↔asm function may pass or return structs by value.** Aggregates cross the boundary by pointer only. This avoids compiler-specific struct-return ABI traps.

**Interrupt handler ABI:**

- Interrupt handlers preserve **all** D/A registers they touch — including caller-saved D0/D1/A0/A1 — because interrupts may occur inside arbitrary C code. VBlank ISR entry/exit uses `MOVEM` to save/restore its clobber set.
- `audio_tick_vblank()` is **ISR-safe**: either preserves all registers internally or is wrapped by an ISR trampoline that does.
- VBlank budget accounting includes: `audio_tick_vblank` time + `dma_q_flush` (queued normal entries) + SAT DMA + `scr_apply` writes + `joy_read`. Cycle probe (`tools/probes/cycle_probe.lua`) measures all five components per frame and fails the stage if total exceeds the locked VBlank window. This prevents audio from silently stealing the DMA budget as song density grows.

**Pointer + integer model:**

- Pointers are 32 bits. ROM and RAM share a single flat address space; no segment switching.
- `u8` = 8-bit unsigned, `u16` = 16-bit unsigned, `u32` = 32-bit unsigned, `s16`/`s32` signed equivalents. Defined in `src/core/types.h`.
- DMA source pointers must be 16-bit-aligned for word transfers. The render layer enforces alignment at submit time and asserts on misalignment in debug builds.

**Render API unit conventions (locked, no per-function variation):**

- All `*_word_count` parameters are **word counts** (16-bit words), never bytes.
- All `*_byte_count` parameters are **byte counts**.
- VRAM addresses passed to render API are **byte addresses** (the value programmed into VDP control as the destination, after the standard write-target encoding handled inside the render layer).
- CRAM addresses are **byte addresses** within CRAM (0–127).
- Plane coordinates `(col, row)` are tile units, not pixels. Plane A is 64×32 tiles; valid range is `col ∈ [0,63]`, `row ∈ [0,31]`.
- Sprite `(x, y)` is in pixels with VDP's standard 128-offset convention (visible screen y starts at 128, x at 128).

**Display-active vs. blanking semantics:**

- Functions ending in `_sync` (e.g. `chr_upload_sync`) write directly through VDP registers and are **valid only during VBlank or with display disabled**. Calling during active display corrupts the screen.
- Functions ending in `_q` or named `*_submit` queue work for the next `dma_q_flush()`. Safe outside VBlank.
- All other functions (`tm_plane_a_write_word`, etc.) are also queued; safe outside VBlank.
- `dma_q_flush()` itself is **VBlank-only**. Calling outside VBlank is a programming error; debug builds assert.

**Queue overflow policy:**

- `dma_q_submit` returns `false` on overflow (either word budget or entry count exhausted) and increments a per-frame counter readable via `dma_q_overflow_count()`. Debug builds also halt with a debug trap.
- Two budgets, two queries:
  - `dma_q_words_remaining()` — words available in transfer-data budget
  - `dma_q_entries_remaining()` — slots available in queue entry array
- Callers submitting large bulk transfers (CHR uploads on room load) must check both before submission and split across frames if needed.
- `dma_q_reset_frame_stats()` is called by the frame loop after `dma_q_flush`; debug builds verify overflow count is 0 at that point.

### 4.6 Preferences Subsystem (Redux Options)

The FS menu already exposes a `FS_OPTIONS` row (see `src/fs_phase.h`, currently a label without a submenu). The native rewrite turns this into a real preferences subsystem that persists Zelda-Redux–style feature toggles across all gameplay subsystems.

**Architecture:**

```
src/game/options/
├── options_runtime.c/.h    flag table, query API, mutation API
├── options_menu.c/.h       OPTIONS submenu UI (phase machine like fs_phase)
├── options_state.h         OptionsState struct, default values, version field
└── options_persist.c/.h    SRAM read/write, migration on version bump
```

**Public query API** (called from gameplay anywhere — Link, items, combat, HUD, render):

```c
// options_abi.h — exposed via render_abi.h's sibling include
bool opt_is_enabled(opt_flag_t flag);
u8   opt_get_value(opt_flag_t flag);   // for non-bool options (text speed, etc.)
void opt_set(opt_flag_t flag, u8 value);
void opt_apply_defaults(void);          // reset to ship defaults
```

**Initial flag set** (drawn from existing Redux integration in FS + commonly requested toggles; not all are wired to gameplay at S8 — some are wired in S4/S6/S7 as the relevant subsystem lands):

| Flag | Default | Wired in stage | Effect |
|---|---|---|---|
| `OPT_TEXT_SPEED` (0=slow, 1=normal, 2=fast) | 1 | S9 (cave NPC text) | Skip per-char delay multiplier |
| `OPT_DARK_ROOM_LIGHT` | off | S10b (dungeon dark rooms) | Render dark rooms fully lit without candle |
| `OPT_SWAP_AB` | off | S4 (Link input mapping) | Swap sword/secondary item buttons |
| `OPT_AUTO_COLLECT_DROPS` | off | S7 (drops) | Drops walk to Link on spawn |
| `OPT_FS_MUSIC` | off | S1 (frontend music) | Re-enables FS music; current build matches NES (silent) |
| `OPT_REDUX_LINK_TINT` | on | S1 (FS palette) | Faded-Link palette for empty slots (already implemented) |
| `OPT_PERMANENT_MAGIC_SHIELD` | off | S7 (drops/damage) | Magic shield not lost on like-like contact |
| `OPT_FAST_DEATH_SKIP` | off | S12 (death) | Skip death-jingle delay on continue |
| `OPT_SHOW_SECRETS` | off | S3 (overworld) / S10 (dungeon) | Reveal bombable walls, burnable trees on inspection |
| `OPT_NO_FLASHING` | off | S12 (ending) / S11 (audio) | Reduces strobing for photosensitivity |

**Persistence:**

- `OptionsState` lives in SRAM at a **new** byte range, separate from per-save-file state. Layout:
  ```c
  struct OptionsState {
      u8  version;          // schema version, bumped on layout change
      u8  flags[N];         // packed flag bytes
      u8  reserved[16];     // future expansion, must be zero
      u8  checksum;         // simple XOR
  };
  ```
- On boot, `options_persist_load()` reads SRAM, validates checksum, migrates if `version < CURRENT_VERSION`, falls back to defaults if invalid.
- Existing per-save-file SRAM layout (the three NES save slots) is **not** changed. Options live alongside, in unused SRAM space.
- SRAM byte range allocation is locked at S0 (`docs/audit/sram_map.md`) so S1's SRAM fixture test can assert on the new range without breaking existing save slots.

**OPTIONS submenu UI:**

- Phase-machine architecture mirroring `fs_phase` (memory: title-screen + FS quality bar applies).
- Reachable from FS_OPTIONS row (existing) and from in-game pause sub-screen (new in S8a).
- Cursor moves between toggles, A toggles bool flags or cycles enum values, B returns.
- Visual style matches existing FS / pause aesthetic; pixel-perfect against a reference mock at acceptance.

**Future-proofing rule:**

- Adding a new flag is a **single-file change in `options_state.h`** (extend `opt_flag_t` enum + default), plus the call site that consumes it. No central registry edits, no menu code edits if the menu auto-reflects the enum (preferred design).
- Bumping `version` triggers automatic migration; never breaks existing saves.
- The OPTIONS submenu is the **only** UI surface for these toggles. No debug-only build flags get promoted into runtime — all runtime preferences flow through this subsystem.

### 4.7 Frame Timing Contract

```
                    one frame (~16.67ms NTSC, ~20ms PAL)
   ┌──────────────────────────────────┬────────────────────────┐
   │       active display (~12ms)     │   VBlank (~4–8ms)      │
   ├──────────────────────────────────┼────────────────────────┤
   │ game_tick()                      │                        │
   │   reads input from prev frame    │                        │
   │   advances all state             │                        │
   │   submits to dma_queue           │                        │
   │ spr_commit()                     │                        │
   │   builds sprite link list in RAM │                        │
   │ vdp_wait_vblank() ──────────────▶│                        │
   │   spins on VDP status            │ flag set, returns      │
   │                                  │ dma_q_flush()          │
   │                                  │   drains queue → VRAM  │
   │                                  │   sprite SAT DMA last  │
   │                                  │ scr_apply()            │
   │                                  │   writes h/v scroll    │
   │                                  │ joy_read()             │
   │                                  │   stores for next tick │
   └──────────────────────────────────┴────────────────────────┘
```

**Contract:**

- `vdp_wait_vblank()` returns at the **start** of VBlank; the entire VBlank window is available to the caller.
- `dma_q_flush()` must complete before active display resumes; queue size is capped to fit the worst-case VBlank budget at S0-locked emulator pacing.
- VBlank flag is cleared by VDP read in `vdp_wait_vblank`; flushing happens after the read.
- If `game_tick()` overruns and the next `vdp_wait_vblank()` is entered after VBlank has already started, the flush still runs in the remaining VBlank. The frame counter increments as usual; visible artifacts (sprite tearing, partial uploads) are the symptom and **logged via cycle probe**.
- `joy_read()` runs **after** rendering. Input affects the **next** `game_tick()`. This is intentional: input-to-pixel latency is one frame, deterministic.
- The VBlank ISR itself does only: increment frame counter, call `music_tick()`, set vblank-pending flag. **No game logic, no DMA, no allocation.**

## 5. Quality Bar

Every stage matches the title-screen and file-select fidelity standard:

- **Pixel-perfect to NES reference** on canonical screens (parity probe diff = 0)
- **Native VDP** (no shim, no PPU emulation)
- **Owned C modules** with phase-machine architecture where stateful (mirror `intro_phase`, `fs_phase`)
- **Asset extraction first** — extract real CHR/palette/tilemap from NES ROM, byte-match in BizHawk before writing C
- **Per-stage verification probe** — BizHawk Lua dump → tool diff
- **Per-stage screenshot archive** under `builds/reports/` for regression bisection

No placeholder rendering phases. No "looks close" — pixel match.

## 6. Repo Layout (Reorg, SGDK)

```
final-try/
├── src/
│   ├── sgdk_adapter/      C, owned — thin layer between gameplay + SGDK
│   │   ├── render_adapter.c/.h   NES tile/palette/attribute → SGDK
│   │   ├── audio_adapter.c/.h    audio_music_play / audio_sfx_play → XGM2
│   │   ├── joy_adapter.c/.h      NES-button-shape state on top of JOY_*
│   │   └── sram_adapter.c/.h     OptionsState + save-slot SRAM helpers
│   ├── abi/               headers only — public include surface
│   │   ├── render_abi.h       SGDK include + adapter prototypes
│   │   ├── audio_abi.h        audio adapter prototypes
│   │   ├── joy_abi.h          joypad adapter prototypes
│   │   ├── sram_abi.h         SRAM adapter prototypes
│   │   └── legacy_bridge.h    transitional z01_*/z07_* externs only;
│   │                          deleted by S10
│   ├── frontend/          C — pre-gameplay sequences
│   │   ├── intro/             intro_main, intro_title, intro_story, …
│   │   ├── fs/                fs_main, fs_phase, fs_render, fs_input, …
│   │   └── frontend_runtime.c
│   ├── game/              C — in-game runtime
│   │   ├── mode/              mode_runtime — gamemode dispatcher
│   │   ├── world/             overworld + dungeon top-level, triforce, ending
│   │   ├── room/              room_load, room_runtime, room transitions
│   │   ├── link/              link_runtime, link_collision
│   │   ├── combat/            combat, damage, projectiles
│   │   ├── enemies/           enemy_*_runtime family
│   │   ├── items/             item_runtime + inventory/pause menu
│   │   ├── hud/               hud_runtime
│   │   ├── cave/              cave_runtime + NPC/person
│   │   └── options/           preferences subsystem — Redux feature toggles,
│   │                          OPTIONS submenu UI, persisted to SRAM
│   ├── state/             shared RAM map headers (typed structs)
│   └── core/              types, intrinsics, RNG
│
│   (no src/platform/, src/render/, or src/zelda_translated/ —
│    SGDK provides platform + render; transpiled banks deleted)
│
├── sgdk/                  vendored SGDK distribution (or git submodule)
│                          versioned + reproducible across clones
├── data/                  extracted Genesis-ready data
│   ├── chr/, palettes/, rooms/, enemies/, items/, audio/
├── tools/                 Python extractors, build scripts, probes
├── reference/             NES disasm + ROM metadata only; NES ROM never committed
├── docs/                  design docs, specs, dev notes
└── builds/                output ROMs, listings, archives, reports
```

The exact mechanism for vendoring SGDK (in-tree copy vs. git submodule vs.
`setup.bat` that downloads to `build/toolchain/sgdk/`) is decided at S0 close
based on the toolchain-portability audit (see `docs/audit/toolchain.md`
"Open issues recorded at S0").

**Conventions (locked once, applied everywhere):**

- C files lowercase, snake_case, `<subsystem>_<role>.{c,h}` (e.g. `link_runtime.c`)
- State headers always `<subsystem>_state.h`, RAM addresses centralized in `src/state/`
- One subsystem per dir; cross-dir includes allowed only via `src/state/*.h`, `src/abi/*.h`, `src/core/*.h`
- **Gameplay (`src/game/`) and frontend (`src/frontend/`) include render only through `src/abi/render_abi.h`.** Private render headers under `src/render/` are visible only to `src/render/*.c`.
- **No subsystem may include transpiled headers directly during cutover.** Legacy `z01_*..z07_*` calls go only through `src/abi/legacy_bridge.h`. That header is deleted at S10.
- **No assembly under `src/`.** SGDK provides any required asm (boot, vectors, IRQ, audio driver). Owned hot-path asm is permitted only if profiling demands it and is then placed under `src/sgdk_adapter/asm/` with explicit justification in a comment header.
- `src/abi/` contains C-facing **headers only** — never `.asm` or `.s`.
- Hardware register access (VDP control/data ports, CRAM, VSRAM, joypad, Z80 ports) is allowed only inside SGDK itself. Our owned code calls SGDK functions; it never touches hardware registers directly.
- Owned C is the real codebase; SGDK is the platform; `data/` is passive (byte-reproducible from NES ROM); `gen/` no longer exists post-reorg.

## 7. Stage Plan

Each stage ends in a testable ROM that meets the quality bar. Old shim/transpile path stays functional through cutover; new path proves at acceptance, then old path dies.

### S0 — Inventory + Guardrails (~1 wk)

Audit the current tree before any file moves. Outputs are documents, scripts, and CI checks; no source code is relocated.

- Generate current source tree snapshot (`docs/audit/repo_tree.txt`)
- Generate **legacy symbol caller report**: every call site of `_ppu_*`, `_oam_*`, `_apu_*`, `_ctrl_*`, `_mmc1_*`, `z01_*`..`z07_*` (file, line, calling function). Output: `docs/audit/legacy_callers.md`.
- Map current frontend dependencies (intro/FS/title file-by-file include + extern graph). Output: `docs/audit/frontend_deps.md`.
- Map current build artifacts and source-order: which `.asm`/`.c` files compile in what order, which `.o` files link into the ROM, which symbols are exported by each. Output: `docs/audit/build_order.md`.
- Classify every file as: **owned C**, **generated data**, **transpiled asm**, **shim asm**, **platform asm**, or **dead/cruft**. Output: `docs/audit/file_classification.md`.
- Add `tools/probes/lint_legacy_symbols.py` — grep-based check that reports new callers of forbidden symbols. **Warning-only at S0.**
- Build and inspect `tools/probes/abi_probe.c` (`u32 abi_ret_u32(void)`, `void *abi_ret_ptr(void)`, `u32 abi_arg_mix(u16, u32, void *)`); commit listing to `docs/audit/abi_probe.md` with proven calling-convention details. Replace every Section 4.5 placeholder marker with the recorded values.
- Lock NES ROM provenance: ROM is **not committed**. `tools/probes/locate_reference_rom.py` resolves the ROM path via local config or `ZELDA_NES_ROM` env var, verifies SHA256 against the value recorded in Section 0, and is called by every probe before extraction.
- Fill the placeholder markers in **Section 0 (Reference Contract)**: ROM hashes, current Genesis baseline ROM hash, emulator versions, palette, viewport/crop/overscan/backdrop/H-mode policy.
- Resolve the **S0-Locked Questions** in Section 12.
- **Acceptance:** current build still produces a working ROM with no behavioral change. All audit documents committed. Lint check runs in CI. Reference + ABI contracts have no remaining placeholders. Section 12 reduced to "None."

### S1 — Repo Reorg + SGDK Integration (~2–3 wks)

- Vendor SGDK into the repo (mechanism decided at S0 close — submodule, in-tree copy, or `setup.bat` download).
- New tree under `src/` (Section 6) — owned C only; no `src/platform/` or `src/render/` directories.
- Move owned C with `git mv` preserving history (each subdir its own commit, build green between commits).
- Build pipeline rewired to use SGDK's makefile / build harness on top of the existing `m68k-elf-gcc 13.2.0`. Single `build.bat` entry point invokes SGDK's build.
- Replace the existing PPU/NMI/OAM shim layer with SGDK calls. Concretely:
  - Frontend (`title`, `intro`, `fs`) retargeted from raw `VDP_CTRL_WORD` writes onto SGDK's `VDP_*`, `DMA_*`, `PAL_*`, `SPR_*`, `JOY_*`.
  - Owned `src/sgdk_adapter/` provides NES-shaped helpers (`render_adapter.c`, `audio_adapter.c`, `joy_adapter.c`, `sram_adapter.c`).
- **SRAM fixture added:** `tools/probes/sram_layout_test.c` — known SRAM blob from current build, typed-struct offset static asserts, load/save roundtrip test. Runs in CI from S1 onward.
- **Audio preservation:** existing audio output is preserved during transition. SGDK's XGM2 driver replaces our `audio_driver.asm` if the SGDK-integration audit (Task 3.5) confirms feature parity for the NES soundtrack; otherwise the audio adapter wraps the existing driver behind `audio_music_play` / `audio_sfx_play` / `audio_tick_vblank`. The adapter API is stable; the driver beneath can swap.
- **Acceptance:** title + intro + FS play identically (including music). **Logical parity (Genesis-vs-Genesis byte-identical)** diff vs current baseline ROM = 0 across CRAM, SAT, plane A/B tilemap, scroll registers on the canonical movie set:
  - `title_idle.bk2`
  - `title_to_file_select.bk2`
  - `intro_story_page_1.bk2`
  - `fs_fresh_cursor.bk2`
  - `fs_cursor_wrap.bk2`
  - `fs_name_entry_create.bk2`
  - `fs_name_entry_backspace.bk2`
  - `fs_file_delete_cancel.bk2`
  - `fs_file_delete_confirm.bk2`
  - `fs_registered_file_start.bk2`

  SRAM fixture passes. Frontend lint invariants graduate from warn → fail.

### S2 — Data Extraction Pipeline (~1 wk)

- Port WHAT IF Python extractors into `tools/` (copy with source commit/date/hash recorded in header comment per file)
- Output Genesis-ready C const arrays under `data/`
- Reference NES disasm checked into `reference/aldonunez/`
- **Acceptance — two layers:**
  1. **Raw extraction parity:** the intermediate raw-byte output of each extractor (CHR, palette, room layouts, enemy tables, etc., before Genesis conversion) byte-matches NES ROM source data, verified by SHA hash against `reference/aldonunez/` cross-references where applicable.
  2. **Genesis conversion reproducibility:** the final `data/*` C const arrays are deterministically generated from the raw extraction. Re-running `tools/extract_*.py` produces byte-identical `data/*` output. SHA of every file under `data/` is recorded in `data/MANIFEST.sha256`; CI fails if regenerated output diverges.

### S3 — Overworld Room Render (~3–4 wks)

- `src/game/room/` — room loader, column/square decode, plane-A tilemap fill, plane-B HUD bar
- BizHawk parity probe diffs Genesis output vs NES start-room (`$77`)
- **Acceptance:**
  - Start-room renders pixel-identical (RGB parity) to NES.
  - `tools/probes/batch_room_render.py` renders all 128 overworld rooms from extracted data and produces a single diff report. Stage fails if **any** room has non-zero normalized tile/palette/attribute mismatch.
  - Four-direction scroll between rooms via native scroll API; transition probe captures scroll register progression frame-by-frame and matches NES.

### S4 — Link (~3–4 wks)

- `src/game/link/` — movement, animation, sword, item-use, push-back, invincibility, sprite render
- Reference NES disasm `Player_*` + WHAT IF Phase 4 plan
- Phase machine: idle / walk / attack / damage / item-use / pickup / death
- **Acceptance:** Link walks the start-room frame-perfect. Per-frame state diff against NES on canonical movies covers the following fields (zero divergence required):
  - `link.x`, `link.y`
  - `link.subpixel_x`, `link.subpixel_y` (if present in NES)
  - `link.direction`
  - `link.action_state`
  - `link.anim_frame`
  - `link.action_timer`
  - `sword.active`
  - `sword.x`, `sword.y`
  - `invincibility_timer`
  - `collision_flags`
  - `rendered_sprite_list_for_link` (canonical tile ids + flips per slot)

### S5 — HUD (~1 wk)

- `src/game/hud/` — hearts, rupees, item box, map dot, A/B icons on plane B
- **Acceptance:** static HUD pixel-identical. Heart drain animation matches.

### S6 — Enemies (~4–6 wks)

- `src/game/enemies/` — re-implement enemy_*_runtime against new state model + render API
- Per-family verification: walker, flyer, projectile, block, dodongo, gleeok, lamnola, manhandla, wallmaster, wanderer, boss
- Drop tables, spawn logic, AI states all clean C
- **Acceptance:** each family animates + behaves frame-perfect in start-room and a smoke dungeon room.

### S7 — Combat + Damage + Drops (~2 wks)

- `src/game/combat/` — Link↔enemy collision, damage, knockback, death animation, drop spawn, item pickup
- **Acceptance:** Link kills moblin, gets drop, picks it up, count increments. Frame-accurate.

### S8 — Items + Inventory + Pause + Options (~3–4 wks, split into sub-stages)

Subdivided to keep per-stage scope honest. All sub-stages use per-item probes; "every item works" is replaced by an enumerated probe table.

- **S8a — Inventory model + pause screen + OPTIONS submenu** (~5–7 days)
  - `src/game/items/inventory.c`, `pause_runtime.c` (phase machine like FS)
  - `src/game/options/` — full preferences subsystem per Section 4.6: `options_runtime.c`, `options_menu.c`, `options_state.h`, `options_persist.c`. Implements the initial flag set defined in Section 4.6's table.
  - OPTIONS submenu reachable from both the existing FS_OPTIONS row and the in-game pause sub-screen.
  - SRAM persistence wired (separate byte range from save slots; layout locked at S0).
  - Acceptance: pause sub-screen renders pixel-identical to NES; item-select cursor moves correctly; map view shows correct dots; OPTIONS submenu UI matches the locked reference mock; all flags toggle, persist across power cycle, and survive a `version` bump migration test (`tools/probes/test_options_migration.py`); the SRAM fixture test from S1 still passes (existing save layout untouched).
- **S8b — Simple active items** (~3–5 days): sword, boomerang, bombs, bow + arrows
  - Acceptance: per-item canonical movie probe; projectile spawn/despawn frame-accurate.
- **S8c — Traversal items** (~3–5 days): ladder, raft, recorder/flute (warp + dungeon-7 entrance)
  - Acceptance: traversal triggers fire on correct tile types; warp animation matches NES.
- **S8d — Economy / consumables / upgrades** (~3–5 days): candle (red/blue), food, potion (red/blue), letter, rings, magical sword, magic shield, book of magic, silver arrow, white sword
  - Acceptance: per-item state mutation probe (HP/inventory/flags) matches NES.

### S9 — Caves / NPCs (~2 wks)

- `src/game/cave/` — cave entry/exit, old man dialogue, shop, gambling, etc.
- Reference existing `cave_runtime.c` logic + NES disasm
- **Acceptance:** every cave type works pixel-perfect. Text rendering matches.

### S10 — Dungeons + Mode Dispatcher (~5–7 wks, split into sub-stages)

- **S10a — Dungeon room render + door states** (~1 wk)
  - Plane-A dungeon tilemap fill, door/wall state flags, dark-room masking
  - Acceptance: every dungeon room in Level 1 renders pixel-identical to NES; door-open/door-closed states match.
- **S10b — Dungeon collision + interactables** (~1 wk)
  - Push blocks, stairs, raftable squares, conveyor squares, fire trap projectiles
  - Acceptance: per-interactable canonical-movie probe.
- **S10c — Locked doors, keys, map, compass** (~1 wk)
  - Key inventory, locked-door consumption, map/compass effect on pause-screen rendering
  - Acceptance: key count matches NES across pickup → use; map/compass UI updates frame-accurately.
- **S10d — Mode dispatcher + Level 1 end-to-end** (~1–2 wks)
  - `src/game/mode/mode_runtime.c` — overworld / dungeon / cave / pause / death / continue / ending
  - Triforce piece pickup transition
  - Acceptance: Level 1 fully playable end-to-end on canonical movie; triforce-pickup transition pixel-identical.
- **S10e — All 9 dungeon layouts smoke test** (~1 wk)
  - `tools/probes/batch_dungeon_render.py` loads + renders every room in all 9 dungeons from extracted data
  - Acceptance: zero normalized mismatches across the full dungeon room set.

### S11 — Audio Final Integration (~1–2 wks)

S1 already exposed the C-facing audio event API (`audio_music_play`, `audio_sfx_play`, `audio_tick_vblank`) via `src/sgdk_adapter/audio_adapter.c`. Stages S4–S10 already call this API with real or no-op-logging implementations. S11 completes the gameplay-wide audio path:

- Lock the driver choice: SGDK's XGM2 (preferred — maintained, format-flexible) or the inherited driver kept behind the adapter.
- Wire NES-extracted audio data (songs, sfx tables) into `data/audio/` in the chosen driver's input format.
- Replace no-op-logging hooks throughout C runtimes with real event triggers.
- **Acceptance:** all music tracks play correctly across overworld, every dungeon, cave, ending. SFX trigger frame-accurate against NES on canonical combat / item-pickup / door-unlock movies.

### S12 — Death / Continue / Save / Ending (~2 wks)

- Death sequence, game-over, continue prompt, save-to-SRAM, name-entry (already in FS), ending sequence
- **Acceptance:** full death+continue loop. Ending plays. SRAM save/load works.

### S13 — Second Quest + Polish (~2 wks)

- Second-quest patches via extractor flag
- Final pass: pixel-diff regressions, perf check VBlank budget, naming pass
- **Acceptance:** full first quest + second quest pixel-clean.

**Total (S0 + S1..S13): ~32–41 weeks (~8–10 months) at quality bar.** (S8 and S10 sub-stages add 2–4 weeks vs. the prior estimate.)

## 8. Cutover Discipline

For every stage:

1. Old shim path stays functional until new path passes acceptance.
2. Feature flag toggles new vs old at module boundary (mirror existing `vblank_mode`).
3. Once new path proves at quality bar, delete old path + flag in same commit.
4. Stage doesn't close until parity probe + screenshot diff archived.

**Deletion checkpoints (every deletion gated by caller audit):**

- After **S1**: delete `genesis_shell.asm` only after S0 caller audit + S1 audit confirm zero callers in any built ROM target. Otherwise mark deprecated and block new callers via lint.
- After **S3**: PPU write path is **deprecated** (lint blocks new callers). Deletion only when caller audit re-run proves zero remaining old-path callers across every supported build mode (main ROM, proof ROMs, demo ROMs). If any legacy module still depends on it, deletion defers to S10.
- After **S6**: `enemy_runtime_private.h` z01_*/z07_* externs deleted only after every caller is migrated; remaining uses block deletion and become S10 work.
- After **S10**: `nes_io.asm`, `c_shims.asm`, `src/zelda_translated/`, `src/gen/z_*.c` deleted in a single commit after final caller audit. ROM byte-size must drop by the expected amount; unexpected size means a missed dependency.
- After **S13**: any remaining transpile-era cruft.

### 8.1 Build Invariants (staged enforcement)

`tools/probes/lint_legacy_symbols.py` and a small set of structural greps run in CI. Each invariant starts warning-only at S0 and graduates to hard failure at the indicated stage.

| Invariant | Warn from | Fail from |
|---|---|---|
| No new `_ppu_*`, `_oam_*`, `_apu_*`, `_ctrl_*`, `_mmc1_*` callers in any new C/asm | S0 | S1 |
| No new `z01_*`..`z07_*` dependencies outside `src/abi/legacy_bridge.h` (transitional only) | S0 | S1 |
| No hardware register writes (VDP/CRAM/VSRAM/joypad/Z80 ports) outside SGDK itself | S0 | S1 (frontend), S3 (game subsystems as they migrate) |
| No asm files under `src/` outside `src/sgdk_adapter/asm/` (and that path requires a profiling-justification comment per file) | S0 | S1 (post-reorg) |
| No `nes_*` symbols anywhere | S6 | S13 |
| All state access through typed structs in `src/state/` (no raw `nes_ram[...]` outside compatibility shim) | S3 | S10 |
| Every file under `data/` is byte-reproducible from NES ROM via `tools/extract_*.py` | S2 | S2 |

## 9. Risks + Mitigations

| ID | Risk | Mitigation |
|---|---|---|
| R1 | Render API design wrong, redo mid-project | S1 ends with frontend running on new API at zero regression. Frontend is canary. Redesign before S2 if needed. |
| R2 | Pixel-perfect bar misses on rooms/enemies | Per-stage parity probes (BizHawk Lua → tool diff). No stage closes without diff = 0. |
| R3 | VBlank budget overrun once C carries DMA + sprite list | Instrument `vdp_wait_vblank` with cycle counter from S1. Per-stage perf check. Drop to inline asm in `render_kernel.s` only on hot path overrun. |
| R4 | Enemy AI behavioral drift (timing, RNG, off-by-one) | Per-family deterministic playback test — record NES inputs, replay on Genesis, frame-by-frame state diff. Built as core S6 tooling. |
| R5 | Stage 3+ blocked because S0 drain incomplete | S1 doesn't depend on transpile drain. Old shim/transpile path stays running through S10. C runtimes still calling z01_*/z07_* keep working through cutover. |
| R6 | Two render code paths drift | S1 cuts frontend off shim entirely. After S1, frontend ONLY uses new render API. Single-owner per code path. |
| R7 | Save format / SRAM incompatibility | SRAM byte layout preserved. Existing saves load post-rewrite. Verified at S12. |
| R8 | Audio glitches when frame loop changes | Audio runs from VBlank IRQ via existing `music_tick`. Decoupled from main loop. S1 verifies music plays under new loop. |
| R9 | Reorg breaks build for days | `git mv` series, commit each subdir, build green between commits. Worst case revert one commit. Reorg never combined with logic rewrite. |
| R10 | Scope creep / "while we're at it" drift | Spec is the contract. New ideas → separate task, not folded in. |

## 10. Verification Machinery

```
tools/probes/
  bizhawk_capture_nes.lua       NES PPU/RAM/OAM dump per frame
  bizhawk_capture_gen.lua       Genesis VDP/CRAM/VRAM/SAT dump per frame
  diff_capture.py               byte-diff two captures, report mismatches
  parity_run.py                 boot Genesis ROM + NES ROM, sync inputs, frame-loop diff
  cycle_probe.lua               VBlank budget tracking
```

**Per-stage acceptance template:**

1. Run NES ROM in BizHawk to canonical state (recorded input file).
2. Capture: PPU palette, OAM, nametable, scroll, RAM.
3. Run Genesis ROM to same state.
4. Capture: CRAM, SAT, VRAM tilemap, VSRAM scroll, RAM.
5. Diff via parity tool — must be 0 mismatches on covered surfaces.
6. Record screenshot pair into `builds/reports/` for archive.

## 11. Final State (Post-S13)

**Source budget (owned code only; SGDK is third-party):**
- `src/sgdk_adapter/` ~800 lines C (render/audio/joy/sram adapters)
- `src/abi/` ~80 lines (headers only)
- `src/frontend/` ~4000 lines C
- `src/game/` ~15000 lines C
- `src/state/` ~500 lines
- `src/core/` ~300 lines

**Owned total: ~21K lines C, near-zero owned asm.** Down from ~60K today (mostly transpiled + shim). **Net −65%.** SGDK provides the platform/render layer outside this budget.

**Deleted at S13:**
- `src/zelda_translated/` (entire)
- `src/gen/z_*.c` (all transpile adapters)
- `src/nes_io.asm`, `src/c_shims.asm`, `src/genesis_shell.asm`
- `src/c_move_object.c`, `src/c_wanderer.c` (folded into runtimes)
- `src/nes_abi.h` → replaced by SGDK's headers + `src/abi/*.h` adapter prototypes
- `*.bak`, `*- Copy*`, top-level `Zelda1-Redux/`, stray zips/midis/build_out logs

**Renamed at S13:**
- `NES_RAM` → `WORK_RAM`
- `NES_OBJ_TYPE` → `obj.type` field access
- `nes_ram[NES_SRAM_BASE+x]` → `sram_buffer[x]` or `save.field`
- All `_ppu_*` / `_oam_*` / `_apu_*` / `_ctrl_*` / `_mmc1_*` symbols — gone
- `z01_*` … `z07_*` symbols — gone
- `gen/intro_*` data files → `data/intro/*`
- `gen/fs_*` data files → `data/fs/*`

**Memory updates at completion:**

- `project_chr_expansion.md` — resolved (SGDK sprite engine handles palette allocation)
- `project_vfix_dead_zone.md` — resolved (no V64 PPU emulation)
- `project_title_story_crash.md` — resolved (no transpiled story scroll)
- `project_midi_fs_integration.md` — resolved (FS runs on SGDK + adapter; audio integrated cleanly)
- `project_what_if.md` — milestone sequence T1→T14 superseded by S1→S13
- `project_best_practices.md` — north star achieved (SGDK is the platform layer; owned C is gameplay)
- `feedback_transpiler_correctness.md` — obsolete, archive
- `feedback_ccr_x_flag.md` — obsolete, archive
- `feedback_drain_size_preserving.md` — obsolete, archive

**Final invariants enforced post-S13:**

- No file under `src/game/` or `src/frontend/` touches hardware registers (VDP/CRAM/VSRAM/joypad/Z80 ports) directly. All hardware access goes through SGDK; gameplay calls SGDK or our `src/sgdk_adapter/`.
- No assembly under `src/` outside `src/sgdk_adapter/asm/`, and any file there must carry a profiling-justification comment header.
- `src/abi/` contains headers only.
- No file references `nes_*` symbols or `_ppu_*` / `_oam_*` / `_apu_*` / `_ctrl_*` / `_mmc1_*` / `z01_*..z07_*` symbols.
- All state access through typed structs in `src/state/`.
- All data files under `data/` are byte-reproducible from NES ROM via `tools/extract_*.py`; SHA manifest under `data/MANIFEST.sha256`.
- No C↔asm function passes or returns structs by value.
- SGDK version is locked at S0 (`sgdk/VERSION` or submodule SHA); upgrades are explicit spec amendments.

## 12. S0-Locked Questions

**Resolved at S0.** See `docs/audit/s0_close.md` for the full close-out
summary; per-question evidence is in the named audit docs.

| # | Question | Resolution | Evidence |
|---|---|---|---|
| Q1 | Active Genesis baseline ROM | `4bcfc1d916f44f31f36ee5bc0862b6b696313a264ffcc8373abde87d318befb4` (`builds/whatif.md`) | `docs/audit/baseline_rom.md` |
| Q2 | Capture geometry | H32 / 256×224 / NES top-crop +8 | `docs/audit/capture_geometry.md` |
| Q3 | ABI proof | D0 for u32 + pointer returns; args on stack; A4 untouched (`-ffixed-a4`) | `docs/audit/abi_probe.md` |
| Q4 | Normalized parity schema lock | **Deferred to S1** — manual NES↔Genesis capture validation requires BizHawk runs (skipped in S0) | `docs/audit/parity_schema_check.md` |
| Q5 | Audio responsibility split | Wrapper plan recorded; existing driver kept through S1, XGM2 swap deferred to S11 | `docs/audit/audio_split_plan.md` |
| Q6 | Render-API public boundary | `src/abi/render_abi.h` (SGDK headers + adapter prototypes); lint enforces from S1 | spec Section 6 |
| Q7 | NES ROM provenance | Not committed; SHA256 verified at runtime by `tools/probes/locate_reference_rom.py` | `docs/audit/toolchain.md`, `tools/probes/locate_reference_rom.py` |
| Q8 | SGDK version | **Pinned `v2.11`** (commit `ef9292c0`); bumped from v2.00 paper-pin to current stable; build chain verified via `sample/basics/hello-world` smoke test | `docs/audit/sgdk_integration.md` |
| Q9 | SGDK vendoring | **Done** — git submodule at `sgdk/` (post-S0, 2026-04-28) | `docs/audit/sgdk_integration.md`, `.gitmodules` |
| Q10 | A4 register conflict | **SAFE** — SGDK does not touch A4 in boot or runtime; `-ffixed-a4` convention preserved | `docs/audit/sgdk_integration.md` |

One remaining deferral (Q4) is tracked as the first S1 acceptance step;
mitigation plan is in `docs/audit/parity_schema_check.md`. Q8/Q9/Q10
resolved post-S0 in the autonomous SGDK-vendoring session.

## 13. References

- `best practices.md` — north star (owned C, gen/ passive, ASM only boot/IO/hot — SGDK satisfies the IO/hot half)
- **SGDK** — `https://github.com/Stephane-D/SGDK`, pinned at **v2.11** (commit `ef9292c0`), vendored as a git submodule at `sgdk/`. Adopted as the platform/render layer. Build chain confirmed end-to-end via `sgdk/sample/basics/hello-world`. See `docs/audit/sgdk_integration.md`.
- WHAT IF (`C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\`) — read-only **data-extraction reference** only. Architectural lifts no longer apply now that SGDK provides the render layer.
  **The build never reads this path.** Any scripts or data borrowed from WHAT IF are copied into `tools/` or `data/`, with the source commit hash and date recorded in a header comment per copied file. FINAL TRY remains reproducible without WHAT IF on disk.
- `reference/aldonunez/` — NES disassembly, semantic reference (checked in at S0 or S2)
- Memory: `feedback_long_term_fix.md`, `feedback_full_native_rewrite.md`, `project_best_practices.md`, `project_title_screen_goal.md`
- Existing native modules as quality reference: `intro_*`, `fs_*`, `frontend_runtime.c`
