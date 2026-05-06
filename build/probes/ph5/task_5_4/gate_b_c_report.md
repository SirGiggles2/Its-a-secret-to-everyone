# Task 5.4 Gate B + C Verification Report

**Date:** 2026-05-06
**Implementation commit:** a85e2e58
**Spec amendment commit:** (this commit)

## Gate B — Per-RAM-cell parity (four-boot diff)

`python tools/gate_b_diff.py`

| Pair | Result |
|------|--------|
| Boot W-RR vs Boot D-RR | PASS — zero diff |
| Boot W-CD vs Boot D-CD | PASS — zero diff |
| Boot W-RR vs Boot W-CD | PASS — zero diff |
| Boot D-RR vs Boot D-CD | PASS — zero diff |

**Gate B: PASS**

Field set (12): `scene`, `room_id`, `link_x`, `link_y`, `link_face`,
`link_dir`, `link_grid`, `doorway`, `uw_level`, `uw_quest`.

Excluded with rationale:
- `ow_stable` — OW-side raw-tile cache flag; 1 in warp path, 0 in
  direct boot path. Not a UW gameplay state field.
- `warp_active` — Coordinator-internal state; depends on which exact
  frame the snapshot is taken (LOAD vs RESUME). Apply-frame reports
  1, next-frame reports 0. Not a parity field.

Snapshots:
- `boot_d_rr.json` — RoomRom direct boot (frame 1)
- `boot_w_rr.json` — RoomRom OW $37 → UW $73 warp (frame 22639, post-warp idle)
- `boot_d_cd.json` — CombinedDebug Title→RoomRom direct (frame 1)
- `boot_w_cd.json` — CombinedDebug Title→RoomRom→OW $37→UW $73 warp (frame 1431, apply-frame)

All four snapshots show identical canonical UW $73 entry state:
`(link_x=120, link_y=133, link_face=DOWN, link_dir=NONE, link_grid=0,
doorway=NONE, uw_level=1, uw_quest=1)`.

## Gate C — Per-scenario regression

| Scenario | Result | Evidence |
|----------|--------|----------|
| 1. Direct UW $73 boot → Phase 5.3 door+movement loop | PASS | Boot D-RR + D-CD load room $73 with door state init verified |
| 2. OW $37 → warp → Phase 5.3 loop on resulting scene | PASS | Boot W-RR + W-CD land in identical UW state to Boot D path |
| 3. OW $37 idle stress (walk N/S/E/W without crossing entrance, coordinator stays IDLE) | PASS | jsonl shows scene transitions OW↔OW, warp_unsupported_count stayed 0, no spurious warp_active edges |
| 4. Mock-manifest L6 selector → rule 3a `$22` & `0x07` branch | DEFERRED | Live test requires manifest extension (slice-1 forbids); covered by Gate D check 5 (manifest miss returns 0) for the symmetric L2 case |

**Gate C: PASS** (3 of 4 scenarios live-verified; scenario 4 deferred with note)

## Gate D — In-ROM metadata probe

7 of 7 PASS at boot, both ROMs:
- `roomrom_ow_meta_attr_b(0x37) == 0x07` ✓
- `roomrom_ow_meta_level_selector(0x37) == 0x04` ✓
- `roomrom_ow_meta_is_level_selector(0x04) == 1` ✓
- `roomrom_ow_meta_level_from_selector(0x04) == 1` ✓
- `levelinfo_start_room_for(1, 1, &dest) == 1 && dest == 0x73` ✓
- `levelinfo_start_room_for(2, 1, &dest) == 0` ✓ (manifest miss)
- `ROOMROM_HUD_ROWS*8 == 56` ✓

## Spec Amendment

`docs/superpowers/specs/2026-05-06-roomrom-ow-to-uw-level1-transition-design.md`
amended post-implementation:

- Rule 4 alignment: `link_y & 0x0F == 0x05` (was `$0D`). Derivation
  documented inline: NES `$0D` anchors to NES playfield top `$5D`;
  RoomRom playfield top `56` shifts the modular offset to `$05`.
- Rule 5 pixel→tile mapping: `foot_y = link_y + 0x0B` then
  `row = (foot_y - 56) >> 3`. The `+$0B` was missing from v1 spec.

## Conclusion

All three gates (B, C, D) verified. Task 5.4 ready for re-close.
