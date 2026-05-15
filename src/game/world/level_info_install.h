/* level_info_install.h — install NES Z1 per-level SRAM tables.
 *
 * NES Z1 ships LevelBlockAttrs A..F (6 x 128 bytes) + LevelInfo (256 bytes)
 * per level in PRG-ROM. On real cart these are SRAM-resident from the
 * factory (or get written once by the boot loader). Our Genesis port
 * never wrote them, so consumers reading $697E (LBA_C), $69FE (LBA_D),
 * and $6BA2 (FoeCounts) saw zeros and produced no enemies.
 *
 * level_info_install_ow() copies the OW tables (already shipped as
 * the front of rooms_overworld[]) into NES RAM at the addresses the
 * drained code expects. Call once at scene_load (OW) or any time the
 * underlying level changes (Phase 5 EnterRoom).
 *
 * UW tables ship via data/rooms/dungeons.c blob; install when UW
 * level loads. */

#ifndef LEVEL_INFO_INSTALL_H
#define LEVEL_INFO_INSTALL_H

void level_info_install_ow(void);
void level_info_install_uw(unsigned char level, unsigned char quest);

#endif
