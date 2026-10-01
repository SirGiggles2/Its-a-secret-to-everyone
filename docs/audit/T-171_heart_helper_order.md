# T-171 — heart helper sequencing (2026-10-01)

- **NES source:** `reference/aldonunez/Z_01.asm:TakeHeartsNoSound, CompareHeartsToContainers`; `Z_05.asm:WorldFillHearts`.
- **Drained C:** `src/core/core_runtime.c:corert_take_hearts_no_sound`; active `src/game/core/core_dispatch.c:core_take_hearts_no_sound` and `src/game/room/room_dispatch.c:room_world_fill_hearts`.
- **Coverage:** FULL for these compare/cap branches; not every healing source.
- **Stance:** EXTEND existing drained/native implementations.

Claude committed the earlier Codex Dodongo finding in `3b2416f2`: the NES helper stores container count in $00 before returning whole-heart count. The old helper omitted that store; a full-health heart pickup at tick 956 produced $066F=23 instead of NES 22. Remaining C expressions compared a function call that writes $00 with a read of $00 in the same equality expression. C does not specify operand evaluation order. Explicitly complete the helper call before reading $00, matching NES JSR then CMP. Apply to native/drained heart awards and shared animated refill.

## Verification

Windows `Debug.bat` PASS. ROM SHA-256 `DBC24AAAE0D07A2124EA78DD3D60AFF3110231FCD73CC381C9706E0F17769ADD`. Includes pre-existing uncommitted flute/whirlwind work; this commit stages only heart sequencing and documentation.

- `t171_dodongo_bomb_trial`: GATE PASS **1150/1150**, baseline unchanged (67 cells), no new/earlier differences. Controller bombs at 622/722; Dodongo consumes both, dies, drops an item; Link picks up its heart at 956 without exceeding capacity. SCREEN MATCH at 850 (death), 950 (drop), 956 (pickup), 1149 (settled).
- Named refill consumer `t050_pond_fairy`: GATE PASS **1364/1364**, baseline unchanged (66 cells), no new/earlier differences. Existing partial-health fixture reaches pond and refills.
- Reports: `builds/reports/lockstep/t171_dodongo_bomb_trial/`, `builds/reports/lockstep/t050_pond_fairy/`.

Dodongo fixture stages level/room and initial Link/bomb selection at 620; no further state correction. Establishes these boss/pickup mechanics, not connected L2 progression, rejected sword/bomb actions, stun-then-sword behavior, dungeon reward/departure or persistence. No full-suite claim for this ROM. Claude's 73/73 claim predates this change and working-tree build.
