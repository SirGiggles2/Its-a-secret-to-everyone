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
#include <genesis.h>
/* SGDK memory_base.h #defines RAM; undef before platform_abi.h reintroduces. */
#ifdef RAM
#  undef RAM
#endif
#include "platform_abi.h"

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

void anim_write_sprite_drained(unsigned int tile, unsigned int slot)
{
    /* Z_01.asm:5367-5371 — invincibility flash. */
    unsigned char attrs = RAM(NES_SCRATCH_03);
    if (ENEMY_RENDER_INV_TIMER(slot) != 0u) {
        attrs = (unsigned char)(RAM(NES_FRAME_COUNTER) & 0x03u);
        RAM(NES_SCRATCH_03) = attrs;
    }

    /* Z_01.asm:5373-5375 — pick OAM byte offset via SpriteOffsets. */
    unsigned char ri = RAM(NES_ROLLING_SPR_INDEX);
    if (ri >= 41u) ri = 0u;   /* defensive — NES guarantees < $28 */
    unsigned char y_off = k_sprite_offsets[ri];

    /* Z_01.asm:5384-5396 — write 4 OAM bytes. */
    unsigned short base = (unsigned short)(NES_SPRITES_BASE + y_off);
    RAM(base + 1u) = (unsigned char)tile;                       /* tile */
    RAM(base + 3u) = ENEMY_RENDER_OBJ_X(slot);                  /* X    */
    RAM(base + 0u) = ENEMY_RENDER_OBJ_Y(slot);                  /* Y    */
    RAM(base + 2u) = attrs;                                      /* attr */

    cycle_cur_sprite_index();
}

/* Bridge entry replacing the c_anim_write_sprite stub. */
void c_anim_write_sprite(unsigned int tile, unsigned int slot)
{
    anim_write_sprite_drained(tile, slot);
}

