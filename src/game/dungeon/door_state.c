/* uw_door_state.c — Ph5.3: UW door type lookup, per-room state, tile patching.
 *
 * NES source:  Z_05.asm:FindDoorAttrByDoorBit, TouchDoor*, LayOutDoors,
 *              UpdateDoors, CheckShutters, SetDoorFlag/ResetDoorFlag
 * Drained C:   NONE (room_dispatch.c has Z_05 drain stubs, but Phase 5
 *              active scope is RoomRom/src only — no cross-scope import)
 * Coverage:    NONE
 * Stance:      GREENFIELD (drain_coverage.py reports 0 candidates in scope)
 */

#include "door_state.h"
#include "uw_render.h"  /* Phase 12.2 promoted */
#include "platform_abi.h"

extern const unsigned char rooms_dungeons[];

/* --- Persist storage: one opened-bitmask byte per room per level.
 * Indexed [level-1][room_id]. Only KEY/KEY2/BOMBABLE doors persist;
 * SHUTTER and FALSE walls re-close on every room reload. */
static unsigned char s_persist[9][128];

/* --- Per-room live state --- */
static unsigned char s_door_types[DOOR_DIR_COUNT]; /* DOOR_TYPE_* per dir */
static unsigned char s_cur_opened;                 /* DOOR_BIT_* bitmask   */
static unsigned char s_false_timer;                /* $18..0 countdown     */
static unsigned char s_cur_level;                  /* 1-based, for persist */
static unsigned char s_cur_room_id;

static void layout_door(unsigned char dir);
static void publish_cur_opened_doors(void);

/* Door faces: see layout_door (NES LayOutDoors port, T-114). */

/* Legacy metatile diagnostics per direction. Real Link collision uses the
 * exact 8px door-face tiles (layout_door), plus doorway-axis bypass in
 * main.c to match NES DoorwayDir behavior. */
static const unsigned char s_walk_mt_col[DOOR_DIR_COUNT]  = {14u, 1u, 8u, 8u};
static const unsigned char s_walk_mt_row[DOOR_DIR_COUNT]  = {5u,  5u, 9u, 1u};
static const unsigned char s_walk_mt_col2[DOOR_DIR_COUNT] = {15u, 0u, 8u, 8u};
static const unsigned char s_walk_mt_row2[DOOR_DIR_COUNT] = {5u,  5u, 10u, 0u};

/* =========================================================================
 * Internal helpers
 * ========================================================================= */

/* Persist an open event for KEY/KEY2/BOMBABLE doors. */
static void persist_open(unsigned char dir)
{
    unsigned char t = s_door_types[dir];
    if (t == DOOR_TYPE_KEY || t == DOOR_TYPE_KEY2 || t == DOOR_TYPE_BOMBABLE) {
        s_persist[s_cur_level - 1u][s_cur_room_id] |= DOOR_DIR_BIT(dir);
    }
}

/* =========================================================================
 * Public API
 * ========================================================================= */

