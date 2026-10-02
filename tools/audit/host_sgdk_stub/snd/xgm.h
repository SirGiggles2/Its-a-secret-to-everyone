/* Host-only SGDK stand-in (see genesis.h). */
#include "../genesis.h"
#ifndef STUB_XGM_H
#define STUB_XGM_H
typedef enum { SOUND_PCM_CH_AUTO = -1, SOUND_PCM_CH1 = 0, SOUND_PCM_CH2,
               SOUND_PCM_CH3, SOUND_PCM_CH4 } SoundPCMChannel;
#define Z80_DRIVER_XGM 6
void Z80_loadDriver(); void XGM_setPCM(); void XGM_startPlay();
void XGM_startPlayPCM(); void XGM_stopPlay();
#endif
