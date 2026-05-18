-- A1 RNG parity gate — NES side.
-- Captures Random[0..12] every frame for 600 frames starting from a
-- known seed. Output: C:\tmp\rng_parity_nes.txt
--
-- NES ScrambleRandom (Z_07.asm:499) fires once per NMI unconditionally.
-- ClearRam (Z_05.asm:7411) seeds Random[0]=$40 / Random[1..12]=$00 at
-- RunGame entry before NMI is enabled.

local function R(o) return memory.read_u8(o, "RAM") end
local function W(o, v) memory.write_u8(o, v, "RAM") end

-- Wait past boot so NMI is enabled and ScrambleRandom is firing.
for _ = 1, 240 do emu.frameadvance() end

-- Force-poke seed to deterministic state.
W(0x0018, 0x40)
for i = 1, 12 do W(0x0018 + i, 0x00) end

-- One frame to let any pending NMI complete before logging.
emu.frameadvance()

local f = io.open("C:/tmp/rng_parity_nes.txt", "w")
f:write("# NES rng parity capture | frame Random[0..12]\n")
for fr = 0, 599 do
    f:write(string.format(
        "%4d %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X\n",
        fr,
        R(0x0018), R(0x0019), R(0x001A), R(0x001B), R(0x001C),
        R(0x001D), R(0x001E), R(0x001F), R(0x0020), R(0x0021),
        R(0x0022), R(0x0023), R(0x0024)))
    emu.frameadvance()
end
f:close()
client.exit()