void uw_door_state_room_init(unsigned char level,
                              unsigned char quest,
                              unsigned char room_id)
{
    unsigned short base;
    unsigned char attrsA, attrsB;
    unsigned char dir;
    unsigned char persist_mask;

    if (level == 0u || level > 9u || room_id >= 128u) return;

    s_cur_level   = level;
    s_cur_room_id = room_id;
    s_false_timer = 0u;

    /* FindDoorAttrByDoorBit (Z_05.asm:4520) — packed attribute extraction.
     *
     * rooms_dungeons[] LevelBlock layout (768 bytes per block):
     *   [+0 .. +127]   AttrsA: N = (byte>>5)&7, S = (byte>>2)&7
     *   [+128 .. +255] AttrsB: W = (byte>>5)&7, E = (byte>>2)&7
     *
     * Block offsets: L1-6 Q1 = 0, L7-9 Q1 = 768,
     *                L1-6 Q2 = 1536, L7-9 Q2 = 2304. */
    base = (level <= 6u) ? 0u : 768u;
    if (quest == 2u) base += 1536u;

    attrsA = rooms_dungeons[base + (unsigned short)room_id];
    attrsB = rooms_dungeons[base + 128u + (unsigned short)room_id];

    s_door_types[DOOR_DIR_N] = (unsigned char)((attrsA >> 5) & 7u);
    s_door_types[DOOR_DIR_S] = (unsigned char)((attrsA >> 2) & 7u);
    s_door_types[DOOR_DIR_E] = (unsigned char)((attrsB >> 2) & 7u);
    s_door_types[DOOR_DIR_W] = (unsigned char)((attrsB >> 5) & 7u);

    /* Restore persisted open state (KEY/BOMBABLE only). */
    persist_mask = s_persist[level - 1u][room_id];

    s_cur_opened = 0u;
    for (dir = 0u; dir < DOOR_DIR_COUNT; dir++) {
        unsigned char t   = s_door_types[dir];
        unsigned char bit = DOOR_DIR_BIT(dir);
        if (t == DOOR_TYPE_OPEN) {
            /* 2026-05-24 — patch open-door art for OPEN doors too.
             * Prior comment claimed "blob tiles already correct" but
             * empirical r$63 visual shows wall art at N door spot.
             * NES Z1 blob may not pre-bake all OPEN door tiles; safer
             * to always patch. */
            s_cur_opened |= bit;
        } else if ((t == DOOR_TYPE_KEY || t == DOOR_TYPE_KEY2 ||
                    t == DOOR_TYPE_BOMBABLE) && (persist_mask & bit)) {
            s_cur_opened |= bit;
        }
        /* WALL/SHUTTER/FALSE start closed; SHUTTER deferred to Phase 6. */
    }

    /* T-114: NES LayOutDoors lays out every true door face (closed ones
     * included), not only the opened ones patched above. */
    for (dir = 0u; dir < DOOR_DIR_COUNT; dir++) layout_door(dir);
    publish_cur_opened_doors();
    /* Override walkability based on current opened state. */
    uw_door_state_apply_walkability();
}

unsigned char uw_door_state_get_type(unsigned char dir)
{
    if (dir >= DOOR_DIR_COUNT) return DOOR_TYPE_WALL;
    return s_door_types[dir];
}

unsigned char uw_door_state_get_opened(void)
{
    return s_cur_opened;
}

unsigned char uw_door_state_is_open(unsigned char dir)
{
    if (dir >= DOOR_DIR_COUNT) return 0u;
    return (s_cur_opened & DOOR_DIR_BIT(dir)) ? 1u : 0u;
}

unsigned char uw_door_state_touch(unsigned char dir, unsigned char *keys)
{
    unsigned char t;
    unsigned char bit;

    if (dir >= DOOR_DIR_COUNT) return 0u;
    t   = s_door_types[dir];
    bit = DOOR_DIR_BIT(dir);

    switch (t) {
    case DOOR_TYPE_OPEN:
        return 1u;

    case DOOR_TYPE_WALL:
        return 0u;

    case DOOR_TYPE_FALSE:
    case DOOR_TYPE_FALSE2:
        /* Once the $18-frame timer has expired the bit is set; pass. */
        if (s_cur_opened & bit) return 1u;
        /* Start timer on first touch. */
        if (s_false_timer == 0u) s_false_timer = 0x18u;
        return 0u;

    case DOOR_TYPE_KEY:
    case DOOR_TYPE_KEY2:
        if (s_cur_opened & bit) return 1u;
        if (keys != (unsigned char *)0 && *keys > 0u) {
            (*keys)--;
            uw_door_state_open_by_mask(bit);
            return 1u;
        }
        return 0u;

    case DOOR_TYPE_BOMBABLE:
    case DOOR_TYPE_SHUTTER:
        /* Open only if already triggered (bomb detonation / room-clear). */
        return (s_cur_opened & bit) ? 1u : 0u;

    default:
        return 0u;
    }
}

void uw_door_state_tick(void)
{
    unsigned char dir;

    if (s_false_timer == 0u) return;
    s_false_timer--;
    if (s_false_timer != 0u) return;

    /* Timer expired: mark all false-wall doors as passable.
     * Tiles are NOT patched — NES Zelda 1 false walls keep their wall art;
     * Link simply passes through. Only walkability changes.
     * No persist — false walls re-close on next room visit. */
    for (dir = 0u; dir < DOOR_DIR_COUNT; dir++) {
        unsigned char t = s_door_types[dir];
        if (t == DOOR_TYPE_FALSE || t == DOOR_TYPE_FALSE2) {
            s_cur_opened |= DOOR_DIR_BIT(dir);
        }
    }
    uw_door_state_apply_walkability();
}

