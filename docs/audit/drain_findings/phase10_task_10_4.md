# Phase 10 Task 10.4 — Wire SFX Events

- **NES source**: `reference/aldonunez/Z_07.asm` SFX dispatch via
                  `SoundFXRequest`. Per-event SFX trigger sites
                  inside drained combat / inventory / world bodies.
- **Drained C**:  None — SFX trigger sites land inside drained
                  bodies. Adapter wrapper exposes
                  `audio_sfx_play(sfx)` (`src/abi/audio_abi.h`).
                  XGM PCM mixing handles the 7 NES DMC samples
                  (IDs 64..70).
- **Coverage**:   PARTIAL — adapter contract + manifest (8 SFX, 7
                  DPCM samples) shipped. Per call-site trigger
                  wiring DEFERRED on Debug.md side for the same
                  reason as Task 10.3: audio driver not linked into
                  Debug.md.
- **Stance**:     PARTIAL — adapter contract ADOPT; per call-site
                  trigger wiring deferred to Phase 11.

## SFX matrix (per master plan 10.4)

| SFX Event           | NES SFX id (from manifest) | Trigger callsite (deferred) |
|---------------------|----------------------------|-----------------------------|
| Sword swing         | (manifest sfx 1)           | `roomrom_combat.c` sword fork |
| Sword beam          | (manifest sfx 2)           | sword-beam spawn               |
| Boomerang           | (manifest sfx 3)           | boomerang_init                  |
| Bomb place          | (manifest sfx 4)           | bomb_place                      |
| Explosion           | (manifest sfx 5)           | bomb_detonate                   |
| Enemy hit           | (DMC sample)               | collision_dispatch monster hit  |
| Enemy death         | (DMC sample)               | enemy slot kill                 |
| Item pickup         | (manifest sfx 6)           | item-pickup gate (boss reward + L-block) |
| Rupee               | (manifest sfx 7)           | rupee credit drain (`hud_world_change_rupees`) |
| Heart               | (DMC sample)               | heart pickup                    |
| Door unlock         | (DMC sample)               | key consumption                  |
| Secret reveal       | (DMC sample)               | secret-trigger fire              |
| Low health warning  | (DMC sample)               | LINK_HEARTS dec → 2-hearts gate (option 9.4) |
| Boss sounds         | (DMC samples)              | boss INIT/UPDATE cry sites      |

14 trigger sites documented; 8 manifest SFX + 6 DPCM samples + boss
roar covering them. Call sites mapped to existing drained / native
subsystem entries.

## XGM channel dispatch

`audio_sfx_play(sfx)` round-robins XGM PCM channels CH2..CH4 so
music's CH1 stays clear. 4-channel PCM mixer at 14 kHz; 7 NES DMC
samples registered as XGM SFX IDs 64..70 (XGM reserves 1..63 for
music sequences).

## Deferral

Task 10.4 implementation work also blocked on
`task_10_3_audio_link_into_debug_md` (shared deferral with Task
10.3). Once the audio driver + adapter link into Debug.md, the 14
trigger sites land as ≤1-line `audio_sfx_play(SFX_ID_*)` calls inside
already-drained subsystems.

## Status

CLOSE (with deferrals) — Task 10.4 SFX matrix + adapter + XGM
channel layout all locked. Trigger wiring tracked as Phase 11
deferral.
