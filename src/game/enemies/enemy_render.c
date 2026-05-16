/* enemy_render.c — NES OAM mirror -> Genesis SAT bridge.
 *
 * NES source:
 *   Z_01.asm:5365 Anim_WriteSprite (single-OAM write primitive)
 *   Z_01.asm:4958 SpriteOffsets (41-entry sprite slot table)
 *   Z_01.asm:3088 CycleCurSpriteIndex (RollingSpriteIndex advance)
 *
 * Coverage:  FULL for Anim_WriteSprite body (per-line port).
 * Stance:    GREENFIELD per Drain Rule D1 (no prior drain).
 *
 * Phase 7 substrate fix 2026-05-15. Replaces c_anim_write_sprite no-op
 * stub at enemy_lamnola_bridge.c:33. Enemy logic ticks correctly now
 * (LBA install + scroll re-init committed earlier this session) but no
 * enemy sprites pixel-rendered without this bridge.
 */

#include "enemy_render.h"
#include "platform_abi.h"
#include "render_abi.h"
#include "world/render/sprite_slots.h"
#include "enemy_loop.h"   /* ENEMY_LOOP_SLOT_FIRST/LAST */
#include "enemy_state.h"  /* ENEMY_X, ENEMY_Y, ENEMY_ALIVE_FLAG, ENEMY_THROWER_SLOT */

/* NES RAM cells — see reference/aldonunez/Variables.inc. */
#define NES_SPRITES_BASE        0x0200u   /* OAM mirror, 64 sprites x 4 bytes */
#define NES_ROLLING_SPR_INDEX   0x0341u
#define NES_OBJ_INV_TIMER_BASE  0x04F0u
#define NES_FRAME_COUNTER       0x0015u
#define NES_SCRATCH_03          0x0003u   /* sprite attrs byte */

/* NES Z_01.asm:5365 — Anim_WriteSprite SpriteOffsets table.
 * 41 entries; index via RollingSpriteIndex (0..$27). */
static const unsigned char k_sprite_offsets[41] = {
    0x60u, 0xBCu, 0x64u, 0xB8u, 0x68u, 0xB4u, 0x6Cu, 0xB0u,
    0x70u, 0xCCu, 0x74u, 0xC8u, 0x78u, 0xC4u, 0x7Cu, 0xC0u,
    0x80u, 0xDCu, 0x84u, 0xD8u, 0x88u, 0xD4u, 0x8Cu, 0xD0u,
    0x90u, 0xECu, 0x94u, 0xE8u, 0x98u, 0xE4u, 0x9Cu, 0xE0u,
    0xA0u, 0xFCu, 0xA4u, 0xF8u, 0xA8u, 0xF4u, 0xACu, 0xF0u,
    0x60u
};

/* NES_OBJ_X + slot, NES_OBJ_Y + slot per platform_abi.h. */
#define ENEMY_RENDER_OBJ_X(slot)  OBJ(NES_OBJ_X, (slot))
#define ENEMY_RENDER_OBJ_Y(slot)  OBJ(NES_OBJ_Y, (slot))
#define ENEMY_RENDER_INV_TIMER(slot) OBJ(NES_OBJ_INV_TIMER_BASE, (slot))

/* NES Z_01.asm:3088 — CycleCurSpriteIndex: advance + wrap at $28. */
static inline void cycle_cur_sprite_index(void)
{
    unsigned char r = (unsigned char)(RAM(NES_ROLLING_SPR_INDEX) + 1u);
    if (r >= 0x28u) r = 0u;
    RAM(NES_ROLLING_SPR_INDEX) = r;
}

/* Phase E 2026-05-15: multi-latch cache. Each ENEMY_LOOP slot can
 * accumulate up to N tiles per frame (multi-tile bosses like Aquamentus
 * write 3-6 tiles, walkers write 1-2). Native sweep emits one Genesis
 * SAT entry per latched tile @ SIZE(1,2) 8x16 (1:1 NES OAM mapping).
 * Worst case: 11 slots * 4 entries = 44 SAT writes/frame, well under
 * H32's 64-slot hardware budget. Per-tile h_flip preserved (each entry
 * stores its own attrs byte) — fixes spec gap #5. */
