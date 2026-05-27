# Round 2 — drill into Sonnet R1 findings

R1 surfaced 3 likely real bugs + 4 design choices:

## REAL BUGS (need verification + fix)
1. **SPR subpal not uploaded for cave**: cave_palette.c:6-9 only writes BG subpals 2+3. NES bonfire uses SPR subpal 2 ($3F19-$3F1B). cave_init never uploads. Fire colors potentially wrong.

2. **z07_animate_object_walking cadence unverified**: NES uses DIR=$08 → AnimateObjectWalking speed table. Gen shim may use different speed → bonfire frame cycle wrong rate.

3. **State 2 (TalkOrShop) ware visibility transition**: After purchase, NES sets ObjY+19=$F8 (hides). Genesis may not.

## DESIGN CHOICES (confirmed)
4. NES bonfire palette flicker = MYTH. Fixed attr 2. Don't bother implementing flicker.
5. NES cave items STATIC. No bob. Don't add bob.
6. Bonfire 2-tile cycle byte-exact: $5C / $9E ↔ confirmed via heap[8/9].
7. State machine 9 states drained, dispatch matches NES.

## R2 QUESTION

Each advisor: For EACH of the 3 real bugs, give:
(a) How to VERIFY (specific BizHawk probe — what addresses/cells, what frame)
(b) Specific FIX (file:line + code change)
(c) Effort estimate

Also: For Codex's "byte-perfect as data problem" architecture:
- Should `tools/parity/cave_golden/` be CHR hashes OR raw OAM bytes OR both?
- How to ensure NES + Gen deterministic seed (FrameCounter=0 at scene entry)?

400 words max. file:line citations.
