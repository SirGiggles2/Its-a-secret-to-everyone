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
| L4 | 0x13 | PASS, KEY 450/450 | Gleeok shot and neck parity repaired |
| L5 | 0x24 | PASS, KEY 750/750 | Statues repaired; 67 existing setup/flicker cells |
| L6 | 0x1C | PASS, KEY 750/750 | Gohma eye-timer parity repaired |
| L7 | 0x2A | PASS, KEY 750/750 | 67 existing setup/flicker cells |
| L8 | 0x3C | PASS, KEY 450/450 | Gleeok shot and neck parity repaired |
| L9 | 0x42 | PASS, KEY 750/750 | Ganon/Wizzrobe dir-zero tile probe repaired |

All nine boss idle rows have 67-cell entry setup/flicker baselines and
passed together 9/9. Final Windows `Debug.bat` ROM SHA-256:
`8A0748626AF9FEF4738F6FC3A1AF20EFF1A967D22133F148EF6CB6F2C2957197`.
The full gated suite passed 67/67. The mismatch report still has 27 open
cells and 13 accepted across these 67 baselines.

The L4/L8 Gleeok repair used NES `Z_04.asm` to correct three linked RAM
aliases (`$4E6` animation timer, `$4E7` body frame, `$510` writhe timer),
the current-neck selection, and `GleeokCurNeck` post-loop `$FF`. The
stretch routines had written to the next segment rather than the current
one. A reference-point comparison also moved a segment left when its
coordinate equaled the target; NES moves it right. Those corrections
restored the `$56` shots at NES coordinates in both rooms.

L6's `$042D` cell was Gohma's next-eye timer: NES decrements it on odd
`FrameCounter` values; the drain used even values. L9's `$0420/$049F`
cells were the Wizzrobe collision probe reused by Ganon. Direction zero
underflows its NES indexed lookup to `$FF`; the USA ROM reads bytes `$F0`
and `$9F` at table + `$FF` (file offsets `$12027/$12031`). The guarded
Genesis path had skipped that probe. Restoring the actual indexed offsets
made the tile match without changing Ganon's movement.

These are idle-room probes only. Next add controlled attack, vulnerability,
victory, reward and departure cases for each distinct boss, then connected
routes. No combat or whole-dungeon acceptance is claimed here.

## Follow-up: Gleeok fireball presentation

The L4 tick-350 NES screenshot shows a red fireball in front of Gleeok's
neck. The Genesis shot had the correct RAM position and SAT tile 1306 on
PAL3, but was almost entirely covered: the native projectile came after
all boss OAM entries in the Genesis SAT. NES OAM puts the shot at slot 28
and the neck at slots 29..55. The boss SAT sweep now emits native
fireballs before boss OAM, retaining normal native order outside boss
rooms. At tick 350 the shot is visible in the Genesis screenshot and
SAT slot 19 precedes neck slots 25/30. The fireball's orange/red palette
is not a byte-exact NES color match; that broader presentation work
remains open.

The changed renderer affects boss rooms, so all nine Q1 boss idle gates
were rerun: 9/9 PASS, no KEY or ratchet regressions (suite tag
`t171_boss_sat_order`, 24 s). Windows `Debug.bat` PASS. Latest local
ROM SHA-256:
`2FF4A959444BB28F9196B476AD6721260D7F6DE2749C7759BDE80EADCE54CE46`.
The earlier full 67/67 gate run was on the pre-order-change ROM.
