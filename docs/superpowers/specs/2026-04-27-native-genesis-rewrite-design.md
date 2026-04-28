# Native Genesis Rewrite — Design Spec

**Date:** 2026-04-27
**Status:** Approved for S0; S1 gated on S0 close
**Path:** E — WHAT IF as reference, rebuild render/room/data layer in C inside FINAL TRY tree
**Quality bar:** Pixel-perfect to NES, matching the title + file-select fidelity standard

---

## 0. Reference Contract

The "golden reference" against which every parity check runs. All values are filled at S0 close and frozen for the project lifespan; bumps require explicit spec amendment.

**Fixed inputs:**

- **NES ROM SHA256:** `<filled at S0 — Legend of Zelda, The (USA).nes>`
- **Current Genesis ROM SHA256 (baseline):** `<filled at S0 — current FINAL TRY known-good ROM>`
- **NES emulator + version:** BizHawk 2.11 (NES core: `<filled at S0>`)
- **Genesis emulator + version:** BizHawk 2.11 (Genesis core: `<filled at S0>`)
- **NES screen palette (RGB):** `<filled at S0 — name and source, e.g. FCEUX default 2C02 or PaletteFromNESHueDecoder>`
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
- **RGB screenshot parity (final-frame visual stages):** PNG-vs-PNG diff after color normalization. Capture geometry is locked at S0:
  - Genesis display mode (H32 or H40) — locked at S0
  - RGB viewport size — locked at S0
  - Crop origin (top-left of comparison region) — locked at S0
  - Overscan policy (ignored or included) — locked at S0
  - Backdrop / transparent color policy — locked at S0
  - Screenshot scaling — none, 1:1 pixel comparison only
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

## 3. Approach (Path E)

WHAT IF (`C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF`) is treated as a **read-only architectural reference**:

- Borrow extracted data files (CHR, palettes, rooms, enemies, items, text, audio).
- Borrow Python extraction scripts (`extract_chr.py`, `extract_rooms.py`, etc.) — copy into `tools/`.
- Borrow architectural decisions (DMA queue shape, sprite slot allocation, plane layout) by reading WHAT IF asm and re-implementing the same ideas in C.
- Do **not** lift WHAT IF asm into FINAL TRY. WHAT IF stays untouched at its current path.

NES disassembly (`reference/aldonunez/`) is the second reference for game-logic semantics.

The active development tree is FINAL TRY. All new code lands here. The repo is reorganized into a clean role-based layout (Section 6) and the existing owned C survives (relocated, not rewritten unless tied to transpile-era patterns).

## 4. Architecture

Three layers, top-down:

```
GAMEPLAY (C, owned) — frontend, game/{mode,world,room,link,combat,enemies,
                       items,hud,cave}, state, core
        │ C ABI: render_*, room_*, sprite_*, scroll_*, dma_queue_*, pal_*
        ▼
RENDER (C, owned)   — render/{vdp,dma_queue,tilemap,sprite,scroll,chr,palette}
                      + optional render_kernel.s (hot DMA inner loops)
        │ raw VDP / 68K
        ▼
PLATFORM (asm, minimal) — platform/{main,vdp_regs,vdp_dma,joypad,vblank,glue,audio_driver}
                          plus boot vectors and reset
        │
        ▼
HARDWARE — Genesis VDP, M68K, Z80 audio
```

The middle layer (`render/`) is pure C with optional small inline asm. No game logic in asm. No NES emulation anywhere.

### 4.1 Render API (C, callable from any runtime)

The public render API is exposed via `src/abi/render_abi.h`. Gameplay and frontend code include only that header. Private render headers under `src/render/` are visible only to `src/render/*.c`.

