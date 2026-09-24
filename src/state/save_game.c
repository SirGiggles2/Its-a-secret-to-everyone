/* save_game.c — NES save block <-> cart SRAM, plus the NES save/load
 * entry points (T-100). The codec is save_serializer.c.
 *
 * Replaces the Genesis-only 43-byte slot format and its $FF6000 staging
 * mirror. Old-format carts fail the NES marker/checksum check at boot and
 * are formatted, exactly as a NES formats a corrupt file.
 */

#include "save_game.h"
#include "save_serializer.h"
#include "platform_abi.h"

extern void sram_nes_save_block_load(volatile unsigned char *dst, unsigned short bytes);
extern void sram_nes_save_block_store(const volatile unsigned char *src, unsigned short bytes);

static void persist(void)
{
    sram_nes_save_block_store(&nes_ram[NES_SAVE_BLOCK_BASE], NES_SAVE_BLOCK_BYTES);
}

void save_game_boot(void)
{
    sram_nes_save_block_load(&nes_ram[NES_SAVE_BLOCK_BASE], NES_SAVE_BLOCK_BYTES);
    save_files_boot_validate();
    /* Z_07.asm InitializeGameOrMode: "Mark Save RAM initialized" ($6001 =
     * $5A; its $7FFF = $A5 partner lies outside the persisted block). */
    nes_ram[0x6001u] = 0x5Au;
    /* The NES formats in battery RAM directly; keep the cart equal to
     * what was validated so a formatted blank slot stays formatted. */
    persist();
}

unsigned char save_game_slot_active(unsigned char slot)
{
    if (slot >= SAVE_SLOT_COUNT) return 0u;
    return RAM(NES_SLOTINFO_ACTIVE + slot) ? 1u : 0u;
}

unsigned char save_game_slot_quest(unsigned char slot)
{
    if (slot >= SAVE_SLOT_COUNT) return 0u;
    return RAM(NES_SLOTINFO_QUEST + slot);
}

unsigned char save_game_load_slot(unsigned char slot)
{
    if (!save_game_slot_active(slot)) return 0u;
    save_file_a_load(slot);
    return 1u;
}

unsigned char save_game_save_current(void)
{
    if (!save_file_a_save(RAM(NES_CUR_SAVE_SLOT))) return 0u;
    persist();
    return 1u;
}

/* File Select occupancy (overrides the weak default in fs_render.c). */
unsigned char fs_sram_slot_occupied(unsigned char slot)
{
    return save_game_slot_active(slot);
}