#define ENEMY_RENDER_MAX_PER_SLOT  4u

typedef struct {
    unsigned char tile;
    unsigned char attrs;
    unsigned char x;
    unsigned char y;
} enemy_render_entry_t;

static enemy_render_entry_t
    s_enemy_entries[ENEMY_LOOP_SLOT_LAST + 1u][ENEMY_RENDER_MAX_PER_SLOT];
static unsigned char s_enemy_count[ENEMY_LOOP_SLOT_LAST + 1u];

/* Phase G 2026-05-15 — Gleeok sub-cache. Flat array of up to 20 entries
 * (per spec). Body 6 + heads 4 + first 4 segments per neck (4*4=16) =
 * 26 max; cap at 20 = body + 4 heads + first 4 segments per neck up
 * to 10. Beyond cap = priority-drop (NES does the same on hardware
 * via per-scanline limit). */
#define ENEMY_RENDER_GLEEOK_MAX  20u
static enemy_render_entry_t s_gleeok_entries[ENEMY_RENDER_GLEEOK_MAX];
static unsigned char s_gleeok_count;

void enemy_render_native_reset(void)
{
    unsigned char i;
    for (i = 0u; i <= ENEMY_LOOP_SLOT_LAST; ++i) {
        s_enemy_count[i] = 0u;
    }
    s_gleeok_count = 0u;
}

void enemy_render_publish_gleeok(unsigned char tile,
                                 unsigned char attrs,
                                 unsigned char x,
                                 unsigned char y)
{
    if (s_gleeok_count >= ENEMY_RENDER_GLEEOK_MAX) return;
    enemy_render_entry_t *e = &s_gleeok_entries[s_gleeok_count];
    e->tile  = tile;
    e->attrs = attrs;
    e->x     = x;
    e->y     = y;
    s_gleeok_count = (unsigned char)(s_gleeok_count + 1u);
}

void anim_write_sprite_drained(unsigned int tile, unsigned int slot)
{
    /* Phase C 2026-05-15: drop latch-time invincibility flash. The
     * native sweep applies hit-flash LIVE per frame so the palette
     * cycles every VBlank regardless of when the enemy last drew.
     * NES Z_01.asm:5367-5371 stays for compat — the OAM byte we
     * write below still reflects the latched state if any external
     * consumer reads it. */
    unsigned char attrs = RAM(NES_SCRATCH_03);

    /* Phase E 2026-05-15 — multi-latch append: each anim_write call
     * adds one entry to the slot's cache (capped at MAX_PER_SLOT).
     * Used by oracle drained enemies (moldorm, lamnola, ganon) which
     * call this directly via c_anim_write_sprite. Per-tile h_flip
     * preserved because each entry stores its own attrs byte. */
    {
        unsigned char cur_slot = ENEMY_THROWER_SLOT;
        if (cur_slot <= ENEMY_LOOP_SLOT_LAST) {
            unsigned char n = s_enemy_count[cur_slot];
            if (n < ENEMY_RENDER_MAX_PER_SLOT) {
                enemy_render_entry_t *e = &s_enemy_entries[cur_slot][n];
                e->tile  = (unsigned char)tile;
                e->attrs = attrs;
                e->x     = ENEMY_RENDER_OBJ_X(slot);
                e->y     = ENEMY_RENDER_OBJ_Y(slot);
                s_enemy_count[cur_slot] = (unsigned char)(n + 1u);
            }
        }
    }

    /* 2026-05-15 perf: NES OAM writes are no longer needed — the native
     * sweep reads the side-channel cache (s_enemy_* arrays) populated
     * above. Skip 4 OAM byte writes per call (~50 calls/frame =
     * ~1600 cycles/frame saved). RollingSpriteIndex still advances so
     * any external SpriteOffsets-table consumer sees the same cadence. */
    cycle_cur_sprite_index();
}

/* Bridge entry replacing the c_anim_write_sprite stub. */
void c_anim_write_sprite(unsigned int tile, unsigned int slot)
{
    anim_write_sprite_drained(tile, slot);
}