```c
// render_abi.h — single public include for game/frontend

// vdp.h — mode + lifecycle
void vdp_init(void);
void vdp_set_display(bool on);
void vdp_wait_vblank(void);

// dma_queue.h — submission queue, flushed in VBlank
typedef enum { DMA_VRAM, DMA_CRAM, DMA_VSRAM } dma_target_t;
bool dma_q_submit(dma_target_t tgt, u16 dst, const void *src, u16 word_count);
void dma_q_flush(void);
u16  dma_q_words_remaining(void);
u16  dma_q_entries_remaining(void);
u16  dma_q_overflow_count(void);
void dma_q_reset_frame_stats(void);

// tilemap.h
void tm_plane_a_write_word(u16 col, u16 row, u16 word);
void tm_plane_a_fill_rect(u16 col, u16 row, u16 w, u16 h, u16 word);
void tm_plane_a_row(u16 col, u16 row, const u16 *src, u16 count);
void tm_plane_a_col(u16 col, u16 row, const u16 *src, u16 count);
void tm_plane_b_write_word(u16 col, u16 row, u16 word);
void tm_plane_b_fill_rect(u16 col, u16 row, u16 w, u16 h, u16 word);
void tm_plane_b_row(u16 col, u16 row, const u16 *src, u16 count);
void tm_plane_b_col(u16 col, u16 row, const u16 *src, u16 count);

// sprite.h — 80-slot manager
typedef struct {
    s16 y, x;
    u16 tile_attr;
    u8  size;
    u8  link_next;
} sprite_slot_t;
u8   spr_alloc(u8 owner_tag);
void spr_free(u8 slot);
void spr_set(u8 slot, const sprite_slot_t *s);
void spr_clear_owner(u8 owner_tag);
void spr_commit(void);

// scroll.h
void scr_set_plane_a(s16 x, s16 y);
void scr_set_plane_b(s16 x, s16 y);
void scr_room_transition_h(s16 dx);
void scr_room_transition_v(s16 dy);
void scr_apply(void);     // VBlank: write final h/v scroll values

// chr.h
void chr_upload(u16 vram_addr, const void *src, u16 byte_count);
void chr_upload_sync(u16 vram_addr, const void *src, u16 byte_count);

// palette.h
void pal_load(u8 pal_index, const u16 *src);
void pal_set_color(u8 pal, u8 idx, u16 color);
void pal_fade_to(const u16 *target, u8 step);

// audio.h — C-facing event API, available from S1 onward
void audio_music_play(u8 song_id);
void audio_sfx_play(u8 sfx_id);
void audio_tick_vblank(void);    // called from VBlank ISR

// joypad.h
void joy_read(void);
u16  joy_state(u8 port);
```

### 4.2 Frame Loop

```c
void main_loop(void) {
    while (1) {
        game_tick();           // mode_runtime dispatches active mode
        spr_commit();          // build sprite RAM mirror, mark dirty
        vdp_wait_vblank();
        dma_q_flush();         // CHR + tilemap + palette uploads, then SAT DMA last
        scr_apply();           // write final h/v scroll values
        joy_read();
        debug_assert(dma_q_overflow_count() == 0);
        dma_q_reset_frame_stats();
    }
}
```

The VBlank ISR is minimal: increment frame counter, call `audio_tick_vblank()`, set vblank-pending flag. **No game logic in interrupts.** Eliminates NMI re-entry race bugs entirely. `audio_tick_vblank()` may wrap the existing `music_tick` driver entry during transition; the public contract name is `audio_tick_vblank`.

**SAT (sprite attribute table) upload contract:** `spr_commit()` builds the SAT RAM mirror and marks it dirty. `dma_q_flush()` always performs the SAT DMA last when the mirror is dirty; SAT upload does not consume normal queue entries and cannot be denied by queue overflow. This guarantees sprite output regardless of bulk-transfer pressure (e.g. CHR uploads on room load).

### 4.3 Shim → Native Mapping

| Shim primitive | Native replacement |
|---|---|
| `_ppu_write_2006` (addr) | direct VRAM addr arg to `tm_*` / `chr_upload` |
| `_ppu_write_2007` (data) | `tm_plane_a_row` / `chr_upload` (queued) |
| `_ppu_write_2005` (scroll) | `scr_set_plane_a(x, y)` |
| `_ppu_write_2001` (mask) | `vdp_set_display(on/off)` |
| `_oam_dma(page)` | `spr_set` per slot + `spr_commit` |
| `_ppu_write_3F00..3F1F` | `pal_set_color(pal, idx, color)` |
| NES NMI handler | nothing — main loop owns timing |
| `_apu_*` | `audio_*` (existing native driver) |
| `_ctrl_*` | `joy_read()` / `joy_state(port)` |
| `_mmc1_*` | nothing — Genesis flat ROM |

### 4.4 RAM Convention

Work RAM stays at `$FF0000`. The base address is arbitrary; only the convention is preserved. State headers migrate field-by-field from NES_-prefixed accessors to typed Genesis-shaped structs over the project lifespan. Deprecated names alias new ones during transition.

### 4.5 ABI Contract

Locked at S0 and held constant through S13.

**Toolchain:**

