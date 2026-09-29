# T-013 connected Aquamentus revisit (2026-09-29)

- **NES source**: `reference/aldonunez/Z_04.asm:Aquamentus_Draw`/boss room-flag handling and live NES room `$35` OAM, nametable and RAM.
- **Drained C**: `src/game/enemies/enemy_boss_bridge.c` and `src/game/enemies/enemy_render.c`; linked room-entry and world-flag paths.
- **Coverage**: PARTIAL (Original L1 Aquamentus cleared-room revisit after controller fight and heart collection; other bosses and post-save re-entry remain separate).
- **Stance**: VERIFY, no production code changed.

`tools/lockstep/presets/t013_aqua_revisit_astra_20260929.json` reuses the connected controller script through tick 8334, after Aquamentus is defeated, its heart is taken and Link has walked into east room `$36`. The only new input is 100 left ticks followed by 100 idle ticks, with no RAM staging. `python tools/lockstep/run_lockstep.py tools/lockstep/presets/t013_aqua_revisit_astra_20260929.json --snap 8334,8400,8450,8533 --full` ran NES and Genesis on `builds/Debug.md` SHA-256 `fa259b45312a049969e067a3796ddf70d2ea58a78e88021ad090d635b2422676`.

The route matched all **8,534/8,534 KEY ticks**. Both consoles were in room `$36` with room `$35` flag `$20` at tick 8334, crossed back into `$35` at tick 8348, and remained in room `$35` with the flag `$20` through tick 8533. No boss-type object `$31–$48` occupied the live enemy slots on either system at 8348, 8450 or 8533. NES OAM and Genesis SAT had zero boss sprites and zero fireballs at 8450 and 8533. The NES nametable-to-Genesis plane comparison at those two settled revisit frames was **704/704 cells exact**. The Genesis frame at 8533 visibly shows the empty boss room.

The new diagnostic's full-RAM **GATE FAIL** has no ratchet baseline (132 unmasked cells); this is not a full-RAM acceptance claim. Separate connected save/reopen evidence verifies the boss flag is serialized, but this specific revisit did not close/reopen the emulator. Other P1 child behaviors, including death-spark presentation, remain open.