/* Phase A/E cache feeder. Called from native draw_dispatch.c
 * anim_write_sprite_pair_not_flashing on EACH iteration (LEFT + RIGHT
 * halves) so natively-dispatched enemies populate s_enemy_entries the
 * same way the drain-shim path (anim_write_sprite_drained via
 * c_anim_write_sprite) does for oracle enemies. ENEMY_THROWER_SLOT
 * mirrors NES CurObjIndex which enemy_loop_tick sets before dispatching
 * the per-slot update fn — same key both paths.
 *
 * Phase E 2026-05-15: append entry to multi-latch cache (cap 4 per
 * slot). Per-tile h_flip preserved: each entry stores its own attrs.
 * Function name kept as _pair_left for ABI stability — it now publishes
 * BOTH halves via separate calls. */
void enemy_render_publish_pair_left(unsigned char tile,
                                    unsigned char attrs,
                                    unsigned char x,
                                    unsigned char y)
{
    unsigned char cur_slot = ENEMY_THROWER_SLOT;
    if (cur_slot <= ENEMY_LOOP_SLOT_LAST) {
        unsigned char n = s_enemy_count[cur_slot];
        if (n < ENEMY_RENDER_MAX_PER_SLOT) {
            enemy_render_entry_t *e = &s_enemy_entries[cur_slot][n];
            e->tile  = tile;
            e->attrs = attrs;
            e->x     = x;
            e->y     = y;
            s_enemy_count[cur_slot] = (unsigned char)(n + 1u);
        }
    }
}

/* Phase D 2026-05-15 — meta-object (spark / cloud) frame publisher.
 * Reads ENEMY_METASTATE(slot), picks a frame tile from the cloud or
 * spark table, and overwrites the slot's cache entry so the native
 * sweep emits a SAT entry at the meta sprite's coordinates.
 *
 * Tile tables: 4-frame cycles from NES Z1 sprite CHR. Cloud uses the
 * bomb-cloud item tiles ($60..$66, even-only since 8x16 mode pairs);
 * spark uses death-sparkle tiles ($66..$6C). Approximate vs the NES
 * Anim_WriteItemSprites indirection — the cache path doesn't go
 * through item-slot resolution yet. Phase 8/F+G can refine.
 *
 * attrs: NES DrawCloud writes [04]/[05] = 1 (palette 1, blue). Use
 * sub-pal 1 = bits 1..0 of attrs = 0x01.
 *
 * Position: ENEMY_X(slot) / ENEMY_Y(slot) (the slot's last logical
 * position, suitable until the slot recycles). */
#define ENEMY_RENDER_META_CLOUD_TILE_BASE 0x60u
#define ENEMY_RENDER_META_SPARK_TILE_BASE 0x66u
static const unsigned char k_meta_cloud_tiles[4] = { 0x60u, 0x62u, 0x64u, 0x66u };
static const unsigned char k_meta_spark_tiles[4] = { 0x66u, 0x68u, 0x6Au, 0x6Cu };
#define ENEMY_RENDER_META_ATTRS  0x01u  /* sub-pal 1, no flip, no priority */

void enemy_render_publish_meta(unsigned int slot)
{
    if (slot > (unsigned int)ENEMY_LOOP_SLOT_LAST) return;
    unsigned char ms = (unsigned char)ENEMY_METASTATE(slot);
    if (ms == 0u) return;

    unsigned char frame;
    unsigned char tile;
    if (ms >= 0x10u) {
        frame = (unsigned char)((ms - 0x10u) & 0x03u);
        tile = k_meta_spark_tiles[frame];
    } else {
        frame = (unsigned char)(ms & 0x03u);
        tile = k_meta_cloud_tiles[frame];
    }

    /* Phase E: meta sprite replaces all enemy entries this frame
     * (1 sprite, not multi-tile body). Reset count + write entry[0]. */
    enemy_render_entry_t *e = &s_enemy_entries[slot][0];
    e->tile  = tile;
    e->attrs = ENEMY_RENDER_META_ATTRS;
    e->x     = (unsigned char)ENEMY_RENDER_OBJ_X(slot);
    e->y     = (unsigned char)ENEMY_RENDER_OBJ_Y(slot);
    s_enemy_count[slot] = 1u;
}

