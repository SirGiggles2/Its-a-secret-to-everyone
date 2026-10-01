# T-171 Q1 boss idle sweep and L5 statue repair

Build: Windows `Debug.bat` PASS, `builds/Debug.md` SHA-256
`30F0134994A966F0D7BFF7229AD3BB4D9B760DB623E380159B3E7B528725D656`.
Reference: live NES lockstep captures, `reference/aldonunez/Z_04.asm`
`UpdateStatues` and `Z_07.asm` underworld `UpdateMode5Play` tail.

## 1. Identify the real problem

Q1 L5 boss room `$24` initially had 40 KEY failures: NES spawned statue
fireballs in monster slots 9–11 from tick 302; Genesis left those slots
empty. The problem was not Dodongo/Gleeok art or a room-data mismatch:
both emulators loaded room `$24` at tick 301.

## 2. Research evidence

The NES calls `UpdateStatues` after its object loop on every underworld
play tick (`Z_07.asm:1978`). Its source checks unique layouts `$24/$23`,
decrements four/two shooter timers, and emits `$55` fireballs. The same
body had already been drained into `src/oracle/enemies/enemy_boss_runtime.c`
but was absent from the linked native `enemy_loop_tick` tail. The first
NES/Genesis RAM difference was `$0358` and statue coordinates at tick 302.

## 3. Structural fix

Promoted the drained statue-update behavior into
`src/game/enemies/enemy_loop.c` and called it before the underworld secret
checks. It uses the NES layout, timing, coordinates and existing shot
creation path. No one-room special case was added.

## 4. Verification and remaining work

Focused L5 replay: KEY 750/750, no runtime ratchet cells beyond the
existing 67-cell entry setup/flicker baseline. NES and Genesis tick-350
screenshots both show the L5 room, Digdogger and a statue shot. The
inherited 58-preset suite passed 58/58 after this change. The runner's
final `gen.png` can be black after emulator shutdown; live-tick snapshots
are the valid presentation evidence (`gen.f00350.png` / `nes.f00350.png`
under `builds/reports/lockstep/t171_boss_l5/`).

The new presets warp Q1 to each level at tick 50, then reload the boss
room from the ROM-derived `uw_levelN_quest1_rooms.json` at tick 300. They
cover room entry and idle boss behavior, not a fight, victory, reward or
departure. L3/L4/L8 stop after 450 ticks because an idle Link dies and
the play-clock capture otherwise waits in death mode.

| Level | Boss room | Result | First open evidence |
|---|---:|---|---|
| L1 | 0x35 | PASS, KEY 750/750 | 67 existing setup/flicker cells |
| L2 | 0x0E | PASS, KEY 750/750 | 67 existing setup/flicker cells |
| L3 | 0x4D | PASS, KEY 450/450 | 67 existing setup/flicker cells |
| L4 | 0x13 | FAIL, 40 KEY cells | Missing `$56` shot in slot 11 at tick 331; Gleeok internal state differs from tick 303 |
| L5 | 0x24 | PASS, KEY 750/750 | Statues repaired; 67 existing setup/flicker cells |
| L6 | 0x1C | TODO, KEY 750/750 | `$042D` Gleeok head info at tick 303; no baseline yet |
| L7 | 0x2A | PASS, KEY 750/750 | 67 existing setup/flicker cells |
| L8 | 0x3C | FAIL, 40 KEY cells | Missing `$56` shot in slot 11 at tick 309; Gleeok internal state differs from tick 303 |
| L9 | 0x42 | TODO, KEY 750/750 | `$0420/$049F` at tick 590; no baseline yet |

Five PASS rows have ratchet baselines and passed together 5/5. L4/L6/L8/L9
presets are intentionally unbaselined; failures remain visible. A trial
Gleeok neck-index comparison reduced non-KEY differences but did not
restore shots, so it was reverted before the verified ROM build. Next
trace the earliest L4/L8 Gleeok state onset against `UpdateGleeok`, then
verify shot appearance and gameplay. L6/L9 non-KEY cells need separate
triage. After idle coverage, add real attacks, vulnerability, reward and
departure cases per boss.
