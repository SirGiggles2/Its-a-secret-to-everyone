/* Host side core of tools/audit/asm_equiv: the NES memory both sides run
 * on, and the callee log shared with the 6502 stubs.
 *
 * Memory map (6502 side and g_mem alike): $0000-$07FF NES RAM, $6000-$7FFF
 * NES WRAM, $5000-$5FFF harness only:
 *   $5000 log index, $5001 per-case call index, $5002/$5003 scratch,
 *   $5004 first unexpected callee id (0 = none), $5100.. log bytes,
 *   $5200/$5300/$5400 per-call preset results (spec stubs). */
unsigned char g_mem[0x8000];
volatile unsigned char *nes_ram = g_mem;

#define H_LOG_IDX  0x5000u
#define H_CALL_IDX 0x5001u
#define H_UNEXP    0x5004u
#define H_LOG_BUF  0x5100u

void eq_log_byte(unsigned char v)
{
    g_mem[H_LOG_BUF + g_mem[H_LOG_IDX]] = v;
    g_mem[H_LOG_IDX] = (unsigned char)(g_mem[H_LOG_IDX] + 1u);
}

/* Auto-generated stubs for callees nobody expected call this. */
void eq_unexpected(unsigned char id)
{
    if (g_mem[H_UNEXP] == 0u) g_mem[H_UNEXP] = id;
}
