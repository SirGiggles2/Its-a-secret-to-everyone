-- L1Q1 room $42: clear-room gate, then push the $68 block upward.
-- Debug navigation loads the real room; only Link position and all-dead
-- gate are staged, as in the paired focused NES fixture.
local ready_addr = tonumber("@SYM:s_in_gameplay@") - 0xFF0000
local players = tonumber("@SYM:players@") - 0xFF0000
local link_dir = tonumber("@SYM:s_link_dir@") - 0xFF0000
local link_grid = tonumber("@SYM:s_link_grid_offset@") - 0xFF0000
local out = assert(io.open("@OUT@", "w"))
local function r(a) return memory.read_u8(a, "68K RAM") end
local function nr(a) return r(0x8000 + a) end
local function nw(a, v) memory.write_u8(0x8000 + a, v, "68K RAM") end
local function step(n, pad)
    for _ = 1, n do joypad.set(pad or {}, 1); emu.frameadvance() end
end
local function press(pad, n) step(n, pad); step(1) end
local function snap(t)
    out:write(string.format("%03d mode=%02X lvl=%02X room=%02X link=%02X,%02X block=%02X:%02X,%02X state=%02X off=%02X allDead=%02X complete=%02X secret=%02X shutter=%02X opened=%02X\n",
        t, nr(0x12), nr(0x10), nr(0xEB), nr(0x70), nr(0x84),
        nr(0x35A), nr(0x7B), nr(0x8F), nr(0xB7), nr(0x39F),
        nr(0x34D), nr(0x4CF), nr(0x4CD), nr(0x4CE), nr(0xEE)))
end
client.reboot_core()
step(30)
local ready = false
for f = 1, 1500 do
    step(1, (f % 30 < 4) and {A=true, B=true, C=true} or {})
    if r(ready_addr) == 1 then ready = true; break end
end
if not ready then out:write("FAIL boot\n"); out:close(); client.exit(); return end
step(60)
press({Mode=true}, 4)
step(60)
press({X=true}, 8)
for _ = 1, 64 do
    local room = nr(0xEB)
    if room == 0x42 then break end
    local col, row = room & 0x0F, room >> 4
    if col < 2 then press({Right=true}, 16)
    elseif col > 2 then press({Left=true}, 16)
    elseif row < 4 then press({Down=true}, 16)
    else press({Up=true}, 16) end
end
press({X=true}, 8)
step(30)
if nr(0xEB) ~= 0x42 or nr(0x10) ~= 1 then
    out:write(string.format("FAIL room=%02X lvl=%02X\n", nr(0xEB), nr(0x10)))
    out:close(); client.exit(); return
end
snap(0)
nw(0x70, 0x70); nw(0x84, 0x9D); nw(0x98, 0x08); nw(0x394, 0)
nw(0x34D, 1)
memory.write_u16_be(players, 0x70, "68K RAM")
memory.write_u16_be(players + 2, 0x9D, "68K RAM")
memory.write_u8(players + 6, 0x08, "68K RAM")
memory.write_u8(players + 7, 1, "68K RAM")
memory.write_u8(players + 13, 0, "68K RAM")
memory.write_u32_be(link_dir, 2, "68K RAM")
memory.write_u8(link_grid, 0, "68K RAM")
snap(1)
for t = 2, 81 do
    step(1, {Up=true})
    if t <= 10 or t % 5 == 0 then snap(t) end
end
out:close()
client.exit()
