-- boot_check.lua — run N frames, watch GAME_MODE transitions, write
-- pass/fail to a file. Used as a cheap "does the ROM boot?" gate for
-- Stage-2a when byte-identical ROM isn't achievable.

local BUS         = 0xFF0000
local GAME_MODE   = BUS + 0x12
local CUR_LEVEL   = BUS + 0x10
local ROOM_ID     = BUS + 0xEB
local FRAME_COUNT = BUS + 0x15

local LOG = "C:\\tmp\\boot_check.txt"
local FRAMES = 600   -- ~10 seconds emu time

local function u8(a)
    memory.usememorydomain("M68K BUS")
    return memory.read_u8(a)
end

local fh = io.open(LOG, "w")
if not fh then
    return
end
fh:write("frame,mode,lvl,room,fc\n")

local modes_seen = {}
for f = 1, FRAMES do
    emu.frameadvance()
    if f % 30 == 0 then
        local m, l, r, c = u8(GAME_MODE), u8(CUR_LEVEL), u8(ROOM_ID), u8(FRAME_COUNT)
        fh:write(string.format("%d,$%02X,$%02X,$%02X,$%02X\n", f, m, l, r, c))
        modes_seen[m] = true
    end
end

-- Summary: number of distinct game modes observed.
local n_modes = 0
local mode_list = {}
for m,_ in pairs(modes_seen) do
    n_modes = n_modes + 1
    mode_list[#mode_list+1] = string.format("$%02X", m)
end
table.sort(mode_list)
fh:write(string.format("# modes=%d [%s]\n", n_modes, table.concat(mode_list, ",")))
fh:close()

pcall(function() client.exit() end)
