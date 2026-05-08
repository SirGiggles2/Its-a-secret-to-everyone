local OUT_PATH = os.getenv("DEBUG_ROOM_SCREENSHOT")
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\reports\\debug\\debug_room.png"
local PRESS_C_AFTER_ENTRY = os.getenv("DEBUG_PRESS_C") == "1"

local function mkdir_for(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir then
        os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"')
    end
end

local function domain_exists(name)
    for _, domain in ipairs(memory.getmemorydomainlist()) do
        if domain == name then
            return true
        end
    end
    return false
end

local DOMAIN = "M68K BUS"
local BASE = 0x00FF7000
local RAM_BASE = 0x00FF8000
if domain_exists("68K RAM") then
    DOMAIN = "68K RAM"
    BASE = 0x7000
    RAM_BASE = 0x8000
elseif domain_exists("M68K RAM") then
    DOMAIN = "M68K RAM"
    BASE = 0x7000
    RAM_BASE = 0x8000
end

local function read_domain_u8(addr)
    memory.usememorydomain(DOMAIN)
    return memory.read_u8(addr)
end

local function read_probe_u8(offset)
    return read_domain_u8(BASE + offset)
end

local function read_ram_u8(offset)
    return read_domain_u8(RAM_BASE + offset)
end

for _ = 1, 120 do
    emu.frameadvance()
    if read_probe_u8(0) == 0xA4 and read_probe_u8(1) == 0x4A then
        break
    end
end

for _ = 1, 60 do
    emu.frameadvance()
    if read_ram_u8(0x07F0) == 1 then
        break
    end
end

for _ = 1, 8 do
    joypad.set({ ["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true })
    emu.frameadvance()
end
joypad.set({})

for _ = 1, 90 do
    emu.frameadvance()
end

if PRESS_C_AFTER_ENTRY then
    for _ = 1, 8 do
        joypad.set({ ["P1 C"] = true })
        emu.frameadvance()
    end
    joypad.set({})

    for _ = 1, 90 do
        emu.frameadvance()
    end
end

mkdir_for(OUT_PATH)
client.screenshot(OUT_PATH)
client.exit()
