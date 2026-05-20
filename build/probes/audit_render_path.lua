-- Trace enemy_render path: read sentinels + s_enemy_count latch state.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

W(0x77D0, 0x46) W(0x77D1, 0x58)
W(0x77D2, 0x05) W(0x77D3, 0x80) W(0x77D4, 0x78)
W(0x77D5, 0x01) W(0x77D6, 0x01) W(0x77D7, 0x00) W(0x77D8, 0x77)
emu.frameadvance()
idle(20)

local f = io.open("C:/tmp/audit_render_path.txt", "w")
-- Sentinel $07FE: incremented by enemy_render_native_sweep per frame.
-- If 0, sweep never fired. If positive, sweep is running.
f:write(string.format("# Sentinel $07FE (enemy_render_native_sweep counter) = $%02X\n",
    R(0x87FE)))

-- NES OAM mirror: dump first few entries at the SpriteOffsets positions.
f:write("\n# NES OAM at SpriteOffsets positions (0x60, 0xBC, 0x64, 0xB8 ...)\n")
local sprite_offsets = {0x60, 0xBC, 0x64, 0xB8, 0x68, 0xB4, 0x6C, 0xB0}
for _, o in ipairs(sprite_offsets) do
    local y = R(0x8200 + o)
    local t = R(0x8200 + o + 1)
    local a = R(0x8200 + o + 2)
    local x = R(0x8200 + o + 3)
    f:write(string.format("  OAM[$%02X] Y=$%02X T=$%02X A=$%02X X=$%02X\n", o, y, t, a, x))
end

-- The s_enemy_entries cache is C-side static memory. Hard to read from
-- Lua. Use the sentinel + OAM evidence.

-- Also dump entire NES OAM mirror non-empty entries.
f:write("\n# All NES OAM non-empty entries:\n")
for s = 0, 63 do
    local y = R(0x8200 + s*4)
    local t = R(0x8200 + s*4 + 1)
    local a = R(0x8200 + s*4 + 2)
    local x = R(0x8200 + s*4 + 3)
    if y ~= 0xF8 and y ~= 0 and not (y == 0 and t == 0 and a == 0 and x == 0) then
        f:write(string.format("  oam[%02d] Y=$%02X T=$%02X A=$%02X X=$%02X\n", s, y, t, a, x))
    end
end

-- Tick a few more frames to observe sentinel growth.
idle(3)
f:write(string.format("\n# Sentinel after 3 more frames = $%02X\n", R(0x87FE)))

idle(60)
f:write(string.format("# Sentinel after 60 more frames = $%02X\n", R(0x87FE)))

f:close()
client.exit()
