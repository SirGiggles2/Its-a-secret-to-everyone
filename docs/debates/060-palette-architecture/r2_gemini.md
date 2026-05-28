Warning: True color (24-bit) support not detected. Using a terminal with true color enabled will result in a better visual experience.
YOLO mode is enabled. All tool calls will be automatically approved.
YOLO mode is enabled. All tool calls will be automatically approved.
Ripgrep is not available. Falling back to GrepTool.
### 1. The Winning Proposal
**SONNET/CODEX** is the superior architecture. **GEMINI (R1)** is rejected because Quadrant-Packing is a "brute-force" emulation hack that wastes 4x VRAM and renders the Genesis SAT `palette` field useless. **CLAUDE** is correct on routing but misses the state-sync bug.

**Concretely wrong with Gemini R1:**
*   **VRAM Bloat:** 4x CHR expansion for sprites is unsustainable if we want to leverage Genesis's larger tile pool for higher-detail backgrounds or FX.
*   **Hardware Neglect:** The Genesis SAT has a 2-bit palette selector. Gemini R1 ignores this, using tile indices to select sub-palettes, which prevents easy HBlank palette swaps for bosses or screen-tinting.

### 2. Resolving the Crux
The "Blue Bonfire" is a **CRAM Shadow Clashing** bug. 

**The Evidence Explained:**
*   **SAT pal=2:** The routing logic *is* correctly mapping NES SPR-Subpal 2 to Genesis PAL2.
*   **Manual Fix Failed:** Why did loading orange into PAL2/3 fail? Because the Genesis is a high-speed DMA machine. The engine is running a `vblank_palette_handler` that re-uploads a "Global/Overworld" palette buffer from RAM to CRAM every single frame. 
*   **The Root Cause:** `cave_palette.asm` only patches the *hardware* CRAM or a local buffer, but the `main_loop`'s VBlank sync is still pointing to the `overworld_palette_buffer`. In the Overworld, PAL2 is used for Blue Darknuts/Blue Knights. The bonfire is sampling PAL2 (correct), but PAL2 contains "Darknut Blue" because the engine clobbered the "Cave Orange" before the frame rendered.

**The One Concrete Fix:**
Unify all palette writes into a **Single Atomic Shadow-CRAM Buffer** (64 bytes). The `cave_palette` must update this *buffer*, not the hardware. Delete all partial-CRAM upload functions.

### 3. The First Migration Step
**Implement the "Palette Manifest" Sync.**
Create a 32-word RAM buffer `palette_shadow_main`. Replace the scattered `copy_to_cram` calls with a single `dma_queue_palette` function in the VBlank handler that sends this entire 64-byte block to CRAM. 

This ensures that any "routing" (like packing the 4 BG sub-pals into PAL0) happens in RAM, and the hardware always sees a consistent, non-clobbered state.
