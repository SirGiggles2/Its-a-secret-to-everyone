/* nes_ram_init.c — RoomRom build only (D3 substrate per debate 006).
 *
 * Title.md uses A4-pinned `nes_ram` initialized by `genesis_shell.asm`
 * boot at `lea ($FF0000).l, A4`. RoomRom uses SGDK's default A-register
 * convention with no A4 pin, so we allocate an in-RAM 2KB scratch image
 * and point `nes_ram` at it before any drained code (which uses the
 * RAM(off) / OBJ(off, slot) macros that index `nes_ram[]`) executes.
 *
 * Per platform_abi.h `#ifdef ROOMROM_BUILD` branch: `nes_ram` is a
 * regular global pointer (not register-pinned). This file is its
 * single definition.
 *
 * Initialization timing: SGDK's main() runs after BSS zeroing. The
 * pointer is initialized at file-static load time (compile-time
 * constant initializer pointing at `roomrom_nes_ram[]`), so it's
 * valid for any C code that runs after SGDK boot — including the
 * RoomRom main() that links shared `src/game/` (or `src/oracle/`)
 * functions reading nes_ram.
 *
 * Memory cost: 2 KB BSS. NES Z1 RAM usage tops at ~$07FF, so 0x800
 * is the matching footprint.
 */

/* 2 KB shadow image. SGDK BSS-zeroed at boot; first access is safe. */
static volatile unsigned char roomrom_nes_ram[0x800];

/* Compile-time-constant initializer points the global at our buffer.
 * This is the storage definition — all RoomRom translation units that
 * include platform_abi.h (with ROOMROM_BUILD set) get the `extern`
 * declaration; this file provides the body. */
volatile unsigned char *nes_ram = roomrom_nes_ram;
