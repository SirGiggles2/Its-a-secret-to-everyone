-- T-164: NES Mode C stair oracle. File seed is the existing lockstep
-- t011 preset; Mode 10 cave setup and stair position are disclosed fixtures.
dofile("@PRESET@")
local stair_x = tonumber("@STAIR_X@")
local out = assert(io.open("@OUT@", "w"))
local function r(a) return memory.read_u8(a, "RAM") end
local function w(a, v) memory.write_u8(a, v, "RAM") end
local function step(n, pad)
    for _ = 1, n do joypad.set(pad or {}, 1); emu.frameadvance() end
end
client.reboot_core()
step(1)
local domains = {}
for _, d in ipairs(memory.getmemorydomainlist()) do domains[d] = true end
local save = domains["Battery RAM"] and "Battery RAM" or
             domains["WRAM"] and "WRAM" or "System Bus"
for a, b in pairs(PRESET.nes_wram) do
    memory.write_u8(save == "System Bus" and a or a - 0x6000, b, save)
end
step(120); step(6, {Start=true}); step(120); step(6, {Start=true})
local ready = false
for _ = 1, 1500 do
    if r(0x12) == 0x05 and r(0xEB) ~= 0 then ready = true; break end
    step(1)
end
if not ready then out:write("FAIL boot\n"); out:close(); client.exit(); return end
step(20)
-- HandleWarpOW already selected Mode C from room $1D's attr $50.
-- $70 collision tile makes Mode 10 enter without an unseeded stair anim.
w(0x10, 0); w(0xEB, 0x1D); w(0x49E, 0x70)
w(0x65, 0x24); w(0x5B, 0x0C); w(0x12, 0x10); w(0x13, 0)
local entered = false
for _ = 1, 240 do
    step(1)
    if r(0x12) == 0x0C and r(0x350) == 0x6E and r(0x13) == 0 then
        entered = true; break
    end
end
if not entered then
    out:write(string.format("FAIL entry mode=%02X cave=%02X\n", r(0x12), r(0x350)))
    out:close(); client.exit(); return
end
step(120)
local rooms = {}
for i = 0, 3 do rooms[i+1] = memory.read_u8(0x6BB2+i, "System Bus") end
out:write(string.format("mode=%02X cave=%02X source=%02X array=%02X,%02X,%02X,%02X\n",
    r(0x12), r(0x350), r(0xEB), rooms[1], rooms[2], rooms[3], rooms[4]))
w(0xAC, 0); w(0x70, stair_x); w(0x84, 0x9D); w(0x394, 0); w(0x98, 8)
step(1, {Up=true})
out:write(string.format("stair_frame mode=%02X room=%02X x=%02X y=%02X grid=%02X\n",
    r(0x12), r(0xEB), r(0x70), r(0x84), r(0x394)))
local offset = stair_x == 0x50 and 1 or stair_x == 0x80 and 2 or 3
local expected = rooms[offset + 1]
for _ = 1, 220 do
    if r(0x12) == 0x05 and r(0xEB) == expected then break end
    step(1)
end
local ok = r(0x12) == 0x05 and r(0xEB) == expected
out:write(string.format("exit mode=%02X room=%02X x=%02X y=%02X expected=%02X %s\n",
    r(0x12), r(0xEB), r(0x70), r(0x84), expected, ok and "PASS" or "FAIL"))
out:close()
client.exit()
