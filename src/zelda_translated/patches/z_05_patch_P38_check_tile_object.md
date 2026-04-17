# z_05 Patch P38 — Restore missing `JSR CheckTileObject` in `LayoutRoomOrCaveOW`

## What the transpiler emits (bug)

Around `_L_z05_LayoutRoomOrCaveOW_SkipSecret:` (z_05.asm:7525) the raw
transpile produces:

```
_L_z05_LayoutRoomOrCaveOW_SkipSecret:
    move.b  (A5)+,D0  ; PLA    jsr     CheckTileObject
    jsr     WriteSquareOW_P35             ; PATCH P35b: OW direct workbuf write
```

The string `"    jsr     CheckTileObject"` was absorbed into the PLA
instruction's trailing comment — the actual `JSR CheckTileObject`
instruction was never emitted.

## Root cause

NES source (reference/aldonunez/Z_05.asm:5861-5862):

```
@SkipSecret:
    PLA                         ; Restore primary square, if it wasn't modified above.
    JSR CheckTileObject
```

The `PLA` line has a long trailing comment. The transpiler's comment-
carry logic appears to concatenate the NEXT source line onto the PLA's
comment string when the PLA's comment word-wraps or mentions a routine
name that matches a label, skipping the actual emission of `JSR
CheckTileObject`.

## What the patch changes it to

```
_L_z05_LayoutRoomOrCaveOW_SkipSecret:
    move.b  (A5)+,D0  ; PLA
    jsr     CheckTileObject   ; PATCH P38: restore dropped JSR
    jsr     WriteSquareOW_P35             ; PATCH P35b: OW direct workbuf write
```

## Why it matters

`CheckTileObject` maps a primary square value in the range `$E5..$EA`
(tree / rockwall / armos variants) to the corresponding cave-entrance
tile-object primary (`$C8..$D8`) and stores the tile-object's world
coordinates. Without it, rooms that trigger a "secret found" overlay —
especially any room where `@MakeCave` fires on primary `$E6` — end up
writing the raw rock-wall primary into the workbuf instead of the
cave-stair primary `$D8`.

This is the byte-level source of the room76 parity report's 220 plane
tile mismatches: positions expecting `$D8/$DA` (cave stairs) show up as
`$E6`-family tiles in the Genesis workbuf.

## Re-apply recipe

1. Run `tools/transpile_6502.py --all --no-stubs`.
2. The patch prints either
   `_patch_z05 P38: restored JSR CheckTileObject in LayoutRoomOrCaveOW`
   (success) or
   `WARNING: _patch_z05 P38 -- CheckTileObject PLA-comment anchor not found`
   (transpiler output drifted).
3. If the warning fires, grep the fresh z_05.asm for
   `; PLA    jsr     CheckTileObject` or the current comment-capture
   shape and update the `p38_old` literal in transpile_6502.py
   accordingly.

## Long-term follow-up

The transpiler comment-carry behavior that dropped the `JSR` is
suspected to affect other sites too. After this fix, grep the generated
banks for `; <opcode>    jsr     [A-Z]` patterns and evaluate each.
