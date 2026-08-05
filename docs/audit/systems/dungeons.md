# System audit — dungeons

> Status is derived from the signed evidence blocks below, never from
> this file's existence. No blocks = all five cells RED. See
> `docs/superpowers/specs/2026-08-03-completion-tracker-design.md`.

**Audited:** 2026-08-04. Second system, per spec §6 ordering.

## Scope

Owns the underworld: room decode and render, doors and locks, cellars,
dark rooms, item rooms, push blocks, the pause dungeon map, and the
walk model inside a dungeon.

Owns:

- `src/game/dungeon/uw_render.c` — room BG decode + render
- `src/game/dungeon/door_state.c` — door/lock/shutter state
- `src/game/dungeon/walk_model.c` — in-dungeon movement
- `src/game/dungeon/uw_map_{builder,data}.c` — pause map
- `src/game/dungeon/{cellar,dark,item_room,push_block}_meta.c`
- `data/rooms/dungeons.c` — LevelBlockAttrs + LevelInfo + layouts

Does NOT own:

- Enemy and boss behaviour inside dungeons (`enemies`, `bosses`).
- The UW→OW warp coordinator (`world`).
- Second-quest variants (`quest2`).

## Axis verdicts

```yaml evidence
- system: dungeons
  axis: DATA
  verdict: GREEN
  artifact: docs/audit/uw_bg_status.md
  artifact_sha256: 5d349fca3cb24677eebeb49f1bb61acd390795e2ad1b3bbd06a4655b1929ef1d
  command: python tools/parity/uw_bg_gate.py --emit-evidence dungeons
  verdict_line: 'uw_bg_gate: 170/170 dungeon rooms BG byte-exact (CRAM via LUT + play-cell
    presence; rendered-RGB and sprites NOT gated)'
  manifest_emitted_by: tools/parity/uw_bg_gate.py
  run_signature: 845cb1a90ac706c5cedc5222b98ad3d6eceacff8790174a3cbe1cc270aa77c25
  inputs:
  - path: tools/parity/uw_bg_gate.py
    sha256: ba8ef03aede4e4ddf30671ba361970507296ab60b442c17b7daa4abd60cc4f04
  - path: tools/parity/cave_golden/cave_byte_diff.py
    sha256: cce1ca6d4d7e0d13c8a6f365042647658fcabade109a3f793a27c342b0479379
  - path: data/rooms/dungeons.c
    sha256: 15bd02152d32d15032472a31d063e19a78090534cf4e94a8be59c14d108b1ee7
  - path: data/misc/palettes.c
    sha256: 50c5bba7cc33562b51862acb05a68b0b9f38d577c26270cad6325a8795b4e24d
  - path: src/game/dungeon/uw_render.c
    sha256: b889934c320e86290c3c73718cf61e6c4a87a9ab3070409b5bc33215fdfa0666
```

```yaml evidence
- system: dungeons
  axis: LEGAL
  verdict: GREEN
  artifact: docs/audit/package_check_status.md
  artifact_sha256: 72b23053d5a9ac8255ff4b1eb3cee5a0ace718c2e50aa1e923b8b459dac0bd08
  command: python tools/builder/package_check.py --emit-evidence dungeons
  verdict_line: 'package_check: 107 banned file(s) excluded, 12597 would ship'
  manifest_emitted_by: tools/builder/package_check.py
  run_signature: 168d270f17fd2f9d24d8384b6e2a877389243b0f131bb519233384c5af692170
  inputs:
  - path: tools/builder/package_check.py
    sha256: c3d3e8fc1669dd15d60f19cd25530de9d1ad1b677d07358d1a0c031d9fb87498
```

BEHAVIOR, PLAYABLE and CODE have no evidence block. All three are RED —
see the gap list.

## Gap list

### DATA — GREEN, but read the verdict line literally

170/170 cached rooms pass, and the gate is **BG CRAM byte-exact via the
misc_palettes LUT + every NES BG play cell has a Genesis tile**. It does
not gate rendered RGB, sprite palettes, or OAM→SAT; the differ reports
those as info. "Dungeon BG byte-exact" is not "dungeons are correct".

This also confirms the 2026-08-04 palette cutover (99bf3173) did not
regress dungeon BG parity — the 42 changed colour words leave all 170
rooms passing.

### CODE — RED

1. `src/game/dungeon/item_room_meta.c:7` — documented STUB: the Triforce
   wrapper bypasses the `GAME_MODE=18` transition. Triforce collection is
   a live path on the critical route through every dungeon.
2. `src/game/dungeon/uw_render.c:583` `draw_placeholder()` — rooms absent
   from the render blob draw a placeholder, and every placeholder cell is
   forced walkable so Link cannot be trapped. That is a reasonable
   failsafe, but it means a missing room is invisible at runtime instead
   of loud. The audit needs to know which rooms actually hit it.
3. `uw_map_data.c` documents itself as *"NOT derived from
   data/rooms/dungeons.c (whose regen diverges from live NES)"*, and
   `RoomRom/data/levelinfo_start_rooms.c` exists for the same reason.
   Both were workarounds for the LevelInfo off-by-four fixed in
   `b5582ffb`/`542a5ea1`. They are now candidates for retirement, which
   would remove two hand-maintained tables that can drift from the ROM.

### BEHAVIOR — RED

No live NES-vs-Genesis behavioural diff exists for dungeons. Doors,
locks, shutters, cellars, dark rooms and the walk model have no
tolerance document and no state-diff capture. The DATA gate covers
static room appearance only.

### PLAYABLE — RED

`tools/dungeon_harness/manifest.json` is still a skeleton: 18 rows, **0**
with `save_state_sha256`, **0** with `rng_seed`, and
`tools/dungeon_harness/save_states/` contains **0** `.State` files. No
dungeon has been demonstrated to complete end-to-end.

This is the gate the 2026-05-24 release debate ranked #2, and it remains
the single largest piece of unproven ground in the project.

## Tolerance

None recorded. The DATA gate is zero-tolerance (0 divergences across all
170 rooms). BEHAVIOR has no tolerance document because it has no
evidence; writing one is part of closing that axis.
