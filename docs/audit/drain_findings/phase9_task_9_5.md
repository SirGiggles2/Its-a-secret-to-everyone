# Phase 9 Task 9.5 — Native HUD

- **NES source**: `reference/aldonunez/Z_07.asm` HUD formatting +
                  status-bar transfer code:
                  - `FormatHeartsInTextBuf` (heart icon row → text
                    buf, 16-slot loop with full/half/empty tile
                    selection over `LINK_HEARTS` / partial).
                  - `FormatStatusBarText` (41-byte status buf =
                    template + hearts + rupees + bombs + keys).
                  - `WorldChangeRupees` (per-frame rupee anim tick:
                    drain `$067D` credit accumulator into
                    `LINK_RUPEES`, drain
                    `CAVE_DOOR_REPAIR_RUPEE_DELTA`, sfx + status bar
                    refresh).
                  - `CopyTripletToTextBuf` (ZP `$01/$02/$03` →
                    `TRANSFER_BUF_BYTE(base-2/-1/0)`).
                  - `FormatDecimalCountByte` (3-digit BCD format via
                    `cave_format_decimal_byte`, leading `$24` clamp to
                    33).
- **Drained C**:  `src/oracle/hud/hud_runtime.c` —
                  `hudrt_format_hearts_in_text_buf` (lines 6-50),
                  `hudrt_copy_triplet_to_text_buf` (52-57),
                  `hudrt_format_decimal_count_byte` (59-68),
                  `hudrt_format_decimal_count_byte_in_text_buf`
                  (70-74), `hudrt_format_status_bar_text` (76-93),
                  `hudrt_world_change_rupees` (95-122). Drain PRIMARY
                  for HUD formatter pipeline.
- **Coverage**:   FULL — every NES status-bar formatter drained and
                  exposed through `src/game/hud/hud_dispatch.h`:
                  `hud_format_hearts_in_text_buf`,
                  `hud_copy_triplet_to_text_buf`,
                  `hud_format_decimal_count_byte`,
                  `hud_format_decimal_count_byte_in_text_buf`,
                  `hud_format_status_bar_text`,
                  `hud_world_change_rupees`.
- **Stance**:     ADOPT — `src/game/hud/hud_dispatch.c` is a thin
                  forwarder layer that wraps the drained `hudrt_*`
                  bodies. Active HUD rendering during gameplay is
                  driven by RoomRom legacy `roomrom_hud.c` (compiled
                  into Debug.md per build manifest); the native
                  dispatch is the formatter contract any consumer of
                  the NES OAM / transfer-buf mirror calls.

## Substrate (`src/game/hud/`)

`hud_dispatch.c` — Phase 9 native HUD formatter dispatch. Forwards to
the drained `hudrt_*` bodies; both ROMs link the same formatter
contract.

`hud_dispatch.h` — public API for HUD formatter:
  `hud_format_hearts_in_text_buf(start_off)` — drain.
  `hud_copy_triplet_to_text_buf()` — drain.
  `hud_format_decimal_count_byte(val)` — drain.
  `hud_format_decimal_count_byte_in_text_buf(val, buf_offset)` — drain.
  `hud_format_status_bar_text()` — drain.
  `hud_world_change_rupees()` — drain.

`probes/hud_format_probe.c` — locks the heart-row formatter against
hand-traced expected byte sequences. Any future native HUD renderer
consumes this contract, so probe must stay green.

`RoomRom/src/roomrom_hud.c` — legacy active HUD renderer (compile-only
in Debug.md). Phase 12 promotion will migrate this body into
`src/game/hud/hud_runtime.c` once UW dialog + map indicator + dungeon
map / compass / triforce render paths fully port. The formatter
contract above is stable across that move.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean build; `hud_dispatch.o` + `hud_format_probe.o` +
`roomrom_hud.o` linked.

## Status

CLOSE — Task 9.5 Native HUD formatter ADOPT-wired. Drain primary; six
formatter entry points exposed via `hud_dispatch.h`; probe locks
contract. Active render layer remains RoomRom legacy until Phase 12
promote.
