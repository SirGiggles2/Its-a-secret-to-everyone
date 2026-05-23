-- Scan all 128 NES OW rooms, capture SPR sub-pal 3 patched colors.
-- Force-warp each room via RAM write to $00EB + GameMode $06 trigger.
-- Wait for InitMode5Play to patch palette, dump $3F1D..$3F1F.
-- Emit a C array suitable for embedding in Gen.

local function R(o) return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
local function PAL(o) return memory.read_u8(o, "PALRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, hold, settle)
  for _=1,hold do joypad.set({[b]=true}, 1); emu.frameadvance() end
  joypad.set({}, 1); for _=1,settle do emu.frameadvance() end
end

-- Boot to gameplay
idle(360); press("Start", 4, 60)
press("Down",4,20); press("Down",4,20); press("Down",4,20)
press("Start",4,60); press("Start",4,60)
for _=1,5 do press("Down",4,8) end
for _=1,5 do press("Right",4,8) end
press("Start",4,60)
for _=1,5 do press("Up",4,12) end
press("Start",4,180); idle(180)

local f = io.open("C:/tmp/nes_ow_subpal3.txt","w")
f:write("/* NES OW sub-pal 3 captured per-room. 128 rooms x 4 bytes. */\n")
f:write("const unsigned char k_ow_subpal3_per_room[128][4] = {\n")

for room = 0, 127 do
  -- Force OW + room id + reload
  W(0x0010, 0x00)
  W(0x00EB, room)
  W(0x0012, 0x06)  -- LoadLevel -> InitEnterRoom -> Play
  idle(120)        -- transition
  idle(60)         -- patch settle

  local c0 = PAL(28)  -- $3F1C universal mirror
  local c1 = PAL(29)  -- $3F1D
  local c2 = PAL(30)  -- $3F1E
  local c3 = PAL(31)  -- $3F1F
  f:write(string.format("    [0x%02X] = { 0x%02X, 0x%02X, 0x%02X, 0x%02X },\n",
    room, c0, c1, c2, c3))
end

f:write("};\n")
f:close()
client.exit()
