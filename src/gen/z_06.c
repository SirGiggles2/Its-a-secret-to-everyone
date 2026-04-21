/* z_06.c — Stage 3a: C port of z_06 code functions.
 * Data tables remain in z_06.asm (emitted by the transpiler in data-only mode).
 */

#include "../nes_abi.h"

#define NES_SRAM_BASE  0x6000u

extern void c_copy_bank_to_window(unsigned int bank);

extern const unsigned long LevelBlockAddrsQ1[];
extern const unsigned long LevelBlockAddrsQ2[];
extern const unsigned long LevelInfoAddrs[];
extern const unsigned long CommonDataBlockAddr_Bank6[];
extern const unsigned char LevelInfoUWQ2ReplacementAddrs[];
extern const unsigned char LevelInfoUWQ2ReplacementSizes[];
extern const unsigned char LevelBlockAttrsBQ2ReplacementOffsets[];
extern const unsigned char LevelBlockAttrsBQ2ReplacementValues[];

/* CopyBlock_ROM: copy from ROM source to NES RAM dest at ($02:$03 hi:lo).
 * Increments dest pointer byte-by-byte until it equals end addr ($04:$05).
 * Then increments submode ($13). Y index walks through source in parallel. */
static void CopyBlock_ROM(const unsigned char *src) {
    unsigned short y = 0;
    for (;;) {
        unsigned char dest_hi = RAM(0x0002);
        unsigned char dest_lo = RAM(0x0003);
        unsigned short dest = ((unsigned short)dest_hi << 8) | dest_lo;
        nes_ram[dest + y] = src[y];

        if (RAM(0x0002) == RAM(0x0004) && RAM(0x0003) == RAM(0x0005)) {
            RAM(0x0013)++;
            return;
        }

        /* Increment 16-bit dest address at $02:$03 (hi:lo, CLC; ADC #1) */
        unsigned char lo = RAM(0x0003);
        lo++;
        RAM(0x0003) = lo;
        if (lo == 0)
            RAM(0x0002)++;

        src++;
    }
}

static void FetchLevelBlockDestInfo(void) {
    RAM(0x0002) = 0x7E;
    RAM(0x0003) = 0x68;
    RAM(0x0004) = 0x7D;
    RAM(0x0005) = 0x6B;
}

static void FetchLevelInfoDestInfo(void) {
    RAM(0x0002) = 0x7E;
    RAM(0x0003) = 0x6B;
    RAM(0x0004) = 0x7D;
    RAM(0x0005) = 0x6C;
}

static void FetchDestAddrForCommonDataBlock(void) {
    RAM(0x0002) = 0xF0;
    RAM(0x0003) = 0x67;
    RAM(0x0004) = 0x7D;
    RAM(0x0005) = 0x68;
}

static void InitMode2_Sub0(void) {
    unsigned char level = RAM(0x0010);
    unsigned char idx = level;

    unsigned char profile = RAM(0x0016);
    unsigned char quest = nes_ram[0x062D + profile];

    const unsigned long *table = (quest != 0) ? LevelBlockAddrsQ2 : LevelBlockAddrsQ1;
    const unsigned char *src = (const unsigned char *)table[idx];
    FetchLevelBlockDestInfo();
    CopyBlock_ROM(src);
}

static void InitMode2_Sub1(void) {
    unsigned char level = RAM(0x0010);
    const unsigned char *src = (const unsigned char *)LevelInfoAddrs[level];
    FetchLevelInfoDestInfo();
    CopyBlock_ROM(src);
    RAM(0x0013) = 0;
    RAM(0x0011)++;
}

void z06_init_mode2_submodes(void) {
    unsigned char submode = RAM(0x0013);
    if (submode == 0)
        InitMode2_Sub0();
    else
        InitMode2_Sub1();
}

void z06_copy_common_data_to_ram(void) {
    const unsigned char *src = (const unsigned char *)CommonDataBlockAddr_Bank6[0];
    FetchDestAddrForCommonDataBlock();
    CopyBlock_ROM(src);
    RAM(0x0013) = 0;
}

static void PatchQ2Rooms(void) {
    for (signed char i = 7; i >= 0; i--) {
        unsigned char off = LevelBlockAttrsBQ2ReplacementOffsets[i];
        unsigned char val = LevelBlockAttrsBQ2ReplacementValues[i];
        nes_ram[NES_SRAM_BASE + 0x08FE + off] = val;
    }
    nes_ram[NES_SRAM_BASE + 0x0A09] = 123;
    nes_ram[NES_SRAM_BASE + 0x0A3A] = 123;
    nes_ram[NES_SRAM_BASE + 0x0A72] = 90;
    nes_ram[NES_SRAM_BASE + 0x08BA] = 114;
    nes_ram[NES_SRAM_BASE + 0x08F2] = 114;
    nes_ram[NES_SRAM_BASE + 0x0B3A] = 1;
    nes_ram[NES_SRAM_BASE + 0x0B72] = 0;
}

void z06_update_mode2_load_full(void) {
    c_copy_bank_to_window(6);

    unsigned char profile = RAM(0x0016);
    unsigned char quest = nes_ram[0x062D + profile];
    if (quest == 0)
        return;

    unsigned char level = RAM(0x0010);
    if (level == 0) {
        PatchQ2Rooms();
        return;
    }

    /* UW Q2 level info replacements */
    unsigned char idx = level << 1;
    /* ReplacementAddrs is accessed at -2 offset (no OW entry) */
    RAM(0x0000) = LevelInfoUWQ2ReplacementAddrs[idx - 2];
    RAM(0x0001) = LevelInfoUWQ2ReplacementAddrs[idx - 1];

    unsigned char count = LevelInfoUWQ2ReplacementSizes[level - 1];
    for (signed char i = (signed char)count; i >= 0; i--) {
        unsigned char ptr_lo = RAM(0x0000);
        unsigned char ptr_hi = RAM(0x0001);
        unsigned short src_addr = ((unsigned short)ptr_hi << 8) | ptr_lo;
        unsigned char val = nes_ram[src_addr + (unsigned char)i];
        nes_ram[NES_SRAM_BASE + 0x0BA7 + (unsigned char)i] = val;
    }
}
