# Codex Handoff — RoomRom Visual Fix + S3 Continuation
Date: 2026-04-28

## What You're Working On

RoomRom is a **dev testing ROM** (not a release ROM) that boots straight to Zelda 1 overworld room 0x77 and lets you D-pad navigate all 128 rooms. Purpose: skip the file select screen during Genesis port development.

Project lives at: `RoomRom/` inside the main repo `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\`

**Current state:** ROM builds and boots. D-pad navigation works. Room tiles render. BUT the screen looks wrong — orange artifact tiles fill the borders because `overworld_bg_chr` tile 0 is an orange ground tile, and SGDK initializes all plane cells to word=0 (→ tile 0). User said: "It's in the wrong spot. Put it in the right spot as if the HUD was there."

---

## Immediate Task — Fix Tile-0 Artifact

### Root Cause
`overworld_bg_chr[0..31]` = orange ground tile. SGDK inits all 64×32 plane A cells to 0. Cells outside the rendered room area (rows 0-1 top, rows 24-27 bottom, cols 32-39 right in H40 mode) display this orange tile.

### Fix — two changes to `RoomRom/src/main.c`

**1. Zero VRAM tile 0 after CHR upload** (in `main()`, after `ow_room_render_upload_chr()`):
```c
{
    u32 blank[8] = {0,0,0,0,0,0,0,0};
    VDP_loadTileData(blank, 0, 1, CPU);
}
```

**2. Clear plane A before each room render** (in `load_room()`, before `ow_room_render_fill_plane_a()`):
```c
VDP_clearPlane(BG_A, TRUE);
```
`VDP_clearPlane` is confirmed in `sgdk/inc/vdp_bg.h` line 232: `void VDP_clearPlane(VDPPlane plane, bool wait);`

### Expected result
- Top 2 rows (HUD area): black
- Left/right/bottom borders outside room: black
- Room content: correct green/brown overworld tiles

---

## Build Instructions

```powershell
# Build
$bat = "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\RoomRom\build.bat"
$out = "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\RoomRom\build_out.txt"
$err = "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\RoomRom\build_err.txt"

# CRITICAL: convert build.bat to CRLF after ANY edit to it
$text = [System.IO.File]::ReadAllText($bat)
$crlf = $text -replace "(?<!\r)\n", "`r`n"
[System.IO.File]::WriteAllText($bat, $crlf, [System.Text.Encoding]::ASCII)

# Run build
$p = Start-Process -FilePath "C:\Windows\System32\cmd.exe" `
    -ArgumentList "/c call `"$bat`"" `
    -WorkingDirectory "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\RoomRom" `
    -Wait -NoNewWindow -PassThru `
    -RedirectStandardOutput $out -RedirectStandardError $err
$p.ExitCode  # 0 = success
```

Output ROM: `RoomRom\out\RoomRom.md`

**DO NOT** use `cd` + `cmd.exe build.bat` — path spaces break it. Use `Start-Process -WorkingDirectory` exactly as above.

---

## Screenshot / Verify

BizHawk lua probe at `RoomRom/probe_roomrom.lua`. Launch pattern:
```powershell
$biz = "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\build\toolchain\bizhawk\EmuHawk.exe"
$rom = "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\RoomRom\out\RoomRom.md"
$lua = "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\RoomRom\probe_roomrom.lua"
$env:CODEX_BIZHAWK_ROOT = "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\build\toolchain\bizhawk"
Start-Process -FilePath $biz -ArgumentList "--lua=`"$lua`"", "`"$rom`"" -WorkingDirectory (Split-Path $biz)
```
Screenshot saved to `RoomRom\out\roomrom_screen.png`. Read it with the Read tool to see the result.

---

## Key Files

| File | Purpose |
|------|---------|
| `RoomRom/src/main.c` | Main loop, navigation, CHR upload |
| `RoomRom/src/render_adapter_sgdk.c` | SGDK implementation of render_abi |
| `RoomRom/build.bat` | Build script (must stay CRLF) |
| `RoomRom/probe_roomrom.lua` | BizHawk screenshot probe |
| `src/game/room/ow_room_render.c` | Shared room render logic (don't break main ROM) |
| `src/game/room/ow_room_render.h` | Header for room render |
| `src/abi/render_abi.h` | ABI between game code and platform |
| `data/rooms/overworld.c` | 3090-byte rooms_overworld[] array |
| `data/chr/overworld_bg.c` | 4160-byte overworld_bg_chr[] |

---

## Room Layout Reference

- 128 rooms: 16 wide × 8 tall
- `room_id = (row << 4) | col`
- `col = room_id & 0x0F`, `row = room_id >> 4`
- `rooms_overworld[768 + room_id] >> 6` = area (0-3) for palette
- Area 3 = south forest (rooms 0x60-0x7F, including 0x77)

---

## After Fixing the Visual

1. **Commit** everything (nothing committed yet this session): build.bat, render_adapter_sgdk.c, ow_room_render.h/c palette additions, main.c navigation + tile-0 fix.
2. Verify screenshot looks correct: black HUD bar top, black borders, green room content.
3. Continue S3 tasks:
   - **S3.A3**: `probe_room_render.py` diff=0 check for room 0x77
   - **S3.B**: `batch_room_render.py` — all 128 rooms
   - **S3.C**: Room navigation in main ROM (separate from RoomRom)
   - **S3.D**: Smooth scroll transition
   - **S3.E**: Close-out + `s3-closed` tag

---

## Important Rules (from project memory)

- **Commit working changes before starting next task** — nothing in this session is committed yet
- **CRLF on build.bat** — cmd.exe fails to parse LF-only .bat files; convert after every edit
- **8.3 short paths** — `%%~fsI` in build.bat for loops; keeps cc1.exe findable by gcc
- **Never ask user to describe visuals** — build it, screenshot it, Read the PNG yourself
- **Never ask user to launch BizHawk** — use the launch pattern above
- **Don't touch shared game code** unless fixing a real bug in it — RoomRom is a test tool
- **Check, don't guess** — dump NES ROM data before changing tile/palette/layout
