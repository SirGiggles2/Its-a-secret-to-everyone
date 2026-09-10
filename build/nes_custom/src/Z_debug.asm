; Ultra-minimal NES debug spawn arm — bank 7 resident.
; Caller writes type to $07F2 (non-zero); next frame spawns slot 1.
.INCLUDE "Variables.inc"
.SEGMENT "BANK_07_00"
.EXPORT DebugSpawnArm

DebugSpawnArm:
    LDA $07F2
    BEQ @x
    STA ObjType+1
    LDA $07F3
    STA ObjX+1
    LDA $07F4
    STA ObjY+1
    LDA #$01
    STA ObjDir+1
    LDA #$00
    STA $07F2
@x: RTS
