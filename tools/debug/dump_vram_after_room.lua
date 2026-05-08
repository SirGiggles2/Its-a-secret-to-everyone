local OUT_PATH = os.getenv("ROOM_VRAM_DUMP")
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\reports\\debug\\room_vram.txt"
local USE_CHORD = os.getenv("ROOM_VRAM_USE_CHORD") == "1"
local PRESS_C = os.getenv("ROOM_VRAM_PRESS_C") == "1"

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

local function press(buttons, frames)
    for _ = 1, frames do
        joypad.set(buttons)
        emu.frameadvance()
    end
    joypad.set({})
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
    press({ ["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true }, 8)
end

for _ = 1, 120 do emu.frameadvance() end

if PRESS_C then
    press({ ["P1 C"] = true }, 8)
    for _ = 1, 90 do emu.frameadvance() end
end

mkdir_for(OUT_PATH)
local f = assert(io.open(OUT_PATH, "w"))
local domains = memory.getmemorydomainlist()
f:write("domains=", table.concat(domains, ","), "\n")

local vram_domain = nil
for _, name in ipairs({ "VRAM", "VDP VRAM" }) do
    if domain_exists(name) then
        vram_domain = name
        break
    end
end
f:write("vram_domain=", tostring(vram_domain), "\n")

if vram_domain then
    for _, plane in ipairs({
        { name = "window", base = 0xB000, stride = 32 },
        { name = "bgb", base = 0xC000, stride = 64 },
        { name = "bga", base = 0xE000, stride = 64 },
    }) do
        for row = 0, 6 do
            f:write(string.format("%s_row_%d:", plane.name, row))
            for col = 0, 31 do
                local addr = plane.base + ((row * plane.stride + col) * 2)
                local word = memory.read_u16_be(addr, vram_domain)
                f:write(string.format(" %04X", word))
            end
            f:write("\n")
        end
    end

    for _, raw in ipairs({ 0x00,0x0A,0x0B,0x15,0x21,0x24,0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0x3F,0x40,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,0x4F,0x61,0x62,0x69,0x6A,0x6B,0x6C,0x6D,0x6E,0xF7,0xF9 }) do
        local tile = raw + 1
        local addr = tile * 32
        f:write(string.format("tile_%02X:", raw))
        for i = 0, 31 do
            f:write(string.format(" %02X", memory.read_u8(addr + i, vram_domain)))
        end
        f:write("\n")
    end
end

f:close()
client.exit()
