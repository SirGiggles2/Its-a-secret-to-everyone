-- T-164: acquire a cave flag, then save it through the controller menu.
local player = tonumber("@SYM:players@")
local cave_id = tonumber("@CAVE_ID@")
local ow_room = tonumber("@OW_ROOM@")
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
local target = ow_room
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
    if nr(0x12) == 0x0B and nr(0x350) == cave_id and nr(0x13) == 0 then
        entered = true; break
    end
    step(1)
end
stage_tile(0)
if not entered then
    out:write(string.format("FAIL entry mode=%02X cave=%02X\n", nr(0x12), nr(0x350)))
    out:close(); client.exit(); return
end
local text_done = false
for _ = 1, 600 do
    if nr(0xAD) == 2 then text_done = true; break end
    step(1)
end
out:write(string.format("mode=%02X cave=%02X room=%02X state=%02X flags=%02X wares=%02X,%02X,%02X hearts=%02X rupees=%02X text_done=%s\n",
    nr(0x12), nr(0x350), nr(0xEB), nr(0xAD), nr(0x413),
    nr(0x422), nr(0x423), nr(0x424), nr(0x66F), nr(0x66D), tostring(text_done)))
if not text_done then out:close(); client.exit(); return end
local ware_idx = nil
for i = 0, 2 do if (nr(0x422+i) & 0x3F) ~= 0x3F then ware_idx = i; break end end
if not ware_idx then out:write("FAIL no ware\n"); out:close(); client.exit(); return end
local ware_addr = 0x422 + ware_idx
local item = nr(ware_addr)
local flag_addr = 0x67F + ow_room
local price = nr(0x430 + ware_idx)
nw(0xAC, 0); pos(0x58 + ware_idx*0x20, 0x98); nw(0x394, 0)
nw(0x66D, 0)
step(3)
out:write(string.format("take state=%02X ware=%02X rupees=%02X credit=%02X flag=%02X\n",
    nr(0xAD), nr(ware_addr), nr(0x66D), nr(0x67D), nr(flag_addr)))
local taken = nr(0xAD) == 8 and (nr(flag_addr) & 0x10) ~= 0
for _ = 1, 500 do if nr(0x67D) == 0 then break end; step(1) end
out:write(string.format("settled rupees=%02X credit=%02X\n", nr(0x66D), nr(0x67D)))
out:write(string.format("ware_index=%d item=%02X award=%d %s\n", ware_idx, item, price,
    taken and nr(0x66D) == price and nr(0x67D) == 0 and "PASS" or "FAIL"))
nw(0xAC, 0); pos(0x70, 0xDD); nw(0x394, 0)
out:write(string.format("leave_pre scene=%02X x=%02X y=%02X action=%02X mode_state=%02X phase=%02X\n",
    r(tonumber("@SYM:s_scene@") - 0xFF0000 + 3), nr(0x70), nr(0x84), nr(0xAC),
    r(mode_state+3), r(tonumber("@SYM:s_lvl_phase@") - 0xFF0000)))
step(8, {Down=true})
out:write(string.format("leave mode=%02X room=%02X x=%02X y=%02X action=%02X joy=%02X phase=%02X start_y=%02X\n",
    nr(0x12), nr(0xEB), nr(0x70), nr(0x84), nr(0xAC),
    nr(0x7F0), r(tonumber("@SYM:s_lvl_phase@") - 0xFF0000),
    r(tonumber("@SYM:s_tick_start_link_y@") - 0xFF0000 + 1)))
for _ = 1, 200 do if nr(0x12) == 0x05 and nr(0xEB) == ow_room then break end; step(1) end
out:write(string.format("outside mode=%02X room=%02X flag=%02X\n", nr(0x12), nr(0xEB), nr(flag_addr)))
step(60)
press({Start=true}, 1)
step(70)
out:write(string.format("pause mode=%02X sub=%02X flag=%02X\n", nr(0x12), nr(0x13), nr(flag_addr)))
for _ = 1, 6 do joypad.set({}, 1); joypad.set({Up=true, A=true}, 2); emu.frameadvance() end
joypad.set({}, 2)
step(40)
out:write(string.format("choice mode=%02X sub=%02X flag=%02X\n", nr(0x12), nr(0x13), nr(flag_addr)))
press({C=true}, 1)
step(10)
out:write(string.format("selected mode=%02X sub=%02X flag=%02X\n", nr(0x12), nr(0x13), nr(flag_addr)))
press({Start=true}, 1)
step(90)
local save_flag = nr(0x6092 + ow_room)
out:write(string.format("saved mode=%02X sub=%02X live_flag=%02X save_flag=%02X %s\n",
    nr(0x12), nr(0x13), nr(flag_addr), save_flag,
    (save_flag & 0x10) ~= 0 and "PASS" or "FAIL"))
out:close()
client.exit()
