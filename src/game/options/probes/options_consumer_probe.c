/* Phase 9 Task 9.4 — Option consumer probe (in-ROM tests). */

#include "options_consumer_probe.h"
#include "../options_runtime.h"
#include "../options_state.h"
#include "../options_consumer.h"
#include "../../../../RoomRom/src/inventory.h"

#define PROBE  ((volatile unsigned char *)OPTIONS_CONSUMER_PROBE_BASE)

static void stamp_magic(void)
{
    unsigned int i;
    PROBE[0] = 'C';
    PROBE[1] = 'N';
    PROBE[2] = 0x01u;
    for (i = 3u; i < 16u; ++i) PROBE[i] = 0u;
}

static unsigned char test_defaults_3_hearts_8_bombs(void)
{
    options_runtime_init();
    options_consumer_apply_inventory_at_start();
    return (g_inventory.heart_values == 0x33u
            && g_inventory.max_bombs == 8u) ? 1u : 0u;
}

static unsigned char test_start_hearts_7(void)
{
    options_runtime_init();
    options_set((unsigned int)OPTION_ID_START_HEARTS, 7u);
    options_consumer_apply_inventory_at_start();
    return (g_inventory.heart_values == 0x77u) ? 1u : 0u;
}

static unsigned char test_bomb_upgrade_plus4(void)
{
    options_runtime_init();
    options_set((unsigned int)OPTION_ID_BOMB_UPGRADE,
                OPTIONS_BOMBUPG_PLUS4);
    options_consumer_apply_inventory_at_start();
    return (g_inventory.max_bombs == 12u) ? 1u : 0u;
}

static unsigned char test_bomb_upgrade_plus8(void)
{
    options_runtime_init();
    options_set((unsigned int)OPTION_ID_BOMB_UPGRADE,
                OPTIONS_BOMBUPG_PLUS8);
    options_consumer_apply_inventory_at_start();
    return (g_inventory.max_bombs == 16u) ? 1u : 0u;
}

static unsigned char test_start_hearts_16_clamps_to_15(void)
{
    options_runtime_init();
    options_set((unsigned int)OPTION_ID_START_HEARTS, 16u);
    options_consumer_apply_inventory_at_start();
    /* heart_values nibble caps at 15 -> packed 0xFF (max=15, cur=15). */
    return (g_inventory.heart_values == 0xFFu) ? 1u : 0u;
}

void options_consumer_probe_run(void)
{
    /* Snapshot mutable state — tests poke g_options via options_set and
     * g_inventory via apply_inventory_at_start. Both are restored at
     * the end so the live gameplay session sees the real options state
     * after the probe runs. */
    unsigned char saved_heart_values  = g_inventory.heart_values;
    unsigned char saved_heart_partial = g_inventory.heart_partial;
    unsigned char saved_max_bombs     = g_inventory.max_bombs;

    unsigned char bits = 0u;
    unsigned char passes = 0u;
    unsigned char total = 5u;

    stamp_magic();

    if (test_defaults_3_hearts_8_bombs())          { bits |= 0x01u; ++passes; }
    if (test_start_hearts_7())                     { bits |= 0x02u; ++passes; }
    if (test_bomb_upgrade_plus4())                 { bits |= 0x04u; ++passes; }
    if (test_bomb_upgrade_plus8())                 { bits |= 0x08u; ++passes; }
    if (test_start_hearts_16_clamps_to_15())       { bits |= 0x10u; ++passes; }

    PROBE[3] = total;
    PROBE[4] = passes;
    PROBE[5] = bits;

    /* Restore mutated state. options_runtime_init resets g_options to
     * defaults; the live game-start path in roomrom_debug_enter ran
     * BEFORE this probe so the post-restore state matches what the
     * debug-entry expected (defaults + apply_inventory_at_start
     * already populated g_inventory). */
    options_runtime_init();
    g_inventory.heart_values  = saved_heart_values;
    g_inventory.heart_partial = saved_heart_partial;
    g_inventory.max_bombs     = saved_max_bombs;
}
