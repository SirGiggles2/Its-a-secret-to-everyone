-- probe_gameplay_smoke.lua — full gameplay loop verification.
-- Arms enemy-stress probe (writes 'EP' to $FF73FC) BEFORE A+B+C debug
-- entry, so roomrom_debug_enter -> enemy_loop_probe_run force-spawns
-- the 11-slot stress harness. Then runs 480 frames swinging sword,
-- capturing slot/inventory/Link state at intervals.
--
-- Output: C:\tmp\probe_gameplay_smoke.txt + screenshot.

local BASE = 0x8000
local function R(off)   return memory.read_u8(BASE + off, "68K RAM") end
local function W(off,v) memory.write_u8(BASE + off, v, "68K RAM") end
local function idle(n)  for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end

local OUT  = "C:\\tmp\\probe_gameplay_smoke.txt"
local SHOT = "C:\\tmp\\probe_gameplay_smoke.png"

-- Phase A — boot.
idle(40)

-- Phase B — arm enemy stress harness.
-- Two control regions exist (legacy + canonical). Set both for safety.
-- Canonical: $FF73F8 = 'R','P', flags byte +2 = 0x02 (ENEMY_STRESS).
W(0x73F8, 0x52)  -- 'R'
W(0x73F9, 0x50)  -- 'P'
W(0x73FA, 0x02)  -- ENEMY_STRESS flag
-- Legacy: $FF73FC = 'E','P'.
W(0x73FC, 0x45)  -- 'E'
W(0x73FD, 0x50)  -- 'P'

-- Phase C — enter debug mode (chord A+B+C).
press({A=true, B=true, C=true}, 30)
idle(20)

-- Phase D — snapshot fn captures slot + Link + inventory state.
local function snap(label)
    local row = {label=label, frame=emu.framecount(),
        gm=R(0x0012), link_x=R(0x0070), link_y=R(0x0084),
        link_face=R(0x008C),
        sword_lv=R(0x0657 + 0), bombs=R(0x0658),
        rupees=R(0x065B), keys=R(0x066E),
        hearts=R(0x066F), max_hearts=R(0x067C),
        slots={}}
    for slot=1,11 do
        row.slots[slot] = {
            a=R(0x0492 + slot),  -- alive
            t=R(0x034F + slot),  -- type
            l=R(0x03A8 + slot),  -- item lifetime (only meaningful for type=$60)
            h=R(0x0485 + slot),  -- HP
            x=R(0x0070 + slot),  -- X
            y=R(0x0084 + slot),  -- Y
            m=R(0x0405 + slot),  -- metastate
        }
    end
    return row
end

local snapshots = {}
snapshots[#snapshots+1] = snap("T+0 post-debug-enter")

-- Phase E — 480 frames of sword swinging + d-pad waggle.
-- Period 30: A=swing, 60: dpad-right, 90: A=swing, etc.
-- Capture snapshot every 60 frames.
for block=1,8 do
    for f=1,60 do
        local btn = {}
        if (f % 8) == 0 then btn.A = true end  -- swing sword
        local phase = ((block * 60 + f) % 32)
        if phase < 8 then btn.RIGHT = true
        elseif phase < 16 then btn.DOWN = true
        elseif phase < 24 then btn.LEFT = true
        else btn.UP = true end
        joypad.set(btn, 1)
        emu.frameadvance()
    end
    snapshots[#snapshots+1] = snap(string.format("T+%d", block * 60))
end

-- Phase F — write report.
local f = io.open(OUT, "w")
f:write("probe_gameplay_smoke\n=====================\n\n")
f:write("Arm path: $FF73F8='RP'+0x02 + $FF73FC='EP'\n")
f:write("Chord:    A+B+C for 30 frames after 40-frame idle\n")
f:write(string.format("Final frame=%d\n\n", emu.framecount()))

for _, s in ipairs(snapshots) do
    f:write(string.format("== %s (frame %d) ==\n", s.label, s.frame))
    f:write(string.format("  GameMode=$%02X Link=($%02X,$%02X) face=$%02X\n",
        s.gm, s.link_x, s.link_y, s.link_face))
    f:write(string.format("  inv: sword$%02X bombs$%02X rupees$%02X keys$%02X hearts$%02X/$%02X\n",
        s.sword_lv, s.bombs, s.rupees, s.keys, s.hearts, s.max_hearts))
    local alive = 0
    local dropped = 0
    for slot=1,11 do
        local sl = s.slots[slot]
        if sl.a ~= 0 then alive = alive + 1 end
        if sl.t == 0x60 then dropped = dropped + 1 end
        if sl.a ~= 0 or sl.t ~= 0 then
            f:write(string.format("  slot%02d: a=%02X t=%02X h=%02X lt=%02X m=%02X xy=($%02X,$%02X)\n",
                slot, sl.a, sl.t, sl.h, sl.l, sl.m, sl.x, sl.y))
        end
    end
    f:write(string.format("  alive=%d dropped=%d\n\n", alive, dropped))
end

-- Verdict logic.
local first_alive = 0
for slot=1,11 do if snapshots[1].slots[slot].a ~= 0 then first_alive = first_alive + 1 end end
local last_alive = 0
local last_dropped = 0
local last = snapshots[#snapshots]
for slot=1,11 do
    if last.slots[slot].a ~= 0 then last_alive = last_alive + 1 end
    if last.slots[slot].t == 0x60 then last_dropped = last_dropped + 1 end
end

local first_rupees = snapshots[1].rupees
local last_rupees = last.rupees

f:write("=== VERDICT ===\n")
f:write(string.format("Spawned at T+0: %d alive\n", first_alive))
f:write(string.format("End-state:      %d alive, %d dropped-item slots\n", last_alive, last_dropped))
f:write(string.format("Rupees delta:   $%02X -> $%02X (+%d)\n",
    first_rupees, last_rupees, last_rupees - first_rupees))

if first_alive == 0 then
    f:write("RED: enemy_loop_probe_run never spawned harness — arm bits not honored\n")
elseif last_alive == first_alive and last_dropped == 0 then
    f:write("YELLOW: enemies spawned but sword never connected (no kills, no drops)\n")
elseif last_dropped > 0 then
    f:write("GREEN: kills landed + drops appeared\n")
elseif last_alive < first_alive then
    f:write("YELLOW: kills landed but drops decayed/picked up before final snapshot\n")
else
    f:write("UNKNOWN\n")
end

f:close()
client.screenshot(SHOT)
gui.text(8, 8, string.format("smoke done a=%d d=%d", last_alive, last_dropped))
client.exit()
