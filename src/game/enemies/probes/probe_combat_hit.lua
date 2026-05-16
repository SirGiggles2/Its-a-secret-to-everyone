-- probe_combat_hit.lua — verify sword damages adjacent enemy.
-- Boot, scroll to room $76 (octoroks), walk Link adjacent to nearest
-- octorok, swing sword, check HP delta + kill count.
--
-- Output: C:\tmp\probe_combat_hit.txt + screenshots.

local BASE = 0x8000
local function R(off)   return memory.read_u8(BASE + off, "68K RAM") end
local function idle(n)  for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end
local function hold(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end
local function dist(x1,y1,x2,y2)
    local dx = x1 - x2; if dx < 0 then dx = -dx end
    local dy = y1 - y2; if dy < 0 then dy = -dy end
    return dx + dy  -- Manhattan
end

local OUT = "C:\\tmp\\probe_combat_hit.txt"
local f = io.open(OUT, "w")
f:write("probe_combat_hit\n================\n\n")

local function dump_enemies()
    local count = 0
    local nearest_slot, nearest_d = 0, 999
    local lx = R(0x0070); local ly = R(0x0084)
    for slot=1,11 do
        if R(0x0492 + slot) ~= 0 then
            count = count + 1
            local ex = R(0x0070 + slot); local ey = R(0x0084 + slot)
            local d = dist(lx, ly, ex, ey)
            if d < nearest_d then nearest_d = d; nearest_slot = slot end
        end
    end
    return count, nearest_slot, nearest_d
end

local function snap(tag, shot_path)
    local lx = R(0x0070); local ly = R(0x0084)
    local cnt, ns, nd = dump_enemies()
    f:write(string.format("== %s ==\n", tag))
    f:write(string.format("  frame=%d Link=($%02X,$%02X) RoomId=$%02X enemies=%d nearest_slot=%d nearest_dist=%d\n",
        emu.framecount(), lx, ly, R(0x00EB), cnt, ns, nd))
    if ns > 0 then
        f:write(string.format("    nearest: type=$%02X hp=$%02X xy=($%02X,$%02X)\n",
            R(0x034F + ns), R(0x0485 + ns),
            R(0x0070 + ns), R(0x0084 + ns)))
    end
    for slot=1,11 do
        if R(0x0492 + slot) ~= 0 then
            f:write(string.format("    slot%02d: type=$%02X hp=$%02X xy=($%02X,$%02X)\n",
                slot, R(0x034F + slot), R(0x0485 + slot),
                R(0x0070 + slot), R(0x0084 + slot)))
        end
    end
    f:write("\n")
    if shot_path then client.screenshot(shot_path) end
end

-- Boot + debug enter.
idle(40)
press({A=true, B=true, C=true}, 30)
idle(60)

-- Walk LEFT 120 frames to scroll into $76 (where octoroks live).
hold({Left=true}, 120)
idle(60)
snap("0 entered room $76", "C:\\tmp\\probe_combat_0.png")

-- Hunt nearest enemy. Walk toward it until adjacent.
-- Strategy: 8 cycles of pick-direction-then-step-30-frames.
for cycle=1,8 do
    local lx = R(0x0070); local ly = R(0x0084)
    local cnt, ns, nd = dump_enemies()
    if ns == 0 then break end
    local ex = R(0x0070 + ns); local ey = R(0x0084 + ns)
    local dx = ex - lx; local dy = ey - ly
    -- Pick dominant axis to close on.
    local btn = {}
    if math.abs(dx) > math.abs(dy) then
        if dx > 0 then btn.Right = true else btn.Left = true end
    else
        if dy > 0 then btn.Down = true else btn.Up = true end
    end
    hold(btn, 30)
end
snap("1 approached nearest enemy", "C:\\tmp\\probe_combat_1.png")

-- Swing sword 30 times with neutral between.
local hp_before = {}
for slot=1,11 do hp_before[slot] = R(0x0485 + slot) end
for i=1,30 do
    joypad.set({A=true}, 1); emu.frameadvance()
    joypad.set({}, 1); emu.frameadvance()
end
snap("2 post-30-swings", "C:\\tmp\\probe_combat_2.png")

-- Continue swinging + repositioning.
for cycle=1,4 do
    local lx = R(0x0070); local ly = R(0x0084)
    local cnt, ns, nd = dump_enemies()
    if ns == 0 then break end
    local ex = R(0x0070 + ns); local ey = R(0x0084 + ns)
    local dx = ex - lx; local dy = ey - ly
    local btn = {}
    if math.abs(dx) > math.abs(dy) then
        if dx > 0 then btn.Right = true else btn.Left = true end
    else
        if dy > 0 then btn.Down = true else btn.Up = true end
    end
    hold(btn, 20)
    for i=1,20 do
        joypad.set({A=true}, 1); emu.frameadvance()
        joypad.set({}, 1); emu.frameadvance()
    end
end
snap("3 post-extended-combat", "C:\\tmp\\probe_combat_3.png")

f:write("=== VERDICT ===\n")
local final_cnt, _, _ = dump_enemies()
f:write(string.format("Initial 4 enemies in room $76\nFinal alive: %d\n", final_cnt))
f:write("HP delta per slot:\n")
for slot=1,11 do
    local hp_after = R(0x0485 + slot)
    if hp_before[slot] ~= 0 or hp_after ~= 0 then
        f:write(string.format("  slot%02d: $%02X -> $%02X (delta %+d)\n",
            slot, hp_before[slot], hp_after, hp_after - hp_before[slot]))
    end
end

if final_cnt == 0 then
    f:write("GREEN: all enemies killed\n")
elseif final_cnt < 4 then
    f:write("YELLOW: combat works, some kills landed\n")
else
    local any_hp_drop = false
    for slot=1,11 do
        local hp_after = R(0x0485 + slot)
        if hp_before[slot] > 0 and hp_after < hp_before[slot] then any_hp_drop = true end
    end
    if any_hp_drop then
        f:write("YELLOW: HP damage registered but no kills\n")
    else
        f:write("RED: no HP changes — sword damage not landing\n")
    end
end

f:close()
client.exit()
