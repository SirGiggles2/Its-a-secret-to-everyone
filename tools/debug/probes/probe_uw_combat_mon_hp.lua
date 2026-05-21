-- probe_uw_combat.lua — verify sword damage path in UW.
-- Track MON_HP for all 11 slots each frame during combat attempt.
-- Position Link directly adjacent to enemy + swing repeatedly.

local OUT = "C:\\tmp\\uw_combat.txt"
local SHOT = "C:\\tmp\\uw_combat\\"
os.execute("mkdir " .. SHOT .. " 2>NUL")

local function nesram(off) return memory.read_u8(0x8000 + off, "68K RAM") end
local function press(buttons, frames)
  for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(n) for i = 1, n do emu.frameadvance() end end

local trace = {}
local function snap(label)
  -- 11 slots: type at $034F+s, HP at $0485+s, X $0070+s, Y $0084+s
  local enemies = {}
  for s = 1, 6 do
    local t  = nesram(0x034F + s)
    local hp = nesram(0x0485 + s)
    local x  = nesram(0x0070 + s)
    local y  = nesram(0x0084 + s)
    if t ~= 0 then
      enemies[#enemies+1] = string.format("s%d{t=%02X hp=%02X xy=%02X,%02X}", s, t, hp, x, y)
    end
  end
  -- Link
  local lx = nesram(0x0070)
  local ly = nesram(0x0084)
  local lhp = nesram(0x066F)
  local sword_state = nesram(0x040E)  -- OBJ_STATE slot 14 = sword obj
  local sword_x = nesram(0x007E)      -- ObjX slot 14
  local sword_y = nesram(0x0092)
  trace[#trace+1] = string.format(
    "%-22s L(%3d,%3d hp$%02X) sw(s=$%02X xy=%02X,%02X) enemies=[%s]",
    label, lx, ly, lhp, sword_state, sword_x, sword_y,
    table.concat(enemies, " "))
end

idle(120)
press({A=true, B=true, C=true}, 8); idle(60)
press({Mode=true}, 4); idle(60); snap("UW entered")

-- Walk through Up door to enemy room $63
press({Up=true}, 180); idle(30); snap("entered r63")
client.screenshot(SHOT .. "01_enter_r63.png")

-- Approach enemy at top of room. Face Up.
press({Up=true}, 30); snap("approach 1")
press({Up=true}, 30); snap("approach 2")
client.screenshot(SHOT .. "02_approached.png")

-- Swing sword multiple times, snap each swing
for i = 1, 12 do
  snap(string.format("pre-swing %02d", i))
  press({A=true}, 4)
  snap(string.format("swing %02d held", i))
  idle(20)
  snap(string.format("swing %02d settle", i))
end
client.screenshot(SHOT .. "03_after_12_swings.png")

-- Move adjacent to one Goriya, swing again
press({Down=true}, 20); snap("down 20")
press({Left=true}, 30); snap("left 30")
for i = 1, 8 do
  press({A=true}, 4); idle(15)
  snap(string.format("repeated swing %02d", i))
end
client.screenshot(SHOT .. "04_repeated.png")

local f = io.open(OUT, "w")
f:write("UW combat probe — " .. os.date() .. "\n")
f:write("=============================================================\n\n")
for _, l in ipairs(trace) do f:write(l .. "\n") end
f:close()
print("Wrote " .. OUT)
