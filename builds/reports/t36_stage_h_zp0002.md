# T36 Stage H — zero-page $0002 divergence at AssignObjSpawnPositions

## Finding

P33d landed (bank-1 pin in UpdatePersonState_Textbox). Cave text should
now render instead of "000000", but parity gate still 6/9. NES never
writes $0350=$6A; Gen does.

Per-frame sampling shows NES and Gen have **identical** obj_templ
($FF0002), cave_tmpl, room_flags, lvl_block at t=0/213/270/280/286/290.
Both sides read obj_templ=$00 at every sample around cave-enter.

### Why Gen still spawns $6A while NES does not

`AssignObjSpawnPositions` (z_05.asm:2256-2395) has two early exits
based on zero-page $0002:

    2262    move.b ($0002,A4),D0
    2263    beq    AssignSpecialPositions   ; $02 == 0 → skip InCave
    2264    cmpi.b #$37,D0
    2265    beq    AssignSpecialPositions   ; $02 == $37 → skip InCave

If $0002 == 0 at call time, function SKIPS the InCave branch and
never writes $0350=$6A. NES trace shows $0002=$00 at cave-enter
frame → NES takes this exit → cavetype stays 0.

Gen capture also reports $0002=$00 at the same frame samples, yet
Gen still writes $6A. Gen BP confirms the write fires at PC $45CEE
(line 2393 in the InCave branch).

**Conclusion:** $0002 on Gen is non-zero for the short window when
`AssignObjSpawnPositions` is actually executing, even though the
per-frame sample captures $0002=$00 (presumably because a later
routine in the same frame re-clears $0002 before the end-of-frame
sample). Some earlier routine on Gen leaves a stale value in $0002
that NES does not.

## Next investigation

Extend the Gen cavetype BP to also log $FF0002 at the moment of the
$0350 write (PC $45CEE).  That tells us what value of $0002 Gen has
at AssignObjSpawnPositions call-time.  Compare to NES behavior.

If $0002 has a specific stale value (e.g. $6A, left over from
CopyBlock_ROM at f=466 writing to $687E..$6B7D, which also reads
$0002/$0003 as ptr-lo/hi), the fix is to ensure $0002 is cleared
before InitMode_EnterRoom invokes AssignObjSpawnPositions — mirror
whatever NES does.

Alternatively, if transpiled code treats $0002 as scratch differently
than 6502 does (e.g., 16-bit access writing $0002..$0003 as a word
and leaving the low byte non-zero), that's a transpiler bug.

## Files touched

- `tools/transpile_6502.py` — added P33d hook in `_patch_z01`
- `src/nes_io.asm` — reverted failed auto-refresh
- `builds/reports/t36_stage_h_zp0002.md` — this doc

## Status

- Build: Zelda27.160, Checksum $F78A
- T36 parity: 6/9 (unchanged — text rendering fix doesn't address
  position divergence)
- Cave text rendering: fix landed, visual verification pending
