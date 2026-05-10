/* Phase 9 Task 9.7 — save slot serializer (substrate, GREENFIELD).
 *
 * Backs the contract in save_serializer.h. Per-slot 43 bytes:
 *   [0..1]  magic ($5A $A5, matches NES InitSaveRam sentinel)
 *   [2..41] inventory mirror of RAM($0657..$067E)
 *   [42]    XOR checksum of bytes [0..41]
 *
 * SRAM base = $6000 via NES_SRAM_BASE; SAVE_BYTE(off) macro lives in
 * save_state.h.
 */

#include "save_serializer.h"
#include "save_state.h"
#include "platform_abi.h"

static unsigned short slot_base(unsigned char slot_idx)
{
    return (unsigned short)((unsigned short)slot_idx * SAVE_SLOT_BYTE_SIZE);
}

unsigned char save_slot_compute_checksum(unsigned char slot_idx)
{
    unsigned short base;
    unsigned char xor_acc = 0u;
    unsigned char i;

    if (slot_idx >= SAVE_SLOT_COUNT) {
        return 0u;
    }
    base = slot_base(slot_idx);
    for (i = 0u; i < (SAVE_SLOT_BYTE_SIZE - 1u); ++i) {
        xor_acc ^= SAVE_BYTE(base + i);
    }
    return xor_acc;
}

unsigned char save_slot_serialize(unsigned char slot_idx)
{
    unsigned short base;
    unsigned char i;
    unsigned char xor_acc;

    if (slot_idx >= SAVE_SLOT_COUNT) {
        return 0u;
    }
    base = slot_base(slot_idx);

    SAVE_BYTE(base + 0u) = SAVE_MAGIC_LO;
    SAVE_BYTE(base + 1u) = SAVE_MAGIC_HI;

    for (i = 0u; i < SAVE_INVENTORY_BYTES; ++i) {
        SAVE_BYTE(base + 2u + i) =
            RAM((unsigned short)(SAVE_INVENTORY_RAM_BASE + i));
    }

    xor_acc = 0u;
    for (i = 0u; i < (SAVE_SLOT_BYTE_SIZE - 1u); ++i) {
        xor_acc ^= SAVE_BYTE(base + i);
    }
    SAVE_BYTE(base + (SAVE_SLOT_BYTE_SIZE - 1u)) = xor_acc;
    return 1u;
}

unsigned char save_slot_validate(unsigned char slot_idx)
{
    unsigned short base;
    unsigned char stored_checksum;
    unsigned char computed_checksum;

    if (slot_idx >= SAVE_SLOT_COUNT) {
        return 0u;
    }
    base = slot_base(slot_idx);

    if (SAVE_BYTE(base + 0u) != SAVE_MAGIC_LO) {
        return 0u;
    }
    if (SAVE_BYTE(base + 1u) != SAVE_MAGIC_HI) {
        return 0u;
    }
    stored_checksum = SAVE_BYTE(base + (SAVE_SLOT_BYTE_SIZE - 1u));
    computed_checksum = save_slot_compute_checksum(slot_idx);
    if (stored_checksum != computed_checksum) {
        return 0u;
    }
    return 1u;
}

unsigned char save_slot_deserialize(unsigned char slot_idx)
{
    unsigned short base;
    unsigned char i;

    if (!save_slot_validate(slot_idx)) {
        return 0u;
    }
    base = slot_base(slot_idx);

    for (i = 0u; i < SAVE_INVENTORY_BYTES; ++i) {
        RAM((unsigned short)(SAVE_INVENTORY_RAM_BASE + i)) =
            SAVE_BYTE(base + 2u + i);
    }
    return 1u;
}
