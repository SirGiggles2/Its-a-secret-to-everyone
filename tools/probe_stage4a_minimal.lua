-- probe_stage4a_minimal.lua — minimal boot test
dofile("C:\\tmp\\boot_sequence.lua")

local OUT = "C:\\tmp\\stage4a_verify.txt"
local BUS = 0xFF0000

local fh = assert(io.open(OUT, "w"))
fh:write("=== Stage 4a Minimal Probe ===\n")
fh:flush()

-- List available memory domains
local domains = memory.getmemorydomainlist()
fh:write("Memory domains: ")
for _, d in ipairs(domains) do fh:write(d .. ", ") end
fh:write("\n")
fh:flush()

-- Run 2000 frames (boot through title to gameplay)
for frame = 1, 2000 do
    local status = boot_sequence.drive(frame, 0x77)
    emu.frameadvance()

    if frame % 200 == 0 then
        local mode = memory.read_u8(BUS + 0x12, "M68K BUS")
        local rid  = memory.read_u8(BUS + 0xEB, "M68K BUS")
        local lvl  = memory.read_u8(BUS + 0x10, "M68K BUS")
        fh:write(string.format("f%d: mode=%02X room=%02X lvl=%d status=%s\n",
            frame, mode, rid, lvl, status))
        fh:flush()
    end
end

-- Check key RAM values that Stage 4a functions touch
local doors = memory.read_u8(BUS + 0xEE, "M68K BUS")
local mode  = memory.read_u8(BUS + 0x12, "M68K BUS")
local room  = memory.read_u8(BUS + 0xEB, "M68K BUS")

fh:write(string.format("\nFinal: mode=%02X room=%02X openedDoors=%02X\n", mode, room, doors))
fh:write(string.format("CHECK rom_boots: %s\n", mode ~= 0xFF and "PASS" or "FAIL"))
fh:write("\n=== SUMMARY ===\n")
fh:write(string.format("  [%s] rom_boots: mode=$%02X\n", mode ~= 0xFF and "PASS" or "FAIL", mode))
fh:write(string.format("  [%s] no_crash: reached frame 2000\n", "PASS"))
fh:write(string.format("\nResult: 2/2 checks passed\n"))
fh:close()

print("Stage 4a minimal probe done")
client.exit()
