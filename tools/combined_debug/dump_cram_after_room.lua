local OUT_PATH = os.getenv("ROOM_CRAM_DUMP")
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\reports\\combined_debug\\room_cram.txt"
local USE_CHORD = os.getenv("ROOM_CRAM_USE_CHORD") == "1"

local function mkdir_for(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir then
        os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"')
    end
end

local function domain_exists(name)
    for _, domain in ipairs(memory.getmemorydomainlist()) do
        if domain == name then return true end
    end
    return false
end

if USE_CHORD then
    local ram_domain = domain_exists("68K RAM") and "68K RAM" or "M68K BUS"
    local ram_base = (ram_domain == "68K RAM") and 0x8000 or 0x00FF8000
    for _ = 1, 120 do emu.frameadvance() end
    for _ = 1, 60 do
        emu.frameadvance()
        memory.usememorydomain(ram_domain)
        if memory.read_u8(ram_base + 0x07F0) == 1 then break end
    end
    for _ = 1, 8 do
        joypad.set({ ["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true })
        emu.frameadvance()
    end
    joypad.set({})
end

for _ = 1, 120 do emu.frameadvance() end

mkdir_for(OUT_PATH)
local f = assert(io.open(OUT_PATH, "w"))
local cram_domain = domain_exists("CRAM") and "CRAM" or nil
f:write("domain=", tostring(cram_domain), "\n")
if cram_domain then
    for row = 0, 3 do
        f:write(string.format("PAL%d:", row))
        for col = 0, 15 do
            local v = memory.read_u16_be((row * 16 + col) * 2, cram_domain)
            f:write(string.format(" %03X", v & 0x0FFF))
        end
        f:write("\n")
    end
end
f:close()
client.exit()
