-- Diagnostic: is rng_next actually advancing nes_ram[$18..$24] on Gen?
-- No force-poke. Just observe.
local function R(o) return memory.read_u8(o, "68K RAM") end

for _ = 1, 240 do emu.frameadvance() end

local f = io.open("C:/tmp/rng_alive_gen.txt", "w")
f:write("# observe Random[0..12] across 60 frames (no poke)\n")
for fr = 0, 60 do
    f:write(string.format(
        "%3d %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X\n",
        fr,
        R(0x8018), R(0x8019), R(0x801A), R(0x801B), R(0x801C),
        R(0x801D), R(0x801E), R(0x801F), R(0x8020), R(0x8021),
        R(0x8022), R(0x8023), R(0x8024)))
    emu.frameadvance()
end
f:close()
client.exit()
