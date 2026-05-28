Warning: True color (24-bit) support not detected. Using a terminal with true color enabled will result in a better visual experience.
YOLO mode is enabled. All tool calls will be automatically approved.
YOLO mode is enabled. All tool calls will be automatically approved.
Ripgrep is not available. Falling back to GrepTool.
Recommendation: **Quadrant-Packed Static Mapping**.

Unify the system by treating Genesis PAL1 and PAL2 as containers for the 8 logical NES sub-palettes. Do not route via SAT palette bits; instead, use the **4x CHR Expansion** (VRAM replication) to select colors via tile indices.

### (a) The Mapping
*   **PAL0 (HUD/Global):** Reserved for the top HUD and global UI colors.
*   **PAL1 (Backgrounds):** Map all 4 NES BG sub-palettes here. 
    *   Indices [1–3], [5–7], [9–11], [13–15] hold NES BG sub-pals 0, 1, 2, and 3 respectively.
    *   Indices [0, 4, 8, 12] must all mirror the NES global backdrop (Color 0).
*   **PAL2 (Sprites):** Map all 4 NES Sprite sub-palettes here using the same quadrant layout.
*   **PAL3 (Enhanced):** Reserved for Genesis-exclusive effects (e.g., high-color bosses or Shadow/Highlight).

### (b) Migration Path
1.  **Standardize CHR Expansion:** Force the asset pipeline to generate 4 versions of every tile. Version $N$ is bit-shifted so its 2-bit NES color indices land in Quadrant $N$ of a 4bpp Genesis palette.
2.  **Static CRAM Targets:** Refactor `cave_palette.c` and `bg_palette.c` to write strictly to PAL1. Link the OAM->SAT converter to point all sprites to PAL2.
3.  **Purge Logic:** Delete `subpal_routing.h`. The "routing" is now baked into the tile index used in the SAT/Plane map, not a register state.

### (c) The Single Biggest Risk
**VRAM Pressure.** 4x CHR replication quadruples VRAM usage for tiles. While Zelda 1 is small, this limits your budget for adding "Genesis-exclusive" high-detail background art or large multi-frame animations later without clever bank-switching.

### (d) Genesis Strength: Dual Playfield Priority
By isolating the NES world to **Plane B** (PAL1) and Sprites (PAL2), you leave **Plane A** completely empty. You can use Plane A for a high-priority "Atmospheric Layer"—adding foreground canopy, weather effects, or torch-light overlays using **Shadow/Highlight mode**. This allows the game to look like a modern 16-bit title while the core rendering remains byte-identical to the NES logic on the layer below.
