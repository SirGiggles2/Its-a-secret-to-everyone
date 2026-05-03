# Drain Finding — Phase 4 Task 4.1 (native port) — `world_get_object_middle`

**Per Rule D1 Gate 1.** First Phase 4 (overworld) port. Native rewrite
+ drain MATCH proof in one finding.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/world_dispatch.c` | `world_get_object_middle` |
| Drained C | `src/oracle/world/world_runtime.c` | 19-27 |
| NES asm | `reference/aldonunez/Z_01.asm` | 5498-5520 (GetObjectMiddle) |
| NES vars | `reference/aldonunez/Variables.inc` | `ObjAttr := $04BF`, `ObjX := $0070`, `ObjY := $0084`, ZP `$02..$03` = scratch |
| State accessors | `src/state/world_state.h` | `WORLD_TMP2/3 = ZP_TMP2/3 = RAM($0002/$0003)`, `OBJ_X(slot) = OBJ(NES_OBJ_X, slot)`, `OBJ_Y(slot) = OBJ(NES_OBJ_Y, slot)`, `OBJ_STATUS_FLAGS(slot) = OBJ($04BF, slot)` |

## Drain MATCH proof — block-by-block

| NES (Z_01.asm 5498-5520) | Drain (world_runtime.c 19-27) | Verdict |
|---------------------------|-------------------------------|---------|
| `LDA #$08 / STA $02 / STA $03` | `WORLD_TMP2 = 8; WORLD_TMP3 = 8` | **MATCH** |
| `LDA ObjAttr,X / AND #$40 / BEQ :+ / LSR $02 / :+` | `if (OBJ_STATUS_FLAGS(slot) & 0x40) WORLD_TMP2 >>= 1` | **MATCH** — LSR is shift-right-by-1; ObjAttr+slot = OBJ_STATUS_FLAGS via OBJ() macro = `nes_ram[$04BF + slot]`. |
| `LDA ObjX,X / CLC / ADC $02 / STA $02` | `WORLD_TMP2 = (uint8_t)(OBJ_X(slot) + WORLD_TMP2)` | **MATCH** |
| `LDA ObjY,X / CLC / ADC $03 / STA $03` | `WORLD_TMP3 = (uint8_t)(OBJ_Y(slot) + WORLD_TMP3)` | **MATCH** |

**Verdict: worldrt_get_object_middle FULL MATCH** vs NES.

## Native port

| Block | Drain | Native | Verdict |
|-------|-------|--------|---------|
| init offsets | `WORLD_TMP2/3 = 8` | `WORLD_TMP2 = 8u; WORLD_TMP3 = 8u` | **MATCH** |
| half-width gate | `if (OBJ_STATUS_FLAGS & 0x40) WORLD_TMP2 >>= 1` | same with `(uint8_t)(... >> 1)` cast | **MATCH** |
| add object position | `WORLD_TMP2 = OBJ_X + WORLD_TMP2` | same | **MATCH** |
| add object position | `WORLD_TMP3 = OBJ_Y + WORLD_TMP3` | same | **MATCH** |

**Verdict: cave_get_object_middle FULL MATCH** — pure C, no shims, no
deferred TODOs.

## Cutover gate

- Title.md callsite `z01_get_object_middle` (src/gen/z_01.c, hand-written
  outside auto-region) gates on `NATIVE_WORLD` — first Phase 4 cutover gate.
- Default OFF → oracle drain `worldrt_get_object_middle` (drain FULL MATCH).
- Defined ON → native `world_get_object_middle` (FULL MATCH; drop-in
  replacement once Title.md build.bat compiles + links world_dispatch.c).
- RoomRom links it unconditionally (build.bat updated to compile
  src/game/world/world_dispatch.c → world_dispatch.o).

**Open: Title.md build.bat does not yet compile + link src/game/world/
world_dispatch.c. Flipping NATIVE_WORLD will fail link until that's
wired.** This matches the cave situation (src/game/cave/cave_dispatch.c
also not yet linked into Title.md). Both will be addressed in a
build-symmetry commit before any consumer flips a gate.

## Stance update

Phase 4 Task 4.1 (Stance: ADOPT) — first overworld port. Pure leaf
function; no follow-on dependencies. Establishes Phase 4 native scaffold
under `src/game/world/`. Subsequent ports per Phase 4 sub-tasks port
worldrt_get_shortcut_or_item_xy_for_room, worldrt_animate_world_fading,
worldrt_check_mazes (the rest of world_runtime.c) into the same dispatch
file.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc cited per process improvement from finding 3_2.
