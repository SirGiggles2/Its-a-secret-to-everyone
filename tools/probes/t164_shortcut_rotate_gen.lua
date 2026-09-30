-- T-164: Mode C source-room rotation from a real OW cave entry.
-- Navigation/warp setup follows the historical cave golden; the stair
-- position is staged explicitly and therefore proves routing, not a full
-- unassisted movement route.
local player = tonumber("@SYM:players@")
local stair_x = tonumber("@STAIR_X@")
local source_room = tonumber("@OW_ROOM@")
local in_gameplay = tonumber("@SYM:s_in_gameplay@") - 0xFF0000
local mode_state = tonumber("@SYM:s_mode@") - 0xFF0000
local raw_tiles = tonumber("@SYM:s_raw_tiles@") - 0xFF0000
local out = assert(io.open("@OUT@", "w"))
local function r(a) return memory.read_u8(a, "68K RAM") end
local function w(a, v) memory.write_u8(a, v, "68K RAM") end
local function nr(a) return r(0x8000 + a) end
local function nw(a, v) w(0x8000 + a, v) end
local function bus(a, v) memory.write_u8(a, v, "M68K BUS") end
local function step(n, pad)
    for _ = 1, n do joypad.set(pad or {}, 1); emu.frameadvance() end
end
local function press(pad, n) step(n, pad); step(1) end
local function pos(x, y)
    bus(player, 0); bus(player + 1, x)
    bus(player + 2, 0); bus(player + 3, y)
    nw(0x70, x); nw(0x84, y)
end
local function stage_tile(v)
    w(0x8000 + 0x6530 + 15 * 0x16 + 9, v)
    w(raw_tiles + 15 * 22 + 9, v)
end
client.reboot_core()
step(30)
local ready = false
for f = 1, 1500 do
    step(1, (f % 30 < 4) and {A=true, B=true, C=true} or {})
    if r(in_gameplay) == 1 then ready = true; break end
end
if not ready then out:write("FAIL boot\n"); out:close(); client.exit(); return end
step(60)
pos(0x78, 0x70)
press({X=true}, 8)
local target = source_room
for _ = 1, 64 do
    local room = nr(0xEB)
    if room == target then break end
    local col, row = room & 0x0F, room >> 4
    local tc, tr = target & 0x0F, target >> 4
    if col < tc then press({Right=true}, 16)
    elseif col > tc then press({Left=true}, 16)
    elseif row < tr then press({Down=true}, 16)
    else press({Up=true}, 16) end
end
press({X=true}, 8)
step(30)
out:write(string.format("ow_room=%02X selector=%02X\n", nr(0xEB), nr(0x68FE + nr(0xEB)) & 0xFC))
stage_tile(0x24)
pos(0x78, 0x7D)
for a = mode_state, mode_state + 3 do w(a, 0) end
out:write(string.format("armed scene=%02X raw=%02X ram=%02X x=%02X y=%02X\n",
    r(tonumber("@SYM:s_scene@") - 0xFF0000), r(raw_tiles + 15*22+9),
    nr(0x6530 + 15*22+9), r((player - 0xFF0000)+1),
    r((player - 0xFF0000)+3)))
step(1)
out:write(string.format("after_trigger mode=%02X cave=%02X sentinel=%02X x=%02X y=%02X\n",
    nr(0x12), nr(0x350), nr(0x7FC), nr(0x70), nr(0x84)))
out:write(string.format("state lvl_phase=%02X mode_state=%02X style=%02X tile=%02X room=%02X\n",
    r(tonumber("@SYM:s_lvl_phase@") - 0xFF0000), r(mode_state+3),
    r(tonumber("@SYM:s_move_style@") - 0xFF0000 + 3), nr(0x7FD), nr(0xEB)))
local entered = false
for _ = 1, 450 do
    if nr(0x12) == 0x0C and nr(0x350) == 0x6E and nr(0x13) == 0 then
        entered = true; break
    end
    step(1)
end
stage_tile(0)
if not entered then
    out:write(string.format("FAIL entry mode=%02X cave=%02X\n", nr(0x12), nr(0x350)))
    out:close(); client.exit(); return
end
step(120)
local rooms = {}
for i = 0, 3 do rooms[i+1] = nr(0x6BB2+i) end
out:write(string.format("mode=%02X cave=%02X source=%02X array=%02X,%02X,%02X,%02X\n",
    nr(0x12), nr(0x350), nr(0xEB), rooms[1], rooms[2], rooms[3], rooms[4]))
local source_index = nil
for i = 1, 4 do if rooms[i] == source_room then source_index = i; break end end
if not source_index then out:write("FAIL source absent\n"); out:close(); client.exit(); return end
local offset = stair_x == 0x50 and 1 or stair_x == 0x80 and 2 or 3
local expected = rooms[((source_index - 1 + offset) % 4) + 1]
nw(0xAC, 0)  -- explicit stair fixture: cave-person halt already observed
pos(stair_x, 0x9D)
out:write(string.format("pre_stair mode=%02X x=%02X y=%02X grid=%02X\n",
    nr(0x12), nr(0x70), nr(0x84), nr(0x394)))
step(1, {Up=true})
out:write(string.format("stair_frame mode=%02X room=%02X x=%02X y=%02X grid=%02X expected=%02X\n",
    nr(0x12), nr(0xEB), nr(0x70), nr(0x84), nr(0x394), expected))
for _ = 1, 180 do
    if nr(0x12) == 0x05 and nr(0xEB) == expected then break end
    step(1)
end
local ok = nr(0x12) == 0x05 and nr(0xEB) == expected
out:write(string.format("exit mode=%02X room=%02X x=%02X y=%02X %s\n",
    nr(0x12), nr(0xEB), nr(0x70), nr(0x84), ok and "PASS" or "FAIL"))
out:close()
client.exit()
