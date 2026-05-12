/* Phase 9 Task 9.7 — SRAM byte-IO adapter for save slots.
 *
 * Public surface for the GREENFIELD save persistence layer
 * (src/state/save_persistence.c). Wraps SGDK SRAM_enable /
 * SRAM_readByte / SRAM_writeByte so gameplay code stays free of
 * <genesis.h> per SGDK-1.
 *
 * Locked SRAM region: $000..$7FF (3 slots × 682 bytes), declared at
 * S0 in docs/audit/sram_map.md as SRAM_SAVE_SLOTS_OFFSET /
 * SRAM_SAVE_SLOTS_SIZE (src/abi/sram_abi.h). Options at $800 are NOT
 * touched.
 */

#ifndef SRC_SGDK_ADAPTER_SRAM_SAVE_IO_H
#define SRC_SGDK_ADAPTER_SRAM_SAVE_IO_H

#ifdef __cplusplus
extern "C" {
#endif

/* Read `size` bytes from cart SRAM slot `slot_idx` (offset = slot * 682)
 * into `buf`. No-op on slot >= 3 or null buf. */
void sram_save_io_read_slot(unsigned char slot_idx, unsigned char *buf,
                            unsigned int size);

/* Write `size` bytes from `buf` into cart SRAM slot `slot_idx`
 * (offset = slot * 682). No-op on slot >= 3 or null buf. */
void sram_save_io_write_slot(unsigned char slot_idx,
                             const unsigned char *buf, unsigned int size);

#ifdef __cplusplus
}
#endif

#endif /* SRC_SGDK_ADAPTER_SRAM_SAVE_IO_H */
