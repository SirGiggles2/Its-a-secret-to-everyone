-- T-164: money-game minimum stake and win/loss after OW entry.
local player = tonumber("@SYM:players@")
local cave_id = tonumber("@CAVE_ID@")
local ow_room = tonumber("@OW_ROOM@")
local outcome = "@OUTCOME@"
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
for i = 0, 2 do
    local a = nr(0x448+i)
    local win = a == 0x14 or a == 0x32
    if (outcome == "win") == win then ware_idx = i; break end
end
if not ware_idx then out:write("FAIL no outcome\n"); out:close(); client.exit(); return end
local amount = nr(0x448+ware_idx)
out:write(string.format("outcome=%s amounts=%02X,%02X,%02X choice=%d\n",
    outcome, nr(0x448), nr(0x449), nr(0x44A), ware_idx))
nw(0xAC, 0); pos(0x58 + ware_idx*0x20, 0x98); nw(0x394, 0)
nw(0x66D, 9)
step(3)
out:write(string.format("under_min state=%02X rupees=%02X add=%02X sub=%02X\n",
    nr(0xAD), nr(0x66D), nr(0x67D), nr(0x67E)))
local low_ok = nr(0xAD) == 5 and nr(0x66D) == 9 and nr(0x67D) == 0 and nr(0x67E) == 0
local stake = outcome == "win" and 10 or 100
nw(0x66D, stake)
step(3)
out:write(string.format("played state=%02X rupees=%02X add=%02X sub=%02X\n",
    nr(0xAD), nr(0x66D), nr(0x67D), nr(0x67E)))
local played = nr(0xAD) == 8
for _ = 1, 400 do if nr(0x67D) == 0 and nr(0x67E) == 0 then break end; step(1) end
local expected = outcome == "win" and stake + amount or stake - amount
out:write(string.format("settled rupees=%02X expected=%02X add=%02X sub=%02X %s\n",
    nr(0x66D), expected, nr(0x67D), nr(0x67E),
    low_ok and played and nr(0x66D) == expected and "PASS" or "FAIL"))
out:close()
client.exit()
