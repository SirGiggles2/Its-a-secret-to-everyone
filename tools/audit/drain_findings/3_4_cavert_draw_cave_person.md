# Drain Finding — Phase 3 Task 3.4 — `cavert_draw_cave_person`

**Per Rule D1 Gate 1.** Drained C vs NES disassembly. Lesson learned from finding 3_2: cite NES symbol addresses from `Variables.inc` for every comparison.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Drained C | `src/game/cave/cave_runtime.c` | 191-197 |
| NES asm | `reference/aldonunez/Z_01.asm` | 370-383 (DrawCavePerson) |
| NES vars | `reference/aldonunez/Variables.inc` | `ObjType := $034F` (so ObjType+1 = $0350) |
| State map | `src/state/cave_state.h` | `CAVE_ROOM_TYPE = RAM(0x0350)` ↔ NES ObjType+1 ✓ |

## Block-by-block diff

| NES (lines 370-383) | C (lines 191-197) | Verdict |
|---------------------|-------------------|---------|
| `JSR Anim_FetchObjPosForSpriteDescriptor` | `z07_anim_fetch_obj_pos(slot)` | **MATCH** (transpiler-named shim) |
| `LDY ObjType+1 / CPY #$7B / BCS :+` (BCS = unsigned ≥; branch when ObjType+1 ≥ 0x7B) | `if ((unsigned char)CAVE_ROOM_TYPE < 0x7B)` (CAVE_ROOM_TYPE = RAM(0x0350) = NES ObjType+1) | **MATCH** (NES branches to NotMirrored when ≥ 0x7B; C branches to Mirrored when < 0x7B — equivalent) |
| `JMP DrawObjectMirrored` | `c_draw_object_mirrored(slot)` | **MATCH** |
| `JMP DrawObjectNotMirrored` | `c_draw_object_not_mirrored(slot)` | **MATCH** |

## Verdict summary

**FULL MATCH.** Drained `cavert_draw_cave_person` is byte-for-byte semantic equivalent of NES `DrawCavePerson`.

## Stance update

Phase 3 Task 3.4 master plan header `Stance: EXTEND`. cavert_draw_cave_person can be ADOPTED as-is (no logic change); EXTEND scope is for the downstream `c_draw_object_mirrored` / `c_draw_object_not_mirrored` shims (which still call `_ppu_*` for VRAM writes) — those need Genesis VDP-native swap.

Sub-task: Gate 1 finding for `c_draw_object_mirrored` would expose where the `_ppu_*` shim swap actually needs to land. That belongs in a separate `world_runtime` Gate 1 finding (cross-subsystem; per Phase 4 entry-point header).

## Provenance

- 2026-05-02. Author: Claude Opus.
- Process improvement adopted from finding 3_2: every NES symbol address cited from Variables.inc explicitly.
