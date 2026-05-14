# Phase 9 Task 9.1 — Redux Options Runtime

- **NES source**: NONE — NES Zelda 1 has no options menu. Redux adds
                  this. Per master plan debate 004 (debates/004 Phase 9
                  resolution), the options subsystem is the sole
                  GREENFIELD path in Phase 9 — every other sub-task has
                  drained NES code that grounds it.
- **Drained C**:  NONE — no candidate row in
                  `tools/audit/drain_coverage.json`. This is a
                  sanctioned GREENFIELD subsystem.
- **Coverage**:   N/A (no NES surface).
- **Stance**:     GREENFIELD (sanctioned by debate 004; NOT a Rule D1
                  violation because no drain candidate exists for the
                  options menu).

## Substrate (`src/game/options/`)

`src/game/options/options_state.h` — wire-stable serializable layout
(32 bytes), fits the locked SRAM range `$800-$81F` reserved by Task 9.2:

| Offset | Field | Type / Range | Purpose |
|--------|-------|--------------|---------|
| 0..1   | magic | `'O','P'` (0x4F 0x50) | sanity |
| 2      | version | u8 (`OPTIONS_VERSION_*`) | migration gate |
| 3..4   | bool_bits | be u16 (`OPTION_BOOL_*` bitfields) | toggles |
| 5      | sword_style | u8 (`OPTIONS_SWORD_*`) | radio |
| 6      | like_like   | u8 (`OPTIONS_LIKELIKE_*`) | radio |
| 7      | bomb_upgrade | u8 (`OPTIONS_BOMBUPG_*`) | radio |
| 8      | start_hearts | u8 (3..16) | numeric |
| 9      | lost_woods | u8 (`OPTIONS_LWOODS_*`) | radio |
| 10     | dark_room | u8 (`OPTIONS_DARK_*`) | radio |
| 11..29 | reserved | 18 bytes | future v2+ growth |
| 30..31 | checksum | be u16 (add-all-bytes mod 65536) | integrity |

`bool_bits` bit assignments (set = enabled): `low_health_warning`,
`automap`, `dungeon_colors`, `visible_secrets`, `diagonal_sword`,
`no_reduced_flashing`, `ab_swap`, `auto_collect_drops`; bits 8..15
reserved.

`options_runtime.c/h` — id-keyed `options_get_u8` / `options_set_u8`
with enum/radio validation per id; defaults exposed via
`options_load_defaults`.

`options_persistence.c/h` — checksum compute/verify and version
migration entry point.

`options_consumer.c/h` — bridge for per-gameplay-feature consumers
(Task 9.4 wires individual consumers).

## Probes

`src/game/options/probes/options_probe.c` — defaults + getter/setter
round-trip + range validation contract.
`src/game/options/probes/options_persistence_probe.c` — checksum +
migration contract.
`src/game/options/probes/options_consumer_probe.c` — consumer-hook
contract (per Task 9.4 wiring rule).

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean build; options TUs linked into `Debug.md`.

## Status

CLOSE — Task 9.1 Redux Options Runtime substrate landed. GREENFIELD
stance documented; per Drain Rule D1, GREENFIELD is legal here because
`tools/audit/drain_coverage.json` has no candidate row for the options
menu (NES Zelda 1 has none).