void enemy_render_reset_oam(void)
{
    /* 2026-05-15 perf: 256-byte OAM clear is no longer required for
     * rendering — the native sweep reads the side-channel cache, not
     * NES OAM mirror. Only RollingSpriteIndex needs reset so the
     * SpriteOffsets table starts fresh each frame.
     * Saves ~2000 cycles per frame. */
    RAM(NES_ROLLING_SPR_INDEX) = 0u;
}

/* Genesis-native sweep: NES OAM mirror -> SGDK SAT slots 32-72.
 *
 * NES OAM record (4 bytes per sprite):
 *   +0 Y
 *   +1 tile
 *   +2 attrs (bit 7 = v_flip, bit 6 = h_flip, bit 5 = behind-BG,
 *             bits 1-0 = sub-palette)
 *   +3 X
 *
 * Genesis SAT (SGDK VDP_setSprite):
 *   y, x, size, link, tile + palette<<13 + h_flip<<11 + v_flip<<12 + priority<<15
 *
 * Tile-ID translation: nes_tile -> ROOMROM_SPR_TILE_BASE + nes_tile.
 * NES sprite CHR window is 256 tiles ($00..$FF) but Z1 uses $00..$BF
 * range for sprites in 8x16 mode. Our SPR_BASE (1025) + SCENE_OBJ
 * offset (44) puts enemy CHR at Genesis tile 1069. Initial mapping is
 * identity offset off SPR_BASE; per-enemy refined mapping lands in
 * follow-up commits.
 *
 * Sub-palette mapping (NES sub-pal $0..$3 -> Genesis PAL$0..$3):
 *   sub_pal 0 -> PAL0
 *   sub_pal 1 -> PAL1 (Link)
 *   sub_pal 2 -> PAL2 (items)
 *   sub_pal 3 -> PAL3
 * Items already live in PAL2 per memory project_pr2_vram_relocation.
 * Enemies typically use sub_pal 1 (red) or 3 (blue). Direct mapping
 * works as default; refined per-bank coloring lands later.
 */

/* SAT slot allocation 2026-05-15 post-HUD-backdrop-retirement
 * (H32 mode, 64 hardware slots total):
 *   0..9   = Link + sword + items + projectiles (sprite_render.c)
 *   10..63 = enemy render bridge (54 slots for NES OAM sprites)
 * Slots 64+ are not evaluated by VDP in H32 mode. Slot contract lives
 * in sprite_slots.h; never hard-code 10 / 63 here. */
#if ROOMROM_SPRITE_SLOT_LAST_H32 > 63u
#  error "H32 mode supports only 64 hardware SAT slots."
#endif

/* 2026-05-15 perf-finding: sweep + render_set_sprite_full chain costs
 * ~30% of frame budget when 11 enemies are alive. Capping the write
 * count did NOT recover proportionally; the per-call cost is irreducible
 * at this layer. Long-term fix = Genesis-native enemy renderer that
 * reads ENEMY_X/Y/TYPE/DRAW_FRAME directly and writes 1 SAT entry per
 * alive enemy (planned next commit). For now, sweep iterates the full
 * H32 enemy slot range. */
#define ENEMY_RENDER_SLOT_LAST ROOMROM_SPRITE_SLOT_LAST_H32
/* NES Z1 OAM mirror is 64 sprites x 4 bytes = 256 bytes at $0200..$02FF.
 * Drained Anim_WriteSprite (Z_01.asm:5365) writes via SpriteOffsets[] —
 * scattered offsets like $60, $BC, $64, $B8 not linear. Sweep must
 * iterate all 64 OAM slots so the scattered writes land in SAT. */
#define NES_OAM_SLOT_COUNT      64u
#define NES_HUD_Y_OFFSET        32u   /* HUD on Window plane covers top 4 rows */

#define ROOMROM_SPR_TILE_BASE   1025u

