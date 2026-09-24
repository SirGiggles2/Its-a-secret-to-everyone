#include "inventory.h"
#include "../abi/platform_abi.h"
#include "../game/hud/hud_dispatch.h"
#include "../game/hud/heart_container_anim.h"

/* Phase 6 Task 6.10.4 — singleton inventory storage.
 *
 * Boot defaults match the NES Z1 fresh-save profile:
 *   - 3 heart containers, 3 current full hearts (heart_values = 0x33).
 *   - HeartPartial full enough for NES MakeSwordShot ($80+).
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
    .heart_partial    = 0xFFu,
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

/* NES source: Variables.inc:Items / Z_01.asm:ItemIdToSlot.
 * Drained C: item_dispatch.c:item_take_item; nes_ram_sync_inventory_hearts.
 * Coverage: PARTIAL inventory readback; Stance: EXTEND.
 * Native cells own gameplay inventory. This legacy struct is a readback
 * for existing UI/weapon consumers, never an independent award ledger.
 * Selection tokens and world_flags have different layouts and are not copied. */
void inventory_sync_from_native(void)
{
    unsigned char changed = 0u;
    unsigned char items = 0u;
#define PULL_FIELD(field, address) do { \
    if (g_inventory.field != nes_ram[address]) changed = 1u; \
    g_inventory.field = nes_ram[address]; \
} while (0)
    PULL_FIELD(bombs, 0x0658u);
    PULL_FIELD(arrow, 0x0659u);
    PULL_FIELD(bow, 0x065Au);
    PULL_FIELD(candle, 0x065Bu);
    PULL_FIELD(food, 0x065Du);
    PULL_FIELD(potion, 0x065Eu);
    PULL_FIELD(raft, 0x0660u);
    PULL_FIELD(book, 0x0661u);
    PULL_FIELD(ring, 0x0662u);
    PULL_FIELD(ladder, 0x0663u);
    PULL_FIELD(magic_key, 0x0664u);
    PULL_FIELD(bracelet, 0x0665u);
    PULL_FIELD(letter, 0x0666u);
    PULL_FIELD(compass_q1, 0x0667u);
    PULL_FIELD(map_q1, 0x0668u);
    PULL_FIELD(compass_l9, 0x0669u);
    PULL_FIELD(map_l9, 0x066Au);
    PULL_FIELD(clock, 0x066Cu);
    PULL_FIELD(rupees, 0x066Du);
    PULL_FIELD(keys, 0x066Eu);
    PULL_FIELD(heart_values, 0x066Fu);
    PULL_FIELD(heart_partial, 0x0670u);
    PULL_FIELD(triforce, 0x0671u);
    PULL_FIELD(boomerang_wood, 0x0674u);
    PULL_FIELD(boomerang_magic, 0x0675u);
    PULL_FIELD(magic_shield, 0x0676u);
    PULL_FIELD(max_bombs, 0x067Cu);
    PULL_FIELD(rupees_to_add, 0x067Du);
    PULL_FIELD(rupees_to_sub, 0x067Eu);
#undef PULL_FIELD
    if (nes_ram[0x065Au]) items |= ITEMS_BIT_BOW;
    if (nes_ram[0x065Fu]) items |= ITEMS_BIT_WAND;
    if (nes_ram[0x0674u] || nes_ram[0x0675u]) items |= ITEMS_BIT_BOOMERANG;
    if (nes_ram[0x065Cu]) items |= ITEMS_BIT_FLUTE;
    if (nes_ram[0x065Du]) items |= ITEMS_BIT_BAIT;
    if (nes_ram[0x0666u]) items |= ITEMS_BIT_LETTER;
    if (nes_ram[0x065Eu]) items |= ITEMS_BIT_POTION_T1;
    if (nes_ram[0x065Eu] >= 2u) items |= ITEMS_BIT_POTION_T2;
    if (items != g_inventory.items) changed = 1u;
    g_inventory.items = items;
    if (changed) inventory_hud_mark_dirty();
}

/* NES source: Z_01.asm:World_ChangeRupees.
 * Drained C: hud_dispatch.c:hud_tick_native_rupees.
 * Coverage: FULL currency state; Stance: EXTEND.
 * NES cells own currency and pending transactions. Mirror after each tick
 * for legacy display/serialization consumers; never spend the mirror. */
void inventory_rupee_tick(unsigned char frame_counter)
{
    unsigned short previous = g_inventory.rupees;
    hud_tick_native_rupees(frame_counter);
    g_inventory.rupees = nes_ram[0x066Du];
    g_inventory.rupees_to_add = nes_ram[0x067Du];
    g_inventory.rupees_to_sub = nes_ram[0x067Eu];
    if (previous != g_inventory.rupees) inventory_hud_mark_dirty();
}

void inventory_rupee_credit(unsigned char count)
{
    unsigned short total = (unsigned short)(nes_ram[0x067Du] + count);
    nes_ram[0x067Du] = (total > 0xFFu) ? 0xFFu : (unsigned char)total;
    g_inventory.rupees_to_add = nes_ram[0x067Du];
}

void inventory_rupee_debit(unsigned char count)
{
    unsigned short total = (unsigned short)(nes_ram[0x067Eu] + count);
    nes_ram[0x067Eu] = (total > 0xFFu) ? 0xFFu : (unsigned char)total;
    g_inventory.rupees_to_sub = nes_ram[0x067Eu];
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