extern void audio_sfx_play(unsigned char sfx);

void uw_door_state_open_by_mask(unsigned char dir_mask)
{
    unsigned char dir;
    unsigned char any_new = 0u;

    for (dir = 0u; dir < DOOR_DIR_COUNT; dir++) {
        unsigned char bit = DOOR_DIR_BIT(dir);
        if (!(dir_mask & bit))     continue;
        if (s_cur_opened & bit)    continue; /* already open */

        s_cur_opened |= bit;
        persist_open(dir);
        uw_door_state_patch_open_tiles(dir);
        any_new = 1u;
    }
    if (any_new) {
        publish_cur_opened_doors();
        uw_door_state_apply_walkability();
        /* NES Z_05.asm:5222-5223 LDA #$04 / JSR PlaySample = door sfx
         * (DMC sample 3 in our 1-based mapping; bit 2 in NES bitmap). */
        audio_sfx_play(3u);
    }
}

void uw_door_state_apply_walkability(void)
{
    unsigned char dir;

    for (dir = 0u; dir < DOOR_DIR_COUNT; dir++) {
        unsigned char t = s_door_types[dir];
        unsigned char open;
        unsigned char mt_col_a, mt_row_a, mt_col_b, mt_row_b;

        if (t == DOOR_TYPE_WALL) {
            open = 0u; /* wall always blocks regardless of opened mask */
        } else {
            open = (s_cur_opened & DOOR_DIR_BIT(dir)) ? 1u : 0u;
        }
        mt_col_a = s_walk_mt_col[dir];
        mt_row_a = s_walk_mt_row[dir];
        mt_col_b = s_walk_mt_col2[dir];
        mt_row_b = s_walk_mt_row2[dir];

        roomrom_uw_room_render_set_walkable(mt_col_a, mt_row_a, open);
        roomrom_uw_room_render_set_walkable(mt_col_b, mt_row_b, open);

        /* Propagate to BG-tile-grain cache. UW Link collision reads via
         * roomrom_uw_room_render_walkable_tile_at(); the metatile cache
         * alone never reaches link_walkable_at. Each metatile covers a
         * 2x2 BG block at (col*2, row*2). */
        {
            unsigned char dr, dc;
            for (dr = 0u; dr < 2u; dr++) {
                for (dc = 0u; dc < 2u; dc++) {
                    roomrom_uw_room_render_set_walkable_tile(
                        (unsigned char)(mt_col_a * 2u + dc),
                        (unsigned char)(mt_row_a * 2u + dr),
                        open);
                    roomrom_uw_room_render_set_walkable_tile(
                        (unsigned char)(mt_col_b * 2u + dc),
                        (unsigned char)(mt_row_b * 2u + dr),
                        open);
                }
            }
        }
    }
}

/* T-114: NES LayOutDoors (Z_05.asm) door faces.
 *
 * Face sets per direction (DoorFaceTilesE/W/S/N, 5 x 12 tiles):
 *   1 open / opened key / opened shutter   2 locked (key, key 2)
 *   3 shutter closed   4 bombable (looks like wall)   5 bombed hole
 * Type -> face (DT DFC DFO): 0 1 1, 4 4 5, 5 2 1, 6 2 1, 7 3 1; walls
 * (1..3) keep the captured wall art. Cells from PlayAreaDoorFaceAddrs
 * ($67A1 E col 28 row 9, $654F W col 1 row 9, $6676 S col 14 row 18,
 * $6665 N col 14 row 1) in the LayOutDoors copy order: E/W 3 cols x 2
 * rows per half (second half 2 rows lower), N/S 2 cols x 3 rows per half
 * (second half 2 cols right). Indexed by DOOR_DIR_E/W/S/N. */