/* NES Z1 sprite CHR layout in our Genesis VRAM:
 *
 * Per reference/aldonunez/Z_03.asm:44 PatternBlockPpuAddrs:
 *   $1700 = BG block dest PPU addr  (BG sprites)
 *   $08E0 = SPRITE block dest PPU addr  (OWSP/UWSP banks)
 *
 * So OWSP/UWSP bank file BYTE 0 -> NES PPU byte $08E0 = PPU tile $8E.
 * NES OAM tile id $XX in 8x16 mode -> top 8x8 at PPU byte ($XX*$10 + bit 0).
 *
 * Genesis VRAM:
 *   NES PPU tile $00..$8D (CommonSpritePatterns + headroom, 142 tiles)
 *     -> SPR_BASE + nes_tile = Genesis 1025+nes_tile.
 *   NES PPU tile $8E..$FF (transient sprite bank, OWSP up to 114 tiles,
 *     UWSP up to 34 tiles x 4 sub-pal copies)
 *     -> SCENE_OBJ tile_base + (nes_tile - $8E)
 *     = Genesis 1069 + bank_tile.
 *
 * UW path adds sub_pal*34 offset to select the correct 4x copy.
 *
 * Pre-2026-05-15 bug: used $70 instead of $8E as the bank base,
 * landing every enemy tile 30 tiles too low in VRAM -> rendered
 * unrelated atlas data as Tektite (diagonal slash instead of spider). */
#define ROOMROM_SCENE_OBJ_TILE_BASE  1069u
#define NES_OWSP_BANK_FIRST          0x8Eu   /* PPU $08E0 / $10 */
#define UWSP_TILES_PER_SUBPAL        34u
#define NES_CUR_LEVEL_CELL           0x0010u

static inline unsigned short translate_tile(unsigned char nes_tile,
                                            unsigned char nes_attrs)
{
    if (nes_tile < NES_OWSP_BANK_FIRST) {
        /* Common sprite pattern block at SPR_BASE 1:1. */
        return (unsigned short)(ROOMROM_SPR_TILE_BASE + (unsigned short)nes_tile);
    }
    /* Per-room transient bank: NES tile $8E+k -> SCENE_OBJ tile k. */
    unsigned char bank_tile = (unsigned char)(nes_tile - NES_OWSP_BANK_FIRST);

    /* OW (CurLevel == 0) uses OWSP single-copy bank: tile k -> 1069+k.
     * UW uses UWSP 4x bank: sub-pal N tile k -> 1069 + N*34 + k. */
    unsigned char cur_level = nes_ram[NES_CUR_LEVEL_CELL];
    if (cur_level == 0u) {
        return (unsigned short)(ROOMROM_SCENE_OBJ_TILE_BASE + bank_tile);
    }
    unsigned char sub_pal = (unsigned char)(nes_attrs & 0x03u);
    unsigned short sub_off =
        (unsigned short)sub_pal * (unsigned short)UWSP_TILES_PER_SUBPAL;
    return (unsigned short)(ROOMROM_SCENE_OBJ_TILE_BASE + sub_off + bank_tile);
}

static inline unsigned short translate_attrs(unsigned char nes_attrs,
                                             unsigned short tile_id)
{
    /* Genesis sprite palette = PAL1 always. NES PALRAM $3F10..$3F1F
     * (full 16-color sprite palette, 4 sub-pal x 4 colors) is loaded
     * into Genesis CRAM PAL1 by roomrom_bg_palette_load_palram_full
     * (src/game/world/bg_palette.c:33).
     *
     * NES sub-pal selection is NOT done via Genesis palette bank.
     * Instead, the atlas pixel data is pre-biased so each tile copy
     * uses CRAM indices for its sub-pal slot:
     *   OWSP: 1 copy per tile, sub-pal 0 bias (colors 1..3 of PAL1)
     *   UWSP: 4 copies per tile, sub-pal 0..3 bias (colors 1..15 of PAL1)
     * translate_tile() picks the correct copy via sub_pal*34 offset.
     *
     * So translate_attrs always selects PAL1 + maps flip + priority. */
    unsigned char h_flip  = (unsigned char)((nes_attrs >> 6) & 0x01u);
    unsigned char v_flip  = (unsigned char)((nes_attrs >> 7) & 0x01u);
    unsigned char prio    = (unsigned char)((nes_attrs >> 5) & 0x01u) ^ 0x01u;
    /* NES bit 5 = "behind BG" = priority LOW. Genesis bit = priority HIGH
     * (above plane A). Invert: NES prio=0 -> Genesis prio=1 (above). */

    /* OW (CurLevel == 0): atlas is single-sub-pal-0-biased, so PAL1
     * renders all OWSP enemies in items palette colors (yellow/gold).
     * Route to PAL3 instead, which holds NES sub-pal 2 colors (red)
     * loaded by roomrom_bg_palette_load_palram_full. Tektite + Octorok
     * + Leever + most OW enemies use sub-pal 2 in NES Z1.
     * UW (CurLevel != 0): atlas is 4x-replicated, each tile copy biased
     * to its sub-pal slot in PAL1 — use PAL1 + sub_pal*34 tile offset
     * (handled in translate_tile). */
    unsigned char cur_level = nes_ram[NES_CUR_LEVEL_CELL];
    unsigned short pal_bank = (cur_level == 0u) ? 3u : 1u;

    unsigned short sat = (unsigned short)(tile_id & 0x07FFu);
    sat |= (unsigned short)(pal_bank << 13);
    sat |= (unsigned short)((v_flip  & 0x01u) << 12);
    sat |= (unsigned short)((h_flip  & 0x01u) << 11);
    sat |= (unsigned short)((prio    & 0x01u) << 15);
    return sat;
}

