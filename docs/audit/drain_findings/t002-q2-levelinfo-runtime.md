# T-002 — Quest 2 LevelInfo runtime verification

**Result: PASS for the Q2 LevelInfo install and L1 pause-map consumer.** P9 connected Quest 2 progression remains separate.

## Scenario and ownership

The native File Select loaded a Quest 2 save card on both NES and Genesis. `tools/lockstep/presets/t002_q2_l1.json` then drove the same normal overworld route from the starting room through the Level 1 entrance. The card pre-owned L1 map and compass so the Q2 pause map could be inspected; no room, level, or progression state was injected after the load. This is a route into L1 with a staged inventory fixture, not proof of natural map acquisition.

`src/game/world/level_info_install.c:level_info_install_uw` owns the 256-byte install and `level_info_apply_q2_patch` owns the Quest 2 replacement. `src/game/inventory/inventory_render.c` consumes the installed map metadata and ownership. The NES reference is the user's ROM in BizHawk 2.11 NesHawk; Genesis is `builds/Debug.md` SHA-256 `276a015a9b6f709bd0b6bb2ab616ae4aa512388ac236a5ce4f4f5a2a8b9faf6a` in Genplus-gx. Both captures are in `builds/reports/lockstep/t002_q2_l1/`, with focused snapshots at game ticks 2070 and 2190 and final pause screenshots.

## Comparison

- Both crossed OW room `$37` and entered Q2 L1 start room `$77` at game tick 2051. Q1's accepted route starts in `$73`, so the Q2 start is discriminating. The preceding load frame has a one-tick scene-identity difference, accepted under the user's Genesis timing allowance; settled state agrees.
- Final live NES work RAM `$6B7E–$6C7D` and Genesis NES mirror match **256/256 bytes**, including patched start room `$6BAD=$77`, map rotation/offset, Triforce room, cellar and map mask fields. Offline ROM-pointer extraction check also passes **18/18** Q1/Q2 LevelInfo records (`python tools/audit/test_q2_levelinfo.py`).
- With map/compass owned, the settled pause map has the same Q2 blue room shape at x40–54. Its blue-pixel mask matches after the already documented one-pixel HUD vertical offset except two 3×3 animated marker blocks (18 pixels); their NES colors are cyan/green at this capture phase while Genesis has the underlying blue. The map shape itself has no mismatched pixels. `nes.png`, `gen.png`, and the tick-2190 snapshots retain the visual evidence.
- Lockstep KEY result: **2313/2313** ticks, zero failures. Diagnostic full-RAM GATE remains FAIL because this preset has no ratchet baseline and includes previously documented boot/scratch differences; it is not used as a whole-game acceptance claim.

**Stance:** KEEP the ROM-derived patch in the active dungeon install. This closes T-002's runtime review. It does not close P7.1a's wider pause presentation, map acquisition, or P9 connected Q2 route.
