local OUT_PATH = os.getenv("DEBUG_BOOT_SCREENSHOT")
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\reports\\debug\\boot.png"
local PRESS_C_AFTER_BOOT = os.getenv("DEBUG_PRESS_C") == "1"

local function mkdir_for(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir then
        os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"')
    end
end

for _ = 1, 120 do
    emu.frameadvance()
end

if PRESS_C_AFTER_BOOT then
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
