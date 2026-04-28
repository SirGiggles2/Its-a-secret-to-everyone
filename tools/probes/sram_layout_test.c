/*
 * SRAM layout fixture (S1 Phase C, Task C3).
 *
 * Pure compile-time check: every assertion fires at preprocessor /
 * codegen time. The .o is produced and discarded - never linked into
 * the ROM. Build success == layout invariants hold.
 *
 * Spec ref: docs/audit/sram_map.md (S0-locked layout)
 * Plan ref: docs/superpowers/plans/2026-04-28-s1-reorg-sgdk-integration.md Phase C
 */

/* ---- SRAM region offsets (locked at S0; immutable through project life) ---- */

enum {
    SRAM_SAVE_SLOTS_OFFSET    = 0x000,
    SRAM_SAVE_SLOTS_SIZE      = 0x800,   /* 2048 bytes - 3 NES save files */

    SRAM_OPTIONS_STATE_OFFSET = 0x800,
    SRAM_OPTIONS_STATE_SIZE   = 0x020,   /* 32 bytes - padded; struct is 26 used */

    SRAM_UNALLOCATED_OFFSET   = 0x820,
    SRAM_UNALLOCATED_SIZE     = 0x17D9,  /* 6105 bytes - reserved future use */

    SRAM_SENTINEL_OFFSET      = 0x1FF9,
    SRAM_SENTINEL_SIZE        = 0x0007,  /* 7 logical bytes - last 4 used: $5A $A5 $C3 $3C */

    SRAM_LOGICAL_TOTAL        = 0x2000   /* 8 KB cart SRAM logical capacity */
};

/* ---- OptionsState struct (per spec Section 4.6) ---- */

#define OPT_FLAGS_COUNT 8

struct OptionsState {
    unsigned char version;
    unsigned char flags[OPT_FLAGS_COUNT];
    unsigned char reserved[16];
    unsigned char checksum;
};

/* ---- Compile-time invariants ---- */

/* Save-slot region byte-exact at SRAM start, 2 KB total. */
_Static_assert(SRAM_SAVE_SLOTS_OFFSET == 0x000,
               "save slots must start at SRAM offset 0x000");
_Static_assert(SRAM_SAVE_SLOTS_SIZE == 2048,
               "save slot region is 2048 bytes (3 NES files within)");

/* OptionsState region immediately follows save slots, 32-byte aligned. */
_Static_assert(SRAM_OPTIONS_STATE_OFFSET == SRAM_SAVE_SLOTS_OFFSET + SRAM_SAVE_SLOTS_SIZE,
               "OptionsState must start immediately after save slots");
_Static_assert(SRAM_OPTIONS_STATE_OFFSET == 0x800,
               "OptionsState must start at SRAM offset 0x800");
_Static_assert(SRAM_OPTIONS_STATE_SIZE == 32,
               "OptionsState region is 32 bytes (padded)");
_Static_assert((SRAM_OPTIONS_STATE_OFFSET & 0x1F) == 0,
               "OptionsState must be 32-byte aligned within SRAM");

/* OptionsState struct fits inside its allocated region with room to spare. */
_Static_assert(sizeof(struct OptionsState) <= SRAM_OPTIONS_STATE_SIZE,
               "OptionsState struct must fit in its 32-byte SRAM region");
_Static_assert(sizeof(struct OptionsState) == 26,
               "OptionsState used size: 1 + 8 + 16 + 1 = 26 bytes");
_Static_assert(OPT_FLAGS_COUNT == 8,
               "OPT_FLAGS_COUNT locked at S0 to 8 bytes (64 bool flags or 8 enums)");

/* Unallocated region size matches map. */
_Static_assert(SRAM_UNALLOCATED_OFFSET == 0x820,
               "unallocated region starts at 0x820 (after OptionsState)");
_Static_assert(SRAM_UNALLOCATED_SIZE == (SRAM_SENTINEL_OFFSET - SRAM_UNALLOCATED_OFFSET),
               "unallocated region must end where sentinel begins");

/* Sentinel sits at the end of cart SRAM. */
_Static_assert(SRAM_SENTINEL_OFFSET == 0x1FF9,
               "sentinel at SRAM offset 0x1FF9");
_Static_assert(SRAM_SENTINEL_OFFSET + SRAM_SENTINEL_SIZE == SRAM_LOGICAL_TOTAL,
               "sentinel must end at SRAM logical capacity");

/* Total SRAM accounted for. */
_Static_assert(SRAM_SAVE_SLOTS_SIZE + SRAM_OPTIONS_STATE_SIZE
               + SRAM_UNALLOCATED_SIZE + SRAM_SENTINEL_SIZE == SRAM_LOGICAL_TOTAL,
               "SRAM regions must sum to 8 KB total");

/* Save slots and OptionsState must not overlap; this is implied by the
 * arithmetic above but stated explicitly for the next person reading. */
_Static_assert(SRAM_SAVE_SLOTS_OFFSET + SRAM_SAVE_SLOTS_SIZE <= SRAM_OPTIONS_STATE_OFFSET,
               "save slots must not overlap OptionsState");

/* Sanity: types are the expected widths. */
_Static_assert(sizeof(unsigned char) == 1, "u8 width");
_Static_assert(sizeof(unsigned short) == 2, "u16 width");
_Static_assert(sizeof(unsigned int) == 4, "u32 width on m68k-elf");

/* The TU has no live symbols; the linker will pull nothing from this .o. */
