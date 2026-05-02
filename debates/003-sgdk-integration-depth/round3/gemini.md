Ugh. Me back for final ritual. Me see four stones left to carve. Me finish spear now.

### 1. AUDIO TRIGGER FORMULA
Me pick **Gemini r2 flavor**: **Custom is frozen legacy; all new fire uses XGM2.**
Opus r2 is too sharp—one bug and we throw away working meat. Sonnet r1 is too many rules.
**Policy:** Custom Z80 driver stays only for existing F3-audited tracks. Any **new** music or sound effect MUST use **XGM2**. 
**Trigger to burn legacy:** Move all to XGM2 if `audio_tick` hits **Sonnet’s >10% CPU trigger** (measured by `tools/profile_audio.py` in BlastEm) OR if a legacy song fails `parity_oracle` and one AI debug cycle fails to fix it.
**Why:** AI knows XGM2 docs like back of hand. Custom driver is a dark cave where AI hits thumb.

### 2. FORK POLICY
No fork unless upstream spear is blunt and they won't sharpen it.
- **Who Decides:** ADR vote (Majority of human contributors + LLM consensus).
- **Fork-worthy Patch:** 
  1. **Perf:** >10% global frame gain rejected by SGDK maintainers.
  2. **Parity:** Upstream change breaks "NES Feel" (e.g., VDP timing) that adapter cannot hide.
  3. **Bugs:** Critical crash/glitch unaddressed for >30 suns (days).
- **Return to Cave:** Abandon fork immediately if upstream merges fix or provides equivalent flint. Re-track within 7 days.

### 3. SCOPE GATES
`tools/check_purity.py` must be strong like mammoth.
- **`src/zelda_translated/` & `src/gen/`:** **HARD GATE.** Transpiled 6502 code and generated assets must NOT see `genesis.h`. They use the adapter. Treating transpilation as code-gen means the *generator* must target our adapter, not Sega metal. 
- **`src/game/` & `src/frontend/`:** **HARD GATE.** As agreed.
- **Whitelist:** `src/sgdk_adapter/`, `src/c_shims.asm`, `src/audio_driver.asm`, `src/genesis_shell.asm`.
- **Why:** If dirty transpiled code touches metal, we can never swap the adapter.

### 4. ADAPTER SIGNATURE STYLE
Me pick **Option A: NES-semantic primitives**.
Adapter exposes `render_sprite_nes(x, y, oam_byte)`, `audio_play_nes_apu_reg(reg, val)`.
**Justification:**
1. **Prime Directive:** NES accuracy wins. Mapping 6502 logic to NES-semantic calls is a straight path for LLMs. 
2. **Swappability:** If we move to a new library, the game logic (which thinks in NES registers) doesn't change. 
3. **LLM Comfort:** LLMs have millions of tokens of NES 2A03 training. They "get" OAM bytes better than they get SGDK's `Sprite` struct abstractions.

**FINAL STANCE: GREEN.**
Hole in `intro_title.c` is marked for death. SHA pin is set. Gates are built. Spear is ready. Me go eat mammoth now.