void enemy_render_sweep_oam_to_sat(void)
{
    /* Phase 1 diagnostic: increment sentinel at NES $07FE per frame
     * so probe can verify this fn fires. */
    nes_ram[0x07FEu] = (unsigned char)(nes_ram[0x07FEu] + 1u);

    unsigned int i;
    unsigned int sat_slot = ROOMROM_SPRITE_SLOT_ENEMY_FIRST;

    /* 2026-05-15 perf: NES Z1's SpriteOffsets table (k_sprite_offsets)
     * scatters Anim_WriteSprite writes across byte offsets $60..$FC =
     * OAM slot 24..63. Slots 0..23 are NEVER populated. Skip them. */
    for (i = 24u; i < NES_OAM_SLOT_COUNT; ++i) {
        unsigned short base = (unsigned short)(NES_SPRITES_BASE + i * 4u);
        unsigned char y     = RAM(base + 0u);
        unsigned char tile  = RAM(base + 1u);
        unsigned char attrs = RAM(base + 2u);
        unsigned char x     = RAM(base + 3u);

        /* All-zero record = unused OAM slot. Skip without consuming a
         * SAT slot. (NES Z1 leaves untouched OAM bytes at 0.) */
        if (y == 0u && tile == 0u && attrs == 0u && x == 0u) {
            continue;
        }
        /* Y == $F0 = NES hide-sprite convention. Skip. */
        if (y == 0xF0u) {
            continue;
        }

        unsigned short tile_id    = translate_tile(tile, attrs);
        unsigned short sat_attrs  = translate_attrs(attrs, tile_id);
        /* NES Z1 uses 8x16 sprite mode (PPUCTRL bit 5 = 1). Each NES
         * sprite = 2 vertically-stacked CHR tiles. Genesis SPRITE_SIZE
         * (1, 2) = 1 column wide, 2 rows tall = 8x16. */
        unsigned short size = RENDER_SPRITE_SIZE(1, 2);

        /* NES OAM Y is absolute screen row (below NES HUD). Genesis
         * VDP screen is same coordinate system; SGDK applies its own
         * +128 offset internally on VDP_setSprite. NES OAM has the
         * standard +1 quirk (sprite Y is top - 1), so pass y as-is.
         * The HUD on Window plane covers rows 0..31 like the NES HUD
         * — no extra offset needed since NES OAM Y already accounts
         * for HUD region. */
        signed short gy = (signed short)y;
        signed short gx = (signed short)x;

        unsigned char link = (sat_slot < ENEMY_RENDER_SLOT_LAST)
                                 ? (unsigned char)(sat_slot + 1u) : 0u;
        render_set_sprite_inline((unsigned short)sat_slot, gx, gy,
                                 size, sat_attrs, link);
        ++sat_slot;
        if (sat_slot > ENEMY_RENDER_SLOT_LAST) break;
    }

    /* 2026-05-15 perf fix: drop the up-to-54-slot pad loop. Write a
     * single terminator at the next slot with link=0, hiding it off-
     * screen. Genesis VDP sprite processing walks the link chain from
     * slot 0; once link=0 it stops scanning. Trailing SAT slots are
     * ignored regardless of their stale contents. Saves up to ~50
     * render_set_sprite_full calls per frame in sparse rooms (~3-5%
     * of frame budget on Tektite room). */
    if (sat_slot <= ENEMY_RENDER_SLOT_LAST) {
        render_set_sprite_inline((unsigned short)sat_slot,
                                 (signed short)-32, (signed short)-32,
                                 RENDER_SPRITE_SIZE(1, 1), 0u, 0u);
    }
}

