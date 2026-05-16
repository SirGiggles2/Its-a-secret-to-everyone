-- probe_combat_room76.lua — scroll into $76 (4 natural octoroks),
-- walk LEFT until adjacent to slot1 octorok (~X=$14), then A-mash.
-- Sample $00B9 sword_state + HP per slot per frame.
--
-- After scroll: Link at ($F0,$85), octoroks at X=$14..$59. Need ~200 LEFT
-- frames to traverse from X=$F0 to ~X=$30.
--
-- Output: C:\tmp\probe_combat_room76.txt + .png

local BASE = 0x8000
local function R(off)   return memory.read_u8(BASE + off, "68K RAM") end
local function idle(n)  for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end
local function hold(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end
local function dist(x1,y1,x2,y2)
    local dx = x1-x2; if dx<0 then dx=-dx end
    local dy = y1-y2; if dy<0 then dy=-dy end
    return dx + dy
end

local OUT = "C:\\tmp\\probe_combat_room76.txt"
local f = io.open(OUT, "w")
f:write("probe_combat_room76\n===================\n\n")

-- Boot + debug enter.
idle(40); press({A=true,B=true,C=true},30); idle(60)

-- Scroll west to $76.
hold({Left=true}, 120); idle(60)

f:write(string.format("== post-scroll ($76 entry) ==\n"))
f:write(string.format("  Link=($%02X,$%02X) RoomId=$%02X\n",
    R(0x0070), R(0x0084), R(0x00EB)))
local alive_after_scroll = 0
for slot=1,11 do
    if R(0x0492+slot) ~= 0 then
        alive_after_scroll = alive_after_scroll + 1
        f:write(string.format("  slot%02d: type=$%02X hp=$%02X xy=($%02X,$%02X)\n",
            slot, R(0x034F+slot), R(0x0485+slot), R(0x0070+slot), R(0x0084+slot)))
    end
end
f:write(string.format("  enemies=%d\n\n", alive_after_scroll))

-- Smart hunt: 12 cycles of (re-pick-target -> step ~25 frames toward it).
-- After ~300 total frames Link should reach an adjacent cell.
f:write("== hunt phase ==\n")
local hp_initial = {}
for slot=1,11 do hp_initial[slot] = R(0x0485+slot) end

local hunt_log = {}
for cycle=1,12 do
    local lx = R(0x0070); local ly = R(0x0084)
    local nearest_slot, nearest_d = 0, 999
    for slot=1,11 do
        if R(0x0492+slot) ~= 0 then
            local d = dist(lx,ly, R(0x0070+slot), R(0x0084+slot))
            if d < nearest_d then nearest_d=d; nearest_slot=slot end
        end
    end
    if nearest_slot == 0 then break end
    local ex = R(0x0070+nearest_slot); local ey = R(0x0084+nearest_slot)
    local dx = ex - lx; local dy = ey - ly
    local btn = {}
    if math.abs(dx) > math.abs(dy) then
        if dx > 0 then btn.Right=true else btn.Left=true end
    else
        if dy > 0 then btn.Down=true else btn.Up=true end
    end
    hold(btn, 25)
    table.insert(hunt_log, string.format("  cyc%02d: Link=($%02X,$%02X) -> slot%d ($%02X,$%02X) d=%d btn=%s",
        cycle, lx, ly, nearest_slot, ex, ey, nearest_d,
        btn.Left and "L" or btn.Right and "R" or btn.Up and "U" or btn.Down and "D" or "-"))
end
for _,line in ipairs(hunt_log) do f:write(line.."\n") end

-- Combat: 120 frames A-mash + per-frame HP tracking.
f:write("\n== combat phase: A-mash 120 frames ==\n")
local hp_prev = {}
for slot=1,11 do hp_prev[slot] = R(0x0485+slot) end
local first_drop_slot = -1
local first_drop_frame = -1
local first_drop_from = 0
local first_drop_to = 0
local sword_state_at_drop = 0
local sword_state_max = 0
local total_drops = 0
local hits_per_slot = {}
for slot=1,11 do hits_per_slot[slot] = 0 end

local lx_at_first_swing = R(0x0070); local ly_at_first_swing = R(0x0084)
f:write(string.format("  Link at combat-start: ($%02X,$%02X) face=$%02X\n",
    lx_at_first_swing, ly_at_first_swing, R(0x008C)))
for slot=1,11 do
    if R(0x0492+slot) ~= 0 then
        f:write(string.format("    enemy slot%02d: hp=$%02X xy=($%02X,$%02X)\n",
            slot, R(0x0485+slot), R(0x0070+slot), R(0x0084+slot)))
    end
end

for i=1,120 do
    if (i%2)==1 then joypad.set({A=true},1) else joypad.set({},1) end
    emu.frameadvance()
    local sst = R(0x00B9)
    if sst > sword_state_max then sword_state_max = sst end
    for slot=1,11 do
        local hp = R(0x0485+slot)
        if hp < hp_prev[slot] then
            total_drops = total_drops + 1
            hits_per_slot[slot] = hits_per_slot[slot] + 1
            if first_drop_slot < 0 then
                first_drop_slot = slot; first_drop_frame = i
                first_drop_from = hp_prev[slot]; first_drop_to = hp
                sword_state_at_drop = sst
            end
        end
        hp_prev[slot] = hp
    end
end

f:write(string.format("\n  sword_state_max during combat: $%02X\n", sword_state_max))
f:write(string.format("  total HP drops: %d\n", total_drops))
f:write(string.format("  per-slot hits: "))
for slot=1,11 do if hits_per_slot[slot] > 0 then f:write(string.format("s%d=%d ", slot, hits_per_slot[slot])) end end
f:write("\n")
if first_drop_slot > 0 then
    f:write(string.format("  first drop: slot=%d frame=%d hp=$%02X->$%02X sst=$%02X\n",
        first_drop_slot, first_drop_frame, first_drop_from, first_drop_to, sword_state_at_drop))
end

local alive_end = 0
for slot=1,11 do if R(0x0492+slot)~=0 then alive_end=alive_end+1 end end
f:write(string.format("  alive_end=%d (was %d at scroll)\n", alive_end, alive_after_scroll))

-- Final sword/Link position vs enemy positions
f:write("\n  final state:\n")
f:write(string.format("    Link=($%02X,$%02X) face=$%02X\n", R(0x0070), R(0x0084), R(0x008C)))
f:write(string.format("    sword cells: B9=$%02X 7D=$%02X 91=$%02X A5=$%02X\n",
    R(0x00B9), R(0x007D), R(0x0091), R(0x00A5)))
for slot=1,11 do
    if R(0x0492+slot)~=0 then
        local d = dist(R(0x0070),R(0x0084), R(0x0070+slot), R(0x0084+slot))
        f:write(string.format("    enemy slot%02d: hp=$%02X xy=($%02X,$%02X) d_from_Link=%d\n",
            slot, R(0x0485+slot), R(0x0070+slot), R(0x0084+slot), d))
    end
end

f:write("\n== VERDICT ==\n")
if total_drops > 0 then
    f:write(string.format("GREEN: combat works end-to-end. %d hits landed.\n", total_drops))
elseif alive_end < alive_after_scroll then
    f:write(string.format("YELLOW: kills landed (%d->%d) but no HP-drop event captured (one-shot kill?).\n",
        alive_after_scroll, alive_end))
elseif sword_state_max == 2 then
    f:write("RED: sword swings (state==2) but NO HP drops. Collision engine gap.\n")
else
    f:write(string.format("YELLOW: sword state max=$%02X never reached 2.\n", sword_state_max))
end

client.screenshot("C:\\tmp\\probe_combat_room76.png")
f:close()
client.exit()
