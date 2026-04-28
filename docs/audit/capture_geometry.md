<!-- docs/audit/capture_geometry.md -->
# Capture Geometry (locked at S0)

| Field | Value |
|---|---|
| Genesis display mode | **H32** (256×224 visible) |
| RGB viewport size | **256×224 px** |
| Crop origin (Genesis) | `(0, 0)` — full H32 frame is the comparison region |
| Crop origin (NES) | `(0, 8)` — skip the top 8 scanlines (NES blanking) so the 224-line comparison region aligns with Genesis H32 |
| Overscan policy | **Ignored** — both captures are cropped to 256×224 visible playfield |
| Backdrop / transparent color | NES `$3F00` (universal background) → Genesis CRAM byte 0 (palette 0, index 0). Both treated as the canonical backdrop in the normalized parity schema. |
| Screenshot scaling | None (1:1 pixel comparison) |

## Resolution

VDP mode confirmed by inspecting `src/genesis_shell.asm`:

- Register 1 = `$8134` (display off during init) / `$8174` (display on) → mode bit M5 set; Genesis mode active.
- Register 12 = `$8C00` → bits 7 and 0 (RS1 / RS0) both clear → **H32** (256-pixel wide; 32 tile columns).
- Plane A at VRAM `$C000`; window plane at `$B000` (HUD strip overlay).

H32 is locked because the existing FINAL TRY ROM uses it; NES (256×240) maps
naturally to Genesis H32 (256×224) by skipping NES's top blanking strip.

## Implications for parity tooling

- `tools/probes/normalize_nes.py` must crop to `(0, 8, 256, 232)` (NES native is
  256×240; visible playfield is 256×224 starting at row 8). HUD strip on Genesis
  Plane B occupies the same 224-line height; tooling does not need a second
  crop for HUD.
- `tools/probes/normalize_gen.py` captures the full H32 viewport `(0, 0, 256, 224)`.
- `tools/probes/diff_capture.py` operates on the cropped 256×224 RGB buffers
  for screenshot parity, and on the full plane/SAT/CRAM byte streams for
  logical parity.
- The locked palette table from `docs/audit/emulators.md` (`quickerNES`
  built-in) drives any external NES→Genesis CRAM mapping needed by the
  normalized schema.

## Open issues

None. Geometry is fixed by the current ROM's VDP register choices; changing
H32→H40 in S1+ would be a spec amendment, not a S0 task.