- **C compiler:** `<filled at S0 — current toolchain, likely m68k-elf-gcc or vbcc>`, version `<filled at S0>`. Optimization level fixed per build profile.
- **Assembler:** vasm Motorola syntax (`vasmm68k_mot.exe`), version `<filled at S0>`.
- **Linker:** `<filled at S0>`. Single linker script under `src/platform/`.

**Calling convention (C ↔ asm):**

- Standard System V m68k ABI as emitted by the chosen C compiler. All cross-language calls go through C-declared prototypes in `src/abi/*.h`; no implicit ABI assumptions.
- **Caller-saved (clobberable by callee):** D0, D1, A0, A1.
- **Callee-saved (must preserve):** D2–D7, A2–A6.
- A7 is the M68K stack pointer; never touched outside platform code.
- Return values: locked at S0 by inspecting compiler output of `tools/probes/abi_probe.c` (see S0 acceptance). The probe defines and exports listing for `u32 abi_ret_u32(void)`, `void *abi_ret_ptr(void)`, `u32 abi_arg_mix(u16 a, u32 b, void *p)`. Result is recorded in `docs/audit/abi_probe.md` (registers used, stack frame, callee-save behavior). No "unless" clauses remain post-S0.
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

## 6. Repo Layout (Reorg)

```
final-try/
├── src/
│   ├── platform/          68K asm — boot, vectors, raw IO primitives
│   │   ├── main.asm           ROM header, vectors, reset
│   │   ├── vdp_regs.asm       VDP register helpers (raw writes only)
│   │   ├── vdp_dma.asm        raw RAM→VDP DMA primitive (no queue logic)
│   │   ├── joypad.asm         controller read primitive
│   │   ├── vblank.asm         VBlank ISR entry, frame counter, music_tick dispatch
│   │   ├── glue.asm           tiny C↔asm trampolines if any
│   │   └── audio_driver.asm   Z80 / FM driver bootstrap
│   ├── render/            C, owned
│   │   ├── vdp.c/.h
│   │   ├── dma_queue.c/.h
│   │   ├── tilemap.c/.h
│   │   ├── sprite.c/.h
│   │   ├── scroll.c/.h
│   │   ├── chr.c/.h
│   │   ├── palette.c/.h
│   │   └── render_kernel.s    optional, hot path only
│   ├── abi/               headers only — no assembly here
│   │   ├── platform_abi.h     (renamed from nes_abi.h)
│   │   ├── render_abi.h       single public include for game/frontend
│   │   └── legacy_bridge.h    transitional z01_*/z07_* externs only; deleted by S10
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
├── data/                  extracted Genesis-ready data
│   ├── chr/, palettes/, rooms/, enemies/, items/, audio/
├── tools/                 Python extractors, build scripts, probes
├── reference/             NES disasm + ROM metadata only; NES ROM is never committed
├── docs/                  design docs, specs, dev notes
└── builds/                output ROMs, listings, archives, reports
```

**Conventions (locked once, applied everywhere):**

- C files lowercase, snake_case, `<subsystem>_<role>.{c,h}` (e.g. `link_runtime.c`)
- State headers always `<subsystem>_state.h`, RAM addresses centralized in `src/state/`
- One subsystem per dir; cross-dir includes allowed only via `src/state/*.h`, `src/abi/*.h`, `src/core/*.h`
- **Gameplay (`src/game/`) and frontend (`src/frontend/`) include render only through `src/abi/render_abi.h`.** Private render headers under `src/render/` are visible only to `src/render/*.c`.
- **No subsystem may include transpiled headers directly during cutover.** Legacy `z01_*..z07_*` calls go only through `src/abi/legacy_bridge.h`. That header is deleted at S10.
- All assembly lives under `src/platform/`, with the single optional exception `src/render/render_kernel.s` for hot-path inner loops. `src/abi/` contains C/asm-facing **headers only** — never `.asm` or `.s`.
- Hardware register access (VDP control/data ports, CRAM, VSRAM, joypad, Z80 ports) is allowed only inside:
  - `src/platform/` (raw primitives, ISR entry, boot)
  - `src/render/` low-level files: `vdp.c`, `dma_queue.c`, `chr.c`, `palette.c`
  - Higher-level render files (`tilemap.c`, `sprite.c`, `scroll.c`) go through the low-level files; gameplay never goes around them.
