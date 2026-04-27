/* tools/file_select_demo/music_stub.c — link-only stubs for proof ROM.
 *
 * Main ROM links real audio_driver implementations of music_play / music_tick
 * and the genesis_shell.asm fs_to_transpiled_trampoline. Proof ROM has none
 * of these — these no-ops let fs_main / fs_handoff reference the symbols
 * without pulling the driver / transpiled runtime in.
 */
void music_play(unsigned char bit) { (void)bit; }
void music_tick(void) {}

/* fs_handoff_to_transpiled in main ROM jumps into transpiled gameplay via
 * fs_to_transpiled_trampoline (genesis_shell.asm). Proof ROM has no
 * transpiled runtime; spin forever instead. */
void fs_to_transpiled_trampoline(void) {
    for (;;) { /* hang — proof ROM cannot enter transpiled gameplay */ }
}