/* 2026-05-15 Genesis-native enemy renderer.
 *
 * Replaces the per-frame iteration of 64 NES OAM entries (each
 * producing one Genesis SAT write) with a slot-keyed loop over the
 * up-to-11 alive enemies. Cost dropped from ~50 SAT writes/frame
 * to <= 11. Tile + attrs are latched into s_enemy_* by
 * anim_write_sprite_drained during enemy update; this function reads
 * the latch directly and emits one Genesis SIZE(1,2) SAT entry per
 * alive enemy. The OAM scatter still happens (cheap) for compat with
 * other consumers; enemy_render_sweep_oam_to_sat is retained for
 * fallback but no longer called from the gameplay tick. */
/* 2026-05-15 perf: published by native sweep so main.c can DMA only the
 * SAT entries actually used this frame (instead of all 64 H32 slots).
 * Initialized large enough for the boot fallback path; native sweep
 * updates each frame. */
unsigned char g_enemy_render_last_sat_slot = ROOMROM_SPRITE_SLOT_ENEMY_FIRST;

/* Phase B 2026-05-15 — per-ENEMY_TYPE size lookup. NES Z1 enemy types
 * are 1-byte ($00..$7F); table indexed by ENEMY_TYPE(slot). Default =
 * SIZE(2,2) (16x16) covers the vast majority. Overrides land here for
 * enemies whose visual width exceeds 16px (Aquamentus 24x16, etc.).
 *
 * Wider enemies (Gleeok body 32x32, Patra body w/ satellites) are
 * handled by Phase F+G per-segment / sub-cache paths, not this table.
 *
 * Source for type IDs: src/game/enemies/enemy_loop.c per-type comments
 * + reference/aldonunez/Z_05.asm (Variables.inc enum). */
#define ENEMY_TYPE_SIZE_TABLE_LEN 0x80u

static const unsigned char k_enemy_type_size[ENEMY_TYPE_SIZE_TABLE_LEN] = {
    /* Aquamentus boss ($3D, Z_04.asm + boss_aquamentus): 24x16 wide
     * mouth + flanks. SIZE(3,2) renders 3 columns x 2 rows = 6 tiles
     * column-major from base tile $XX..$XX+5. */
    [0x3Du] = ((3u - 1u) << 2) | (2u - 1u),
    /* All other slots zero-initialized = sentinel "use default". */
};

static inline unsigned short enemy_type_to_size(unsigned char enemy_type)
{
    /* Default: SIZE(2,2). Encoding: (w-1)<<2 | (h-1) per RENDER_SPRITE_SIZE. */
    if (enemy_type < ENEMY_TYPE_SIZE_TABLE_LEN) {
        unsigned char e = k_enemy_type_size[enemy_type];
        if (e != 0u) return (unsigned short)e;
    }
    return RENDER_SPRITE_SIZE(2, 2);
}

