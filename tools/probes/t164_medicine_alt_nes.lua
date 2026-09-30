-- T-164: NES letter shop's second potion and settled price.
dofile("@PRESET@")
local cave_id = tonumber("@CAVE_ID@")
local ow_room = tonumber("@OW_ROOM@")
local stop_state = tonumber("@STOP_STATE@")
local start_rupees = tonumber("@START_RUPEES@")
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
w(0x66D, start_rupees)
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
if cave_id == 0x74 then
    step(80)
    w(0x666, 1); w(0x656, 0x0F)
    step(8, {B=true}); step(1)
    out:write(string.format("letter_use state=%02X letter=%02X selected=%02X\n",
        r(0xAD), r(0x666), r(0x656)))
end
local reached = false
for _ = 1, 700 do
    if r(0xAD) == stop_state then reached = true; break end
    step(1)
end
out:write(string.format("mode=%02X cave=%02X room=%02X state=%02X flags=%02X wares=%02X,%02X,%02X prices=%02X,%02X,%02X rupees=%02X add=%02X sub=%02X roomflag=%02X letter=%02X selected=%02X reached=%s\n",
    r(0x12), r(0x350), r(0xEB), r(0xAD), r(0x413),
    r(0x422), r(0x423), r(0x424), r(0x430), r(0x431), r(0x432),
    r(0x66D), r(0x67D), r(0x67E), r(0x67F+ow_room),
    r(0x666), r(0x656), tostring(reached)))
if cave_id == 0x74 and reached then
    w(0xAC, 0); w(0x70, 0x98); w(0x84, 0x98); w(0x394, 0)
    w(0x66D, 0); step(3)
    out:write(string.format("potion_reject state=%02X ware=%02X flag=%02X\n",
        r(0xAD), r(0x424), r(0x67F+ow_room)))
    local rejected = r(0xAD) == 2 and r(0x424) == 0xE0 and (r(0x67F+ow_room) & 0x10) == 0
    w(0x66D, 68); step(3)
    out:write(string.format("potion_buy state=%02X ware=%02X flag=%02X potion=%02X debit=%02X\n",
        r(0xAD), r(0x424), r(0x67F+ow_room), r(0x65E), r(0x67E)))
    local bought = r(0x424) == 0xFF and (r(0x67F+ow_room) & 0x10) ~= 0 and r(0x65E) == 2
    for _ = 1, 200 do if r(0x67E) == 0 then break end; step(1) end
    out:write(string.format("potion_settled rupees=%02X debit=%02X %s\n",
        r(0x66D), r(0x67E), rejected and bought and r(0x66D) == 0 and r(0x67E) == 0 and "PASS" or "FAIL"))
end
out:close()
client.exit()
