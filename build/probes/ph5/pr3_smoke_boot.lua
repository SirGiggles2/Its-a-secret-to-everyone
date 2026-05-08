-- pr3_smoke_boot.lua
-- Smoke test: boot CombinedDebug, drop into RoomRom UW, capture
-- screenshot at frame 200. Verify no crash + flame-tile region not
-- glitched (atlas regions still rendering OK after PR-3 expansion).

local OUT_DIR = "C:\\tmp\\pr3_smoke_boot"
os.execute("mkdir " .. OUT_DIR .. " 2>nul")

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then memory.usememorydomain("Main RAM") end
end

local fcount = 0
while fcount < 250 do
    local input = {}
    -- A+B+C chord 60..80 to drop into RoomRom UW.
    if fcount >= 60 and fcount < 80 then
        input.A = true; input.B = true; input.C = true
    end
    joypad.set(input, 1)
    if fcount == 90 then
        client.screenshot(OUT_DIR .. "\\post_boot.png")
        print("[smoke] post_boot screenshot")
    end
    if fcount == 200 then
        client.screenshot(OUT_DIR .. "\\stable.png")
        print("[smoke] stable screenshot")
    end
    fcount = fcount + 1
    emu.frameadvance()
end

print("[smoke] DONE -> " .. OUT_DIR)
client.exit()