- Owned C is the real codebase; `data/` is passive (byte-reproducible from NES ROM); `gen/` no longer exists post-reorg.

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
- Build and inspect `tools/probes/abi_probe.c` (`u32 abi_ret_u32(void)`, `void *abi_ret_ptr(void)`, `u32 abi_arg_mix(u16, u32, void *)`); commit listing to `docs/audit/abi_probe.md` with proven calling-convention details. Replace every `<filled at S0>` placeholder in Section 4.5.
- Lock NES ROM provenance: ROM is **not committed**. `tools/probes/locate_reference_rom.py` resolves the ROM path via local config or `ZELDA_NES_ROM` env var, verifies SHA256 against the value recorded in Section 0, and is called by every probe before extraction.
- Fill the `<filled at S0>` placeholders in **Section 0 (Reference Contract)**: ROM hashes, current Genesis baseline ROM hash, emulator versions, palette, viewport/crop/overscan/backdrop/H-mode policy.
- Resolve the **S0-Locked Questions** in Section 12.
- **Acceptance:** current build still produces a working ROM with no behavioral change. All audit documents committed. Lint check runs in CI. Reference + ABI contracts have no remaining placeholders. Section 12 reduced to "None."

### S1 — Repo Reorg + Render Floor (~2–3 wks)

- New tree under `src/` (Section 6)
- Move owned C with `git mv` preserving history (each subdir its own commit, build green between commits)
- Build pipeline rewired (single `build.bat`)
- **Render floor implemented**: real minimal native VDP/tilemap/palette/sprite/DMA behavior — enough to run the existing frontend natively at parity. Not stubs. Specifically:
  - `vdp_init`, `vdp_wait_vblank`, `vdp_set_display` fully functional
  - `dma_q_submit` + `dma_q_flush` with a working queue sized for current frontend's per-frame transfer count
  - `tm_plane_a_*` and `tm_plane_b_*` writes (queued path only)
  - `chr_upload` + `chr_upload_sync`
  - `pal_load`, `pal_set_color`, `pal_fade_to`
  - `spr_alloc`, `spr_set`, `spr_commit` with 80-slot manager
  - `scr_set_plane_a`, `scr_set_plane_b`, `scr_apply`
  - `joy_read` / `joy_state`
- Frontend (title + intro + FS) re-pointed onto new render API. Local ad-hoc `vdp_set_mode_v32`, `vdp_load_cram_at`, `VDP_CTRL_WORD` writes inside intro/fs files are replaced by render-API calls.
- **SRAM fixture added:** `tools/probes/sram_layout_test.c` — known SRAM blob from current build, typed-struct offset static asserts, load/save roundtrip test. Runs in CI from S1 onward.
- **Audio preservation:** existing audio bootstrap is preserved well enough that title/intro/FS music plays under the new frame loop. The C-facing audio event API (`audio_music_play`, `audio_sfx_play`, `audio_tick_vblank`) is wired in S1, even if its implementation initially forwards to the existing driver. Stages S4–S10 may call this API as no-op-logging or real hooks before S11 completes integration.
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

S1 already preserved frontend music under the new frame loop and exposed the C-facing audio event API (`audio_music_play`, `audio_sfx_play`, `audio_tick_vblank`). Stages S4–S10 already call this API with real or no-op-logging implementations. S11 completes the gameplay-wide audio path:

- Replace any provisional driver glue with the final native driver under `src/platform/audio_driver.asm`
- Wire WHAT IF audio data extraction (songs, sfx tables) into `data/audio/`
- Replace no-op-logging hooks throughout C runtimes with real event triggers
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
| No hardware register writes (VDP/CRAM/VSRAM/joypad/Z80 ports) outside `src/platform/` and `src/render/` | S0 | S1 (frontend), S3 (game subsystems as they migrate) |
| No asm files outside `src/platform/` and `src/render/render_kernel.s` | S0 | S1 (post-reorg) |
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

**Source budget:**
- `src/platform/` ~500 lines asm (boot, vectors, vblank, joypad, audio bootstrap)
- `src/render/` ~3000 lines C + ~150 lines asm (`render_kernel.s`, only if needed)
- `src/abi/` ~50 lines
- `src/frontend/` ~4000 lines C
- `src/game/` ~15000 lines C
- `src/state/` ~500 lines
- `src/core/` ~300 lines

**Total: ~25K lines C + ~700 lines asm.** Down from ~60K today (mostly transpiled + shim). **Net −58%.**

