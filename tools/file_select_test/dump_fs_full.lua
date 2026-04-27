-- dump_fs_full.lua: boot Redux ROM, press Start, capture FS data.
-- Outputs to <repo>\tools\file_select_test\ref\:
--   real_redux_fs.png        screenshot
--   fs_chr.bin               PPU $0000-$1FFF (8KB CHR-RAM)
--   fs_nt.bin                PPU $2000-$23FF (1KB nametable + attrs)
--   fs_palram.bin            PPU $3F00-$3F1F (32 bytes palette RAM)
--   fs_oam.bin               OAM 256 bytes

local REPO = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\native-file-select"
local OUT  = REPO .. "\\tools\\file_select_test\\ref"
os.execute('mkdir "' .. OUT .. '" 2>nul')

-- Boot. Advance past title.
for f = 1, 300 do emu.frameadvance() end
-- Press Start.
joypad.set({ ["P1 Start"] = true }, 1)
emu.frameadvance()
emu.frameadvance()
joypad.set({}, 1)
-- Settle on FS.
for f = 1, 240 do emu.frameadvance() end

-- Screenshot first (fail-fast if path bad).
client.screenshot(OUT .. "\\real_redux_fs.png")

-- PPU $0000-$1FFF (CHR-RAM 8KB).
local fh = io.open(OUT .. "\\fs_chr.bin", "wb")
for i = 0, 0x1FFF do fh:write(string.char(memory.read_u8(i, "PPU Bus"))) end
fh:close()

-- PPU $2000-$23FF (nametable + attrs).
fh = io.open(OUT .. "\\fs_nt.bin", "wb")
for i = 0, 0x3FF do fh:write(string.char(memory.read_u8(0x2000 + i, "PPU Bus"))) end
fh:close()

-- PPU $3F00-$3F1F (palette RAM).
fh = io.open(OUT .. "\\fs_palram.bin", "wb")
for i = 0, 0x1F do fh:write(string.char(memory.read_u8(0x3F00 + i, "PPU Bus"))) end
fh:close()

-- OAM (256 bytes).
fh = io.open(OUT .. "\\fs_oam.bin", "wb")
for i = 0, 0xFF do fh:write(string.char(memory.read_u8(i, "OAM"))) end
fh:close()

print("[dump_fs_full] DONE")
client.exit()
