-- T-054: inspect a naturally loaded Quest 2 overworld room before/after
-- the installed-LevelBlock renderer correction. Private debug warp only
-- selects the room; no tiles, flags, or objects are staged.
local target = tonumber("@TARGET@")
local in_gameplay = tonumber("@SYM:s_in_gameplay@") - 0xFF0000
local raw_tiles = tonumber("@SYM:s_raw_tiles@") - 0xFF0000
local out = assert(io.open("@OUT@", "w"))
local function r(a) return memory.read_u8(a, "68K RAM") end
local function nr(a) return r(0x8000 + a) end
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
local room = nr(0xEB)
out:write(string.format("room=%02X mode=%02X attrs=%02X,%02X,%02X object=%02X,%02X,%02X\n",
    room, nr(0x12), nr(0x687E+room), nr(0x68FE+room), nr(0x69FE+room),
    nr(0x35A), nr(0x7B), nr(0x8F)))
local raw = assert(io.open("@RAW@", "wb"))
for i = 0, 703 do raw:write(string.char(r(raw_tiles+i))) end
raw:close()
local vram_bytes = memory.read_bytes_as_array(0, 65536, "VRAM")
local vram = assert(io.open("@VRAM@", "wb"))
for i = 1, 65536, 256 do
    local chunk = {}
    for j = i, i + 255 do chunk[#chunk + 1] = string.char(vram_bytes[j]) end
    vram:write(table.concat(chunk))
end
vram:close()
client.screenshot("@SHOT@")
out:close()
client.exit()
