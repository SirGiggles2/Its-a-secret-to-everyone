# T-127 NES sound requests -> Genesis SFX

User report (2026-09-26): the sword swing played the beam sound.

Cause: Genesis played SFX by direct audio_sfx_play(n) calls with placeholder
DMC samples. The swing used DMC sample 1 (the sword-beam sample; NES swing is
EffectRequest $01, a noise effect). Enemy hit / death, item pickup, key, parry,
arrow and boomerang used unrelated samples (boss roars, Link hurt). Nothing
consumed the NES request cells SampleRequest $0601, Tune1Request $0602,
EffectRequest $0603, Tune0Request $0604 that the drains already write.

NES source: Z_00.asm DriveSample, DriveEffect (sword/arrow/flame/stairs/bomb/
sea noise effects, SwordSfxNotes etc.), DriveTune0 / DriveTune1
(TuneScripts0/1, NotePeriodTable, CustomEnvelopeTune1, VibratePitch).

Genesis:
- tools/audio/synth_noise_sfx.py -> data/audio/sfx_pcm_noise.{c,h}: sword,
  arrow, flame, bomb, sea rendered with the NES noise LFSR from the Z_00
  tables and frame rules (stairs already existed).
- tools/audio/synth_square_sfx.py -> data/audio/sfx_pcm_tunes.{c,h}: the 15
  square tunes (Tune0 bits 0-6, Tune1 bits 0-7) from a DriveTune0/1 register
  replay through an APU pulse model (tables parsed from Z_00.asm).
- src/game/audio/audio_requests.c: the only place gameplay sound starts;
  consumes $0601/$0602/$0603/$0604 each frame with the NES priority rules;
  channels: DMC samples + Tune1 CH2, noise effects CH3, Tune0 CH4 (CH1 plays
  the music's drum samples).
- Call sites now write the NES request cell: sword swing $0603|=1, arrow and
  boomerang $0603|=2, stairs $0603|=8, door $0601|=4, flute $0602 $10; the
  placeholder direct calls are removed.

Evidence:
- Request cells $0601-$0604 per frame equal to NES (t116_shot_right,
  t116_rod_right, t116_book_fire, t116_shot_hit: swing f51 $0603=$01, beam
  f63 $0601=$01, rod $0604=$04, candle $0603=$04, kill f400 $0602=$20 +
  $0604=$02).
- t116_shot_hit: 4 PCM starts (g_audio_pcm_calls): swing, beam, hit, death.
- Waveforms are rendered, not byte-verifiable (no NES PCM reference), same as
  the stairs SFX; ear check by the user.
- Suite (tools/lockstep/run_suite.py): no regressions.
