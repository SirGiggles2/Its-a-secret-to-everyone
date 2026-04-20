/* z_03.c — Stage 2d: C port of z_03 code functions.
 * Data tables remain in z_03.asm (emitted by the transpiler in data-only mode).
 * This file implements the 9 code functions that do pattern block transfer.
 */

#include "../nes_abi.h"

/* Import-side shims (defined in c_shims.asm) */
extern void c_copy_bank_to_window(unsigned int bank);
extern unsigned char c_ppu_read_2(void);
extern void c_ppu_write_6(unsigned int val);
extern void c_ppu_write_7(unsigned int val);
extern void c_turn_off_all_video(void);

/* Data tables remain in the asm side — linker resolves these */
extern const unsigned char LevelPatternBlockSrcAddrs[];
extern const unsigned char BossPatternBlockSrcAddrs[];
extern const unsigned char PatternBlockSrcAddrsUW[];
extern const unsigned char PatternBlockSrcAddrsOW[];
extern const unsigned char PatternBlockPpuAddrs[];
extern const unsigned char PatternBlockPpuAddrsExtra[];
extern const unsigned char PatternBlockSizesOW[];
extern const unsigned char PatternBlockSizesUW[];

#define PATTERN_BLOCK_INDEX 0x051D
#define CUR_LEVEL           0x0010

static void ResetPatternBlockIndex(void) {
    RAM(PATTERN_BLOCK_INDEX) = 0;
}

static void FetchPatternBlockAddrUW(void) {
    c_copy_bank_to_window(3);
    unsigned char idx = RAM(PATTERN_BLOCK_INDEX);
    idx <<= 1;
    RAM(0x0000) = PatternBlockSrcAddrsUW[idx];
    RAM(0x0001) = PatternBlockSrcAddrsUW[idx + 1];
}

static void FetchPatternBlockInfoOW(void) {
    c_copy_bank_to_window(3);
    unsigned char idx = RAM(PATTERN_BLOCK_INDEX);
    idx <<= 1;
    RAM(0x0000) = PatternBlockSrcAddrsOW[idx];
    RAM(0x0002) = PatternBlockSizesOW[idx];
    RAM(0x0001) = PatternBlockSrcAddrsOW[idx + 1];
    RAM(0x0003) = PatternBlockSizesOW[idx + 1];
}

static void FetchPatternBlockAddrUWSpecial(void) {
    c_copy_bank_to_window(3);
    unsigned char idx = RAM(CUR_LEVEL);
    idx <<= 1;
    RAM(0x0000) = LevelPatternBlockSrcAddrs[idx];
    RAM(0x0001) = LevelPatternBlockSrcAddrs[idx + 1];
}

static void FetchPatternBlockUWBoss(void) {
    c_copy_bank_to_window(3);
    unsigned char idx = RAM(CUR_LEVEL);
    idx <<= 1;
    RAM(0x0000) = BossPatternBlockSrcAddrs[idx];
    RAM(0x0001) = BossPatternBlockSrcAddrs[idx + 1];
}

static void FetchPatternBlockSizeUW(void) {
    unsigned char idx = RAM(PATTERN_BLOCK_INDEX);
    idx <<= 1;
    RAM(0x0002) = PatternBlockSizesUW[idx];
    RAM(0x0003) = PatternBlockSizesUW[idx + 1];
}

static void TransferPatternBlock_Bank3(void) {
    unsigned char idx = RAM(PATTERN_BLOCK_INDEX);
    idx <<= 1;
    c_ppu_write_6(PatternBlockPpuAddrs[idx]);
    c_ppu_write_6(PatternBlockPpuAddrs[idx + 1]);

    for (;;) {
        unsigned char lo = RAM(0x0000);
        unsigned char hi = RAM(0x0001);
        unsigned short addr = ((unsigned short)hi << 8) | lo;
        unsigned char val = nes_ram[addr];
        c_ppu_write_7(val);

        /* Increment 16-bit source address (little-endian at $00:$01) */
        lo = RAM(0x0000);
        lo++;
        RAM(0x0000) = lo;
        if (lo == 0) {
            hi = RAM(0x0001);
            hi++;
            RAM(0x0001) = hi;
        }

        /* Decrement 16-bit count (big-endian at $02:$03) */
        unsigned char cnt_lo = RAM(0x0003);
        unsigned char cnt_hi = RAM(0x0002);
        if (cnt_lo == 0) {
            cnt_hi--;
            RAM(0x0002) = cnt_hi;
        }
        cnt_lo--;
        RAM(0x0003) = cnt_lo;

        if (RAM(0x0002) == 0 && RAM(0x0003) == 0)
            break;
    }
    RAM(PATTERN_BLOCK_INDEX)++;
}

static void TransferLevelPatternBlocksUW(void) {
    do {
        FetchPatternBlockAddrUW();
        FetchPatternBlockSizeUW();
        TransferPatternBlock_Bank3();
    } while (RAM(PATTERN_BLOCK_INDEX) != 2);

    FetchPatternBlockAddrUWSpecial();
    FetchPatternBlockSizeUW();
    TransferPatternBlock_Bank3();

    FetchPatternBlockUWBoss();
    FetchPatternBlockSizeUW();
    TransferPatternBlock_Bank3();

    ResetPatternBlockIndex();
}

void z03_transfer_level_pattern_blocks(void) {
    c_turn_off_all_video();
    c_ppu_read_2();
    ResetPatternBlockIndex();

    if (RAM(CUR_LEVEL) != 0) {
        TransferLevelPatternBlocksUW();
        return;
    }

    /* Overworld path */
    do {
        FetchPatternBlockInfoOW();
        TransferPatternBlock_Bank3();
    } while (RAM(PATTERN_BLOCK_INDEX) != 2);
}
