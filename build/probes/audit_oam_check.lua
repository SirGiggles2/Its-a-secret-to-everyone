-- Check NES OAM mirror after Goriya spawn.
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
idle(30)

local f = io.open("C:/tmp/audit_oam.txt", "w")
-- NES OAM mirror at $0200..$02FF (64 sprites * 4 bytes each).
-- BizHawk Genesis: NES RAM at $FF8200 = 68K RAM offset $8200.
f:write("# NES OAM mirror ($0200..$02FF) on Genesis\n")
f:write("# 64 sprites x 4 bytes: Y, tile, attr, X\n")
for s = 0, 63 do
    local y = R(0x8200 + s*4 + 0)
    local t = R(0x8200 + s*4 + 1)
    local a = R(0x8200 + s*4 + 2)
    local x = R(0x8200 + s*4 + 3)
    -- Only log if Y is in plausible visible range (not $F8 sentinel for "hidden").
    if y ~= 0xF8 and y ~= 0 then
        f:write(string.format("oam[%2d] Y=$%02X T=$%02X A=$%02X X=$%02X\n", s, y, t, a, x))
    end
end

-- Also dump slot 1 RAM cells
f:write("\n# slot 1 state cells\n")
f:write(string.format("type=$%02X X=$%02X Y=$%02X dir=$%02X qspd=$%02X state=$%02X anim_frame=$%02X anim_cnt=$%02X\n",
    R(0x834F+1), R(0x8070+1), R(0x8084+1), R(0x8098+1),
    R(0x83BC+1), R(0x80AC+1), R(0x83E4+1), R(0x83D0+1)))

-- Check rolling sprite index
f:write(string.format("RollingSpriteIndex ($0341) = %02X\n", R(0x8341)))

f:close()
client.exit()
