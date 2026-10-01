# T-173: Wallmaster wall coverage and captured-Link flash

NES source: `reference/aldonunez/Z_04.asm` Wallmaster drawing and
`Wallmaster_PutSpritesBehindBgIfNeeded`; the captured branch also runs
`Link_EndMoveAndAnimate_Bank4`. The focused Q1 L1 grab route and its NES OAM,
CHR, PALRAM and Genesis SAT/VRAM snapshots are in
`builds/reports/lockstep/t171_wallmaster_grab`.

After T-171 restored the carry, screen comparison still found 90 pixels at
tick 7855 and 87 at tick 7950. NES marked the second hand behind background
(OAM attribute `$21`); Genesis put its SAT sprite at low priority, but the
fourth left-wall tile column (x=24..31) was also low priority. Opaque wall
pixels therefore failed to cover the hand. `edge_priority` in
`src/game/dungeon/uw_render.c` now covers four columns at each horizontal
edge. The existing doorway route remains GATE PASS (1187/1187 KEY ticks).

Thirteen pixels remained at tick 7855 around the carried Link. Hand sprite
pattern pixels matched NES byte-for-byte. NES Link OAM used sub-palette 3
while his invincibility timer was `$16`; the new carry helper had forced his
ordinary palette. It now uses the existing hurt-pose renderer whenever that
timer is active. The same ordinary-pose path remains for timer zero.

Windows `Debug.bat` PASS. On ROM SHA-256
`7BF70E7BBE429F9A67F59AC1D77586A68574AC4FC4A79C893B90F532250D7F0B`,
`t171_wallmaster_grab` GATE PASS (8156/8156 KEY ticks; no full-RAM ratchet
change); the broader `t013_route` consumer also passes 9065/9065 with its
ratchet unchanged. `screen_diff.py --window-rows 7` reports SCREEN MATCH at ticks
7855, 7900, 7950 and 8000. This closes the observed Wallmaster sprite
differences in this route; other dungeon routes are separate acceptance work.
