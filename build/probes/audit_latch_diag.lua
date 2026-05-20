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

local f = io.open("C:/tmp/audit_latch_diag.txt", "w")
f:write(string.format("Sentinel $07FE = $%02X (sweep counter)\n", R(0x87FE)))
f:write(string.format("s_enemy_count[1]      $07E0 = $%02X\n", R(0x87E0)))
f:write(string.format("entries[1][0].tile    $07E1 = $%02X\n", R(0x87E1)))
f:write(string.format("entries[1][1].tile    $07E2 = $%02X\n", R(0x87E2)))
f:write(string.format("entries[1][2].tile    $07E3 = $%02X\n", R(0x87E3)))
f:write(string.format("entries[1][3].tile    $07E4 = $%02X\n", R(0x87E4)))
local tlo = R(0x87E5)
local thi = R(0x87E6)
f:write(string.format("translate result LSB/MSB = $%02X $%02X = %d\n", tlo, thi, (thi*256)+tlo))
f:write(string.format("s_enemy_count[11]     $07E7 = $%02X\n", R(0x87E7)))
f:write(string.format("total latch count     $07EA = $%02X\n", R(0x87EA)))
f:write(string.format("publish call counter  $07ED = $%02X\n", R(0x87ED)))
f:write(string.format("last cur_slot         $07EC = $%02X\n", R(0x87EC)))
f:write(string.format("last tile             $07EB = $%02X\n", R(0x87EB)))
f:close()
client.exit()
