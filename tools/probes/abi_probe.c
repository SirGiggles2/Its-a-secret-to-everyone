/* tools/probes/abi_probe.c
 *
 * S0 ABI proof. Compile with the SAME flags build.bat uses for src/*.c
 * (especially -ffixed-a4) and inspect the listing to record:
 *   - return-value register usage for u32 vs pointer
 *   - argument-passing for mixed (u16, u32, void*) signatures
 *   - callee-saved register set actually emitted
 */

typedef unsigned int   u32;
typedef unsigned short u16;
typedef unsigned char  u8;

/* Force out-of-line by putting in its own translation unit and avoiding inline. */
__attribute__((noinline)) u32 abi_ret_u32(void) {
    return 0xDEADBEEFu;
}

__attribute__((noinline)) void *abi_ret_ptr(void) {
    return (void *)0xC0FFEE00u;
}

__attribute__((noinline)) u32 abi_arg_mix(u16 a, u32 b, void *p) {
    return (u32)a + b + (u32)(unsigned long)p;
}

/* Reference all three so the compiler emits them. */
u32 (*const abi_probe_table[3])(void) = {
    (u32 (*)(void))abi_ret_u32,
    (u32 (*)(void))abi_ret_ptr,
    (u32 (*)(void))abi_arg_mix,
};
