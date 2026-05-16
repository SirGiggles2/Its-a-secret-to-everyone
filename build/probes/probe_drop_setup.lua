-- probe_drop_setup.lua — verify SetUpDroppedItem port.
-- Kill an enemy via stress harness or A-button sword swing, then sweep
-- enemy slots over 300 frames and confirm:
--   * any slot transitioning to TYPE=$60 either gets META_ITEM_LIFETIME=$FF
--     (committed drop) OR clears completely (ALIVE_FLAG=0, no-drop type).
--   * no slot stays stuck at TYPE=$60 with LIFETIME=0 forever.
--
-- Output: C:\tmp\probe_drop_setup.txt + screenshot.

local OUT = "C:\\tmp\\probe_drop_setup.txt"
local SHOT = "C:\\tmp\\probe_drop_setup.png"

local function R(off) return memory.read_u8(0x8000 + off, "68K RAM") end
local function idle(n)
    for _=1,n do emu.frameadvance() end
end
local function press(b, n)
    for _=1,n do joypad.set(b, 1); emu.frameadvance() end
end

-- Boot + stress harness ARM (writes magic to $73FC/$73FD per CLAUDE.md).
idle(60)
memory.write_u8(0x73FC, 0x45, "68K RAM")
memory.write_u8(0x73FD, 0x50, "68K RAM")
idle(60)
press({A=true,B=true,C=true}, 30)
idle(60)

-- Snapshot enemy slots 1..11 every 30 frames for 10 windows = 300 frames.
local windows = {}
for w=1,10 do
    press({A=true}, 4)  -- repeat sword swings to kill stressed enemies
    idle(26)
    local snap = {}
    for slot=1,11 do
        snap[slot] = {
            alive     = R(0x0492 + slot),
            type      = R(0x034F + slot),
            metastate = R(0x0405 + slot),
            lifetime  = R(0x03A8 + slot),
            item_id   = R(0x00AC + slot),
        }
    end
    windows[w] = snap
end

local f = io.open(OUT, "w")
f:write("probe_drop_setup — verify SetUpDroppedItem port\n")
f:write("===============================================\n\n")
f:write(string.format("WorldKillCycle = $%02X\n", R(0x052A)))
f:write(string.format("WorldKillCount = $%02X\n", R(0x0627)))
f:write(string.format("HelpDropCount  = $%02X\n", R(0x0050)))
f:write(string.format("HelpDropValue  = $%02X\n", R(0x0051)))
f:write("\n")

local stuck_count = 0
local drop_count  = 0
local destroy_count = 0
for slot=1,11 do
    f:write(string.format("slot %02d:\n", slot))
    local saw_60 = false
    for w=1,10 do
        local s = windows[w][slot]
        local mark = ""
        if s.type == 0x60 then
            saw_60 = true
            if s.lifetime == 0 then
                mark = " <-- STUCK no lifetime"
                stuck_count = stuck_count + 1
            else
                mark = " <-- drop OK"
            end
        elseif saw_60 and s.alive == 0 and s.type == 0 then
            mark = " <-- destroyed (no-drop)"
            destroy_count = destroy_count + 1
            saw_60 = false  -- count once
        end
        f:write(string.format("  w%02d alive=%02X type=%02X ms=%02X lt=%02X id=%02X%s\n",
            w, s.alive, s.type, s.metastate, s.lifetime, s.item_id, mark))
        if s.type == 0x60 and s.lifetime ~= 0 then drop_count = drop_count + 1 end
    end
end

f:write("\n")
f:write(string.format("drops_committed=%d  destroyed=%d  stuck=%d\n",
    drop_count, destroy_count, stuck_count))
if stuck_count == 0 then
    f:write("VERDICT: GREEN — no slot stuck at type=$60 lifetime=0\n")
else
    f:write("VERDICT: RED — stuck dead-dummy slots still exist\n")
end
f:close()
client.screenshot(SHOT)
gui.text(8, 8, "drop probe done")
client.exit()
