-- T-164: NES additional paid-hint selection oracle.
dofile("@PRESET@")
local cave_id = tonumber("@CAVE_ID@")
local ow_room = tonumber("@OW_ROOM@")
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
-- $70 collision skips an unseeded Mode 10 stair animation.
w(0x10, 0); w(0xEB, ow_room); w(0x49E, 0x70)
w(0x65, 0x24); w(0x5B, 0x0B); w(0x12, 0x10); w(0x13, 0)
local entered = false
for _ = 1, 240 do
    step(1)
    if r(0x12) == 0x0B and r(0x350) == cave_id and r(0x13) == 0 then
        entered = true; break
    end
end
if not entered then
    out:write(string.format("FAIL entry mode=%02X cave=%02X\n", r(0x12), r(0x350)))
    out:close(); client.exit(); return
end
local text_done = false
for _ = 1, 600 do
    if r(0xAD) == 2 then text_done = true; break end
    step(1)
end
out:write(string.format("mode=%02X cave=%02X room=%02X state=%02X flags=%02X wares=%02X,%02X,%02X hearts=%02X rupees=%02X text_done=%s\n",
    r(0x12), r(0x350), r(0xEB), r(0xAD), r(0x413),
    r(0x422), r(0x423), r(0x424), r(0x66F), r(0x66D), tostring(text_done)))
if not text_done then out:close(); client.exit(); return end
local ware_idx = tonumber("@WARE_INDEX@")
local ware_addr = 0x422 + ware_idx
local item = r(ware_addr)
local flag_addr = 0x67F + ow_room
local price = r(0x430 + ware_idx)
w(0xAC, 0); w(0x70, 0x58 + ware_idx*0x20); w(0x84, 0x98); w(0x394, 0)
w(0x66D, 0)
step(3)
out:write(string.format("reject state=%02X ware=%02X rupees=%02X debit=%02X flag=%02X\n",
    r(0xAD), r(ware_addr), r(0x66D), r(0x67E), r(flag_addr)))
local low_ok = r(0xAD) == 2 and r(ware_addr) == item and r(0x67E) == 0
w(0x66D, price)
step(3)
out:write(string.format("hint state=%02X selector=%02X flags=%02X rupees=%02X debit=%02X flag=%02X\n",
    r(0xAD), r(0x415), r(0x413), r(0x66D), r(0x67E), r(flag_addr)))
local expected_sel = ware_idx == 2 and (cave_id == 0x75 and 0x16 or 0x1A)
    or (cave_id == 0x76 and ware_idx == 1 and 0x18 or 0x14)
local high_ok = r(0x415) == expected_sel and r(ware_addr) == item and (r(0x413) & 0x08) == 0
for _ = 1, 400 do if r(0x67E) == 0 then break end; step(1) end
out:write(string.format("settled rupees=%02X debit=%02X\n", r(0x66D), r(0x67E)))
out:write(string.format("ware_index=%d price=%d selector=%02X %s\n", ware_idx, price, r(0x415),
    low_ok and high_ok and r(0x66D) == 0 and r(0x67E) == 0 and "PASS" or "FAIL"))
out:close()
client.exit()