void enemy_render_reset_oam(void)
{
    /* Zero NES OAM mirror $0200..$02FF + reset RollingSpriteIndex.
     * Called once on room enter so stale sprites from prior room
     * don't ghost in slot 32+ until the new room writes them. */
    unsigned int i;
    for (i = 0u; i < 256u; ++i) {
        RAM((unsigned short)(NES_SPRITES_BASE + i)) = 0u;
    }
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

/* SAT slot allocation 2026-05-15:
 *   0-9   = Link + sword + items (existing roomrom_sprites)
 *   10-57 = HUD backdrop strip (48 sprites)
 *   58-79 = enemy render bridge (22 slots for NES OAM sprites)
 * HUD backdrop slot 57 forwards link to 58 (sprite_render.c) so enemy
 * sprite chain stays in the visible scan path. */
#define ENEMY_SAT_SLOT_FIRST    58u
#define ENEMY_SAT_SLOT_LAST     79u
/* NES Z1 OAM mirror is 64 sprites x 4 bytes = 256 bytes at $0200..$02FF.
 * Drained Anim_WriteSprite (Z_01.asm:5365) writes via SpriteOffsets[] —
 * scattered offsets like $60, $BC, $64, $B8 not linear. Sweep must
 * iterate all 64 OAM slots so the scattered writes land in SAT. */
#define NES_OAM_SLOT_COUNT      64u
#define NES_HUD_Y_OFFSET        32u   /* HUD on Window plane covers top 4 rows */

#define ROOMROM_SPR_TILE_BASE   1025u

/* NES Z1 sprite CHR layout in our Genesis VRAM (per sprite_render.c
 * comment + atlas/enemy_chr.h):
 *   NES tile $00..$6F = CommonSpritePatterns (112 tiles) at SPR_BASE
 *                      = Genesis tile 1025..1136 (loaded by
 *                      roomrom_sprites_upload_chr at boot).
 *   NES tile $70..$E1 = per-room transient sprite bank (OWSP for
 *                      overworld, UWSP127/358/469 for underworld).
 *                      Loaded into SCENE_OBJ slot at tile_base =
 *                      SPR_BASE + 44 = Genesis tile 1069. Bank holds
 *                      up to 136 tiles (UW 4x sub-pal, OW 1x). NES
 *                      bank tile 0 = Genesis tile 1069.
 *   NES tile $E2..$FF = unused by Z1 sprite render in standard rooms.
 *
 * Atlas tile manifest dispatch (UW level -> bank) lives in
 * RoomRom/src/atlas/level_chr_swap.c. UW sub-pal indexing
 * (Genesis tile = 1069 + sub_pal*34 + bank_tile) is required when
 * the NES OAM attr byte selects a non-zero sub-pal. Initial pass
 * uses sub-pal 0 only; refined sub-pal multiplier lands in a
 * follow-up commit. */
#define ROOMROM_SCENE_OBJ_TILE_BASE  1069u
#define NES_COMMON_SPRITE_LAST       0x6Fu

static inline unsigned short translate_tile(unsigned char nes_tile)
{
    if (nes_tile <= NES_COMMON_SPRITE_LAST) {
        return (unsigned short)(ROOMROM_SPR_TILE_BASE + (unsigned short)nes_tile);
    }
    /* Per-room transient bank: NES tile $70+k -> SCENE_OBJ slot tile k. */
    unsigned char bank_tile = (unsigned char)(nes_tile - 0x70u);
    return (unsigned short)(ROOMROM_SCENE_OBJ_TILE_BASE + (unsigned short)bank_tile);
}

static inline unsigned short translate_attrs(unsigned char nes_attrs,
                                             unsigned short tile_id)
{
    unsigned char sub_pal = (unsigned char)(nes_attrs & 0x03u);
    unsigned char h_flip  = (unsigned char)((nes_attrs >> 6) & 0x01u);
    unsigned char v_flip  = (unsigned char)((nes_attrs >> 7) & 0x01u);
    unsigned char prio    = (unsigned char)((nes_attrs >> 5) & 0x01u) ^ 0x01u;
    /* NES bit 5 = "behind BG" = priority LOW. Genesis bit = priority HIGH
     * (above plane A). Invert: NES prio=0 -> Genesis prio=1 (above). */

    unsigned short sat = (unsigned short)(tile_id & 0x07FFu);
    sat |= (unsigned short)((sub_pal & 0x03u) << 13);
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
    unsigned int sat_slot = ENEMY_SAT_SLOT_FIRST;

    for (i = 0u; i < NES_OAM_SLOT_COUNT; ++i) {
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

        unsigned short tile_id    = translate_tile(tile);
        unsigned short sat_attrs  = translate_attrs(attrs, tile_id);
        /* NES Z1 uses 8x16 sprite mode (PPUCTRL bit 5 = 1). Each NES
         * sprite = 2 vertically-stacked CHR tiles. Genesis SPRITE_SIZE
         * (1, 2) = 1 column wide, 2 rows tall = 8x16. */
        unsigned short size = SPRITE_SIZE(1, 2);

        /* NES OAM Y is absolute screen row (below NES HUD). Genesis
         * VDP screen is same coordinate system; SGDK applies its own
         * +128 offset internally on VDP_setSprite. NES OAM has the
         * standard +1 quirk (sprite Y is top - 1), so pass y as-is.
         * The HUD on Window plane covers rows 0..31 like the NES HUD
         * — no extra offset needed since NES OAM Y already accounts
         * for HUD region. */
        signed short gy = (signed short)y;
        signed short gx = (signed short)x;

        unsigned char link = (sat_slot < ENEMY_SAT_SLOT_LAST)
                                 ? (unsigned char)(sat_slot + 1u) : 0u;
        VDP_setSpriteFull((u16)sat_slot, gx, gy, size, sat_attrs, link);
        ++sat_slot;
        if (sat_slot > ENEMY_SAT_SLOT_LAST) break;
    }

    /* Pad remaining SAT slots to off-screen so stale entries clear. */
    for (; sat_slot <= ENEMY_SAT_SLOT_LAST; ++sat_slot) {
        unsigned char link = (sat_slot < ENEMY_SAT_SLOT_LAST)
                                 ? (unsigned char)(sat_slot + 1u) : 0u;
        VDP_setSpriteFull((u16)sat_slot, (signed short)-32,
                          (signed short)-32, SPRITE_SIZE(1, 1),
                          0u, link);
    }

}
