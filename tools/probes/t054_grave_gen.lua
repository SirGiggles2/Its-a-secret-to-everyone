-- Q1/$21 or Q2/$20 grave push. Debug navigation selects room only;
-- no tile, object, room flag, inventory, or quest cell is injected.
local target = tonumber("@ROOM@")
local quest = tonumber("@QUEST@")
local obj_x = tonumber("@X@")
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
    out:write(string.format("%03d mode=%02X room=%02X link=%02X,%02X obj=%02X,%02X,%02X state=%02X grid=%02X flag=%02X entrance=%02X slot=%02X questnum=%02X\n",
        t, nr(0x12), nr(0xEB), nr(0x70), nr(0x84), nr(0x35A), nr(0x7B), nr(0x8F),
        nr(0xB7), nr(0x39F), nr(0x67F + target), nr(0x65), nr(0x16),
        nr(0x62D + nr(0x16))))
end
client.reboot_core()
step(30)
local ready = false
for f = 1, 1500 do
    local chord = (quest == 2) and {X=true, Y=true, Z=true} or {A=true, B=true, C=true}
    step(1, (f % 30 < 4) and chord or {})
    if r(ready_addr) == 1 then ready = true; break end
end
if not ready then out:write("FAIL boot\n"); out:close(); client.exit(); return end
step(60)
press({X=true}, 8)
for _ = 1, 64 do
    local room = nr(0xEB)
    if room == target then break end
    local col, row = room & 0x0F, room >> 4
    local tc, tr = target & 0x0F, target >> 4
    if col > tc then press({Left=true}, 16)
    elseif col < tc then press({Right=true}, 16)
    elseif row < tr then press({Down=true}, 16)
    else press({Up=true}, 16) end
end
press({X=true}, 8)
step(30)
if nr(0xEB) ~= target or nr(0x35A) ~= 0x65 or nr(0x7B) ~= obj_x then
    out:write(string.format("FAIL room/object %02X/%02X\n", nr(0xEB), nr(0x35A)))
    out:close(); client.exit(); return
end
snap(0)
nw(0x70, obj_x); nw(0x84, 0x9D); nw(0x98, 0x08); nw(0x394, 0)
memory.write_u16_be(players, obj_x, "68K RAM")
memory.write_u16_be(players + 2, 0x9D, "68K RAM")
memory.write_u8(players + 6, 0x08, "68K RAM")
memory.write_u8(players + 7, 1, "68K RAM")
memory.write_u8(players + 13, 0, "68K RAM")
memory.write_u32_be(link_dir, 2, "68K RAM")
memory.write_u8(link_grid, 0, "68K RAM")
snap(1)
for t = 2, 81 do
    step(1, {Up=true})
    if t <= 12 or t % 5 == 0 or nr(0x12) ~= 5 then snap(t) end
    if t == 40 then
        local raw = assert(io.open("@RAW@", "wb"))
        for c = 0, 31 do
            for row = 0, 21 do raw:write(string.char(nr(0x6530 + c * 22 + row))) end
        end
        raw:close()
        client.screenshot("@SHOT@")
        -- First approach crossed Y=$8D before the stair was revealed.
        -- Approach again after the real push/reveal; leave tiles and flag intact.
        nw(0x70, obj_x); nw(0x84, 0x9D); nw(0x98, 0x08); nw(0x394, 0)
        memory.write_u16_be(players, obj_x, "68K RAM")
        memory.write_u16_be(players + 2, 0x9D, "68K RAM")
        memory.write_u8(players + 6, 0x08, "68K RAM")
        memory.write_u8(players + 7, 1, "68K RAM")
        memory.write_u8(players + 13, 0, "68K RAM")
        memory.write_u32_be(link_dir, 2, "68K RAM")
        memory.write_u8(link_grid, 0, "68K RAM")
        out:write("reapproach after reveal\n")
        snap(t)
    end
end
out:close()
client.exit()
