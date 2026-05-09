/* roomrom_rng.c — byte-for-byte port of Z_07.asm:499-515 @ScrambleRandom.
 *
 * NES asm:
 *   LDX #$18 ; Y = $0D ; LDA $00,X ; AND #$02 ; STA $00
 *   LDA $01,X ; AND #$02 ; EOR $00 ; CLC
 *   BEQ @LoopRandom ; SEC
 *   @LoopRandom: ROR $00,X ; INX ; DEY ; BNE @LoopRandom
 *
 * Translation: bit 1 of Random[0] EOR bit 1 of Random[1] -> carry-in.
 * Then ROR carry through the 13 bytes Random[0..12].
 */

#include "roomrom_rng.h"

void rng_seed(unsigned short seed)
{
    unsigned char lo = (unsigned char)(seed & 0xFF);
    unsigned char hi = (unsigned char)((seed >> 8) & 0xFF);
    unsigned char i;
    /* NES seed pattern from tools/bizhawk_t38_enemy_nes_capture.lua:501
     * is just incrementing bytes; we sprinkle the 16-bit seed across the
     * 13-byte array so any nonzero seed scrambles uniquely. */
    for (i = 0; i < RNG_RANDOM_LEN; i++) {
        unsigned char v = (i & 1) ? hi : lo;
        v ^= (unsigned char)(i * 0x53u);
        if (v == 0) v = 0x40 + i;  /* avoid all-zero state */
        RAM(RNG_RANDOM_BASE + i) = v;
    }
}

static void rng_scramble(void)
{
    /* Reproduce @ScrambleRandom tap+ROR-chain exactly. */
    unsigned char b0 = RAM(RNG_RANDOM_BASE + 0) & 0x02;
    unsigned char b1 = RAM(RNG_RANDOM_BASE + 1) & 0x02;
    unsigned char carry_in = (b0 ^ b1) ? 1 : 0;
    unsigned char i;
    for (i = 0; i < RNG_RANDOM_LEN; i++) {
        unsigned char v = RAM(RNG_RANDOM_BASE + i);
        unsigned char new_carry = v & 0x01;
        v = (unsigned char)((v >> 1) | (carry_in ? 0x80 : 0x00));
        RAM(RNG_RANDOM_BASE + i) = v;
        carry_in = new_carry;
    }
}

unsigned short rng_next(void)
{
    rng_scramble();
    return (unsigned short)(((unsigned short)RAM(RNG_RANDOM_BASE + 1) << 8)
                            | (unsigned short)RAM(RNG_RANDOM_BASE + 0));
}

unsigned short rng_peek(void)
{
    return (unsigned short)(((unsigned short)RAM(RNG_RANDOM_BASE + 1) << 8)
                            | (unsigned short)RAM(RNG_RANDOM_BASE + 0));
}
