#include "save_menu_runtime.h"

extern const unsigned char ProfileNameAddrsLo[];
extern const unsigned char ProfileNameAddrsHi[];
extern void c_import_sram_commit(void);

void savert_update_mode_d_save_sub2(void) {
    c_import_sram_commit();
    MODE_VALUE = 0;
    SUBMODE_VALUE = 1;
}

void savert_fetch_profile_name_address(void) {
    unsigned char idx = SAVE_SLOT_INDEX;
    COMBAT_HARM_FLAG = ProfileNameAddrsLo[idx];
    COMBAT_THRESHOLD_X = ProfileNameAddrsHi[idx];
}
