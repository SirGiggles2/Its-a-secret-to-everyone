-- T-054: Quest 2 room $74 natural $24 pad -> cave $78.
-- Only Link is positioned on the naturally rendered tile; tile map is untouched.
local player = tonumber("@SYM:players@")
local in_gameplay = tonumber("@SYM:s_in_gameplay@") - 0xFF0000
local out = assert(io.open("@OUT@", "w"))
local function r(a) return memory.read_u8(a, "68K RAM") end
local function w(a, v) memory.write_u8(a, v, "68K RAM") end
local function nr(a) return r(0x8000 + a) end
local function bus(a, v) memory.write_u8(a, v, "M68K BUS") end
local function step(n, pad)
    for _ = 1, n do joypad.set(pad or {}, 1); emu.frameadvance() end
end
local function press(pad, n) step(n, pad); step(1) end
client.reboot_core()
step(30)
local ready = false
for f = 1, 1500 do
    step(1, (f % 30 < 4) and {X=true, Y=true, Z=true} or {})
    if r(in_gameplay) == 1 then ready = true; break end
end
if not ready then out:write("FAIL boot\n"); out:close(); client.exit(); return end
step(60)
press({X=true}, 8)
for _ = 1, 64 do
    local room = nr(0xEB)
    if room == 0x74 then break end
    local col, row = room & 0x0F, room >> 4
    if col > 4 then press({Left=true}, 16)
    elseif col < 4 then press({Right=true}, 16)
    elseif row > 7 then press({Up=true}, 16)
    else press({Down=true}, 16) end
end
press({X=true}, 8)
step(30)
if nr(0xEB) ~= 0x74 or nr(0x69FE+0x74) ~= 0x5A then
    out:write(string.format("FAIL room=%02X attrD=%02X\n", nr(0xEB), nr(0x69FE+0x74)))
    out:close(); client.exit(); return
end
bus(player, 0); bus(player+1, 0x70)
bus(player+2, 0); bus(player+3, 0x4D)
w(0x8000+0x70, 0x70); w(0x8000+0x84, 0x4D)
w(0x8000+0x394, 0)
out:write(string.format("before mode=%02X room=%02X x=%02X y=%02X tile=%02X\n",
    nr(0x12), nr(0xEB), nr(0x70), nr(0x84), nr(0x6530+14*22+3)))
step(1)
out:write(string.format("trigger mode=%02X room=%02X tile=%02X\n",
    nr(0x12), nr(0xEB), nr(0x7FD)))
local entered = false
for _ = 1, 300 do
    if nr(0x12) == 0x0B and nr(0x350) == 0x78 then entered = true; break end
    step(1)
end
out:write(string.format("entered=%s mode=%02X cave=%02X room=%02X\n",
    tostring(entered), nr(0x12), nr(0x350), nr(0xEB)))
client.screenshot("@SHOT@")
out:close()
client.exit()
