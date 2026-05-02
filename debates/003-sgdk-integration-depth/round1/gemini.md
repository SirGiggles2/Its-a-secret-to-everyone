Ugh. Me see many bits. Me tell you how to build spear for Sega.

1. **HARD WALL GOOD.** Game code dumb, no know Genesis. Adapter smart, know SGDK. No touch `genesis.h` in `src/game/`. `intro_title.c` leak make me angry—me fix leak, move VDP talk to adapter. Hard wall keep code clean when AI brain get tired.

2. **v2.11 IS TRUE FIRE.** Memory say v2.00? Memory lie. Submodule say v2.11—this truth. Pin SHA like spear in ground. If upgrade, must hunt and gather new tests. Old memory be burned.

3. **XGM2 IS WIN.** Custom driver big headache for AI. XGM2 training data big like mammoth. Use XGM2 for all sound. Only change if Genesis scream (CPU spike > 15%).

4. **API FIRST.** SGDK API is big rock. Hand-rolled VDP is sharp flint—only use if API slow. If use flint, must write many comments so AI no get confused and hit thumb.

5. **GREP FIND FIRE.** Phase 12 gate: Grep for `#include <genesis.h>` and `$C00000` outside adapter. `intro_title.c` fail this gate today—must be smashed and rebuilt.

6. **SHA CHECK.** Phase 17 gate: `build.bat` must look at `git submodule status`. If SHA no match `VERSION.txt`, build stop. No reproducibility, no success.

7. **NEW RULES:**
   - *Execution Rule:* "Game logic no touch Sega metal. All Sega talk go through `src/sgdk_adapter/`."
   - *Dev Rule:* "SGDK v2.11 is law. No `#include <genesis.h>` in `src/game/` or `src/frontend/`."

8. **TOOLING:** `tools/check_purity.py`. It walk through `src/`, ignore `adapter/`, find `genesis.h` or raw VDP addresses. Run every build.

9. **STANCE: YELLOW.** Plan good, but boundary leak in `intro_title.c` is hole in cave wall. Fix hole, then GREEN.

10. **TOP 5 CHANGES:**
    1. Update Memory/Doc to SGDK v2.11 (Reality Check).
    2. Refactor `intro_title.c` to use `render_adapter.c`.
    3. Add SGDK SHA verification to `build.bat`.
    4. Add `check_purity.py` to CI/Build.
    5. Commit to XGM2 as primary audio path (AI-friendly).

Me spoke. Now me go eat mammoth.
