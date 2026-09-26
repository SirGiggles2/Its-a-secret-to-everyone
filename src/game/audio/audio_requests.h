#ifndef AUDIO_REQUESTS_H
#define AUDIO_REQUESTS_H

/* NES sound-request cells consumed like the NES sound engine (Z_00.asm
 * DriveSample / DriveEffect): SampleRequest $0601 -> DMC sample,
 * EffectRequest $0603 -> noise-channel effect. Call once per frame. */
void audio_requests_consume(void);

#endif
