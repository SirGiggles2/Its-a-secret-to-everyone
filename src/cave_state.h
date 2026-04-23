#ifndef CAVE_STATE_H
#define CAVE_STATE_H

#include "nes_abi.h"

/* Cave/person state map for promoted z_01 cave runtime code. Use names
 * at the owned-C boundary so cave logic stops depending on raw offsets.
 */
#define CAVE_TMP0                        RAM(0x0000)
#define CAVE_TMP1                        RAM(0x0001)
#define CAVE_TMP2                        RAM(0x0002)
#define CAVE_TMP3                        RAM(0x0003)
#define CAVE_TMP4                        RAM(0x0004)
#define CAVE_RANDOM_A                    RAM(0x0019)
#define CAVE_RANDOM_B                    RAM(0x001A)
#define CAVE_DELAY_TIMER                 RAM(0x0029)
#define CAVE_LINK_ACTION_TIMER           RAM(0x00AC)
#define CAVE_PERSON_STATE                RAM(0x00AD)
#define CAVE_LINK_INPUT_FLAGS            RAM(0x00F8)
#define CAVE_ROOM_TYPE                   RAM(0x0350)
#define CAVE_FLAGS                       RAM(0x0413)
#define CAVE_TEXT_SELECTOR               RAM(0x0415)
#define CAVE_TEXT_CHAR_INDEX             RAM(0x0416)
#define CAVE_ACTIVE_WARE_INDEX           RAM(0x0421)
#define CAVE_WARE_ITEM(idx)              RAM(0x0422 + (idx))
#define CAVE_TRANSFER_PRICE_COUNT        RAM(0x042E)
#define CAVE_TRANSFER_PRICE_OFFSET       RAM(0x042F)
#define CAVE_PRICE(idx)                  RAM(0x0430 + (idx))
#define CAVE_SELECTED_WARE_INDEX         RAM(0x0438)
#define CAVE_PRIZE_ORDER(idx)            RAM(0x0448 + (idx))
#define CAVE_TEXT_LINE_ADDR_LO           RAM(0x045F)
#define CAVE_MONEY_GAME_PERM(idx)        RAM(0x046C + (idx))
#define CAVE_MONEY_GAME_AMOUNT(idx)      RAM(0x046F + (idx))
#define CAVE_TEXT_TICK_SFX               RAM(0x0604)
#define LINK_RUPEES                      RAM(0x066D)
#define CAVE_ROOM_SCRIPT_STATE           RAM(0x0666)
#define CAVE_DOOR_REPAIR_RUPEE_DELTA     RAM(0x067E)

#define CAVE_TRANSFER_BUF_CHAR_BASE      0x0302
#define CAVE_TRANSFER_BUF_PRICE_SIGN(off) RAM(0x0306 + (off))
#define CAVE_TRANSFER_BUF_PRICE_HUNDREDS(off) RAM(0x0307 + (off))
#define CAVE_TRANSFER_BUF_PRICE_TENS(off) RAM(0x0308 + (off))
#define CAVE_TRANSFER_BUF_PRICE_UNITS(off) RAM(0x0309 + (off))

#define CAVE_WARE_DRAW_SLOT              19u
#define CAVE_WARES_PER_ROOM              3u

#endif
