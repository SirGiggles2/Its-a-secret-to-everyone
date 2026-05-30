# Phase 0.C — Boss room IDs

**Date:** 2026-05-30
**Phase:** 8 (boss completion)
**Source:** `tools/parity/probe_nes_known_bosses.lua` table (probe-author
canonical; probe run 2026-05-30 against NES Z1 ROM).

## Canonical NES Z1 boss room IDs

| Level | Room ($EB) | Boss | NES ObjType |
|---|---|---|---|
| L1 | $35 | Aquamentus | $3D |
| L2 | $73 | Dodongo | $31/$32 |
| L3 | $0F | Manhandla | $3C |
| L4 | $45 | Gleeok 2-head | $43 |
| L5 | $06 | Digdogger (1 child) | $38 |
| L6 | $0F | Gohma Red | $33 |
| L7 | $23 | Aquamentus #2 | $3D |
| L8 | $1F | Gleeok 4-head | $45 |
| L9 | $1E | Patra Red | $47 |
| L9 | $1F | Ganon | $3E |

## Verification path

Probe `tools/parity/probe_nes_known_bosses.lua` iterates all 10 bosses
forcing `$10 = level`, `$EB = room`, `$12 = $06` (LoadLevel) then
`$12 = $05` (Play). Captures slot table `$034F+s` per slot for
`s = 1..19`. Output `C:/tmp/nes_known_bosses.txt`.

Iteration ran cleanly — all 10 entries produced output sections,
matching screenshots emitted to `C:/tmp/nes_boss_<name>.png`.

**Caveat:** `$6BBC LevelInfo_BossRoomId` mirror reads `$00` for every
forced level because the force-write path skips the natural file-load
flow that populates the mirror. The probe **table values are the
authoritative input** (room ID + level pair); the live `$6BBC` read is
diagnostic only and confirms the mirror is uninitialized under
force-warp.

## Genesis-side validation

Same room IDs are written to `$EB` by `tools/parity/probe_gen_real_bosses.lua`
which logs `$FF6BBC` after Debug.md install_uw runs. Phase B per-boss
probes inherit this room list.

## Phase B per-boss probe scaffolding

Each `tools/parity/probe_{nes,gen}_boss_<name>.lua` warps to the room
above for capture-frame baseline. L7 (Aquamentus-2) inherits the same
boss-type ObjType `$3D` as L1 but uses **Bank3468** CHR per
`BossPatternBlockSrcAddrs[6]` (per Z_03.asm:24-34). Phase A
`level_chr_boss_request(level)` must dispatch by **level**, not by
ObjType.

## Outstanding

- Genesis `$FF6BBC` mirror verify needs to run via
  `probe_gen_real_bosses.lua` once Debug.md install_uw path is
  exercised. Schedule before Phase F matrix gate.
- L9 hosts both Patra ($1E) and Ganon ($1F). Two separate boss-room
  entries in matrix.