static const unsigned char k_door_face_tiles[DOOR_DIR_COUNT][60] = {
    { 0x88u, 0x74u, 0x8Au, 0x24u, 0x87u, 0x87u, 0x75u, 0x89u, 0x24u, 0x8Bu, 0x87u, 0x87u,
      0x88u, 0xA4u, 0x8Au, 0xA6u, 0x87u, 0x87u, 0xA5u, 0x89u, 0xA7u, 0x8Bu, 0x87u, 0x87u,
      0x88u, 0xACu, 0x8Au, 0xAEu, 0x87u, 0x87u, 0xADu, 0x89u, 0xAFu, 0x8Bu, 0x87u, 0x87u,
      0xDFu, 0xDFu, 0xDFu, 0xDFu, 0xF5u, 0xF5u, 0xDFu, 0xDFu, 0xDFu, 0xDFu, 0xF5u, 0xF5u,
      0xDFu, 0x24u, 0xDFu, 0x92u, 0xF5u, 0xF5u, 0x24u, 0xDFu, 0x93u, 0xDFu, 0xF5u, 0xF5u },
    { 0x82u, 0x82u, 0x83u, 0x24u, 0x85u, 0x76u, 0x82u, 0x82u, 0x24u, 0x84u, 0x77u, 0x86u,
      0x82u, 0x82u, 0x83u, 0xA0u, 0x85u, 0xA2u, 0x82u, 0x82u, 0xA1u, 0x84u, 0xA3u, 0x86u,
      0x82u, 0x82u, 0x83u, 0xACu, 0x85u, 0xAEu, 0x82u, 0x82u, 0xADu, 0x84u, 0xAFu, 0x86u,
      0xF5u, 0xF5u, 0xDEu, 0xDEu, 0xDEu, 0xDEu, 0xF5u, 0xF5u, 0xDEu, 0xDEu, 0xDEu, 0xDEu,
      0xF5u, 0xF5u, 0xDEu, 0x90u, 0xDEu, 0x24u, 0xF5u, 0xF5u, 0x91u, 0xDEu, 0x24u, 0xDEu },
    { 0x7Eu, 0x7Fu, 0x7Du, 0x76u, 0x24u, 0x7Du, 0x74u, 0x24u, 0x7Du, 0x80u, 0x81u, 0x7Du,
      0x7Eu, 0x7Fu, 0x7Du, 0x9Cu, 0x9Du, 0x7Du, 0x9Eu, 0x9Fu, 0x7Du, 0x80u, 0x81u, 0x7Du,
      0x7Eu, 0x7Fu, 0x7Du, 0xA8u, 0xA9u, 0x7Du, 0xAAu, 0xABu, 0x7Du, 0x80u, 0x81u, 0x7Du,
      0xDDu, 0xDDu, 0xF5u, 0xDDu, 0xDDu, 0xF5u, 0xDDu, 0xDDu, 0xF5u, 0xDDu, 0xDDu, 0xF5u,
      0xDDu, 0xDDu, 0xF5u, 0x24u, 0x8Eu, 0xF5u, 0x24u, 0x8Fu, 0xF5u, 0xDDu, 0xDDu, 0xF5u },
    { 0x78u, 0x79u, 0x7Au, 0x78u, 0x24u, 0x77u, 0x78u, 0x24u, 0x75u, 0x78u, 0x7Bu, 0x7Cu,
      0x78u, 0x79u, 0x7Au, 0x78u, 0x98u, 0x99u, 0x78u, 0x9Au, 0x9Bu, 0x78u, 0x7Bu, 0x7Cu,
      0x78u, 0x79u, 0x7Au, 0x78u, 0xA8u, 0xA9u, 0x78u, 0xAAu, 0xABu, 0x78u, 0x7Bu, 0x7Cu,
      0xF5u, 0xDCu, 0xDCu, 0xF5u, 0xDCu, 0xDCu, 0xF5u, 0xDCu, 0xDCu, 0xF5u, 0xDCu, 0xDCu,
      0xF5u, 0xDCu, 0xDCu, 0xF5u, 0x8Cu, 0x24u, 0xF5u, 0x8Du, 0x24u, 0xF5u, 0xDCu, 0xDCu },
};
static const unsigned char k_door_face_origin[DOOR_DIR_COUNT][2] = {
    { 28u, 9u }, { 1u, 9u }, { 14u, 18u }, { 14u, 1u }
};

/* Face index 1..5 for the door's type and opened state; 0 = keep wall. */
static unsigned char door_face_index(unsigned char dir)
{
    unsigned char t = s_door_types[dir];
    unsigned char opened = (s_cur_opened & DOOR_DIR_BIT(dir)) ? 1u : 0u;
    switch (t) {
    case DOOR_TYPE_OPEN:     return 1u;
    case DOOR_TYPE_BOMBABLE: return opened ? 5u : 4u;
    case DOOR_TYPE_KEY:
    case DOOR_TYPE_KEY2:     return opened ? 1u : 2u;
    case DOOR_TYPE_SHUTTER:  return opened ? 1u : 3u;
    default:                 return 0u;
    }
}

