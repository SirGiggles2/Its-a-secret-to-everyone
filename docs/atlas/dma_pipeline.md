# DMA Pipeline — VRAM + CRAM Upload Map
*(Phase BB, written 2026-05-19 session 6 close)*

## Purpose
Single doc tracing every byte uploaded to VDP per scene. Wall-clock
budget per VBlank ≈ 7790 B (per `vendor/SGDK/inc/dma.h` Z80-pause-aware
limit). Every upload site below must fit either in VBlank or
across multiple VBlanks via state-machine chunking.

## Upload primitive surface (`src/abi/render_abi.h`)

| API | Target | Used for |
|---|---|---|
| `render_chr_upload(vram_addr, src, byte_count)` | VRAM tile data | Static atlas blobs, scene init |
| `render_cram_upload(src, count_words)` | CRAM (palette) | Scene full-palette load |
| `render_cram_subrange_upload(start_slot, src, count)` | CRAM range | Per-frame palette FX, sub-pal swap |

All three drain through SGDK's queued DMA (`DMA_doDma` / `VDP_doVRamDMA`
etc.) — see `src/sgdk_adapter/render_adapter.c:255-330`.

## Per-scene upload totals (current, post Phase J/J.2/K)

### Gameplay scene init (one-time per scene transition)

| Site | File:line | Bytes | Trigger |
|---:|---|---:|---|
| BG sparse atlas | `ow_render.c:256` / `uw_render.c:206` | **17024** | Scene boot or map_id flip |
| SPR common bank | `sprite_render.c:241` | **7616** | First gameplay scene |
| ITEM atlas (4 sub-pal copies) | `sprite_render.c:282` | 4 x **3136** = 12544 | First gameplay scene |
| SCENE_OBJ swap (UWSP / OWSP / boss) | `level_chr_swap.c` half-A/half-B | 1088-2048 per swap | Level enter |
| Cloud meta CHR | `enemy_render.c:276` | ~256 | First cloud spawn (lazy) |
| **Gameplay scene init total** | | **~37 KB** | One-time per fresh scene |

### Gameplay per-frame (recurring)

| Site | File:line | Bytes | Trigger |
|---:|---|---:|---|
| transfer_buf CRAM batch | `transfer_buf_drain.c:80` | ≤ **96 B** (typical 32-64) | NES PALRAM mirror dirty |
| Sword beam sub-pal swap | `combat_runtime.c:361` | **8 B** (4 CRAM words) | Beam pal cycle (every 4 ticks) |
| Cave palette overlay | `cave_palette.c:19` | **16 B** (8 CRAM words) | Cave entry |
| **Per-frame typical** | | **~32-256 B** | Idle / combat |

### Frontend scene init

| Scene | Site | Bytes | Notes |
|---:|---|---:|---|
| Title BG | `intro_title.c:226` | ~3 KB | First boot |
| Title SPR | `intro_title.c:228` | ~1 KB | First boot |
| Title CRAM full | `intro_title.c:239` | 128 (64 words) | Boot |
| Title fade cycles | `intro_title.c:279` | 128 per frame | Fade FX (transient) |
| Story BG common | `intro_story.c:134` | ~3 KB | Story boot |
| Story font | `intro_story.c:136` | ~1.5 KB | Story boot |
| Story misc/punct/blink | `intro_story.c:138-144` | ~2 KB total | Story boot |
| Story CRAM | `intro_story.c:158` | 128 | Story boot |
| FS BG/SPR | `fs_main.c:59-73` | ~4 KB | File select boot |
| **Title boot total** | | **~5 KB** | One-time |
| **Story boot total** | | **~7 KB** | One-time |
| **FS boot total** | | **~4 KB** | One-time |

## Worst-case VBlank scenarios

### Scenario A: Cold gameplay scene boot (first frame)
- BG sparse atlas: 17024 B → **requires multi-frame chunking** (level_chr_swap state machine)
- SPR common + ITEM atlas: 20160 B → multi-frame
- SCENE_OBJ swap: 1088 B → fits one VBlank
- **Mitigation:** state-machine breaks upload across N frames; user sees scene fade-in rather than instant snap.

### Scenario B: Mid-game frame (steady state)
- transfer_buf: 32-96 B
- Sword beam pal swap: 8 B
- **Total: < 256 B per frame** — comfortable margin (~30x under VBlank ceiling)

### Scenario C: Scene transition (room scroll)
- Scroll-stage uses plane B as staging; no CHR re-upload during scroll
- CRAM swap at scroll-complete: 32-64 B
- **Total: < 128 B during transition** — fits

### Scenario D: SCENE_OBJ bank swap (level transition / boss intro)
- BLANK fill (clears 4352 B in old slot): 4352 B
- New bank upload (half A + half B): 544 + 544 = 1088 B
- Palette swap: 64 B
- **Total: ~5504 B over 2 VBlanks** (half-A frame N, half-B frame N+1)

## Upload-cost summary

| Phase | When | Frequency | Bytes |
|---|---|---:|---:|
| Scene init | Once per gameplay scene | Rare | ~37 KB (chunked across N VBlanks) |
| Bank swap | Per level transition | Per-level | ~5.5 KB across 2 VBlanks |
| Per-frame steady | Every frame | 60 Hz | < 256 B |
| Scroll transition | Per room scroll | Per-room | < 128 B |

## Observability gaps

- **No live byte counter**: SGDK adapter (`render_adapter.c`) does not
  instrument `render_chr_upload` / `render_cram_upload` with a
  per-frame accumulator. Current Phase Q probe
  (`dma_telemetry_probe.lua`) infers via wall-clock frame timing
  (>18 ms) — coarse proxy.
- **Mitigation planned (Phase Q v2):** add `render_dma_stats_get()`
  returning max-bytes-this-frame; wire BizHawk Lua probe to read it.

## DMA payload reductions shipped (sessions 1-6 cumulative)

| Phase | Site | Before | After | Savings |
|---|---|---:|---:|---:|
| B | ITEM atlas (sprite) | 4 x 1920 = 7680 B | 4 x 3136 = 12544 B* | (atlas grew due to Phase K; per-sub-pal still 1x) |
| F | UWSP enemy bank | 4352 B (4x) | 1088 B (1x) | **-75%** |
| J | BG bank | 32768 B (4x) | 17024 B (sparse) | **-48%** |
| J.2 | BG bank (post bank shift) | — | 17024 B (incl 4 variants stored in ROM) | VRAM headroom 154 → 618 |
| R | transfer_buf | 16 indiv writes | 1 batched subrange | per-frame storm CRAM op count drops ~10x |

*ITEM atlas growth is content (15 extracted pickup items + animation frames) not pixel-bias overhead.

## Verification

`tools/debug/dma_telemetry_probe.lua` flags frames > 18 ms wall-clock.
Phase Q v2 (next) replaces wall-clock proxy with instrumented byte
counter for precise per-frame VBlank utilization measurement.
