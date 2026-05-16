-- probe_natural_drop.lua — verify drop→pickup chain in real gameplay.
-- Enter debug mode, idle through enemy_loop_probe_run() spawn, swing sword
-- until enemies die. Capture frame-by-frame slot history for 60 frames
-- post-A+B+C entry — look for any natural type=$60 lifetime>0 transition.
--
-- Output: C:\tmp\probe_natural_drop.txt + screenshot.

local BASE = 0x8000
local function R(off) return memory.read_u8(BASE + off, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end

local OUT  = "C:\\tmp\\probe_natural_drop.txt"
local SHOT = "C:\\tmp\\probe_natural_drop.png"

idle(60)
press({A=true,B=true,C=true}, 30)
idle(60)

-- Now capture history of all 11 slots across 240 frames while swinging.
local hist = {}
for slot=1,11 do hist[slot] = {} end
for frame=1,240 do
    -- swing sword + waggle dpad to land hits
    local btn = {A=true}
    if (frame % 8) < 4 then btn.RIGHT = true else btn.LEFT = true end
    joypad.set(btn, 1)
    emu.frameadvance()
    for slot=1,11 do
        hist[slot][frame] = {
            a = R(0x0492 + slot),
            t = R(0x034F + slot),
            l = R(0x03A8 + slot),
            i = R(0x00AC + slot),
        }
    end
end

local f = io.open(OUT, "w")
f:write("probe_natural_drop\n==================\n\n")
f:write(string.format("GameMode=$%02X Link=$%02X,$%02X\n", R(0x0012), R(0x0070), R(0x0084)))

local saw_drop = false
local drop_summary = {}
for slot=1,11 do
    local first_60, last_60 = nil, nil
    local life_at_first_60 = nil
    local picked_up = false
    for frame=1,240 do
        local s = hist[slot][frame]
        if s.t == 0x60 then
            if not first_60 then
                first_60 = frame
                life_at_first_60 = s.l
            end
            last_60 = frame
        elseif first_60 and s.t == 0 and s.a == 0 then
            picked_up = true
        end
    end
    if first_60 then
        saw_drop = true
        drop_summary[#drop_summary+1] = string.format(
            "  slot %02d: type=$60 frames %d..%d (lifetime first=$%02X) %s",
            slot, first_60, last_60, life_at_first_60,
            picked_up and "-> picked up / destroyed" or "")
    end
end

if saw_drop then
    f:write("DROPS OBSERVED:\n")
    for _, line in ipairs(drop_summary) do f:write(line .. "\n") end
else
    f:write("NO DROPS in 240 frames.\n")
end

f:write("\nFINAL SLOT STATE:\n")
for slot=1,11 do
    f:write(string.format("  slot %02d: alive=%02X type=%02X lt=%02X id=%02X x=%02X y=%02X\n",
        slot, R(0x0492+slot), R(0x034F+slot), R(0x03A8+slot), R(0x00AC+slot),
        R(0x0070+slot), R(0x0084+slot)))
end

f:write(string.format("\nWorldKillCycle=$%02X WorldKillCount=$%02X HelpDropCount=$%02X HelpDropValue=$%02X\n",
    R(0x052A), R(0x0627), R(0x0050), R(0x0051)))

-- Inventory diff vs starting at frame ~60 (snapshot before fight)
f:write(string.format("\nINVENTORY: rupees$%02X bombs$%02X keys$%02X\n",
    R(0x065B), R(0x0658), R(0x066E)))

f:close()
client.screenshot(SHOT)
gui.text(8, 8, saw_drop and "drops observed" or "no drops")
client.exit()
