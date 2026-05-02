-- Phase 5 smoke probe: capture screenshot + CRAM dump after RoomRom boots.
-- Skip the boot frames, advance ~120 frames, save CRAM + a screenshot.

local OUT_PNG  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY-roomrom-s1\\RoomRom\\out\\phase5_ow_orig.png"
local OUT_JSON = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY-roomrom-s1\\RoomRom\\out\\phase5_cram.json"

for _ = 1, 240 do emu.frameadvance() end

local f = io.open(OUT_JSON, "w")
if f then
    f:write("{\"cram\":[")
    memory.usememorydomain("CRAM")
    for i = 0, 127 do
        if i > 0 then f:write(",") end
        f:write(string.format("%d", memory.read_u8(i)))
    end
    f:write("]}")
    f:close()
end

if client and client.screenshot then
    client.screenshot(OUT_PNG)
end

if client and client.exit then client.exit() end