static void layout_door(unsigned char dir)
{
    unsigned char face = door_face_index(dir);
    const unsigned char *src;
    unsigned char half, c, r, k;
    if (face == 0u) return;
    src = &k_door_face_tiles[dir][(unsigned short)(face - 1u) * 12u];
    k = 0u;
    for (half = 0u; half < 2u; ++half) {
        unsigned char cols = (dir == DOOR_DIR_E || dir == DOOR_DIR_W) ? 3u : 2u;
        unsigned char rows = (dir == DOOR_DIR_E || dir == DOOR_DIR_W) ? 2u : 3u;
        for (c = 0u; c < cols; ++c) {
            for (r = 0u; r < rows; ++r) {
                unsigned char col = k_door_face_origin[dir][0];
                unsigned char row = k_door_face_origin[dir][1];
                unsigned char pal;
                if (dir == DOOR_DIR_E || dir == DOOR_DIR_W) {
                    col = (unsigned char)(col + c);
                    row = (unsigned char)(row + 2u * half + r);
                } else {
                    col = (unsigned char)(col + 2u * half + c);
                    row = (unsigned char)(row + r);
                }
                pal = roomrom_uw_room_render_palette_at(col, (unsigned char)(row + 8u));
                roomrom_uw_room_render_write_tile(col, row, src[k], pal);
                ++k;
            }
        }
    }
}

/* CurOpenedDoors ($EE) as the NES keeps it: only true doors (bombable,
 * key, key 2, shutter) keep their bit (LayOutDoors clears the rest). */
static void publish_cur_opened_doors(void)
{
    unsigned char dir, mask = 0u;
    for (dir = 0u; dir < DOOR_DIR_COUNT; dir++) {
        unsigned char t = s_door_types[dir];
        if (t >= DOOR_TYPE_BOMBABLE && (s_cur_opened & DOOR_DIR_BIT(dir)))
            mask |= DOOR_DIR_BIT(dir);
    }
    nes_ram[0x00EEu] = mask;
}

void uw_door_state_patch_open_tiles(unsigned char dir)
{
    if (dir >= DOOR_DIR_COUNT) return;
    layout_door(dir);
}

unsigned char uw_door_state_has_shutters(void)
{
    unsigned char dir;
    for (dir = 0u; dir < DOOR_DIR_COUNT; dir++) {
        if (s_door_types[dir] == DOOR_TYPE_SHUTTER) return 1u;
    }
    return 0u;
}

void uw_door_state_trigger_shutters(void)
{
    unsigned char dir;
    unsigned char mask = 0u;
    for (dir = 0u; dir < DOOR_DIR_COUNT; dir++) {
        if (s_door_types[dir] == DOOR_TYPE_SHUTTER) {
            mask |= DOOR_DIR_BIT(dir);
        }
    }
    if (mask) uw_door_state_open_by_mask(mask);
}

void uw_door_state_reset_persist(void)
{
    unsigned char lvl, room;
    for (lvl = 0u; lvl < 9u; lvl++) {
        for (room = 0u; room < 128u; room++) {
            s_persist[lvl][room] = 0u;
        }
    }
}

unsigned char uw_door_state_false_timer(void)
{
    return s_false_timer;
}

unsigned char uw_door_state_current_level(void)
{
    return s_cur_level;
}

void uw_door_state_copy_persist_for_active_level(unsigned char *dst,
                                                  unsigned short dst_size)
{
    unsigned short i;
    unsigned char lvl_idx;
    if (dst == 0 || dst_size == 0u) return;
    if (s_cur_level == 0u || s_cur_level > 9u) {
        for (i = 0u; i < dst_size; i++) dst[i] = 0u;
        return;
    }
    lvl_idx = (unsigned char)(s_cur_level - 1u);
    for (i = 0u; i < dst_size && i < 128u; i++) {
        dst[i] = s_persist[lvl_idx][i];
    }
    /* Zero remainder if dst is larger than 128 (slice-1 probe block is 256 B). */
    for (; i < dst_size; i++) dst[i] = 0u;
}
