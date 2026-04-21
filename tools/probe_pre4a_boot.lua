-- probe_pre4a_boot.lua — boot test on pre-Stage4a ROM
local BUS = 0xFF0000
local DOM = "M68K BUS"
local OUT = "C:\\tmp\\pre4a_boot.txt"
local function u8(a) return memory.read_u8(a, DOM) end

local fh = assert(io.open(OUT, "w"))
fh:write("=== Pre-4a Boot Test ===\n")
fh:flush()

for frame = 1, 2000 do
    local mode = u8(BUS + 0x12)
    local rid  = u8(BUS + 0xEB)

    if frame % 30 >= 0 and frame % 30 <= 4 then
        joypad.set({ Start = true, ["P1 Start"] = true }, 1)
    else
        joypad.set({}, 1)
    end

    emu.frameadvance()

    if frame % 100 == 0 then
        fh:write(string.format("f%d: mode=%02X room=%02X\n", frame, mode, rid))
        fh:flush()
    end
end

fh:write("\n=== SUMMARY ===\n")
fh:write(string.format("Final mode=%02X\n", u8(BUS + 0x12)))
fh:close()
client.exit()
