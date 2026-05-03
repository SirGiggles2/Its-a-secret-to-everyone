# Drain Finding — Phase 3 Task 3.4 (native port) — `cave_draw_items`

**Per Rule D1 Gate 1.** Native rewrite vs drained C vs NES disassembly.
Companion to Phase 3 summary verdict (line 13: drain MATCH).

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/cave/cave_dispatch.c` | `cave_draw_items` body |
| Drained C | `src/oracle/cave/cave_runtime.c` | 199-218 |
| NES asm | `reference/aldonunez/Z_01.asm` | 388-440 (DrawCaveItems) |
| NES data | `reference/aldonunez/Z_01.asm` | 385 (`CaveWareXs: .BYTE $58, $78, $98`) |
| NES vars | `reference/aldonunez/Variables.inc` | `ObjX := $0070` (+19=$0083), `ObjY := $0084` (+19=$0097), `CaveFlags := $0413`, $0421 = active ware idx, `CaveItemIds = $0422..$0424` |
| State accessors | `src/state/cave_state.h` | `cave_flags_get/set`, `cave_active_ware_index_get/set`, `CAVE_WARES_PER_ROOM=3u`, `CAVE_WARE_DRAW_SLOT=19u` |

## Per-block diff

| NES (Z_01.asm 388-440) | Drain (cave_runtime.c 199-218) | Native (cave_dispatch.c) | Verdict |
|------------------------|--------------------------------|--------------------------|---------|
| `LDA CaveFlags / AND #$04 / BEQ @ShowPriceRupee` | `if (CAVE_FLAGS & 4)` | `if (cave_flags_get() & 0x04u)` | **MATCH** |
| `LDA #$02 / STA $0421` | `CAVE_ACTIVE_WARE_INDEX = 2` | `cave_active_ware_index_set(2u)` | **MATCH** |
| `LDX $0421 / LDA CaveWareXs,X / STA ObjX+19` | `RAM(0x0083) = CaveWareXs[i]` | `RAM(0x0083) = ware_xs[i]` (table baked in: `{0x58,0x78,0x98}`) | **MATCH** |
| `LDA #$98 / STA ObjY+19` | `RAM(0x0097) = 0x98` | `RAM(0x0097) = 0x98u` | **MATCH** |
| `LDA CaveItemIds,X / AND #$3F / CMP #$3F / BEQ @NextWare` | `item = CAVE_WARE_ITEM(i) & 0x3F; if (item != 0x3F)` | `unsigned char item = (RAM(0x0422+i) & 0x3Fu); if (item != 0x3Fu)` | **MATCH** |
| `LDX #$13 / JSR AnimateItemObject` | `c_animate_item_object(item, CAVE_WARE_DRAW_SLOT)` | **STAGE-1 STUB** — Phase 4 native cave_animate_item_object | DEFERRED |
| `DEC $0421 / BPL @LoopWare` | `CAVE_ACTIVE_WARE_INDEX--; while ((signed char)CAVE_ACTIVE_WARE_INDEX >= 0)` | `cave_active_ware_index_set(idx-1); while ((signed char)idx >= 0)` | **MATCH** |
| `LDA CaveFlags / AND #$08 / BEQ @Exit` | `if (CAVE_FLAGS & 8)` | `if (cave_flags_get() & 0x08u)` | **MATCH** |
| `LDA #$30 / STA ObjX+19 / LDA #$AB / STA ObjY+19` | `RAM(0x0083)=48; RAM(0x0097)=0xAB` | `RAM(0x0083)=0x30u; RAM(0x0097)=0xABu` | **MATCH** |
| `LDA #$18 / LDX #$13 / JSR AnimateItemObject` | `c_animate_item_object(24, CAVE_WARE_DRAW_SLOT)` | **STAGE-1 STUB** — Phase 4 native rupee draw | DEFERRED |

## Verdict summary

**STAGE-1 SHAPE MATCH.** Flag dispatch, loop bounds, X/Y writes, item
sentinel check, and rupee placement coords are byte-for-byte equivalents
of NES + drain. Underlying `AnimateItemObject` invocations stubbed
pending Phase 4 native item-object draw (`cave_animate_item_object`
using sprite descriptors + `render_sat_write`).

CaveWareXs ($58/$78/$98) is baked in as a `static const` table inside
`cave_draw_items`. Native code stays independent of `src/data/*.inc`
transpile data path.

## Cutover gate

- Title.md callsite `z01_draw_cave_items` (src/gen/z_01.c, hand-written
  outside auto-region) shares the `NATIVE_CAVE_DRAW` gate with
  `z01_draw_cave_person`.
- Default OFF → oracle drain `cavert_draw_cave_items` (drain MATCH).
- Defined ON → native `cave_draw_items` (stage-1: cave wares + price
  rupee invisibly absent until Phase 4 lands).
- RoomRom links it but does not yet call it (cave_tick stub).

## Stance update

Phase 3 Task 3.4 (Stance: EXTEND) — surface ported, draw bodies deferred.
Phase 4 sub-task: native `cave_animate_item_object(item_id, slot)` reads
the active sprite descriptor for slot 19 and emits SAT entries via
`render_sat_write`. Once that lands, stage-2 fills both stubs and re-
files this finding as **FULL MATCH (native)** with byte-level SAT
parity proof.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc cited per process improvement from finding 3_2.
