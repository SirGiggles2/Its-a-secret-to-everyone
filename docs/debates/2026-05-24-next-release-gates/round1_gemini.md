# Round 1: Gemini Opening — The Triple-Lock for v1.0

To ship **FINAL TRY v1.0**, we must stop pretending that "compiles" equals "complete." The following three gates are the smallest path to an honest release.

### 1. Audio Link & Runtime Probes (Phases 10.3/10.5)
*   **Gate:** `phase17_final_release_gate` (Runtime Health)
*   **Blast Radius:** **Total.** A silent Zelda is a tech demo, not a product. Currently, Audio TUs are unlinked in `Debug.md`, making all runtime audio probes (`task_10_5`) a lie. We are flying blind on Z80 stability and PCM pathing.
*   **Effort:** ~8 hours. Link TUs, resolve MIDI-FS dependencies, and enable automated runtime assertions.
*   **Path:** `src/sgdk_adapter/audio_adapter.c`

### 2. Cross-Emulator Matrix (Phase 16)
*   **Gate:** `phase17_final_release_gate` (Hardware Proxy)
*   **Blast Radius:** **High.** BizHawk is a permissive sandbox. Shipping a "v1.0" that crashes on a real Mega Drive because of VDP bandwidth or Z80 bus contention is an avoidable embarrassment. BlastEm is the only acceptable proxy for the deferred `hardware_smoke` gate.
*   **Effort:** ~4 hours. Integrate `blastem` into the automated probe loop to catch timing divergence.
*   **Path:** `tools/builder/release_gate.py`

### 3. Dungeon Harness Population (Phase 14)
*   **Gate:** `phase17_from_scratch_build_gate` (Prerequisite)
*   **Blast Radius:** **Critical.** The manifest currently shows **18 SKIP rows** for dungeons. Shipping v1.0 while skipping verification of the game's core content is a betrayal of the project's parity goal. This is the only path to a "GREEN" build gate.
*   **Effort:** ~12 hours. Execute the BizHawk capture pass to flip SKIP to GREEN across all 9 dungeons.
*   **Path:** `tools/dungeon_harness/manifest.json`

Gemini — Round 1 opening
