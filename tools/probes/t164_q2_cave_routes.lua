-- T-164: armed debug Q2 entry, then read the installed OW selector sweep.
-- Static blob and installed SRAM differ in Q2; cave routing must use SRAM.
local function r(a) return memory.read_u8(a, "68K RAM") end
local function bus(a, v) memory.write_u8(a, v, "M68K BUS") end
client.reboot_core()
for _ = 1, 30 do emu.frameadvance() end
local ready = false
for frame = 1, 1500 do
    bus(0xFF73F8, 0x52); bus(0xFF73F9, 0x50); bus(0xFF73FA, 0x08)
    joypad.set((frame % 30 < 4) and {X=true, Y=true, Z=true} or {}, 1)
    emu.frameadvance()
    if r(0x7C00) == 0x57 and r(0x7C01) == 0x52 then ready = true; break end
end
local out = assert(io.open("@OUT@", "w"))
if not ready then out:write("ERROR no warp probe publication\n"); out:close(); client.exit(); return end
-- Debug-entry quest selection lives in native state; the NES mirror's
-- $062D byte is not the selection oracle here. Installed Q2 bytes are.
out:write(string.format("quest_mirror=%02X mode=%02X\n", r(0x862D), r(0x8012)))
local expected = {
    [0x0E]={0x7B,0x78}, [0x0F]={0x83,0x7A},
    [0x22]={0x84,0x7B}, [0x34]={0x0F,0x00},
    [0x74]={0x7A,0x78},
}
local failed = false
for _, room in ipairs({0x0E,0x0F,0x22,0x34,0x74}) do
    local raw = r(0x7C00 + 264 + room)
    local xor = r(0x7C00 + 136 + room)
    local installed = raw ~ xor
    local cave = r(0x7C00 + 8 + room)
    local want = expected[room]
    local ok = installed == want[1] and cave == want[2]
    failed = failed or not ok
    out:write(string.format("room=%02X blob=%02X installed=%02X cave=%02X expected=%02X/%02X %s\n",
        room, raw, installed, cave, want[1], want[2], ok and "PASS" or "FAIL"))
end
out:write(failed and "FAIL\n" or "PASS\n")
out:close()
client.exit()
