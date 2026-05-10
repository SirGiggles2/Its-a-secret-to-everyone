/* Phase 9 Task 9.7 — save serializer probe (in-ROM tests). */

#include "save_serializer_probe.h"
#include "../save_serializer.h"
#include "../save_state.h"
#include "platform_abi.h"

#define PROBE  ((volatile unsigned char *)SAVE_SERIALIZER_PROBE_BASE)

static void stamp_magic(void)
{
    unsigned int i;
    PROBE[0] = 'S';
    PROBE[1] = 'V';
    PROBE[2] = 0x01u;
    for (i = 3u; i < 16u; ++i) PROBE[i] = 0u;
}

static void seed_inventory(unsigned char first)
{
    unsigned char i;
    for (i = 0u; i < SAVE_INVENTORY_BYTES; ++i) {
        RAM((unsigned short)(SAVE_INVENTORY_RAM_BASE + i)) =
            (unsigned char)(first + i);
    }
}

static unsigned char inventory_matches(unsigned char first)
{
    unsigned char i;
    for (i = 0u; i < SAVE_INVENTORY_BYTES; ++i) {
        if (RAM((unsigned short)(SAVE_INVENTORY_RAM_BASE + i))
            != (unsigned char)(first + i)) {
            return 0u;
        }
    }
    return 1u;
}

static unsigned char test_round_trip(void)
{
    seed_inventory(0x10u);
    if (!save_slot_serialize(0u)) return 0u;
    seed_inventory(0xA5u);                  /* clobber live state */
    if (!save_slot_deserialize(0u)) return 0u;
    return inventory_matches(0x10u);
}

static unsigned char test_magic_validate(void)
{
    seed_inventory(0x20u);
    if (!save_slot_serialize(1u)) return 0u;
    return save_slot_validate(1u);
}

static unsigned char test_bad_magic_rejected(void)
{
    unsigned short base = (unsigned short)(2u * SAVE_SLOT_STRIDE);
    seed_inventory(0x30u);
    if (!save_slot_serialize(2u)) return 0u;
    SAVE_BYTE(base) = 0x00u;
    return (save_slot_validate(2u) == 0u) ? 1u : 0u;
}

static unsigned char test_bad_checksum_rejected(void)
{
    unsigned short base;
    unsigned char saved_byte;
    seed_inventory(0x40u);
    if (!save_slot_serialize(0u)) return 0u;
    base = 0u;
    /* Flip one inventory byte WITHOUT updating checksum. */
    saved_byte = SAVE_BYTE(base + 5u);
    SAVE_BYTE(base + 5u) = (unsigned char)(saved_byte ^ 0xFFu);
    return (save_slot_validate(0u) == 0u) ? 1u : 0u;
}

static unsigned char test_cross_slot_isolation(void)
{
    unsigned short slot1_base = SAVE_SLOT_STRIDE;
    unsigned char i;
    /* Write a sentinel pattern across slot-1's payload region. */
    for (i = 0u; i < SAVE_SLOT_PAYLOAD_BYTES; ++i) {
        SAVE_BYTE(slot1_base + i) = (unsigned char)(0xC0u + i);
    }
    /* Serialize slot 0 — must NOT touch slot 1 region. */
    seed_inventory(0x50u);
    if (!save_slot_serialize(0u)) return 0u;
    for (i = 0u; i < SAVE_SLOT_PAYLOAD_BYTES; ++i) {
        if (SAVE_BYTE(slot1_base + i) != (unsigned char)(0xC0u + i)) {
            return 0u;
        }
    }
    return 1u;
}

static void mark(unsigned char bit, unsigned char *passes,
                 unsigned char *bits)
{
    *passes = (unsigned char)(*passes + 1u);
    *bits |= (unsigned char)(1u << bit);
}

void save_serializer_probe_run(void)
{
    unsigned char saved_inv[SAVE_INVENTORY_BYTES];
    /* Snapshot only the bytes we actually write: per-slot payload (43)
     * + slot-1 sentinel region used by cross_slot_isolation. Bounded
     * stack alloc — keep under SGDK probe budget. */
    unsigned char saved_payload[SAVE_SLOT_COUNT][SAVE_SLOT_PAYLOAD_BYTES];
    unsigned char saved_slot1_sentinel[SAVE_SLOT_PAYLOAD_BYTES];
    unsigned char slot;
    unsigned char i;
    unsigned char bits = 0u;
    unsigned char passes = 0u;
    const unsigned char total = 5u;

    /* Snapshot live inventory + per-slot payload regions + slot-1 sentinel. */
    for (i = 0u; i < SAVE_INVENTORY_BYTES; ++i) {
        saved_inv[i] = RAM((unsigned short)(SAVE_INVENTORY_RAM_BASE + i));
    }
    for (slot = 0u; slot < SAVE_SLOT_COUNT; ++slot) {
        unsigned short base = (unsigned short)(slot * SAVE_SLOT_STRIDE);
        for (i = 0u; i < SAVE_SLOT_PAYLOAD_BYTES; ++i) {
            saved_payload[slot][i] = SAVE_BYTE(base + i);
        }
    }
    for (i = 0u; i < SAVE_SLOT_PAYLOAD_BYTES; ++i) {
        saved_slot1_sentinel[i] = SAVE_BYTE(SAVE_SLOT_STRIDE + i);
    }

    stamp_magic();

    if (test_round_trip())            mark(0u, &passes, &bits);
    if (test_magic_validate())        mark(1u, &passes, &bits);
    if (test_bad_magic_rejected())    mark(2u, &passes, &bits);
    if (test_bad_checksum_rejected()) mark(3u, &passes, &bits);
    if (test_cross_slot_isolation())  mark(4u, &passes, &bits);

    PROBE[3] = total;
    PROBE[4] = passes;
    PROBE[5] = bits;

    /* Restore live state. */
    for (i = 0u; i < SAVE_INVENTORY_BYTES; ++i) {
        RAM((unsigned short)(SAVE_INVENTORY_RAM_BASE + i)) = saved_inv[i];
    }
    for (slot = 0u; slot < SAVE_SLOT_COUNT; ++slot) {
        unsigned short base = (unsigned short)(slot * SAVE_SLOT_STRIDE);
        for (i = 0u; i < SAVE_SLOT_PAYLOAD_BYTES; ++i) {
            SAVE_BYTE(base + i) = saved_payload[slot][i];
        }
    }
    for (i = 0u; i < SAVE_SLOT_PAYLOAD_BYTES; ++i) {
        SAVE_BYTE(SAVE_SLOT_STRIDE + i) = saved_slot1_sentinel[i];
    }
}
