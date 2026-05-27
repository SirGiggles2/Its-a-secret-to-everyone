# Round 2 prompt — drill down on core disagreement

You participated in Round 1. Read your r001 file. Read the other 3 too. Now answer Round 2.

## Core disagreement
- Sonnet (🟠): D1-D4 already landed. Current code mostly works. Just fix CAVE_ID_MAX + grid_offset + verifier. 13-25h total.
- Codex (🔴): Replace generic renderer with typed per-cave dispatch + `static CaveLayout cave_layouts[]` extracted from NES. 5-8 days.
- Gemini (🟡): manifest_interiors.json + oracle-driven validation.
- Opus (🐙): H1-H4 phases.

## Round 2 question
EACH cave $6A..$7D and EACH dungeon entrance has unique sprites/layout/text per NES.
The current Genesis code renders ALL caves with same template (bonfire + person at fixed coords).

**Specifically: is `cave_draw_person` at cave_dispatch.c:685 ALREADY per-cave-specific, or does it just render ObjType[1] as a generic person sprite?**

If per-cave-specific exists → just byte-diff vs NES, fix divergences as they appear (Sonnet's path).
If generic-only → need typed renderers + extracted CaveLayout table (Codex's path).

ALSO answer:
- What's the NES authoritative table for per-cave NPC sprites? cite reference/aldonunez/Z_01.asm or Z_07.asm line.
- Where does the per-cave VRAM tile patten / nametable live on NES? Cave heap or fixed?
- Does Phase D's existing port handle per-cave nametable already, or only sprite slot init?

300 words max. Be concrete with file:line citations from previous reads.
