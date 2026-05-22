/* mode_wingame.h — Mode 0x13 WinGame ending dispatch.
 *
 * NES source: reference/aldonunez/Z_02.asm:3236 UpdateMode13WinGame.
 * Five sub-states (Sub0 flash, Sub1/2 text streamer, Sub3 credits,
 * Sub4 final). Sub0 native; Sub1-4 stubbed pending port (see file).
 */
#ifndef MODE_WINGAME_H
#define MODE_WINGAME_H

void mode13_wingame_update(void);

#endif
