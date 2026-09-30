-- Q1 room $34: bump secret Armos statue at $40,$80 from below.
-- Debug navigation selects the natural room. Only Link position is staged.
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
    local seen = {}
    for s = 1, 11 do
        if nr(0x34F + s) == 0x1E then
            seen[#seen+1] = string.format("%d:%02X,%02X:%02X", s,
                nr(0x70 + s), nr(0x84 + s), nr(0x28 + s))
        end
    end
    out:write(string.format("%03d mode=%02X room=%02X link=%02X,%02X coll=%02X statue_tl=%02X armos=%s flag=%02X\n",
        t, nr(0x12), nr(0xEB), nr(0x70), nr(0x84), nr(0x49E),
        nr(0x6530 + 8 * 22 + 8), table.concat(seen, ","), nr(0x67F + 0x34)))
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
press({X=true}, 8)
for _ = 1, 64 do
    local room = nr(0xEB)
    if room == 0x34 then break end
    local col, row = room & 0x0F, room >> 4
    if col < 4 then press({Right=true}, 16)
    elseif col > 4 then press({Left=true}, 16)
    elseif row < 3 then press({Down=true}, 16)
    else press({Up=true}, 16) end
end
press({X=true}, 8)
step(30)
if nr(0xEB) ~= 0x34 then
    out:write(string.format("FAIL room=%02X\n", nr(0xEB)))
    out:close(); client.exit(); return
end
snap(0)
nw(0x70, 0x40); nw(0x84, 0x8D); nw(0x98, 0x08); nw(0x394, 0)
memory.write_u16_be(players, 0x40, "68K RAM")
memory.write_u16_be(players + 2, 0x8D, "68K RAM")
memory.write_u8(players + 6, 0x08, "68K RAM")
memory.write_u8(players + 7, 1, "68K RAM")
memory.write_u8(players + 13, 0, "68K RAM")
memory.write_u32_be(link_dir, 2, "68K RAM")
memory.write_u8(link_grid, 0, "68K RAM")
snap(1)
for t = 2, 101 do
    step(1, {Up=true})
    if t <= 12 or t % 5 == 0 then snap(t) end
end
out:close()
client.exit()
