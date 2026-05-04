# Drain Finding — Phase 4 Task 4.14 (native port) — room mode helpers (no-emulation)

**Per Rule D1 Gate 1.** Native ports of room mode helpers that
formerly required NES-hardware emulation shims (MMC1 mapper writes,
PPU register writes). Per debate 007 synthesis (no-emulation, native
mantra), MMC1 calls dropped entirely; PPU mask shadow + Genesis VDP
display-disable handled natively.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (extends) | `src/game/room/room_dispatch.{h,c}` | `room_turn_off_all_video`, `room_world_fill_hearts`, `room_update_hearts_and_rupees`, `room_update_mode3_unfurl` |
| Drain | `src/oracle/room/room_mode_runtime.c` (272-327), `room_object_runtime.c` (31-48) |
| NES asm | `reference/aldonunez/Z_07.asm:1739` (TurnOffAllVideo) |

## Stance

**REWRITE-MIRROR with NES-hardware drops.** Per debate 007 synthesis:

### MMC1 / SwitchBank — DROPPED entirely (option A)
- `c_set_mmc1_control(15)` in `roommd_update_mode3_unfurl` → removed.
- `c_switch_bank(5)` in `roommd_update_hearts_and_rupees` → removed.
- Genesis has flat M68K address space; no MMC1 mapper exists.
- Pre-flight gate audit: SwitchBank/SetMMC1Control callers verified to
  remain in `src/zelda_translated/z_01.asm` + `z_07.asm` (Title.md
  transpile asm) which is NOT modified — Title.md path keeps its
  asm bank-switch calls, native path drops them. NATIVE_ROOM flips
  between paths cleanly.

### TurnOffAllVideo — Genesis-native VDP control (option C, Sonnet correction)
NES asm:
```
moveq #0,D0
jsr _ppu_write_1     ; PPUMASK shadow + Genesis VDP Reg 1 = $8134
move.b D0,($00FE,A4) ; PPU_MASK shadow = 0
```

Sonnet's debate 007 contribution: pure shadow write is **insufficient**.
NES `_ppu_write_1` does TWO things:
1. PPUMASK shadow at `$00FE`.
2. Genesis VDP Reg 1 disable (`move.w #$8134, (VDP_CTRL).l`).

Without #2, mode transitions display stale VRAM (tearing). Native
implementation must do both:
```c
RAM(NES_PPU_MASK_SHADOW) = 0u;
render_display_enable(0u);  /* SGDK adapter native VDP toggle */
```

`render_display_enable` lives in `src/sgdk_adapter/render_adapter.c`
(VDP Reg 1 raw write). Forward-decl'd in `room_dispatch.c`. This is
**Genesis-native**, not NES-emulation.

### WorldFillHearts — pure RAM port
Drain is pure RAM logic + `z01_compare_hearts_to_containers` (native
via NATIVE_CORE). Direct rewrite. Uses `WORLD_TMP0` (= ZP_TMP0 =
`RAM($0000)`) to compare against current container target.

### update_mode3_unfurl — preserved gate semantics
- `progress_update_world_curtain_effect` native (NATIVE_PROGRESS).
- `room_go_to_next_mode_*` native (NATIVE_ROOM).
- MMC1 ctrl drop documented.

### update_hearts_and_rupees — pure dispatch
- `room_world_fill_hearts` native.
- `hud_world_change_rupees` native (NATIVE_HUD).
- `c_switch_bank(5)` drop documented.

## DEFERRED — room_update_mode2_load

`roomld_update_mode2_load_full` calls `c_copy_bank_to_window(6)` —
a `c_`-prefixed bank-window cache shim (`src/c_shims.asm:999`).
Strict reading of CLAUDE.md "no transpile-bridge shims (z01_/z07_/c_/
...) in src/game/" blocks the drain call.

Two paths to unblock:
1. Port `roomld_update_mode2_load_full` natively (heavy z_06 chain:
   level pattern transfer + palette upload + common data copy).
2. Expose non-c_-prefixed bank-window primitive that
   `room_update_mode2_load` can call directly.

Path 2 is cleaner — `_copy_bank_to_window` (asm primitive in nes_io.asm
line 1719) is Genesis-native bank-window cache, not NES emulation.
Renaming the c_ wrapper or exposing a `bank_copy_to_window()` native
inline is a 1-line change. Deferred to a follow-up commit.

## Cutover

- z_07 manifest: drop 2 entries (`roommd_update_mode3_unfurl`,
  `roommd_update_hearts_and_rupees`). `roommd_update_mode2_load`
  retained (deferred).
- src/gen/z_07.c: hand-write 2 wrappers under `NATIVE_ROOM`.

## Verification

- `build_all.ps1` green: Title.md + RoomRom.md both link.
- Title.md sha unchanged: `56f1e2f7681562fc` (verified).
- Default OFF preserves all transpile-asm bank-switch behavior on
  Title.md — only NATIVE_ROOM flag flip drops MMC1.

## Phase 4 status

room subsystem: 21+ fns native (was 17). Zero MMC1/SwitchBank/PPU
references in any NATIVE_ROOM-gated native code. Mantra: **NO
EMULATION. WE ARE NATIVE.** ✓

## References

- Debate 007 synthesis: `~/.claude-octopus/debates/FINAL_TRY/007-no-emulation-mmc1/synthesis.md`
- Sonnet's VDP-write correction: `r001_sonnet.md` paragraph "C without VDP control write".
- Strict-vs-spirit drain-call rule resolution: all 4 advisors agree drain prefixes are not banned shim prefixes; spirit allows native C calls.
