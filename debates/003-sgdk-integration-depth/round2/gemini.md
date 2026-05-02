Ugh. Me back. Me look at other cave drawings. Peers have sharp rocks, but me see some soft spots.

1. **AUDIO BATTLE.** Sonnet, Opus, and Codex say keep custom driver for 'NES accuracy.' Me say: Accuracy is meat, but AI training is the fire. AI know SGDK headers and XGM2 like back of hand. Custom Z80 blobs are dark caves where AI get lost and scream. However, Sonnet say audit is green. Me no smash working spear if it still kill mammoth. Me update stance: Custom driver is **FROZEN LEGACY**. No touch, no grow, no 'one more fix.' All **NEW** music and sound must use XGM2. If custom driver break 2 times, or if it hit Sonnet's 10% CPU trigger, we burn it and move all to XGM2. This gives us safety of old spear with power of new fire.

2. **VDP FLINT.** Me said use hand-rolled VDP if 'slow.' Sonnet say '15% win.' Opus say '20%.' Me like Sonnet's 15% rock. It big enough to be worth risk of burning AI brain at 2am. If win is small like squirrel (5%), use SGDK API. If win is big like mammoth (15%), use flint. This keeps code clean for AI while keeping game fast for Sega.

3. **GAPS & GATES.** Sonnet and Opus right—me no say *when* to fix `intro_title.c`. Me say now. We no build gate while mammoth still in cave. Refactor `intro_title.c` is Step 0. Also, Codex want 'audit note' for SHA bump. Me like this. Every time we move SHA spear in the ground, we must write **WHY** in `docs/sgdk_pin.md`. No note, no bump.

4. **PURITY TOOL.** Me call it `check_purity.py`. Codex call it `check_sgdk_boundary.py`. Me think 'purity' sound more like strong tribe. Me keep name but use **BOTH** greps (Include + Raw VDP) like all peers say. Tool must crawl `src/` but ignore `src/sgdk_adapter/`. `intro_title.c` must fail this tool today to prove tool is strong.

5. **TOP 5 REFINED:**
   1. **FIX THE HOLE:** Refactor `intro_title.c` to use `render_adapter.c`. Remove raw `$C00000` writes. Do this first.
   2. **SHA IS LAW:** `build.bat` must run `git submodule status`. If SHA no match `tools/sgdk_pin.txt`, build stop. This is Phase 17 gate.
   3. **PURITY GATE:** Add `tools/check_purity.py` to Phase 12 gate. Grep for `<genesis.h>` AND `$C00000`/`VDP_DATA` literals.
   4. **BURN OLD MEMORY:** Update all docs/memory to SGDK v2.11. v2.00 is ghost of dead mammoth—burn it.
   5. **AUDIO PATH:** XGM2 is the primary spear for all expansion. Custom driver is frozen legacy for existing tracks only.

**STANCE: YELLOW.** Cave wall still has hole in `intro_title.c`. Fix hole, then GREEN.

Me spoke. Me go find more mammoth.
