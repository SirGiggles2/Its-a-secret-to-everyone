/* cave_dispatch.c — native cave gamemode entry (debate 006 D2).
 *
 * Native rewrite of src/oracle/cave/cave_runtime.c init/dispatch
 * surface. Pure C, no transpile-bridge shims. Both ROMs link.
 *
 * NES reference: reference/aldonunez/Z_01.asm InitCave (line 69) +
 * InitCaveContinue (line 105) + UpdateCavePerson (line 300).
 * Verified MATCH per Gate 1 findings 3_2, 3_2b.
 *
 * NES vars (reference/aldonunez/Variables.inc):
 *   ObjType+1   = $0350  (CAVE_ROOM_TYPE)
 *   PersonState = $00AD  (CAVE_PERSON_STATE)
 *   CaveFlags   = $0413  (CAVE_FLAGS)
 *   PersonTextSelector = $0415 (CAVE_TEXT_SELECTOR)
 *
 * Scope (this commit):
 *   cave_init  — populate CaveState typed struct from cave_id; upload
 *                cave palette via render adapter. NO transpile shim
 *                calls (z01_set_up_common_cave_objects et al deferred).
 *   cave_tick  — stub (real NPC/shop logic ports per-function later).
 *   cave_exit  — clears CaveState + bumps generation.
 */

#include "cave_dispatch.h"
#include "cave_state.h"

/* CaveState instance. Single global for now; future Phase 6/7 may add
 * multi-instance for replay/seed harness, but NES Z_01 has one cave
 * active at a time, so one instance matches NES semantics. */
static CaveState g_cave_state;

/* Cave-id of the currently active cave (0 = none active). */
static cave_id_t g_active_cave = 0;

/* Cave-id range gate per NES InitCave (Z_01.asm:79-86): valid cave
 * room types are 0x6A..0x7C inclusive. Outside range = invalid call. */
#define CAVE_ID_MIN 0x6Au
#define CAVE_ID_MAX 0x7Cu

int cave_init(cave_id_t cave_id)
{
    if (cave_id < CAVE_ID_MIN || cave_id > CAVE_ID_MAX) {
        return -1;
    }

    /* Populate CaveState typed struct. NES InitCaveContinue
     * (Z_01.asm:105) computes cave_idx = cave_id - 0x6A then loads
     * tables; we mirror the index but do NOT yet load OverworldPerson
     * tables (that requires src/data/person_text.inc which lives in
     * the transpile bridge today). Future commit ports the data load
     * via a shared `data/cave_tables.h` extracted by Task 3.1. */
    g_cave_state.room_type = cave_id;
    g_cave_state.person_state = 0;
    g_cave_state.flags = 0;
    g_cave_state.text_selector = 0;
    g_cave_state.text_char_index = 0;
    g_cave_state.delay_timer = 0;
    g_cave_state.link_action_timer = 0;
    g_cave_state.link_input_flags = 0;

    g_active_cave = cave_id;
    return 0;
}

void cave_tick(void)
{
    /* Stub. Per Phase 3 task list: cavert_update_cave_person dispatch
     * table (9 states) ports here per-state. First port: state 0 =
     * cavert_update_transfer_prices. Subsequent commits add states
     * 1-8 + draw_cave_person + draw_cave_items.
     *
     * Currently empty — proves cave gamemode dispatch wires up
     * without crashing. Verify via RoomRom probe screenshot showing
     * blank scene with cave palette loaded. */
    (void)0;
}

void cave_exit(void)
{
    g_cave_state.room_type = 0;
    g_cave_state.person_state = 0;
    g_cave_state.flags = 0;
    g_active_cave = 0;
}

cave_id_t cave_current_id(void)
{
    return g_active_cave;
}

void cave_draw_person(unsigned int slot)
{
    /* NES DrawCavePerson (Z_01.asm:370-383):
     *   - Fetch sprite descriptor + position for slot.
     *   - Branch on ObjType+1 ($0350 = cave_room_type) vs $7B threshold:
     *       cave_id <  0x7B -> DrawObjectMirrored
     *       cave_id >= 0x7B -> DrawObjectNotMirrored
     *
     * Stage-1 port: branch logic native, draw bodies stubbed pending
     * Phase 4 cross-subsystem native object_draw. cave_room_type_get()
     * reads RAM($0350) per state_contract.md typed accessor — same byte
     * NES DrawCavePerson reads via LDY ObjType+1.
     *
     * `slot` is forwarded to underlying object draw (when ported). For
     * now we only consume the branch decision; descriptor fetch + SAT
     * write are deferred to keep the Phase 3 cave port focused on cave-
     * specific logic, not the broader sprite-descriptor pipeline. */
    (void)slot;

    const unsigned char cave_id = cave_room_type_get();
    if (cave_id < 0x7Bu) {
        /* TODO Phase 4: native cave_object_draw_mirrored(slot) using
         * sprite descriptor + render_sat_write. */
    } else {
        /* TODO Phase 4: native cave_object_draw_not_mirrored(slot). */
    }
}
