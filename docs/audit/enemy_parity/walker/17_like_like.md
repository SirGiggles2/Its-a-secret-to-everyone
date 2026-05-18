# $17 LikeLike

- **NES source**: reference/aldonunez/Z_04.asm:6818 UpdateLikeLike
- **Drained C**:  src/game/enemies/enemy_special_bridge.c:201 enrt_update_like_like
- **Coverage**:   FULL
- **Stance**:     EXTEND

Behavior: 2-mode driven by ObjCaptureTimer ($042C alias). Free-roam:
common_wanderer($80) + 4-frame anim cycle + capture-detect on
collision. Captured: anim up to frame 3, capture timer increments, at
$60 eats magic shield (gated by OPTIONS_LIKELIKE_VANILLA), at $C0
locks. Drain matches Phase 9 Task 9.4 LIKE_LIKE_BEHAVIOR consumer
(redux NO_EAT skips shield write).
