# z_07 Patch P37 — DEBUG_TELEPORT DPAD instant-teleport hook

## What the transpiler emits

At the top of `_L_z07_UpdateMode5Play_NotInMenu` (around z_07.asm:3254)
the straight 6502 → M68K transpile produces:

```
_L_z07_UpdateMode5Play_NotInMenu:
    ; Not in submenu.
    ;
    move.b  ($00F8,A4),D0
    andi.b #$10,D0
    bne.s  __far_z_07_0037
    jmp  BeginUpdateWorld
```

## What the patch changes it to

```
_L_z07_UpdateMode5Play_NotInMenu:
    ; Not in submenu.
    ;
    ifne DEBUG_TELEPORT
    jsr     _debug_teleport_check      ; PATCH P37: DPAD teleport
    tst.b   D0
    beq.s   _L_z07_UpdateMode5Play_NotInMenu_noTp
    rts
_L_z07_UpdateMode5Play_NotInMenu_noTp:
    endc
    move.b  ($00F8,A4),D0
    andi.b #$10,D0
    bne.s  __far_z_07_0037
    jmp  BeginUpdateWorld
```

## Why

Overworld tile/palette QA requires visiting all 128 OW rooms quickly. With
normal scroll-based movement each transition takes ~90–120 frames. A DPAD
instant-teleport lets a tester cover the whole grid in under a minute.

`_debug_teleport_check` in `genesis_shell.asm` performs the overworld /
mode / DPAD / edge gates and, when all satisfied, snaps RoomId to the
adjacent room via `NextRoomIdOffsets[dir]`, clears scroll/NT state,
relays out the room via `LayOutRoom`, and returns D0=1 so the hook skips
the frame's normal play update.

Wrapping both the hook and the routine body in `ifne DEBUG_TELEPORT`
means `DEBUG_TELEPORT equ 0` strips the feature entirely for release.

## Re-apply recipe

1. Run `tools/transpile_6502.py --all --no-stubs` — it inserts the
   `ifne DEBUG_TELEPORT` block at the anchor shown above.
2. If the anchor is missing the transpiler prints
   `WARNING: _patch_z07 P37 -- UpdateMode5Play_NotInMenu pattern not found`
   and you need to update the `old_not_in_menu` literal in the patch to
   match the new transpiler output.
3. `DEBUG_TELEPORT equ 1` is defined near the top of
   `src/genesis_shell.asm`; the routine body lives at the bottom of the
   same file (after all `zelda_translated/z_*.asm` includes).
