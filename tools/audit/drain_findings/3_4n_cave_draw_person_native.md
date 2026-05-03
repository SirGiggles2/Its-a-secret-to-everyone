# Drain Finding — Phase 3 Task 3.4 (native port) — `cave_draw_person`

**Per Rule D1 Gate 1.** Native rewrite vs drained C vs NES disassembly.
Companion to finding `3_4_cavert_draw_cave_person.md` (drain MATCH proof).

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/cave/cave_dispatch.c` | `cave_draw_person` body |
| Drained C | `src/oracle/cave/cave_runtime.c` | 191-197 |
| NES asm | `reference/aldonunez/Z_01.asm` | 370-383 (DrawCavePerson) |
| NES vars | `reference/aldonunez/Variables.inc` | `ObjType := $034F` (so `ObjType+1 = $0350`) |
| State accessor | `src/state/cave_state.h` | `cave_room_type_get()` reads `RAM(0x0350)` ✓ |

## Per-op diff

| NES (Z_01.asm 370-383) | Drain (cave_runtime.c 191-197) | Native (cave_dispatch.c) | Verdict |
|------------------------|--------------------------------|--------------------------|---------|
| `JSR Anim_FetchObjPosForSpriteDescriptor` | `z07_anim_fetch_obj_pos(slot)` | **STAGE-1 STUB** — Phase 4 native sprite-descriptor pipeline | DEFERRED |
| `LDY ObjType+1` (NES $0350) | `unsigned char room_type = CAVE_ROOM_TYPE` (RAM($0350)) | `unsigned char cave_id = cave_room_type_get()` (RAM($0350) via accessor) | **MATCH** |
| `CPY #$7B / BCS NotMirrored` (≥0x7B → NotMirrored) | `if ((unsigned char)CAVE_ROOM_TYPE < 0x7B)` (<0x7B → Mirrored) | `if (cave_id < 0x7Bu)` (<0x7B → Mirrored) | **MATCH** |
| `JMP DrawObjectMirrored` | `c_draw_object_mirrored(slot)` | **STAGE-1 STUB** — Phase 4 `cave_object_draw_mirrored` | DEFERRED |
| `JMP DrawObjectNotMirrored` | `c_draw_object_not_mirrored(slot)` | **STAGE-1 STUB** — Phase 4 `cave_object_draw_not_mirrored` | DEFERRED |

## Verdict summary

**STAGE-1 SHAPE MATCH.** Branch dispatch + cave_id read are byte-for-byte
semantic equivalents of NES + drain. Sprite descriptor fetch and OAM
emission are intentionally stubbed pending the Phase 4 cross-subsystem
native object_draw port (which replaces `c_draw_object_*` and
`z07_anim_fetch_obj_pos` transpile shims with `render_sat_write`-based
SGDK SAT writes).

## Cutover gate

- Title.md callsite `z01_draw_cave_person` (src/gen/z_01.c, hand-written
  outside auto-region) gates on `NATIVE_CAVE_DRAW`.
- Default OFF → oracle drain `cavert_draw_cave_person` (verified MATCH).
- Defined ON → native `cave_draw_person` (stage-1 stub: cave NPC sprite
  invisibly absent until Phase 4 lands the object_draw port).
- RoomRom links `cave_draw_person` but does not yet call it (cave_tick
  is a stub pending state-machine port). Linker exercise only at this
  stage.

## Stance update

Phase 3 Task 3.4 (Stance: EXTEND) — surface ported, body deferred. Phase 4
sub-task: native `cave_object_draw_{mirrored,not_mirrored}` using
`render_sat_write`. Once that ports, stage-2 commit fills the stub bodies
and re-files this finding as **FULL MATCH (native)** with byte-for-byte
SAT-output parity proof.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Companion to `3_4_cavert_draw_cave_person.md` (drain MATCH proof).
- Variables.inc cited per process improvement from finding 3_2 (avoids
  offset miscount near-miss).
