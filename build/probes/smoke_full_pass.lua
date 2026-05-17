-- smoke_full_pass.lua — exercise core gameplay to validate -O3 build.
-- 1. Boot + debug mode chord
-- 2. Screenshot initial OW (boot room)
-- 3. Attack 30 frames (trigger SFX path)
-- 4. Hold UP 200f (scroll)
-- 5. Screenshot post-scroll OW
-- 6. Idle 200f, measure FPS
-- 7. Press Start + B (toggle scene per project_roomrom_debug_teleport)
-- 8. Screenshot scene-toggle result
-- 9. Write smoke_full_pass.txt with timings + state captures

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\smoke_full_pass.txt"
local f = io.open(OUT, "w")

local FC = 0x7202
local ROOM = 0x7205
local SCENE = 0x7204
local LX = 0x7207
local LY = 0x7209

idle(60)
-- A+B+C chord enters debug mode (force-spawns 11 enemies per harness)
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(30)

local function fc() return R16BE(FC) end
local function state_line(label)
  return string.format("%s scene=%d room=$%02X x=$%02X y=$%02X fc=%d",
    label, R(SCENE), R(ROOM), R(LX), R(LY), fc())
end

f:write(state_line("[01 post-boot]   ") .. "\n")
client.screenshot("C:\\tmp\\smoke_01_boot.png")

-- Attack 30 frames
for i=1,30 do joypad.set({B=true}, 1); emu.frameadvance() end
idle(20)
f:write(state_line("[02 post-attack] ") .. "\n")
client.screenshot("C:\\tmp\\smoke_02_attack.png")

-- Scroll up
local fc_pre = fc()
for i=1,200 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(30)
local fc_post = fc()
local scroll_game = fc_post - fc_pre
if scroll_game < 0 then scroll_game = scroll_game + 65536 end
f:write(string.format("[03 scroll]      200 emu -> %d game = %.3f ratio\n",
  scroll_game, scroll_game/200))
f:write(state_line("[03 post-scroll] ") .. "\n")
client.screenshot("C:\\tmp\\smoke_03_scroll.png")

-- Idle measure
fc_pre = fc()
for i=1,300 do emu.frameadvance() end
fc_post = fc()
local idle_game = fc_post - fc_pre
if idle_game < 0 then idle_game = idle_game + 65536 end
f:write(string.format("[04 idle 300]    300 emu -> %d game = %.3f ratio (target 1.000)\n",
  idle_game, idle_game/300))

-- Walk right
for i=1,120 do joypad.set({Right=true}, 1); emu.frameadvance() end
idle(20)
f:write(state_line("[05 post-right]  ") .. "\n")
client.screenshot("C:\\tmp\\smoke_05_right.png")

-- Final idle
fc_pre = fc()
for i=1,300 do emu.frameadvance() end
fc_post = fc()
idle_game = fc_post - fc_pre
if idle_game < 0 then idle_game = idle_game + 65536 end
f:write(string.format("[06 final idle]  300 emu -> %d game = %.3f ratio\n",
  idle_game, idle_game/300))
client.screenshot("C:\\tmp\\smoke_06_final.png")

f:write("\nDONE\n")
f:close()
gui.text(8, 8, "smoke done")
idle(15)
client.exit()
