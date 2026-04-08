-- Native scroll driver verification probe
-- Captures screenshots at key frames across story scroll, item scroll, and hold
local BASE = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/native_scroll/"

-- Key frames to capture:
-- ~850:  Phase 0->1 transition, story scroll starts
-- ~1100: Story scroll mid - "THE LEGEND OF ZELDA" visible
-- ~1300: Story scroll - full text visible
-- ~1600: Story->item transition (subphase 1 wait)
-- ~1900: Item scroll beginning - "ALL OF TREASURES" header
-- ~2200: Item scroll - HEART/CONTAINER HEART with sprites
-- ~2560: Item scroll - mid danger zone (curV $C0-$EF)
-- ~2800: Item scroll - later items
-- ~3200: Item scroll - near end
-- ~3500: Hold phase

local frames = {850, 1100, 1300, 1600, 1900, 2200, 2560, 2800, 3200, 3500}

local f_idx = 1
while f_idx <= #frames do
    while emu.framecount() < frames[f_idx] do
        emu.frameadvance()
    end
    local fn = string.format("%sgen_f%05d.png", BASE, frames[f_idx])
    client.screenshot(fn)
    print(string.format("Frame %d saved", frames[f_idx]))
    f_idx = f_idx + 1
end

print("Native scroll probe complete — " .. #frames .. " screenshots")
client.exit()
