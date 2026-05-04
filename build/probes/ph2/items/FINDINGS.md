# Phase 2 Task 2.2 close-gate evidence — bundled item probe

**Probe:** `RoomRom/probe_roomrom_items_bundled.lua`
**ROM:** `RoomRom/out/RoomRom.md` (built before this run)
**Run:** 2026-05-04 via /bizhawkScript

## Captures

| File | Phase | Expected | Actual |
|---|---|---|---|
| `00_boot.png` | settle 240f, no input | UW L1 starting room, Link facing south | OK — Link visible, room visible |
| `01_sword_{down,up,left,right}.png` | A press per facing | Sword sprite at slot 1, attack pose | Link moved facings, **no sword sprite** |
| `02_beam_{right,down}.png` | A press at full HP | Beam sprite slot 2 | **No beam** |
| `03_boomerang_{down,right}.png` | B press default item | Boomerang slot 3 | **No boomerang** |
| `04_arrow_right.png` | Z (cycle) + B | Arrow slot 4 | **No arrow** |
| `05_bomb_fuse.png` | Z×2 + B | Bomb slot 5 with fuse | **No bomb** |
| `06_explosion_mid.png` | settle 50f after bomb | Explosion slot 5/6 | **No explosion** |

## Anomaly

`bundled.txt` SAT slot reads (Y/size/link/TileAttr/X) are all-zero across every checkpoint, including for slot 0 (Link) which is visible on screen. CRAM reads return correct nonzero palette data, so memory.read_u8 + memory.usememorydomain works in this BizHawk version.

Two non-exclusive root causes possible:
1. **SAT_BASE wrong.** Probe uses `0xF400`. SGDK's default is configurable per VDP register 5; RoomRom's actual SAT may live elsewhere. CRAM works because it's a separate domain. Need to dump VDP reg 5 or scan VRAM for the real SAT address.
2. **Items genuinely not rendering.** Even if SAT_BASE were wrong, screenshots should show item sprites — they don't. Suggests A/B/Z buttons are not triggering sword/boomerang/arrow/bomb spawn paths in this RoomRom build.

## Refusal to direct-fix

Per /primedirective Bug detection branch: defer to /chuckle (root-cause) → /octo:debate (adversarial review) → apply synthesized fix. Quick-patch shortcut forbidden.

## Affected close-gate steps

- `focused_probe_set` — probe ran, but result is RED (bug surfaced)
- `screenshot_state_evidence` — captured; shows symptom
- `diff_vs_nes_reference` — cannot be advanced until items render
