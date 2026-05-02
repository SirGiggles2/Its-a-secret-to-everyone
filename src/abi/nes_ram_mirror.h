/* nes_ram_mirror.h — NES RAM mirror layer
 *
 * PURPOSE
 * -------
 * This header is the ONLY place where owned C code may call RAM() or OBJ()
 * macros once a subsystem has been promoted to typed structs.  It provides
 * thin typed accessor wrappers that read/write the nes_ram[] array at the
 * canonical NES offsets required by transpiled co-resident code.
 *
 * ARCHITECTURE (from docs/audit/state_contract.md)
 * -------------------------------------------------
 *
 *   +----------------------------------+
 *   | Owned C modules (src/game/, ...) |
 *   | Read/write typed struct fields   |
 *   +----------------+-----------------+
 *                    |
 *                    v
 *   +----------------------------------+
 *   | Typed state structs              |
 *   | src/state/*_state.h              |
 *   | LinkState, RoomState, EnemyState |
 *   | ItemState, SaveState, …          |
 *   +----------------+-----------------+
 *                    |
 *                    v  (where parity with transpiled NES code matters)
 *   +----------------------------------+  <— THIS FILE
 *   | NES RAM mirror layer             |
 *   | src/abi/nes_ram_mirror.h         |
 *   | Thin wrappers that read/write    |
 *   | nes_ram[off] for transpiled code |
 *   +----------------+-----------------+
 *                    |
 *                    v
 *   +----------------------------------+
 *   | nes_ram[]  (A4 register pointer) |
 *   | Existing transpiled NES RAM image|
 *   +----------------------------------+
 *
 * RULES
 * -----
 * 1. Owned C NEVER calls RAM() or OBJ() directly — those macros belong
 *    exclusively to this file and src/abi/platform_abi.h.
 * 2. Each accessor added here maps one typed struct field to exactly one
 *    NES RAM byte offset.  The NES offset MUST be cited in a comment on
 *    the same line or via a _Static_assert against offsetof.
 * 3. Only one canonical accessor name per NES RAM byte.  Alias collisions
 *    are tracked in docs/audit/state_macro_inventory.md and must be
 *    resolved before the owning subsystem is promoted (Migration Rule 3
 *    in state_contract.md).
 *
 * DEPRECATION PLAN
 * ----------------
 * At Phase 12 promotion gate the raw RAM()/OBJ() macros defined in
 * platform_abi.h will gain [[deprecated]] annotations.  Any remaining
 * callsite outside this file will become a compile-time warning, escalated
 * to error at the Phase 12 close gate.  All owned-C callers must migrate
 * to typed struct fields before then.
 *
 * HOW TO ADD AN ACCESSOR
 * ----------------------
 * 1. Identify the NES RAM offset (verify via NES ROM dump if needed).
 * 2. Add a static inline accessor below with a comment citing the offset.
 * 3. Update the corresponding typed struct in src/state/*.h to hold the
 *    field, and make the accessor read/write through the struct.
 * 4. Run tools/state/verify_no_alias_collisions.py — must remain green.
 *
 * See docs/audit/state_contract.md for the full migration order table.
 */

#ifndef NES_RAM_MIRROR_H
#define NES_RAM_MIRROR_H

#include "platform_abi.h"

#ifdef __cplusplus
extern "C" {
#endif

/* =========================================================================
 * PLACEHOLDER — typed accessors will be added here as each subsystem is
 * promoted to typed structs (Phase 2+).
 *
 * Promotion order (from state_contract.md):
 *   Phase 2  — palette_state.h / vram_map_state.h (new)
 *   Phase 3  — cave_state.h (new)
 *   Phase 4  — world_state.h
 *   Phase 5  — room_state.h, collision_state.h
 *   Phase 6  — link_state.h, item_state.h
 *   Phase 7  — enemy_state.h  (resolves OBJ(0x0412) alias collision)
 *   Phase 8  — boss_state.h (new)
 *   Phase 9  — save_state.h, options_state.h
 *   Phase 13 — link_state.h -> player_state.h array generalization
 *
 * Example accessor shape (fill in as subsystems are promoted):
 *
 *   static inline unsigned char nes_link_dir_get(void) {
 *       return RAM(0x0098);   // NES $0098 — Link direction
 *   }
 *   static inline void nes_link_dir_set(unsigned char v) {
 *       RAM(0x0098) = v;
 *   }
 * ========================================================================= */

#ifdef __cplusplus
}
#endif

#endif /* NES_RAM_MIRROR_H */
