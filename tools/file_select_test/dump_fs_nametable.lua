-- dump_fs_nametable.lua
-- Boot Redux NES ROM, advance to File Select screen, dump nametable 0 ($2000-$23FF)
-- to binary file for static UI tilemap extraction.
--
-- 1024 bytes: 960 bytes tile indices (30 rows x 32 cols) + 64 bytes attribute table.
-- Output: tools/file_select_test/ref/fs_nt.bin  (tracked reference artifact)
--
-- Frame timing mirrors dump_fs_oam.lua (300 advance + Start press + 118 settle = ~421 total).
-- This is confirmed to land on FS screen per R8 OAM probe output.
--
-- LAUNCH NOTE: Set CODEX_BIZHAWK_ROOT via the environment BEFORE launching BizHawk
-- (not via PowerShell $env: which does not propagate to Start-Process children).
-- If CODEX_BIZHAWK_ROOT is unset, output lands relative to BizHawk's working dir.
-- Alternatively: copy this script + ROM to C:\tmp\ and hardcode output to C:\tmp\fs_nt.bin.

local ROOT = os.getenv("CODEX_BIZHAWK_ROOT") or "."
ROOT = ROOT:gsub("\\", "/")
local REF_DIR = ROOT .. "/tools/file_select_test/ref"
local OUT_BIN = REF_DIR .. "/fs_nt.bin"

os.execute('if not exist "' .. REF_DIR:gsub("/", "\\") .. '" mkdir "' .. REF_DIR:gsub("/", "\\") .. '"')

print("dump_fs_nametable: ROOT=" .. ROOT)
print("dump_fs_nametable: OUT_BIN=" .. OUT_BIN)

-- Advance past title screen (same timing as dump_fs_oam.lua).
-- 300 frames gets us past the Redux title animation.
for f = 1, 300 do emu.frameadvance() end

-- Press Start to leave title screen (hold 2 frames, release)
joypad.set({ ["P1 Start"] = true }, 1)
emu.frameadvance()
joypad.set({}, 1)
emu.frameadvance()

-- Settle into File Select screen (118 frames, matching R8 OAM probe)
for f = 1, 118 do emu.frameadvance() end

print("dump_fs_nametable: at FS, frame=" .. emu.framecount())

-- Dump PPU nametable 0: $2000-$23FF (1024 bytes).
-- BizHawk NES core exposes "PPU Bus" domain for live PPU memory reads.
local fh = assert(io.open(OUT_BIN, "wb"))
for i = 0, 0x3FF do
    local v = memory.read_u8(0x2000 + i, "PPU Bus")
    fh:write(string.char(v))
end
fh:close()

print("dump_fs_nametable: wrote 1024 bytes to " .. OUT_BIN)
print("dump_fs_nametable: nametable tile rows 0..29 + 64 attr bytes")

-- Print first 5 rows of nametable tiles for quick sanity check in console
print("=== Nametable tile preview (row 0-4, 32 cols each) ===")
local fh2 = assert(io.open(OUT_BIN, "rb"))
local raw = fh2:read("*a")
fh2:close()

for row = 0, 4 do
    local line = string.format("row%02d: ", row)
    for col = 0, 31 do
        local byte_idx = row * 32 + col + 1  -- Lua string is 1-indexed
        local v = string.byte(raw, byte_idx)
        line = line .. string.format("%02X ", v)
    end
    print(line)
end

client.exit()
