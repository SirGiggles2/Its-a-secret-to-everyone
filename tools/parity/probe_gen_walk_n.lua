-- Warp L1 r$63, kill all enemies, walk Link UP, verify Y decreases past N door threshold.

local NES_BASE = 0x8000
local function R(o)   return memory.read_u8(NES_BASE + o, "68K RAM") end
local function W(o,v) memory.write_u8(NES_BASE + o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function safe_set(p)
  local ok = pcall(function() joypad.set(p or {}, 1) end)
  if not ok then joypad.set(p or {}) end
end
local function hold(b, frames)
  for _=1,frames do safe_set({[b]=true, ["P1 "..b]=true}); emu.frameadvance() end
  safe_set({})
end
local PROBE_CTRL = 0x73F8
local DMG_CTRL = 0x77E0

for _ = 1, 60 do emu.frameadvance() end
for _ = 1, 30 do
  safe_set({A=true, B=true, C=true, ["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
  emu.frameadvance()
end
safe_set({})
for _ = 1, 240 do emu.frameadvance() end

-- Warp L1 r$63
W(0x0098, 0x08)
memory.write_u8(PROBE_CTRL + 0, 0x52, "68K RAM")
memory.write_u8(PROBE_CTRL + 1, 0x50, "68K RAM")
memory.write_u8(PROBE_CTRL + 3, 1, "68K RAM")
memory.write_u8(PROBE_CTRL + 4, 1, "68K RAM")
memory.write_u8(PROBE_CTRL + 5, 0, "68K RAM")
memory.write_u8(PROBE_CTRL + 6, 0x63, "68K RAM")
memory.write_u8(PROBE_CTRL + 7, 0x5A, "68K RAM")
for _ = 1, 30 do
  emu.frameadvance()
  if memory.read_u8(PROBE_CTRL + 7, "68K RAM") == 0 then break end
end
idle(180)

local out = io.open("C:/tmp/gen_walk_n.txt","w")
out:write(string.format("PRE: LinkX=$%02X LinkY=$%02X RoomId=$%02X\n",
  R(0x0070), R(0x0084), R(0x00EB)))
client.screenshot("C:/tmp/gen_walk_n_pre.png")

-- Kill enemies fast via damage hook
for s = 1, 11 do
  for k = 1, 20 do
    if R(0x0492+s) == 0 then break end
    memory.write_u8(DMG_CTRL + 0, 0x44, "68K RAM")
    memory.write_u8(DMG_CTRL + 1, 0x44, "68K RAM")
    memory.write_u8(DMG_CTRL + 2, s, "68K RAM")
    memory.write_u8(DMG_CTRL + 3, 0x10, "68K RAM")
    memory.write_u8(DMG_CTRL + 4, 0x80, "68K RAM")
    for _ = 1, 2 do emu.frameadvance() end
  end
end
idle(60)

out:write(string.format("KILLED: LinkX=$%02X LinkY=$%02X $034D=$%02X $04CE=$%02X\n",
  R(0x0070), R(0x0084), R(0x034D), R(0x04CE)))
client.screenshot("C:/tmp/gen_walk_n_killed.png")

-- Walk Link UP for 300 frames
hold("Up", 300)
idle(30)

out:write(string.format("POST-UP: LinkX=$%02X LinkY=$%02X RoomId=$%02X\n",
  R(0x0070), R(0x0084), R(0x00EB)))
client.screenshot("C:/tmp/gen_walk_n_post.png")
out:close()
client.exit()
