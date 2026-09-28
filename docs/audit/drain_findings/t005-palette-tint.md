# T-005 — Triforce and pause tint after NES-reference LUT

**Result: PASS for the questioned tint; no generator change.** This does not close the wider P7.1a pause-presentation task.

## Source and scenario

- Owning conversion: `tools/extract_misc.py:nes_color_index_to_genesis`, emitted to `data/misc/palettes.c`, consumed through `src/game/world/bg_palette.c` and `src/game/inventory/inventory_palette.c`.
- NES reference: BizHawk 2.11 NesHawk palette and live settled pause PALRAM from `builds/reports/recovery/p7-pause-ow-nes-20260923/` (room `$77`) and `p7-pause-allitems-nes-20260923/` (L1 room `$45`). The same 32-byte PALRAM values are visible in the captured files. NES ROM SHA-256: `8f72dc2e98572eb4ba7c3a902bca5f69c448fc4391837e5f8f0d4556280440ac`.
- Current Genesis capture: isolated BizHawk Genplus-gx probes cloned from the matched 2026-09-23 probes, with separate staging/config and report directories `builds/reports/recovery/t005-pause-ow-gen-current/` and `t005-pause-l1-gen-current/`. Both reached the same room, level and staged inventory as their NES counterpart and dumped 128 CRAM bytes plus screenshots. `builds/Debug.md` SHA-256: `276a015a9b6f709bd0b6bb2ab616ae4aa512388ac236a5ce4f4f5a2a8b9faf6a` (T-154 verified Windows build). This is a presentation fixture, not an acquisition route.

## Byte comparison

Each captured NES PALRAM index was converted with the current 64-entry LUT and compared with the current Genesis CRAM word at its routed slot. Genesis CRAM dump words are big-endian.

| Settled pause scene | BG PAL0–3 | SPR PAL1 nontransparent | Additional PAL2 | Additional PAL3 |
|---|---:|---:|---:|---:|
| OW `$77` Triforce | 16/16 | 12/12 | 3/3 | 3/3 |
| L1 `$45` map | 16/16 | 11/12 ordinary + 1/1 marker override | 3/3 | 3/3 |

The four transparent sprite color-zero slots in OW use NES `$00` converted to CRAM `$666` even though BizHawk PALRAM reads `$0F` at the mirrors; no visible pixel uses those slots. L1 reuses PAL1 index 9 for the compass/Triforce map marker: its CRAM `$440` equals the conversion of the NES sprite sub-palette 3 color 1 (`$0C`), not the ordinary sprite color at PALRAM index 25 (`$16`). This is the documented `inventory_subscreen_enter` override, and the current capture confirms it.

The questioned indices now map `$17 → $048`, `$36 → $CCE`, `$37 → $ACE`; the current CRAM contains these words wherever the live NES PALRAM uses them. The removed August override words (`$04E`, `$46E`, `$8EE`) were farther from the locked NES RGB reference: summed channel errors for the three colors fell respectively `96→28`, `249→23`, and `60→26`. Current OW and L1 screenshots were inspected alongside the NES screenshots; the Triforce fill and menu tint agree within Genesis color quantization. The current OW CRAM is byte-identical to the September matched capture; the current L1 CRAM differs only at the intentional two-byte marker slot.

**Stance:** KEEP the NES-reference LUT. Remaining pause layout/HUD pixel-phase and motion questions remain under P7.1a; this focused tint check makes no claim about them. No new build was needed because no source was changed.
