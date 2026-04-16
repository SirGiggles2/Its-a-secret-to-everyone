# T36 Stage E — root cause: phantom cave-person

## Finding

Gen spawns a cave-person object at slot 0 ($0350=$6A) during cave enter.
NES does NOT ($0350=0). The phantom cave-person halts Link via
SetUpCommonCaveObjects (writes $00AC=$40) and runs UpdatePersonState_Textbox
(drives $00AD=1, $0029=6-count cycling).

## Evidence (per-frame trace t=289..560)

| t    | NES $0350 | NES $00AD | NES $0029 | Gen $0350 | Gen $00AD | Gen $0029 | Gen $00AC |
|------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| 289  | 0         | 0         | 0         | $6A       | 0         | 0         | 0         |
| 295  | 0         | 0         | 0         | $6A       | 0         | 0         | $40       |
| 309  | 0         | 0         | 0         | $6A       | 1         | 5         | $40       |
| 550  | 0         | 0         | 0         | $6A       | 1         | 4         | $40       |

NES stays 0 throughout. Gen sticks on phantom person forever.

## Code path on Gen

`z_05.asm:2355 _L_z05_AssignObjSpawnPositions_CheckCaves`:
```
move.b  ($0012,A4),D0      ; mode
cmpi.b  #$0B,D0
beq  _L_z05_AssignObjSpawnPositions_InCave
```
In mode $0B, InCave branch fires. Calculates:
```
sram_val = SRAM[$08FE + $00EB]
cave_index = ((sram_val & $FC) - $40) >> 2
$0350 = $6A + cave_index
```

For cave_index=0 → $0350=$6A → phantom person type.

## Why NES doesn't hit InCave

Possibilities (need further trace):
1. NES never calls AssignObjSpawnPositions in this cave path
2. NES hits the function but exits earlier via `$0002` (object template type)
   check at line 2262-2265
3. NES calculation yields something different via different $00EB/SRAM value

## Downstream symptom chain

1. Gen $0350=$6A → InitCave → SetUpCommonCaveObjects halts Link ($00AC=$40)
2. Cave-type $6A falls through to InitCaveContinue (not TakeType) → runs
   textbox state machine
3. UpdatePersonState_Textbox advances $00AD and decrements $0029
4. `jsr UnhaltLink` at z_01.asm:900 fires only when textbox reaches page 3
   (D3=2 at ChangeLine)
5. Textbox text on Gen never advances to that condition, so UnhaltLink
   never fires, $00AC stays $40 forever → Link_HandleInput skips
   FilterInput → $03F8 stale → ModifyDirAtGridPoint no match →
   SetObjDirAndInputDir never writes $0098 → Link frozen.

## Next steps

Add $00EB, $04CD, $0002, $034E to captures and rerun to identify
which predicate in AssignObjSpawnPositions NES takes but Gen doesn't.
The real fix is probably in whoever sets $00EB (cave level-block index)
or $0002 (object template type) prior to mode $0B entry.
