-- Quick readback: spawn Goriya, read back slot 1 type after settled,
-- dump CHR + palette state. Write to file then exit.

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

local f = io.open("C:/tmp/readback.txt", "w")
f:write("# slot 1-3 state after spawn\n")
for s = 1, 11 do
    f:write(string.format("s%d T:$%02X X:$%02X Y:$%02X St:$%02X Q:$%02X\n",
        s, R(0x834F+s), R(0x8070+s), R(0x8084+s), R(0x80AC+s), R(0x83BC+s)))
end
f:write("\n# probe arm state\n")
f:write(string.format("$FF77D0=%02X $FF77D2=%02X\n", R(0x77D0), R(0x77D2)))
f:close()

client.screenshot("C:/tmp/readback.png")
client.exit()
