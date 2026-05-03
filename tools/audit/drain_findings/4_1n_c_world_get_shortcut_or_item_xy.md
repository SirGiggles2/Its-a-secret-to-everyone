# Drain Finding — Phase 4 Task 4.1 (native port) — `world_get_shortcut_or_item_xy`

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for the
shortcut/item screen-coordinate decoder (used by overworld shortcut
warp + underworld item drop position lookup).

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/world_dispatch.c` | `world_get_shortcut_or_item_xy_for_room`, `world_get_shortcut_or_item_xy` |
| Drained C | `src/oracle/world/world_runtime.c` | 6-17 |
| NES asm | `reference/aldonunez/Z_01.asm` | 3993-4020 (GetShortcutOrItemXY + GetShortcutOrItemXYForRoom) |
| NES SRAM data | LevelBlockAttrsF at $6AFE; LevelInfo_ShortcutOrItemPosArray at $6BA7 (cartridge data area, mirrored into nes_ram[] via the bridge layer) |
| NES vars | `reference/aldonunez/Variables.inc` | `RoomId := $00EB` (= CUR_ROOM_ID) |

## Drain MATCH proof — block-by-block

| NES (Z_01.asm 4002-4020) | Drain (world_runtime.c 6-13) | Verdict |
|--------------------------|-------------------------------|---------|
| `LDA LevelBlockAttrsF,Y` (Y = room_id) | `lookup = nes_ram[$6000 + 0x0AFE + room_id]` | **MATCH** — LevelBlockAttrsF is at SRAM $6AFE (= $6000+$0AFE), room_id-indexed. |
| `AND #$30 / LSR x4` | `type_idx = (lookup & 0x30) >> 4` | **MATCH** — isolate bits 4-5, shift to LSB. |
| `LDA LevelInfo_ShortcutOrItemPosArray,Y` (Y = type_idx) | `entry = nes_ram[$6000 + 0x0BA7 + type_idx]` | **MATCH** — array at SRAM $6BA7. |
| `PHA / AND #$0F / ASL x4 / TAY` | `y = (entry & 0x0F) << 4` | **MATCH** — low nibble << 4 = Y screen coord. |
| `PLA / AND #$F0` (returned in A) | `x = entry & 0xF0` | **MATCH** — high nibble already in upper position = X screen coord. |
| Return: A = X, Y = Y | Return: `(x << 8) | y` packed unsigned int | **MATCH** (semantic — drain packs A/Y into one int for C-callers). |

For `GetShortcutOrItemXY` (no-arg variant):

| NES (Z_01.asm 3993-3994) | Drain (world_runtime.c 15-17) | Verdict |
|--------------------------|-------------------------------|---------|
| `LDY RoomId / fall through` | `return worldrt_get_shortcut_or_item_xy_for_room(CUR_ROOM_ID)` | **MATCH** |

**Verdict: worldrt_get_shortcut_or_item_xy[_for_room] FULL MATCH** vs NES.

## Native port

Pure-leaf functions — no shims, no deferred TODOs. Direct equivalent of
drain logic with `nes_ram[]` access via `platform_abi.h`.

| Block | Drain | Native | Verdict |
|-------|-------|--------|---------|
| LevelBlockAttrsF lookup | `nes_ram[NES_SRAM_BASE + 0x0AFE + room_id]` | same with `(room_id & 0xFFu)` mask for safety | **MATCH** |
| type_idx extract | `(lookup & 0x30) >> 4` | same | **MATCH** |
| ShortcutOrItemPosArray lookup | `nes_ram[NES_SRAM_BASE + 0x0BA7 + type_idx]` | same | **MATCH** |
| Y decode | `(entry & 0x0F) << 4` | same | **MATCH** |
| X decode | `entry & 0xF0` | same | **MATCH** |
| pack return | `(x << 8) \| y` | same | **MATCH** |
| no-arg variant | `worldrt_*_for_room(CUR_ROOM_ID)` | `world_*_for_room((unsigned int)CUR_ROOM_ID)` | **MATCH** |

**Verdict: world_get_shortcut_or_item_xy[_for_room] FULL MATCH** —
drop-in.

## Cutover gate

- Title.md callsites `z01_get_shortcut_or_item_xy_for_room` +
  `z01_get_shortcut_or_item_xy` share `NATIVE_WORLD` gate.
- Default OFF → oracle drain (drain FULL MATCH).
- Defined ON → native (drop-in FULL MATCH).
- RoomRom links unconditionally (build.bat compiles world_dispatch.c
  via prior commit `d1003edb`).

## Stance update

Phase 4 Task 4.1 (Stance: ADOPT) — third world port. Drain `world_runtime.c`
is now 3/4 functions ported (get_object_middle, check_mazes, get_shortcut_or_item_xy
+ no-arg variant). Remaining: `worldrt_animate_world_fading` — uses
TRANSFER_BUF pipeline (cross-subsystem). Defers to Phase 4 transfer-
buf primitive port.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc + SRAM table addresses cited per process improvement
  from finding 3_2.
