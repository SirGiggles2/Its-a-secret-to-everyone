/* mode_wingame.h — Mode 0x13 WinGame ending dispatch.
 *
 * NES source: reference/aldonunez/Z_02.asm:3236 UpdateMode13WinGame.
 * Initialization, flash and text use the native mode owner. Credits
 * presentation and final quest/save reset remain pending (see tracker).
 */
#ifndef MODE_WINGAME_H
#define MODE_WINGAME_H

void mode13_wingame_update(void);
unsigned char mode13_wingame_draws_link(void);

#endif
