-- probe_uw_v2.lua — press MODE button to toggle SCENE_OW->SCENE_UW.

local OUT = "C:\\tmp\\uw_v2.txt"
local SHOT = "C:\\tmp\\uw_v2\\"
os.execute("mkdir " .. SHOT .. " 2>NUL")

local function nesram(off) return memory.read_u8(0x8000 + off, "68K RAM") end
local function dvr(off) return memory.read_u8(off, "68K RAM") end
local function press(buttons, frames)
  for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(n) for i = 1, n do emu.frameadvance() end end

local trace = {}
local function snap(label)
  trace[#trace+1] = string.format(
    "%-30s gm=$%02X rm=$%02X lvl=$%02X lx=%3d ly=%3d scn=$%02X song=$%02X",
    label,
    nesram(0x0012), nesram(0x00EB), nesram(0x0010),
    nesram(0x0070), nesram(0x0084),
    nesram(0x07E8),   -- s_scene sentinel after MODE toggle
    dvr(0xE000)       -- m_song
  )
end

idle(120)
press({A=true, B=true, C=true}, 8); idle(60); snap("post-chord OW")
client.screenshot(SHOT .. "01_ow.png")

-- MODE button edge-press to toggle scene
-- Note: BUTTON_MODE may be 'Mode' in BizHawk joypad table for Genesis 6-button
press({Mode=true}, 4); idle(60); snap("after MODE press #1")
client.screenshot(SHOT .. "02_post_mode.png")

idle(60); snap("settle")
client.screenshot(SHOT .. "03_settle.png")

press({Right=true}, 60); snap("Right 60 in UW")
client.screenshot(SHOT .. "04_right.png")

press({Up=true}, 60); snap("Up 60 in UW")
client.screenshot(SHOT .. "05_up.png")

press({A=true}, 4); idle(20); snap("sword in UW")
client.screenshot(SHOT .. "06_sword.png")

press({Down=true}, 120); snap("Down 120")
client.screenshot(SHOT .. "07_down.png")

-- Walk all 4 sides to find doors / scroll
press({Left=true}, 120); snap("Left 120")
client.screenshot(SHOT .. "08_left.png")

press({Up=true}, 180); snap("Up 180")
client.screenshot(SHOT .. "09_up_more.png")

local f = io.open(OUT, "w")
f:write("UW v2 probe (MODE toggle) — " .. os.date() .. "\n")
f:write("=============================================================\n\n")
for _, l in ipairs(trace) do f:write(l .. "\n") end
f:write("\nExpected: scn becomes $01 (SCENE_UW), song -> $40, screen = dungeon BG\n")
f:close()
print("Wrote " .. OUT)
