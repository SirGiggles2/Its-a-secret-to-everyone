# T-171: Wallmaster capture and return

NES authority: `reference/aldonunez/Z_04.asm`, `UpdateWallmaster` at
`@DrawWithCapturedLink` and the end-of-trip branch. The source copies the
Wallmaster's position into Link, runs `Link_EndMoveAndAnimate_Bank4`, draws
the closed hand in OAM slots 16/17 ahead of Link's 18/19, then enters mode 3
after seven crossed tiles to return Link to the dungeon entrance.

The existing Genesis capture helper was a stub. On the focused Q1 Level 1
route, Wallmaster grabbed Link at tick 7851, but Genesis left his typed
position at the old spot: the first KEY divergence was ObjY at tick 7852.
The helper now updates the native Link owner and NES mirror, runs the drained
animation, and draws Link at the hand. The native SAT sweep temporarily
links the captured hand before Link to reproduce NES sprite coverage. It
restores the ordinary mask-to-Link link on the next sweep, including after
the Wallmaster exits into mode 3; without that restoration, Link was absent
from the returned room even though his RAM matched.

Reproduction and regression: `tools/lockstep/presets/t171_wallmaster_grab.json`
uses normal route inputs to reach room `$45`, waits for the grab, and follows
the mode-3 return through resumed play in entrance room `$73`. No position,
inventory, or room state is injected between route segments. Paired BizHawk
NES/Genesis capture: gate PASS, KEY 8156/8156, zero KEY mismatches, including
the capture, return and resumed play through tick 8155. Its full-RAM ratchet
has exactly the same 70 cells and onset ticks as the existing `t013_route`
baseline; no new divergence appears. Screen captures at carried tick
7900 and resumed-play ticks 8000 and 8050 match pixel-for-pixel. The two
other sampled carry frames retain small differences from separate moving
Wallmasters; this result does not claim all Wallmaster presentation is done.

Windows `Debug.bat` PASS, ROM SHA-256
`7D42C61FCE0F3E124A7996FD9302EB65B5A12CE366CE51A44069E216B5735900`.
The existing `t013_route` consumer also passes: KEY 9065/9065, full-RAM
ratchet unchanged (70/70 cells).
The current playable ROM is `builds/Debug.md`.
This focused route establishes the capture and return, not every Wallmaster
approach or every dungeon enemy interaction.
