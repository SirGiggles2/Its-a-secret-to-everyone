# T-160 Aquamentus fireball sprite sub-palette 3 (2026-09-29)

- **NES source**: `reference/aldonunez/Z_04.asm:Aquamentus_Shoot` and live NES OAM/CHR/PALRAM at connected L1 route ticks 8200, 8215, 8221, 8227.
- **Drained C**: `src/game/enemies/enemy_render.c:translate_tile`/`xlat_sat`; no alternate fireball renderer candidate.
- **Coverage**: PARTIAL (Aquamentus `$44/$45` sprite palette routing; other projectile types remain in their own tasks).
- **Stance**: EXTEND the linked OAM-to-SAT path.

Reproduction on prior `builds/Debug.md` SHA-256 `e3f9a52653d411d48a5a41704f35bf50ab628b19d206891d36088850ff7d7234`: `python tools/lockstep/run_lockstep.py tools/lockstep/presets/t013_boss_visual_astra_20260929.json --snap 8200,8215,8221,8227 --full`. At ticks 8215 and 8227, NES fireball tile `$44` uses OAM attr 3 (sprite palette `$0F,$0A,$29,$30`, green). Genesis displayed purple because generic attr 3 clamps to PAL2 and the sole fireball tile copy still uses pixel indices 1–3. `verify_aquamentus_visual.py` failed at tick 8215 (`NES#29 tile 44: color 64 != 2594`). Attr 0 at 8200 and attr 1 at 8221 had the expected colors.

The repair keeps the existing ROM-derived `$44/$45` pair for attrs 0–2. It uploads a second two-tile copy with only nontransparent indices biased 1–3 → 13–15, and selects that copy with PAL1 when OAM attr is 3. NES sprite palette 3 already occupies PAL1[13..15]. Both the full translator and cached SAT path apply the same rule. `RoomRom/src/roomrom_vram_map.h` reserves previously unused tiles 1426–1427; `verify_vram_budget.py` now checks overlap and VDP-table bounds for the pair. The sprite catalog and freshness sentinel were regenerated from those inputs.

Verification: `Debug.bat` passed and produced `builds/Debug.md` SHA-256 `fa259b45312a049969e067a3796ddf70d2ea58a78e88021ad090d635b2422676`. The focused route again ran 9065/9065 KEY ticks with zero KEY mismatches. `python tools/lockstep/verify_aquamentus_visual.py builds/reports/lockstep/t013_boss_visual_astra_20260929 8200 8215 8221 8227` matched **6 boss sprites, 8 fireballs, 964 nontransparent sprite pixels** including the previously failing green states. VRAM budget passed with FIREBALL_PAL3=1426..1427 and 108 tiles of contiguous tail headroom. The route's full-RAM **GATE FAIL** is unchanged: this new diagnostic has no ratchet baseline (131 unmasked cells); neither that check nor all boss/presentation behavior is claimed passing here.

Remaining: T-013 boss death/re-entry and connected presentation checks; other projectile consumers are outside this narrow sprite-palette repair. Music stays deferred.
