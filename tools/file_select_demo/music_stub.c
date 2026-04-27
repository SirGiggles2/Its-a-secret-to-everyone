/* tools/file_select_demo/music_stub.c — link-only stubs for proof ROM.
 *
 * Main ROM links real audio_driver implementations of music_play / music_tick.
 * Proof ROM keeps audio out of scope; these no-ops let fs_main reference the
 * symbols without pulling the driver in.
 */
void music_play(unsigned char bit) { (void)bit; }
void music_tick(void) {}
