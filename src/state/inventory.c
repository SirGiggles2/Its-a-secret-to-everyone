#include "inventory.h"
#include "../game/hud/heart_container_anim.h"

/* Phase 6 Task 6.10.4 — singleton inventory storage.
 *
 * Boot defaults match the NES Z1 fresh-save profile:
 *   - 3 heart containers, 3 current full hearts (heart_values = 0x33).
 *   - HeartPartial empty.
 *   - 0 rupees, 0 keys, 0 bombs (NES MaxBombs default = 8).
 *   - No items, no bow/wand/boomerang/etc.
 *
 * The singleton is zero-initialized first; the populated fields below
 * land via the static initializer so save-load work in Phase 0 can
 * replace the literal once authored. */

inventory_t g_inventory = {
    .items            = 0u,
    .bombs            = 0u,
    .arrow            = INV_ARROW_NONE,
    .bow              = 0u,
    .candle           = INV_CANDLE_NONE,
    .food             = 0u,
    .potion           = 0u,
    .raft             = 0u,
    .book             = 0u,
    .ring             = INV_RING_NONE,
    .ladder           = 0u,
    .magic_key        = 0u,
    .bracelet         = 0u,
    .letter           = INV_LETTER_NONE,
    .compass_q1       = 0u,
    .map_q1           = 0u,
    .compass_l9       = 0u,
    .map_l9           = 0u,
    .clock            = 0u,
    .rupees           = 0u,
    .keys             = 0u,
    .heart_values     = 0x33u,         /* 3 max / 3 current */
    .heart_partial    = 0u,
    .triforce         = 0u,
    .boomerang_wood   = 0u,
    .boomerang_magic  = 0u,
    .magic_shield     = INV_SHIELD_WOOD,
    .max_bombs        = MAX_BOMBS_DEFAULT,
    .rupees_to_add    = 0u,
    .rupees_to_sub    = 0u,
    .world_flags      = 0u,
    .selected_b_item  = 0u,
};

static unsigned char s_inventory_hud_dirty = 1u;

void inventory_hud_mark_dirty(void)
{
    s_inventory_hud_dirty = 1u;
}

unsigned char inventory_hud_consume_dirty(void)
{
    unsigned char dirty = s_inventory_hud_dirty;
    s_inventory_hud_dirty = 0u;
    return dirty;
}

/* NES Z_01.asm:2812 World_ChangeRupees:
 *   FrameCounter LSR -> carry: every-other-frame gate.
 *   if RupeesToAdd > 0: DEC RupeesToAdd, INC InvRupees, queue tune.
 *   if RupeesToSubtract > 0: DEC RupeesToSubtract, DEC InvRupees, queue tune.
 *
 * RoomRom diverges in two places:
 *   - InvRupees is 16-bit (master plan 6.10.10 widening); cap at
 *     INV_RUPEE_CAP (999) — NES displays max 255 but the wider field
 *     accommodates future treasure-route economy.
 *   - Tune queueing skipped — the audio-driver hookup for HUD-tick tunes
 *     lives in Phase 6.10.11 (status-bar transfer buf already pulls the
 *     count, just the SFX side is deferred). */
void inventory_rupee_tick(unsigned char frame_counter)
{
    if ((frame_counter & 1u) != 0u) return;   /* every other frame */

    if (g_inventory.rupees_to_add != 0u) {
        if (g_inventory.rupees < INV_RUPEE_CAP) {
            g_inventory.rupees++;
            inventory_hud_mark_dirty();
        }
        g_inventory.rupees_to_add--;
    }
    if (g_inventory.rupees_to_sub != 0u) {
        if (g_inventory.rupees != 0u) {
            g_inventory.rupees--;
            inventory_hud_mark_dirty();
        }
        g_inventory.rupees_to_sub--;
    }
}

void inventory_rupee_credit(unsigned char count)
{
    unsigned short total = (unsigned short)(g_inventory.rupees_to_add + count);
    g_inventory.rupees_to_add = (total > 0xFFu) ? 0xFFu : (unsigned char)total;
}

void inventory_rupee_debit(unsigned char count)
{
    unsigned short total = (unsigned short)(g_inventory.rupees_to_sub + count);
    g_inventory.rupees_to_sub = (total > 0xFFu) ? 0xFFu : (unsigned char)total;
}

/* Plan v5b T2.7 — NES @TakeHeartContainer parity + native scale-up anim.
 *
 * NES Z_01.asm:4538:
 *   LDA Items, Y        ; Y = $18 heart-container slot, value packs max/cur
 *   CMP #$F0            ; if already at max-hearts (max nibble = $F),
 *   BCS Exit            ;   return.
 *   ADC #$11            ; else add 1-max + 1-current (carry was clear from CMP).
 *   JMP SetItemValue    ; store back to Items[Y].
 *
 * RoomRom equivalent: heart_values packs max in hi nibble, cur in lo
 * nibble; cap max at $0F (HEART_CONTAINERS_MAX). The CMP-with-$F0
 * gate means once max == $0F no further heart containers are added. */
unsigned char inventory_add_heart_container(void)
{
    unsigned char hv = g_inventory.heart_values;
    unsigned char max_h = heart_values_max(hv);
    unsigned char cur_h = heart_values_cur(hv);

    if (max_h >= HEART_CONTAINERS_MAX) {
        return 0u;
    }
    max_h++;
    if (cur_h < HEART_CONTAINERS_MAX) {
        cur_h++;
    }
    g_inventory.heart_values = heart_values_pack(max_h, cur_h);
    inventory_hud_mark_dirty();

    /* New container occupies slot (max_h - 1). draw_hearts_row uses
     * 0..7 = bottom row, 8..15 = top row. */
    hud_heart_container_anim_start((unsigned char)(max_h - 1u));
    return 1u;
}