**Deleted at S13:**
- `src/zelda_translated/` (entire)
- `src/gen/z_*.c` (all transpile adapters)
- `src/nes_io.asm`, `src/c_shims.asm`, `src/genesis_shell.asm`
- `src/c_move_object.c`, `src/c_wanderer.c` (folded into runtimes)
- `src/nes_abi.h` → renamed/shrunk to `src/abi/platform_abi.h`
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

- `project_chr_expansion.md` — resolved (no sprite multiplex problem under native sprite mgr)
- `project_vfix_dead_zone.md` — resolved (no V64 PPU emulation)
- `project_title_story_crash.md` — resolved (no transpiled story scroll)
- `project_midi_fs_integration.md` — resolved (FS runs on native, music plays cleanly)
- `project_what_if.md` — milestone sequence T1→T14 superseded by S1→S13
- `project_best_practices.md` — north star achieved, gen/ retired
- `feedback_transpiler_correctness.md` — obsolete, archive
- `feedback_ccr_x_flag.md` — obsolete, archive
- `feedback_drain_size_preserving.md` — obsolete, archive

**Final invariants enforced post-S13:**

- No file under `src/game/` or `src/frontend/` touches hardware registers (VDP/CRAM/VSRAM/joypad/Z80 ports) directly. Render is the only abstraction these layers see; the public surface is `src/abi/render_abi.h`.
- `src/render/` may touch hardware only through render-owned low-level files (`vdp.c`, `dma_queue.c`, `chr.c`, `palette.c`). Higher-level render files (`tilemap.c`, `sprite.c`, `scroll.c`) go through those low-level files.
- `src/platform/` owns boot, vectors, joypad primitive, Z80/audio bootstrap, raw interrupt entry, and raw DMA primitive.
- No assembly outside `src/platform/` and `src/render/render_kernel.s`. `src/abi/` contains headers only.
- No file references `nes_*` symbols or `_ppu_*` / `_oam_*` / `_apu_*` / `_ctrl_*` / `_mmc1_*` / `z01_*..z07_*` symbols.
- All state access through typed structs in `src/state/`.
- All data files under `data/` are byte-reproducible from NES ROM via `tools/extract_*.py`; SHA manifest under `data/MANIFEST.sha256`.
- No C↔asm function passes or returns structs by value.

## 12. S0-Locked Questions

These must be resolved before S1 begins. S0 closes by recording answers and reducing this section to **None**.

1. **Active Genesis baseline ROM** — must be the current FINAL TRY known-good build unless explicitly amended. WHAT IF is architectural reference only, never the parity baseline.
2. **Capture geometry** — Genesis display mode (H32 / H40), RGB viewport size, crop origin, overscan policy, backdrop / transparent color policy.
3. **ABI proof** — `tools/probes/abi_probe.c` and listing output committed under `docs/audit/abi_probe.md`. Pointer return register, argument passing, callee-saved register set are recorded from actual compiler output. Confirm the no-struct-by-value rule holds for the chosen toolchain.
4. **Normalized parity schema lock** — confirm `tools/probes/normalize_nes.py` and `tools/probes/normalize_gen.py` produce schema instances that diff cleanly on a known-equivalent screen pair (e.g. start-room from current FINAL TRY ROM vs NES ROM after manual eyeball check).
5. **Audio responsibility split** — confirm S1 preservation of frontend music is reachable with existing `audio_driver.asm` under the new frame loop. Confirm S11 receives the gameplay-wide audio integration debt without S4–S10 being blocked.
6. **Render-API public boundary** — confirm `src/abi/render_abi.h` is the only render-facing include for game/frontend. Lint enforces.
7. **Reference ROM provenance** — confirm `tools/probes/locate_reference_rom.py` resolves the NES ROM via local config or `ZELDA_NES_ROM` env var and verifies SHA256 before any extraction or probe runs. Confirm ROM is not committed to repo.

## 13. References

- `best practices.md` — north star (owned C, gen/ passive, ASM only boot/IO/hot)
- WHAT IF (`C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\`) — architectural reference, read-only.
  **The build never reads this path.** Any scripts, data, or layout decisions borrowed from WHAT IF are copied into `tools/`, `data/`, or this spec, with the source commit hash and date recorded in a header comment per copied file. FINAL TRY remains reproducible without WHAT IF on disk.
- `reference/aldonunez/` — NES disassembly, semantic reference (checked in at S0 or S2)
- Memory: `feedback_long_term_fix.md`, `feedback_full_native_rewrite.md`, `project_best_practices.md`, `project_title_screen_goal.md`
- Existing native modules as quality reference: `intro_*`, `fs_*`, `frontend_runtime.c`
