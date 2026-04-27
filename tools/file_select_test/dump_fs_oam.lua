-- dump_fs_oam.lua
-- Boot Redux NES ROM, advance to File Select screen, dump OAM bytes 0..255 to CSV.
-- OAM layout: 64 sprites x 4 bytes each.
--   byte 0 = Y position (sprite renders at Y+1)
--   byte 1 = tile index
--   byte 2 = attribute (palette, flip flags)
--   byte 3 = X position
--
-- Output: tools/file_select_test/out/fs_oam.csv
-- Each line: <byte_index>,<hex_value>  (0..255)
-- Also writes a decoded sprite table: tools/file_select_test/out/fs_oam_decoded.txt

local ROOT = os.getenv("CODEX_BIZHAWK_ROOT") or "."
ROOT = ROOT:gsub("\\", "/")
local OUT_DIR = ROOT .. "/tools/file_select_test/out"
local OUT_CSV = OUT_DIR .. "/fs_oam.csv"
local OUT_TXT = OUT_DIR .. "/fs_oam_decoded.txt"

os.execute('if not exist "' .. OUT_DIR:gsub("/", "\\") .. '" mkdir "' .. OUT_DIR:gsub("/", "\\") .. '"')

print("dump_fs_oam: ROOT=" .. ROOT)
print("dump_fs_oam: OUT_CSV=" .. OUT_CSV)

-- Advance past title screen.  The NES Redux title requires ~200 frames
-- before the title animation completes and Start can be pressed.
-- We advance 300 frames to be safely past any boot sequence, then pulse
-- Start, then advance 120 more frames to let the File Select settle.
for f = 1, 300 do emu.frameadvance() end

-- Press Start to leave title screen (hold 2 frames, release)
joypad.set({ ["P1 Start"] = true }, 1)
emu.frameadvance()
joypad.set({}, 1)
emu.frameadvance()

-- Settle into File Select screen (60 frames)
for f = 1, 118 do emu.frameadvance() end

print("dump_fs_oam: at FS, frame=" .. emu.framecount())

-- Dump raw OAM bytes 0..255 to CSV
local fh = assert(io.open(OUT_CSV, "w"))
fh:write("byte_index,hex_value\n")
for i = 0, 255 do
    local v = memory.read_u8(i, "OAM")
    fh:write(string.format("%d,%02X\n", i, v))
end
fh:close()
print("dump_fs_oam: wrote " .. OUT_CSV)

-- Also write decoded sprite table for easy inspection
local fh2 = assert(io.open(OUT_TXT, "w"))
fh2:write("=== NES OAM at FS frame ~" .. emu.framecount() .. " ===\n")
fh2:write("# Format: spr NN: Y=YY T=TT A=AA X=XX  (renders at screen_y=Y+1)\n")
fh2:write("# Sprites with Y >= $EF are offscreen (hidden)\n\n")

local cursor_candidates = {}
for i = 0, 63 do
    local base = i * 4
    local y = memory.read_u8(base + 0, "OAM")
    local t = memory.read_u8(base + 1, "OAM")
    local a = memory.read_u8(base + 2, "OAM")
    local x = memory.read_u8(base + 3, "OAM")
    local line = string.format("spr %02d: Y=%02X T=%02X A=%02X X=%02X", i, y, t, a, x)
    if y >= 0xEF then
        line = line .. "  [hidden]"
    else
        -- Check if Y is near known slot row positions
        -- Slot 1: Y~$47 (renders at $48), Slot 2: Y~$57, Slot 3: Y~$67
        if (y >= 0x44 and y <= 0x4B) then
            line = line .. "  <== SLOT1 CURSOR CANDIDATE"
            cursor_candidates[#cursor_candidates + 1] = {spr = i, y = y, t = t, a = a, x = x, slot = 1}
        elseif (y >= 0x54 and y <= 0x5B) then
            line = line .. "  <== SLOT2 CURSOR CANDIDATE"
            cursor_candidates[#cursor_candidates + 1] = {spr = i, y = y, t = t, a = a, x = x, slot = 2}
        elseif (y >= 0x64 and y <= 0x6B) then
            line = line .. "  <== SLOT3 CURSOR CANDIDATE"
            cursor_candidates[#cursor_candidates + 1] = {spr = i, y = y, t = t, a = a, x = x, slot = 3}
        end
    end
    fh2:write(line .. "\n")
end

fh2:write("\n=== CURSOR CANDIDATES ===\n")
if #cursor_candidates == 0 then
    fh2:write("WARNING: no sprites found near expected slot Y positions ($44-$6B)!\n")
    fh2:write("Game may not have reached File Select yet, or Y positions differ.\n")
    fh2:write("Check all visible sprites above for the heart cursor tile.\n")
else
    for _, c in ipairs(cursor_candidates) do
        fh2:write(string.format("Slot %d: spr%02d Y=$%02X T=$%02X A=$%02X X=$%02X  (screen_y=%d)\n",
            c.slot, c.spr, c.y, c.t, c.a, c.x, c.y + 1))
    end
end

fh2:close()
print("dump_fs_oam: wrote " .. OUT_TXT)

-- Print summary to console
print("=== CURSOR CANDIDATES ===")
if #cursor_candidates == 0 then
    print("WARNING: no candidates found near Y=$44-$6B")
else
    for _, c in ipairs(cursor_candidates) do
        print(string.format("Slot %d candidate: spr%02d Y=$%02X T=$%02X (tile) A=$%02X X=$%02X",
            c.slot, c.spr, c.y, c.t, c.a, c.x))
    end
end

client.exit()
