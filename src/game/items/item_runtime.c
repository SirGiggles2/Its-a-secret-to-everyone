#include "item_runtime.h"
#include "legacy_bridge.h"

static void itemrt_take_class0_complex(unsigned char item_slot) {
    unsigned char level_raw = ITEM_LEVEL_RAW;
    if (level_raw == 0) {
        return;
    }
    if (item_slot == 0x1B) {
        z01_take_power_triforce();
        return;
    }
    if (item_slot == 0x11) {
        ITEM_GOT_CLOCK_FLAG = 1;
    }
    {
        unsigned char level = (unsigned char)(level_raw - 1);
        if (level >= 8) {
            item_slot = (unsigned char)(item_slot + 2);
            level &= 7;
        } else {
            level &= 7;
        }
        INVENTORY_VALUE(item_slot) |= LevelMasks[level];
    }
    if (item_slot != 0x1A) {
        return;
    }
    z07_end_game_mode();
    GAME_MODE = 18;
}

static void itemrt_handle_class2(unsigned char item_slot) {
    unsigned char val = ITEM_VALUE_SCRATCH;
    if (val < INVENTORY_VALUE(item_slot)) {
        return;
    }
    INVENTORY_VALUE(item_slot) = val;
    if (item_slot != 0x0B) {
        return;
    }
    {
        unsigned char ring_val = LINK_RING_LEVEL;
        unsigned char color = LinkColors_CommonCode[ring_val];
        unsigned char save_slot = SAVE_SLOT_INDEX;
        unsigned char palette_off = SaveSlotToPaletteRowOffset[save_slot];
        MenuPalettesTransferBuf[20 + palette_off] = color;
    }
    z07_patch_and_cue_level_palettes_transfer();
}

static void itemrt_check_class1(unsigned char item_slot, unsigned char item_class) {
    if (item_class != 0x10) {
        if (item_class == 0x20) {
            itemrt_handle_class2(item_slot);
            return;
        }
        {
            unsigned char result = 0xFF;
            if (item_slot == 7 && result >= 3) {
                result = 2;
            }
            if (item_slot == 1 && result >= LINK_MAX_HEARTS) {
                result = LINK_MAX_HEARTS;
            }
            z01_set_item_value(result, item_slot);
        }
        return;
    }
    if (item_slot == 0x18) {
        unsigned char cur = INVENTORY_VALUE(item_slot);
        if (cur >= 0xF0) {
            return;
        }
        z01_set_item_value((unsigned char)(cur + 0x11), item_slot);
        return;
    }
    if (item_slot == 0x1C) {
        z01_take_5_rupees();
        return;
    }
    if (item_slot == 0x16) {
        z01_take_one_rupee();
        return;
    }
    if (item_slot == 0x19) {
        z01_take_hearts();
        return;
    }
    if (item_slot == 0x17) {
        z01_play_key_taken_tune();
    }
    if (item_slot == 0x14) {
        z01_take_hearts_no_sound();
        return;
    }
    {
        unsigned int sum = (unsigned int)ITEM_VALUE_SCRATCH + INVENTORY_VALUE(item_slot);
        unsigned char result = (sum > 0xFF) ? 0xFF : (unsigned char)sum;
        if (item_slot == 7 && result >= 3) {
            result = 2;
        }
        if (item_slot == 1 && result >= LINK_MAX_HEARTS) {
            result = LINK_MAX_HEARTS;
        }
        z01_set_item_value(result, item_slot);
    }
}

void itemrt_take_item(unsigned char item_id) {
    ITEM_SFX_PRIMARY = 8;
    if (item_id == 0x0E) {
        ITEM_SFX_PRIMARY = 2;
    }
    if (GAME_MODE != 5) {
        ITEM_FREEZE_FLAG = 0x80;
        ITEM_SFX_SECONDARY = 8;
        ITEM_PICKUP_ID = item_id;
    }
    {
        unsigned char item_slot = ItemIdToSlot[item_id];
        unsigned char descriptor = ItemIdToDescriptor[item_id];
        ITEM_VALUE_SCRATCH = descriptor & 0x0F;
        {
            unsigned char item_class = descriptor & 0xF0;
            if (item_class != 0) {
                itemrt_check_class1(item_slot, item_class);
                return;
            }
        }
        if (item_slot == 0x11 || item_slot == 0x10 || item_slot == 0x1A || item_slot == 0x1B) {
            itemrt_take_class0_complex(item_slot);
            return;
        }
        z01_set_item_value(ITEM_VALUE_SCRATCH, item_slot);
    }
}