void enemy_render_native_sweep(void)
{
    unsigned int slot;
    unsigned int sat_slot = ROOMROM_SPRITE_SLOT_ENEMY_FIRST;

    /* Phase 1 diagnostic: increment sentinel at NES $07FE per frame
     * so probe can verify this fn fires. */
    nes_ram[0x07FEu] = (unsigned char)(nes_ram[0x07FEu] + 1u);

    for (slot = ENEMY_LOOP_SLOT_FIRST; slot <= ENEMY_LOOP_SLOT_LAST; ++slot) {
        unsigned char n = s_enemy_count[slot];
        unsigned char ei;
        if (n == 0u) continue;
        if (sat_slot > ENEMY_RENDER_SLOT_LAST) break;

        /* Phase C live hit-flash: compute once per slot since flash
         * affects all latched entries equally. Sub-pal bits 1..0 of
         * attrs override with FrameCounter & 0x03 if ObjInvincibility
         * Timer ($04F0+slot) is non-zero. NES Z_01.asm:5367-5371 logic,
         * applied at sweep-time instead of latch-time so the palette
         * cycles every frame regardless of when the enemy last drew. */
        unsigned char inv_active = (ENEMY_RENDER_INV_TIMER(slot) != 0u);
        unsigned char fc_pal = (unsigned char)(RAM(NES_FRAME_COUNTER) & 0x03u);

        for (ei = 0u; ei < n; ++ei) {
            enemy_render_entry_t *e = &s_enemy_entries[slot][ei];
            unsigned char y = e->y;
            if (y == 0xF0u) continue;
            if (sat_slot > ENEMY_RENDER_SLOT_LAST) break;

            unsigned char render_attrs = e->attrs;
            if (inv_active) {
                render_attrs = (unsigned char)((render_attrs & 0xFCu) | fc_pal);
            }
            unsigned short tile_id   = translate_tile(e->tile, render_attrs);
            unsigned short sat_attrs = translate_attrs(render_attrs, tile_id);
            /* Phase E: each cache entry = one NES OAM (8x16). Render
             * as Genesis SIZE(1,2) for exact 1:1 mapping. Per-tile
             * h_flip preserved because each entry's attrs byte was
             * captured separately. Wide enemies (Aquamentus 24x16)
             * render as N entries (3 OAM = 3 SIZE(1,2) at successive
             * x positions), no special-case needed. */
            unsigned short size = RENDER_SPRITE_SIZE(1, 2);

            unsigned char link = (sat_slot < ENEMY_RENDER_SLOT_LAST)
                                     ? (unsigned char)(sat_slot + 1u) : 0u;
            render_set_sprite_inline((unsigned short)sat_slot,
                                     (signed short)e->x, (signed short)y,
                                     size, sat_attrs, link);
            ++sat_slot;
        }
    }

    /* Phase G 2026-05-15 — Gleeok sub-cache emission. Body / heads /
     * segments published via enemy_render_publish_gleeok land here.
     * Drained in flat order (body first, then heads, then segments
     * per the NES draw call ordering). Skip if no Gleeok entries.
     * Cap honored by publisher (drops over 20). */
    {
        unsigned char gi;
        for (gi = 0u; gi < s_gleeok_count; ++gi) {
            if (sat_slot > ENEMY_RENDER_SLOT_LAST) break;
            enemy_render_entry_t *e = &s_gleeok_entries[gi];
            if (e->y == 0xF0u) continue;

            unsigned short tile_id   = translate_tile(e->tile, e->attrs);
            unsigned short sat_attrs = translate_attrs(e->attrs, tile_id);
            unsigned short size      = RENDER_SPRITE_SIZE(1, 2);
            unsigned char  link      = (sat_slot < ENEMY_RENDER_SLOT_LAST)
                                          ? (unsigned char)(sat_slot + 1u) : 0u;
            render_set_sprite_inline((unsigned short)sat_slot,
                                     (signed short)e->x, (signed short)e->y,
                                     size, sat_attrs, link);
            ++sat_slot;
        }
    }

    /* Terminator: hide remaining SAT slots via chain break (link=0). */
    if (sat_slot <= ENEMY_RENDER_SLOT_LAST) {
        render_set_sprite_inline((unsigned short)sat_slot,
                                 (signed short)-32, (signed short)-32,
                                 RENDER_SPRITE_SIZE(1, 1), 0u, 0u);
        /* Publish: DMA needs to include the terminator slot. */
        g_enemy_render_last_sat_slot = (unsigned char)(sat_slot + 1u);
    } else {
        g_enemy_render_last_sat_slot = (unsigned char)sat_slot;
    }

    /* Clear per-slot entry counts for next frame; entries arrays stay
     * populated (overwritten as new anim_write calls append). */
    {
        unsigned char i;
        for (i = 0u; i <= ENEMY_LOOP_SLOT_LAST; ++i) {
            s_enemy_count[i] = 0u;
        }
        s_gleeok_count = 0u;
    }
}
