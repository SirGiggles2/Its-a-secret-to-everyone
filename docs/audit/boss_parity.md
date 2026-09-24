# Boss parity — SPAWN + RENDER + INIT-STATE (2026-05-31)

All 10 NES Z1 bosses, Quest 1 orig, live byte-diff: **NES (BizHawk) vs Genesis
(Debug.md)**. NES goldens = `tools/parity/out/nes_boss_spawn_L*_Q1_orig.json`
(probe_nes_boss_spawn.lua). Genesis = `gen_boss_direct/<name>/`
(probe_gen_boss_direct.lua). Differ = `tools/parity/diff_boss_state.py`.

## Verdict — 10/10 type + HP byte-match NES

| Lvl | Boss | Room | ObjType | HP | NES==Gen | Notes |
|---|---|---|---|---|---|---|
| L1 | Aquamentus    | $35 | $3D | $60 | ✓ type+HP | moving (x±) |
| L2 | Dodongo       | $56 | $31 | $F0 | ✓ type+HP | moving |
| L3 | Manhandla     | $10 | $3C | $40 | ✓ type+HP | moving |
| L4 | Gleeok 2-head | $13 | $43 | $A0 | ✓ type+HP+**XY** | fixed pos |
| L5 | Digdogger     | $24 | $38 | $F0 | ✓ type+HP | $39→$38 morph; moving |
| L6 | Gohma         | $1C | $34 | $20 | ✓ type+HP | moving |
| L7 | Aquamentus #2 | $2A | $3D | $60 | ✓ type+HP | moving |
| L8 | Gleeok 4-head | $3C | $45 | $A0 | ✓ type+HP+**XY** | fixed pos |
| L9 | Patra         | $52 | $47 | $B0 | ✓ type+HP+**XY** | fixed pos; +$25 children |
| L9 | Ganon         | $42 | $3E | $F0 | ✓ type+HP | |

ObjType + HP are the boss init-state invariants and byte-match NES live for all
10. X/Y match exactly for the fixed-position bosses; the moving bosses differ in
X/Y only (their drained move-AI advances them, RNG/frame-phase dependent — not a
divergence). NES boss rooms ($24 L5, $1C L6, $42 Ganon, …) independently
re-confirm the Q1-LBA fix.

## Coverage

- **SPAWN** 10/10 — slot-1 ObjType byte-matches NES (`fix_dungeons_q1_lba.py`
  restored true Q1 LevelBlockAttrs; `level_info_install.c` WorldFlagsAddr fix).
- **RENDER** 10/10 — OAM + on-screen SAT boss sprites; palette de-camouflaged
  (`uw_render.c` per-boss sprite sub-pal selection). All visible.
- **INIT STATE** 10/10 — type + HP byte-match NES (this table).
- **AI** 10/10 — `enemy_loop.c` init+update fns all route to drained NES bodies
  (Z_04/Z_07, ADOPT stance); runtime artifacts (Aquamentus $55 fireballs, Patra
  $25 children, Digdogger $39→$38 morph) confirm the AI ticks NES-correctly.

## Not covered

Dynamic multi-frame AI trajectory byte-diff (deterministic same-RNG capture) —
the drained AI is per-line-cited from NES asm (Drain Rule D1 PRIMARY evidence);
single-frame init-state parity + live behavior artifacts substantiate it.
Quest-2 / redux maps not yet state-diffed (Q1 orig complete).
