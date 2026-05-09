Warning: True color (24-bit) support not detected. Using a terminal with true color enabled will result in a better visual experience.
Ripgrep is not available. Falling back to GrepTool.
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 3s.. Retrying after 5819ms...
(node:24900) [DEP0190] DeprecationWarning: Passing args to a child process with shell option true can lead to security vulnerabilities, as the arguments are not escaped, only concatenated.
(Use `node --trace-deprecation ...` to show where the warning was created)
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 5s.. Retrying after 6006ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 4s.. Retrying after 5491ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 4s.. Retrying after 5728ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 5s.. Retrying after 6408ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 6s.. Retrying after 6217ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 7s.. Retrying after 8477ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 5s.. Retrying after 6275ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 5s.. Retrying after 6466ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 6s.. Retrying after 7312ms...
## Phase 7 Task 7.1 Framework: Verdict

### Q1 — enemy_state.h alias collision resolution
**Verdict: (c) Flat byte-slot array + per-enemy-type accessor macros.**
NES `ObjVars.inc` reveals that scratch RAM slots (e.g., `0x0412`, `0x41F`, `0x478`) are not just aliased per "family," but are often reused by generic shared routines (like `UpdateCommonWanderer` using `ObjTurnRate`). A tagged union (a) would be conceptually cleaner but practically brittle, leading to a "dependency hell" of union members. Using flat `uint8_t obj_extra[SLOT_COUNT][EXTRA_SLOT_COUNT]` with macros like `#define ObjWantsToShoot(s) obj_extra[s][0]` preserves the 1:1 mapping to `reference/aldonunez/Z_04.asm` logic, making the port easier to audit and debug.

### Q2 — roomrom_rng.h design
**Verdict: (a) Port NES Z1 Random helper byte-for-byte.**
NES Zelda 1 uses a highly specific 13-byte LFSR (scrambled in `IsrNmi` at `@ScrambleRandom` in `reference/aldonunez/Z_07.asm`). It taps bit 1 of `$18` and `$19`, then RORs the carry through 13 bytes. Since enemy spawn positions, drop table rolls, and movement timers (e.g., `Wizzrobe_AlignWithNearestSquareAndRandomizeTimer`) depend on this exact sequence, any deviation (b or c) will break gameplay parity. The Genesis implementation must replicate this 13-byte state rotation precisely.

### Q3 — enemy_parity_matrix.md scope
**Verdict: (b) Generate skeleton from existing files + NES asm grep.**
Hand-authoring 30+ enemies (a) is high-effort and low-accuracy. We should generate a matrix skeleton by scraping `reference/aldonunez/Z_04.asm` for `Init*` and `Update*` labels. This skeleton should then be "fleshed out" with probe IDs and behavior constants (HP, speed, timers) as each behavior family is implemented. This keeps the matrix relevant and accurate to the actual implementation state.

## Integrated Framework Recommendation

The framework should center on an **"Array of Structs" (AoS)** for core object data (X, Y, Dir, Type) to leverage Genesis cache locality, but use **"Struct of Arrays" (SoA)** or flat buffers for the aliased "extra" state to match NES indexing.

1.  **State Management:** Define `EnemyContext` in `src/game/enemies/enemy_dispatch.h` containing 16 slots. Each slot includes standard members and a `uint8_t scratch[9]` array for aliased data.
2.  **RNG Implementation:** Create `src/core/roomrom_rng.c` implementing the 13-byte `ROR` chain. Export `rng_next_byte()` which returns the primary seed (`$18`).
3.  **Probes:** Define `PROBE_RNG_SEED` at the start of the 13-byte RNG block to allow `verify_roomrom_all.py` to sync RNG state between NES and Genesis for automated parity testing.
4.  **Dispatch:** Maintain the current `enemy_dispatch.c` logic but extend it to pass the `scratch` pointer to family-specific update functions, ensuring they only operate on their designated aliases.

This approach honors the **CLAUDE.md** priority of "long-term outcome" (ease of audit against source) while meeting the "NES accuracy" spec.
