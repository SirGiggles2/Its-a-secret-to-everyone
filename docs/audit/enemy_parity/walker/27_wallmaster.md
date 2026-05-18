# $27 Wallmaster

- **NES source**: reference/aldonunez/Z_04.asm:4121 UpdateWallmaster
- **Drained C**:  src/game/enemies/enemy_special_bridge.c:515 enrt_update_wallmaster
- **Coverage**:   FULL
- **Stance**:     EXTEND

Behavior: 2-state machine. State 0 (idle in wall): gated on Link's
ObjState[0]==$40 + ObjTimer+1==0 + Link in trigger zone (X in {$20,
$D0} side walls OR Y in {$5D, $BD} top/bottom walls).
enrt_wallmaster_calc_start_position computes emergence X/Y. State 1
(walking along wall): MoveObject in dir; on $10/$F0 grid align,
advance step + tiles crossed; on 7th tile, captured-Link → GameMode=3
unfurl reset, else state=0 return.
