/* palette_state.h — NES PALRAM mirror + Genesis CRAM cache.
 *
 * Phase 2 (Graphics Registry) per docs/audit/state_contract.md migration
 * order. Typed-struct promotion target for palette state.
 *
 * NES PALRAM is 32 bytes at PPU $3F00–$3F1F (not CPU RAM):
 *   $3F00–$3F0F : 4 BG sub-palettes (4 colors each)
 *   $3F10–$3F1F : 4 sprite sub-palettes (4 colors each)
 * Color 0 of every sub-palette mirrors the universal background color
 * at $3F00 (handled by NES PPU; we replicate via PALETTE_UBG_INDEX).
 *
 * Genesis CRAM is 64 word entries (4 PAL banks x 16 colors). The cached
 * Genesis colors are produced by nes_to_cram (RoomRom roomrom_bg_palette
 * already defines the canonical conversion).
 *
 * NOT yet wired to consumers — this header establishes the typed shape.
 * Wiring lands as RoomRom palette modules promote (Phase 12).
 */

#ifndef PALETTE_STATE_H
#define PALETTE_STATE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PALETTE_PALRAM_BYTES         32u  /* NES PALRAM size */
#define PALETTE_BG_HALF_BYTES        16u  /* $3F00–$3F0F */
#define PALETTE_SPR_HALF_BYTES       16u  /* $3F10–$3F1F */
#define PALETTE_SUBPAL_COUNT         4u   /* 4 BG + 4 sprite sub-palettes */
#define PALETTE_COLORS_PER_SUBPAL    4u
#define PALETTE_UBG_INDEX            0u   /* universal BG color slot */

/* Genesis CRAM: 4 banks (PAL0..PAL3) x 16 colors per bank. */
#define PALETTE_CRAM_BANK_COUNT      4u
#define PALETTE_CRAM_BANK_COLORS    16u
#define PALETTE_CRAM_TOTAL_COLORS   (PALETTE_CRAM_BANK_COUNT * PALETTE_CRAM_BANK_COLORS)

typedef struct PaletteState {
    /* NES PALRAM mirror — 32 bytes at $3F00–$3F1F.
     * Caller writes raw NES color indices ($00..$3F). */
    uint8_t  nes_palram[PALETTE_PALRAM_BYTES];

    /* Genesis CRAM cache — 64 words from the most recent conversion of
     * nes_palram. Layout follows the canonical RoomRom mapping
     * (roomrom_bg_palette_load_palram_full). */
    uint16_t cram_cache[PALETTE_CRAM_TOTAL_COLORS];

    /* Bumped each time nes_palram is rewritten. Lets adapter code skip
     * redundant CRAM uploads when the palette has not changed. */
    uint16_t generation;

    /* Set non-zero when cram_cache is valid for the current nes_palram.
     * Cleared on nes_palram write; set after conversion. */
    uint8_t  cram_cache_valid;
} PaletteState;

#define PALETTE_STATE_INITIALIZER  { \
    .nes_palram       = { 0 }, \
    .cram_cache       = { 0 }, \
    .generation       = 0u, \
    .cram_cache_valid = 0u, \
}

/* Sub-palette accessors. subpal_idx is 0..3 across BG (sub) or sprite
 * (sub + PALETTE_SUBPAL_COUNT). color_idx is 0..3 within the sub-pal. */
static inline uint8_t palette_bg_color(const PaletteState *p,
                                       uint8_t subpal, uint8_t color) {
    return p->nes_palram[(uint16_t)subpal * PALETTE_COLORS_PER_SUBPAL + color];
}
static inline uint8_t palette_spr_color(const PaletteState *p,
                                        uint8_t subpal, uint8_t color) {
    return p->nes_palram[
        PALETTE_BG_HALF_BYTES +
        (uint16_t)subpal * PALETTE_COLORS_PER_SUBPAL + color];
}
static inline uint8_t palette_ubg_color(const PaletteState *p) {
    return p->nes_palram[PALETTE_UBG_INDEX];
}

static inline void palette_invalidate_cache(PaletteState *p) {
    p->cram_cache_valid = 0u;
    p->generation++;
}

/* Compile-time sanity. */
_Static_assert(PALETTE_BG_HALF_BYTES + PALETTE_SPR_HALF_BYTES ==
               PALETTE_PALRAM_BYTES,
               "BG + sprite halves must equal full PALRAM");
_Static_assert(PALETTE_SUBPAL_COUNT * PALETTE_COLORS_PER_SUBPAL ==
               PALETTE_BG_HALF_BYTES,
               "sub-pal count x colors-per-sub-pal must equal BG half");
_Static_assert(PALETTE_CRAM_BANK_COUNT * PALETTE_CRAM_BANK_COLORS == 64u,
               "Genesis CRAM is 64 words");

#ifdef __cplusplus
}
#endif

#endif /* PALETTE_STATE_H */
